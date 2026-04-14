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
    @Published var newlyUnlockedPractices: [Practice] = [] // Track newly unlocked practices

    /// Session-scoped cache of fetched PracticeGameData keyed by practice ID.
    /// PracticeGameData is immutable scenario content (scenes, text, options),
    /// so caching is always safe. User progress is tracked separately server-side.
    @Published private(set) var gameDataCache: [UUID: PracticeGameData] = [:]

    // MARK: - Dependencies
    private let practiceService: PracticeServiceProtocol

    // MARK: - Init
    init(practiceService: PracticeServiceProtocol = PracticeService()) {
        self.practiceService = practiceService
    }

    // MARK: - Fetch Practices from DB
    func fetchPractices() async {
        isLoading = true
        errorMessage = nil
        do {
            practices = try await practiceService.fetchPractices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
    
    // MARK: - Check for Newly Unlocked Practices (called when returning from daily practice)
    func checkForNewlyUnlockedPractices() async {
        guard SupabaseManager.shared.currentUserId != nil else {
            return
        }

        // Store previous state
        let previouslyLockedPractices = practices.filter { $0.isLocked }

        // Refresh practices to get updated lock status
        await fetchPractices()

        // Find practices that were locked before but are now unlocked
        let currentlyUnlocked = practices.filter { !$0.isLocked }
        newlyUnlockedPractices = currentlyUnlocked.filter { currentPractice in
            previouslyLockedPractices.contains { $0.id == currentPractice.id }
        }

        if !newlyUnlockedPractices.isEmpty {
            print("🎉 \(newlyUnlockedPractices.count) new practice(s) unlocked!")
            for practice in newlyUnlockedPractices {
                print("   - \(practice.title)")
            }
        }
    }
    
    // MARK: - Clear Newly Unlocked Practices
    func clearNewlyUnlockedPractices() {
        newlyUnlockedPractices.removeAll()
    }
    
    // MARK: - Get Current User's Daily Practice Count
    func getCurrentDailyPracticeCount() async -> Int {
        do {
            guard let userIdString = SupabaseManager.shared.currentUserId,
                  let userId = UUID(uuidString: userIdString) else {
                return 0
            }
            
            return try await practiceService.getTotalDailyPractices(userId: userId)
        } catch {
            print("❌ Failed to get daily practice count: \(error)")
            return 0
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
