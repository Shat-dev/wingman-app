//
//  WalkthroughAndErrorCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, twelfth slice: the walkthrough cards, and
//  the error descriptions that end in developer-facing detail.
//

import XCTest
@testable import Wingman

@MainActor
final class WalkthroughAndErrorCopyTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    /// Puts `L10n` into "translated app" mode with an empty German table.
    private func useATranslatedApp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copy-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    // MARK: - Walkthrough

    /// The cards are written with deliberate line breaks; making them
    /// localizable must keep every character, the breaks included.
    func testWalkthroughCards() {
        XCTAssertEqual(
            WalkthroughOverlayView.welcome,
            "Welcome to Wingman. This is home.\nDaily practice keeps you sharp. The log fills with moments you took, not replayed."
        )
        XCTAssertEqual(
            WalkthroughOverlayView.coursesTour,
            "Courses. Mindset, approaching, flirting, follow-up.\nShort lessons that build the man who moves, not the one who freezes."
        )
        XCTAssertEqual(
            WalkthroughOverlayView.scenarioTour,
            "And this is where you practise.\nBookstore, gym, coffee shop. Choose what to say, see what happens."
        )
        XCTAssertEqual(
            WalkthroughOverlayView.progressTour,
            "Last one. This one is you.\nEmpty today. In a month it either tells a story or it doesn't."
        )
        XCTAssertEqual(WalkthroughOverlayView.signOff, "Good luck, we're rooting for you.")
    }

    func testWalkthroughHintsAndNudges() {
        XCTAssertEqual(WalkthroughOverlayView.continueHint, "Tap to continue")
        XCTAssertEqual(WalkthroughOverlayView.startFillingHint, "Start filling it")
        XCTAssertEqual(WalkthroughOverlayView.finishHint, "Tap to finish")
        XCTAssertEqual(WalkthroughOverlayView.nudgeText(.lesson), "Almost done, you'll be free to explore in a second.")
        XCTAssertEqual(WalkthroughOverlayView.nudgeText(.dailyPractice), "One thing at a time. Play the scenario first.")
        XCTAssertEqual(WalkthroughOverlayView.nudgeText(.lockedScenario), "That one's further down the line. Start with the first.")
    }

    // MARK: - Messages with technical detail

    func testEnglishKeepsTheTechnicalDetail() {
        XCTAssertEqual(L10n.withTechnicalDetail(english: "Failed: boom", translated: "Sorry."), "Failed: boom")
    }

    func testATranslatedAppGetsTheWholeSentenceAndNeverBuildsTheEnglishOne() throws {
        try useATranslatedApp()
        var builtEnglish = false
        func english() -> String { builtEnglish = true; return "Failed: boom" }
        XCTAssertEqual(L10n.withTechnicalDetail(english: english(), translated: "Sorry."), "Sorry.")
        XCTAssertFalse(builtEnglish)
    }

    func testDailyPracticeErrorsInEnglish() {
        XCTAssertEqual(
            DailyPracticeError.notAuthenticated.errorDescription,
            "User not authenticated. Please log in to access daily practice questions."
        )
        XCTAssertEqual(DailyPracticeError.failedToFetchQuestions("timeout").errorDescription, "Failed to fetch daily questions: timeout")
        XCTAssertEqual(DailyPracticeError.failedToSubmitCompletion("timeout").errorDescription, "Failed to submit completion: timeout")
        XCTAssertEqual(DailyPracticeError.failedToCheckCompletionStatus("timeout").errorDescription, "Failed to check completion status: timeout")
        XCTAssertEqual(DailyPracticeError.failedToFetchStatus("timeout").errorDescription, "Failed to fetch daily practice status: timeout")
        XCTAssertEqual(DailyPracticeError.failedToUpdateStreak("timeout").errorDescription, "Failed to update daily practice streak: timeout")
        XCTAssertEqual(DailyPracticeError.invalidQuestionData.errorDescription, "Invalid question data received")
        XCTAssertEqual(
            DailyPracticeError.networkError.errorDescription,
            "No internet connection. Please check your network and try again."
        )
    }

    func testDailyPracticeErrorsInATranslatedAppDropTheDetail() throws {
        try useATranslatedApp()
        let detail = "PGRST301 JWT expired"
        let errors: [DailyPracticeError] = [
            .failedToFetchQuestions(detail), .failedToSubmitCompletion(detail),
            .failedToCheckCompletionStatus(detail), .failedToFetchStatus(detail), .failedToUpdateStreak(detail)
        ]
        for error in errors {
            let description = try XCTUnwrap(error.errorDescription)
            XCTAssertFalse(description.contains(detail), description)
            XCTAssertFalse(description.isEmpty)
        }
    }

    func testRevenueCatErrorsInEnglish() {
        XCTAssertEqual(RevenueCatError.customerInfoFailed("x").errorDescription, "Failed to get customer info: x")
        XCTAssertEqual(RevenueCatError.offeringsFailed("x").errorDescription, "Failed to fetch products: x")
        XCTAssertEqual(RevenueCatError.purchaseFailed("x").errorDescription, "Purchase failed: x")
        XCTAssertEqual(RevenueCatError.restoreFailed("x").errorDescription, "Restore failed: x")
    }

    func testRevenueCatErrorsInATranslatedAppDropTheDetail() throws {
        try useATranslatedApp()
        for error in [RevenueCatError.customerInfoFailed("x9z"), .offeringsFailed("x9z"), .purchaseFailed("x9z"), .restoreFailed("x9z")] {
            XCTAssertFalse(try XCTUnwrap(error.errorDescription).contains("x9z"))
        }
    }
}
