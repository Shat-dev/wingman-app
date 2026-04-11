//
//  SupabaseManager.swift
//  Wingman
//

import Foundation
import Supabase

// MARK: - Supabase Manager
final class SupabaseManager {
    
    static let shared = SupabaseManager()
    
    // MARK: - Configuration
    // Replace these with your actual Supabase credentials
    private let supabaseURL = URL(string: "https://bnckmgnysfliiypvxxii.supabase.co")!
    private let supabaseKey = "sb_publishable_B1an-2PeSHETguChW_Xdxg_50UYkPtb"
    
    // MARK: - Client
    lazy var client: SupabaseClient = {
        return SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: false  // Disable auto-refresh to prevent hanging when offline
                )
            )
        )
    }()
    
    private init() {}
    
    // MARK: - Authentication Helpers
    var currentUserId: String? {
        return UserDefaults.standard.string(forKey: "current_user_id")
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
            "goal_notifications"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
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

 -- user_profiles table
 CREATE TABLE user_profiles (
     id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
     name TEXT NOT NULL,
     avatar_index INTEGER DEFAULT 0,
     email TEXT,
     created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
 );

 -- Row Level Security for profiles
 ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

 CREATE POLICY "Users can view their own profile"
     ON user_profiles FOR SELECT
     USING (auth.uid() = id);

 CREATE POLICY "Users can update their own profile"
     ON user_profiles FOR UPDATE
     USING (auth.uid() = id);

 CREATE POLICY "Users can insert their own profile"
     ON user_profiles FOR INSERT
     WITH CHECK (auth.uid() = id);

 CREATE POLICY "Users can delete their own profile"
     ON user_profiles FOR DELETE
     USING (auth.uid() = id);

 */
