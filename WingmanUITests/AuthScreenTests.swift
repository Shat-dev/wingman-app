//
//  AuthScreenTests.swift
//  WingmanUITests
//
//  The sign-in screen reached from the landing screen's "Log in" link.
//
//  Unlike the onboarding sweep this never taps "Get started", so it signs
//  nobody in and creates no guest user.
//
//  It needs a fresh install (a simulator that still holds a session opens on
//  the paywall or home instead of the landing screen):
//
//      xcrun simctl uninstall <udid> com.lazul.wingman
//      xcrun simctl keychain <udid> reset
//
//  This is the voluntary sign-in screen, which has no legal line: that line
//  is only shown on the sign-in screens that follow the paywall or a
//  purchase. Its two layouts are covered by AuthLegalCopyTests (unit tests)
//  and by the onboarding sweep when it is run past the paywall.
//

import XCTest

final class AuthScreenTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testVoluntaryLoginScreen() {
        let app = XCUIApplication()
        app.launch()

        // One button holding two texts, read as "Already have an account? Log in".
        let logIn = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Log in")).firstMatch
        XCTAssertTrue(
            logIn.waitForExistence(timeout: 20),
            "Landing screen did not appear. This test needs a fresh install: uninstall the app and reset the simulator's keychain first."
        )
        logIn.tap()
        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 10), "Sign-in screen did not appear")
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        Thread.sleep(forTimeInterval: 1.0)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "auth-login-voluntary"
        attachment.lifetime = .keepAlways
        add(attachment)

        // No legal line here; see the file header.
        XCTAssertFalse(app.buttons["Terms"].exists)
        XCTAssertFalse(app.links["Terms"].exists)

        // Back returns to the landing screen.
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
    }
}
