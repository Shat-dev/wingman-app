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
    // First-answer-wins dedup set keyed by question id. Without this,
    // previousQuestion() lets a user re-answer a prior question and double-
    // count it into the streak-update RPC. Reset per session in loadTodayQuestions.
    private var countedQuestionIds: Set<UUID> = []

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
            countedQuestionIds = []
            
            do {
                let fetchedQuestions = try await practiceService.getTodayQuestions()
                
                self.questions = fetchedQuestions
                self.currentQuestionIndex = 0
                self.resetQuestion()
                self.isLoading = false
                
                log("✅ Loaded \(fetchedQuestions.count) questions for today")
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                log("❌ Failed to load questions: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - User Actions
    func selectOption(at index: Int) {
        guard !hasCheckedAnswer else {
            log("⚠️ Cannot select option after checking answer")
            return
        }

        HapticManager.shared.selection()

        if currentQuestion.questionType == .singleSelect {
            log("📌 User selected option \(index): \(currentQuestion.options[index])")
            selectedOptionIndex = index
        } else {
            // Multiple select - toggle selection
            if selectedOptionIndices.contains(index) {
                selectedOptionIndices.remove(index)
                log("📌 User deselected option \(index): \(currentQuestion.options[index])")
            } else {
                selectedOptionIndices.insert(index)
                log("📌 User selected option \(index): \(currentQuestion.options[index])")
            }
            log("📌 Currently selected indices: \(selectedOptionIndices)")
        }
    }
    
    func checkAnswer() {
        guard !isLoading else { return }
        
        if currentQuestion.questionType == .singleSelect {
            guard let selected = selectedOptionIndex else {
                log("❌ No option selected")
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

            log("\n✅ Answer checked!")
            log("   - Selected: \(currentQuestion.options[selected])")
            log("   - Result: \(isAnswerCorrect ? "CORRECT ✅" : "INCORRECT ❌")")

            // Update streak tracking — first-answer-wins per question so
            // back-nav + re-answer can't inflate the counts we send to the
            // streak RPC.
            let questionId = currentQuestion.id
            if countedQuestionIds.insert(questionId).inserted {
                totalQuestionsAnswered += 1
                if isAnswerCorrect {
                    totalCorrectAnswers += 1
                }
            }

            // Submit completion to backend. Capture questionId/isCorrect
            // synchronously here — `currentQuestion` is a computed property
            // over `currentQuestionIndex`, so reading it inside the Task
            // after a rapid Next-tap would resolve to the wrong question.
            let wasCorrect = isAnswerCorrect
            Task { @MainActor in
                await submitCompletion(
                    questionId: questionId,
                    isCorrect: wasCorrect,
                    selectedAnswers: SelectedAnswers(singleSelect: selected)
                )
            }

        } else {
            guard !selectedOptionIndices.isEmpty else {
                log("❌ No options selected")
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

            log("\n✅ Answer checked!")
            log("   - Selected indices: \(selectedOptionIndices)")
            log("   - Correct indices: \(correctSet)")
            log("   - Result: \(isAnswerCorrect ? "CORRECT ✅" : "INCORRECT ❌")")

            // Update streak tracking — first-answer-wins per question so
            // back-nav + re-answer can't inflate the counts we send to the
            // streak RPC.
            let questionId = currentQuestion.id
            if countedQuestionIds.insert(questionId).inserted {
                totalQuestionsAnswered += 1
                if isAnswerCorrect {
                    totalCorrectAnswers += 1
                }
            }

            // Submit completion to backend. Capture questionId/isCorrect
            // synchronously here — `currentQuestion` is a computed property
            // over `currentQuestionIndex`, so reading it inside the Task
            // after a rapid Next-tap would resolve to the wrong question.
            let wasCorrect = isAnswerCorrect
            let selectedMulti = Array(selectedOptionIndices)
            Task { @MainActor in
                await submitCompletion(
                    questionId: questionId,
                    isCorrect: wasCorrect,
                    selectedAnswers: SelectedAnswers(multipleSelect: selectedMulti)
                )
            }
        }
    }
    
    func nextQuestion() {
        guard hasCheckedAnswer else {
            log("⚠️ Must check answer before proceeding")
            return
        }
        
        if currentQuestionIndex < questions.count - 1 {
            log("\n➡️ Moving to next question (\(currentQuestionIndex + 2)/\(questions.count))")
            currentQuestionIndex += 1
            resetQuestion()
        } else {
            log("\n🎉 All questions completed!")
            log("   - Total questions: \(questions.count)")
            log("   - Questions answered: \(totalQuestionsAnswered)")
            log("   - Correct answers: \(totalCorrectAnswers)")
            isDailyPracticeCompleted = true
            HapticManager.shared.success()

            // Update daily practice streak in the database
            log("📊 About to update daily practice streak...")
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
        log("🔄 Updating daily practice streak...")
        log("   - Questions answered: \(totalQuestionsAnswered)")
        log("   - Correct answers: \(totalCorrectAnswers)")
        
        // Validate that we have the expected values
        guard totalQuestionsAnswered > 0 else {
            log("⚠️ WARNING: No questions answered tracked! This shouldn't happen.")
            log("   - This means the tracking isn't working correctly")
            
            // Show completion view with default streak count
            await MainActor.run {
                currentStreak = 1 // Default if update fails
                showCompletionView = true
            }
            return
        }
        
        do {
            log("📡 Calling practiceService.updateDailyPracticeStreak...")
            let result = try await practiceService.updateDailyPracticeStreak(
                questionsAnswered: totalQuestionsAnswered,
                correctAnswers: totalCorrectAnswers
            )
            
            log("✅ Streak updated successfully:")
            log("   - Current streak: \(result.streak)")
            log("   - Total completed: \(result.completed)")

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
            log("❌ Failed to update streak (DailyPracticeError):")
            log("   - Error: \(error.errorDescription ?? "Unknown error")")
            log("   - Full error: \(error)")
            
            // Show completion view with fallback streak count
            await MainActor.run {
                currentStreak = 1 // Fallback if update fails
                showCompletionView = true
            }
        } catch {
            log("❌ Failed to update streak (Unknown error):")
            log("   - Error type: \(type(of: error))")
            log("   - Description: \(error.localizedDescription)")
            log("   - Full error: \(error)")
            
            // Show completion view with fallback streak count
            await MainActor.run {
                currentStreak = 1 // Fallback if update fails
                showCompletionView = true
            }
        }
    }
    
    func previousQuestion() {
        if currentQuestionIndex > 0 {
            log("\n⬅️ Moving to previous question (\(currentQuestionIndex)/\(questions.count))")
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
        log("🔄 Question state reset")
    }
    
    private func submitCompletion(questionId: UUID, isCorrect: Bool, selectedAnswers: SelectedAnswers) async {
        do {
            let response = try await practiceService.submitCompletion(
                questionId: questionId,
                selectedAnswers: selectedAnswers,
                isCorrect: isCorrect
            )

            log("✅ Completion submitted: \(response.message)")

        } catch {
            log("❌ Failed to submit completion: \(error.localizedDescription)")
            // Note: We don't show this error to the user as it doesn't affect their experience
        }
    }
    
    func reset() {
        log("🔄 Resetting entire practice session")
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
