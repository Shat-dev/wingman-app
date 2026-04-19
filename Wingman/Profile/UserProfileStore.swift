//
//  UserProfileStore.swift
//  Wingman
//
//  Single source of truth for the user's display name on the client.
//  Mirrors the StreakStore pattern:
//   - Persists last-known value to UserDefaults so views render instantly
//     from cache on entry (fixes the Profile name flash-of-empty).
//   - Never overwrites an existing value on refresh failure.
//   - Publishes changes so every view bound to it updates instantly when
//     a new name is saved via EditProfileSheet or synced from Supabase.
//

import Foundation
import Supabase
import Combine

@MainActor
final class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()

    // MARK: - Published State
    // Optional so the UI can distinguish "not loaded yet" (nil) from "loaded empty".
    @Published private(set) var displayName: String?
    @Published private(set) var isRefreshing: Bool = false

    // MARK: - Cache Keys
    // New canonical key. Kept distinct from the legacy "user_name" key so the
    // two do not fight each other; writes go to BOTH for backward compatibility
    // with existing readers (EditProfileSheet, Apple Sign-In flow).
    static let displayNameKey = "profile_cache_display_name"
    static let legacyUserNameKey = "user_name"
    static let cacheKeys = [displayNameKey]

    private init() {
        loadFromCache()
    }

    // MARK: - Cache I/O

    private func loadFromCache() {
        let d = UserDefaults.standard
        if let cached = d.string(forKey: Self.displayNameKey) {
            displayName = cached
        } else if let legacy = d.string(forKey: Self.legacyUserNameKey), !legacy.isEmpty {
            // Migration: if the legacy cache has a value but the new one
            // doesn't, seed from the legacy key so existing users don't
            // flash-to-empty on the first launch after this ships.
            displayName = legacy
        } else if let metadataName = SupabaseManager.shared.client.auth
                    .currentUser?.userMetadata["display_name"]?.stringValue,
                  !metadataName.isEmpty {
            // Both UserDefaults caches empty (e.g. email sign-in on a new
            // device, or fresh install of an existing account — neither path
            // calls apply(name:)). Fall back to the Supabase SDK's restored
            // session metadata, which is already in-memory by the time this
            // runs since the singleton is first instantiated after
            // MainTabView renders (post `restoreSessionGracefully`).
            // Without this, ProfileView flashes empty until refresh() lands.
            // Persist to cache so next cold start hits the fast path above.
            displayName = metadataName
            saveToCache(metadataName)
        }
        log("📦 UserProfileStore: seeded from cache — displayName=\(displayName ?? "nil")")
    }

    private func saveToCache(_ name: String) {
        let d = UserDefaults.standard
        d.set(name, forKey: Self.displayNameKey)
        // Keep the legacy key in sync for any external reader still using it.
        d.set(name, forKey: Self.legacyUserNameKey)
    }

    // MARK: - Refresh (network)

    /// Fetch the latest display name from Supabase auth metadata.
    /// On failure, leaves existing cached value intact — never wipes.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let user = try await SupabaseManager.shared.client.auth.user()
            if let name = user.userMetadata["display_name"]?.stringValue, !name.isEmpty {
                displayName = name
                saveToCache(name)
                log("✅ UserProfileStore: refreshed from Supabase — \(name)")
            } else {
                // Metadata has no display_name. Leave the cached value as-is
                // rather than overwriting to nil — the cache is still the best
                // thing we have for display.
                log("ℹ️ UserProfileStore: Supabase metadata has no display_name; keeping cached value")
            }
        } catch {
            log("❌ UserProfileStore: refresh failed, keeping cached value — \(error.localizedDescription)")
        }
    }

    // MARK: - External writes

    /// Called after a successful Supabase write elsewhere (EditProfileSheet,
    /// onboarding loading screen, anonymous sync) to push the authoritative
    /// new value into the store without a round-trip.
    func apply(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        saveToCache(trimmed)
    }

    // MARK: - Lifecycle

    /// Called from SupabaseManager.clearCurrentUser() on logout.
    func clearCache() {
        let d = UserDefaults.standard
        Self.cacheKeys.forEach { d.removeObject(forKey: $0) }
        // Note: the legacy "user_name" key is cleared by clearCurrentUser()
        // already — we do not double-handle it here.
        displayName = nil
    }
}
