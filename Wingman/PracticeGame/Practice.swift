//
//  Practice.swift
//  Wingman
//
//  Created by Adnan Khan on 23/01/2026.
//


//
//  Practice.swift
//  Wingman
//
//  Created by Claude on 23/01/2026.
//

import Foundation

struct Practice: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let dailyPracticeCount: Int
    let imageUrl: String
    let isLocked: Bool
    let order: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case dailyPracticeCount = "daily_practice_count"
        case imageUrl = "image_url"
        case isLocked = "is_locked"
        case order
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Practice Detail (for subsequent screens)
struct PracticeDetail: Identifiable, Codable {
    let id: UUID
    let practiceId: UUID
    let content: String
    let videoUrl: String?
    let audioUrl: String?
    let duration: Int // in minutes
    let steps: [PracticeStep]
    
    enum CodingKeys: String, CodingKey {
        case id
        case practiceId = "practice_id"
        case content
        case videoUrl = "video_url"
        case audioUrl = "audio_url"
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

// MARK: - User Practice Progress
struct UserPracticeProgress: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let practiceId: UUID
    let isCompleted: Bool
    let completedAt: Date?
    let streak: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case practiceId = "practice_id"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case streak
    }
}