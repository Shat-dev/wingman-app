//
//  XPService.swift
//  Wingman
//
//  Supabase transport for the XP ledger. Mirrors DailyPracticeService's shape
//  so the two read the same way, but talks to award_xp / get_xp_summary.
//

import Foundation
import Supabase

// MARK: - Wire models

/// One row of `award_xp`'s result.
///
/// `awarded` is false when the unique constraint `user_xp_events_once` rejected
/// the insert — i.e. this lesson/scenario/day has already paid out. The UI must
/// key off this rather than assuming every completion earns something, or a
/// replay would claim XP that was never granted.
struct XPAwardResult: Codable {
    let awarded: Bool
    let amountAwarded: Int
    let totalXP: Int
    /// True only when a genuinely new award was refused by the source's daily
    /// cap. A replay reports `awarded == false, capped == false`; the two must
    /// stay distinguishable, because a replay should show nothing while a
    /// capped award can explain itself.
    let capped: Bool

    /// The parts `amount_awarded` is made of, so the completion screen can
    /// itemise them. They always sum to `amountAwarded`, and are all 0 whenever
    /// `awarded` is false — a replay or a capped attempt can never render line
    /// items for an award that did not happen.
    let baseAwarded: Int
    let correctAwarded: Int
    let bonusAwarded: Int

    enum CodingKeys: String, CodingKey {
        case awarded
        case amountAwarded  = "amount_awarded"
        case totalXP        = "total_xp"
        case capped
        case baseAwarded    = "base_awarded"
        case correctAwarded = "correct_awarded"
        case bonusAwarded   = "bonus_awarded"
    }
}

/// One row of `get_xp_summary`.
///
/// `lastAwardedAt` is decoded as a String, not a Date, for the same reason
/// `LessonQuestionService.UpdatedAtRow` is: nothing compares it as a date, and
/// a date-decoding-strategy mismatch would throw and take the whole hydration
/// down with it.
struct XPSummary: Codable {
    let totalXP: Int
    let eventCount: Int
    let lastAwardedAt: String?

    enum CodingKeys: String, CodingKey {
        case totalXP       = "total_xp"
        case eventCount    = "event_count"
        case lastAwardedAt = "last_awarded_at"
    }
}

// MARK: - RPC parameters
//
// File-scope + `nonisolated Encodable, Sendable` to satisfy the Supabase SDK's
// generic constraint under this target's MainActor default isolation — the same
// pattern as DailyPracticeServiceProtocol.swift:21-36.

private struct AwardXPParams: nonisolated Encodable, Sendable {
    let p_source_type: String
    let p_source_id: String
    let p_local_date: String
    /// Facts, not amounts. The server turns these into XP via `xp_rules`; the
    /// client never names a number. Both are 0 for sources with no quiz, which
    /// the server reads as "no perfect bonus applies".
    let p_correct_count: Int
    let p_question_count: Int
}

// MARK: - Protocol

protocol XPServiceProtocol {
    /// Records one award. Idempotent on `(user, source_type, source_id)`.
    func award(
        sourceType: String,
        sourceId: String,
        localDate: String,
        correctCount: Int,
        questionCount: Int
    ) async throws -> XPAwardResult

    /// The user's running total, for hydration.
    func summary() async throws -> XPSummary
}

// MARK: - Live implementation

class XPService: XPServiceProtocol {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Note there is no user id parameter. `award_xp` derives the user from
    /// `auth.uid()` server-side, so a client cannot credit anyone but itself —
    /// unlike `update_daily_practice_streak`, which takes a `p_user_id` it never
    /// validates (docs/diagnostics/xp-gamification-audit.md §A.5.2).
    func award(
        sourceType: String,
        sourceId: String,
        localDate: String,
        correctCount: Int,
        questionCount: Int
    ) async throws -> XPAwardResult {
        // Fail fast rather than waiting out a timeout. The caller queues on
        // throw, so being offline costs the award nothing — it is retried on
        // reconnect. The streak's write path has no such guard and simply loses
        // the day (audit §A.6).
        guard await NetworkMonitor.shared.isConnected else {
            throw XPServiceError.offline
        }

        guard await SupabaseManager.shared.currentUserId != nil else {
            throw XPServiceError.notAuthenticated
        }

        let params = AwardXPParams(
            p_source_type: sourceType,
            p_source_id: sourceId,
            p_local_date: localDate,
            p_correct_count: correctCount,
            p_question_count: questionCount
        )

        // RETURNS TABLE decodes as an array of rows, exactly like
        // get_daily_practice_status.
        let rows: [XPAwardResult] = try await client
            .rpc("award_xp", params: params)
            .execute()
            .value

        guard let result = rows.first else {
            throw XPServiceError.emptyResult
        }
        return result
    }

    func summary() async throws -> XPSummary {
        guard await NetworkMonitor.shared.isConnected else {
            throw XPServiceError.offline
        }
        guard await SupabaseManager.shared.currentUserId != nil else {
            throw XPServiceError.notAuthenticated
        }

        let rows: [XPSummary] = try await client
            .rpc("get_xp_summary")
            .execute()
            .value

        guard let summary = rows.first else {
            throw XPServiceError.emptyResult
        }
        return summary
    }
}

// MARK: - Errors

enum XPServiceError: LocalizedError {
    case notAuthenticated
    case offline
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "No session — XP cannot be attributed to a user."
        case .offline:          return "No internet connection."
        case .emptyResult:      return "XP RPC returned no rows."
        }
    }
}

// MARK: - Mock (previews / tests)

final class MockXPService: XPServiceProtocol {
    var awardResult: XPAwardResult = XPAwardResult(
        awarded: true, amountAwarded: 30, totalXP: 30, capped: false,
        baseAwarded: 20, correctAwarded: 10, bonusAwarded: 0
    )
    var summaryResult: XPSummary = XPSummary(totalXP: 30, eventCount: 1, lastAwardedAt: nil)
    var shouldThrow: Error?

    func award(
        sourceType: String,
        sourceId: String,
        localDate: String,
        correctCount: Int,
        questionCount: Int
    ) async throws -> XPAwardResult {
        if let shouldThrow { throw shouldThrow }
        return awardResult
    }

    func summary() async throws -> XPSummary {
        if let shouldThrow { throw shouldThrow }
        return summaryResult
    }
}
