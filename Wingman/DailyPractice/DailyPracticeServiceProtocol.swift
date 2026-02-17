//
//  DailyPracticeService.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import Foundation
import Supabase

// MARK: - Service Protocol
protocol DailyPracticeServiceProtocol {
    func getTodayQuestions() async throws -> [DailyPracticeQuestion]
    func submitCompletion(questionId: UUID, selectedAnswers: SelectedAnswers, isCorrect: Bool) async throws -> CompletionResponse
}

// MARK: - Supabase Models (matching your database schema)
struct SupabaseQuestion: Codable {
    let questionId: UUID
    let questionNumber: Int
    let module: String
    let questionType: String
    let questionText: String
    let options: [String]
    let correctAnswerIndex: Int?
    let correctAnswerIndices: [Int]?
    let explanation: String
    
    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case questionNumber = "question_number"
        case module
        case questionType = "question_type"
        case questionText = "question_text"
        case options
        case correctAnswerIndex = "correct_answer_index"
        case correctAnswerIndices = "correct_answer_indices"
        case explanation
    }
}

struct UserQuestionCompletion: Codable {
    let userId: String
    let questionId: String
    let selectedAnswers: SelectedAnswers
    let isCorrect: Bool
    let completedAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case questionId = "question_id"
        case selectedAnswers = "selected_answers"
        case isCorrect = "is_correct"
        case completedAt = "completed_at"
    }
}

// MARK: - Supabase Service Implementation
class DailyPracticeService: DailyPracticeServiceProtocol {
    
    private var supabaseClient: SupabaseClient {
        return SupabaseManager.shared.client
    }
    
    func getTodayQuestions() async throws -> [DailyPracticeQuestion] {
        do {
            // Get current user ID from your existing manager
            guard let userIdString = SupabaseManager.shared.currentUserId else {
                throw DailyPracticeError.notAuthenticated
            }
            
            // Get today's date in user's timezone
            let todayDate = getCurrentLocalDate()
            
            print("🔄 Fetching daily questions for user: \(userIdString), date: \(todayDate)")
            
            // Call the database function that handles all the daily generation logic
            let supabaseQuestions: [SupabaseQuestion] = try await supabaseClient
                .rpc("get_or_create_daily_questions", params: [
                    "p_user_id": userIdString,
                    "p_date": todayDate
                ])
                .execute()
                .value
            
            // Convert Supabase models to your app models
            let questions = supabaseQuestions.map { supabaseQ -> DailyPracticeQuestion in
                let questionType: QuestionType = supabaseQ.questionType == "single_select" ? .singleSelect : .multipleSelect
                
                return DailyPracticeQuestion(
                    id: supabaseQ.questionId,
                    number: supabaseQ.questionNumber,
                    question: supabaseQ.questionText,
                    options: supabaseQ.options,
                    questionType: questionType,
                    correctAnswerIndex: supabaseQ.correctAnswerIndex,
                    correctAnswerIndices: supabaseQ.correctAnswerIndices,
                    explanation: supabaseQ.explanation
                )
            }
            
            print("✅ Loaded \(questions.count) questions from Supabase for date: \(todayDate)")
            return questions
            
        } catch {
            print("❌ Failed to load questions from Supabase: \(error)")
            throw DailyPracticeError.failedToFetchQuestions(error.localizedDescription)
        }
    }
    
    func submitCompletion(questionId: UUID, selectedAnswers: SelectedAnswers, isCorrect: Bool) async throws -> CompletionResponse {
        do {
            // Get current user ID from your existing manager
            guard let userIdString = SupabaseManager.shared.currentUserId else {
                throw DailyPracticeError.notAuthenticated
            }
            
            print("🔄 Submitting completion for question: \(questionId), user: \(userIdString)")
            
            // Create completion record
            let completion = UserQuestionCompletion(
                userId: userIdString,
                questionId: questionId.uuidString,
                selectedAnswers: selectedAnswers,
                isCorrect: isCorrect,
                completedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            // Insert into database
            try await supabaseClient
                .from("user_question_completions")
                .insert(completion)
                .execute()
            
            print("✅ Completion submitted to Supabase for question: \(questionId)")
            
            return CompletionResponse(
                success: true,
                message: isCorrect ? "Correct answer!" : "Incorrect answer.",
                isCorrect: isCorrect
            )
            
        } catch {
            print("❌ Failed to submit completion to Supabase: \(error)")
            throw DailyPracticeError.failedToSubmitCompletion(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentLocalDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
}

// MARK: - Error Handling
enum DailyPracticeError: LocalizedError {
    case notAuthenticated
    case failedToFetchQuestions(String)
    case failedToSubmitCompletion(String)
    case invalidQuestionData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated. Please log in to access daily practice questions."
        case .failedToFetchQuestions(let message):
            return "Failed to fetch daily questions: \(message)"
        case .failedToSubmitCompletion(let message):
            return "Failed to submit completion: \(message)"
        case .invalidQuestionData:
            return "Invalid question data received"
        }
    }
}
