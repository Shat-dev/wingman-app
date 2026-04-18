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

@MainActor
final class PaywallViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var authManager: AuthManager?
    
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
                let fetchedOfferings = try await Purchases.shared.offerings()
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
        
        do {
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            
            // Check if user has the Wingman Pro entitlement
            let hasEntitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
            
            if hasEntitlement {
                log("✅ PaywallViewModel: Purchase successful")
                log("   - Entitlement active: \(hasEntitlement)")
                log("   - Expiry date: \(customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.expirationDate?.formatted() ?? "No expiry")")
                
                // If user is anonymous, store purchase info for later linking
                if authManager?.isAnonymousUser == true {
                    AnonymousUserManager.shared.storeRevenueCatPurchase(customerInfo: customerInfo)
                    log("💰 PaywallViewModel: Stored anonymous purchase for linking")
                }
                
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
            if let nsError = error as NSError? {
                switch nsError.code {
                case 1: // User cancelled
                    log("🚫 PaywallViewModel: User cancelled purchase")
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
            } else {
                self.error = "Purchase failed. Please try again."
                self.showAlert = true
            }
            
            log("❌ PaywallViewModel: Purchase failed: \(error.localizedDescription)")
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
