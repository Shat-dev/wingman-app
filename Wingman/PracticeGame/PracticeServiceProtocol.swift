//
//  PracticeServiceProtocol.swift
//  Wingman
//

import Foundation
import Supabase

// MARK: - Protocol
protocol PracticeServiceProtocol {
    func fetchPractices() async throws -> [Practice]
    func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail?
    func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress]
    func updateUserProgress(progress: UserPracticeProgress) async throws
    func unlockPractice(practiceId: UUID, userId: UUID) async throws
    func completePractice(practiceId: UUID, userId: UUID) async throws

    // Game-specific
    func fetchGameData(scenarioId: UUID, womanName: String?) async throws -> PracticeGameData
    func saveScenarioProgress(userId: UUID, scenarioId: UUID, currentScreenId: UUID) async throws
    func completeScenario(userId: UUID, scenarioId: UUID) async throws
    func getTotalDailyPractices(userId: UUID) async throws -> Int
}

// MARK: - RPC / Request param structs
// Keep at file scope so they are not actor-isolated. Make Encodable conformance nonisolated
// so it can satisfy Sendable-constrained generics in Supabase SDK.

private struct GetScenarioScreensParams: nonisolated Encodable, Sendable {
    let p_scenario_id: String
}

private struct GetTotalDailyPracticesParams: nonisolated Encodable, Sendable {
    let p_user_id: String
}

private struct ProgressUpsert: nonisolated Encodable, Sendable {
    let user_id: String
    let scenario_id: String
    let current_screen_id: String
    let last_played_at: String
}

private struct ScenarioCompletionUpdate: nonisolated Encodable, Sendable {
    let is_completed: Bool
    let completed_at: String
}

private struct ScenarioCompletionLog: nonisolated Encodable, Sendable {
    let user_id: String
    let scenario_id: String
}

private struct PracticeProgressUpdate: nonisolated Encodable, Sendable {
    let is_completed: Bool
    let completed_at: String
}

// MARK: - Private decode models

private struct UserScenarioProgressRow: Codable, Sendable {
    let scenarioId: UUID
    let isCompleted: Bool
    let currentScreenId: UUID?
    enum CodingKeys: String, CodingKey {
        case scenarioId      = "scenario_id"
        case isCompleted     = "is_completed"
        case currentScreenId = "current_screen_id"
    }
}

private struct ScenarioTitleRow: Codable, Sendable {
    let id: UUID
    let title: String
}

// MARK: - Live Supabase Service

final class PracticeService: PracticeServiceProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: Fetch All Practices
    func fetchPractices() async throws -> [Practice] {
        guard let userIdString = SupabaseManager.shared.currentUserId,
              let userId = UUID(uuidString: userIdString) else {
            throw PracticeServiceError.notAuthenticated
        }

        let totalCompleted = try await getTotalDailyPractices(userId: userId)

        let rows: [Practice] = try await client
            .from("scenarios")
            .select()
            .eq("is_published", value: true)
            .order("order_index", ascending: true)
            .execute()
            .value

        let progressRows: [UserScenarioProgressRow] = (try? await client
            .from("user_scenario_progress")
            .select("scenario_id, is_completed, current_screen_id")
            .eq("user_id", value: userIdString)
            .execute()
            .value) ?? []

        let progressMap = Dictionary(
            uniqueKeysWithValues: progressRows.map { ($0.scenarioId, $0) }
        )

        return rows.map { practice in
            var p = practice
            p.isLocked = totalCompleted < practice.requiredDailyPractices
            if let prog = progressMap[practice.id] {
                p.isCompleted = prog.isCompleted
                p.currentScreenId = prog.currentScreenId
            }
            return p
        }
    }

    // MARK: Fetch Practice Detail (legacy — for PracticeDetailView)
    func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail? {
        let response: [PracticeDetail] = try await client
            .from("practice_details")
            .select("*, steps:practice_steps(*)")
            .eq("practice_id", value: practiceId.uuidString)
            .execute()
            .value
        return response.first
    }

    // MARK: Fetch User Progress
    func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress] {
        let response: [UserPracticeProgress] = try await client
            .from("user_practice_progress")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return response
    }

    // MARK: Update User Progress
    func updateUserProgress(progress: UserPracticeProgress) async throws {
        try await client
            .from("user_practice_progress")
            .upsert(progress)
            .execute()
    }

    // MARK: Unlock Practice
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

    // MARK: Complete Practice
    func completePractice(practiceId: UUID, userId: UUID) async throws {
        let update = PracticeProgressUpdate(
            is_completed: true,
            completed_at: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("user_practice_progress")
            .update(update)
            .eq("practice_id", value: practiceId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: Fetch Game Data
    func fetchGameData(scenarioId: UUID, womanName: String?) async throws -> PracticeGameData {
        let rows: [ScenarioScreenRow] = try await client
            .rpc("get_scenario_screens", params: GetScenarioScreensParams(p_scenario_id: scenarioId.uuidString))
            .execute()
            .value

        let scenes: [GameScene] = rows.map { row in
            let sceneType = GameScene.SceneType(rawValue: row.screenType) ?? .context
            let options: [GameOption]? = row.options.isEmpty ? nil : row.options.map { opt in
                GameOption(
                    id: opt.id,
                    text: opt.text,
                    nextSceneId: opt.nextScreenId,
                    isCorrect: opt.isCorrect,
                    orderIndex: opt.orderIndex
                )
            }
            return GameScene(
                id: row.screenId,
                type: sceneType,
                characterName: womanName,
                text: row.text ?? "",
                imageName: row.imageUrl,
                options: options,
                order: row.orderIndex,
                defaultNextScreenId: row.defaultNextScreenId,
                retryTargetScreenId: row.retryTargetScreenId
            )
        }

        let scenario: ScenarioTitleRow? = try? await client
            .from("scenarios")
            .select("id, title")
            .eq("id", value: scenarioId.uuidString)
            .single()
            .execute()
            .value

        return PracticeGameData(
            id: scenarioId.uuidString,
            title: scenario?.title ?? "Practice Scenario",
            scenes: scenes
        )
    }

    // MARK: Save Scenario Progress (called on every screen advance)
    func saveScenarioProgress(userId: UUID, scenarioId: UUID, currentScreenId: UUID) async throws {
        let upsert = ProgressUpsert(
            user_id: userId.uuidString,
            scenario_id: scenarioId.uuidString,
            current_screen_id: currentScreenId.uuidString,
            last_played_at: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("user_scenario_progress")
            .upsert(upsert, onConflict: "user_id,scenario_id")
            .execute()
    }

    // MARK: Complete Scenario
    func completeScenario(userId: UUID, scenarioId: UUID) async throws {
        let update = ScenarioCompletionUpdate(
            is_completed: true,
            completed_at: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("user_scenario_progress")
            .update(update)
            .eq("user_id", value: userId.uuidString)
            .eq("scenario_id", value: scenarioId.uuidString)
            .execute()

        let log = ScenarioCompletionLog(
            user_id: userId.uuidString,
            scenario_id: scenarioId.uuidString
        )
        try await client
            .from("user_scenario_completions")
            .insert(log)
            .execute()
    }

    // MARK: Get Total Daily Practices
    func getTotalDailyPractices(userId: UUID) async throws -> Int {
        let count: Int = try await client
            .rpc("get_total_daily_practices", params: GetTotalDailyPracticesParams(p_user_id: userId.uuidString))
            .execute()
            .value
        return count
    }
}

// MARK: - Service Errors

enum PracticeServiceError: LocalizedError {
    case notAuthenticated
    case scenarioNotFound
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "Please log in to access practices."
        case .scenarioNotFound:     return "Scenario not found."
        case .invalidData(let msg): return "Data error: \(msg)"
        }
    }
}

// MARK: - Mock Service (Previews / Unit Tests)

final class MockPracticeService: PracticeServiceProtocol {

    func fetchPractices() async throws -> [Practice] { Practice.mockData }

    func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail? {
        PracticeDetail(
            id: UUID(), practiceId: practiceId,
            content: "This practice helps you understand that you are not your thoughts...",
            videoUrl: nil, audioUrl: nil, duration: 15,
            steps: [
                PracticeStep(id: UUID(), title: "Step 1", description: "Find a quiet place", order: 1),
                PracticeStep(id: UUID(), title: "Step 2", description: "Close your eyes", order: 2),
                PracticeStep(id: UUID(), title: "Step 3", description: "Observe your thoughts", order: 3)
            ]
        )
    }

    func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress] { [] }
    func updateUserProgress(progress: UserPracticeProgress) async throws {}
    func unlockPractice(practiceId: UUID, userId: UUID) async throws {}
    func completePractice(practiceId: UUID, userId: UUID) async throws {}
    func fetchGameData(scenarioId: UUID, womanName: String?) async throws -> PracticeGameData { MockData.sampleGame }
    func saveScenarioProgress(userId: UUID, scenarioId: UUID, currentScreenId: UUID) async throws {}
    func completeScenario(userId: UUID, scenarioId: UUID) async throws {}
    func getTotalDailyPractices(userId: UUID) async throws -> Int { 3 }
}

// MARK: - Mock Data

extension Practice {
    static let mockData: [Practice] = [
        Practice(
            id: UUID(), title: "The Nightclub Approach",
            summary: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
            coverImageUrl: "c_girl", requiredDailyPractices: 0,
            womanName: "Sophie", orderIndex: 1, isPublished: true,
            createdAt: Date(), updatedAt: Date(),
            isLocked: false, isCompleted: false, currentScreenId: nil
        ),
        Practice(
            id: UUID(), title: "The Coffee Shop Opener",
            summary: "Approach a woman reading a book in a relaxed daytime setting.",
            coverImageUrl: "c_girl", requiredDailyPractices: 2,
            womanName: "Emma", orderIndex: 2, isPublished: true,
            createdAt: Date(), updatedAt: Date(),
            isLocked: false, isCompleted: false, currentScreenId: nil
        ),
        Practice(
            id: UUID(), title: "Group Social Dynamics",
            summary: "Handle approaching a woman who is with her friends.",
            coverImageUrl: "c_girl", requiredDailyPractices: 5,
            womanName: "Mia", orderIndex: 3, isPublished: true,
            createdAt: Date(), updatedAt: Date(),
            isLocked: true, isCompleted: false, currentScreenId: nil
        )
    ]
}
