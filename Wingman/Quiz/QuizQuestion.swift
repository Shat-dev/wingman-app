//
//  QuizQuestion.swift
//  Wingman
//

import Foundation

enum QuestionType: String, Codable, CaseIterable {
    case singleSelect = "single_select"
    case multipleSelect = "multiple_select"
}

/// One multiple-choice question, whatever surface it is being asked on.
///
/// Formerly `DailyPracticeQuestion`. Renamed rather than copied because the
/// end-of-lesson quiz reads from the same `public.questions` table as Daily
/// Practice — lesson questions were generated from the lesson prose and already
/// live there, tagged with `lesson_id` / `lesson_quiz_order`. Identical rows in,
/// identical model out, so one type serves both and there is nothing to keep in
/// sync.
///
/// `id` stays a `UUID` because it is the primary key of that table. Daily
/// Practice needs it for the `user_question_completions` foreign key; the
/// lesson quiz needs it to record a missed question for later review.
struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    let number: Int
    let question: String
    let options: [String]
    let questionType: QuestionType
    let correctAnswerIndex: Int?      // For single select
    let correctAnswerIndices: [Int]?  // For multiple select
    let explanation: String

    // Single select initializer
    init(number: Int, question: String, options: [String], correctAnswerIndex: Int, explanation: String) {
        self.id = UUID()
        self.number = number
        self.question = question
        self.options = options
        self.questionType = .singleSelect
        self.correctAnswerIndex = correctAnswerIndex
        self.correctAnswerIndices = nil
        self.explanation = explanation
    }

    // Multiple select initializer
    init(number: Int, question: String, options: [String], correctAnswerIndices: [Int], explanation: String) {
        self.id = UUID()
        self.number = number
        self.question = question
        self.options = options
        self.questionType = .multipleSelect
        self.correctAnswerIndex = nil
        self.correctAnswerIndices = correctAnswerIndices
        self.explanation = explanation
    }

    // Full initializer for Supabase
    init(id: UUID, number: Int, question: String, options: [String], questionType: QuestionType, correctAnswerIndex: Int?, correctAnswerIndices: [Int]?, explanation: String) {
        self.id = id
        self.number = number
        self.question = question
        self.options = options
        self.questionType = questionType
        self.correctAnswerIndex = correctAnswerIndex
        self.correctAnswerIndices = correctAnswerIndices
        self.explanation = explanation
    }
}

/// The outcome of checking one answer, handed back to whoever owns the run.
///
/// `QuizEngine.checkAnswer()` returns this synchronously so the owner records
/// the answer against the question that was actually on screen. The previous
/// code captured `questionId` and `isCorrect` into local constants before
/// launching its submission `Task` for exactly this reason — `currentQuestion`
/// is computed from `currentQuestionIndex`, so reading it inside an async block
/// after a fast "Next" tap resolves to the wrong question. Returning the answer
/// removes the hazard rather than working around it.
struct QuizAnswer {
    let question: QuizQuestion
    let isCorrect: Bool

    /// Set for single-select questions.
    let selectedIndex: Int?

    /// Set for multiple-select questions.
    let selectedIndices: [Int]?
}
