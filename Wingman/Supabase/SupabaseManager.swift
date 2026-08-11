//
//  SupabaseManager.swift
//  Wingman
//

import Foundation
import Supabase

// MARK: - Supabase Manager
final class SupabaseManager {
    
    nonisolated static let shared = SupabaseManager()

    // MARK: - Configuration
    // Replace these with your actual Supabase credentials
    private static let supabaseURL: URL = {
        guard let url = URL(string: "https://bnckmgnysfliiypvxxii.supabase.co") else {
            preconditionFailure("Invalid Supabase URL — configuration error")
        }
        return url
    }()
    private static let supabaseKey = "sb_publishable_B1an-2PeSHETguChW_Xdxg_50UYkPtb"

    // MARK: - Client
    // nonisolated + eagerly-initialized `let` (rather than `lazy var`) so the
    // client can be read from nonisolated contexts — a mutable stored property
    // can't be marked `nonisolated` directly. SupabaseClient is itself Sendable
    // (uses internal locking), so this is safe.
    nonisolated let client: SupabaseClient = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                autoRefreshToken: false  // Disable auto-refresh to prevent hanging when offline
            )
        )
    )

    private init() {}
    
    // MARK: - Authentication Helpers
    /// Single source of truth for the current Supabase user ID.
    /// Reads directly from the Supabase SDK's in-memory session (backed by
    /// keychain), so it is always consistent with `client.auth.currentUser`.
    /// No UserDefaults cache — eliminates the class of bug where the cache
    /// could get out of sync with the SDK (e.g. after `.initialSession`
    /// restoration or after a fresh install with a keychain-persisted session).
    var currentUserId: String? {
        return client.auth.currentUser?.id.uuidString
    }

    var isAuthenticated: Bool {
        return currentUserId != nil
    }
    
    func setCurrentUser(id: String, email: String?) {
        UserDefaults.standard.set(id, forKey: "current_user_id")
        if let email = email {
            UserDefaults.standard.set(email, forKey: "user_email")
        }
    }
    
    func clearCurrentUser() {
        let keys = [
            "current_user_id",
            "user_email",
            "user_name",
            "user_avatar_index",
            "total_approaches",
            "current_streak",
            "best_streak",
            "last_practice_date",
            "daily_reading_goal",
            "goal_notifications",
            // The name typed on the onboarding name screen. It belongs to the
            // session that produced it: the commitment pact reads it, and
            // Apple sign-in treats its presence as "this user already told us
            // what to call them" and declines to overwrite. Left behind, the
            // next person to sign in on this device would inherit both.
            OnboardingNameKey.defaultsKey
        ] + StreakStore.cacheKeys + UserProfileStore.cacheKeys
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        // Also wipe in-memory cache on the shared stores so a subsequent
        // login on the same session doesn't briefly show the previous user's
        // streak or name.
        Task { @MainActor in
            StreakStore.shared.clearCache()
            UserProfileStore.shared.clearCache()
            // Scenario lock/completion state is per-user and the store is now
            // app-wide (it used to die with PracticeView on logout).
            PracticeViewModel.shared.clearCache()
        }
    }
}

// MARK: - Database Schema Reference
/*
 
 -- approach_logs table
 CREATE TABLE approach_logs (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
     title TEXT NOT NULL,
     approach_level INTEGER NOT NULL CHECK (approach_level BETWEEN 1 AND 4),
     anxiety_level INTEGER NOT NULL CHECK (anxiety_level BETWEEN 1 AND 10),
     notes TEXT,
     logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
     updated_at TIMESTAMPTZ,
     created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
 );

 -- Create index for faster queries
 CREATE INDEX idx_approach_logs_user_id ON approach_logs(user_id);
 CREATE INDEX idx_approach_logs_logged_at ON approach_logs(logged_at DESC);

 -- Row Level Security
 ALTER TABLE approach_logs ENABLE ROW LEVEL SECURITY;

 CREATE POLICY "Users can view their own approach logs"
     ON approach_logs FOR SELECT
     USING (auth.uid() = user_id);

 CREATE POLICY "Users can insert their own approach logs"
     ON approach_logs FOR INSERT
     WITH CHECK (auth.uid() = user_id);

 CREATE POLICY "Users can update their own approach logs"
     ON approach_logs FOR UPDATE
     USING (auth.uid() = user_id);

 CREATE POLICY "Users can delete their own approach logs"
     ON approach_logs FOR DELETE
     USING (auth.uid() = user_id);

 -- Note: user profile fields (display_name, avatar_index, age, goals) are
 -- stored on `auth.users.user_metadata` via `client.auth.update(user:)`.
 -- No separate `user_profiles` table exists in this project — writes go
 -- through Supabase's built-in auth metadata.

 */
