//
//  PracticeViewModel.swift
//  Wingman
//

import Foundation
import Combine

@MainActor
final class PracticeViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var practices: [Practice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedPractice: Practice?

    /// Whether `practices`' completion flags reflect a successful read of
    /// `user_scenario_progress`. False after a failed fetch, and false while the
    /// list is being served from the disk cache. See `PracticeFetchResult`.
    @Published private(set) var progressAvailable = false

    /// Session-scoped cache of fetched PracticeGameData keyed by practice ID.
    /// PracticeGameData is immutable scenario content (scenes, text, options),
    /// so caching is always safe. User progress is tracked separately server-side.
    @Published private(set) var gameDataCache: [UUID: PracticeGameData] = [:]

    // MARK: - Dependencies
    private let practiceService: PracticeServiceProtocol
    private var lessonCompletedObserver: NSObjectProtocol?

    // MARK: - Init
    init(practiceService: PracticeServiceProtocol = PracticeService()) {
        self.practiceService = practiceService

        // Refresh practices when a lesson is completed so scenario unlock state
        // reflects the new total immediately, without waiting for a tab switch.
        lessonCompletedObserver = NotificationCenter.default.addObserver(
            forName: .lessonCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchPractices()
            }
        }
    }

    deinit {
        if let observer = lessonCompletedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Fetch Practices from DB
    func fetchPractices() async {
        // Seed from the last successful fetch so a fresh app launch renders
        // content immediately instead of a blank spinner; PracticeView only
        // shows its full-screen loader when `practices` is empty, so this
        // turns every relaunch after the first into a silent background
        // refresh instead of a cold wait.
        if practices.isEmpty, let cached = Self.loadCachedPractices() {
            practices = cached
        }

        isLoading = true
        errorMessage = nil
        do {
            let result = try await practiceService.fetchPractices()
            practices = result.practices
            progressAvailable = result.progressAvailable
            Self.saveCachedPractices(practices)
        } catch {
            errorMessage = error.localizedDescription
            // The list on screen is now either stale cache or empty; either
            // way its completion flags are not authoritative.
            progressAvailable = false
        }
        isLoading = false
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
