//
//  PaywallTrial.swift
//  Wingman
//
//  The trial badge on the paywall's plan rows: "3-day Free Trial".
//
//  The badge used to be that literal text. The trial length is set in App
//  Store Connect, per product, and nothing kept the two in step: change the
//  trial there and the app would go on promising three days. Under Apple's
//  Guideline 3.1.2 a trial claim has to be accurate.
//
//  The length is now read from the product's introductory offer, which is
//  what the App Store will actually grant, and the badge is built from it.
//  With today's products (a three-day free trial) it reads exactly as before.
//  A product with no free trial gets no badge.
//
//  Each badge is one catalog entry with the number as its placeholder, so a
//  translation can supply its own singular and plural forms.
//

import Foundation
import RevenueCat

nonisolated enum PaywallTrial {

    /// How long a free trial lasts.
    struct Length: Equatable {
        enum Unit: Equatable {
            case day
            case month
            case year
        }

        let count: Int
        let unit: Unit
    }

    /// The period units an introductory offer can use.
    enum OfferUnit: Equatable {
        case day
        case week
        case month
        case year
    }

    /// The trial length an introductory offer describes.
    ///
    /// Nil unless the offer is a free trial (a discounted first period is
    /// not one) and its length is a positive number. Weeks are counted in
    /// days, so a one-week trial is "7-day", the way the App Store itself
    /// usually reports it.
    static func length(isFreeTrial: Bool, periodValue: Int, periodUnit: OfferUnit, numberOfPeriods: Int) -> Length? {
        guard isFreeTrial else { return nil }
        let count = periodValue * max(numberOfPeriods, 1)
        guard count > 0 else { return nil }

        switch periodUnit {
        case .day:   return Length(count: count, unit: .day)
        case .week:  return Length(count: count * 7, unit: .day)
        case .month: return Length(count: count, unit: .month)
        case .year:  return Length(count: count, unit: .year)
        }
    }

    /// The badge text for a trial of this length.
    static func badge(_ length: Length) -> String {
        let count = length.count
        switch length.unit {
        case .day:
            return String(
                localized: "\(count)-day Free Trial",
                comment: "Badge on a paywall plan. %lld is the number of days in the free trial, for example 3."
            )
        case .month:
            return String(
                localized: "\(count)-month Free Trial",
                comment: "Badge on a paywall plan. %lld is the number of months in the free trial."
            )
        case .year:
            return String(
                localized: "\(count)-year Free Trial",
                comment: "Badge on a paywall plan. %lld is the number of years in the free trial."
            )
        }
    }
}

extension StoreProduct {

    /// The length of this product's free trial, as the App Store defines it.
    /// Nil when the product has no introductory offer or the offer is not a
    /// free trial.
    var freeTrialLength: PaywallTrial.Length? {
        guard let offer = introductoryDiscount else { return nil }

        let unit: PaywallTrial.OfferUnit
        switch offer.subscriptionPeriod.unit {
        case .day:   unit = .day
        case .week:  unit = .week
        case .month: unit = .month
        case .year:  unit = .year
        @unknown default: return nil
        }

        return PaywallTrial.length(
            isFreeTrial: offer.paymentMode == .freeTrial,
            periodValue: offer.subscriptionPeriod.value,
            periodUnit: unit,
            numberOfPeriods: offer.numberOfPeriods
        )
    }
}
