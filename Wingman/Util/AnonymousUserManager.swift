//
//  AnonymousUserManager.swift
//  Wingman
//
//  Created by AI Assistant
//

import Foundation
import RevenueCat

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
        static let revenueCatCustomerId = "anonymous_revenueCat_customer_id"
        static let hasActivePurchase = "anonymous_has_active_purchase"
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
    
    // MARK: - RevenueCat Data
    
    var revenueCatCustomerId: String? {
        get { defaults.string(forKey: Keys.revenueCatCustomerId) }
        set {
            defaults.set(newValue, forKey: Keys.revenueCatCustomerId)
            log("💰 AnonymousUserManager: RevenueCat customer ID stored: \(newValue ?? "nil")")
        }
    }
    
    var hasActivePurchase: Bool {
        get { defaults.bool(forKey: Keys.hasActivePurchase) }
        set {
            defaults.set(newValue, forKey: Keys.hasActivePurchase)
            log("💰 AnonymousUserManager: Active purchase status: \(newValue)")
        }
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
    
    // MARK: - RevenueCat Methods
    
    /// Store RevenueCat customer info after purchase
    func storeRevenueCatPurchase(customerInfo: CustomerInfo) {
        revenueCatCustomerId = customerInfo.originalAppUserId
        hasActivePurchase = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
        log("💰 AnonymousUserManager: Stored purchase info for customer: \(customerInfo.originalAppUserId)")
    }
    
    /// Check if anonymous user has a purchase that needs to be linked
    var needsRevenueCatLinking: Bool {
        return revenueCatCustomerId != nil && hasActivePurchase
    }
    
    // MARK: - Clear Data
    
    func clearAllData() {
        defaults.removeObject(forKey: Keys.anonymousUserId)
        defaults.removeObject(forKey: Keys.userName)
        defaults.removeObject(forKey: Keys.userAge)
        defaults.removeObject(forKey: Keys.userGoals)
        defaults.removeObject(forKey: Keys.referralCode)
        defaults.removeObject(forKey: Keys.hasCompletedOnboarding)
        defaults.removeObject(forKey: Keys.revenueCatCustomerId)
        defaults.removeObject(forKey: Keys.hasActivePurchase)
        log("🗑️ Cleared all anonymous user data including RevenueCat info")
    }
    
    // MARK: - Debug
    
    func printCurrentData() {
        log("📱 Anonymous User Data:")
        log("   - ID: \(anonymousUserId)")
        log("   - Name: \(userName ?? "nil")")
        log("   - Age: \(userAge ?? "nil")")
        log("   - Goals: \(userGoals ?? "nil")")
        log("   - Referral: \(referralCode ?? "nil")")
        log("   - Completed: \(hasCompletedOnboarding)")
        log("   - RevenueCat Customer: \(revenueCatCustomerId ?? "nil")")
        log("   - Has Purchase: \(hasActivePurchase)")
    }
}
