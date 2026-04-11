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
    func isTodaysPracticeCompleted() async throws -> Bool
    func getDailyPracticeStatus() async throws -> DailyPracticeStatus
    func updateDailyPracticeStreak(questionsAnswered: Int, correctAnswers: Int) async throws -> StreakUpdateResult
}

// MARK: - RPC Parameter Models
private struct GetDailyQuestionsParams: nonisolated Encodable, Sendable {
    let p_user_id: String
    let p_date: String
}

private struct GetDailyStatusParams: nonisolated Encodable, Sendable {
    let p_user_id: String
    let p_date: String
}

private struct UpdateStreakParams: nonisolated Encodable, Sendable {
    let p_user_id: String
    let p_date: String
    let p_questions_answered: Int
    let p_correct_answers: Int
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

struct DailyPracticeStatus: Codable {
    let currentStreak: Int?
    let totalCompleted: Int?
    let isCompletedToday: Bool?
    let canResume: Bool?
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case totalCompleted = "total_completed"
        case isCompletedToday = "is_completed_today"
        case canResume = "can_resume"
    }
    
    // Computed properties with default values
    var streak: Int { currentStreak ?? 0 }
    var completed: Int { totalCompleted ?? 0 }
    var completedToday: Bool { isCompletedToday ?? false }
    var canContinue: Bool { canResume ?? true }
}

struct StreakUpdateResult: Codable {
    let currentStreak: Int?
    let totalCompleted: Int?
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case totalCompleted = "total_completed"
    }
    
    // Computed properties with default values
    var streak: Int { currentStreak ?? 0 }
    var completed: Int { totalCompleted ?? 0 }
}

// MARK: - Supabase Service Implementation
class DailyPracticeService: DailyPracticeServiceProtocol {
    
    private var supabaseClient: SupabaseClient {
        return SupabaseManager.shared.client
    }
    
    func getTodayQuestions() async throws -> [DailyPracticeQuestion] {
        // Check network connectivity first
        guard NetworkMonitor.shared.isConnected else {
            throw DailyPracticeError.networkError
        }
        
        do {
            // Get current user ID from your existing manager
            guard let userIdString = SupabaseManager.shared.currentUserId else {
                throw DailyPracticeError.notAuthenticated
            }
            
            // Get today's date in user's timezone
            let todayDate = getCurrentLocalDate()
            
            print("🔄 Fetching daily questions for user: \(userIdString), date: \(todayDate)")
            
            // Call the database function that handles all the daily generation logic
            let params = GetDailyQuestionsParams(p_user_id: userIdString, p_date: todayDate)
            let supabaseQuestions: [SupabaseQuestion] = try await supabaseClient
                .rpc("get_or_create_daily_questions", params: params)
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
    
    func isTodaysPracticeCompleted() async throws -> Bool {
        // Check network connectivity first
        guard NetworkMonitor.shared.isConnected else {
            throw DailyPracticeError.networkError
        }
        
        do {
            // Get current user ID from your existing manager
            guard let userIdString = SupabaseManager.shared.currentUserId else {
                throw DailyPracticeError.notAuthenticated
            }
            
            print("🔄 Checking if today's practice is completed for user: \(userIdString)")
            
            // Get today's start and end times
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let formatter = ISO8601DateFormatter()
            let startOfDayString = formatter.string(from: startOfDay)
            let endOfDayString = formatter.string(from: endOfDay)
            
            // Query to count completed questions for today
            let response = try await supabaseClient
                .from("user_question_completions")
                .select("id", count: .exact)
                .eq("user_id", value: userIdString)
                .gte("completed_at", value: startOfDayString)
                .lt("completed_at", value: endOfDayString)
                .execute()
            
            let count = response.count ?? 0
            
            // Check if the count matches the expected number of questions (5)
            let isCompleted = (count >= 5)
            
            print("✅ Today's practice completion status for user \(userIdString): \(isCompleted) (completed \(count)/5 questions)")
            return isCompleted
            
        } catch {
            print("❌ Failed to check today's practice completion status: \(error)")
            throw DailyPracticeError.failedToCheckCompletionStatus(error.localizedDescription)
        }
    }
    
    func getDailyPracticeStatus() async throws -> DailyPracticeStatus {
        // Check network connectivity first
        guard NetworkMonitor.shared.isConnected else {
            throw DailyPracticeError.networkError
        }
        
        do {
            // Get current user ID from your existing manager
            guard let userIdString = SupabaseManager.shared.currentUserId else {
                throw DailyPracticeError.notAuthenticated
            }
            
            print("🔄 Fetching daily practice status for user: \(userIdString)")
            
            // Get today's date in user's timezone
            let todayDate = getCurrentLocalDate()
            
            // Call the database function that retrieves the daily practice status
            let params = GetDailyStatusParams(p_user_id: userIdString, p_date: todayDate)
            let statusArray: [DailyPracticeStatus] = try await supabaseClient
                .rpc("get_daily_practice_status", params: params)
                .execute()
                .value
            
            // Extract the first (and should be only) result from the array
            guard var status = statusArray.first else {
                // If no status returned, return default values
                print("⚠️ No status data returned from database, using defaults")
                return DailyPracticeStatus(
                    currentStreak: 0,
                    totalCompleted: 0,
                    isCompletedToday: false,
                    canResume: true
                )
            }
            
            // Double-check completion status using user_question_completions count
            // (since get_daily_practice_status checks daily_question_sets which is created at start, not completion)
            let actuallyCompleted = try await checkTodayCompletionFromQuestions()
            
            print("✅ Loaded daily practice status from Supabase for user: \(userIdString)")
            print("   - Current streak: \(status.streak)")
            print("   - DB says completed today: \(status.completedToday)")
            print("   - Actually completed (5 questions): \(actuallyCompleted)")
            print("   - Can resume: \(!actuallyCompleted)")
            
            // Override with actual completion check
            return DailyPracticeStatus(
                currentStreak: status.currentStreak,
                totalCompleted: status.totalCompleted,
                isCompletedToday: actuallyCompleted,
                canResume: !actuallyCompleted
            )
            
        } catch {
            print("❌ Failed to load daily practice status from Supabase: \(error)")
            throw DailyPracticeError.failedToFetchStatus(error.localizedDescription)
        }
    }
    
    // Helper function to check if today's 5 questions are completed
    private func checkTodayCompletionFromQuestions() async throws -> Bool {
        guard let userIdString = SupabaseManager.shared.currentUserId else {
            return false
        }
        
        // Get today's start and end times
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let formatter = ISO8601DateFormatter()
        let startOfDayString = formatter.string(from: startOfDay)
        let endOfDayString = formatter.string(from: endOfDay)
        
        // Query to count completed questions for today
        let response = try await supabaseClient
            .from("user_question_completions")
            .select("id", count: .exact)
            .eq("user_id", value: userIdString)
            .gte("completed_at", value: startOfDayString)
            .lt("completed_at", value: endOfDayString)
            .execute()
        
        let count = response.count ?? 0
        return count >= 5
    }
    
    func updateDailyPracticeStreak(questionsAnswered: Int, correctAnswers: Int) async throws -> StreakUpdateResult {
        do {
            // Get current user ID from your existing manager
            guard let userIdString = SupabaseManager.shared.currentUserId else {
                throw DailyPracticeError.notAuthenticated
            }
            
            print("🔄 Updating daily practice streak for user: \(userIdString)")
            print("   - Questions Answered: \(questionsAnswered)")
            print("   - Correct Answers: \(correctAnswers)")
            
            // Get today's date in user's timezone
            let todayDate = getCurrentLocalDate()
            print("   - Date: \(todayDate)")
            
            // Call the database function that updates the daily practice streak
            let params = UpdateStreakParams(
                p_user_id: userIdString,
                p_date: todayDate,
                p_questions_answered: questionsAnswered,
                p_correct_answers: correctAnswers
            )
            
            print("📡 Calling RPC function 'update_daily_practice_streak' with params:")
            print("   - p_user_id: \(userIdString)")
            print("   - p_date: \(todayDate)")
            print("   - p_questions_answered: \(questionsAnswered)")
            print("   - p_correct_answers: \(correctAnswers)")
            
            let resultArray: [StreakUpdateResult] = try await supabaseClient
                .rpc("update_daily_practice_streak", params: params)
                .execute()
                .value
            
            print("📥 Received response from database:")
            print("   - Result array count: \(resultArray.count)")
            
            // Extract the first (and should be only) result from the array
            guard let result = resultArray.first else {
                print("❌ ERROR: No streak data returned from database (empty array)")
                throw DailyPracticeError.failedToUpdateStreak("No streak data returned from database")
            }
            
            print("✅ Updated daily practice streak in Supabase for user: \(userIdString)")
            print("   - Current streak: \(result.streak)")
            print("   - Total completed: \(result.completed)")
            return result
            
        } catch {
            print("❌ Failed to update daily practice streak in Supabase:")
            print("   - Error type: \(type(of: error))")
            print("   - Error description: \(error.localizedDescription)")
            print("   - Full error: \(error)")
            throw DailyPracticeError.failedToUpdateStreak(error.localizedDescription)
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
    case failedToCheckCompletionStatus(String)
    case failedToFetchStatus(String)
    case failedToUpdateStreak(String)
    case invalidQuestionData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated. Please log in to access daily practice questions."
        case .failedToFetchQuestions(let message):
            return "Failed to fetch daily questions: \(message)"
        case .failedToSubmitCompletion(let message):
            return "Failed to submit completion: \(message)"
        case .failedToCheckCompletionStatus(let message):
            return "Failed to check completion status: \(message)"
        case .failedToFetchStatus(let message):
            return "Failed to fetch daily practice status: \(message)"
        case .failedToUpdateStreak(let message):
            return "Failed to update daily practice streak: \(message)"
        case .invalidQuestionData:
            return "Invalid question data received"
        case .networkError:
            return "No internet connection. Please check your network and try again."
        }
    }
}
