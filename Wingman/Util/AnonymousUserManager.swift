//
//  AnonymousUserManager.swift
//  Wingman
//
//  Created by AI Assistant
//

import Foundation

/// Manages local storage for anonymous users before account creation
class AnonymousUserManager {
    static let shared = AnonymousUserManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let anonymousUserId = "anonymous_user_id"
        static let userName = "anonymous_user_name"
        static let userAge = "anonymous_user_age"
        static let userGoals = "anonymous_user_goals"
        static let referralCode = "anonymous_referral_code"
        static let hasCompletedOnboarding = "anonymous_has_completed_onboarding"
    }
    
    // MARK: - Anonymous User ID
    
    var anonymousUserId: String {
        if let existingId = defaults.string(forKey: Keys.anonymousUserId) {
            return existingId
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: Keys.anonymousUserId)
        return newId
    }
    
    // MARK: - User Data
    
    var userName: String? {
        get { defaults.string(forKey: Keys.userName) }
        set { defaults.set(newValue, forKey: Keys.userName) }
    }
    
    var userAge: String? {
        get { defaults.string(forKey: Keys.userAge) }
        set { defaults.set(newValue, forKey: Keys.userAge) }
    }
    
    var userGoals: String? {
        get { defaults.string(forKey: Keys.userGoals) }
        set { defaults.set(newValue, forKey: Keys.userGoals) }
    }
    
    var referralCode: String? {
        get { defaults.string(forKey: Keys.referralCode) }
        set { defaults.set(newValue, forKey: Keys.referralCode) }
    }
    
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    // MARK: - Clear Data
    
    func clearAllData() {
        defaults.removeObject(forKey: Keys.anonymousUserId)
        defaults.removeObject(forKey: Keys.userName)
        defaults.removeObject(forKey: Keys.userAge)
        defaults.removeObject(forKey: Keys.userGoals)
        defaults.removeObject(forKey: Keys.referralCode)
        defaults.removeObject(forKey: Keys.hasCompletedOnboarding)
        print("🗑️ Cleared all anonymous user data")
    }
    
    // MARK: - Debug
    
    func printCurrentData() {
        print("📱 Anonymous User Data:")
        print("   - ID: \(anonymousUserId)")
        print("   - Name: \(userName ?? "nil")")
        print("   - Age: \(userAge ?? "nil")")
        print("   - Goals: \(userGoals ?? "nil")")
        print("   - Referral: \(referralCode ?? "nil")")
        print("   - Completed: \(hasCompletedOnboarding)")
    }
}
