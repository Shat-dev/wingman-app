//
//  PaywallTrialTests.swift
//  WingmanTests
//
//  WP4 of the localization plan, second slice: the trial badge.
//
//  The badge was the literal "3-day Free Trial". It is now built from the
//  trial length the App Store reports for the product. These tests pin that
//  today's configuration (a three-day free trial) still reads exactly the
//  same, cover the other lengths an introductory offer can have, and check
//  that anything that is not a free trial gives no badge.
//

import XCTest
@testable import Wingman

@MainActor
final class PaywallTrialTests: XCTestCase {

    private func length(
        _ value: Int, _ unit: PaywallTrial.OfferUnit, periods: Int = 1, freeTrial: Bool = true
    ) -> PaywallTrial.Length? {
        PaywallTrial.length(isFreeTrial: freeTrial, periodValue: value, periodUnit: unit, numberOfPeriods: periods)
    }

    private func badge(
        _ value: Int, _ unit: PaywallTrial.OfferUnit, periods: Int = 1, freeTrial: Bool = true
    ) -> String? {
        length(value, unit, periods: periods, freeTrial: freeTrial).map(PaywallTrial.badge)
    }

    // MARK: - Today's products

    /// Parity: a three-day free trial reads exactly as the old literal did.
    func testThreeDayTrialReadsAsItAlwaysHas() {
        XCTAssertEqual(badge(3, .day), "3-day Free Trial")
    }

    // MARK: - Other lengths

    func testDayCounts() {
        XCTAssertEqual(badge(1, .day), "1-day Free Trial")
        XCTAssertEqual(badge(7, .day), "7-day Free Trial")
        XCTAssertEqual(badge(14, .day), "14-day Free Trial")
    }

    /// The App Store reports a one-week trial either as 7 days or as 1 week;
    /// both give the same badge.
    func testWeeksAreCountedInDays() {
        XCTAssertEqual(length(1, .week), PaywallTrial.Length(count: 7, unit: .day))
        XCTAssertEqual(badge(1, .week), badge(7, .day))
        XCTAssertEqual(badge(2, .week), "14-day Free Trial")
    }

    func testMonthsAndYears() {
        XCTAssertEqual(badge(1, .month), "1-month Free Trial")
        XCTAssertEqual(badge(3, .month), "3-month Free Trial")
        XCTAssertEqual(badge(1, .year), "1-year Free Trial")
    }

    /// An offer can repeat its period: three one-day periods are a three-day
    /// trial.
    func testRepeatedPeriodsAreMultiplied() {
        XCTAssertEqual(length(1, .day, periods: 3), PaywallTrial.Length(count: 3, unit: .day))
        XCTAssertEqual(badge(1, .day, periods: 3), "3-day Free Trial")
        XCTAssertEqual(badge(1, .week, periods: 2), "14-day Free Trial")
    }

    /// A period count of zero is treated as one, as the rest of the app's
    /// offer reading does.
    func testAZeroPeriodCountCountsAsOne() {
        XCTAssertEqual(length(3, .day, periods: 0), PaywallTrial.Length(count: 3, unit: .day))
    }

    // MARK: - No badge

    /// A discounted first period (the one-time offer's kind) is not a free
    /// trial.
    func testAPaidIntroductoryOfferGivesNoBadge() {
        XCTAssertNil(length(1, .year, freeTrial: false))
        XCTAssertNil(badge(3, .day, freeTrial: false))
    }

    func testANonsenseLengthGivesNoBadge() {
        XCTAssertNil(length(0, .day))
        XCTAssertNil(length(-3, .day))
    }

    // MARK: - One catalog entry per unit

    /// The number is a placeholder in a single entry, not text glued on, so
    /// a translation can vary the whole phrase by plural.
    func testEveryCountUsesTheSameEntry() {
        for count in [1, 2, 3, 5, 7, 21, 30] {
            XCTAssertEqual(badge(count, .day), "\(count)-day Free Trial")
        }
    }
}
