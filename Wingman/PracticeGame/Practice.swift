//
//  Practice.swift
//  Wingman
//

import Foundation

// MARK: - Practice (maps to `scenarios` table)
struct Practice: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let coverImageUrl: String?
    let requiredDailyPractices: Int   // unlock threshold (cumulative)
    let womanName: String?
    let orderIndex: Int
    let isPublished: Bool
    let createdAt: Date
    let updatedAt: Date

    // Computed — not stored in DB; set by the service after fetching
    var isLocked: Bool = false
    var isCompleted: Bool = false
    var currentScreenId: UUID? = nil

    // Convenience alias used by existing UI
    var dailyPracticeCount: Int { requiredDailyPractices }
    var imageUrl: String { coverImageUrl ?? "" }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case coverImageUrl          = "cover_image_url"
        case requiredDailyPractices = "required_daily_practices"
        case womanName              = "woman_name"
        case orderIndex             = "order_index"
        case isPublished            = "is_published"
        case createdAt              = "created_at"
        case updatedAt              = "updated_at"
    }
}

// MARK: - PracticeGameData (maps to scenario + its screens in one load)
struct PracticeGameData: Identifiable, Codable {
    let id: String
    let title: String
    var scenes: [GameScene]
}

// MARK: - GameScene (maps to `scenario_screens` + embedded options)
struct GameScene: Identifiable, Codable {
    let id: String
    let type: SceneType
    let characterName: String?      // woman_name from scenario
    let text: String
    let imageName: String?
    var options: [GameOption]?
    let order: Int
    let defaultNextScreenId: String?
    let retryTargetScreenId: String?

    enum SceneType: String, Codable {
        case context        = "context"
        case userDialogue   = "user_dialogue"
        case womanDialogue  = "woman_dialogue"
        case options        = "options"
        case feedback       = "feedback"
    }

    enum CodingKeys: String, CodingKey {
        case id, type, text, options, order
        case characterName          = "character_name"
        case imageName              = "image_url"
        case defaultNextScreenId    = "default_next_screen_id"
        case retryTargetScreenId    = "retry_target_screen_id"
    }
}

// MARK: - GameOption (maps to `screen_options`)
struct GameOption: Identifiable, Codable {
    let id: String
    let text: String
    let nextSceneId: String?
    let isCorrect: Bool
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, text
        case nextSceneId    = "next_screen_id"
        case isCorrect      = "is_correct"
        case orderIndex     = "order_index"
    }
}

// MARK: - Raw Supabase response from get_scenario_screens RPC
struct ScenarioScreenRow: Codable {
    let screenId: String
    let screenType: String
    let orderIndex: Int
    let text: String?
    let imageUrl: String?
    let defaultNextScreenId: String?
    let retryTargetScreenId: String?
    let options: [ScreenOptionRow]

    enum CodingKeys: String, CodingKey {
        case screenId               = "screen_id"
        case screenType             = "screen_type"
        case orderIndex             = "order_index"
        case text
        case imageUrl               = "image_url"
        case defaultNextScreenId    = "default_next_screen_id"
        case retryTargetScreenId    = "retry_target_screen_id"
        case options
    }
}

struct ScreenOptionRow: Codable {
    let id: String
    let text: String
    let nextScreenId: String?
    let isCorrect: Bool
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, text
        case nextScreenId   = "next_screen_id"
        case isCorrect      = "is_correct"
        case orderIndex     = "order_index"
    }
}

// MARK: - Unlocked Scenario Row (from get_unlocked_scenarios RPC)
struct UnlockedScenarioRow: Codable {
    let scenarioId: UUID
    let title: String
    let summary: String?
    let coverImageUrl: String?
    let requiredDailyPractices: Int
    let womanName: String?
    let orderIndex: Int
    let isCompleted: Bool
    let currentScreenId: UUID?
    let totalDailyCompletions: Int

    enum CodingKeys: String, CodingKey {
        case scenarioId             = "scenario_id"
        case title
        case summary
        case coverImageUrl          = "cover_image_url"
        case requiredDailyPractices = "required_daily_practices"
        case womanName              = "woman_name"
        case orderIndex             = "order_index"
        case isCompleted            = "is_completed"
        case currentScreenId        = "current_screen_id"
        case totalDailyCompletions  = "total_daily_completions"
    }
}

// MARK: - Legacy Detail / Step models kept for PracticeDetailView
struct PracticeDetail: Identifiable, Codable {
    let id: UUID
    let practiceId: UUID
    let content: String
    let videoUrl: String?
    let audioUrl: String?
    let duration: Int
    let steps: [PracticeStep]

    enum CodingKeys: String, CodingKey {
        case id
        case practiceId = "practice_id"
        case content
        case videoUrl   = "video_url"
        case audioUrl   = "audio_url"
        case duration
        case steps
    }
}

struct PracticeStep: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let order: Int
}

struct UserPracticeProgress: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let practiceId: UUID
    let isCompleted: Bool
    let completedAt: Date?
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case practiceId = "practice_id"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case streak
    }
}
