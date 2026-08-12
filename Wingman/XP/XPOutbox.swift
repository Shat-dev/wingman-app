//
//  XPOutbox.swift
//  Wingman
//
//  Durable queue of XP awards that have been earned but not yet acknowledged
//  by the server.
//
//  WHY THIS EXISTS
//
//  The streak has no equivalent and it costs users days: if
//  `update_daily_practice_streak` fails, DailyPracticeViewModel shows the
//  completion screen with a hardcoded streak of 1 and never retries, so the day
//  is gone (docs/diagnostics/xp-gamification-audit.md §A.5.3, §A.6). XP must not
//  inherit that. An award is written here *before* the network call, so a
//  process kill mid-flight cannot lose it.
//
//  Replaying is safe because `award_xp` is idempotent on
//  `(user_id, source_type, source_id)` — the ledger's unique constraint turns a
//  duplicate send into `awarded = false` rather than double credit. That is what
//  lets this be an at-least-once queue instead of an exactly-once one, which
//  would be much harder to get right.
//

import Foundation

/// One award waiting to be confirmed by the server.
struct XPPendingAward: Codable, Equatable, Identifiable {
    let id: UUID
    /// The user this was earned by. Checked on every flush — see
    /// `XPOutbox.pending(for:)`.
    let userId: String
    let sourceType: String
    let sourceId: String
    let localDate: String
    let createdAt: Date
    /// The facts the server turns into an amount. Persisted with the entry so a
    /// retry days later still computes the same award — recomputing them at
    /// flush time is impossible, the quiz is long gone.
    let correctCount: Int
    let questionCount: Int
}

extension XPPendingAward {
    /// Written as an extension so the memberwise initialiser survives.
    ///
    /// `correctCount` / `questionCount` decode as 0 when absent, so a queue
    /// written by an earlier build still drains instead of being discarded
    /// wholesale by `XPOutbox.all()`'s decode-failure path.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        userId        = try c.decode(String.self, forKey: .userId)
        sourceType    = try c.decode(String.self, forKey: .sourceType)
        sourceId      = try c.decode(String.self, forKey: .sourceId)
        localDate     = try c.decode(String.self, forKey: .localDate)
        createdAt     = try c.decode(Date.self,   forKey: .createdAt)
        correctCount  = try c.decodeIfPresent(Int.self, forKey: .correctCount)  ?? 0
        questionCount = try c.decodeIfPresent(Int.self, forKey: .questionCount) ?? 0
    }
}

enum XPOutbox {

    /// Registered in `XPStore.cacheKeys`, so a sign-out wipes it along with the
    /// rest of the outgoing user's cached state.
    static let storageKey = "xp_outbox"

    /// Beyond this the queue is not draining and something is broken; dropping
    /// the oldest keeps UserDefaults from growing without bound.
    static let maxEntries = 200

    /// Entries older than this are dropped unsent. In practice only entries
    /// belonging to a *different* user ever get this old, since anything for the
    /// current user flushes on the next award, foreground or reconnect.
    static let maxAgeDays = 30

    // MARK: - Read

    static func all() -> [XPPendingAward] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([XPPendingAward].self, from: data)
        } catch {
            // A decode failure means the stored shape changed under us. Drop it
            // rather than wedging every future flush on data we cannot read.
            log("⚠️ XPOutbox: unreadable queue discarded — \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: storageKey)
            return []
        }
    }

    /// Entries belonging to `userId`, oldest first.
    ///
    /// **This filter is the guard that stops user B being credited for user A's
    /// work.** Entries for other users are never sent — only aged out by
    /// `prune()`. A queued award is tied to the account that earned it, not to
    /// whoever happens to be signed in when the network comes back.
    static func pending(for userId: String) -> [XPPendingAward] {
        all()
            .filter { $0.userId == userId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Write

    static func enqueue(_ award: XPPendingAward) {
        var queue = all()

        // Same (user, source, id) already queued — no point holding two, the
        // server would reject the second anyway.
        guard !queue.contains(where: {
            $0.userId == award.userId &&
            $0.sourceType == award.sourceType &&
            $0.sourceId == award.sourceId
        }) else { return }

        queue.append(award)

        if queue.count > maxEntries {
            let dropped = queue.count - maxEntries
            queue = Array(queue.sorted { $0.createdAt < $1.createdAt }.dropFirst(dropped))
            log("🚨 XPOutbox: over \(maxEntries) entries, dropped \(dropped) oldest — flushing is broken")
        }

        save(queue)
    }

    static func remove(id: UUID) {
        save(all().filter { $0.id != id })
    }

    /// Drops entries past `maxAgeDays`. Returns how many went.
    @discardableResult
    static func prune() -> Int {
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 60 * 60)
        let queue = all()
        let kept = queue.filter { $0.createdAt >= cutoff }
        guard kept.count != queue.count else { return 0 }
        save(kept)
        return queue.count - kept.count
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Private

    private static func save(_ queue: [XPPendingAward]) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(queue), forKey: storageKey)
        } catch {
            log("⚠️ XPOutbox: could not persist queue — \(error.localizedDescription)")
        }
    }
}
