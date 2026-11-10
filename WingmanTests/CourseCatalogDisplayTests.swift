//
//  CourseCatalogDisplayTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, seventh slice: the course catalog.
//
//  A course title is two things now: `title` / `canonicalTitle` (English,
//  what analytics sends) and `displayTitle` (what the user reads). These
//  tests check English is unchanged, that a translation moves the display
//  side only, and that category names — brand terms — are never translated.
//

import XCTest
@testable import Wingman

@MainActor
final class CourseCatalogDisplayTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    private func useTranslations(_ translations: [String: String]) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("course-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: translations, format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    private var courses: [Course] { CourseCategory.dummyCategories.flatMap(\.courses) }

    private func course(_ id: String) throws -> Course {
        try XCTUnwrap(courses.first { $0.id == id }, id)
    }

    // MARK: - English

    func testCatalogHas25CoursesInFiveCategories() {
        XCTAssertEqual(CourseCategory.dummyCategories.count, 5)
        XCTAssertEqual(courses.count, 25)
        XCTAssertEqual(Set(courses.map(\.title)).count, 25)
    }

    func testDisplayTitlesAreTheEnglishTitles() {
        for course in courses {
            XCTAssertEqual(course.displayTitle, course.title)
            XCTAssertEqual(course.canonicalTitle, course.title)
        }
    }

    func testEveryCourseTitleHasAContentCatalogEntry() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: L10n.contentTable, withExtension: "strings"))
        let catalog = Set((try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])).keys)
        for course in courses {
            XCTAssertTrue(catalog.contains(course.title), "No Content.xcstrings entry for the course \"\(course.title)\"")
        }
    }

    // MARK: - Lock banner

    func testLockBannerInEnglish() {
        XCTAssertNil(CourseLockReason.unlocked.bannerText)
        XCTAssertEqual(
            CourseLockReason.awaitingPrevious(
                previousCourseTitle: "Beliefs & Reframes",
                previousCourseID: "course_1",
                previousCourseCanonicalTitle: "Beliefs & Reframes"
            ).bannerText,
            "Complete all lessons in Beliefs & Reframes to unlock this course."
        )
        // Same sentence the banner has always shown when the previous course
        // could not be resolved.
        XCTAssertEqual(
            CourseLockReason.awaitingPrevious(
                previousCourseTitle: nil,
                previousCourseID: nil,
                previousCourseCanonicalTitle: CourseAnalytics.unknownPreviousCourseTitle
            ).bannerText,
            "Complete all lessons in the previous course to unlock this course."
        )
    }

    func testLockReasonFromTheViewModelCarriesBothTitles() throws {
        let viewModel = CoursesViewModel()
        viewModel.loadCourses()
        let second = try course("course_2")
        guard case .awaitingPrevious(let shown, let id, let canonical) = viewModel.courseLockReason(second) else {
            // course_1 may already be complete on this install; nothing to check then.
            throw XCTSkip("course_2 is unlocked on this simulator")
        }
        XCTAssertEqual(shown, "Beliefs & Reframes")
        XCTAssertEqual(id, "course_1")
        XCTAssertEqual(canonical, "Beliefs & Reframes")
    }

    // MARK: - Translated

    func testTranslationChangesTheDisplayedTitleOnly() throws {
        let first = try course("course_1")
        let second = try course("course_2")

        try useTranslations([
            "Beliefs & Reframes": "Überzeugungen & Umdeutungen",
            "Mindset & Foundations": "Denkweise & Grundlagen"
        ])

        XCTAssertEqual(first.displayTitle, "Überzeugungen & Umdeutungen")
        XCTAssertEqual(first.title, "Beliefs & Reframes")
        XCTAssertEqual(first.canonicalTitle, "Beliefs & Reframes")
        // No translation for this one: English.
        XCTAssertEqual(second.displayTitle, "Fear & Exposure")

        // What analytics sends for a locked course is still English, even
        // though the banner shows the translated title.
        let properties = CourseAnalytics.courseLockedEncountered(
            course: second,
            previousCourseID: first.id,
            previousCourseCanonicalTitle: first.canonicalTitle
        )
        XCTAssertEqual(properties["previous_course_title"] as? String, "Beliefs & Reframes")
        XCTAssertEqual(properties["course_title"] as? String, "Fear & Exposure")
    }

    /// Category names are brand terms: shown in English even when a
    /// translation for the same text happens to exist.
    func testCategoryNamesAreNeverTranslated() throws {
        let english = CourseCategory.dummyCategories.map(\.displayName)
        XCTAssertEqual(english, [
            "Mindset & Foundations",
            "Approach Mechanics",
            "Conversation Flow",
            "Flirting & Chemistry",
            "Integration & Mastery"
        ])
        try useTranslations(["Mindset & Foundations": "Denkweise & Grundlagen"])
        XCTAssertEqual(CourseCategory.dummyCategories.map(\.displayName), english)
    }
}
