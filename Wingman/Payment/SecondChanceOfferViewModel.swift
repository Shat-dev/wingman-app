//
//  SecondChanceOfferViewModel.swift
//  Wingman
//
//  Drives the one-time 50%-off-year-1 recovery offer shown after a user
//  dismisses the feature-gated paywall without purchasing. See
//  docs/second-chance-paywall-plan.md for the full design rationale.
//

import Foundation
import SwiftUI
import Combine
import RevenueCat
import FacebookCore

@MainActor
final class SecondChanceOfferViewModel: ObservableObject {

    @Published var package: Package?
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showAlert = false

    /// Whether the resolved product actually carries the introductory offer this
    /// entire screen is pitching.
    ///
    /// False means App Store Connect has no Pay-Up-Front offer on
    /// `wingman_yearly_discount` — never configured, misconfigured, or still
    /// pending review. Every price below would render blank and StoreKit would
    /// charge the standard price under a "Get 50% Off" button, so the screen
    /// must not be shown at all. `SubscriptionGateModifier` gates on this before
    /// presenting; the view re-checks on appear as a second layer.
    var hasIntroductoryOffer: Bool {
        package?.storeProduct.introductoryDiscount != nil
    }

    /// Discounted price the user is charged today (the Pay-Up-Front
    /// introductory price on `wingman_yearly_discount`).
    ///
    /// Empty when `hasIntroductoryOffer` is false — callers must gate on that
    /// rather than rendering this, or the user sees "Billed  today".
    var discountedPriceString: String {
        package?.storeProduct.introductoryDiscount?.localizedPriceString ?? ""
    }

    /// Whole-number percentage saved in year 1, **computed from this
    /// storefront's actual prices** rather than asserted.
    ///
    /// The offer is configured as "50% off" in App Store Connect, but that is a
    /// choice of *price point*, not a percentage: Apple's price tiers do not
    /// land on exactly half the base price in every territory, so the real
    /// saving drifts a point or two across storefronts. Hardcoding "50%" in the
    /// UI — which is what this screen used to do in four places — is therefore
    /// a false pricing claim under Guideline 3.1.2 wherever the tiers do not
    /// line up, and no amount of correct dashboard configuration can fix it.
    ///
    /// **Truncated, never rounded up.** Rounding 49.5% to "50%" overstates the
    /// discount; truncating to "49%" understates it. Understating is always
    /// safe, and the exact prices are shown alongside anyway.
    ///
    /// Nil when the numbers are missing or implausible — callers must then make
    /// no numeric claim at all rather than falling back to a guess.
    var savingsPercent: Int? {
        guard let product = package?.storeProduct,
              let introPrice = product.introductoryDiscount?.price else { return nil }

        let basePrice = product.price
        guard basePrice > 0, introPrice < basePrice else { return nil }

        let fraction = (basePrice - introPrice) / basePrice * 100
        let percent = Int(NSDecimalNumber(decimal: fraction).doubleValue) // truncates

        // A discount outside this band means something is misconfigured
        // upstream; say nothing rather than something wrong.
        guard (1...99).contains(percent) else { return nil }
        return percent
    }

    /// The price StoreKit reverts to after year 1 — this is the product's own
    /// standard price, which App Store Connect has intentionally been
    /// configured to match `wingman_yearly`'s price (see Phase 0 setup).
    var renewalPriceString: String {
        package?.storeProduct.localizedPriceString ?? ""
    }

    var productId: String {
        package?.storeProduct.productIdentifier ?? Constants.SECOND_CHANCE_YEARLY_PRODUCT_ID
    }

    /// Reads the already-resolved package from `RevenueCatManager`.
    /// `SubscriptionGateModifier` only presents this screen after confirming
    /// the package exists and is eligible, so this is a cached, synchronous
    /// read — not a fresh network fetch.
    func load() {
        package = RevenueCatManager.shared.getSecondChancePackage()
    }

    /// Mirrors `PaywallViewModel.purchase(_:)`'s structure (cancellation
    /// handling, entitlement check, synchronous `SubscriptionManager` update
    /// before the async refresh) with recovery-offer-specific analytics.
    func purchase() async -> Bool {
        guard let package else { return false }
        isPurchasing = true

        Analytics.capture(Analytics.Event.recoveryOfferPurchaseStarted, [
            "product_id": package.storeProduct.productIdentifier
        ])

        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            if userCancelled {
                log("🚫 SecondChanceOfferViewModel: User cancelled purchase")
                isPurchasing = false
                return false
            }

            let entitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]
            let hasEntitlement = entitlement?.isActive == true

            if hasEntitlement {
                log("✅ SecondChanceOfferViewModel: Purchase successful")

                Analytics.capture(Analytics.Event.recoveryOfferPurchased, [
                    "product_id": package.storeProduct.productIdentifier,
                    "discounted_price": discountedPriceString
                ])

                // Meta: same standard `.subscribe` event PaywallViewModel logs,
                // valued at what was actually charged today (the discounted
                // intro price), not the eventual renewal price.
                let chargedPrice = package.storeProduct.introductoryDiscount?.price ?? package.storeProduct.price
                let priceAmount = NSDecimalNumber(decimal: chargedPrice).doubleValue
                let currency = package.storeProduct.currencyCode ?? "USD"
                AppEvents.shared.logEvent(
                    .subscribe,
                    valueToSum: priceAmount,
                    parameters: [.currency: currency, .contentID: package.storeProduct.productIdentifier]
                )

                // Authoritative customerInfo from the purchase result, applied
                // synchronously before the network refresh — same rationale as
                // PaywallViewModel.purchase(_:).
                SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)
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
            let nsError = error as NSError
            if nsError.code == 1 {
                log("🚫 SecondChanceOfferViewModel: User cancelled purchase")
            } else {
                self.error = "Purchase failed. Please try again."
                self.showAlert = true
                log("❌ SecondChanceOfferViewModel: Purchase failed: \(error.localizedDescription)")
                Analytics.capture(Analytics.Event.recoveryOfferPurchaseFailed, [
                    "product_id": package.storeProduct.productIdentifier,
                    "error_code": nsError.code
                ])
            }
            isPurchasing = false
            return false
        }
    }

    func openRestore() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let hasEntitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
            if hasEntitlement {
                SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)
                await SubscriptionManager.shared.refreshSubscriptionStatus()
            }
            return hasEntitlement
        } catch {
            log("❌ SecondChanceOfferViewModel: Restore failed: \(error)")
            return false
        }
    }
}
