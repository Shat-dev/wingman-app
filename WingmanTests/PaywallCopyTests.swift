//
//  PaywallCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, fourth slice: the paywall and one-time-offer
//  copy that is not pricing or legal disclosure became localizable. These
//  tests pin the English wording, and check that the purchase-failure
//  `reason` — the value sent to analytics as `failure_reason` — is an
//  identifier that stays the same whatever the message says.
//
//  (The personalised tick lines are pinned in
//  PersonalisationCharacterizationTests.)
//

import XCTest
@testable import Wingman

@MainActor
final class PaywallCopyTests: XCTestCase {

    // MARK: - Main paywall page

    private let answerKeys = ["onboarding_barriers", "onboarding_goals"]
    private var savedAnswers: [String: String?] = [:]

    override func setUp() {
        super.setUp()
        // The test host is a real install and may hold onboarding answers.
        for key in answerKeys {
            savedAnswers[key] = UserDefaults.standard.string(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in answerKeys {
            if let value = savedAnswers[key] ?? nil {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testMainPageWithNoAnswers() {
        let page = PaywallCopy.mainPage
        XCTAssertEqual(page.imageName, "paywall_1")
        XCTAssertEqual(page.headline, "Day 1 of becoming the guy who goes for it")
        XCTAssertEqual(page.bullets, [
            "Stop talking yourself out of it",
            "Go first without overthinking it",
            "No more \u{201C}what if\u{201D} moments"
        ])
    }

    /// The same answers the screenshot baseline was captured with: the first
    /// pick of each multi-select answer drives its tick.
    func testMainPageUsesTheFirstPickOfEachAnswer() {
        UserDefaults.standard.set("Not knowing what to say or how to start, Other", forKey: "onboarding_barriers")
        UserDefaults.standard.set("Learning how to approach, Better mindset & confidence", forKey: "onboarding_goals")
        XCTAssertEqual(PaywallCopy.mainPage.bullets, [
            "Know exactly how to start talking",
            "Walk up to her without hesitating",
            "No more \u{201C}what if\u{201D} moments"
        ])
    }

    // MARK: - Purchase alerts

    func testAlertTitles() {
        XCTAssertEqual(PurchaseAlertKind.error.title, "Error")
        XCTAssertEqual(PurchaseAlertKind.info.title, "Waiting for approval")
    }

    /// RevenueCat error code (raw value, from the SDK's `ErrorCode`) →
    /// the `reason` sent to analytics and the message shown.
    private let failures: [(code: Int, reason: String, message: String)] = [
        (20, "payment_pending", "This purchase needs approval before it can go through \u{2014} usually from the account holder or your bank. You'll get access automatically once it's approved."),
        (2, "store_problem", "The App Store is having trouble right now. Please try again in a few minutes."),
        (3, "not_allowed", "Purchases aren't allowed on this device. Check Screen Time restrictions and try again."),
        (4, "payment_invalid", "That payment method was declined. Check your payment details in the App Store and try again."),
        (5, "product_unavailable", "This plan isn't available on your App Store account right now."),
        (6, "already_purchased", "You already have a subscription on this account. Tap Restore to get access back."),
        (7, "already_purchased", "You already have a subscription on this account. Tap Restore to get access back."),
        (10, "network", "You appear to be offline. Reconnect and try again."),
        (35, "network", "You appear to be offline. Reconnect and try again."),
        (12, "backend", "Something went wrong on our end. Please try again."),
        (16, "backend", "Something went wrong on our end. Please try again."),
        (23, "configuration", "Purchases are temporarily unavailable. Please try again later."),
        (11, "configuration", "Purchases are temporarily unavailable. Please try again later."),
        (17, "configuration", "Purchases are temporarily unavailable. Please try again later.")
    ]

    func testPurchaseFailureMessagesAndReasons() {
        for expected in failures {
            let failure = PurchaseFailure(NSError(domain: "RevenueCat.ErrorCode", code: expected.code))
            XCTAssertEqual(failure.reason, expected.reason, "code \(expected.code)")
            XCTAssertEqual(failure.message, expected.message, "code \(expected.code)")
        }
    }

    func testOnlyAPendingPaymentIsInformational() {
        for expected in failures {
            let failure = PurchaseFailure(NSError(domain: "RevenueCat.ErrorCode", code: expected.code))
            if expected.code == 20 {
                guard case .info = failure.alertKind else { return XCTFail("A pending payment should not read as an error") }
            } else {
                guard case .error = failure.alertKind else { return XCTFail("code \(expected.code) should be an error") }
            }
        }
    }

    func testUnmappedAndForeignErrorsUseTheGenericMessage() {
        let unmapped = PurchaseFailure(NSError(domain: "RevenueCat.ErrorCode", code: 8))
        XCTAssertEqual(unmapped.reason, "store_error")
        XCTAssertEqual(unmapped.message, "Purchase failed. Please try again.")

        let foreign = PurchaseFailure(NSError(domain: NSURLErrorDomain, code: -1009))
        XCTAssertEqual(foreign.reason, "store_error")
        XCTAssertEqual(foreign.message, "Purchase failed. Please try again.")
    }

    /// `reason` goes to analytics. It must be a plain identifier, never the
    /// message text.
    func testFailureReasonsAreIdentifiers() {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz_")
        for expected in failures {
            let reason = PurchaseFailure(NSError(domain: "RevenueCat.ErrorCode", code: expected.code)).reason
            XCTAssertTrue(reason.unicodeScalars.allSatisfy(allowed.contains), "\(reason) is not an identifier")
        }
    }
}
