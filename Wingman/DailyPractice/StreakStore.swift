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
    @Published private(set) var completedDates: Set<String> = []
    @Published private(set) var isRefreshing: Bool = false

    // MARK: - Dependencies
    private let practiceService: DailyPracticeServiceProtocol = DailyPracticeService()
    private let client = SupabaseManager.shared.client

    // MARK: - Cache Keys
    // Kept in sync with SupabaseManager.clearCurrentUser() so cache is wiped on logout.
    static let currentStreakKey  = "streak_cache_current"
    static let totalCompletedKey = "streak_cache_total_completed"
    static let completedDatesKey = "streak_cache_completed_dates"
    static let cacheKeys = [currentStreakKey, totalCompletedKey, completedDatesKey]

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
        log("📦 StreakStore: seeded from cache — current=\(currentStreak.map(String.init) ?? "nil") total=\(totalCompleted.map(String.init) ?? "nil") dates=\(completedDates.count)")
    }

    private func saveToCache() {
        let d = UserDefaults.standard
        if let c = currentStreak { d.set(c, forKey: Self.currentStreakKey) }
        if let t = totalCompleted { d.set(t, forKey: Self.totalCompletedKey) }
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
    }

    // MARK: - Private helpers

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
