//
//  AnalyticsScreenNameTests.swift
//  WingmanTests
//
//  WP2 (part 2) of the localization plan: screen names stay fixed
//  identifiers, and the properties added beside existing ones (numeric
//  prices, error domain and code) never overwrite what an event already
//  sends.
//

import XCTest
@testable import Wingman

@MainActor
final class AnalyticsScreenNameTests: XCTestCase {

    /// The `$screen_name` values production already sends
    /// (docs/localization-analytics-baseline.md, section 6), plus
    /// "Practice Detail", which is defined in code but was not observed in
    /// the 90-day window. Saved insights filter on these by exact match.
    func testScreenNamesAreTheBaselineSet() {
        XCTAssertEqual(Analytics.Screen.all.sorted(), [
            "Auth",
            "AuthAfterPurchase",
            "AuthRequired",
            "AuthSaveProgress",
            "Course Detail",
            "Courses",
            "Daily Practice",
            "Home",
            "Landing",
            "Lesson",
            "Onboarding",
            "OneTimeOffer",
            "Paywall",
            "Practice",
            "Practice Detail",
            "Profile",
            "Settings"
        ])
    }

    func testScreenNamesAreUnique() {
        XCTAssertEqual(Set(Analytics.Screen.all).count, Analytics.Screen.all.count)
    }

    // MARK: - Adding properties never changes existing ones

    func testAddedPropertiesNeverOverwriteExistingOnes() {
        let merged = Analytics.properties(
            ["plan": "yearly", "error_code": -1],
            adding: ["error_code": 42, "error_domain": "Test"]
        )
        XCTAssertEqual(merged["plan"] as? String, "yearly")
        XCTAssertEqual(merged["error_code"] as? Int, -1, "An existing property was overwritten")
        XCTAssertEqual(merged["error_domain"] as? String, "Test")
    }

    // MARK: - Error identity

    func testErrorPropertiesAreDomainAndCode() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "Die Internetverbindung scheint offline zu sein."]
        )
        let properties = Analytics.errorProperties(error)
        XCTAssertEqual(Set(properties.keys), ["error_domain", "error_code"])
        XCTAssertEqual(properties["error_domain"] as? String, "NSURLErrorDomain")
        XCTAssertEqual(properties["error_code"] as? Int, -1009)
    }

    /// The same error described in two languages has the same identity.
    func testErrorPropertiesDoNotDependOnTheMessageLanguage() {
        func error(_ message: String) -> NSError {
            NSError(domain: "RevenueCat.ErrorCode", code: 10, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let english = Analytics.errorProperties(error("Network error."))
        let german = Analytics.errorProperties(error("Netzwerkfehler."))
        XCTAssertEqual(english["error_domain"] as? String, german["error_domain"] as? String)
        XCTAssertEqual(english["error_code"] as? Int, german["error_code"] as? Int)
    }

    // MARK: - Prices

    func testPricePropertiesAreNumericWithISOCurrency() {
        let properties = PaywallAnalytics.priceProperties(price: Decimal(string: "79.99")!, currencyCode: "EUR")
        XCTAssertEqual(Set(properties.keys), ["price_amount", "currency"])
        XCTAssertEqual(try XCTUnwrap(properties["price_amount"] as? Double), 79.99, accuracy: 0.0001)
        XCTAssertEqual(properties["currency"] as? String, "EUR")
    }

    func testPricePropertiesForAWholeNumberCurrency() {
        let properties = PaywallAnalytics.priceProperties(price: Decimal(999), currencyCode: "SEK")
        XCTAssertEqual(try XCTUnwrap(properties["price_amount"] as? Double), 999, accuracy: 0.0001)
        XCTAssertEqual(properties["currency"] as? String, "SEK")
    }

    func testCurrencyIsOmittedWhenUnknown() {
        XCTAssertNil(PaywallAnalytics.priceProperties(price: Decimal(string: "14.99")!, currencyCode: nil)["currency"])
        XCTAssertNil(PaywallAnalytics.priceProperties(price: Decimal(string: "14.99")!, currencyCode: "")["currency"])
    }

    func testIntroPriceProperties() {
        XCTAssertTrue(PaywallAnalytics.introPriceProperties(introPrice: nil).isEmpty)
        let properties = PaywallAnalytics.introPriceProperties(introPrice: Decimal(string: "49.99")!)
        XCTAssertEqual(try XCTUnwrap(properties["intro_price_amount"] as? Double), 49.99, accuracy: 0.0001)
    }

    /// The purchase events' existing properties survive having prices added.
    func testAddingPricesKeepsThePurchaseEventIdentity() {
        let existing: [String: Any] = ["plan": "monthly", "product_id": "wingman_monthly", "source": "onboarding"]
        let merged = Analytics.properties(
            existing,
            adding: PaywallAnalytics.priceProperties(price: Decimal(string: "14.99")!, currencyCode: "USD")
        )
        XCTAssertEqual(merged["plan"] as? String, "monthly")
        XCTAssertEqual(merged["product_id"] as? String, "wingman_monthly")
        XCTAssertEqual(merged["source"] as? String, "onboarding")
        XCTAssertEqual(merged.count, 5)
    }
}
