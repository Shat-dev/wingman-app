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
    /// When the offer was first on screen. Kept here rather than in the view
    /// so a rebuilt view (SwiftUI can recreate a presentation's content)
    /// never re-spends the offer or re-reports the view.
    var shownAt: Date?
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

    /// How long the discount lasts, e.g. "year" or "6 months", read from the
    /// intro offer. Only read once `state == .ready`, which guarantees it.
    var introDurationPhrase: String {
        StoreProduct.durationPhrase(months: package?.storeProduct.introDurationMonths ?? 12)
    }

    /// The regular billing period the plan renews into, e.g. "year".
    var renewalPeriodPhrase: String {
        StoreProduct.durationPhrase(months: package?.storeProduct.periodMonths ?? 12)
    }

    /// "Yearly Plan", "Monthly Plan", or "6-month Plan" for anything else.
    var planTitle: String {
        switch package?.storeProduct.periodMonths {
        case 12: return "Yearly Plan"
        case 1: return "Monthly Plan"
        case let months?: return "\(months)-month Plan"
        case nil: return "Plan"
        }
    }

    /// The discounted stretch expressed per month, for the "only X per month"
    /// line. Nil when the discount lasts a single month (the line would just
    /// repeat the price) or the formatter can't produce it, in which case the
    /// line is omitted rather than guessed.
    var introPricePerMonthString: String? {
        guard let product = package?.storeProduct,
              let intro = product.introductoryDiscount,
              let months = product.introDurationMonths,
              months > 1 else { return nil }
        let monthly = intro.price / Decimal(months)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatter?.locale ?? .current
        return formatter.string(from: NSDecimalNumber(decimal: monthly))
    }

    var productId: String {
        package?.storeProduct.productIdentifier ?? Constants.ONE_TIME_OFFER_PRODUCT_ID
    }

    private var baseProperties: [String: Any] {
        var properties: [String: Any] = [
            "plan": Self.plan,
            "product_id": productId,
            "source": Self.source.rawValue,
            "offer": Self.offerName
        ]
        // Numeric prices, once the product has loaded. Added beside the
        // formatted `intro_price` / `full_price` strings on `paywall_viewed`,
        // which vary by storefront and cannot be aggregated.
        if let product = package?.storeProduct {
            properties = Analytics.properties(properties, adding: PaywallAnalytics.priceProperties(
                price: product.price,
                currencyCode: product.currencyCode
            ))
            properties = Analytics.properties(properties, adding: PaywallAnalytics.introPriceProperties(
                introPrice: product.introDurationMonths != nil ? product.introductoryDiscount?.price : nil
            ))
        }
        return properties
    }

    // MARK: - Preload
    //
    // The offer used to start fetching only once it was on screen, so closing
    // the paywall crossfaded into a spinner and the offer then snapped in a
    // beat later. The onboarding paywall now starts the fetch while it is still
    // up (`preload()`), and the offer view adopts that instance
    // (`takePreloaded()`). When it is ready by the time the X is tapped, the
    // paywall slides the offer up over itself (see PaywallView); otherwise the
    // X falls back to RootView's offer branch, which waits for this fetch.

    private static var preloaded: OneTimeOfferViewModel?

    /// Starts loading the offer in the background. Safe to call repeatedly.
    static func preload() {
        guard preloaded == nil else { return }
        let vm = OneTimeOfferViewModel()
        preloaded = vm
        Task { await vm.load() }
    }

    /// True once the preloaded offer has its prices and passed every check,
    /// i.e. presenting it now shows the offer at once rather than a blank
    /// screen that might close itself.
    static var isPreloadedReady: Bool { preloaded?.state == .ready }

    /// The preloaded instance if there is one (consumed, so a later
    /// presentation fetches fresh), otherwise a new one.
    static func takePreloaded() -> OneTimeOfferViewModel {
        defer { preloaded = nil }
        return preloaded ?? OneTimeOfferViewModel()
    }

    // MARK: - Load

    /// Fetches offerings fresh (the launch-time cache may predate a dashboard
    /// change), then confirms the intro offer exists and the user can claim
    /// it. Every check fails closed: no offer shown beats the wrong price
    /// shown.
    private var loadTask: Task<Void, Never>?

    /// Joins the fetch already in flight (e.g. the paywall's preload) rather
    /// than starting a second one.
    func load() async {
        guard state == .loading else { return }
        if loadTask == nil { loadTask = Task { await performLoad() } }
        await loadTask?.value
    }

    private func performLoad() async {

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
        // Every length on screen ("first year", "/year", per month) is read
        // from the product, so an intro or period the copy can't phrase
        // (pay-as-you-go, free trial, days, weeks) closes the offer instead.
        guard package.storeProduct.introDurationMonths != nil,
              package.storeProduct.periodMonths != nil else {
            return fail("intro_duration_unsupported")
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
        state = .unavailable(reason: reason)
    }

    /// Called by the view when it closes itself. Kept out of `fail` so a
    /// preload for someone who subscribes on the paywall (and never reaches
    /// the offer) doesn't count as an unavailable offer.
    func reportUnavailable() {
        guard case .unavailable(let reason) = state else { return }
        Analytics.capture("one_time_offer_unavailable", [
            "reason": reason,
            "source": Self.source.rawValue,
            "is_connected": NetworkMonitor.shared.isConnected
        ])
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
            Analytics.capture(Analytics.Event.purchasesRestoreFailed, Analytics.properties([
                "reason": "error",
                "source": Self.source.rawValue,
                "error_message": error.localizedDescription
            ], adding: Analytics.errorProperties(error)))
            self.error = "Restore failed. Please try again."
            self.showAlert = true
            return false
        }
    }
}

/// Lets the paywall present a loaded offer with `fullScreenCover(item:)`.
extension OneTimeOfferViewModel: Identifiable {}
