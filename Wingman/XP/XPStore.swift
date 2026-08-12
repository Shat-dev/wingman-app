//
//  XPStore.swift
//  Wingman
//
//  Single source of truth for XP on the client.
//
//  Follows StreakStore's shape deliberately — cache-seeded so views render the
//  last-known-good number instantly, never wiped on a failed refresh, and an
//  `apply` path so a completion can push the authoritative total in without a
//  second round trip.
//
//  It adds one thing StreakStore does not have: the cache records which user it
//  belongs to. `SupabaseManager.clearCurrentUser()` only runs on sign-out, so a
//  `.signedIn` for a different account with no intervening `.signedOut` leaves
//  the previous user's number on screen until a refresh lands. StreakStore has
//  that hole today; this does not. Backporting it to StreakStore is a behaviour
//  change to the streak and is deliberately NOT bundled with this work — see
//  docs/xp-system-plan.md §4.2.
//

import Foundation
import Combine
import UIKit

@MainActor
final class XPStore: ObservableObject {

    static let shared = XPStore()

    /// What the last confirmed award was worth. Set only from a server result
    /// where `awarded == true`, so it can never claim XP that a replay did not
    /// actually grant. Optimistic pre-server display arrives with the
    /// completion screens in Phase 3.
    struct Award: Equatable {
        let source: XPSource
        let amount: Int
        let totalAfter: Int
    }

    // MARK: - Published state
    // Optional so a view can tell "not loaded yet" (nil) from "loaded, and it
    // is zero" — the same reason StreakStore's are optional.

    @Published private(set) var totalXP: Int?
    @Published private(set) var lastAward: Award?
    @Published private(set) var isRefreshing: Bool = false

    // MARK: - Cache keys
    // Registered in SupabaseManager.clearCurrentUser() so sign-out wipes them.

    static let totalKey  = "xp_cache_total"
    static let ownerKey  = "xp_cache_owner_user_id"
    static let cacheKeys = [totalKey, ownerKey, XPOutbox.storageKey]

    // MARK: - Dependencies

    private let service: XPServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var isFlushing = false

    init(service: XPServiceProtocol = XPService()) {
        self.service = service
        loadFromCache()
        observeFlushTriggers()
    }

    // MARK: - Cache I/O

    private func loadFromCache() {
        let d = UserDefaults.standard
        let cachedOwner = d.string(forKey: Self.ownerKey)
        let currentOwner = SupabaseManager.shared.currentUserId

        // Drop only on a *proven* mismatch. At launch the Supabase session has
        // often not restored yet, so `currentOwner` is nil — treating that as a
        // mismatch would wipe the cache on every cold start and defeat the whole
        // point of having one.
        if let cachedOwner, let currentOwner, cachedOwner != currentOwner {
            log("📦 XPStore: cached total belongs to a different user — discarding")
            d.removeObject(forKey: Self.totalKey)
            d.removeObject(forKey: Self.ownerKey)
            return
        }

        if d.object(forKey: Self.totalKey) != nil {
            totalXP = d.integer(forKey: Self.totalKey)
        }
        log("📦 XPStore: seeded from cache — total=\(totalXP.map(String.init) ?? "nil") queued=\(XPOutbox.all().count)")
    }

    private func saveToCache() {
        let d = UserDefaults.standard
        if let totalXP { d.set(totalXP, forKey: Self.totalKey) }
        if let owner = SupabaseManager.shared.currentUserId { d.set(owner, forKey: Self.ownerKey) }
    }

    // MARK: - Refresh

    /// Pull the authoritative total. On failure the existing value is kept —
    /// never overwritten with 0.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let summary = try await service.summary()
            totalXP = summary.totalXP
            saveToCache()
            log("✅ XPStore: refreshed — total=\(summary.totalXP) events=\(summary.eventCount)")
        } catch {
            log("❌ XPStore: refresh failed, keeping cached value — \(error.localizedDescription)")
        }
    }

    // MARK: - Awarding

    /// Record that `source` was completed. Safe to call more than once for the
    /// same `sourceId`: the server's unique constraint makes the repeat a no-op
    /// that returns `awarded = false`.
    ///
    /// Never throws. A completion must not fail because XP could not be
    /// recorded — the award is queued and retried instead.
    /// `correctCount` / `questionCount` are the facts the server turns into an
    /// amount. Leave both at 0 for sources with no quiz — the server reads that
    /// as "no perfect bonus applies" and pays the flat base.
    func award(
        _ source: XPSource,
        sourceId: String,
        correctCount: Int = 0,
        questionCount: Int = 0
    ) async {
        guard let userId = SupabaseManager.shared.currentUserId else {
            // Not queued: an award with no user cannot be attributed later, and
            // guessing at flush time is exactly how one user gets credited for
            // another's work. Reachable only if the session dies mid-session —
            // RootView walls sessionless users before MainTabView.
            log("⚠️ XPStore: no session, dropping award \(source.rawValue)/\(sourceId)")
            Analytics.capture(Analytics.Event.xpAwardFailed, [
                "source_type": source.rawValue,
                "queued": false,
                "reason": "no_session"
            ])
            return
        }

        // Drop any award left over from a previous completion. The completion
        // screens read `lastAward`, so without this a lesson finished ten
        // minutes ago would decorate the next scenario's screen — and a replay,
        // which is supposed to show nothing, would show the earlier award.
        lastAward = nil

        let pending = XPPendingAward(
            id: UUID(),
            userId: userId,
            sourceType: source.rawValue,
            sourceId: sourceId,
            localDate: XPLocalDate.today(),
            createdAt: Date(),
            correctCount: correctCount,
            questionCount: questionCount
        )

        // Persist BEFORE the network call, so a crash or kill between here and
        // the response still leaves the award recoverable.
        XPOutbox.enqueue(pending)

        await send(pending)
        await flushOutbox()
    }

    /// Award against a row identified by UUID — scenarios and approach logs.
    ///
    /// Exists so the casing cannot be got wrong at a call site. Swift's
    /// `UUID.uuidString` is UPPERCASE while Postgres renders `uuid::text`
    /// lowercase, so passing `someId.uuidString` straight through writes a
    /// `source_id` that no longer plain-equals the row it came from — a join to
    /// `approach_logs` or `scenarios` would silently return nothing and need
    /// `lower(source_id)` to work.
    ///
    /// Nothing breaks functionally either way (the client is self-consistent,
    /// so idempotency and `user_xp_events_once` hold regardless), but the whole
    /// point of keying on the row id is being able to audit the ledger against
    /// the thing that earned it. This is the same uppercase/lowercase trap that
    /// once created duplicate PostHog persons — see Analytics.swift:355-359.
    func award(
        _ source: XPSource,
        sourceId: UUID,
        correctCount: Int = 0,
        questionCount: Int = 0
    ) async {
        await award(
            source,
            sourceId: sourceId.uuidString.lowercased(),
            correctCount: correctCount,
            questionCount: questionCount
        )
    }

    /// Send one queued award. Removes it from the queue only on success.
    private func send(_ pending: XPPendingAward) async {
        do {
            let result = try await service.award(
                sourceType: pending.sourceType,
                sourceId: pending.sourceId,
                localDate: pending.localDate,
                correctCount: pending.correctCount,
                questionCount: pending.questionCount
            )
            // Removed on ANY successful response, `capped` included: XP beyond
            // a source's daily cap is forfeited by design, not deferred to
            // tomorrow, so retrying it would never succeed.
            XPOutbox.remove(id: pending.id)
            // `recordAward: true` — this is the award the user is looking at.
            apply(result: result, sourceType: pending.sourceType, recordAward: true)

            log("✨ XPStore: \(pending.sourceType)/\(pending.sourceId) "
                + "awarded=\(result.awarded) +\(result.amountAwarded) total=\(result.totalXP)"
                + (result.capped ? " (refused: daily cap)" : ""))
        } catch {
            log("↩️ XPStore: award queued for retry (\(pending.sourceType)/\(pending.sourceId)) — "
                + error.localizedDescription)
            Analytics.capture(Analytics.Event.xpAwardFailed, [
                "source_type": pending.sourceType,
                "queued": true,
                "reason": String(describing: error)
            ])
        }
    }

    /// - Parameter recordAward: whether this result is the award the user is
    ///   currently looking at, and so may set `lastAward`.
    ///
    ///   **Only the award that `award(_:sourceId:…)` was just called for may set
    ///   it.** A drain of the outbox settles older entries that belong to
    ///   completions the user finished minutes or days ago; letting those write
    ///   `lastAward` would repaint the open completion screen with someone
    ///   else's number. `award()` flushes right after sending, so without this
    ///   guard a single stale queued entry was enough to make the badge lie
    ///   about what had just been earned.
    ///
    ///   The total is always applied either way — every response carries the
    ///   server's recomputed sum, so the last one to land is the truthful one.
    private func apply(result: XPAwardResult, sourceType: String, recordAward: Bool) {
        totalXP = result.totalXP
        if recordAward, result.awarded, let source = XPSource(rawValue: sourceType) {
            lastAward = Award(source: source, amount: result.amountAwarded, totalAfter: result.totalXP)
        }
        saveToCache()

        // Fired here rather than as a property on `lesson_completed` and
        // friends, which is what the plan (§5.5) originally called for. Those
        // events fire the moment the user finishes; the award resolves
        // afterwards and may be queued for hours. Carrying the amount on them
        // would mean delaying a completion event until the network answers —
        // and never firing it at all offline, which is far worse than a
        // separate event.
        //
        // This is not a duplicate completion signal: it measures award
        // confirmation. It joins back to the completion events by person and
        // `source_id`.
        Analytics.capture(Analytics.Event.xpAwarded, [
            "source_type": sourceType,
            "awarded": result.awarded,
            "capped": result.capped,
            "amount": result.amountAwarded,
            "total_after": result.totalXP
        ])
    }

    // MARK: - Outbox

    /// Retry everything queued for the current user.
    ///
    /// Entries belonging to a different account are skipped, never sent — see
    /// `XPOutbox.pending(for:)`.
    func flushOutbox() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        let pruned = XPOutbox.prune()
        if pruned > 0 { log("🧹 XPOutbox: pruned \(pruned) stale entr\(pruned == 1 ? "y" : "ies")") }

        guard let userId = SupabaseManager.shared.currentUserId else { return }
        let queue = XPOutbox.pending(for: userId)
        guard !queue.isEmpty else { return }

        log("🔁 XPStore: flushing \(queue.count) queued award(s)")

        var flushed = 0
        for entry in queue {
            do {
                let result = try await service.award(
                    sourceType: entry.sourceType,
                    sourceId: entry.sourceId,
                    localDate: entry.localDate,
                    correctCount: entry.correctCount,
                    questionCount: entry.questionCount
                )
                XPOutbox.remove(id: entry.id)
                // `recordAward: false` — a drained backlog entry updates the
                // total but must never claim the completion screen's badge.
                apply(result: result, sourceType: entry.sourceType, recordAward: false)
                flushed += 1
            } catch {
                // Almost certainly still offline. Stop rather than hammering the
                // rest of the queue against the same failure; the next trigger
                // picks up where this left off.
                log("↩️ XPStore: flush stopped, \(queue.count - flushed) still queued — \(error.localizedDescription)")
                break
            }
        }

        if flushed > 0 {
            Analytics.capture(Analytics.Event.xpOutboxFlushed, ["count": flushed])
        }
    }

    /// Foreground and reconnect are the two moments a stuck queue can move.
    /// Mirrors the retry wiring AuthManager uses for guest bootstrap
    /// (AuthManager.swift:1794-1807).
    private func observeFlushTriggers() {
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in await self?.flushOutbox() }
            }
            .store(in: &cancellables)

        NetworkMonitor.shared.$isConnected
            .dropFirst()
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor in await self?.flushOutbox() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    /// Called from `SupabaseManager.clearCurrentUser()` on sign-out.
    ///
    /// The queue goes too. A pending award belongs to the account that earned
    /// it, and sign-out is the point where that account's data leaves the
    /// device; keeping it would mean holding one user's activity on a device
    /// someone else may now use. The cost is a queued award lost on an explicit
    /// sign-out while offline, which is a narrow window and a deliberate action.
    func clearCache() {
        let d = UserDefaults.standard
        Self.cacheKeys.forEach { d.removeObject(forKey: $0) }
        totalXP = nil
        lastAward = nil
    }
}
