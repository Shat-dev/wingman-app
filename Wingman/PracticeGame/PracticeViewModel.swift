//
//  PracticeViewModel.swift
//  Wingman
//

import Foundation
import Combine

@MainActor
final class PracticeViewModel: ObservableObject {

    /// App-wide instance. Shared rather than owned by `PracticeView` so the
    /// scenario list can be fetched during the login sequence, before the
    /// Scenarios tab is ever opened — a view-owned `@StateObject` cannot start
    /// loading until the tab it lives on appears, which is what made the first
    /// visit always show a spinner.
    ///
    /// Being long-lived also means the list and `gameDataCache` now survive the
    /// MainTabView rebuilds that RootView performs when it moves between the
    /// demo, post-demo-ask and gated branches.
    static let shared = PracticeViewModel()

    // MARK: - Published Properties
    @Published var practices: [Practice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedPractice: Practice?

    /// Whether `practices`' completion flags reflect a successful read of
    /// `user_scenario_progress`. False after a failed fetch, and false while the
    /// list is being served from the disk cache. See `PracticeFetchResult`.
    @Published private(set) var progressAvailable = false

    /// Scenarios this session watched the user finish, by id.
    ///
    /// First-hand knowledge, and strictly better evidence than the network read
    /// `progressAvailable` describes — which is the point. Completing a
    /// scenario while the progress read is failing (or with the completion
    /// write itself failing) must still mark the card, and a refetch that comes
    /// back without the flag must not un-mark it. Mirrors how lesson progress
    /// treats the local record as the source of truth and the cloud as
    /// best-effort.
    ///
    /// In-memory only. Durability across launches comes from the disk cache,
    /// which already round-trips `isCompleted`.
    @Published private(set) var locallyCompletedIds: Set<UUID> = []

    /// Session-scoped cache of fetched PracticeGameData keyed by practice ID.
    /// PracticeGameData is immutable scenario content (scenes, text, options),
    /// so caching is always safe. User progress is tracked separately server-side.
    @Published private(set) var gameDataCache: [UUID: PracticeGameData] = [:]

    // MARK: - Dependencies
    private let practiceService: PracticeServiceProtocol
    private var lessonCompletedObserver: NSObjectProtocol?
    private var scenarioCompletedObserver: NSObjectProtocol?

    /// The user the in-memory state was last loaded for, or nil if never loaded.
    ///
    /// Only meaningful because this object is now a singleton: it used to die
    /// with `PracticeView`, so a new sign-in always got an empty one. Now it
    /// outlives sessions, and `isLocked` / `isCompleted` are per-user — without
    /// this check the next account would briefly see the previous account's
    /// lock and completion state. `clearCache()` on logout is the primary
    /// guard; this is the backstop for any path that doesn't route through it.
    private var loadedUserId: String?

    // MARK: - Init
    init(practiceService: PracticeServiceProtocol = PracticeService()) {
        self.practiceService = practiceService

        // Refresh practices when a lesson is completed so scenario unlock state
        // reflects the new total immediately, without waiting for a tab switch.
        //
        // Silent (`preloadPractices`) because lessons complete in LessonView,
        // pushed from Courses — the Scenarios tab is never on screen when this
        // fires. Surfacing an error here would leave `errorMessage` set on a
        // screen the user is not looking at, and the error view would then flash
        // on their next visit before `PracticeView.task` cleared it. That visit
        // re-fetches and reports failures properly.
        lessonCompletedObserver = NotificationCenter.default.addObserver(
            forName: .lessonCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.preloadPractices()
            }
        }

        // Marks the finished card complete straight away. `PracticeView`'s
        // `.task` sits on its `NavigationStack`, which the push into the game
        // never tears down, so returning from a scenario re-runs nothing — the
        // card would otherwise stay unmarked until the user left the tab and
        // came back.
        scenarioCompletedObserver = NotificationCenter.default.addObserver(
            forName: .scenarioCompleted,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let scenarioId = note.object as? UUID else { return }
            Task { @MainActor [weak self] in
                self?.noteScenarioCompleted(scenarioId)
                await self?.preloadPractices()
            }
        }
    }

    deinit {
        if let observer = lessonCompletedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = scenarioCompletedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Fetch Practices from DB

    /// Loads the scenario list for display. Surfaces failures via
    /// `errorMessage` so `PracticeView` can offer Try Again.
    func fetchPractices() async {
        await load(surfacingErrors: true)
    }

    /// Warms the scenario list ahead of the Scenarios tab being opened, called
    /// from the login sequence in `AuthManager`. This is what removes the
    /// first-visit spinner: by the time the user reaches the tab the list is
    /// already in memory, so `PracticeView`'s loader — which only shows while
    /// `practices` is empty — never appears.
    ///
    /// Silent on failure, deliberately. A preload runs for a screen the user
    /// has not asked for, so it must not leave `errorMessage` set: the error
    /// view would then flash on entry before `fetchPractices()` cleared it.
    /// A failed preload simply leaves the cold path exactly as it was.
    ///
    /// Must run after lesson progress is available — `isLocked` is derived from
    /// the local lesson-completion count. See the call sites in `AuthManager`.
    func preloadPractices() async {
        await load(surfacingErrors: false)
    }

    private func load(surfacingErrors: Bool) async {
        dropStateIfUserChanged()

        // Seed from the last successful fetch so a fresh app launch renders
        // content immediately instead of a blank spinner; PracticeView only
        // shows its full-screen loader when `practices` is empty, so this
        // turns every relaunch after the first into a silent background
        // refresh instead of a cold wait.
        if practices.isEmpty, let cached = Self.loadCachedPractices() {
            practices = cached
        }

        let userId = SupabaseManager.shared.currentUserId

        isLoading = true
        if surfacingErrors { errorMessage = nil }
        do {
            let result = try await practiceService.fetchPractices()
            practices = result.practices
            progressAvailable = result.progressAvailable
            loadedUserId = userId
            // Before the cache write, so a completion this session survives a
            // refetch that raced the (fire-and-forget) completion write and
            // came back without the flag. See `locallyCompletedIds`.
            reapplyLocalCompletions()
            Self.saveCachedPractices(practices)
            // A successful load clears a stale failure from an earlier attempt
            // even when this one was a silent preload — leaving it set would
            // show Try Again over a list that is actually current.
            errorMessage = nil
        } catch {
            if surfacingErrors {
                errorMessage = error.localizedDescription
            }
            // The list on screen is now either stale cache or empty; either
            // way its completion flags are not authoritative.
            progressAvailable = false
        }
        isLoading = false
    }

    // MARK: - Scenario completion

    /// Records a scenario the user just finished and marks its card complete
    /// without waiting on the server.
    ///
    /// Driven by `.scenarioCompleted`, posted from `PracticeGameViewModel`
    /// the moment a genuine finish is reached. The reconciling refetch is the
    /// caller's job; this is only the immediate half.
    func noteScenarioCompleted(_ scenarioId: UUID) {
        locallyCompletedIds.insert(scenarioId)

        guard let index = practices.firstIndex(where: { $0.id == scenarioId }) else { return }
        guard !practices[index].isCompleted else { return }
        practices[index].isCompleted = true
        Self.saveCachedPractices(practices)
    }

    /// Re-marks scenarios finished this session that a fetch came back without.
    private func reapplyLocalCompletions() {
        guard !locallyCompletedIds.isEmpty else { return }
        for index in practices.indices where locallyCompletedIds.contains(practices[index].id) {
            practices[index].isCompleted = true
        }
    }

    /// Whether `practice`'s card should render its completed treatment.
    ///
    /// Completion is only shown when the flag is trustworthy. A `false`
    /// `progressAvailable` means every `isCompleted` is false because the
    /// progress read failed or the list is stale disk cache — not because
    /// nothing is finished — so the flag alone would silently unmark finished
    /// scenarios. Suppressing until a good read lands errs toward showing no
    /// completion rather than a wrong one, and a scenario finished this session
    /// is exempt because that is first-hand knowledge. See `PracticeFetchResult`.
    func showsCompletion(for practice: Practice) -> Bool {
        guard practice.isCompleted else { return false }
        return progressAvailable || locallyCompletedIds.contains(practice.id)
    }

    /// Discards in-memory state belonging to a different user. See `loadedUserId`.
    ///
    /// Routes through `clearCache()` rather than repeating the field list, so
    /// the logout path and this backstop cannot drift apart — anything stale
    /// enough to wipe on logout is stale on an account switch too.
    private func dropStateIfUserChanged() {
        guard let loadedUserId,
              loadedUserId != SupabaseManager.shared.currentUserId else { return }
        log("🎮 Scenario cache belonged to a previous user — dropping")
        clearCache()
    }

    /// Wipes in-memory state on logout. Invoked from
    /// `SupabaseManager.clearCurrentUser()`, alongside the other per-user
    /// stores. The disk cache is namespaced per user id and is left alone, so
    /// a returning account still gets its warm start.
    func clearCache() {
        practices = []
        gameDataCache = [:]
        selectedPractice = nil
        progressAvailable = false
        // Per-user, like the lock and completion flags it backs — leaving it
        // would carry one account's finished scenarios onto the next.
        locallyCompletedIds = []
        errorMessage = nil
        loadedUserId = nil
    }

    // MARK: - Disk cache (UserDefaults, namespaced per-user)
    // `Practice`'s own Codable conformance intentionally omits isLocked/
    // isCompleted/currentScreenId from its CodingKeys (they're computed by
    // the service, not DB columns), so encoding a `Practice` directly would
    // silently drop them. This mirror type exists purely so the cache
    // round-trip preserves those fields without touching `Practice`'s
    // CodingKeys, which the real Supabase decode path depends on.
    private struct CachedPractice: Codable {
        let id: UUID
        let title: String
        let summary: String
        let coverImageUrl: String?
        let requiredLessonsCompleted: Int
        let womanName: String?
        let orderIndex: Int
        let isPublished: Bool
        let createdAt: Date
        let updatedAt: Date
        let isLocked: Bool
        let isCompleted: Bool
        let currentScreenId: UUID?

        init(_ practice: Practice) {
            id = practice.id
            title = practice.title
            summary = practice.summary
            coverImageUrl = practice.coverImageUrl
            requiredLessonsCompleted = practice.requiredLessonsCompleted
            womanName = practice.womanName
            orderIndex = practice.orderIndex
            isPublished = practice.isPublished
            createdAt = practice.createdAt
            updatedAt = practice.updatedAt
            isLocked = practice.isLocked
            isCompleted = practice.isCompleted
            currentScreenId = practice.currentScreenId
        }

        var asPractice: Practice {
            Practice(
                id: id, title: title, summary: summary, coverImageUrl: coverImageUrl,
                requiredLessonsCompleted: requiredLessonsCompleted, womanName: womanName,
                orderIndex: orderIndex, isPublished: isPublished, createdAt: createdAt, updatedAt: updatedAt,
                isLocked: isLocked, isCompleted: isCompleted, currentScreenId: currentScreenId
            )
        }
    }

    private static var cacheKey: String {
        "cached_practices_\(SupabaseManager.shared.currentUserId ?? "anonymous")"
    }

    private static func loadCachedPractices() -> [Practice]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CachedPractice].self, from: data) else {
            return nil
        }
        return cached.map { $0.asPractice }
    }

    private static func saveCachedPractices(_ practices: [Practice]) {
        guard let data = try? JSONEncoder().encode(practices.map(CachedPractice.init)) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    // MARK: - Select Practice
    func selectPractice(_ practice: Practice) {
        guard !practice.isLocked else { return }
        selectedPractice = practice
    }

    // MARK: - Fetch Game Data for selected practice
    func fetchGameData(for practice: Practice) async -> PracticeGameData? {
        // Fast path: cache hit
        if let cached = gameDataCache[practice.id] {
            return cached
        }
        do {
            let data = try await practiceService.fetchGameData(
                scenarioId: practice.id,
                womanName: practice.womanName
            )
            gameDataCache[practice.id] = data
            return data
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Prefetch Game Data
    /// Prefetches PracticeGameData for every currently-unlocked practice that is
    /// not already cached. Fetches run concurrently via TaskGroup. Individual
    /// failures are silently swallowed — the tap-time fallback in PracticeView
    /// will re-attempt and surface errors if the user actually needs that data.
    func prefetchGameData() async {
        let toFetch = practices.filter { !$0.isLocked && gameDataCache[$0.id] == nil }
        guard !toFetch.isEmpty else { return }

        await withTaskGroup(of: (UUID, PracticeGameData?).self) { [practiceService] group in
            for practice in toFetch {
                group.addTask {
                    let data = try? await practiceService.fetchGameData(
                        scenarioId: practice.id,
                        womanName: practice.womanName
                    )
                    return (practice.id, data)
                }
            }
            for await (id, data) in group {
                if let data = data {
                    gameDataCache[id] = data
                }
            }
        }
    }

    // MARK: - Fetch Practice Detail (for detail view)
    func fetchPracticeDetail(for practice: Practice) async -> PracticeDetail? {
        do {
            return try await practiceService.fetchPracticeDetail(practiceId: practice.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
}

// MARK: - Preview Helper
extension PracticeViewModel {
    static var preview: PracticeViewModel {
        let vm = PracticeViewModel(practiceService: MockPracticeService())
        vm.practices = Practice.mockData
        return vm
    }
}
