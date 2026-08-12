//
//  StreakStore.swift
//  Wingman
//
//  Single source of truth for daily-practice streak state on the client.
//  - Persists last-known values to UserDefaults so views can render instantly
//    from cache before a network refresh completes (fixes "flash of 0").
//  - Never overwrites existing values on refresh failure (preserves last-known-good).
//  - Mirrors writes from HomeViewModel (status fetch) and DailyPracticeViewModel
//    (completion result) so every successful read/write keeps the cache fresh.
//

import Foundation
import Supabase
import Combine

@MainActor
final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    // MARK: - Published State
    // Optional so the UI can distinguish "never loaded" (nil) from "loaded and zero".
    @Published private(set) var currentStreak: Int?
    @Published private(set) var totalCompleted: Int?
    /// All-time best run, for Profile's "Top streak" tile.
    ///
    /// `user_daily_practice_streaks.longest_streak` has been maintained by
    /// `update_daily_practice_streak` since the beginning but nothing ever read
    /// it — the streak RPC does not return it. Read directly off the table
    /// rather than by widening `get_daily_practice_status`, which would mean a
    /// DROP and CREATE of a function Home depends on for a value only Profile
    /// wants. RLS on that table already scopes it to `auth.uid() = user_id`.
    @Published private(set) var longestStreak: Int?
    @Published private(set) var completedDates: Set<String> = []
    @Published private(set) var isRefreshing: Bool = false

    /// The streak advance produced by one specific completion.
    ///
    /// Carries `sourceId` for the same reason `XPStore.Award` does: a
    /// completion screen must be able to tell its own result from the previous
    /// one, or a lesson finished minutes ago decorates the next screen.
    @Published private(set) var lastAdvance: Advance?

    struct Advance: Equatable {
        let sourceId: String
        let streak: Int
        /// False when the day was already counted, so the screen can say "5 day
        /// streak" without implying this completion is what earned it.
        let didExtend: Bool
    }

    // MARK: - Dependencies
    private let practiceService: DailyPracticeServiceProtocol = DailyPracticeService()
    private let client = SupabaseManager.shared.client

    // MARK: - Cache Keys
    // Kept in sync with SupabaseManager.clearCurrentUser() so cache is wiped on logout.
    static let currentStreakKey  = "streak_cache_current"
    static let totalCompletedKey = "streak_cache_total_completed"
    static let completedDatesKey = "streak_cache_completed_dates"
    static let longestStreakKey  = "streak_cache_longest"
    static let cacheKeys = [currentStreakKey, totalCompletedKey, completedDatesKey, longestStreakKey]

    private init() {
        loadFromCache()
    }

    // MARK: - Cache I/O

    private func loadFromCache() {
        let d = UserDefaults.standard
        if d.object(forKey: Self.currentStreakKey) != nil {
            currentStreak = d.integer(forKey: Self.currentStreakKey)
        }
        if d.object(forKey: Self.totalCompletedKey) != nil {
            totalCompleted = d.integer(forKey: Self.totalCompletedKey)
        }
        if let arr = d.array(forKey: Self.completedDatesKey) as? [String] {
            completedDates = Set(arr)
        }
        if d.object(forKey: Self.longestStreakKey) != nil {
            longestStreak = d.integer(forKey: Self.longestStreakKey)
        }
        log("📦 StreakStore: seeded from cache — current=\(currentStreak.map(String.init) ?? "nil") total=\(totalCompleted.map(String.init) ?? "nil") dates=\(completedDates.count)")
    }

    private func saveToCache() {
        let d = UserDefaults.standard
        if let c = currentStreak { d.set(c, forKey: Self.currentStreakKey) }
        if let t = totalCompleted { d.set(t, forKey: Self.totalCompletedKey) }
        if let l = longestStreak { d.set(l, forKey: Self.longestStreakKey) }
        d.set(Array(completedDates), forKey: Self.completedDatesKey)
    }

    // MARK: - Refresh (network)

    /// Fetch latest streak status + weekly completed dates from Supabase.
    /// On failure, leaves existing values intact — never wipes to 0.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let status = try await practiceService.getDailyPracticeStatus()
            currentStreak = status.streak
            totalCompleted = status.completed

            // Weekly dates are a best-effort fetch; partial success is allowed.
            if let dates = try? await fetchCompletedDatesForCurrentWeek() {
                completedDates = dates
            }

            // Same contract: best-effort, never clobbers a good value with nil.
            // `update_daily_practice_streak` does not return `longest_streak`,
            // so this is the only path that refreshes it — which is fine,
            // Profile calls `refresh()` on every appearance.
            if let longest = try? await fetchLongestStreak() {
                longestStreak = longest
            }

            saveToCache()
            log("✅ StreakStore: refresh ok — current=\(status.streak) total=\(status.completed) dates=\(completedDates.count)")
        } catch {
            // Preserve last-known values. Do not overwrite to 0.
            log("❌ StreakStore: refresh failed, keeping cached values — \(error.localizedDescription)")
        }
    }

    // MARK: - External writes (avoid duplicate RPC round-trips)

    /// Called by HomeViewModel after it fetches `getDailyPracticeStatus` for its
    /// own button-state needs, so the store stays in sync without another RPC.
    func apply(status: DailyPracticeStatus) {
        currentStreak = status.streak
        totalCompleted = status.completed
        saveToCache()
    }

    /// Called by DailyPracticeViewModel after a completion `update_daily_practice_streak`
    /// call succeeds, so Profile sees the new streak immediately on re-entry.
    func apply(updateResult: StreakUpdateResult) {
        currentStreak = updateResult.streak
        totalCompleted = updateResult.completed
        // Also mark today as completed in the weekly set.
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        completedDates.insert(fmt.string(from: Date()))
        saveToCache()
    }

    // MARK: - Lifecycle

    /// Invoked from SupabaseManager.clearCurrentUser() to wipe in-memory cache
    /// alongside UserDefaults on logout.
    func clearCache() {
        let d = UserDefaults.standard
        Self.cacheKeys.forEach { d.removeObject(forKey: $0) }
        currentStreak = nil
        totalCompleted = nil
        completedDates = []
        longestStreak = nil
        lastAdvance = nil
    }

    // MARK: - Activity (lessons and scenarios)

    /// Records that the user did something today that counts toward the streak.
    ///
    /// Separate from `update_daily_practice_streak`, which also writes a
    /// `user_daily_practice_sessions` row — that table is Home's "practised
    /// today" flag, and a lesson writing to it would disable the Daily Practice
    /// button. `mark_streak_activity` moves only the streak.
    ///
    /// Never throws. A lesson must not fail because its streak write did.
    func noteActivity(sourceId: String) async {
        guard SupabaseManager.shared.currentUserId != nil else {
            log("⚠️ StreakStore: no session, skipping streak activity for \(sourceId)")
            return
        }

        // Drop any advance left over from an earlier completion, so a screen
        // waiting on its own result never renders someone else's.
        lastAdvance = nil

        do {
            let rows: [StreakActivityRow] = try await client
                .rpc("mark_streak_activity", params: MarkStreakParams(p_local_date: Self.streakDateToday()))
                .execute()
                .value

            guard let row = rows.first else {
                log("⚠️ StreakStore: mark_streak_activity returned no rows")
                return
            }

            currentStreak = row.currentStreak
            longestStreak = row.longestStreak
            lastAdvance = Advance(sourceId: sourceId, streak: row.currentStreak, didExtend: row.didExtend)
            saveToCache()

            log("🔥 StreakStore: activity \(sourceId) — streak=\(row.currentStreak) extended=\(row.didExtend)")
        } catch {
            // Fire and forget. There is no retry queue for the streak, the same
            // as the daily-practice path, so an offline lesson does not count.
            log("❌ StreakStore: streak activity failed for \(sourceId) — \(error.localizedDescription)")
        }
    }

    /// Today, formatted exactly as `DailyPracticeService.getCurrentLocalDate()`
    /// formats it.
    ///
    /// **Deliberately does NOT pin the locale**, unlike `XPLocalDate`. Both
    /// writers stamp `last_completed_date`, and the streak arithmetic compares
    /// those stamps to each other — so they have to agree. On a device set to a
    /// non-Gregorian calendar the existing writer produces e.g. `2569-08-13`;
    /// pinning Gregorian here would write `2026-08-13`, and the two would read
    /// as a 500-year gap and reset the user's streak on every alternate
    /// completion. Matching the existing behaviour beats being right alone.
    /// Fixing both together is a separate change.
    private static func streakDateToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    // MARK: - Private helpers

    private func fetchLongestStreak() async throws -> Int? {
        guard let userId = SupabaseManager.shared.currentUserId else { return nil }

        let rows: [LongestStreakRow] = try await client
            .from("user_daily_practice_streaks")
            .select("longest_streak")
            .eq("user_id", value: userId)
            .execute()
            .value

        return rows.first?.longestStreak
    }

    private func fetchCompletedDatesForCurrentWeek() async throws -> Set<String> {
        guard let userId = SupabaseManager.shared.currentUserId else {
            return []
        }

        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromSunday, to: today),
              let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
            return []
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let startStr = fmt.string(from: startOfWeek)
        let endStr = fmt.string(from: endOfWeek)

        let sessions: [StreakSessionRow] = try await client
            .from("user_daily_practice_sessions")
            .select("date")
            .eq("user_id", value: userId)
            .gte("date", value: startStr)
            .lte("date", value: endStr)
            .execute()
            .value

        return Set(sessions.map { $0.date })
    }
}

private struct StreakSessionRow: Decodable {
    let date: String
}

private struct MarkStreakParams: nonisolated Encodable, Sendable {
    let p_local_date: String
}

private struct StreakActivityRow: Decodable {
    let currentStreak: Int
    let longestStreak: Int
    let didExtend: Bool

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case didExtend     = "did_extend"
    }
}

private struct LongestStreakRow: Decodable {
    let longestStreak: Int

    enum CodingKeys: String, CodingKey {
        case longestStreak = "longest_streak"
    }
}
