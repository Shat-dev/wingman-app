//
//  L10nContentTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, first slice: the lookup layer.
//
//  The app ships no translation yet, so these tests build one at runtime — a
//  throwaway bundle with a German `Content` table — and point `L10n` at it.
//  That is what lets Release A prove, before any language exists, that:
//
//    - display text changes with the translation;
//    - a missing or empty translation shows the English text, never a key or
//      a blank;
//    - nothing that is stored, compared or sent to analytics changes at all.
//

import XCTest
@testable import Wingman

@MainActor
final class L10nContentTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    /// Points `L10n` at a bundle whose `Content` table holds `translations`.
    private func useTranslations(_ translations: [String: String], table: String = L10n.contentTable) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("l10n-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: translations, format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(table).strings"))
        temporaryRoot = root

        let bundle = try XCTUnwrap(Bundle(url: lproj), "Could not open the fake translation bundle")
        L10n.sourceOverrideForTesting = .bundle(bundle)
    }

    private let german: [String: String] = [
        "Fear of social consequences": "Angst vor sozialen Folgen",
        "Fear of rejection or being embarrassed": "Angst vor Ablehnung oder Peinlichkeit",
        "Not knowing what to say or how to start": "Nicht wissen, was ich sagen soll",
        "Learning how to approach": "Lernen, wie man jemanden anspricht",
        "Other": "Sonstiges",
        "25-34": "25–34",
        "Worrying about coming across wrong": ""          // an empty translation
    ]

    // MARK: - Source language

    func testAppRunsInItsSourceLanguage() {
        guard case .sourceLanguage = L10n.source else {
            return XCTFail("The app ships English only and must take the pass-through path")
        }
    }

    func testEnglishInEnglishOut() {
        XCTAssertEqual(L10n.content("Fear of social consequences"), "Fear of social consequences")
        XCTAssertEqual(L10n.content("Anything at all, even text no table has"), "Anything at all, even text no table has")
        XCTAssertEqual(L10n.content(""), "")
    }

    // MARK: - Translated

    func testTranslatedTextIsReturned() throws {
        try useTranslations(german)
        XCTAssertEqual(L10n.content("Fear of social consequences"), "Angst vor sozialen Folgen")
        XCTAssertEqual(L10n.content("Other"), "Sonstiges")
    }

    func testMissingTranslationFallsBackToEnglish() throws {
        try useTranslations(german)
        XCTAssertEqual(L10n.content("Better mindset & confidence"), "Better mindset & confidence")
    }

    func testEmptyTranslationFallsBackToEnglish() throws {
        try useTranslations(german)
        XCTAssertEqual(L10n.content("Worrying about coming across wrong"), "Worrying about coming across wrong")
    }

    func testMissingTableFallsBackToEnglish() throws {
        // The bundle has a table, but not the one `content` reads.
        try useTranslations(german, table: "SomethingElse")
        XCTAssertEqual(L10n.content("Fear of social consequences"), "Fear of social consequences")
    }

    func testEmptyInputStaysEmpty() throws {
        try useTranslations(german)
        XCTAssertEqual(L10n.content(""), "")
    }

    // MARK: - Onboarding: labels move, data does not

    func testOptionLabelsAreTranslated() throws {
        try useTranslations(german)
        XCTAssertEqual(BarrierOption.socialConsequences.label, "Angst vor sozialen Folgen")
        // Keyed by the English label, which for this option is the corrected
        // spelling, not the stored value.
        XCTAssertEqual(BarrierOption.fearOfRejection.label, "Angst vor Ablehnung oder Peinlichkeit")
        XCTAssertEqual(GoalOption.howToApproach.label, "Lernen, wie man jemanden anspricht")
        // No translation and an empty one: English.
        XCTAssertEqual(GoalOption.attraction.label, "Creating attraction and romantic interest")
        XCTAssertEqual(BarrierOption.comingAcrossWrong.label, "Worrying about coming across wrong")
    }

    func testCanonicalValuesIgnoreTranslations() throws {
        let before = (
            barriers: BarrierOption.allCases.map(\.canonicalValue),
            goals: GoalOption.allCases.map(\.canonicalValue),
            ages: AgeOption.allCases.map(\.canonicalValue)
        )
        try useTranslations(german)
        XCTAssertEqual(BarrierOption.allCases.map(\.canonicalValue), before.barriers)
        XCTAssertEqual(GoalOption.allCases.map(\.canonicalValue), before.goals)
        // Even where a translation exists for the very same text ("25-34").
        XCTAssertEqual(AgeOption.allCases.map(\.canonicalValue), before.ages)
        XCTAssertEqual(AgeOption.age25to34.label, "25–34")
        XCTAssertEqual(AgeOption.age25to34.canonicalValue, "25-34")
    }

    /// The whole chain in a translated app: the user taps German labels, and
    /// what is stored, restored and personalised is exactly what an English
    /// user's answers produce.
    func testStoredAnswerAndPersonalisationAreTheSameInATranslatedApp() throws {
        let ids = [BarrierOption.whatToSay.rawValue, BarrierOption.fearOfRejection.rawValue, BarrierOption.other.rawValue]
        let englishStored = OnboardingAnswerCoding.storedValue(forSelectedIDs: ids, in: BarrierOption.options)

        try useTranslations(german)
        let germanOptions = BarrierOption.options
        XCTAssertEqual(germanOptions.first { $0.id == BarrierOption.whatToSay.rawValue }?.label, "Nicht wissen, was ich sagen soll")

        let germanStored = OnboardingAnswerCoding.storedValue(forSelectedIDs: ids, in: germanOptions)
        XCTAssertEqual(germanStored, englishStored)
        XCTAssertEqual(
            germanStored,
            "Not knowing what to say or how to start, Fear of rejection or being embarrased, Other"
        )
        XCTAssertEqual(
            OnboardingAnswerCoding.selectedIDs(fromStoredValue: germanStored, in: germanOptions, isMultiSelect: true),
            ids
        )

        let firstPick = OnboardingAnswerCoding.firstPick(ofStoredValue: germanStored)
        XCTAssertEqual(BarrierOption(storedValue: firstPick), .whatToSay)
        XCTAssertEqual(PaywallCopy.barrierLine(firstPick), "Know exactly how to start talking")
        XCTAssertEqual(MarketingNotifications.barrierLine(firstPick), "What if your opener didn\u{2019}t need to be clever?")
    }

    /// A German label is not a stored value: it must not resolve to an option.
    func testTranslatedLabelsAreNotAcceptedAsStoredValues() throws {
        try useTranslations(german)
        XCTAssertNil(BarrierOption(storedValue: "Angst vor sozialen Folgen"))
        XCTAssertEqual(PaywallCopy.barrierLine("Angst vor sozialen Folgen"), "Stop talking yourself out of it")
    }

    // MARK: - Analytics values ignore translations

    func testAnalyticsValuesIgnoreTranslations() throws {
        let lesson = try XCTUnwrap(
            LessonDataService.shared.loadLessonsForCourse(courseId: "course_1").first { $0.id == "lesson_1_1" }
        )
        let course = try XCTUnwrap(CourseCategory.dummyCategories.flatMap(\.courses).first { $0.id == "course_1" })
        let level = try XCTUnwrap(LogApproachViewModel().levels.first { $0.number == 4 })

        try useTranslations([
            "You are not your thoughts": "Du bist nicht deine Gedanken",
            "Beliefs & Reframes": "Überzeugungen & Umdeutungen",
            "Direct Approach": "Direkte Ansprache",
            "I am becoming a guy who takes action.": "Ich werde zu jemandem, der handelt.",
            "Mindset & Foundations": "Denkweise & Grundlagen"
        ])

        XCTAssertEqual(lesson.analyticsProperties["lesson_name"] as? String, "You are not your thoughts")
        XCTAssertEqual(lesson.analyticsProperties["category"] as? String, "Beliefs & Reframes")
        XCTAssertEqual(
            CourseAnalytics.lessonGateBlocked(lesson: lesson, course: course)["course_title"] as? String,
            "Beliefs & Reframes"
        )
        XCTAssertEqual(level.canonicalTitle, "Direct Approach")
        XCTAssertEqual(CommitmentPactCopy.analyticsHeadline, "I am becoming a guy who takes action.")
        XCTAssertEqual(CourseCategory.dummyCategories.first?.canonicalName, "Mindset & Foundations")
        XCTAssertEqual(Analytics.Screen.all.count, 17)
    }
}
