//
//  DailyPracticeViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import Foundation
import Combine

final class DailyPracticeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var questions: [DailyPracticeQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var selectedOptionIndex: Int? = nil // For single select
    @Published var selectedOptionIndices: Set<Int> = [] // For multiple select
    @Published var hasCheckedAnswer: Bool = false
    @Published var isAnswerCorrect: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isDailyPracticeCompleted: Bool = false // Track completion of all questions
    @Published var currentStreak: Int = 0 // Current streak count for completion view
    @Published var showCompletionView: Bool = false // Controls showing the completion view
    
    // MARK: - Streak Tracking
    private var totalQuestionsAnswered: Int = 0
    private var totalCorrectAnswers: Int = 0

    // MARK: - Dependencies
    private let practiceService: DailyPracticeServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Completion Handler
    var onDailyPracticeCompleted: (() -> Void)?

    // MARK: - Initialization
    init(practiceService: DailyPracticeServiceProtocol = DailyPracticeService()) {
        self.practiceService = practiceService
    }
    
    // MARK: - Computed Properties
    var currentQuestion: DailyPracticeQuestion {
        guard currentQuestionIndex < questions.count else {
            // Return a dummy question to prevent crashes
            return DailyPracticeQuestion(
                number: 1,
                question: "Loading...",
                options: ["Please wait..."],
                correctAnswerIndex: 0,
                explanation: ""
            )
        }
        return questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0.0 }
        return Double(currentQuestionIndex + 1) / Double(questions.count)
    }
    
    var isCheckAnswerEnabled: Bool {
        if currentQuestion.questionType == .singleSelect {
            return selectedOptionIndex != nil && !hasCheckedAnswer
        } else {
            return !selectedOptionIndices.isEmpty && !hasCheckedAnswer
        }
    }
    
    var buttonTitle: String {
        if hasCheckedAnswer {
            return "Next"
        } else {
            return "Check Answer"
        }
    }
    
    var isLastQuestion: Bool {
        currentQuestionIndex == questions.count - 1
    }
    
    // MARK: - Lifecycle Methods
    func loadTodayQuestions() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            
            // Reset tracking for new session
            totalQuestionsAnswered = 0
            totalCorrectAnswers = 0
            
            do {
                let fetchedQuestions = try await practiceService.getTodayQuestions()
                
                self.questions = fetchedQuestions
                self.currentQuestionIndex = 0
                self.resetQuestion()
                self.isLoading = false
                
                print("✅ Loaded \(fetchedQuestions.count) questions for today")
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("❌ Failed to load questions: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - User Actions
    func selectOption(at index: Int) {
        guard !hasCheckedAnswer else {
            print("⚠️ Cannot select option after checking answer")
            return
        }

        HapticManager.shared.selection()

        if currentQuestion.questionType == .singleSelect {
            print("📌 User selected option \(index): \(currentQuestion.options[index])")
            selectedOptionIndex = index
        } else {
            // Multiple select - toggle selection
            if selectedOptionIndices.contains(index) {
                selectedOptionIndices.remove(index)
                print("📌 User deselected option \(index): \(currentQuestion.options[index])")
            } else {
                selectedOptionIndices.insert(index)
                print("📌 User selected option \(index): \(currentQuestion.options[index])")
            }
            print("📌 Currently selected indices: \(selectedOptionIndices)")
        }
    }
    
    func checkAnswer() {
        guard !isLoading else { return }
        
        if currentQuestion.questionType == .singleSelect {
            guard let selected = selectedOptionIndex else {
                print("❌ No option selected")
                return
            }
            
            hasCheckedAnswer = true
            isAnswerCorrect = (selected == currentQuestion.correctAnswerIndex)

            // Haptic feedback for answer result
            if isAnswerCorrect {
                HapticManager.shared.success()
            } else {
                HapticManager.shared.warning()
            }

            print("\n✅ Answer checked!")
            print("   - Selected: \(currentQuestion.options[selected])")
            print("   - Result: \(isAnswerCorrect ? "CORRECT ✅" : "INCORRECT ❌")")

            // Update streak tracking
            totalQuestionsAnswered += 1
            if isAnswerCorrect {
                totalCorrectAnswers += 1
            }
            
            // Submit completion to backend
            Task { @MainActor in
                await submitCompletion(selectedAnswers: SelectedAnswers(singleSelect: selected))
            }
            
        } else {
            guard !selectedOptionIndices.isEmpty else {
                print("❌ No options selected")
                return
            }
            
            hasCheckedAnswer = true
            let correctSet = Set(currentQuestion.correctAnswerIndices ?? [])
            isAnswerCorrect = (selectedOptionIndices == correctSet)

            // Haptic feedback for answer result
            if isAnswerCorrect {
                HapticManager.shared.success()
            } else {
                HapticManager.shared.warning()
            }

            print("\n✅ Answer checked!")
            print("   - Selected indices: \(selectedOptionIndices)")
            print("   - Correct indices: \(correctSet)")
            print("   - Result: \(isAnswerCorrect ? "CORRECT ✅" : "INCORRECT ❌")")
            
            // Update streak tracking
            totalQuestionsAnswered += 1
            if isAnswerCorrect {
                totalCorrectAnswers += 1
            }
            
            // Submit completion to backend
            Task { @MainActor in
                await submitCompletion(selectedAnswers: SelectedAnswers(multipleSelect: Array(selectedOptionIndices)))
            }
        }
    }
    
    func nextQuestion() {
        guard hasCheckedAnswer else {
            print("⚠️ Must check answer before proceeding")
            return
        }
        
        if currentQuestionIndex < questions.count - 1 {
            print("\n➡️ Moving to next question (\(currentQuestionIndex + 2)/\(questions.count))")
            currentQuestionIndex += 1
            resetQuestion()
        } else {
            print("\n🎉 All questions completed!")
            print("   - Total questions: \(questions.count)")
            print("   - Questions answered: \(totalQuestionsAnswered)")
            print("   - Correct answers: \(totalCorrectAnswers)")
            isDailyPracticeCompleted = true
            HapticManager.shared.success()

            // Update daily practice streak in the database
            print("📊 About to update daily practice streak...")
            Task {
                await updateDailyPracticeStreak()
            }
            
            // Notify that daily practice is completed - this can trigger practice unlocking checks
            onDailyPracticeCompleted?()
            
            // Post notification for HomeView to refresh
            NotificationCenter.default.post(name: .dailyPracticeCompleted, object: nil)
        }
    }
    
    // MARK: - Streak Update
    private func updateDailyPracticeStreak() async {
        print("🔄 Updating daily practice streak...")
        print("   - Questions answered: \(totalQuestionsAnswered)")
        print("   - Correct answers: \(totalCorrectAnswers)")
        
        // Validate that we have the expected values
        guard totalQuestionsAnswered > 0 else {
            print("⚠️ WARNING: No questions answered tracked! This shouldn't happen.")
            print("   - This means the tracking isn't working correctly")
            
            // Show completion view with default streak count
            await MainActor.run {
                currentStreak = 1 // Default if update fails
                showCompletionView = true
            }
            return
        }
        
        do {
            print("📡 Calling practiceService.updateDailyPracticeStreak...")
            let result = try await practiceService.updateDailyPracticeStreak(
                questionsAnswered: totalQuestionsAnswered,
                correctAnswers: totalCorrectAnswers
            )
            
            print("✅ Streak updated successfully:")
            print("   - Current streak: \(result.streak)")
            print("   - Total completed: \(result.completed)")

            // Update UI with the streak result and show completion view
            await MainActor.run {
                currentStreak = result.streak
                showCompletionView = true
                // Push the authoritative post-completion values into the shared
                // store so Profile (and the on-disk cache) reflect them
                // immediately, without waiting for another RPC on next view entry.
                StreakStore.shared.apply(updateResult: result)
            }
            
        } catch let error as DailyPracticeError {
            print("❌ Failed to update streak (DailyPracticeError):")
            print("   - Error: \(error.errorDescription ?? "Unknown error")")
            print("   - Full error: \(error)")
            
            // Show completion view with fallback streak count
            await MainActor.run {
                currentStreak = 1 // Fallback if update fails
                showCompletionView = true
            }
        } catch {
            print("❌ Failed to update streak (Unknown error):")
            print("   - Error type: \(type(of: error))")
            print("   - Description: \(error.localizedDescription)")
            print("   - Full error: \(error)")
            
            // Show completion view with fallback streak count
            await MainActor.run {
                currentStreak = 1 // Fallback if update fails
                showCompletionView = true
            }
        }
    }
    
    func previousQuestion() {
        if currentQuestionIndex > 0 {
            print("\n⬅️ Moving to previous question (\(currentQuestionIndex)/\(questions.count))")
            currentQuestionIndex -= 1
            resetQuestion()
        }
    }
    
    // MARK: - Helper Functions
    private func resetQuestion() {
        selectedOptionIndex = nil
        selectedOptionIndices.removeAll()
        hasCheckedAnswer = false
        isAnswerCorrect = false
        print("🔄 Question state reset")
    }
    
    private func submitCompletion(selectedAnswers: SelectedAnswers) async {
        do {
            let response = try await practiceService.submitCompletion(
                questionId: currentQuestion.id,
                selectedAnswers: selectedAnswers,
                isCorrect: isAnswerCorrect
            )
            
            print("✅ Completion submitted: \(response.message)")
            
        } catch {
            print("❌ Failed to submit completion: \(error.localizedDescription)")
            // Note: We don't show this error to the user as it doesn't affect their experience
        }
    }
    
    func reset() {
        print("🔄 Resetting entire practice session")
        currentQuestionIndex = 0
        resetQuestion()
    }
    
    // MARK: - Helper functions for UI state
    func isOptionSelected(_ index: Int) -> Bool {
        if currentQuestion.questionType == .singleSelect {
            return selectedOptionIndex == index
        } else {
            return selectedOptionIndices.contains(index)
        }
    }
    
    func isOptionCorrect(_ index: Int) -> Bool {
        guard hasCheckedAnswer else { return false }
        
        if currentQuestion.questionType == .singleSelect {
            return index == currentQuestion.correctAnswerIndex
        } else {
            return currentQuestion.correctAnswerIndices?.contains(index) ?? false
        }
    }
    
    func isOptionIncorrect(_ index: Int) -> Bool {
        guard hasCheckedAnswer else { return false }
        
        if currentQuestion.questionType == .singleSelect {
            return selectedOptionIndex == index && !isAnswerCorrect
        } else {
            return selectedOptionIndices.contains(index) &&
                   !(currentQuestion.correctAnswerIndices?.contains(index) ?? false)
        }
    }
    
    func shouldShowCorrectButNotSelected(_ index: Int) -> Bool {
        guard hasCheckedAnswer && currentQuestion.questionType == .multipleSelect else { return false }
        
        return (currentQuestion.correctAnswerIndices?.contains(index) ?? false) &&
               !selectedOptionIndices.contains(index)
    }
}
