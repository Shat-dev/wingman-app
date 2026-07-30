//
//  LessonQuestionService.swift
//  Wingman
//

import Foundation
import Supabase

// MARK: - Wire model

/// One row of `public.questions` that has been tagged to a lesson.
///
/// The same table Daily Practice draws from — lesson questions were generated
/// from the lesson prose and already live there, marked with `lesson_id` and a
/// `lesson_quiz_order` of 1…n. Untagged rows, and tagged rows with a null
/// `lesson_quiz_order`, stay Daily Practice-only.
struct LessonQuestionRow: Decodable {
    let id: UUID
    let lessonId: String
    let lessonQuizOrder: Int
    let questionType: String
    let questionText: String
    let options: [String]
    let correctAnswerIndex: Int?
    let correctAnswerIndices: [Int]?
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case lessonQuizOrder = "lesson_quiz_order"
        case questionType = "question_type"
        case questionText = "question_text"
        case options
        case correctAnswerIndex = "correct_answer_index"
        case correctAnswerIndices = "correct_answer_indices"
        case explanation
    }

    /// `number` is the quiz slot, so questions render "1.", "2.", "3." in the
    /// order they were curated.
    var asQuizQuestion: QuizQuestion {
        QuizQuestion(
            id: id,
            number: lessonQuizOrder,
            question: questionText,
            options: options,
            questionType: questionType == "multiple_select" ? .multipleSelect : .singleSelect,
            correctAnswerIndex: correctAnswerIndex,
            correctAnswerIndices: correctAnswerIndices,
            explanation: explanation
        )
    }
}

/// Decoded as a `String`, not a `Date`, on purpose. The watermark only ever
/// answers "has anything changed since last sync?", so an exact-match compare
/// is enough — and it can't be broken by a date-decoding strategy mismatch.
/// A failure there would be caught by `refresh()`'s catch, leaving the quiz
/// silently never syncing, which is the worst kind of bug to ship.
private struct UpdatedAtRow: Decodable {
    let updatedAt: String
    enum CodingKeys: String, CodingKey { case updatedAt = "updated_at" }
}

/// Append-only record of a lesson-quiz answer.
///
/// Deliberately **not** `user_question_completions`. That table feeds
/// `get_excluded_question_ids()`, which removes anything answered in the last
/// 90 days from the Daily Practice draw — writing a wrong lesson answer there
/// would ban the question for 90 days, the opposite of resurfacing it for
/// review. It would also trip the client-side `count >= 5` check that decides
/// whether today's Daily Practice is already done.
private struct LessonQuizAnswerRow: Encodable {
    let userId: String
    let questionId: String
    let lessonId: String
    let isCorrect: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case questionId = "question_id"
        case lessonId = "lesson_id"
        case isCorrect = "is_correct"
    }
}

// MARK: - Service

protocol LessonQuestionServiceProtocol {
    /// Every question tagged to a lesson and assigned a quiz slot.
    func fetchAllLessonQuestions() async throws -> [LessonQuestionRow]

    /// The newest `updated_at` across those rows, used as a sync watermark.
    func latestUpdatedAt() async throws -> String?

    /// Fire-and-forget record of one answered lesson-quiz question.
    func recordAnswer(questionId: UUID, lessonId: String, isCorrect: Bool) async throws
}

final class LessonQuestionService: LessonQuestionServiceProtocol {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    private static let columns = """
    id, lesson_id, lesson_quiz_order, question_type, question_text, \
    options, correct_answer_index, correct_answer_indices, explanation
    """

    func fetchAllLessonQuestions() async throws -> [LessonQuestionRow] {
        try await client
            .from("questions")
            .select(Self.columns)
            .not("lesson_id", operator: .is, value: "null")
            .not("lesson_quiz_order", operator: .is, value: "null")
            .order("lesson_id", ascending: true)
            .order("lesson_quiz_order", ascending: true)
            .execute()
            .value
    }

    func latestUpdatedAt() async throws -> String? {
        let rows: [UpdatedAtRow] = try await client
            .from("questions")
            .select("updated_at")
            .not("lesson_quiz_order", operator: .is, value: "null")
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first?.updatedAt
    }

    func recordAnswer(questionId: UUID, lessonId: String, isCorrect: Bool) async throws {
        guard let userId = SupabaseManager.shared.currentUserId else { return }

        try await client
            .from("user_lesson_quiz_answers")
            .insert(LessonQuizAnswerRow(
                userId: userId,
                questionId: questionId.uuidString,
                lessonId: lessonId,
                isCorrect: isCorrect
            ))
            .execute()
    }
}
