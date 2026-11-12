//
//  GermanReleaseChecksTests.swift
//  WingmanTests
//
//  The two checks the German launch checklist asks for before submitting
//  (docs/german-launch-checklist.md, step 7, items 5 and 6), run against the
//  German that actually ships rather than small made-up tables:
//
//    - Fallback: take the real German, remove a sample of strings and rows,
//      and confirm English appears in their place. Nothing blank, no keys.
//    - Analytics parity: with the real German showing, every value sent to
//      analytics is identical to the English run, for every lesson, course,
//      category, onboarding answer and scenario.
//
//  Sources: the app's de.lproj (Localizable and Content), the 25 lesson
//  overlays, the bundled quiz-question translations, and, for scenarios,
//  localization/de/db/scenario_*.json in the repository: the same files the
//  live database rows were generated from.
//

import XCTest
@testable import Wingman

@MainActor
final class GermanReleaseChecksTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        L10n.contentLanguageOverrideForTesting = nil
        if let temporaryRoot { try? FileManager.default.removeItem(at: temporaryRoot) }
        temporaryRoot = nil
        super.tearDown()
    }

    // MARK: - The shipped German

    private func shippedGermanBundle() throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "de", ofType: "lproj"), "the app ships no de.lproj")
        return try XCTUnwrap(Bundle(path: path))
    }

    private func shippedTable(_ name: String) throws -> [String: String] {
        let url = try shippedGermanBundle().url(forResource: name, withExtension: "strings")
        let dictionary = try XCTUnwrap(NSDictionary(contentsOf: try XCTUnwrap(url, "\(name).strings")) as? [String: String])
        XCTAssertGreaterThan(dictionary.count, 100, "\(name) looks empty")
        return dictionary
    }

    /// Run as the shipped German app: content lookups go to the real de.lproj.
    private func becomeTheShippedGermanApp() throws {
        L10n.sourceOverrideForTesting = .bundle(try shippedGermanBundle())
        L10n.contentLanguageOverrideForTesting = .init(value: "de")
    }

    /// Run as a German app whose tables lack `removed`: a de.lproj in a
    /// temporary folder holding the real tables minus those keys.
    private func becomeAGermanAppMissing(_ removed: [String: Set<String>]) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fallback-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        for table in ["Localizable", "Content"] {
            let kept = try shippedTable(table).filter { !(removed[table] ?? []).contains($0.key) }
            let data = try PropertyListSerialization.data(fromPropertyList: kept, format: .binary, options: 0)
            try data.write(to: lproj.appendingPathComponent("\(table).strings"))
        }
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
        L10n.contentLanguageOverrideForTesting = .init(value: "de")
    }

    /// Every `n`th item, in a stable order: a fixed, spread-out sample.
    private func sample<T: Comparable>(_ items: some Collection<T>, every n: Int) -> Set<T> {
        Set(items.sorted().enumerated().filter { $0.offset % n == 0 }.map(\.element))
    }

    private var categories: [CourseCategory] { CourseCategory.dummyCategories }
    private var courses: [Course] { categories.flatMap(\.courses) }

    private func englishLessons() -> [Lesson] {
        courses.flatMap { LessonDataService.shared.loadLessonsForCourse(courseId: $0.id) }
    }

    private func germanLessons(dropping drop: (String) -> Bool = { _ in false }) throws -> [Lesson] {
        try courses.flatMap { course -> [Lesson] in
            let english = LessonDataService.shared.loadLessonsForCourse(courseId: course.id)
            guard !english.isEmpty else { return [] }
            let overlay = try XCTUnwrap(LessonOverlay.load(courseId: course.id, language: "de"), "no German for \(course.id)")
            return LessonOverlay.apply(overlay.filter { !drop($0.key) }, to: english)
        }
    }

    // MARK: - Scenario rows from the repository

    private struct ScenarioFile {
        let scenarioID: UUID
        let title: (en: String, de: String)
        let summary: (en: String, de: String)
        let screens: [String: (en: String, de: String)]
        let options: [String: (en: String, de: String)]
    }

    private func scenarioFiles() throws -> [ScenarioFile] {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = repo.appendingPathComponent("localization/de/db")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix("scenario_") && $0.hasSuffix(".json") }.sorted()
        XCTAssertEqual(names.count, 15)

        func pair(_ any: Any?) -> (en: String, de: String) {
            let d = any as? [String: String] ?? [:]
            return (d["en"] ?? "", d["de"] ?? "")
        }
        return try names.map { name in
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent(name))) as? [String: Any])
            let scenario = try XCTUnwrap((json["scenario"] as? [String: Any])?.first)
            let fields = scenario.value as? [String: Any] ?? [:]
            return ScenarioFile(
                scenarioID: try XCTUnwrap(UUID(uuidString: scenario.key)),
                title: pair(fields["title"]),
                summary: pair(fields["summary"]),
                screens: (json["screens"] as? [String: Any] ?? [:]).mapValues(pair),
                options: (json["options"] as? [String: Any] ?? [:]).mapValues(pair)
            )
        }
    }

    /// English scenes for a scenario: one screen per text row, the options
    /// on the first screen. Only text and IDs matter to the overlay.
    private func englishScenes(_ file: ScenarioFile) -> [GameScene] {
        let options = file.options.sorted { $0.key < $1.key }.enumerated().map { index, option in
            GameOption(id: option.key, text: option.value.en, nextSceneId: nil, isCorrect: index == 0, orderIndex: index)
        }
        return file.screens.sorted { $0.key < $1.key }.enumerated().map { index, screen in
            GameScene(
                id: screen.key, type: index == 0 ? .options : .context, characterName: nil,
                text: screen.value.en, imageName: nil, options: index == 0 ? options : nil, order: index,
                defaultNextScreenId: nil, retryTargetScreenId: nil
            )
        }
    }

    // MARK: - Fallback: catalogs

    func testRemovedInterfaceAndContentStringsShowEnglish() throws {
        let localizable = try shippedTable("Localizable")
        let content = try shippedTable("Content")
        let removedLocalizable = sample(localizable.keys, every: 6)
        let removedContent = sample(content.keys, every: 6)
        try becomeAGermanAppMissing(["Localizable": removedLocalizable, "Content": removedContent])
        guard case .bundle(let bundle) = L10n.source else { return XCTFail("not running as a translated app") }

        for key in removedLocalizable {
            XCTAssertEqual(bundle.localizedString(forKey: key, value: nil, table: "Localizable"), key, "removed: \(key)")
        }
        for key in removedContent {
            XCTAssertEqual(L10n.content(key), key, "removed: \(key)")
        }
        // The rest is still German, and nothing that remains is blank.
        for (key, german) in content where !removedContent.contains(key) {
            XCTAssertEqual(L10n.content(key), german)
            XCTAssertFalse(german.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
        }
        for (key, german) in localizable where !removedLocalizable.contains(key) {
            XCTAssertFalse(german.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
        }
        XCTAssertGreaterThan(removedLocalizable.count + removedContent.count, 80)
    }

    func testRemovedCategoryAndCourseNamesShowEnglish() throws {
        let names = categories.map(\.name) + courses.map(\.title)
        let removed = sample(names, every: 3)
        try becomeAGermanAppMissing(["Content": removed])

        for category in categories {
            XCTAssertEqual(category.displayName == category.name, removed.contains(category.name), category.name)
        }
        for course in courses {
            XCTAssertEqual(course.displayTitle == course.title, removed.contains(course.title), course.title)
        }
    }

    // MARK: - Fallback: lessons

    func testRemovedLessonTextShowsEnglish() throws {
        var removedKeys = Set<String>()
        let lessons = try germanLessons { key in
            // Every 5th key by a stable hash of its name.
            let drop = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % 5 == 0
            if drop { removedKeys.insert(key) }
            return drop
        }
        let english = Dictionary(uniqueKeysWithValues: englishLessons().map { ($0.id, $0) })
        XCTAssertGreaterThan(removedKeys.count, 200)

        var englishShown = 0, germanShown = 0
        for lesson in lessons {
            let source = try XCTUnwrap(english[lesson.id])
            let titleRemoved = removedKeys.contains(LessonOverlay.titleKey(lessonId: lesson.id))
            XCTAssertEqual(lesson.displayTitle == source.title, titleRemoved, lesson.id)
            XCTAssertFalse(lesson.displayTitle.isEmpty)
            XCTAssertFalse(lesson.displaySummary.isEmpty)

            for (screen, sourceScreen) in zip(lesson.screens, source.screens) {
                for (paragraph, sourceParagraph) in zip(screen.content, sourceScreen.content) {
                    XCTAssertFalse(paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, paragraph.id)
                    if removedKeys.contains(paragraph.id) {
                        XCTAssertEqual(paragraph.text, sourceParagraph.text, "removed: \(paragraph.id)")
                        englishShown += 1
                    } else if paragraph.text != sourceParagraph.text {
                        germanShown += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(englishShown, 200)
        XCTAssertGreaterThan(germanShown, englishShown, "most paragraphs must still be German")
    }

    // MARK: - Fallback: quiz questions

    func testRemovedQuizTranslationsShowEnglish() throws {
        let rows = QuestionTranslationSeed.load(language: "de")
        XCTAssertEqual(rows.count, 765)
        let removed = sample(rows.map(\.questionId.uuidString), every: 7)
        let kept = rows.filter { !removed.contains($0.questionId.uuidString) }

        let english = englishLessons().flatMap { LessonQuestionStore.shared.questions(forLessonId: $0.id) }
        XCTAssertGreaterThan(english.count, 200)
        let shown = ContentOverlay.apply(kept, to: english)

        let germanIDs = Set(kept.map(\.questionId))
        var fellBack = 0
        for (question, source) in zip(shown, english) {
            XCTAssertEqual(question.id, source.id)
            XCTAssertFalse(question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertEqual(question.options.count, source.options.count, "options never change shape")
            XCTAssertTrue(question.options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            XCTAssertEqual(question.correctAnswerIndex, source.correctAnswerIndex, "scoring never changes")
            if germanIDs.contains(source.id) {
                XCTAssertNotEqual(question.question, source.question, "German expected: \(source.id)")
            } else {
                XCTAssertEqual(question.question, source.question, "English expected: \(source.id)")
                XCTAssertEqual(question.options, source.options)
                fellBack += 1
            }
        }
        XCTAssertGreaterThan(fellBack, 10, "the sample must hit lesson questions")
    }

    // MARK: - Fallback: scenarios

    func testRemovedScenarioRowsShowEnglish() throws {
        var checked = 0
        for file in try scenarioFiles() {
            let scenes = englishScenes(file)
            let removedScreens = sample(file.screens.keys, every: 4)
            let removedOptions = sample(file.options.keys, every: 3)
            let shown = ContentOverlay.apply(
                screens: file.screens.filter { !removedScreens.contains($0.key) }.compactMap { id, text in
                    UUID(uuidString: id).map { ScreenTranslation(screenId: $0, text: text.de) }
                },
                options: file.options.filter { !removedOptions.contains($0.key) }.compactMap { id, text in
                    UUID(uuidString: id).map { OptionTranslation(optionId: $0, text: text.de) }
                },
                to: scenes
            )
            for (scene, source) in zip(shown, scenes) {
                XCTAssertFalse(scene.text.isEmpty)
                XCTAssertEqual(scene.text, removedScreens.contains(source.id) ? source.text : file.screens[source.id]?.de)
                for (option, sourceOption) in zip(scene.options ?? [], source.options ?? []) {
                    XCTAssertEqual(option.text, removedOptions.contains(sourceOption.id) ? sourceOption.text : file.options[sourceOption.id]?.de)
                    XCTAssertEqual(option.isCorrect, sourceOption.isCorrect)
                    checked += 1
                }
            }

            // A scenario whose title row is missing keeps its English title.
            let practice = Practice(
                id: file.scenarioID, title: file.title.en, summary: file.summary.en, coverImageUrl: nil,
                requiredLessonsCompleted: 0, womanName: nil, orderIndex: 1, isPublished: true,
                createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
            )
            XCTAssertEqual(ContentOverlay.apply([], to: [practice])[0].displayTitle, file.title.en)
        }
        XCTAssertGreaterThan(checked, 200)
    }

    // MARK: - Parity: what analytics receives

    private func comparable(_ properties: [String: Any]) -> String {
        properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }

    /// Lesson, course and category values for every lesson in the app.
    private func lessonAndCourseValues(_ lessons: [Lesson]) throws -> [String] {
        let byCourse = Dictionary(grouping: lessons, by: \.courseId)
        var values: [String] = []
        for (index, course) in courses.enumerated() {
            for lesson in byCourse[course.id] ?? [] {
                values.append("lesson " + comparable(lesson.analyticsProperties))
                values.append("gate " + comparable(CourseAnalytics.lessonGateBlocked(lesson: lesson, course: course)))
            }
            let previous = index > 0 ? courses[index - 1] : nil
            values.append("locked " + comparable(CourseAnalytics.courseLockedEncountered(
                course: course, previousCourseID: previous?.id,
                previousCourseCanonicalTitle: previous?.canonicalTitle ?? CourseAnalytics.unknownPreviousCourseTitle
            )))
        }
        values += categories.map { "category \($0.id)=\($0.canonicalName)" }
        return values
    }

    func testTheShippedGermanSendsTheSameLessonCourseAndCategoryValues() throws {
        let englishRun = try lessonAndCourseValues(englishLessons())

        try becomeTheShippedGermanApp()
        let lessons = try germanLessons()
        // The German run must really be showing German.
        XCTAssertGreaterThan(lessons.filter { $0.displayTitle != $0.title }.count, lessons.count * 9 / 10)
        XCTAssertTrue(categories.allSatisfy { $0.displayName != $0.name }, "every category shows German")
        XCTAssertGreaterThan(courses.filter { $0.displayTitle != $0.title }.count, courses.count * 9 / 10)

        let germanRun = try lessonAndCourseValues(lessons)
        XCTAssertGreaterThan(englishRun.count, 150)
        XCTAssertEqual(germanRun.count, englishRun.count)
        for (german, english) in zip(germanRun, englishRun) {
            XCTAssertEqual(german, english)
        }
    }

    private func onboardingValues() -> [String] {
        func values<Kind: OnboardingOptionKind>(_ kind: Kind.Type) -> [String] {
            let options = Kind.allCases.map(\.option)
            return options.map { "\(Kind.questionKey): " + OnboardingAnswerCoding.storedValue(forSelectedIDs: [$0.id], in: options) }
                + ["\(Kind.questionKey) all: " + OnboardingAnswerCoding.storedValue(forSelectedIDs: options.map(\.id), in: options)]
        }
        return values(MotivationOption.self) + values(AgeOption.self) + values(LastApproachOption.self)
            + values(ApproachFrequencyOption.self) + values(BarrierOption.self) + values(GoalOption.self)
    }

    func testTheShippedGermanStoresAndSendsTheSameOnboardingAnswers() throws {
        let englishRun = onboardingValues()
        let englishLabels = MotivationOption.allCases.map(\.label)

        try becomeTheShippedGermanApp()
        XCTAssertNotEqual(MotivationOption.allCases.map(\.label), englishLabels, "the German run must show German labels")
        XCTAssertEqual(onboardingValues(), englishRun)
    }

    func testTheShippedGermanSendsTheSameScenarioValues() throws {
        for file in try scenarioFiles() {
            let english = PracticeGameData(id: file.scenarioID.uuidString, title: file.title.en, scenes: englishScenes(file))
            let practice = ContentOverlay.apply(
                [ScenarioTranslation(scenarioId: file.scenarioID, title: file.title.de, summary: file.summary.de)],
                to: [Practice(
                    id: file.scenarioID, title: file.title.en, summary: file.summary.en, coverImageUrl: nil,
                    requiredLessonsCompleted: 0, womanName: nil, orderIndex: 1, isPublished: true,
                    createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
                )]
            )[0]
            XCTAssertEqual(practice.displayTitle, file.title.de)
            // What the game is built with: the English title, German screens.
            let german = PracticeGameData(
                id: file.scenarioID.uuidString, title: practice.title,
                scenes: ContentOverlay.apply(
                    screens: file.screens.compactMap { id, text in UUID(uuidString: id).map { ScreenTranslation(screenId: $0, text: text.de) } },
                    options: [], to: englishScenes(file)
                )
            )
            for walkthrough in [true, false] {
                XCTAssertEqual(comparable(german.analyticsProperties(duringWalkthrough: walkthrough)),
                               comparable(english.analyticsProperties(duringWalkthrough: walkthrough)))
            }
        }
    }
}
