//
//  StoreProduct+IntroDiscount.swift
//  Wingman
//
//  Shared reading of a product's introductory offer, used by the post-demo
//  one-time offer (OneTimeOfferView).
//

import Foundation
import RevenueCat

extension StoreProduct {

    /// Whole-number percentage saved in year 1, **computed from this
    /// storefront's actual prices** rather than asserted.
    ///
    /// The offer is configured as "50% off" in App Store Connect, but that is a
    /// choice of *price point*, not a percentage: Apple's price tiers do not
    /// land on exactly half the base price in every territory, so the real
    /// saving drifts a point or two across storefronts. Hardcoding "50%" in the
    /// UI is therefore a false pricing claim under Guideline 3.1.2 wherever the
    /// tiers do not line up, and no amount of correct dashboard configuration
    /// can fix it.
    ///
    /// **Truncated, never rounded up.** Rounding 49.5% to "50%" overstates the
    /// discount; truncating to "49%" understates it. Understating is always
    /// safe, and the exact prices are shown alongside anyway.
    ///
    /// Nil when the numbers are missing or implausible — callers must then make
    /// no numeric claim at all rather than falling back to a guess.
    var introSavingsPercent: Int? {
        guard let introPrice = introductoryDiscount?.price,
              let introMonths = introDurationMonths,
              let baseMonths = periodMonths else { return nil }

        let basePrice = price
        guard basePrice > 0, introPrice > 0 else { return nil }

        // Like for like: the intro may cover a different stretch than one
        // billing period (six discounted months on a yearly plan, say), so
        // compare what a month costs under each.
        let introMonthly = introPrice / Decimal(introMonths)
        let baseMonthly = basePrice / Decimal(baseMonths)
        guard introMonthly < baseMonthly else { return nil }

        let fraction = (baseMonthly - introMonthly) / baseMonthly * 100
        let percent = Int(NSDecimalNumber(decimal: fraction).doubleValue) // truncates

        // A discount outside this band means something is misconfigured
        // upstream; say nothing rather than something wrong.
        guard (1...99).contains(percent) else { return nil }
        return percent
    }

    // MARK: - Durations
    //
    // Read from StoreKit too, so the copy says "first year" only when the
    // offer actually covers a year. Day and week periods return nil: nothing
    // sold here uses them, and the copy has no honest way to phrase them.

    /// Months in one regular billing period ("12" for the yearly plan).
    var periodMonths: Int? {
        subscriptionPeriod.flatMap(Self.months)
    }

    /// Months the introductory price covers, when it is paid up front in a
    /// single charge. Nil for pay-as-you-go and free-trial intros, whose
    /// "billed today" wording would be different.
    var introDurationMonths: Int? {
        guard let discount = introductoryDiscount,
              discount.paymentMode == .payUpFront,
              let months = Self.months(discount.subscriptionPeriod) else { return nil }
        return months * max(discount.numberOfPeriods, 1)
    }

    private static func months(_ period: SubscriptionPeriod) -> Int? {
        switch period.unit {
        case .month: return period.value
        case .year: return period.value * 12
        default: return nil
        }
    }

    /// Localized price actually charged today under the introductory offer.
    /// Nil when the product carries no such offer, which callers must treat as
    /// "do not pitch a discount" rather than rendering an empty string.
    var introPriceString: String? {
        introductoryDiscount?.localizedPriceString
    }
}
