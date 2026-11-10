//
//  OnboardingSweepTests.swift
//  WingmanUITests
//
//  Walks a fresh install from the landing screen through onboarding, the
//  paywall, the first-run walkthrough and the four tabs, with fixed answers,
//  attaching a screenshot of every screen. The attachments are the visual
//  baseline for the localization work: run it before and after a change and
//  compare the images.
//
//  Two runs, one test method each. Run ONE method per run
//  (`-only-testing:WingmanUITests/OnboardingSweepTests/<method>`):
//
//    testOnboardingToPaywall
//        English, as shipped. Screens 01-17 are compared against
//        docs/localization-baseline.
//
//    testOnboardingInDoubleLengthPseudoLanguage
//        The same walk with every localized string doubled
//        (`-NSDoubleLocalizedStrings YES`, the system's pseudo-language) and
//        the layouts built for translated apps switched on
//        (`-l10nForceTranslatedLayout YES`). Nothing is compared; the
//        screenshots are read for clipped, cut or overlapping text. No
//        language has to exist for this.
//
//  Needs a clean install: uninstall the app and reset the simulator keychain
//  first, otherwise a stored guest session skips onboarding.
//
//  Side effects of a run: tapping "Get started" creates an anonymous Supabase
//  user, and events are sent to PostHog tagged `environment = dev` (Debug).
//  Each method is one such user. Run it on a throwaway simulator and not in
//  a loop.
//
//  Elements are found by the start of their visible English text because the
//  app has no accessibility identifiers yet (the start, so that a doubled
//  string still matches). Once real languages exist this needs identifiers,
//  or it will only run in English.
//
//  Everything up to the paywall is asserted. What follows the paywall is
//  walked as far as it goes and never fails the run: those screens depend on
//  the network and on feature switches, and a missing one should not cost
//  the screenshots already taken.
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
        walkFromLandingThroughTheApp()
    }

    func testOnboardingInDoubleLengthPseudoLanguage() {
        app.launchArguments += [
            "-NSDoubleLocalizedStrings", "YES",
            "-l10nForceTranslatedLayout", "YES"
        ]
        app.launch()
        walkFromLandingThroughTheApp()
    }

    // MARK: - The walk

    private func walkFromLandingThroughTheApp() {
        // Landing
        let getStarted = button("Get started")
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
        let projectionContinue = button("Continue")
        XCTAssertTrue(projectionContinue.waitForExistence(timeout: 10), "Growth projection did not appear")
        settle(2.5) // chart animation
        snap("growth-projection")
        projectionContinue.tap()

        // 8. Loading screen, with the system notification prompt on top
        settle(1.0)
        snap("loading")
        dismissNotificationPromptIfShown()

        // 9. Social proof
        let socialContinue = button("Continue")
        XCTAssertTrue(socialContinue.waitForExistence(timeout: 20), "Social proof did not appear")
        settle(1.0)
        snap("social-proof")
        socialContinue.tap()

        // 10. Commitment pact (press and hold). Skipped by the app if the
        //     pact is switched off, so its absence is not a failure.
        let commit = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Commit")).firstMatch
        if commit.waitForExistence(timeout: 8) {
            settle(0.8)
            snap("commitment-pact")
            commit.press(forDuration: 2.5)
        }

        // 11. Paywall. The close button appears a few seconds after the
        //     paywall does. A Debug build cannot load prices, so this
        //     captures the "Can't load pricing" state; the priced paywall
        //     needs a Release build.
        let close = button("Close paywall")
        XCTAssertTrue(close.waitForExistence(timeout: 25), "Paywall did not appear")
        settle(2.0)
        snap("paywall")

        walkPastThePaywall(close: close)
    }

    /// Paywall closed -> one-time offer (if it can be shown) -> first-run
    /// walkthrough -> the four tabs. Best effort: see the file header.
    private func walkPastThePaywall(close: XCUIElement) {
        close.tap()

        // 12. One-time offer. It closes itself when it cannot be honoured,
        //     which is always the case in a Debug build (no products), so
        //     this is normally skipped.
        let closeOffer = button("Close offer")
        if closeOffer.waitForExistence(timeout: 6) {
            settle(1.0)
            snap("one-time-offer")
            closeOffer.tap()
        }

        // 13. Walkthrough: five cards, each on top of a dimmed tab. A tap
        //     anywhere moves on.
        let cards: [(text: String, name: String)] = [
            ("Welcome to Wingman", "walkthrough-home"),
            ("Courses. Mindset", "walkthrough-courses"),
            ("And this is where you practise", "walkthrough-scenarios"),
            ("Last one. This one is you", "walkthrough-profile"),
            ("Good luck", "walkthrough-sign-off")
        ]
        for (index, card) in cards.enumerated() {
            let shown = anything(containing: card.text)
            guard shown.waitForExistence(timeout: index == 0 ? 20 : 8) else {
                snap("stopped-before-\(card.name)")
                return
            }
            settle(1.2)
            snap(card.name)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        }

        // 14. The four tabs, as a new user who closed the paywall sees them.
        settle(2.5)
        for (tab, name) in [("Home", "tab-home"), ("Courses", "tab-courses"), ("Scenarios", "tab-scenarios"), ("Profile", "tab-profile")] {
            let tabButton = button(tab)
            guard tabButton.waitForExistence(timeout: 8), tabButton.isHittable else {
                snap("stopped-before-\(name)")
                return
            }
            tabButton.tap()
            settle(2.0)
            snap(name)
        }
    }

    // MARK: - Steps

    private func answer(_ option: String, name: String) {
        let optionButton = button(option)
        XCTAssertTrue(optionButton.waitForExistence(timeout: 10), "Option \"\(option)\" did not appear")
        settle(0.6)
        snap(name)
        optionButton.tap()
        settle(0.6)
        let next = button("Next")
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Next button missing on \(name)")
        next.tap()
    }

    private func continuePastStatistic(name: String) {
        let hint = button("Tap to continue")
        let hintText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Tap to continue")).firstMatch
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

    /// The first button whose label starts with `text`. The start, not the
    /// whole label, so that a doubled pseudo-language string still matches.
    private func button(_ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    /// The first element of any kind whose label contains `text`.
    private func anything(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

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
