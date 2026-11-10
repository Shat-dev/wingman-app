//
//  PaywallPricingTests.swift
//  WingmanTests
//
//  WP4 of the localization plan, first slice: the "only $1.35 per week" line
//  on the paywall's plan rows.
//
//  The amount is unchanged (decision D3). The formatting moved from the
//  device's locale to the product's own price formatter. These tests pin the
//  English output, prove it equals the old implementation wherever the
//  device region and the App Store match, and show the case the old code got
//  wrong: a storefront whose currency is not the device's.
//

import XCTest
@testable import Wingman

@MainActor
final class PaywallPricingTests: XCTestCase {

    /// A price formatter as StoreKit provides one for a product: currency
    /// style, the storefront's locale and currency.
    private func productFormatter(locale: String, currency: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: locale)
        formatter.currencyCode = currency
        return formatter
    }

    /// The paywall's weekly price exactly as it was computed before this
    /// slice, with the device locale passed in.
    private func originalWeeklyPrice(price: Decimal, period: PaywallPricing.BillingPeriod, deviceLocale: String) -> String {
        let weeklyPrice: Decimal
        if period == .year {
            weeklyPrice = price / 52
        } else if period == .month {
            weeklyPrice = price / 4.33
        } else {
            weeklyPrice = price
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: deviceLocale)
        return "only " + (formatter.string(from: weeklyPrice as NSNumber) ?? "$0.00")
    }

    private let usd = ("en_US", "USD")

    // MARK: - English output

    func testEnglishLineForTheYearlyPlan() {
        let formatter = productFormatter(locale: "en_US", currency: "USD")
        XCTAssertEqual(
            PaywallPricing.weeklyPriceLine(price: Decimal(string: "69.99")!, period: .year, formatter: formatter),
            "only $1.35 per week"
        )
    }

    func testEnglishLineForTheMonthlyPlan() {
        let formatter = productFormatter(locale: "en_US", currency: "USD")
        XCTAssertEqual(
            PaywallPricing.weeklyPriceLine(price: Decimal(string: "12.99")!, period: .month, formatter: formatter),
            "only $3.00 per week"
        )
    }

    func testAPeriodThatIsNeitherYearNorMonthShowsThePriceItself() {
        let formatter = productFormatter(locale: "en_US", currency: "USD")
        XCTAssertEqual(
            PaywallPricing.weeklyPrice(price: Decimal(string: "4.99")!, period: .other, formatter: formatter),
            "$4.99"
        )
    }

    func testSubtitles() {
        XCTAssertEqual(PaywallPricing.perYear, "per year")
        XCTAssertEqual(PaywallPricing.perMonth, "per month")
    }

    // MARK: - The amount (decision D3)

    func testWeeklyAmountUsesTheOriginalConstants() {
        XCTAssertEqual(PaywallPricing.weeklyAmount(price: 52, period: .year), 1)
        XCTAssertEqual(PaywallPricing.weeklyAmount(price: Decimal(string: "4.33")!, period: .month), Decimal(string: "4.33")! / 4.33)
        XCTAssertEqual(PaywallPricing.weeklyAmount(price: 7, period: .other), 7)
    }

    // MARK: - Same as before wherever the device region matches the store

    /// Every price from 0.49 to 199.99 in 50-cent steps, both plans, in the
    /// four biggest English markets and two euro ones.
    func testOutputEqualsTheOriginalWhenDeviceAndStorefrontMatch() {
        let markets = [("en_US", "USD"), ("en_GB", "GBP"), ("en_AU", "AUD"), ("en_CA", "CAD"), ("de_DE", "EUR"), ("sv_SE", "SEK")]
        var compared = 0
        for (locale, currency) in markets {
            let formatter = productFormatter(locale: locale, currency: currency)
            var cents = 49
            while cents <= 19_999 {
                let price = Decimal(cents) / 100
                for period in [PaywallPricing.BillingPeriod.year, .month, .other] {
                    let new = PaywallPricing.weeklyPrice(price: price, period: period, formatter: formatter).map { "only " + $0 }
                    let old = originalWeeklyPrice(price: price, period: period, deviceLocale: locale)
                    XCTAssertEqual(new, old, "\(locale) \(price) \(period)")
                    compared += 1
                }
                cents += 50
            }
        }
        XCTAssertEqual(compared, 6 * 400 * 3)
    }

    // MARK: - The case the old code got wrong

    /// A phone set to the United States buying from the German App Store.
    /// The product is priced in euros; the old code showed a dollar sign.
    func testAForeignStorefrontShowsTheStoresCurrencyNotTheDevices() {
        let price = Decimal(string: "69.99")!
        let german = productFormatter(locale: "de_DE", currency: "EUR")

        let old = originalWeeklyPrice(price: price, period: .year, deviceLocale: "en_US")
        XCTAssertEqual(old, "only $1.35", "the old behaviour this slice fixes")

        let new = PaywallPricing.weeklyPrice(price: price, period: .year, formatter: german)
        XCTAssertEqual(new?.contains("€"), true, new ?? "nil")
        XCTAssertEqual(new?.contains("$"), false, new ?? "nil")
        XCTAssertEqual(new?.contains("1,35"), true, new ?? "nil")
    }

    /// A currency without minor units keeps its own convention: the old code
    /// forced two decimals onto every currency.
    func testACurrencyWithoutDecimalsShowsNone() {
        let yen = productFormatter(locale: "ja_JP", currency: "JPY")
        let new = PaywallPricing.weeklyPrice(price: 9800, period: .year, formatter: yen)
        XCTAssertEqual(new?.contains("188"), true, new ?? "nil")
        XCTAssertEqual(new?.contains("."), false, new ?? "nil")
    }

    // MARK: - No formatter, no line

    func testNoFormatterMeansNoLineRatherThanAGuess() {
        XCTAssertNil(PaywallPricing.weeklyPrice(price: 10, period: .year, formatter: nil))
        XCTAssertNil(PaywallPricing.weeklyPriceLine(price: 10, period: .year, formatter: nil))
    }

    /// The product's formatter is used as it is, not changed: StoreKit hands
    /// out a shared instance.
    func testTheProductsFormatterIsNotModified() {
        let formatter = productFormatter(locale: "en_US", currency: "USD")
        let before = (formatter.maximumFractionDigits, formatter.minimumFractionDigits, formatter.locale, formatter.currencyCode)
        _ = PaywallPricing.weeklyPriceLine(price: 10, period: .year, formatter: formatter)
        XCTAssertEqual(formatter.maximumFractionDigits, before.0)
        XCTAssertEqual(formatter.minimumFractionDigits, before.1)
        XCTAssertEqual(formatter.locale, before.2)
        XCTAssertEqual(formatter.currencyCode, before.3)
    }
}
