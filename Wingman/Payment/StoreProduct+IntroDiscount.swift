//
//  StoreProduct+IntroDiscount.swift
//  Wingman
//
//  Shared reading of a product's introductory offer, used by both screens that
//  pitch the 50%-off year: SecondChanceOfferView and the feature-gate paywall
//  during the discount window (see AuthManager.secondChanceDiscountWindow).
//
//  Lives here rather than on either view model because the two must never
//  disagree — a percentage computed one way on one screen and another way on
//  the next is a pricing claim that changes as the user navigates.
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
        guard let introPrice = introductoryDiscount?.price else { return nil }

        let basePrice = price
        guard basePrice > 0, introPrice < basePrice else { return nil }

        let fraction = (basePrice - introPrice) / basePrice * 100
        let percent = Int(NSDecimalNumber(decimal: fraction).doubleValue) // truncates

        // A discount outside this band means something is misconfigured
        // upstream; say nothing rather than something wrong.
        guard (1...99).contains(percent) else { return nil }
        return percent
    }

    /// Localized price actually charged today under the introductory offer.
    /// Nil when the product carries no such offer, which callers must treat as
    /// "do not pitch a discount" rather than rendering an empty string.
    var introPriceString: String? {
        introductoryDiscount?.localizedPriceString
    }
}
