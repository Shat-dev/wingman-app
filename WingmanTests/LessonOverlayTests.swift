//
//  LessonOverlayTests.swift
//  WingmanTests
//
//  WP7 of the localization plan, fifth slice: translated lesson text laid
//  over the bundled English lessons by ID.
//
//  English must load exactly what it always has; a translation may only
//  change what is shown; anything it does not cover stays English; and the
//  lesson's English title must keep feeding analytics.
//

import XCTest
@testable import Wingman

@MainActor
final class LessonOverlayTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private var lessons: [Lesson] {
        [
            Lesson(
                id: "lesson_14_1", courseId: "course_14", courseSummary: "Share without oversharing.",
                courseTitle: "Sharing & Vulnerability", lessonNumber: 1, title: "Match First, Then Lead",
                duration: 3, summary: "Match her pace.", isCompleted: false, isLocked: false,
                screens: [
                    LessonScreen(id: "screen_14_1_1", order: 0, content: [
                        LessonContent(id: "content_14_1_1_1", text: "First paragraph.", order: 0),
                        LessonContent(id: "content_14_1_1_2", text: "Second paragraph.", order: 1)
                    ])
                ]
            ),
            Lesson(
                id: "lesson_14_2", courseId: "course_14", courseSummary: "Share without oversharing.",
                courseTitle: "Sharing & Vulnerability", lessonNumber: 2, title: "Offer Before You Ask",
                duration: 4, summary: "Give a little first.", isCompleted: true, isLocked: true,
                screens: [
                    LessonScreen(id: "screen_14_2_1", order: 0, content: [
                        LessonContent(id: "content_14_2_1_1", text: "Third paragraph.", order: 0)
                    ])
                ]
            )
        ]
    }

    private func encoded(_ lessons: [Lesson]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(lessons)
    }

    private func paragraphs(_ lessons: [Lesson]) -> [String] {
        lessons.flatMap(\.screens).flatMap(\.content).map(\.text)
    }

    // MARK: - No overlay

    func testAnEmptyOverlayLeavesLessonsUnchanged() throws {
        let result = LessonOverlay.apply([:], to: lessons)
        XCTAssertEqual(try encoded(result), try encoded(lessons))
        XCTAssertEqual(result.map(\.displayTitle), ["Match First, Then Lead", "Offer Before You Ask"])
        XCTAssertEqual(result.map(\.displaySummary), ["Match her pace.", "Give a little first."])
        XCTAssertEqual(result.map(\.displayCourseSummary), ["Share without oversharing.", "Share without oversharing."])
    }

    /// Without a translation the display accessors are the English fields.
    func testDisplayAccessorsDefaultToEnglish() {
        let lesson = lessons[0]
        XCTAssertEqual(lesson.displayTitle, lesson.title)
        XCTAssertEqual(lesson.displaySummary, lesson.summary)
        XCTAssertEqual(lesson.displayCourseSummary, lesson.courseSummary)
        XCTAssertEqual(lesson.displayCourseTitle, lesson.courseTitle)
    }

    // MARK: - A full overlay

    private var german: [String: String] {
        [
            "lesson_14_1.title": "Erst anpassen, dann führen",
            "lesson_14_1.summary": "Pass dich ihrem Tempo an.",
            "course_14.summary": "Teile, ohne zu viel zu teilen.",
            "content_14_1_1_1": "Erster Absatz.",
            "content_14_1_1_2": "Zweiter Absatz.",
            "content_14_2_1_1": "Dritter Absatz."
        ]
    }

    func testTranslatedTextIsShownAndEnglishFieldsAreKept() {
        let result = LessonOverlay.apply(german, to: lessons)

        XCTAssertEqual(result[0].displayTitle, "Erst anpassen, dann führen")
        XCTAssertEqual(result[0].displaySummary, "Pass dich ihrem Tempo an.")
        XCTAssertEqual(result[0].displayCourseSummary, "Teile, ohne zu viel zu teilen.")
        XCTAssertEqual(result[1].displayCourseSummary, "Teile, ohne zu viel zu teilen.", "one course summary serves every lesson")
        XCTAssertEqual(paragraphs(result), ["Erster Absatz.", "Zweiter Absatz.", "Dritter Absatz."])

        // The English fields are untouched.
        XCTAssertEqual(result[0].title, "Match First, Then Lead")
        XCTAssertEqual(result[0].summary, "Match her pace.")
        XCTAssertEqual(result[0].courseSummary, "Share without oversharing.")
        XCTAssertEqual(result[0].courseTitle, "Sharing & Vulnerability")
    }

    /// Requirement 5: analytics values are the same before and after.
    func testAnalyticsStillGetsTheEnglishTitle() {
        let result = LessonOverlay.apply(german, to: lessons)
        for (before, after) in zip(lessons, result) {
            XCTAssertEqual(after.canonicalTitle, before.canonicalTitle)
            XCTAssertEqual(after.canonicalCourseTitle, before.canonicalCourseTitle)
            XCTAssertEqual(
                after.analyticsProperties as NSDictionary,
                before.analyticsProperties as NSDictionary
            )
        }
    }

    func testStructureIsNeverChanged() {
        let result = LessonOverlay.apply(german, to: lessons)
        for (before, after) in zip(lessons, result) {
            XCTAssertEqual(after.id, before.id)
            XCTAssertEqual(after.courseId, before.courseId)
            XCTAssertEqual(after.lessonNumber, before.lessonNumber)
            XCTAssertEqual(after.duration, before.duration)
            XCTAssertEqual(after.isCompleted, before.isCompleted)
            XCTAssertEqual(after.isLocked, before.isLocked)
            XCTAssertEqual(after.screens.map(\.id), before.screens.map(\.id))
            XCTAssertEqual(after.screens.map(\.order), before.screens.map(\.order))
            XCTAssertEqual(after.screens.flatMap(\.content).map(\.id), before.screens.flatMap(\.content).map(\.id))
            XCTAssertEqual(after.screens.flatMap(\.content).map(\.order), before.screens.flatMap(\.content).map(\.order))
        }
    }

    // MARK: - Partial and broken overlays

    func testAnythingMissingStaysEnglish() {
        let partial = ["lesson_14_1.title": "Erst anpassen, dann führen", "content_14_1_1_2": "Zweiter Absatz."]
        let result = LessonOverlay.apply(partial, to: lessons)

        XCTAssertEqual(result[0].displayTitle, "Erst anpassen, dann führen")
        XCTAssertEqual(result[0].displaySummary, "Match her pace.")
        XCTAssertEqual(result[0].displayCourseSummary, "Share without oversharing.")
        XCTAssertEqual(result[1].displayTitle, "Offer Before You Ask")
        XCTAssertEqual(paragraphs(result), ["First paragraph.", "Zweiter Absatz.", "Third paragraph."])
    }

    func testBlankTranslationsStayEnglish() {
        let blank = ["lesson_14_1.title": "  ", "lesson_14_1.summary": "", "course_14.summary": "\n", "content_14_1_1_1": " "]
        let result = LessonOverlay.apply(blank, to: lessons)
        XCTAssertEqual(result[0].displayTitle, "Match First, Then Lead")
        XCTAssertEqual(result[0].displaySummary, "Match her pace.")
        XCTAssertEqual(result[0].displayCourseSummary, "Share without oversharing.")
        XCTAssertEqual(paragraphs(result)[0], "First paragraph.")
    }

    func testUnknownIDsAreIgnored() throws {
        let stray = ["lesson_99_9.title": "Fremd", "content_0_0_0_0": "Fremd", "screen_14_1_1": "Fremd"]
        let result = LessonOverlay.apply(stray, to: lessons)
        XCTAssertEqual(try encoded(result), try encoded(lessons))
        XCTAssertEqual(result.map(\.displayTitle), lessons.map(\.title))
    }

    // MARK: - Loading an overlay file

    private func bundle(containing files: [String: String]) throws -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lesson-overlay-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (name, contents) in files {
            try Data(contents.utf8).write(to: root.appendingPathComponent(name))
        }
        temporaryRoot = root
        return try XCTUnwrap(Bundle(url: root))
    }

    func testOverlayFileNameIsPerCourseAndLanguage() {
        XCTAssertEqual(LessonOverlay.resourceName(courseId: "course_14", language: "de"), "lesson_overlay_course_14_de")
        XCTAssertEqual(LessonOverlay.resourceName(courseId: "course_1", language: "pt-br"), "lesson_overlay_course_1_pt-br")
    }

    func testAnOverlayFileIsLoadedAndApplied() throws {
        let bundle = try bundle(containing: [
            "lesson_overlay_course_14_de.json": #"{"lesson_14_1.title":"Erst anpassen, dann führen","content_14_1_1_1":"Erster Absatz."}"#
        ])
        let overlay = try XCTUnwrap(LessonOverlay.load(courseId: "course_14", language: "de", bundle: bundle))
        let result = LessonOverlay.apply(overlay, to: lessons)
        XCTAssertEqual(result[0].displayTitle, "Erst anpassen, dann führen")
        XCTAssertEqual(paragraphs(result)[0], "Erster Absatz.")
    }

    func testNoFileForTheCourseOrLanguageMeansNoOverlay() throws {
        let bundle = try bundle(containing: ["lesson_overlay_course_14_de.json": "{}"])
        XCTAssertNil(LessonOverlay.load(courseId: "course_15", language: "de", bundle: bundle))
        XCTAssertNil(LessonOverlay.load(courseId: "course_14", language: "sv", bundle: bundle))
    }

    func testAnUnreadableFileMeansNoOverlay() throws {
        let bundle = try bundle(containing: ["lesson_overlay_course_14_de.json": "not json"])
        XCTAssertNil(LessonOverlay.load(courseId: "course_14", language: "de", bundle: bundle))
    }

    // MARK: - The app's own lessons

    /// Overlay files ship only for the languages the app ships (German from
    /// Release B), and every bundled German file actually loads.
    func testTheAppBundleShipsOverlaysOnlyForShippedLanguages() {
        for index in 1...25 {
            for language in ["sv", "fr", "es", "nl"] {
                XCTAssertNil(LessonOverlay.load(courseId: "course_\(index)", language: language))
            }
        }
        let germanFiles = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("lesson_overlay_") && $0.hasSuffix("_de.json") }
        XCTAssertFalse(germanFiles.isEmpty, "No German lesson overlay is bundled")
        for file in germanFiles {
            let courseId = String(file.dropFirst("lesson_overlay_".count).dropLast("_de.json".count))
            XCTAssertNotNil(LessonOverlay.load(courseId: courseId, language: "de"), "\(file) does not load")
        }
    }

    /// Overlay keys are IDs, so every lesson and paragraph ID across the 25
    /// bundled courses has to be unique. Also: in English the real lessons
    /// show their English text.
    func testBundledLessonIDsAreUniqueAndEnglishIsShown() {
        XCTAssertNil(L10n.contentLanguage)
        var seen = Set<String>()
        var lessonCount = 0
        for index in 1...25 {
            let lessons = LessonDataService.shared.loadLessonsForCourse(courseId: "course_\(index)")
            XCTAssertFalse(lessons.isEmpty, "course_\(index)")
            for lesson in lessons {
                lessonCount += 1
                XCTAssertTrue(seen.insert(lesson.id).inserted, lesson.id)
                XCTAssertEqual(lesson.displayTitle, lesson.title)
                XCTAssertEqual(lesson.displaySummary, lesson.summary)
                XCTAssertNil(lesson.translatedTitle)
                for paragraph in lesson.screens.flatMap(\.content) {
                    XCTAssertTrue(seen.insert(paragraph.id).inserted, paragraph.id)
                }
            }
        }
        XCTAssertEqual(lessonCount, 94)
    }
}
