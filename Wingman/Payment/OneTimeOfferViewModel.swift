//
//  OneTimeOfferViewModel.swift
//  Wingman
//
//  Drives the one-time offer: 50% off the first year of the annual plan,
//  shown once, as soon as the user closes the onboarding paywall without
//  subscribing (before the walkthrough; 1.12 showed it after).
//
//  Reports through the standard `paywall_*` events with `source=postPaywall`
//  (1.12 used `postDemo`), so
//  every existing paywall funnel and the "Payments received" tile count it
//  without changes. `offer=one_time_50` separates it from the full-price
//  paywall in the same funnels.
//

import Foundation
import SwiftUI
import Combine
import RevenueCat
import FacebookCore

@MainActor
final class OneTimeOfferViewModel: ObservableObject {

    enum LoadState: Equatable {
        case loading
        case ready
        /// No offer we can honestly show — offerings unreachable, product
        /// missing, no intro offer configured, or the user is not eligible
        /// for it. The view closes itself rather than pitching a price
        /// StoreKit would not charge.
        case unavailable(reason: String)
    }

    @Published private(set) var state: LoadState = .loading
    @Published private(set) var package: Package?
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showAlert = false
    @Published var alertKind: PurchaseAlertKind = .error

    static let source = PaywallSource.postPaywall
    static let offerName = "one_time_50"
    private static let plan = "yearly_discount"

    func dismissAlert() {
        error = nil
        alertKind = .error
    }

    // MARK: - Display

    /// Price charged today for year one. Only read once `state == .ready`,
    /// which guarantees the intro offer exists.
    var introPriceString: String { package?.storeProduct.introPriceString ?? "" }

    /// Standard yearly price, which the discounted year renews into.
    var fullPriceString: String { package?.storeProduct.localizedPriceString ?? "" }

    /// Computed from the storefront's real prices, never asserted — see
    /// `StoreProduct.introSavingsPercent`. Nil means make no numeric claim.
    var savingsPercent: Int? { package?.storeProduct.introSavingsPercent }

    /// The discounted year expressed per month, for the "less than X a month"
    /// line. Nil when the formatter can't produce it, in which case the line
    /// is omitted rather than guessed.
    var introPricePerMonthString: String? {
        guard let product = package?.storeProduct,
              let intro = product.introductoryDiscount else { return nil }
        let monthly = intro.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatter?.locale ?? .current
        return formatter.string(from: NSDecimalNumber(decimal: monthly))
    }

    var productId: String {
        package?.storeProduct.productIdentifier ?? Constants.ONE_TIME_OFFER_PRODUCT_ID
    }

    private var baseProperties: [String: Any] {
        [
            "plan": Self.plan,
            "product_id": productId,
            "source": Self.source.rawValue,
            "offer": Self.offerName
        ]
    }

    // MARK: - Load

    /// Fetches offerings fresh (the launch-time cache may predate a dashboard
    /// change), then confirms the intro offer exists and the user can claim
    /// it. Every check fails closed: no offer shown beats the wrong price
    /// shown.
    func load() async {
        guard state == .loading else { return }

        guard let offerings = await withTimeout({ try? await Purchases.shared.offerings() }) else {
            return fail("offerings_unavailable")
        }
        RevenueCatManager.shared.offerings = offerings

        guard let offering = offerings.all[Constants.ONE_TIME_OFFER_OFFERING_ID] else {
            return fail("offering_not_found")
        }
        guard let package = offering.package(identifier: Constants.ONE_TIME_OFFER_PACKAGE_ID) else {
            return fail("package_not_found")
        }
        // Without a configured intro offer StoreKit charges the full yearly
        // price under a "50% off" button.
        guard package.storeProduct.introductoryDiscount != nil else {
            return fail("no_intro_offer_on_product")
        }

        // Intro offers are once per subscription group. Anyone whose earlier
        // trial lapsed has spent theirs, and would be charged full price.
        // `.unknown` is what a fresh install with no receipt returns — Apple
        // honours the offer then, so it counts as eligible.
        let productId = package.storeProduct.productIdentifier
        let eligibility = await withTimeout {
            await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: [productId])
        }
        switch eligibility?[productId]?.status {
        case .eligible, .unknown:
            break
        case .none:
            return fail("eligibility_unavailable")
        default:
            return fail("not_intro_eligible")
        }

        self.package = package
        state = .ready
    }

    private func fail(_ reason: String) {
        log("🎁 OneTimeOfferViewModel: offer unavailable — \(reason)")
        Analytics.capture("one_time_offer_unavailable", [
            "reason": reason,
            "source": Self.source.rawValue,
            "is_connected": NetworkMonitor.shared.isConnected
        ])
        state = .unavailable(reason: reason)
    }

    /// Races `work` against an 8 s timeout, matching the paywall's offerings
    /// load, so a hung network call can't strand the user on a spinner.
    private func withTimeout<T>(_ work: @escaping @Sendable () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - Analytics

    func reportViewed() {
        var props = baseProperties
        props["intro_price"] = introPriceString
        props["full_price"] = fullPriceString
        props["savings_percent"] = savingsPercent ?? -1
        Analytics.capture("paywall_viewed", props)
    }

    func reportDismissed(timeOnScreen: TimeInterval?) {
        var props = baseProperties
        props["time_on_screen_seconds"] = timeOnScreen.map { Int($0) } ?? -1
        Analytics.capture("paywall_dismissed", props)
    }

    // MARK: - Purchase

    /// Same shape as `PaywallViewModel.purchase(_:)`: cancellation is its own
    /// terminal event, the entitlement is read from the purchase result, and
    /// `SubscriptionManager` is updated synchronously before the refresh.
    func purchase() async -> Bool {
        guard let package else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        Analytics.capture("paywall_purchase_started", baseProperties)

        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            if userCancelled {
                log("🚫 OneTimeOfferViewModel: User cancelled purchase")
                var props = baseProperties
                props["detection"] = "purchase_result"
                Analytics.capture(Analytics.Event.paywallPurchaseCancelled, props)
                return false
            }

            let entitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]
            guard entitlement?.isActive == true else {
                self.error = "Purchase completed but entitlement not found. Please contact support."
                self.showAlert = true
                var props = baseProperties
                props["error_code"] = -1
                props["failure_reason"] = "entitlement_missing"
                Analytics.capture("paywall_purchase_failed", props)
                return false
            }

            log("✅ OneTimeOfferViewModel: Purchase successful")
            var props = baseProperties
            props["is_trial"] = entitlement?.periodType == .trial
            props["is_sandbox"] = entitlement?.isSandbox ?? false
            Analytics.capture("paywall_purchase_succeeded", props)

            // Meta: valued at what was charged today (the discounted year),
            // not the eventual renewal price.
            let charged = package.storeProduct.introductoryDiscount?.price ?? package.storeProduct.price
            AppEvents.shared.logEvent(
                .subscribe,
                valueToSum: NSDecimalNumber(decimal: charged).doubleValue,
                parameters: [
                    .currency: package.storeProduct.currencyCode ?? "USD",
                    .contentID: package.storeProduct.productIdentifier
                ]
            )

            SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)
            await SubscriptionManager.shared.refreshSubscriptionStatus()
            return true
        } catch {
            let nsError = error as NSError
            if nsError.code == 1 {
                log("🚫 OneTimeOfferViewModel: User cancelled purchase")
                var props = baseProperties
                props["detection"] = "error_code"
                Analytics.capture(Analytics.Event.paywallPurchaseCancelled, props)
            } else {
                let failure = PurchaseFailure(error)
                self.error = failure.message
                self.alertKind = failure.alertKind
                self.showAlert = true
                log("❌ OneTimeOfferViewModel: Purchase failed: \(error.localizedDescription)")
                var props = baseProperties
                props["error_code"] = nsError.code
                props["failure_reason"] = failure.reason
                Analytics.capture("paywall_purchase_failed", props)
            }
            return false
        }
    }

    func restore() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let restored = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
            if restored {
                Analytics.capture(Analytics.Event.purchasesRestored, ["source": Self.source.rawValue])
                SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)
                await SubscriptionManager.shared.refreshSubscriptionStatus()
            } else {
                Analytics.capture(Analytics.Event.purchasesRestoreFailed, [
                    "reason": "no_active_entitlement",
                    "source": Self.source.rawValue
                ])
                self.error = "We couldn't find an active subscription for this Apple ID."
                self.showAlert = true
            }
            return restored
        } catch {
            log("❌ OneTimeOfferViewModel: Restore failed: \(error)")
            Analytics.capture(Analytics.Event.purchasesRestoreFailed, [
                "reason": "error",
                "source": Self.source.rawValue,
                "error_message": error.localizedDescription
            ])
            self.error = "Restore failed. Please try again."
            self.showAlert = true
            return false
        }
    }
}
