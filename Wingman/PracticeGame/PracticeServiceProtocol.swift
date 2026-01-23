//
//  PracticeServiceProtocol.swift
//  Wingman
//
//  Created by Adnan Khan on 23/01/2026.
//


//
//  PracticeService.swift
//  Wingman
//
//  Created by Claude on 23/01/2026.
//

import Foundation
import Supabase

protocol PracticeServiceProtocol {
    func fetchPractices() async throws -> [Practice]
    func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail?
    func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress]
    func updateUserProgress(progress: UserPracticeProgress) async throws
    func unlockPractice(practiceId: UUID, userId: UUID) async throws
    func completePractice(practiceId: UUID, userId: UUID) async throws
}

final class PracticeService: PracticeServiceProtocol {
    
    // MARK: - Dependencies
    private let client: SupabaseClient
    
    // MARK: - Init
    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }
    
    // MARK: - Fetch All Practices
    func fetchPractices() async throws -> [Practice] {
        let response: [Practice] = try await client
            .from("practices")
            .select()
            .order("order", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Fetch Practice Detail
    func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail? {
        let response: [PracticeDetail] = try await client
            .from("practice_details")
            .select("""
                *,
                steps:practice_steps(*)
            """)
            .eq("practice_id", value: practiceId.uuidString)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Fetch User Progress
    func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress] {
        let response: [UserPracticeProgress] = try await client
            .from("user_practice_progress")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Update User Progress
    func updateUserProgress(progress: UserPracticeProgress) async throws {
        try await client
            .from("user_practice_progress")
            .upsert(progress)
            .execute()
    }
    
    // MARK: - Unlock Practice
    func unlockPractice(practiceId: UUID, userId: UUID) async throws {
        let newProgress = UserPracticeProgress(
            id: UUID(),
            userId: userId,
            practiceId: practiceId,
            isCompleted: false,
            completedAt: nil,
            streak: 0
        )
        
        try await client
            .from("user_practice_progress")
            .insert(newProgress)
            .execute()
    }
    
    // MARK: - Complete Practice
    func completePractice(practiceId: UUID, userId: UUID) async throws {
        struct ProgressUpdate: Encodable {
            let isCompleted: Bool
            let completedAt: String
            
            enum CodingKeys: String, CodingKey {
                case isCompleted = "is_completed"
                case completedAt = "completed_at"
            }
        }
        
        let update = ProgressUpdate(
            isCompleted: true,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_practice_progress")
            .update(update)
            .eq("practice_id", value: practiceId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}

// MARK: - Mock Service for Previews
final class MockPracticeService: PracticeServiceProtocol {
    
    func fetchPractices() async throws -> [Practice] {
        return Practice.mockData
    }
    
    func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail? {
        return PracticeDetail(
            id: UUID(),
            practiceId: practiceId,
            content: "This practice helps you understand that you are not your thoughts...",
            videoUrl: nil,
            audioUrl: nil,
            duration: 15,
            steps: [
                PracticeStep(id: UUID(), title: "Step 1", description: "Find a quiet place", order: 1),
                PracticeStep(id: UUID(), title: "Step 2", description: "Close your eyes", order: 2),
                PracticeStep(id: UUID(), title: "Step 3", description: "Observe your thoughts", order: 3)
            ]
        )
    }
    
    func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress] {
        return []
    }
    
    func updateUserProgress(progress: UserPracticeProgress) async throws {}
    
    func unlockPractice(practiceId: UUID, userId: UUID) async throws {}
    
    func completePractice(practiceId: UUID, userId: UUID) async throws {}
}

// MARK: - Mock Data
extension Practice {
    static let mockData: [Practice] = [
        Practice(
            id: UUID(),
            title: "Your are not your thoughts",
            summary: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
            dailyPracticeCount: 1,
            imageUrl: "practice_meditation_1",
            isLocked: false,
            order: 1,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Practice(
            id: UUID(),
            title: "Your are not your thoughts",
            summary: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
            dailyPracticeCount: 2,
            imageUrl: "practice_meditation_2",
            isLocked: false,
            order: 2,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Practice(
            id: UUID(),
            title: "Your are not your thoughts",
            summary: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
            dailyPracticeCount: 3,
            imageUrl: "practice_meditation_3",
            isLocked: true,
            order: 3,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Practice(
            id: UUID(),
            title: "Your are not your thoughts",
            summary: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
            dailyPracticeCount: 5,
            imageUrl: "practice_meditation_4",
            isLocked: true,
            order: 4,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Practice(
            id: UUID(),
            title: "Your are not your thoughts",
            summary: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
            dailyPracticeCount: 8,
            imageUrl: "practice_meditation_5",
            isLocked: true,
            order: 5,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Practice(
            id: UUID(),
            title: "Your are not your thoughts",
            summary: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
            dailyPracticeCount: 11,
            imageUrl: "practice_meditation_6",
            isLocked: true,
            order: 6,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}
