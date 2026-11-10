//
//  ApproachCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, eighth slice: approach logging and profile.
//  Pins the English wording that became localizable, and the approach list's
//  date text: unchanged in English, locale-aware once the app is translated.
//

import XCTest
@testable import Wingman

@MainActor
final class ApproachCopyTests: XCTestCase {

    // MARK: - Log approach form

    func testConfidenceDescriptions() {
        let viewModel = LogApproachViewModel()
        let expected: [Double: String] = [
            1: "Very anxious",
            2: "Anxious",
            3: "Slightly nervous",
            4: "Moderate anxiety",
            5: "Neutral",
            6: "Somewhat confident",
            7: "Confident",
            8: "Very confident",
            9: "Extremely confident",
            10: "Very confident"
        ]
        for (level, text) in expected {
            viewModel.anxietyLevel = level
            XCTAssertEqual(viewModel.anxietyLevelText, text, "level \(level)")
        }
        viewModel.anxietyLevel = 0
        XCTAssertEqual(viewModel.anxietyLevelText, "Moderate")
    }

    func testFormTitlesForANewApproach() {
        let viewModel = LogApproachViewModel()
        XCTAssertFalse(viewModel.isEditMode)
        XCTAssertEqual(viewModel.saveButtonTitle, "Log Approach")
        XCTAssertEqual(viewModel.headerTitle, "Log Approach")
        XCTAssertEqual(
            viewModel.placeholderText,
            "Congratulations! How did you feel? What was the situation? How did it go for you?"
        )
    }

    /// One sentence per case; before, a verb was inserted into a shared one.
    func testSaveFailureMessages() {
        XCTAssertEqual(LogApproachViewModel.saveFailureMessage(isEdit: false), "Failed to save. Please try again.")
        XCTAssertEqual(LogApproachViewModel.saveFailureMessage(isEdit: true), "Failed to update. Please try again.")
    }

    /// The level names sent to analytics are still the plain English ones.
    func testLevelNamesForAnalyticsAreUnchanged() {
        XCTAssertEqual(LogApproachViewModel().levels.map(\.canonicalTitle), [
            "Social Warm-up", "Extended Conversation", "Indirect Approach", "Direct Approach"
        ])
    }

    // MARK: - Approach list dates

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testRelativeDayText() {
        let now = date(2026, 11, 10)
        func text(_ date: Date) -> String {
            ApproachDateText.string(for: date, now: now, calendar: calendar)
        }
        XCTAssertEqual(text(now), "Today")
        XCTAssertEqual(text(date(2026, 11, 9)), "1 day ago")
        XCTAssertEqual(text(date(2026, 11, 8)), "2 days ago")
        XCTAssertEqual(text(date(2026, 11, 4)), "6 days ago")
    }

    /// A week or more old: the fixed "MMM d, yyyy" form the list has always
    /// used in English.
    func testOlderDatesKeepTheEnglishFormat() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let old = date(2026, 10, 20)

        XCTAssertEqual(
            ApproachDateText.string(for: old, now: date(2026, 11, 10), calendar: calendar),
            formatter.string(from: old)
        )
        XCTAssertEqual(
            ApproachDateText.calendarDate(old, isSourceLanguage: true, locale: Locale(identifier: "de_DE")),
            formatter.string(from: old),
            "While the app is English, the device region must not change the date format"
        )
        // On the simulator's US English settings this is the familiar form.
        if Locale.current.identifier.hasPrefix("en_US") {
            XCTAssertEqual(formatter.string(from: old).prefix(4), "Oct ")
            XCTAssertTrue(formatter.string(from: old).hasSuffix(", 2026"))
        }
    }

    /// In a translated app the date follows the locale: day first in German.
    func testOlderDatesFollowTheLocaleInATranslatedApp() {
        let old = date(2026, 10, 20)
        let german = ApproachDateText.calendarDate(old, isSourceLanguage: false, locale: Locale(identifier: "de_DE"))
        let english = ApproachDateText.calendarDate(old, isSourceLanguage: true, locale: Locale(identifier: "de_DE"))

        XCTAssertNotEqual(german, english)
        XCTAssertTrue(german.contains("2026"))
        XCTAssertTrue(german.contains("Okt"), "Expected a German month abbreviation, got \(german)")
        let dayIndex = try? XCTUnwrap(german.range(of: "20")).lowerBound
        let monthIndex = try? XCTUnwrap(german.range(of: "Okt")).lowerBound
        if let dayIndex, let monthIndex {
            XCTAssertTrue(dayIndex < monthIndex, "German dates put the day before the month: \(german)")
        }
    }
}
