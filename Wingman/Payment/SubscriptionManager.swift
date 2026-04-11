//
//  SubscriptionManager.swift
//  Wingman
//
//  Created by Adnan Khan on 10/04/2026.
//

import Foundation
import SwiftUI
import Combine
import RevenueCat
import StoreKit

/// SubscriptionManager monitors subscription status and detects expiry
/// It runs periodic checks and emits notifications when subscription state changes
@MainActor
final class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published var isSubscriptionActive: Bool = false
    @Published var subscriptionExpiryDate: Date?
    @Published var lastCheckDate: Date?
    @Published var isCheckingSubscription: Bool = false
    @Published var hasCheckedAtLeastOnce: Bool = false
    
    // MARK: - Notifications
    static let subscriptionExpiredNotification = NSNotification.Name("SubscriptionExpired")
    static let subscriptionRestoredNotification = NSNotification.Name("SubscriptionRestored")
    static let subscriptionStatusChangedNotification = NSNotification.Name("SubscriptionStatusChanged")
    
    // MARK: - Private Properties
    private var periodicCheckTimer: Timer?
    private let checkInterval: TimeInterval = 300 // Check every 5 minutes
    private var lastSubscriptionState: Bool = false
    private var isInitialized: Bool = false
    
    // MARK: - Constants
    private let entitlementID = Constants.ENTITLEMENT_ID
    
    private override init() {
        super.init()
        // Don't setup subscription monitoring here - defer until RevenueCat is configured
    }
    
    deinit {
        // Safely stop timer from non-main-actor context
        if periodicCheckTimer != nil {
            print("⏹️ SubscriptionManager: Stopping periodic subscription checks (deinit)")
            periodicCheckTimer?.invalidate()
            periodicCheckTimer = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup & Configuration
    /// Initialize subscription monitoring - call this AFTER RevenueCat is configured
    func initializeMonitoring() {
        guard !isInitialized else {
            print("ℹ️ SubscriptionManager: Already initialized")
            return
        }
        
        print("📱 SubscriptionManager: Initializing subscription monitoring")
        
        if RevenueCatConfig.useStoreKitTestingMode {
            print("🧪 SubscriptionManager: Using NATIVE STOREKIT (Testing Mode)")
            initializeStoreKitMonitoring()
        } else {
            print("🔗 SubscriptionManager: Using REVENUCAT")
            initializeRevenueCatMonitoring()
        }
        
        isInitialized = true
        
        // Initial check
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    /// Initialize with native StoreKit (for local testing)
    private func initializeStoreKitMonitoring() {
        print("📲 SubscriptionManager: Setting up StoreKit transaction listener")
        
        Task {
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    print("💳 SubscriptionManager: Transaction verified - \(transaction.productID)")
                    await handleStoreKitTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
        
        // Start periodic checks
        startPeriodicChecks()
    }
    
    /// Initialize with RevenueCat
    private func initializeRevenueCatMonitoring() {
        print("🔗 SubscriptionManager: Setting up RevenueCat listener")
        
        // Listen for RevenueCat customer info updates
        Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
            Task { @MainActor in
                self?.handleCustomerInfoUpdate(customerInfo, error: error)
            }
        }
        
        // Start periodic checks
        startPeriodicChecks()
    }
    
    private func setupSubscriptionMonitoring() {
        // This method is no longer needed but keeping signature for reference
        print("⚠️ SubscriptionManager: setupSubscriptionMonitoring() called - use initializeMonitoring() instead")
    }
    
    // MARK: - Subscription Status Checks
    /// Check current subscription status from RevenueCat or StoreKit
    func checkSubscriptionStatus() async {
        print("🔍 SubscriptionManager: Checking subscription status...")
        isCheckingSubscription = true
        
        if RevenueCatConfig.useStoreKitTestingMode {
            await checkStoreKitSubscriptionStatus()
        } else {
            await checkRevenueCatSubscriptionStatus()
        }

        isCheckingSubscription = false
        lastCheckDate = Date()
    }
    
    /// Check subscription status via RevenueCat
    private func checkRevenueCatSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            handleCustomerInfoUpdate(customerInfo, error: nil)
            hasCheckedAtLeastOnce = true
        } catch {
            print("❌ SubscriptionManager: Failed to check RevenueCat subscription: \(error.localizedDescription)")
            hasCheckedAtLeastOnce = true
        }
    }
    
    /// Check subscription status via StoreKit
    private func checkStoreKitSubscriptionStatus() async {
        print("🛍️ SubscriptionManager: Checking StoreKit subscription status...")
        
        var hasActiveSubscription = false
        var latestExpiryDate: Date? = nil
        
        // Check all subscription transactions
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                print("   - Found transaction: \(transaction.productID)")
                if transaction.productID == Constants.YEARLY_PRODUCT_ID ||
                   transaction.productID == Constants.MONTHLY_PRODUCT_ID {
                    hasActiveSubscription = true
                    if let expiryDate = transaction.expirationDate {
                        if latestExpiryDate == nil || expiryDate > latestExpiryDate! {
                            latestExpiryDate = expiryDate
                        }
                    }
                }
            }
        }
        
        print("🛍️ SubscriptionManager: StoreKit check - Active: \(hasActiveSubscription), Expiry: \(latestExpiryDate?.formatted() ?? "None")")
        updateSubscriptionStatus(isActive: hasActiveSubscription, expiryDate: latestExpiryDate)
        hasCheckedAtLeastOnce = true
    }
    
    /// Handle StoreKit transaction updates
    private func handleStoreKitTransaction(_ transaction: StoreKit.Transaction) async {
        print("💳 SubscriptionManager: Handling StoreKit transaction")
        print("   - Product ID: \(transaction.productID)")
        print("   - Expiration Date: \(transaction.expirationDate?.formatted() ?? "No expiry")")
        
        // Re-check subscription status after transaction
        await checkStoreKitSubscriptionStatus()
    }

    
    /// Handle customer info updates from RevisionCat
    private func handleCustomerInfoUpdate(_ customerInfo: CustomerInfo?, error: Error?) {
        guard let customerInfo = customerInfo else {
            print("❌ SubscriptionManager: No customer info received")
            updateSubscriptionStatus(isActive: false, expiryDate: nil)
            return
        }
        
        let entitlement = customerInfo.entitlements[entitlementID]
        let wasActive = lastSubscriptionState
        let isNowActive = entitlement?.isActive == true
        
        print("📊 SubscriptionManager: Entitlement status update")
        print("   - Entitlement ID: \(entitlementID)")
        print("   - Is Active: \(isNowActive)")
        print("   - Expiry Date: \(entitlement?.expirationDate?.formatted() ?? "No expiry")")
        print("   - Is Sandbox: \(entitlement?.isSandbox ?? false)")
        print("   - Previous State: \(wasActive)")
        
        let expiryDate = entitlement?.expirationDate
        updateSubscriptionStatus(isActive: isNowActive, expiryDate: expiryDate)
        
        // Detect state changes
        if wasActive && !isNowActive {
            print("⚠️ SubscriptionManager: Subscription EXPIRED!")
            NotificationCenter.default.post(name: Self.subscriptionExpiredNotification, object: nil)
        } else if !wasActive && isNowActive {
            print("✅ SubscriptionManager: Subscription ACTIVATED!")
            NotificationCenter.default.post(name: Self.subscriptionRestoredNotification, object: nil)
        }
        
        lastSubscriptionState = isNowActive
    }
    
    /// Update the subscription status
    private func updateSubscriptionStatus(isActive: Bool, expiryDate: Date?) {
        let statusChanged = isActive != isSubscriptionActive
        
        self.isSubscriptionActive = isActive
        self.subscriptionExpiryDate = expiryDate
        
        if statusChanged {
            print("🔔 SubscriptionManager: Posting subscription status changed notification")
            NotificationCenter.default.post(name: Self.subscriptionStatusChangedNotification, object: nil)
        }
    }
    
    // MARK: - Periodic Checks
    /// Start periodic subscription checks
    func startPeriodicChecks() {
        print("⏰ SubscriptionManager: Starting periodic subscription checks (every 5 minutes)")
        
        // Stop existing timer if any
        stopPeriodicChecks()
        
        // Start new timer
        periodicCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkSubscriptionStatus()
            }
        }
        
        // Perform initial check immediately
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    /// Stop periodic subscription checks
    func stopPeriodicChecks() {
        if periodicCheckTimer != nil {
            print("⏹️ SubscriptionManager: Stopping periodic subscription checks")
            periodicCheckTimer?.invalidate()
            periodicCheckTimer = nil
        }
    }
    
    // MARK: - Refresh Methods
    /// Force refresh subscription status immediately
    func refreshSubscriptionStatus() async {
        print("🔄 SubscriptionManager: Force refreshing subscription status")
        
        if !RevenueCatConfig.useStoreKitTestingMode {
            Purchases.shared.invalidateCustomerInfoCache()
        }
        
        await checkSubscriptionStatus()
    }
}
