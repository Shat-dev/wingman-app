//
//  AnalyticsPropertiesTests.swift
//  WingmanTests
//
//  WP2 of the localization plan: the lesson, course, scenario, approach-level
//  and commitment values sent to PostHog are the English canonical ones, and
//  match what PostHog already holds (docs/localization-analytics-baseline.md,
//  captured from production before any localization change).
//

import XCTest
@testable import Wingman

@MainActor
final class AnalyticsPropertiesTests: XCTestCase {

    // MARK: - Lessons vs production history

    private struct BaselineLesson: Decodable {
        let lesson_id: String
        let lesson_name: String
        let category: String
    }

    private func lessonBaseline() throws -> [BaselineLesson] {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "lesson-analytics-baseline", withExtension: "json"),
            "Fixture missing from the test bundle"
        )
        return try JSONDecoder().decode([BaselineLesson].self, from: Data(contentsOf: url))
    }

    private func allBundledLessons() -> [Lesson] {
        (1...25).flatMap { LessonDataService.shared.loadLessonsForCourse(courseId: "course_\($0)") }
    }

    /// Every lesson the app ships sends exactly the `lesson_name` and
    /// `category` that production events carried before this work.
    func testLessonNamesAndCategoriesMatchProductionBaseline() throws {
        let baseline = try lessonBaseline()
        XCTAssertEqual(baseline.count, 94)

        let lessons = Dictionary(uniqueKeysWithValues: allBundledLessons().map { ($0.id, $0) })
        XCTAssertEqual(lessons.count, 94, "Bundled lesson count changed")

        for row in baseline {
            let lesson = try XCTUnwrap(lessons[row.lesson_id], "\(row.lesson_id) is no longer bundled")
            let properties = lesson.analyticsProperties
            XCTAssertEqual(properties["lesson_id"] as? String, row.lesson_id)
            XCTAssertEqual(properties["lesson_name"] as? String, row.lesson_name, row.lesson_id)
            XCTAssertEqual(properties["category"] as? String, row.category, row.lesson_id)
        }
    }

    func testLessonPropertiesShape() throws {
        let lesson = try XCTUnwrap(allBundledLessons().first { $0.id == "lesson_12_1" })
        let properties = lesson.analyticsProperties
        XCTAssertEqual(Set(properties.keys), ["lesson_id", "lesson_name", "category", "course_id"])
        XCTAssertEqual(properties["course_id"] as? String, "course_12")
        XCTAssertEqual(properties["lesson_name"] as? String, "Never Run Out of Things to Say")
        // From the lesson JSON: capital T. The Swift catalog spells the same
        // course "Small talk & Momentum"; see the gate-event test below.
        XCTAssertEqual(properties["category"] as? String, "Small Talk & Momentum")
    }

    // MARK: - Course catalog vs production history

    /// `course_id` → (`course_title`, `previous_course_title`) as observed on
    /// `course_locked_encountered` in production.
    private let lockedCourseBaseline: [String: (title: String, previous: String)] = [
        "course_2": ("Fear & Exposure", "Beliefs & Reframes"),
        "course_3": ("Presence & Expressions", "Fear & Exposure"),
        "course_4": ("Inner Stability", "Presence & Expressions"),
        "course_5": ("Non-negotiables", "Inner Stability"),
        "course_7": ("The Physical Approach", "Approach Readiness"),
        "course_8": ("The Opener", "The Physical Approach"),
        "course_9": ("Reading & Responding", "The Opener"),
        "course_11": ("Advanced Opening Techniques", "Situational Specific Approaches"),
        "course_13": ("Listening & Attunement", "Small talk & Momentum"),
        "course_14": ("Sharing & Vulnerability", "Listening & Attunement"),
        "course_19": ("Compliments & Verbal Chemistry", "Playfulness & Spark"),
        "course_20": ("Physical Presence", "Compliments & Verbal Chemistry"),
        "course_21": ("Advanced Flirting Skills", "Physical Presence"),
        "course_23": ("Creating Opportunities", "Upgrading Your Lifestyle"),
        "course_24": ("Mastery & Identity", "Creating Opportunities"),
        "course_25": ("Learning & Self Discovery", "Mastery & Identity")
    ]

    private var catalog: [String: Course] {
        Dictionary(uniqueKeysWithValues: CourseCategory.dummyCategories.flatMap(\.courses).map { ($0.id, $0) })
    }

    private func previousCourse(of course: Course) -> Course? {
        let siblings = CourseCategory.dummyCategories
            .first { $0.id == course.categoryId }?
            .courses.sorted { $0.displayOrder < $1.displayOrder } ?? []
        guard let index = siblings.firstIndex(where: { $0.id == course.id }), index > 0 else { return nil }
        return siblings[index - 1]
    }

    func testCourseLockedPropertiesMatchProductionBaseline() throws {
        for (courseID, expected) in lockedCourseBaseline {
            let course = try XCTUnwrap(catalog[courseID], courseID)
            let previous = try XCTUnwrap(previousCourse(of: course), "\(courseID) has no previous course")

            let properties = CourseAnalytics.courseLockedEncountered(
                course: course,
                previousCourseID: previous.id,
                previousCourseCanonicalTitle: previous.canonicalTitle
            )
            XCTAssertEqual(properties["course_id"] as? String, courseID)
            XCTAssertEqual(properties["course_title"] as? String, expected.title, courseID)
            XCTAssertEqual(properties["previous_course_title"] as? String, expected.previous, courseID)
            XCTAssertEqual(properties["category_id"] as? String, course.categoryId)
            XCTAssertEqual(properties["previous_course_id"] as? String, previous.id)
        }
    }

    func testCourseLockedWithUnknownPreviousCourse() throws {
        let course = try XCTUnwrap(catalog["course_2"])
        let properties = CourseAnalytics.courseLockedEncountered(
            course: course,
            previousCourseID: nil,
            previousCourseCanonicalTitle: CourseAnalytics.unknownPreviousCourseTitle
        )
        XCTAssertEqual(properties["previous_course_title"] as? String, "the previous course")
        XCTAssertNil(properties["previous_course_id"])
    }

    func testLessonGateBlockedProperties() throws {
        let course = try XCTUnwrap(catalog["course_12"])
        let lesson = try XCTUnwrap(allBundledLessons().first { $0.id == "lesson_12_1" })
        let properties = CourseAnalytics.lessonGateBlocked(lesson: lesson, course: course)

        XCTAssertEqual(Set(properties.keys), ["lesson_id", "lesson_title", "course_id", "course_title"])
        XCTAssertEqual(properties["lesson_id"] as? String, "lesson_12_1")
        XCTAssertEqual(properties["lesson_title"] as? String, "Never Run Out of Things to Say")
        XCTAssertEqual(properties["course_id"] as? String, "course_12")
        // From the Swift catalog: lower-case "talk". This differs from the
        // `category` the lesson events send for the same course. Both are
        // existing production values and each must keep its own spelling.
        XCTAssertEqual(properties["course_title"] as? String, "Small talk & Momentum")
    }

    func testCategoryNamesAreTheBrandNames() {
        XCTAssertEqual(CourseCategory.dummyCategories.map(\.canonicalName), [
            "Mindset & Foundations",
            "Approach Mechanics",
            "Conversation Flow",
            "Flirting & Chemistry",
            "Integration & Mastery"
        ])
    }

    // MARK: - Scenarios

    func testScenarioProperties() {
        let game = PracticeGameData(id: "A1000001-0000-0000-0000-000000000001", title: "Bar Window", scenes: [])
        let properties = game.analyticsProperties(duringWalkthrough: false)
        XCTAssertEqual(Set(properties.keys), ["scenario_id", "scenario_name", "during_walkthrough"])
        XCTAssertEqual(properties["scenario_id"] as? String, "A1000001-0000-0000-0000-000000000001")
        XCTAssertEqual(properties["scenario_name"] as? String, "Bar Window")
        XCTAssertEqual(properties["during_walkthrough"] as? Bool, false)
        XCTAssertEqual(game.analyticsProperties(duringWalkthrough: true)["during_walkthrough"] as? Bool, true)
    }

    // MARK: - Approach levels

    func testApproachLevelNames() {
        let levels = LogApproachViewModel().levels
        XCTAssertEqual(levels.map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(levels.map(\.canonicalTitle), [
            "Social Warm-up",
            "Extended Conversation",
            "Indirect Approach",
            "Direct Approach"
        ])
    }

    // MARK: - Commitment pact

    func testCommitmentHeadlineIsTheFixedSentence() {
        XCTAssertEqual(CommitmentPactCopy.analyticsHeadline, "I am becoming a guy who takes action.")
        // The rendered headline can carry the user's name; the analytics
        // value never does.
        XCTAssertNotEqual(CommitmentPactCopy.headline(for: "Sam"), CommitmentPactCopy.analyticsHeadline)
        XCTAssertFalse(CommitmentPactCopy.analyticsHeadline.contains("Sam"))
    }

    // MARK: - Language super-properties

    func testLanguageSuperPropertiesForTheShippingApp() {
        let properties = Analytics.languageSuperProperties(preferredLanguages: ["de-DE", "en-AU"])
        XCTAssertEqual(Set(properties.keys), ["app_language", "device_language"])
        // The app ships English only, so it runs in English whatever the
        // device prefers. This flips only when a language is added on purpose.
        XCTAssertEqual(properties["app_language"] as? String, "en")
        XCTAssertEqual(properties["device_language"] as? String, "de-DE")
    }

    func testLanguageSuperPropertiesWithNoPreferredLanguage() {
        let properties = Analytics.languageSuperProperties(preferredLanguages: [])
        XCTAssertEqual(properties["device_language"] as? String, "unknown")
    }
}
