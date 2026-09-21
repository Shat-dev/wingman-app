//
//  RevenueCatManager.swift
//  Wingman
//
//  Created by Adnan Khan on 06/04/2026.
//

import Foundation
import RevenueCat
import SwiftUI
import Combine

@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    // MARK: - Published Properties
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isLoading = false
    @Published var error: RevenueCatError?
    
    // MARK: - Constants
    private let apiKey = Constants.REVENUE_CAT_API_KEY
    private let entitlementID = Constants.ENTITLEMENT_ID
    
    // MARK: - Computed Properties
    var isSubscribed: Bool {
        customerInfo?.entitlements[entitlementID]?.isActive == true
    }
    
    var activeSubscription: String? {
        guard let customerInfo = customerInfo else { return nil }
        return customerInfo.entitlements[entitlementID]?.productIdentifier
    }
    
    private override init() {
        super.init()
        configure()
    }
    
    // MARK: - Configuration
    func configure() {
        // Skip RevenueCat configuration if using StoreKit testing mode
        if RevenueCatConfig.useStoreKitTestingMode {
            log("🧪 RevenueCat: SKIPPED - Using StoreKit Testing Mode")
            return
        }
        
        // configure() is reached twice on every launch — once from this
        // singleton's init, once from RootView's startup task. Re-running
        // identity resolution on the payments SDK gains nothing and only
        // creates opportunities to get it wrong, so the second call no-ops.
        guard !Purchases.isConfigured else {
            log("ℹ️ RevenueCat: Already configured — skipping")
            return
        }

        log("🔧 RevenueCat: Configuring with API Key")
        // Verbose RevenueCat logs in Debug only — Release ships with .error
        // so production console noise is limited to real failures.
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif

        // Configure WITHOUT an appUserID, and do NOT assign one before
        // sign-in. Both matter, for different reasons:
        //
        // 1. An id passed here takes precedence over RevenueCat's cached one
        //    (IdentityManager.configure resolves
        //    `appUserID ?? cachedAppUserID ?? …`), so supplying one would
        //    re-identify a returning subscriber as somebody else on every
        //    cold launch and their entitlements would come back empty.
        //
        // 2. RevenueCat only transfers purchases automatically when logging
        //    in *from* an anonymous id ("$RCAnonymousID:…"). Assigning our
        //    own id pre-signup makes the account an identified one, so the
        //    later logIn(supabaseUserId) becomes an identified→identified
        //    switch and a purchase made while anonymous is left stranded on
        //    the old id. Leaving RevenueCat anonymous until real sign-in is
        //    what lets that handoff work.
        //
        // Consequence, accepted knowingly: pre-signup RevenueCat events are
        // keyed to $RCAnonymousID while PostHog uses its own anonymous id, so
        // a purchase made before account creation won't stitch to the
        // onboarding/paywall events that produced it until the user signs up.
        // That is an analytics gap; the alternative was a revenue bug.
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        log("🆔 RevenueCat: Identity: \(Purchases.shared.appUserID)")

        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }
    }
    
    // MARK: - User Management
    func setUserID(_ userID: String) {
        Task {
            do {
                _ = try await Purchases.shared.logIn(userID)
                await refreshCustomerInfo()
                log("🔑 RevenueCat: User logged in with ID: \(userID)")
            } catch {
                log("❌ RevenueCat: Failed to login user: \(error)")
            }
        }
    }
    
    func logoutUser() {
        Task {
            do {
                _ = try await Purchases.shared.logOut()
                await refreshCustomerInfo()
                log("👋 RevenueCat: User logged out")
            } catch {
                log("❌ RevenueCat: Failed to logout user: \(error)")
            }
        }
    }
    
    /// Link a purchase made while anonymous to the authenticated account.
    ///
    /// `anonymousCustomerID` is passed in rather than read back from
    /// `AnonymousUserManager`. The caller (`syncAnonymousDataToBackend`)
    /// deliberately clears that store before it gets here, so the previous
    /// version's `guard anonymousManager.needsRevenueCatLinking` always
    /// failed — and it returned `true`, reporting success for work it had
    /// silently skipped.
    ///
    /// Normally redundant: with RevenueCat left anonymous until sign-in, its
    /// own alias on `logIn` already moves the purchase across. This is the
    /// fallback for when that didn't happen — a failed or raced logIn.
    func linkAnonymousUserPurchases(_ userID: String, anonymousCustomerID: String) async -> Bool {
        log("🔗 RevenueCat: Verifying anonymous purchase link")
        log("   - Anonymous Customer ID: \(anonymousCustomerID)")
        log("   - Authenticated User ID: \(userID)")

        do {
            // Fast path: check whether the SDK's alias already did the work.
            // Worth testing first — the fallback below logs back into the
            // anonymous customer, which would move the active user *away*
            // from the account we just signed into if run unnecessarily.
            let current = try await Purchases.shared.customerInfo()
            if Purchases.shared.appUserID == userID,
               current.entitlements[entitlementID]?.isActive == true {
                log("✅ RevenueCat: Entitlement already on \(userID) — nothing to link")
                customerInfo = current
                return true
            }

            // Fallback: adopt the anonymous customer, then identify as the
            // authenticated user so RevenueCat transfers the purchase.
            _ = try await Purchases.shared.logIn(anonymousCustomerID)
            let anonymousCustomerInfo = try await Purchases.shared.customerInfo()
            log("📋 RevenueCat: Anonymous entitlements: \(anonymousCustomerInfo.entitlements.active.keys)")

            _ = try await Purchases.shared.logIn(userID)
            let finalCustomerInfo = try await Purchases.shared.customerInfo()
            log("📋 RevenueCat: Final entitlements: \(finalCustomerInfo.entitlements.active.keys)")

            customerInfo = finalCustomerInfo
            // Push the result straight into SubscriptionManager rather than
            // waiting on the delegate or the 5-minute poll, so the gates the
            // user is about to hit see the transferred entitlement.
            SubscriptionManager.shared.handleCustomerInfoUpdate(finalCustomerInfo, error: nil)

            let hasEntitlement = finalCustomerInfo.entitlements[entitlementID]?.isActive == true
            if hasEntitlement {
                log("✅ RevenueCat: Purchase transferred to \(userID)")
            } else {
                log("❌ RevenueCat: Transfer ran but \(userID) has no active entitlement")
            }
            // Only ever report success when an entitlement is actually present.
            return hasEntitlement

        } catch {
            log("❌ RevenueCat: Failed to link anonymous purchases: \(error)")
            return false
        }
    }
    
    // MARK: - Customer Info
    func refreshCustomerInfo() async {
        do {
            isLoading = true
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            error = nil

            log("ℹ️ RevenueCat: Customer info refreshed")
        } catch {
            self.error = RevenueCatError.customerInfoFailed(error.localizedDescription)
            log("❌ RevenueCat: Failed to get customer info: \(error)")
        }
        isLoading = false
    }
    
    // MARK: - Offerings
    func fetchOfferings() async {
        do {
            isLoading = true
            let fetchedOfferings = try await Purchases.shared.offerings()
            offerings = fetchedOfferings
            error = nil
            log("📦 RevenueCat: Offerings fetched: \(fetchedOfferings.all.count) offerings")
        } catch {
            self.error = RevenueCatError.offeringsFailed(error.localizedDescription)
            log("❌ RevenueCat: Failed to fetch offerings: \(error)")
        }
        isLoading = false
    }
    
    // MARK: - Purchases
    func purchase(_ package: Package) async -> Bool {
        do {
            isLoading = true
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            self.customerInfo = customerInfo
            error = nil
            
            let success = customerInfo.entitlements[entitlementID]?.isActive == true
            log("💰 RevenueCat: Purchase completed. Entitled: \(success)")
            isLoading = false
            return success
        } catch {
            self.error = RevenueCatError.purchaseFailed(error.localizedDescription)
            log("❌ RevenueCat: Purchase failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        do {
            isLoading = true
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            error = nil
            
            let success = customerInfo.entitlements[entitlementID]?.isActive == true
            log("🔄 RevenueCat: Restore completed. Entitled: \(success)")
            isLoading = false
            return success
        } catch {
            self.error = RevenueCatError.restoreFailed(error.localizedDescription)
            log("❌ RevenueCat: Restore failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Subscription Status
    func checkSubscriptionStatus() -> SubscriptionStatus {
        guard let customerInfo = customerInfo else {
            return .unknown
        }
        
        guard let entitlement = customerInfo.entitlements[entitlementID] else {
            return .notSubscribed
        }
        
        if entitlement.isActive {
            return .subscribed(productID: entitlement.productIdentifier)
        } else {
            return .expired
        }
    }
    
    // MARK: - Product Information
    func getYearlyPackage() -> Package? {
        return offerings?.current?.package(identifier: "yearly") ??
               offerings?.current?.annual
    }
    
    func getMonthlyPackage() -> Package? {
        return offerings?.current?.package(identifier: "monthly") ??
               offerings?.current?.monthly
    }
    
    func getAllPackages() -> [Package] {
        return offerings?.current?.availablePackages ?? []
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            log("🔄 RevenueCat: Customer info updated via delegate")

            // Forward to SubscriptionManager so authManager.hasActiveSubscription
            // stays in sync without waiting for the 5-min periodic timer or a
            // foreground transition. RC pushes this delegate on logIn/logOut,
            // post-purchase, restore, and any server-side change — exactly the
            // events that previously left SubscriptionManager stale (e.g. after
            // setUserID() during sign-in on a new device, or account-switch on
            // a shared device). handleCustomerInfoUpdate is idempotent.
            SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)
        }
    }
}

// MARK: - Supporting Types
enum RevenueCatError: LocalizedError {
    case customerInfoFailed(String)
    case offeringsFailed(String)
    case purchaseFailed(String)
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .customerInfoFailed(let message):
            return "Failed to get customer info: \(message)"
        case .offeringsFailed(let message):
            return "Failed to fetch products: \(message)"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        }
    }
}

enum SubscriptionStatus {
    case unknown
    case notSubscribed
    case subscribed(productID: String)
    case expired
    
    var isActive: Bool {
        if case .subscribed = self {
            return true
        }
        return false
    }
}
