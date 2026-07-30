//
//  QuizEngine.swift
//  Wingman
//

import Foundation

/// The question-by-question state machine behind a run of quiz questions:
/// selection, checking, moving forward and back, and the per-question state
/// that makes back-navigation non-destructive.
///
/// Lifted from `DailyPracticeViewModel` so the end-of-lesson quiz doesn't
/// reimplement answer checking. Everything specific to Daily Practice — loading
/// today's set, posting completions, the streak RPC, the completion screen —
/// stays in that view model. The engine knows nothing about networks, streaks
/// or notifications.
///
/// **This is a struct, not an `ObservableObject`, on purpose.** A nested
/// observable object does not forward `objectWillChange` to its parent, so a
/// class here would leave `DailyPracticeView` silently not re-rendering when an
/// option is tapped. As a value type held in an `@Published` property (or
/// `@State`), every mutation republishes for free.
struct QuizEngine {

    // MARK: - Per-question saved state
    //
    // Preserves answer state across back/forward navigation so a user can
    // review a previous question without being able to re-answer it.
    private struct SavedQuestionState {
        let selectedOptionIndex: Int?
        let selectedOptionIndices: Set<Int>
        let hasCheckedAnswer: Bool
        let isAnswerCorrect: Bool
    }

    /// What `advance()` did, so the owner can react without guessing.
    enum AdvanceOutcome {
        /// The current answer hasn't been checked yet — nothing moved.
        case blocked
        /// Moved on to the next question.
        case moved
        /// That was the last question; the run is over.
        case finished
    }

    // MARK: - State

    private(set) var questions: [QuizQuestion]
    private(set) var currentQuestionIndex: Int = 0
    private(set) var selectedOptionIndex: Int?          // single select
    private(set) var selectedOptionIndices: Set<Int> = [] // multiple select
    private(set) var hasCheckedAnswer: Bool = false
    private(set) var isAnswerCorrect: Bool = false

    /// Distinct questions answered this run, and how many were right.
    ///
    /// First-answer-wins: `countedQuestionIds` stops back-navigating and
    /// re-answering from inflating these. Daily Practice sends them to the
    /// streak RPC, so an inflated count is a wrong streak — silent, and noticed
    /// days later. This dedup is carried across unchanged.
    private(set) var answeredCount: Int = 0
    private(set) var correctCount: Int = 0
    private var countedQuestionIds: Set<UUID> = []

    private var questionStates: [UUID: SavedQuestionState] = [:]

    /// Correct answers needed to pass. `0` means "answering them all is enough",
    /// which is what both surfaces ship with — Daily Practice has never had a
    /// pass mark, and the lesson quiz is completion-gated in v1. Present so
    /// turning on a threshold later is a value change rather than a refactor.
    let passThreshold: Int

    // MARK: - Init

    init(questions: [QuizQuestion] = [], passThreshold: Int = 0) {
        self.questions = questions
        self.passThreshold = passThreshold
    }

    // MARK: - Computed

    var currentQuestion: QuizQuestion {
        guard currentQuestionIndex < questions.count else {
            // Placeholder to prevent crashes before the first load resolves.
            return QuizQuestion(
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

    var isLastQuestion: Bool {
        currentQuestionIndex == questions.count - 1
    }

    var didPass: Bool {
        correctCount >= passThreshold
    }

    /// Bridge to `QuizQuestionView`. Lives here rather than at each call site so
    /// the two-representations-to-index-sets collapse exists once.
    var questionState: QuizQuestionState {
        let question = currentQuestion
        let isMultipleSelect = question.questionType == .multipleSelect

        let selected: Set<Int> = isMultipleSelect
            ? selectedOptionIndices
            : Set([selectedOptionIndex].compactMap { $0 })

        let correct: Set<Int> = isMultipleSelect
            ? Set(question.correctAnswerIndices ?? [])
            : Set([question.correctAnswerIndex].compactMap { $0 })

        return QuizQuestionState(
            number: question.number,
            text: question.question,
            options: question.options,
            isMultipleSelect: isMultipleSelect,
            selectedIndices: selected,
            correctIndices: correct,
            hasCheckedAnswer: hasCheckedAnswer,
            isAnswerCorrect: isAnswerCorrect,
            explanation: question.explanation
        )
    }

    // MARK: - Loading

    /// Replaces the question set and resets every per-run counter.
    mutating func load(questions: [QuizQuestion]) {
        self.questions = questions
        currentQuestionIndex = 0
        answeredCount = 0
        correctCount = 0
        countedQuestionIds = []
        questionStates = [:]
        resetCurrentQuestion()
    }

    // MARK: - User actions

    mutating func selectOption(at index: Int) {
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

    /// Grades the current answer. Returns what was answered so the owner can
    /// record it, or `nil` if nothing was selected.
    ///
    /// The correct/incorrect haptics fire here rather than at the call site:
    /// they are feedback on the outcome, identical on every surface, and easy to
    /// forget when wiring up a new one. Haptics that belong to a *tap* (the
    /// impact on the Check Answer button) stay with the view's caller.
    mutating func checkAnswer() -> QuizAnswer? {
        if currentQuestion.questionType == .singleSelect {
            guard let selected = selectedOptionIndex else {
                log("❌ No option selected")
                return nil
            }

            hasCheckedAnswer = true
            isAnswerCorrect = (selected == currentQuestion.correctAnswerIndex)

            if isAnswerCorrect {
                HapticManager.shared.success()
            } else {
                HapticManager.shared.warning()
            }

            log("\n✅ Answer checked!")
            log("   - Selected: \(currentQuestion.options[selected])")
            log("   - Result: \(isAnswerCorrect ? "CORRECT ✅" : "INCORRECT ❌")")

            recordAnswer()

            return QuizAnswer(
                question: currentQuestion,
                isCorrect: isAnswerCorrect,
                selectedIndex: selected,
                selectedIndices: nil
            )

        } else {
            guard !selectedOptionIndices.isEmpty else {
                log("❌ No options selected")
                return nil
            }

            hasCheckedAnswer = true
            let correctSet = Set(currentQuestion.correctAnswerIndices ?? [])
            isAnswerCorrect = (selectedOptionIndices == correctSet)

            if isAnswerCorrect {
                HapticManager.shared.success()
            } else {
                HapticManager.shared.warning()
            }

            log("\n✅ Answer checked!")
            log("   - Selected indices: \(selectedOptionIndices)")
            log("   - Correct indices: \(correctSet)")
            log("   - Result: \(isAnswerCorrect ? "CORRECT ✅" : "INCORRECT ❌")")

            recordAnswer()

            return QuizAnswer(
                question: currentQuestion,
                isCorrect: isAnswerCorrect,
                selectedIndex: nil,
                selectedIndices: Array(selectedOptionIndices)
            )
        }
    }

    /// Moves to the next question, or reports that the run is over.
    mutating func advance() -> AdvanceOutcome {
        guard hasCheckedAnswer else {
            log("⚠️ Must check answer before proceeding")
            return .blocked
        }

        if currentQuestionIndex < questions.count - 1 {
            log("\n➡️ Moving to next question (\(currentQuestionIndex + 2)/\(questions.count))")
            saveCurrentQuestionState()
            currentQuestionIndex += 1
            loadQuestionState(for: questions[currentQuestionIndex].id)
            return .moved
        } else {
            log("\n🎉 All questions completed!")
            log("   - Total questions: \(questions.count)")
            log("   - Questions answered: \(answeredCount)")
            log("   - Correct answers: \(correctCount)")
            return .finished
        }
    }

    mutating func goBack() {
        if currentQuestionIndex > 0 {
            log("\n⬅️ Moving to previous question (\(currentQuestionIndex)/\(questions.count))")
            saveCurrentQuestionState()
            currentQuestionIndex -= 1
            loadQuestionState(for: questions[currentQuestionIndex].id)
        }
    }

    /// Returns to the first question, discarding saved per-question state but
    /// deliberately **not** the answered/correct counters — matching the
    /// previous `DailyPracticeViewModel.reset()` exactly.
    mutating func reset() {
        log("🔄 Resetting entire practice session")
        currentQuestionIndex = 0
        questionStates = [:]
        resetCurrentQuestion()
    }

    // MARK: - Per-option display state

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

    // MARK: - Private helpers

    /// First-answer-wins. Re-checking a question reached via `goBack()` must not
    /// count twice.
    private mutating func recordAnswer() {
        if countedQuestionIds.insert(currentQuestion.id).inserted {
            answeredCount += 1
            if isAnswerCorrect {
                correctCount += 1
            }
        }
    }

    private mutating func resetCurrentQuestion() {
        selectedOptionIndex = nil
        selectedOptionIndices.removeAll()
        hasCheckedAnswer = false
        isAnswerCorrect = false
        log("🔄 Question state reset")
    }

    private mutating func saveCurrentQuestionState() {
        guard currentQuestionIndex < questions.count else { return }
        let id = questions[currentQuestionIndex].id
        questionStates[id] = SavedQuestionState(
            selectedOptionIndex: selectedOptionIndex,
            selectedOptionIndices: selectedOptionIndices,
            hasCheckedAnswer: hasCheckedAnswer,
            isAnswerCorrect: isAnswerCorrect
        )
    }

    private mutating func loadQuestionState(for id: UUID) {
        if let saved = questionStates[id] {
            selectedOptionIndex = saved.selectedOptionIndex
            selectedOptionIndices = saved.selectedOptionIndices
            hasCheckedAnswer = saved.hasCheckedAnswer
            isAnswerCorrect = saved.isAnswerCorrect
            log("🔁 Restored saved state for question \(id)")
        } else {
            resetCurrentQuestion()
        }
    }
}
