//
//  PracticeServiceProtocol.swift
//  Wingman
//

import Foundation
import Supabase

// MARK: - Protocol

protocol PracticeServiceProtocol: Sendable {
    func fetchPractices() async throws -> [Practice]
    func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail?
    func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress]
    func updateUserProgress(progress: UserPracticeProgress) async throws
    func unlockPractice(practiceId: UUID, userId: UUID) async throws
    func completePractice(practiceId: UUID, userId: UUID) async throws
    func fetchGameData(scenarioId: UUID, womanName: String?) async throws -> PracticeGameData
    func saveScenarioProgress(userId: UUID, scenarioId: UUID, currentScreenId: UUID) async throws
    func completeScenario(userId: UUID, scenarioId: UUID) async throws
    func getTotalDailyPractices(userId: UUID) async throws -> Int
}

// MARK: - RPC / Request param structs
// Must be file-scope + Sendable so the Supabase SDK generic constraint is satisfied.

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

private struct UserScenarioProgressRow: nonisolated Codable, Sendable {
    let scenarioId: UUID
    let isCompleted: Bool
    let currentScreenId: UUID?
    enum CodingKeys: String, CodingKey {
        case scenarioId      = "scenario_id"
        case isCompleted     = "is_completed"
        case currentScreenId = "current_screen_id"
    }
}

private struct ScenarioTitleRow: nonisolated Codable, Sendable {
    let id: UUID
    let title: String
}

// MARK: - Live Supabase Service
//
// WHY nonisolated + a nonisolated computed var:
//
// `nonisolated func` alone does not help when the method body accesses a
// stored property (`self.client`), because stored properties themselves are
// still actor-isolated when the class is used from an @MainActor context.
//
// The correct pattern is:
//   1. Store the client URL/key (plain Sendable Strings), OR
//   2. Store the client as a `nonisolated let` so Swift knows it is safe to
//      read from any isolation domain.
//
// SupabaseClient is a reference type that is itself Sendable (it uses internal
// locking), so marking the stored `let` as `nonisolated` is correct and safe.

final class PracticeService: PracticeServiceProtocol {

    // MARK: - Testing toggle
    // Set to true to force-unlock all practices locally for testing PracticeView.
    // Remember to set back to false before shipping. Adnan
    static var forceUnlockForTesting: Bool = false

    // nonisolated let → can be read from any nonisolated async method
    nonisolated let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: Fetch All Practices
    nonisolated func fetchPractices() async throws -> [Practice] {
        // Check network connectivity first
        guard NetworkMonitor.shared.isConnected else {
            throw PracticeServiceError.networkError
        }
        
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
            // Normal locking logic
            p.isLocked = totalCompleted < practice.requiredDailyPractices
            if let prog = progressMap[practice.id] {
                p.isCompleted = prog.isCompleted
                p.currentScreenId = prog.currentScreenId
            }
            // Testing override
            if PracticeService.forceUnlockForTesting {
                p.isLocked = false
            }
            return p
        }
    }

    // MARK: Fetch Practice Detail
    nonisolated func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail? {
        let response: [PracticeDetail] = try await client
            .from("practice_details")
            .select("*, steps:practice_steps(*)")
            .eq("practice_id", value: practiceId.uuidString)
            .execute()
            .value
        return response.first
    }

    // MARK: Fetch User Progress
    nonisolated func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress] {
        let response: [UserPracticeProgress] = try await client
            .from("user_practice_progress")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return response
    }

    // MARK: Update User Progress
    nonisolated func updateUserProgress(progress: UserPracticeProgress) async throws {
        try await client
            .from("user_practice_progress")
            .upsert(progress)
            .execute()
    }

    // MARK: Unlock Practice
    nonisolated func unlockPractice(practiceId: UUID, userId: UUID) async throws {
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
    nonisolated func completePractice(practiceId: UUID, userId: UUID) async throws {
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
    nonisolated func fetchGameData(scenarioId: UUID, womanName: String?) async throws -> PracticeGameData {
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

        let startId = scenes.min(by: { $0.order < $1.order })?.id ?? ""
        return PracticeGameData(
            id: scenarioId.uuidString,
            title: scenario?.title ?? "Practice Scenario",
            startingScreenId: startId,
            scenes: scenes
        )
    }

    // MARK: Save Scenario Progress
    nonisolated func saveScenarioProgress(userId: UUID, scenarioId: UUID, currentScreenId: UUID) async throws {
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
    nonisolated func completeScenario(userId: UUID, scenarioId: UUID) async throws {
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
    nonisolated func getTotalDailyPractices(userId: UUID) async throws -> Int {
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
    case networkError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "Please log in to access practices."
        case .scenarioNotFound:     return "Scenario not found."
        case .invalidData(let msg): return "Data error: \(msg)"
        case .networkError:         return "No internet connection. Please check your network and try again."
        }
    }
}

// MARK: - Mock Service (Previews / Unit Tests)

final class MockPracticeService: PracticeServiceProtocol {
    nonisolated func fetchPractices() async throws -> [Practice] { Practice.mockData }

    nonisolated func fetchPracticeDetail(practiceId: UUID) async throws -> PracticeDetail? {
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

    nonisolated func fetchUserProgress(userId: UUID) async throws -> [UserPracticeProgress] { [] }
    nonisolated func updateUserProgress(progress: UserPracticeProgress) async throws {}
    nonisolated func unlockPractice(practiceId: UUID, userId: UUID) async throws {}
    nonisolated func completePractice(practiceId: UUID, userId: UUID) async throws {}
    nonisolated func fetchGameData(scenarioId: UUID, womanName: String?) async throws -> PracticeGameData {
        MockData.barWindow
    }
    nonisolated func saveScenarioProgress(userId: UUID, scenarioId: UUID, currentScreenId: UUID) async throws {}
    nonisolated func completeScenario(userId: UUID, scenarioId: UUID) async throws {}
    nonisolated func getTotalDailyPractices(userId: UUID) async throws -> Int { 3 }
}

// MARK: - Mock Data

extension Practice {
    static let mockData: [Practice] = [
        Practice(
            id: UUID(), title: "Bar Window",
            summary: "Loud music, crowded space, short attention spans. You notice her. Do you lead or wait?",
            coverImageUrl: "c_girl", requiredDailyPractices: 1,
            womanName: "Sophie", orderIndex: 1, isPublished: true,
            createdAt: Date(), updatedAt: Date(),
            isLocked: false, isCompleted: false, currentScreenId: nil
        ),
        Practice(
            id: UUID(), title: "Coffee Connections",
            summary: "Bad weather, warm coffee, shared space. A simple moment turns into an opportunity.",
            coverImageUrl: "c_girl", requiredDailyPractices: 2,
            womanName: "Lily", orderIndex: 2, isPublished: true,
            createdAt: Date(), updatedAt: Date(),
            isLocked: false, isCompleted: false, currentScreenId: nil
        ),
        Practice(
            id: UUID(), title: "Fetch & Flirt",
            summary: "Laughter, eye contact, and two dogs chasing each other. Timing matters here.",
            coverImageUrl: "c_girl", requiredDailyPractices: 3,
            womanName: "Maya", orderIndex: 3, isPublished: true,
            createdAt: Date(), updatedAt: Date(),
            isLocked: false, isCompleted: false, currentScreenId: nil
        )
    ]
}
