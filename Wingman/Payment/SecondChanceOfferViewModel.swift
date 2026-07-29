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

    /// Discounted price the user is charged today (the Pay-Up-Front
    /// introductory price on `wingman_yearly_discount`).
    var discountedPriceString: String {
        package?.storeProduct.introductoryDiscount?.localizedPriceString ?? ""
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
