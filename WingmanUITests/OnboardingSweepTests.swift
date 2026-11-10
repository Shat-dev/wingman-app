//
//  OnboardingSweepTests.swift
//  WingmanUITests
//
//  Walks a fresh install from the landing screen to the paywall with fixed
//  answers, attaching a screenshot of every screen. The attachments are the
//  visual baseline for the localization work: run it before and after a
//  change (or in another language) and compare the images.
//
//  Needs a clean install: uninstall the app and reset the simulator keychain
//  first, otherwise a stored guest session skips onboarding.
//
//  Side effects of a run: tapping "Get started" creates an anonymous Supabase
//  user, and events are sent to PostHog tagged `environment = dev` (Debug).
//  Run it on a throwaway simulator and not in a loop.
//
//  Elements are found by their visible English text because the app has no
//  accessibility identifiers yet. Once other languages exist this needs
//  identifiers, or it will only run in English.
//

import XCTest

final class OnboardingSweepTests: XCTestCase {

    private var app: XCUIApplication!
    private var shot = 0

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testOnboardingToPaywall() {
        app.launch()

        // Landing
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 20), "Landing screen did not appear")
        snap("landing")
        getStarted.tap()

        // 1. Motivation (multi-select)
        answer("Want more confidence in general", name: "q-motivation")

        // 2. Age
        answer("25-34", name: "q-age")

        // 3. Last approach, then its statistic
        answer("Within the past month", name: "q-last-approach")
        continuePastStatistic(name: "stat-last-approach")

        // 4. Frequency, then its statistic
        answer("Sometimes", name: "q-approach-frequency")
        continuePastStatistic(name: "stat-approach-frequency")

        // 5. Barriers (multi-select), then its statistic
        answer("Not knowing what to say or how to start", name: "q-barriers")
        continuePastStatistic(name: "stat-barriers")

        // 6. Goals (multi-select), then its statistic
        answer("Learning how to approach", name: "q-goals")
        continuePastStatistic(name: "stat-goals")

        // 7. Growth projection
        let projectionContinue = app.buttons["Continue"]
        XCTAssertTrue(projectionContinue.waitForExistence(timeout: 10), "Growth projection did not appear")
        settle(2.5) // chart animation
        snap("growth-projection")
        projectionContinue.tap()

        // 8. Loading screen, with the system notification prompt on top
        settle(1.0)
        snap("loading")
        dismissNotificationPromptIfShown()

        // 9. Social proof
        let socialContinue = app.buttons["Continue"]
        XCTAssertTrue(socialContinue.waitForExistence(timeout: 20), "Social proof did not appear")
        settle(1.0)
        snap("social-proof")
        socialContinue.tap()

        // 10. Commitment pact (press and hold). Skipped by the app if the
        //     pact is switched off, so its absence is not a failure.
        let commit = app.descendants(matching: .any)["Commit"]
        if commit.waitForExistence(timeout: 8) {
            settle(0.8)
            snap("commitment-pact")
            commit.press(forDuration: 2.5)
        }

        // 11. Paywall. The close button appears a few seconds after the
        //     paywall does. A Debug build cannot load prices, so this
        //     captures the "Can't load pricing" state; the priced paywall
        //     needs a Release build.
        let close = app.buttons["Close paywall"]
        XCTAssertTrue(close.waitForExistence(timeout: 25), "Paywall did not appear")
        settle(2.0)
        snap("paywall")
    }

    // MARK: - Steps

    private func answer(_ option: String, name: String) {
        let button = app.buttons[option]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Option \"\(option)\" did not appear")
        settle(0.6)
        snap(name)
        button.tap()
        settle(0.6)
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Next button missing on \(name)")
        next.tap()
    }

    private func continuePastStatistic(name: String) {
        let hint = app.buttons["Tap to continue"]
        let hintText = app.staticTexts["Tap to continue"]
        let appeared = hint.waitForExistence(timeout: 10) || hintText.waitForExistence(timeout: 2)
        XCTAssertTrue(appeared, "Statistic screen \(name) did not appear")
        settle(1.0)
        snap(name)
        if hint.exists && hint.isHittable {
            hint.tap()
        } else if hintText.exists && hintText.isHittable {
            hintText.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        }
    }

    private func dismissNotificationPromptIfShown() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don\u{2019}t Allow"]
        if deny.waitForExistence(timeout: 12) {
            snap("loading-notification-prompt")
            deny.tap()
        }
    }

    // MARK: - Helpers

    private func settle(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func snap(_ name: String) {
        shot += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", shot, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
