//
//  PracticeDetailViewModel.swift
//  Wingman
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class PracticeDetailViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var practiceDetail: PracticeDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasUnlockedNewPractices: Bool = false // Track if new practices were unlocked

    // MARK: - Properties
    let practice: Practice

    // MARK: - Dependencies
    private let practiceService: PracticeServiceProtocol

    // MARK: - Init
    init(
        practice: Practice,
        practiceService: PracticeServiceProtocol = PracticeService()
    ) {
        self.practice = practice
        self.practiceService = practiceService
    }

    // MARK: - Fetch Practice Detail from DB
    func fetchPracticeDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            practiceDetail = try await practiceService.fetchPracticeDetail(practiceId: practice.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Start Practice
    func startPractice() {
        // Navigation is handled in the parent view via PracticeView
    }

    // MARK: - Mark Practice Complete with Unlocking Logic
    func markPracticeComplete(userId: UUID) async {
        do {
            try await practiceService.completePractice(practiceId: practice.id, userId: userId)
            
            // Check if completing this practice unlocks new ones
            await checkForNewlyUnlockedPractices(userId: userId)
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Check for Newly Unlocked Practices
    private func checkForNewlyUnlockedPractices(userId: UUID) async {
        do {
            // Get updated total daily practices count
            let totalCompleted = try await practiceService.getTotalDailyPractices(userId: userId)
            
            // Fetch all practices to see which ones should be unlocked
            let allPractices = try await practiceService.fetchPractices()
            
            // Check if any practices that were locked are now unlocked
            let newlyUnlocked = allPractices.filter { practice in
                return !practice.isLocked && practice.requiredDailyPractices <= totalCompleted
            }
            
            // If there are newly unlocked practices, set the flag
            hasUnlockedNewPractices = newlyUnlocked.count > 0
            
            if hasUnlockedNewPractices {
                print("🔓 \(newlyUnlocked.count) new practice(s) unlocked!")
                for practice in newlyUnlocked {
                    print("   - \(practice.title) (required: \(practice.requiredDailyPractices))")
                }
            }
            
        } catch {
            print("❌ Failed to check for newly unlocked practices: \(error)")
            // Don't set error message as this is not critical for user experience
        }
    }
    
    // MARK: - Get Current Daily Practice Count
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
    
    // MARK: - Check if Practice Should Be Unlocked
    func checkIfShouldBeUnlocked() async -> Bool {
        let currentCount = await getCurrentDailyPracticeCount()
        return currentCount >= practice.requiredDailyPractices
    }
    
    // MARK: - Reset Unlock Status
    func resetUnlockStatus() {
        hasUnlockedNewPractices = false
    }
}

// MARK: - Preview Helper
extension PracticeDetailViewModel {
    static func preview(practice: Practice = Practice.mockData[0]) -> PracticeDetailViewModel {
        let vm = PracticeDetailViewModel(
            practice: practice,
            practiceService: MockPracticeService()
        )
        vm.practiceDetail = PracticeDetail(
            id: UUID(),
            practiceId: practice.id,
            content: "This practice helps you understand that you are not your thoughts. Learn to observe your mental patterns without attachment and discover the space of awareness that exists beyond thinking.",
            videoUrl: nil,
            audioUrl: nil,
            duration: 15,
            steps: [
                PracticeStep(id: UUID(), title: "Find a Quiet Space", description: "Choose a comfortable, quiet location where you won't be disturbed.", order: 1),
                PracticeStep(id: UUID(), title: "Close Your Eyes", description: "Gently close your eyes and take three deep breaths to center yourself.", order: 2),
                PracticeStep(id: UUID(), title: "Observe Your Thoughts", description: "Notice thoughts as they arise without judging or engaging with them.", order: 3)
            ]
        )
        return vm
    }
}
