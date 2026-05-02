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

    // MARK: - Cache Keys
    //
    // Global (not per-user) because Apple subscriptions are tied to Apple ID
    // and persist across our app-user sign-ins on the same device. A second
    // user signing into the app on a shared device inherits the same Apple
    // subscription state, which is correct — the entitlement is device-scoped.
    private let cacheKeyActive = "cached_subscription_active"
    private let cacheKeyExpiry = "cached_subscription_expiry"

    private override init() {
        super.init()
        // Don't setup subscription monitoring here - defer until RevenueCat is configured
    }
    
    deinit {
        // Safely stop timer from non-main-actor context
        if periodicCheckTimer != nil {
            log("⏹️ SubscriptionManager: Stopping periodic subscription checks (deinit)")
            periodicCheckTimer?.invalidate()
            periodicCheckTimer = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup & Configuration
    /// Initialize subscription monitoring - call this AFTER RevenueCat is configured
    func initializeMonitoring() {
        guard !isInitialized else {
            log("ℹ️ SubscriptionManager: Already initialized")
            return
        }

        log("📱 SubscriptionManager: Initializing subscription monitoring")

        // Load persisted subscription state synchronously BEFORE kicking off
        // the RC/StoreKit network check. This prevents the cold-start window
        // where `isSubscriptionActive` defaults to false until RC responds —
        // during that window a paying user would be treated as unpaid by
        // feature gates. Offline, that window would be the full RC timeout
        // (~30s) resolving to "unpaid" indefinitely. The cache gives us a
        // correct answer instantly; the network check below refines it.
        loadSubscriptionCache()

        if RevenueCatConfig.useStoreKitTestingMode {
            log("🧪 SubscriptionManager: Using NATIVE STOREKIT (Testing Mode)")
            initializeStoreKitMonitoring()
        } else {
            log("🔗 SubscriptionManager: Using REVENUCAT")
            initializeRevenueCatMonitoring()
        }

        isInitialized = true

        // Initial check is performed inside startPeriodicChecks() (called by
        // initializeStoreKitMonitoring / initializeRevenueCatMonitoring above),
        // so we don't fire another one here — doing both sent two identical
        // RevenueCat/StoreKit round-trips on every cold start.
    }
    
    /// Initialize with native StoreKit (for local testing)
    private func initializeStoreKitMonitoring() {
        log("📲 SubscriptionManager: Setting up StoreKit transaction listener")
        
        Task {
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    log("💳 SubscriptionManager: Transaction verified - \(transaction.productID)")
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
        log("🔗 SubscriptionManager: Setting up RevenueCat listener")
        
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
        log("⚠️ SubscriptionManager: setupSubscriptionMonitoring() called - use initializeMonitoring() instead")
    }
    
    // MARK: - Subscription Status Checks
    /// Check current subscription status from RevenueCat or StoreKit
    func checkSubscriptionStatus() async {
        log("🔍 SubscriptionManager: Checking subscription status...")
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
            log("❌ SubscriptionManager: Failed to check RevenueCat subscription: \(error.localizedDescription)")
            hasCheckedAtLeastOnce = true
        }
    }
    
    /// Check subscription status via StoreKit
    private func checkStoreKitSubscriptionStatus() async {
        log("🛍️ SubscriptionManager: Checking StoreKit subscription status...")
        
        var hasActiveSubscription = false
        var latestExpiryDate: Date? = nil
        
        // Check all subscription transactions
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                log("   - Found transaction: \(transaction.productID)")
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
        
        log("🛍️ SubscriptionManager: StoreKit check - Active: \(hasActiveSubscription), Expiry: \(latestExpiryDate?.formatted() ?? "None")")
        updateSubscriptionStatus(isActive: hasActiveSubscription, expiryDate: latestExpiryDate)
        hasCheckedAtLeastOnce = true
    }
    
    /// Handle StoreKit transaction updates
    private func handleStoreKitTransaction(_ transaction: StoreKit.Transaction) async {
        log("💳 SubscriptionManager: Handling StoreKit transaction")
        log("   - Product ID: \(transaction.productID)")
        log("   - Expiration Date: \(transaction.expirationDate?.formatted() ?? "No expiry")")
        
        // Re-check subscription status after transaction
        await checkStoreKitSubscriptionStatus()
    }

    
    /// Handle customer info updates from RevisionCat
    func handleCustomerInfoUpdate(_ customerInfo: CustomerInfo?, error: Error?) {
        guard let customerInfo = customerInfo else {
            log("❌ SubscriptionManager: No customer info received")
            updateSubscriptionStatus(isActive: false, expiryDate: nil)
            return
        }
        
        let entitlement = customerInfo.entitlements[entitlementID]
        let wasActive = lastSubscriptionState
        let isNowActive = entitlement?.isActive == true
        
        log("📊 SubscriptionManager: Entitlement status update")
        log("   - Entitlement ID: \(entitlementID)")
        log("   - Is Active: \(isNowActive)")
        log("   - Expiry Date: \(entitlement?.expirationDate?.formatted() ?? "No expiry")")
        log("   - Is Sandbox: \(entitlement?.isSandbox ?? false)")
        log("   - Previous State: \(wasActive)")
        
        let expiryDate = entitlement?.expirationDate
        updateSubscriptionStatus(isActive: isNowActive, expiryDate: expiryDate)
        
        // Detect state changes
        if wasActive && !isNowActive {
            log("⚠️ SubscriptionManager: Subscription EXPIRED!")
            NotificationCenter.default.post(name: Self.subscriptionExpiredNotification, object: nil)
        } else if !wasActive && isNowActive {
            log("✅ SubscriptionManager: Subscription ACTIVATED!")
            NotificationCenter.default.post(name: Self.subscriptionRestoredNotification, object: nil)
        }
        
        lastSubscriptionState = isNowActive
    }
    
    /// Update the subscription status
    private func updateSubscriptionStatus(isActive: Bool, expiryDate: Date?) {
        self.isSubscriptionActive = isActive
        self.subscriptionExpiryDate = expiryDate

        // Persist to cache so the next cold start can read last-known state
        // synchronously during init (see loadSubscriptionCache below).
        writeSubscriptionCache(isActive: isActive, expiryDate: expiryDate)

        // Always post — not just on transitions. The previous transition-only
        // gate (`isActive != isSubscriptionActive`) silently dropped the
        // notification when SubscriptionManager already had the right value
        // but a downstream observer (AuthManager.hasActiveSubscription, which
        // defaults to false at init) hadn't yet been seeded. The result was a
        // paying user whose RC entitlement was confirmed active but whose
        // AuthManager flag stayed false until the next real transition. The
        // sole observer (AuthManager.subscriptionStatusChanged → syncSubscriptionStatus)
        // is idempotent — copying two properties — so firing on every update
        // costs nothing and closes the seeding gap.
        NotificationCenter.default.post(name: Self.subscriptionStatusChangedNotification, object: nil)
    }

    // MARK: - Subscription Cache (offline-safe cold start)
    //
    // Purpose: gated features read `isSubscriptionActive`. At cold start this
    // defaults to false and the real answer arrives only after a RevenueCat
    // network round-trip (or longer, if offline). Without a cache, a paying
    // user would see paywalls during that window. We persist the last-known
    // active state + expiry date and replay it at init. The live RC check
    // still runs and corrects the answer if anything changed.
    //
    // Tamper consideration: UserDefaults is readable/writable by a determined
    // user with file-system access. For a freemium content app with locally
    // bundled content, this isn't a meaningful new attack surface — a
    // tampering user can already strip gates entirely from the IPA.

    private func writeSubscriptionCache(isActive: Bool, expiryDate: Date?) {
        UserDefaults.standard.set(isActive, forKey: cacheKeyActive)
        if let expiryDate = expiryDate {
            UserDefaults.standard.set(expiryDate, forKey: cacheKeyExpiry)
        } else {
            UserDefaults.standard.removeObject(forKey: cacheKeyExpiry)
        }
    }

    /// Reads the persisted subscription state into the live @Published
    /// properties. Applies a clock check so a stale "active" cache whose
    /// expiry has passed is correctly treated as inactive — we don't need
    /// the network to know a date is in the past.
    ///
    /// Sets `hasCheckedAtLeastOnce = true` so gated UI doesn't block waiting
    /// on the network round-trip; the cache IS our first check, the RC call
    /// that follows is a refinement.
    private func loadSubscriptionCache() {
        let cachedActive = UserDefaults.standard.bool(forKey: cacheKeyActive)
        let cachedExpiry = UserDefaults.standard.object(forKey: cacheKeyExpiry) as? Date

        // Clock check: if cache says active but the stored expiry has passed,
        // the subscription lapsed while the app wasn't observing. Treat as
        // inactive. (No expiry stored + active = treat as active; covers
        // lifetime / non-expiring entitlements.)
        let effectiveActive: Bool
        if cachedActive, let expiry = cachedExpiry, expiry <= Date() {
            effectiveActive = false
        } else {
            effectiveActive = cachedActive
        }

        self.isSubscriptionActive = effectiveActive
        self.subscriptionExpiryDate = cachedExpiry
        // Seed the transition-detection state so the subsequent network
        // check's handleCustomerInfoUpdate doesn't misfire an "expired" or
        // "restored" notification for what is really just our cache catching
        // up to network reality.
        self.lastSubscriptionState = effectiveActive
        self.hasCheckedAtLeastOnce = true

        log("💾 SubscriptionManager: Loaded cached subscription — rawActive=\(cachedActive), effectiveActive=\(effectiveActive), expiry=\(cachedExpiry?.formatted() ?? "nil")")
    }
    
    // MARK: - Periodic Checks
    /// Start periodic subscription checks
    func startPeriodicChecks() {
        log("⏰ SubscriptionManager: Starting periodic subscription checks (every 5 minutes)")
        
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
            log("⏹️ SubscriptionManager: Stopping periodic subscription checks")
            periodicCheckTimer?.invalidate()
            periodicCheckTimer = nil
        }
    }
    
    // MARK: - Refresh Methods
    /// Force refresh subscription status immediately
    func refreshSubscriptionStatus() async {
        log("🔄 SubscriptionManager: Force refreshing subscription status")
        
        if !RevenueCatConfig.useStoreKitTestingMode {
            Purchases.shared.invalidateCustomerInfoCache()
        }
        
        await checkSubscriptionStatus()
    }
}
