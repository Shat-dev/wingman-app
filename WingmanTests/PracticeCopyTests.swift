//
//  PracticeCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, tenth slice: scenarios and XP.
//
//  The lesson-count label is the first string in the app to use a String
//  Catalog plural variant: the singular comes from the catalog, not from an
//  `if` in code. These tests therefore also check that the plural pipeline
//  actually works in the built app, with English output unchanged.
//

import XCTest
@testable import Wingman

@MainActor
final class PracticeCopyTests: XCTestCase {

    // MARK: - Lesson count (catalog plural)

    func testLessonCountForAnUnlockedScenario() {
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 1, isLocked: false), "1 lesson")
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 2, isLocked: false), "2 lessons")
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 5, isLocked: false), "5 lessons")
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 0, isLocked: false), "0 lessons")
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 21, isLocked: false), "21 lessons")
    }

    func testLessonCountForALockedScenario() {
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 1, isLocked: true), "1 lesson required")
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 2, isLocked: true), "2 lessons required")
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 12, isLocked: true), "12 lessons required")
        XCTAssertEqual(PracticeCopy.lessonCountLabel(count: 0, isLocked: true), "0 lessons required")
    }

    // MARK: - XP breakdown

    func testXPBreakdownLabels() {
        func labels(base: Int, fromCorrect: Int, bonus: Int, correctCount: Int) -> [String] {
            XPStore.Award(
                source: .lesson, sourceId: "lesson_1_1",
                amount: base + fromCorrect + bonus, totalAfter: 100,
                base: base, fromCorrect: fromCorrect, bonus: bonus, correctCount: correctCount
            ).components.map(\.label)
        }
        XCTAssertEqual(labels(base: 10, fromCorrect: 0, bonus: 0, correctCount: 0), ["Completed"])
        XCTAssertEqual(labels(base: 10, fromCorrect: 2, bonus: 0, correctCount: 1), ["Completed", "1 correct"])
        XCTAssertEqual(labels(base: 10, fromCorrect: 4, bonus: 0, correctCount: 2), ["Completed", "2 correct"])
        XCTAssertEqual(labels(base: 10, fromCorrect: 6, bonus: 5, correctCount: 3), ["Completed", "3 correct", "All correct"])
    }

    // MARK: - Errors shown to the user

    func testPracticeErrorMessages() {
        XCTAssertEqual(PracticeServiceError.notAuthenticated.errorDescription, "Please log in to access practices.")
        XCTAssertEqual(PracticeServiceError.scenarioNotFound.errorDescription, "Scenario not found.")
        XCTAssertEqual(PracticeServiceError.invalidData("missing screens").errorDescription, "Data error: missing screens")
        XCTAssertEqual(
            PracticeServiceError.networkError.errorDescription,
            "No internet connection. Please check your network and try again."
        )
    }
}
