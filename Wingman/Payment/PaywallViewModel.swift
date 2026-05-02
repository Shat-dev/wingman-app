//
//  PaywallViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import Foundation
import SwiftUI
import Combine
import RevenueCat
import StoreKit
import PostHog

/// Thrown by `loadOfferings()` when the RevenueCat offerings fetch doesn't
/// resolve within its deadline. Caught by the same block that handles
/// network errors, so the UI surfaces the existing "Can't load pricing"
/// error state with its Try Again button.
private struct PaywallTimeoutError: Error {}

@MainActor
final class PaywallViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var authManager: AuthManager?
    /// Origin tag for PostHog paywall_purchase_* events. Set by the
    /// presenting `PaywallView` in its `.onAppear`. Defaults to `.onboarding`
    /// so events are still attributable if a code path forgets to set it,
    /// but the compiler-required `source` on `PaywallView.init` makes that
    /// path effectively unreachable.
    var source: PaywallSource = .onboarding
    
    // MARK: - RevenueCat
    @Published var isLoading = false
    @Published var offerings: Offerings?
    @Published var selectedPackage: Package?
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showAlert = false

    /// Per-product intro-offer eligibility from RevenueCat. Populated after
    /// offerings load and after a failed restore. Empty dictionary means
    /// "not yet known" — computed properties below treat that as eligible
    /// (optimistic default) so the 95% first-time-user path is unaffected by
    /// a pending or failed eligibility check.
    @Published var introEligibility: [String: IntroEligibility] = [:]

    // MARK: - Carousel
    @Published var currentPage: Int = 0

    // MARK: - In-app Safari
    /// Drives a `.sheet(item:)` that presents Privacy/Terms in an
    /// SFSafariViewController modal instead of bouncing out to Safari.app.
    @Published var safariLink: IdentifiableURL?

    let pages: [PaywallPage] = [
        PaywallPage(
            imageName: "paywall_1",
            bullets: [
                "Stop overthinking your next move",
                "Feel more natural each time you talk",
                "Learn core social and flirting skills through daily reps"
            ]
        ),
        PaywallPage(
            imageName: "paywall_2",
            bullets: [
                "Develop the skills most men were never taught",
                "Master mindset, communication, flirting, and approach mechanics step-by-step",
                "Learn how to create attraction & interest"
            ]
        ),
        PaywallPage(
            imageName: "paywall_3",
            bullets: [
                "Stop guessing what to say next",
                "Practice real encounters through scenario-based games",
                "Be ready for any situation before it happens"
            ]
        ),
        PaywallPage(
            imageName: "paywall_4",
            bullets: [
                "See your confidence grow with real data",
                "Track your approaches, reflections, and progress",
                "Stay motivated as you watch yourself improve"
            ]
        )
    ]

    // MARK: - Plan
    @Published var selectedPlan: SubscriptionPlan = .yearly
    
    // MARK: - Computed Properties
    var yearlyPackage: Package? {
        return offerings?.current?.package(identifier: "yearly") ??
               offerings?.current?.annual
    }
    
    var monthlyPackage: Package? {
        return offerings?.current?.package(identifier: "monthly") ??
               offerings?.current?.monthly
    }
    
    var yearlyPrice: String {
        return yearlyPackage?.storeProduct.localizedPriceString ?? ""
    }

    var monthlyPrice: String {
        return monthlyPackage?.storeProduct.localizedPriceString ?? ""
    }
    
    var currentPackage: Package? {
        return selectedPlan == .yearly ? yearlyPackage : monthlyPackage
    }

    // MARK: - Trial Eligibility
    //
    // `.eligible` and `.unknown` both map to "show trial UI" — `.unknown` is
    // what RevenueCat returns for a fresh install with no App Store receipt,
    // and Apple will grant the trial in that case. Only an authoritative
    // `.ineligible` or `.noIntroOfferExists` hides the trial badge, matching
    // Apple's Guideline 3.1.2 requirement that trial claims be accurate.

    var isYearlyTrialEligible: Bool {
        guard let id = yearlyPackage?.storeProduct.productIdentifier else { return true }
        return isEligibleStatus(introEligibility[id]?.status)
    }

    var isMonthlyTrialEligible: Bool {
        guard let id = monthlyPackage?.storeProduct.productIdentifier else { return true }
        return isEligibleStatus(introEligibility[id]?.status)
    }

    func isTrialEligible(for plan: SubscriptionPlan) -> Bool {
        return plan == .yearly ? isYearlyTrialEligible : isMonthlyTrialEligible
    }

    /// Nil (not-yet-checked) → eligible (optimistic). `.unknown` (fresh install,
    /// no receipt) → eligible per RevenueCat's own recommendation.
    private func isEligibleStatus(_ status: IntroEligibilityStatus?) -> Bool {
        guard let status else { return true }
        switch status {
        case .eligible, .unknown: return true
        case .ineligible, .noIntroOfferExists: return false
        @unknown default: return true
        }
    }

    init() {
        loadOfferings()
    }

    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
        selectedPackage = plan == .yearly ? yearlyPackage : monthlyPackage
        log("🧾 Selected plan: \(plan.rawValue)")
    }

    // MARK: - RevenueCat Methods
    func loadOfferings() {
        Task {
            isLoading = true

            do {
                // Race the RevenueCat offerings fetch against a 15s timeout so
                // a hanging StoreKit call (cached sandbox account from prior
                // TestFlight use, captive WiFi, Apple server stall, etc.)
                // doesn't leave the user on an infinite spinner. On timeout
                // we throw PaywallTimeoutError into the shared catch block
                // below, which surfaces the existing "Can't load pricing"
                // error state with its Try Again button. 15s is generous
                // enough not to false-positive on slow cellular (typical
                // offerings response is <2s on healthy networks, 3-5s on
                // slow mobile) while still short enough that users don't
                // give up and kill the app before we recover.
                let fetchedOfferings = try await withThrowingTaskGroup(of: Offerings.self) { group in
                    group.addTask {
                        try await Purchases.shared.offerings()
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 15_000_000_000)
                        throw PaywallTimeoutError()
                    }
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
                self.offerings = fetchedOfferings

                // Auto-select yearly package by default
                self.selectedPackage = yearlyPackage

                log("📦 PaywallViewModel: Loaded offerings")

                // Fetch intro-offer eligibility for both packages. Non-throwing
                // API — failures resolve to `.unknown`, which our optimistic
                // default treats as eligible, so this call cannot regress the
                // existing first-time-user UX.
                await loadIntroEligibility()
            } catch {
                self.error = "Failed to load subscription options. Please try again."
                self.showAlert = true
                log("❌ PaywallViewModel: Failed to load offerings: \(error)")
            }

            isLoading = false

            // Fire after isLoading flips so the UI unblocks immediately;
            // the capture itself is a background metadata write that we
            // don't want to gate paywall rendering on.
            if self.offerings != nil {
                await captureStoreContextIfNeeded()
            }
        }
    }

    /// Fetches per-product intro-offer eligibility from RevenueCat and stores
    /// it on `introEligibility`. Safe to call repeatedly (RC caches receipts
    /// locally). Non-throwing; failures leave unresolved products at
    /// `.unknown`, which the eligibility computed properties treat as eligible.
    private func loadIntroEligibility() async {
        guard let yearlyID = yearlyPackage?.storeProduct.productIdentifier,
              let monthlyID = monthlyPackage?.storeProduct.productIdentifier else {
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: [yearlyID, monthlyID]
        )
        self.introEligibility = result
        log("🎫 PaywallViewModel: Eligibility — yearly=\(result[yearlyID]?.status.rawValue ?? -1), monthly=\(result[monthlyID]?.status.rawValue ?? -1)")
    }

    /// Reads App Store storefront country (StoreKit 2) and currency
    /// (from any loaded StoreProduct), then delegates the write to
    /// `AuthManager.captureStoreContext` which handles auth-gating,
    /// per-user idempotency, and the actual `user_metadata` update.
    private func captureStoreContextIfNeeded() async {
        // Country from StoreKit 2 storefront (nil on simulator/offline).
        var country: String? = nil
        if let storefront = await Storefront.current {
            country = storefront.countryCode
        }

        // Currency from a loaded StoreProduct — yearly preferred, monthly fallback.
        let currency = yearlyPackage?.storeProduct.currencyCode
            ?? monthlyPackage?.storeProduct.currencyCode

        await authManager?.captureStoreContext(country: country, currency: currency)
    }
    
    func continueTapped() async -> Bool {
        guard let package = currentPackage else {
            self.error = "Please select a subscription plan"
            self.showAlert = true
            return false
        }
        
        return await purchase(package)
    }
    
    func purchase(_ package: Package) async -> Bool {
        isPurchasing = true

        // Plan label derived from the package's product identifier.
        let plan: String = {
            if package.storeProduct.productIdentifier == Constants.YEARLY_PRODUCT_ID { return "yearly" }
            if package.storeProduct.productIdentifier == Constants.MONTHLY_PRODUCT_ID { return "monthly" }
            return "unknown"
        }()
        // PostHog: purchase initiated. Captured before the StoreKit call so
        // we have a denominator even when network or sheet errors prevent
        // the success / failure branches from running.
        PostHogSDK.shared.capture("paywall_purchase_started", properties: [
            "plan": plan,
            "product_id": package.storeProduct.productIdentifier,
            "source": source.rawValue
        ])

        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            // RevenueCat does not throw on user cancellation of the Apple payment
            // sheet — it returns with userCancelled = true. Bail before the
            // entitlement check so we don't misreport a dismissed sheet as a
            // completed-but-missing-entitlement error.
            if userCancelled {
                log("🚫 PaywallViewModel: User cancelled purchase")
                isPurchasing = false
                return false
            }

            // Check if user has the Wingman Pro entitlement
            let entitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]
            let hasEntitlement = entitlement?.isActive == true

            if hasEntitlement {
                log("✅ PaywallViewModel: Purchase successful")
                log("   - Entitlement active: \(hasEntitlement)")
                log("   - Expiry date: \(entitlement?.expirationDate?.formatted() ?? "No expiry")")

                // PostHog: purchase confirmed by RevenueCat entitlement. Read
                // `customerInfo.entitlements` directly here — do NOT read
                // `authManager.hasActiveSubscription`; that flag is updated
                // asynchronously via NotificationCenter and may not have
                // flipped yet at this point in the call stack.
                let isTrial = entitlement?.periodType == .trial
                let isAnon = authManager?.isAnonymousUser == true
                PostHogSDK.shared.capture("paywall_purchase_succeeded", properties: [
                    "plan": plan,
                    "product_id": package.storeProduct.productIdentifier,
                    "source": source.rawValue,
                    "is_trial": isTrial,
                    "is_anonymous": isAnon
                ])

                // If user is anonymous, store purchase info for later linking
                if isAnon {
                    AnonymousUserManager.shared.storeRevenueCatPurchase(customerInfo: customerInfo)
                    log("💰 PaywallViewModel: Stored anonymous purchase for linking")
                }

                // Apply the authoritative customerInfo from the purchase
                // result synchronously BEFORE the network refresh. This is
                // RC's own definitive answer — using it here means the
                // SubscriptionGateModifier auto-dismiss (which keys off
                // authManager.hasActiveSubscription) fires reliably even if
                // the follow-up network refresh below fails (e.g. connection
                // drops immediately after the StoreKit transaction). The
                // refresh still runs to invalidate the RC cache for any
                // subsequent reads.
                SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)

                // 🔄 Refresh subscription status immediately after purchase
                log("🔄 PaywallViewModel: Refreshing subscription status after purchase...")
                await SubscriptionManager.shared.refreshSubscriptionStatus()

                isPurchasing = false
                return true
            } else {
                self.error = "Purchase completed but entitlement not found. Please contact support."
                self.showAlert = true
                isPurchasing = false
                return false
            }

        } catch {
            // Handle RevenueCat specific errors using the error directly
            let nsError = error as NSError
            if nsError.code == 1 {
                // User cancelled — don't surface error UI, don't fire
                // PostHog failure event (cancellation is not a failure).
                log("🚫 PaywallViewModel: User cancelled purchase")
            } else {
                switch nsError.code {
                case 2: // Store problem
                    self.error = "Store is currently unavailable. Please try again later."
                    self.showAlert = true
                case 3: // Purchase not allowed
                    self.error = "Purchases are not allowed on this device"
                    self.showAlert = true
                case 4: // Payment pending
                    self.error = "Payment is pending approval"
                    self.showAlert = true
                default:
                    self.error = "Purchase failed. Please try again."
                    self.showAlert = true
                }
                log("❌ PaywallViewModel: Purchase failed: \(error.localizedDescription)")
                // PostHog: purchase failure (excluding user cancellation).
                // `error_code` is the RevenueCat NSError code; no PII.
                PostHogSDK.shared.capture("paywall_purchase_failed", properties: [
                    "plan": plan,
                    "product_id": package.storeProduct.productIdentifier,
                    "source": source.rawValue,
                    "error_code": nsError.code
                ])
            }

            isPurchasing = false
            return false
        }
    }
    
    // MARK: - Footer Links
    func openPrivacy() {
        if let url = URL(string: Constants.PRIVACY_POLICY_URL) {
            safariLink = IdentifiableURL(url: url)
        }
    }
    
    func openRestore() async {
        isLoading = true
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let hasEntitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
            
            if hasEntitlement {
                self.error = "Purchases restored successfully!"
                self.showAlert = true
                log("✅ PaywallViewModel: Purchases restored")
                
                // 🔄 Refresh subscription status after restore
                log("🔄 PaywallViewModel: Refreshing subscription status after restore...")
                await SubscriptionManager.shared.refreshSubscriptionStatus()
            } else {
                self.error = "No active subscriptions found to restore"
                self.showAlert = true
                log("⚠️ PaywallViewModel: No purchases to restore")

                // Re-run eligibility after a restore that didn't grant access.
                // The restore writes the App Store receipt to disk, which lets
                // RevenueCat give an authoritative `.ineligible` for a user
                // who's already used their trial on this Apple ID — updating
                // the paywall copy correctly.
                await loadIntroEligibility()
            }
        } catch {
            self.error = "Failed to restore purchases. Please try again."
            self.showAlert = true
            log("❌ PaywallViewModel: Restore failed: \(error)")
        }
        
        isLoading = false
    }
    
    func openTerms() {
        if let url = URL(string: Constants.TERMS_CONDITIONS_URL) {
            safariLink = IdentifiableURL(url: url)
        }
    }
}
