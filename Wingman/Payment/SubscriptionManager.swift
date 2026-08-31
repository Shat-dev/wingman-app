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

    /// True while the active entitlement is a free trial — i.e. the user has
    /// an entitlement but has paid nothing for it yet.
    ///
    /// `isSubscriptionActive` cannot answer this: it is true for a trialist
    /// and a payer alike, which is correct for feature gating (both get the
    /// content) and wrong for anything that cares whether money changed hands.
    /// `ReviewPromptManager` is the first such caller.
    ///
    /// Defaults to false, and a false value is only meaningful alongside
    /// `isSubscriptionActive == true`. Not cached across launches on purpose —
    /// unlike the active flag, nothing user-facing blocks on it during the
    /// cold-start window, and a stale "not in trial" would be the one error
    /// that matters.
    @Published private(set) var isInTrial: Bool = false

    /// When money last actually left the user's account for this entitlement.
    ///
    /// Sourced from RevenueCat's `latestPurchaseDate` while the entitlement is
    /// in a **paid** period (`periodType == .normal`), so a trial start never
    /// sets it — only the conversion charge does, and every renewal after that
    /// moves it forward.
    ///
    /// Cached like `isSubscriptionActive`, and for the same reason: it is a
    /// date the caller needs at cold start, and waiting on a RevenueCat
    /// round-trip to learn a timestamp we already knew is pure latency. Never
    /// cleared on expiry — "when were they last charged" stays true after the
    /// subscription lapses, and clearing it would silently re-arm anything
    /// gating on elapsed time.
    @Published private(set) var lastPaidChargeAt: Date?
    
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
    private let cacheKeyLastCharge = "cached_subscription_last_paid_charge"

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
        var isTrialCharge = false
        var paidChargeDate: Date? = nil
        
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
                    if isIntroductoryOffer(transaction) {
                        isTrialCharge = true
                    } else if paidChargeDate == nil || transaction.purchaseDate > paidChargeDate! {
                        paidChargeDate = transaction.purchaseDate
                    }
                }
            }
        }
        
        log("🛍️ SubscriptionManager: StoreKit check - Active: \(hasActiveSubscription), Expiry: \(latestExpiryDate?.formatted() ?? "None")")
        updateSubscriptionStatus(isActive: hasActiveSubscription, expiryDate: latestExpiryDate)

        // Mirror of `updateBillingPeriod` for the local-StoreKit path, so a
        // developer testing with a StoreKit configuration file gets the same
        // trial/paid split RevenueCat provides. `paidChargeDate` stays nil for
        // an introductory (trial) transaction, which is the same rule as
        // `periodType == .normal` on the RevenueCat side.
        isInTrial = hasActiveSubscription && isTrialCharge
        if let paidChargeDate, lastPaidChargeAt == nil || paidChargeDate > lastPaidChargeAt! {
            lastPaidChargeAt = paidChargeDate
            UserDefaults.standard.set(paidChargeDate, forKey: cacheKeyLastCharge)
        }

        hasCheckedAtLeastOnce = true
    }
    
    /// Whether a transaction is currently running on an introductory offer —
    /// the local-StoreKit equivalent of RevenueCat's `periodType == .trial`.
    ///
    /// Two branches because the deployment target is iOS 16.6 while
    /// `Transaction.offer` only exists from 17.2. The `offerType` fallback is
    /// deprecated in favour of it, and that deprecation warning is accepted
    /// deliberately: the alternative is reporting every pre-17.2 tester's
    /// trial as a paid charge, which is the one answer this whole file exists
    /// to get right.
    private func isIntroductoryOffer(_ transaction: StoreKit.Transaction) -> Bool {
        if #available(iOS 17.2, *) {
            return transaction.offer?.type == .introductory
        } else {
            return transaction.offerType == .introductory
        }
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
        updateBillingPeriod(from: entitlement)
        
        // Detect state changes
        if wasActive && !isNowActive {
            log("⚠️ SubscriptionManager: Subscription EXPIRED!")
            NotificationCenter.default.post(name: Self.subscriptionExpiredNotification, object: nil)

            // Revenue churn. Purchases were captured on the way in and
            // nothing on the way out, so no insight could tell a retained
            // subscriber from a lapsed one.
            //
            // Safe to hang off this branch specifically: `loadSubscriptionCache()`
            // seeds `lastSubscriptionState` from the cache at init precisely
            // so the first network check can't mistake the cache catching up
            // for a real transition. A cold start therefore cannot emit this.
            //
            // `churn_type` is the split that actually matters — a user who
            // cancelled and one whose card failed need opposite responses,
            // and RevenueCat already distinguishes them.
            //
            // Guarded on the entitlement being *present*. `!isNowActive` is
            // true both for an entitlement that expired and for one that is
            // missing from `customerInfo` entirely, and those are different
            // events with opposite meanings: the first is churn, the second is
            // an identity switch, a transfer, or a backend that cannot see the
            // transaction. Without the guard the second is filed as `lapsed`
            // churn with every distinguishing property silently absent — which
            // is exactly what happened for every `subscription_expired` this
            // app has ever emitted. See `Analytics.Event
            // .subscriptionEntitlementLost` for the full account.
            if let entitlement {
                let churnType: String
                if entitlement.billingIssueDetectedAt != nil {
                    churnType = "billing_issue"
                } else if entitlement.unsubscribeDetectedAt != nil {
                    churnType = "voluntary"
                } else {
                    churnType = "lapsed"
                }

                var properties: [String: Any] = [
                    "churn_type": churnType,
                    "was_trial": entitlement.periodType == .trial,
                    "is_sandbox": entitlement.isSandbox,
                ]
                properties["product_identifier"] = entitlement.productIdentifier
                if let expiryDate = expiryDate {
                    properties["expiry_date"] = ISO8601DateFormatter().string(from: expiryDate)
                }
                if let originalPurchase = entitlement.originalPurchaseDate {
                    properties["days_subscribed"] = Calendar.current
                        .dateComponents([.day], from: originalPurchase, to: Date()).day ?? 0
                }
                Analytics.capture(Analytics.Event.subscriptionExpired, properties)
            } else {
                // Access has already been revoked by `updateSubscriptionStatus`
                // above, and deliberately stays revoked: "customerInfo carries
                // no entitlement" must not be a route to free Pro, whatever the
                // cause. Only the telemetry changes here.
                //
                // `entitlements_total == 0` says RevenueCat holds nothing at
                // all for this App User ID — the shape of a credential or
                // ingestion failure. A non-zero count with our entitlement
                // absent instead points at the entitlement identifier or the
                // offering configuration having moved.
                log("🚨 SubscriptionManager: entitlement '\(entitlementID)' ABSENT from customerInfo — not churn")
                Analytics.capture(Analytics.Event.subscriptionEntitlementLost, [
                    "entitlement_id": entitlementID,
                    "entitlements_total": customerInfo.entitlements.all.count,
                    "entitlements_active": customerInfo.entitlements.active.count,
                    // The id to paste into RevenueCat's customer search when
                    // this fires. PostHog's distinct_id is not always the same
                    // value — an aliased or transferred customer is precisely
                    // the case this event exists to catch.
                    "rc_original_app_user_id": customerInfo.originalAppUserId,
                    "customer_info_request_date": ISO8601DateFormatter()
                        .string(from: customerInfo.requestDate),
                ])
            }
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

    // MARK: - Billing Period (trial vs paid)

    /// Derives `isInTrial` and `lastPaidChargeAt` from the RevenueCat
    /// entitlement.
    ///
    /// The distinction that matters is `periodType`: `.trial` and `.intro` are
    /// promotional periods where the user has been charged nothing (or a token
    /// intro price), `.normal` is a period they paid full freight for. Only
    /// `.normal` moves `lastPaidChargeAt`, which is what makes a trial start
    /// invisible to it and a trial *conversion* the first thing it records.
    ///
    /// `latestPurchaseDate` is the transaction behind the current period, so
    /// on conversion it becomes the conversion charge and on each renewal the
    /// renewal charge — "when money last left the account", exactly.
    private func updateBillingPeriod(from entitlement: EntitlementInfo?) {
        guard let entitlement, entitlement.isActive else {
            // An inactive or missing entitlement is not a trial. Deliberately
            // leaves `lastPaidChargeAt` alone: an expired subscriber was still
            // charged, whenever that was, and forgetting it here would be a
            // silent re-arm for anything measuring elapsed time since.
            if isInTrial { isInTrial = false }
            return
        }

        let nowInTrial = entitlement.periodType == .trial
        if isInTrial != nowInTrial {
            log("🧾 SubscriptionManager: periodType \(entitlement.periodType) — isInTrial \(isInTrial) → \(nowInTrial)")
            isInTrial = nowInTrial
        }

        guard entitlement.periodType == .normal,
              let chargedAt = entitlement.latestPurchaseDate else { return }

        // Monotonic. RevenueCat can serve a cached `CustomerInfo` that is
        // older than one we already processed, and letting the timestamp walk
        // backwards would re-open a window that had already closed.
        guard lastPaidChargeAt == nil || chargedAt > lastPaidChargeAt! else { return }

        log("🧾 SubscriptionManager: recorded paid charge at \(chargedAt.formatted())")
        lastPaidChargeAt = chargedAt
        UserDefaults.standard.set(chargedAt, forKey: cacheKeyLastCharge)
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
        self.lastPaidChargeAt = UserDefaults.standard.object(forKey: cacheKeyLastCharge) as? Date

        // `isInTrial` is deliberately left at its `false` default here rather
        // than cached. Everything that reads it also requires
        // `isSubscriptionActive`, and the cache can restore that to `true`
        // before the network says anything — so a cached `false` would, for
        // the length of the cold-start window, present a trialist as a payer.
        // Leaving it false is the same value but honestly unknown, and the
        // callers that care are all on user-driven paths that run long after
        // the first `handleCustomerInfoUpdate` has landed.

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
