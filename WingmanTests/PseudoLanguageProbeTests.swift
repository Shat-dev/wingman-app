//
//  PseudoLanguageProbeTests.swift
//  WingmanTests
//
//  What the system's double-length pseudo-language (`NSDoubleLocalizedStrings`)
//  does to this app's strings, checked without walking the app.
//
//  The pseudo-language sweep (`OnboardingSweepTests`) creates a guest user in
//  production every time it runs, so it should not be the place to discover
//  that doubling a string with a placeholder crashes or prints garbage. These
//  tests answer that first, on strings the sweep will meet.
//
//  Answer, 2026-11-10: nothing crashes. Plain strings double cleanly.
//  Strings with a placeholder show one garbled copy and one correct one.
//  Plural strings show raw format codes. See the tests for the details.
//
//  They are skipped unless the pseudo-language is switched on for the app,
//  which a normal test run never does. To run them on a simulator:
//
//      xcrun simctl spawn <udid> defaults write com.lazul.wingman NSDoubleLocalizedStrings -bool YES
//      xcodebuild test … -only-testing:WingmanTests/PseudoLanguageProbeTests
//      xcrun simctl spawn <udid> defaults delete com.lazul.wingman NSDoubleLocalizedStrings
//
//  Always run the last line: with the setting left on, most other tests fail.
//

import XCTest
@testable import Wingman

@MainActor
final class PseudoLanguageProbeTests: XCTestCase {

    private func requirePseudoLanguage() throws {
        try XCTSkipUnless(
            UserDefaults.standard.bool(forKey: "NSDoubleLocalizedStrings"),
            "The double-length pseudo-language is off (the normal case)."
        )
    }

    /// A plain string comes back twice.
    func testPlainStringsAreDoubled() throws {
        try requirePseudoLanguage()
        let value = String(localized: "Get started")
        print("PROBE plain: [\(value)]")
        XCTAssertEqual(value, "Get started Get started")
    }

    // The next three record what the pseudo-language does to strings with
    // placeholders, as observed on iOS 26.5 (2026-11-10). None of it crashes.
    // None of it is an app bug, and none of it happens in a real language:
    // it is how the system doubles a format string. Knowing it tells whoever
    // reads the sweep's screenshots what to ignore.

    /// A number placeholder: the second copy is correct, the first loses its
    /// placeholder ("lld days ago 15 days ago").
    func testANumberPlaceholderSurvivesInOneCopy() throws {
        try requirePseudoLanguage()
        let days = 15
        let value = String(localized: "\(days) days ago")
        print("PROBE number: [\(value)]")
        XCTAssertTrue(value.hasSuffix("15 days ago"), value)
        XCTAssertGreaterThan(value.count, "15 days ago".count + 5, value)
    }

    /// A text placeholder: same pattern ("… in @ to unlock … in Beliefs &
    /// Reframes to unlock …").
    func testATextPlaceholderSurvivesInOneCopy() throws {
        try requirePseudoLanguage()
        let value = CourseLockReason.awaitingPrevious(
            previousCourseTitle: "Beliefs & Reframes",
            previousCourseID: "course_1",
            previousCourseCanonicalTitle: "Beliefs & Reframes"
        ).bannerText ?? ""
        print("PROBE text: [\(value)]")
        XCTAssertTrue(value.contains("Beliefs & Reframes"), value)
        XCTAssertGreaterThan(value.count, 80, value)
    }

    /// A plural string is broken by the pseudo-language: it shows the raw
    /// plural format ("#@value@ %#@value@") in place of "3 lessons". Lesson
    /// counts in pseudo-language screenshots are therefore meaningless.
    func testAPluralStringIsBrokenByThePseudoLanguage() throws {
        try requirePseudoLanguage()
        let one = PracticeCopy.lessonCountLabel(count: 1, isLocked: false)
        let many = PracticeCopy.lessonCountLabel(count: 3, isLocked: true)
        print("PROBE plural: [\(one)] [\(many)]")
        XCTAssertFalse(one.isEmpty)
        XCTAssertFalse(many.isEmpty)
    }

    /// Data strings shown through `L10n.content` are not UI strings and are
    /// not doubled: the app is still in its source language.
    func testContentStringsAreNotDoubled() throws {
        try requirePseudoLanguage()
        XCTAssertEqual(L10n.content("Sometimes"), "Sometimes")
    }
}
