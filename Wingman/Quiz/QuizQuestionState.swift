//
//  QuizQuestionState.swift
//  Wingman
//

import Foundation

/// Everything `QuizQuestionView` needs to render one question, as plain values.
///
/// Deliberately a value type holding no reference to any view model. Daily
/// Practice builds one from `DailyPracticeViewModel`; the end-of-lesson quiz
/// will build one from its own source. Neither needs to know the other exists,
/// which is the whole point of the extraction — the option buttons, colour
/// rules and explanation panel stop being private to `DailyPracticeView`.
///
/// Single- and multiple-select collapse onto index *sets* here. The two paths
/// in `DailyPracticeViewModel` (`selectedOptionIndex: Int?` for single,
/// `selectedOptionIndices: Set<Int>` for multi) produce identical rendering
/// once a single selection is expressed as a one-element set. Each helper below
/// notes why it is equivalent to the branch it replaces — those equivalences
/// are the correctness argument for this refactor, so they are worth keeping
/// written down rather than rediscovering from the diff.
struct QuizQuestionState {

    let number: Int
    let text: String
    let options: [String]
    let isMultipleSelect: Bool

    /// Indices the user has picked. For single-select this holds 0 or 1 entries.
    let selectedIndices: Set<Int>

    /// Indices that are actually correct, regardless of what was picked.
    let correctIndices: Set<Int>

    let hasCheckedAnswer: Bool
    let isAnswerCorrect: Bool
    let explanation: String

    // MARK: - Per-option display state

    /// Equivalent to `DailyPracticeViewModel.isOptionSelected`.
    func isSelected(_ index: Int) -> Bool {
        selectedIndices.contains(index)
    }

    /// Equivalent to `DailyPracticeViewModel.isOptionCorrect`: once checked, the
    /// correct option is highlighted whether or not the user picked it.
    func isCorrect(_ index: Int) -> Bool {
        hasCheckedAnswer && correctIndices.contains(index)
    }

    /// Equivalent to `DailyPracticeViewModel.isOptionIncorrect`.
    ///
    /// The original single-select branch reads
    /// `selectedOptionIndex == index && !isAnswerCorrect`. With exactly one
    /// selected index that is the same as "selected but not correct": if the
    /// picked index were the correct one then `isAnswerCorrect` would be true,
    /// and an index that was never picked fails the first clause either way.
    func isIncorrect(_ index: Int) -> Bool {
        hasCheckedAnswer
            && selectedIndices.contains(index)
            && !correctIndices.contains(index)
    }

    /// Equivalent to `DailyPracticeViewModel.shouldShowCorrectButNotSelected`.
    /// Multiple-select only — it renders a correct answer the user missed as an
    /// empty checkbox rather than a tick.
    func showsCorrectButNotSelected(_ index: Int) -> Bool {
        hasCheckedAnswer
            && isMultipleSelect
            && correctIndices.contains(index)
            && !selectedIndices.contains(index)
    }

    // MARK: - Derived

    /// Equivalent to `DailyPracticeViewModel.isCheckAnswerEnabled` for both
    /// question types: single-select's `selectedOptionIndex != nil` is the same
    /// as a non-empty one-element set.
    var isCheckAnswerEnabled: Bool {
        !selectedIndices.isEmpty && !hasCheckedAnswer
    }
}
