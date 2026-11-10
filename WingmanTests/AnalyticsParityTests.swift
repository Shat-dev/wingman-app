//
//  AnalyticsParityTests.swift
//  WingmanTests
//
//  Section 9 of the localization plan: the names and values the app sends to
//  analytics must be the same in every language.
//
//  `Analytics.recorderForTesting` receives every event instead of it being
//  sent. A scripted run is recorded once in English and once as a translated
//  app showing German content, and the two recordings must be identical.
//
//  What the script covers: everything that can be driven without a screen, a
//  network or a purchase — the walkthrough, and each event whose values are
//  built from content that gets translated (onboarding answers, lessons,
//  courses, scenarios, the commitment pact). It builds those values with the
//  same functions the screens use.
//
//  What it does not cover: the plan's full run through the real screens with
//  a sandbox purchase, and a comparison against build 37. Both need things a
//  unit test cannot do.
//

import XCTest
@testable import Wingman

@MainActor
final class AnalyticsParityTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        Analytics.recorderForTesting = nil
        L10n.sourceOverrideForTesting = nil
        L10n.contentLanguageOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    // MARK: - Recording

    /// Every call recorded while `work` runs, as comparable lines:
    /// "event walkthrough_step_viewed {step=welcome}".
    private func record(dropping volatile: Set<String> = ["duration_seconds"], _ work: () throws -> Void) rethrows -> [String] {
        var calls: [Analytics.RecordedCall] = []
        Analytics.recorderForTesting = { calls.append($0) }
        defer { Analytics.recorderForTesting = nil }
        try work()
        return calls.map { call in
            let properties = (call.properties ?? [:])
                .filter { !volatile.contains($0.key) }
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            return "\(call.kind.rawValue) \(call.name) {\(properties)}"
        }
    }

    // MARK: - A translated app

    /// A German table for the `Content` catalog, so option labels, course
    /// titles and anything else shown through `L10n.content` really are
    /// different from the English.
    private func becomeATranslatedApp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("parity-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let table: [String: String] = [
            "Want more confidence in general": "Mehr Selbstvertrauen",
            "Sometimes": "Manchmal",
            "Not knowing what to say or how to start": "Nicht wissen, was ich sagen soll",
            "Learning how to approach": "Lernen, wie ich jemanden anspreche",
            "Beliefs & Reframes": "Überzeugungen neu denken",
            "Fear & Exposure": "Angst und Konfrontation"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: table, format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
        L10n.contentLanguageOverrideForTesting = .init(value: "de")
    }

    // MARK: - The script

    private let scenarioID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    /// One pass through the events. `translated` lays German content over
    /// the English, as a German app with translations would.
    private func runScript(translated: Bool) throws {
        // Walkthrough: start, the four tab cards, a nudge, the sign-off.
        let walkthrough = WalkthroughCoordinator()
        walkthrough.start(hasCompletedFreeDemo: false, hasActiveSubscription: false, isNewSubscriber: false)
        walkthrough.showNudge(.lesson)
        walkthrough.dismissNudge()
        for _ in 0..<4 {
            walkthrough.advance()
            walkthrough.tabApplied()
        }
        walkthrough.advance()

        // Onboarding answers: what is stored and sent for a tapped option.
        for (options, pick) in [
            (MotivationOption.options, 4), (ApproachFrequencyOption.options, 2),
            (BarrierOption.options, 0), (GoalOption.options, 1)
        ] {
            let chosen = options[pick]
            Analytics.capture("onboarding_question_answered", [
                "answer": OnboardingAnswerCoding.storedValue(forSelectedIDs: [chosen.id], in: options),
                "shown_label_differs_from_value": false
            ])
        }

        // A lesson and its course, with German lesson text laid over.
        var lessons = LessonDataService.shared.loadLessonsForCourse(courseId: "course_1")
        if translated {
            let first = try XCTUnwrap(lessons.first)
            lessons = LessonOverlay.apply([
                LessonOverlay.titleKey(lessonId: first.id): "Ein deutscher Titel",
                LessonOverlay.summaryKey(lessonId: first.id): "Eine deutsche Zusammenfassung"
            ], to: lessons)
        }
        let lesson = try XCTUnwrap(lessons.first)
        XCTAssertEqual(lesson.displayTitle == lesson.title, !translated, "the script must really show German when translated")
        Analytics.capture(Analytics.Event.lessonStarted, lesson.analyticsProperties)
        Analytics.capture(Analytics.Event.lessonCompleted, lesson.analyticsProperties)

        // A scenario with a German display title and German screen text.
        var practices = [
            Practice(
                id: scenarioID, title: "Bar Window", summary: "Loud music.", coverImageUrl: nil,
                requiredLessonsCompleted: 0, womanName: "Amber", orderIndex: 1, isPublished: true,
                createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
            )
        ]
        var scenes = [
            GameScene(
                id: scenarioID.uuidString.lowercased(), type: .context, characterName: nil,
                text: "You walk in.", imageName: nil, options: nil, order: 1,
                defaultNextScreenId: nil, retryTargetScreenId: nil
            )
        ]
        if translated {
            practices = ContentOverlay.apply(
                [ScenarioTranslation(scenarioId: scenarioID, title: "Am Bartresen", summary: "Laute Musik.")], to: practices
            )
            scenes = ContentOverlay.apply(
                screens: [ScreenTranslation(screenId: scenarioID, text: "Du kommst rein.")], options: [], to: scenes
            )
        }
        XCTAssertEqual(practices[0].displayTitle == "Bar Window", !translated)
        let game = PracticeGameData(id: scenarioID.uuidString, title: practices[0].title, scenes: scenes)
        Analytics.capture("practice_scenario_started", game.analyticsProperties(duringWalkthrough: true))
        Analytics.capture("practice_scenario_completed", game.analyticsProperties(duringWalkthrough: false))

        // The commitment pact.
        Analytics.capture("commitment_pact_committed", ["headline": CommitmentPactCopy.analyticsHeadline])

        // Events sent straight to the SDK (sign-in, paywall) are recorded too.
        Analytics.captureNow("paywall_viewed", properties: ["source": "onboarding"])
        Analytics.screen(Analytics.Screen.paywall)
    }

    // MARK: - Parity

    func testATranslatedAppSendsExactlyWhatEnglishSends() throws {
        let english = try record { try runScript(translated: false) }

        try becomeATranslatedApp()
        XCTAssertFalse(L10n.isSourceLanguage)
        XCTAssertEqual(L10n.content("Sometimes"), "Manchmal", "the translated run must really be translated")
        let german = try record { try runScript(translated: true) }

        // 8 walkthrough, 4 answers, 2 lesson, 2 scenario, 1 pact, 2 direct.
        XCTAssertEqual(english.count, 19)
        XCTAssertEqual(german.count, english.count)
        for (index, pair) in zip(english, german).enumerated() {
            XCTAssertEqual(pair.1, pair.0, "call \(index)")
        }
    }

    /// The recording itself, pinned, so a change to any of these values is
    /// noticed even when English and German change together.
    func testTheEnglishRecording() throws {
        let english = try record { try runScript(translated: false) }
        let lesson = try XCTUnwrap(LessonDataService.shared.loadLessonsForCourse(courseId: "course_1").first)

        XCTAssertEqual(Array(english.prefix(8)), [
            "event walkthrough_started {}",
            "event walkthrough_step_viewed {step=welcome}",
            "event walkthrough_nudge_shown {step=welcome, surface=lesson}",
            "event walkthrough_step_viewed {step=coursesTour}",
            "event walkthrough_step_viewed {step=scenarioTour}",
            "event walkthrough_step_viewed {step=progressTour}",
            "event walkthrough_step_viewed {step=signOff}",
            "event walkthrough_completed {}"
        ])
        XCTAssertTrue(english.contains("event onboarding_question_answered {answer=Want more confidence in general, shown_label_differs_from_value=false}"))
        XCTAssertTrue(english.contains("event onboarding_question_answered {answer=Fear of rejection or being embarrased, shown_label_differs_from_value=false}"))
        XCTAssertTrue(english.contains { $0.hasPrefix("event lesson_started {") && $0.contains("lesson_name=\(lesson.title)") })
        XCTAssertTrue(english.contains("event practice_scenario_started {during_walkthrough=true, scenario_id=\(scenarioID.uuidString), scenario_name=Bar Window}"))
        XCTAssertTrue(english.contains("event commitment_pact_committed {headline=I am becoming a guy who takes action.}"))
        XCTAssertEqual(Array(english.suffix(2)), ["event paywall_viewed {source=onboarding}", "screen Paywall {}"])
    }

    // MARK: - The recorder

    func testNothingIsRecordedOnceTheRecorderIsRemoved() {
        var count = 0
        Analytics.recorderForTesting = { _ in count += 1 }
        Analytics.capture("one")
        Analytics.captureNow("two")
        Analytics.screen("three")
        XCTAssertEqual(count, 3)

        Analytics.recorderForTesting = nil
        XCTAssertNil(Analytics.recorderForTesting, "the app never has a recorder")
    }

    func testVolatileValuesAreLeftOutOfTheComparison() {
        let lines = record {
            Analytics.capture("walkthrough_completed", ["duration_seconds": 12.5, "step": "signOff"])
        }
        XCTAssertEqual(lines, ["event walkthrough_completed {step=signOff}"])
    }
}
