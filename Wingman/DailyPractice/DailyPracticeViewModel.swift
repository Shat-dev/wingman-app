//
//  DailyPracticeViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import Foundation
import Combine

/// Owns a run of Daily Practice questions.
///
/// The question-by-question mechanics (selection, checking, forward/back, saved
/// per-question state, first-answer-wins counting) now live in `QuizEngine` so
/// the end-of-lesson quiz shares them rather than reimplementing them. What
/// stays here is everything that is specifically *daily*: fetching today's set,
/// posting each answer to `user_question_completions`, the streak RPC, the
/// completion screen, and the notification Home listens for.
///
/// The engine is a value type held in an `@Published` property, so mutating it
/// republishes and the view re-renders exactly as it did when this class held
/// the state directly. The properties below forward to it so
/// `DailyPracticeView`'s call sites are unchanged.
final class DailyPracticeViewModel: ObservableObject {

    // MARK: - Quiz State (shared engine)
    @Published private(set) var engine = QuizEngine()

    // MARK: - Daily-specific Published Properties
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isDailyPracticeCompleted: Bool = false // Track completion of all questions
    @Published var currentStreak: Int = 0 // Current streak count for completion view
    @Published var showCompletionView: Bool = false // Controls showing the completion view

    // MARK: - Engine Forwarding
    //
    // Kept as properties with the original names so the view layer did not have
    // to change when the state moved into the engine.
    var questions: [QuizQuestion] { engine.questions }
    var currentQuestionIndex: Int { engine.currentQuestionIndex }
    var selectedOptionIndex: Int? { engine.selectedOptionIndex }
    var selectedOptionIndices: Set<Int> { engine.selectedOptionIndices }
    var hasCheckedAnswer: Bool { engine.hasCheckedAnswer }
    var isAnswerCorrect: Bool { engine.isAnswerCorrect }
    var currentQuestion: QuizQuestion { engine.currentQuestion }
    var progress: Double { engine.progress }
    var isCheckAnswerEnabled: Bool { engine.isCheckAnswerEnabled }
    var isLastQuestion: Bool { engine.isLastQuestion }

    /// Everything `QuizQuestionView` needs to render the current question.
    var questionState: QuizQuestionState { engine.questionState }

    var buttonTitle: String {
        hasCheckedAnswer ? "Next" : "Check Answer"
    }

    // MARK: - Dependencies
    private let practiceService: DailyPracticeServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Completion Handler
    var onDailyPracticeCompleted: (() -> Void)?

    // MARK: - Initialization
    init(practiceService: DailyPracticeServiceProtocol = DailyPracticeService()) {
        self.practiceService = practiceService
    }

    // MARK: - Lifecycle Methods
    func loadTodayQuestions() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                let fetchedQuestions = try await practiceService.getTodayQuestions()

                // Resets index, per-question saved state and the answered /
                // correct counters for the new session.
                self.engine.load(questions: fetchedQuestions)
                self.isLoading = false

                log("✅ Loaded \(fetchedQuestions.count) questions for today")

            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                log("❌ Failed to load questions: \(error.localizedDescription)")
            }
        }
    }

    /// Seeds a fixed set without touching the network. Used by the SwiftUI
    /// preview, which previously assigned to `questions` directly.
    func loadForPreview(_ questions: [QuizQuestion]) {
        engine.load(questions: questions)
        isLoading = false
        errorMessage = nil
    }

    // MARK: - User Actions
    func selectOption(at index: Int) {
        engine.selectOption(at: index)
    }

    func checkAnswer() {
        guard !isLoading else { return }

        // The engine grades the answer and hands back what was answered. It
        // returns nil when nothing is selected, which is the same no-op the
        // previous guards produced.
        guard let answer = engine.checkAnswer() else { return }

        // Submit completion to the backend. The question and correctness come
        // from the returned value rather than being re-read from
        // `currentQuestion`, so a fast Next tap cannot make this resolve to the
        // wrong question.
        let selectedAnswers: SelectedAnswers
        if let singleIndex = answer.selectedIndex {
            selectedAnswers = SelectedAnswers(singleSelect: singleIndex)
        } else {
            selectedAnswers = SelectedAnswers(multipleSelect: answer.selectedIndices ?? [])
        }

        let questionId = answer.question.id
        let wasCorrect = answer.isCorrect
        Task { @MainActor in
            await submitCompletion(
                questionId: questionId,
                isCorrect: wasCorrect,
                selectedAnswers: selectedAnswers
            )
        }
    }

    func nextQuestion() {
        switch engine.advance() {
        case .blocked, .moved:
            // Nothing daily-specific to do — the engine already moved, or
            // refused because the answer hasn't been checked.
            break

        case .finished:
            isDailyPracticeCompleted = true
            HapticManager.shared.success()

            // Update daily practice streak in the database. Counts are read
            // here on the main actor and passed in, rather than reaching back
            // into the engine from inside the task.
            log("📊 About to update daily practice streak...")
            let answered = engine.answeredCount
            let correct = engine.correctCount
            Task {
                await updateDailyPracticeStreak(questionsAnswered: answered, correctAnswers: correct)
            }

            // Notify that daily practice is completed - this can trigger practice unlocking checks
            onDailyPracticeCompleted?()

            // Post notification for HomeView to refresh
            NotificationCenter.default.post(name: .dailyPracticeCompleted, object: nil)
        }
    }

    func previousQuestion() {
        engine.goBack()
    }

    func reset() {
        engine.reset()
    }

    // MARK: - Streak Update
    private func updateDailyPracticeStreak(questionsAnswered: Int, correctAnswers: Int) async {
        log("🔄 Updating daily practice streak...")
        log("   - Questions answered: \(questionsAnswered)")
        log("   - Correct answers: \(correctAnswers)")

        // Validate that we have the expected values
        guard questionsAnswered > 0 else {
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
                questionsAnswered: questionsAnswered,
                correctAnswers: correctAnswers
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

    // MARK: - Completion Submission
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

    // MARK: - Helper functions for UI state
    func isOptionSelected(_ index: Int) -> Bool { engine.isOptionSelected(index) }
    func isOptionCorrect(_ index: Int) -> Bool { engine.isOptionCorrect(index) }
    func isOptionIncorrect(_ index: Int) -> Bool { engine.isOptionIncorrect(index) }
    func shouldShowCorrectButNotSelected(_ index: Int) -> Bool { engine.shouldShowCorrectButNotSelected(index) }
}
