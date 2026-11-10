//
//  PaywallPricing.swift
//  Wingman
//
//  The "only $1.35 per week" line on the paywall's plan rows.
//
//  The amount is arithmetic on the product's price (decision D3 of the
//  localization plan: keep the app's own division, do not switch to
//  RevenueCat's per-week value, so the English paywall shows the same cents
//  it always has).
//
//  What changed is the formatting. The line used to be formatted with the
//  DEVICE's locale, which also decides the currency symbol: a phone set to
//  the United States buying from the German App Store was shown the euro
//  amount with a dollar sign. It is now formatted with the PRODUCT's own
//  price formatter, the same one StoreKit uses for the full price shown on
//  the same row, so the two can never disagree about the currency.
//
//  For a user whose device region and App Store match — nearly everyone —
//  the output is identical to before.
//

import Foundation
import RevenueCat

nonisolated enum PaywallPricing {

    /// How often a plan bills.
    enum BillingPeriod: Equatable {
        case year
        case month
        /// Anything else (a week, a day, or unknown): the price is shown
        /// as it is.
        case other
    }

    /// The plan's price spread over a week.
    ///
    /// 52 weeks in a year, about 4.33 in a month. These are the constants
    /// the paywall has always used; changing either moves the English price
    /// by a cent or two.
    static func weeklyAmount(price: Decimal, period: BillingPeriod) -> Decimal {
        switch period {
        case .year:  return price / 52
        case .month: return price / 4.33
        case .other: return price
        }
    }

    /// The weekly amount as money, in the product's currency and number
    /// format. Nil when the product has no formatter: a guessed currency is
    /// worse than no line.
    static func weeklyPrice(price: Decimal, period: BillingPeriod, formatter: NumberFormatter?) -> String? {
        guard let formatter else { return nil }
        return formatter.string(from: weeklyAmount(price: price, period: period) as NSNumber)
    }

    /// The whole line under a plan's title: "only $1.35 per week".
    ///
    /// One sentence with the price as its only placeholder, so a translation
    /// can put the price wherever its grammar needs it.
    static func weeklyPriceLine(price: Decimal, period: BillingPeriod, formatter: NumberFormatter?) -> String? {
        guard let weekly = weeklyPrice(price: price, period: period, formatter: formatter) else { return nil }
        return String(
            localized: "only \(weekly) per week",
            comment: "Paywall plan row, under the plan's name. %@ is a price with its currency, for example $1.35."
        )
    }

    /// Under the yearly plan's full price.
    static var perYear: String {
        String(localized: "per year", comment: "Paywall plan row, under the yearly plan's full price ($69.99 per year).")
    }

    /// Under the monthly plan's full price.
    static var perMonth: String {
        String(localized: "per month", comment: "Paywall plan row, under the monthly plan's full price ($12.99 per month).")
    }
}

extension PaywallPricing.BillingPeriod {

    /// From a StoreKit subscription period, as RevenueCat reports it.
    init(_ unit: SubscriptionPeriod.Unit?) {
        switch unit {
        case .year:  self = .year
        case .month: self = .month
        default:     self = .other
        }
    }
}

extension PaywallPricing {

    /// The line for a purchasable package.
    static func weeklyPriceLine(for package: Package) -> String? {
        let product = package.storeProduct
        return weeklyPriceLine(
            price: product.price,
            period: BillingPeriod(product.subscriptionPeriod?.unit),
            formatter: product.priceFormatter
        )
    }
}
