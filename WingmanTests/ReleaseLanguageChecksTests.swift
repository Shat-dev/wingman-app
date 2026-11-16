//
//  ReleaseLanguageChecksTests.swift
//  WingmanTests
//
//  The two checks the launch checklists ask for before submitting
//  (docs/german-launch-checklist.md, step 7, items 5 and 6), run against the
//  translations that actually ship rather than small made-up tables, for every
//  shipped language:
//
//    - Fallback: take the real translation, remove a sample of strings and
//      rows, and confirm English appears in their place. Nothing blank, no keys.
//    - Analytics parity: with the real translation showing, every value sent
//      to analytics is identical to the English run, for every lesson, course,
//      category, onboarding answer and scenario.
//
//  Sources, per language: the app's <lang>.lproj (Localizable and Content),
//  the 25 lesson overlays, the bundled quiz-question translations, and, for
//  scenarios, localization/<lang>/db/scenario_*.json in the repository: the
//  same files the live database rows are generated from.
//
//  German (Release B) is complete and required: if any of it is missing, the
//  tests fail. Spanish and French (Release C) and Japanese (Release D) are
//  translated after the tests were written, so
//  a part of a language that is not fully bundled yet (catalogs, all 25
//  lesson overlays, all 765 quiz rows, all 15 scenario files) is skipped with
//  a note in the test log instead of failing.
//

import XCTest
@testable import Wingman

@MainActor
final class ReleaseLanguageChecksTests: XCTestCase {

    /// Every language the app ships translated content for.
    static let shippedLanguages = ["de", "es", "fr", "ja"]
    /// Languages that must be complete. The others are checked once bundled.
    static let requiredLanguages: Set<String> = ["de"]

    static let questionCount = 765
    static let scenarioCount = 15

    private var temporaryRoots: [URL] = []

    override func tearDown() {
        resetToEnglish()
        for root in temporaryRoots { try? FileManager.default.removeItem(at: root) }
        temporaryRoots = []
        super.tearDown()
    }

    private func resetToEnglish() {
        L10n.sourceOverrideForTesting = nil
        L10n.contentLanguageOverrideForTesting = nil
    }

    // MARK: - Which parts of a language are bundled

    private enum Part: String {
        case catalogs = "interface catalogs"
        case lessons = "lesson overlays (all 25 courses)"
        case quiz = "quiz translations (all 765)"
        case scenarios = "scenario files (all 15)"
    }

    /// True when `part` of `language` is complete, so its checks run. A
    /// required language always runs, so a missing piece fails its checks.
    private func isBundled(_ part: Part, _ language: String) -> Bool {
        if Self.requiredLanguages.contains(language) { return true }
        let bundled: Bool
        switch part {
        case .catalogs:
            bundled = bundledTable("Localizable", language) != nil && bundledTable("Content", language) != nil
        case .lessons:
            bundled = courses.allSatisfy { course in
                LessonDataService.shared.loadLessonsForCourse(courseId: course.id).isEmpty
                    || LessonOverlay.load(courseId: course.id, language: language) != nil
            }
        case .quiz:
            bundled = QuestionTranslationSeed.load(language: language).count == Self.questionCount
        case .scenarios:
            bundled = scenarioFileNames(language).count == Self.scenarioCount
        }
        if !bundled {
            print("note: ReleaseLanguageChecks skipped '\(language)' \(part.rawValue): not fully bundled yet")
        }
        return bundled
    }

    /// The languages whose `parts` are all bundled. Always includes German.
    private func languages(with parts: Part...) -> [String] {
        Self.shippedLanguages.filter { language in parts.allSatisfy { isBundled($0, language) } }
    }

    // MARK: - The shipped translation

    private func shippedBundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), "the app ships no \(language).lproj")
        return try XCTUnwrap(Bundle(path: path))
    }

    /// The shipped table, or nil when it is missing or looks empty. Plain
    /// optionals, not XCTUnwrap: `isBundled` probes with this, and XCTUnwrap
    /// records a failure even under `try?`.
    private func bundledTable(_ name: String, _ language: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let url = Bundle(path: path)?.url(forResource: name, withExtension: "strings"),
              let dictionary = NSDictionary(contentsOf: url) as? [String: String],
              dictionary.count > 100 else { return nil }
        return dictionary
    }

    private func shippedTable(_ name: String, _ language: String) throws -> [String: String] {
        try XCTUnwrap(bundledTable(name, language), "\(language) \(name).strings is missing or looks empty")
    }

    /// Run as the shipped app in `language`: content lookups go to the real lproj.
    private func becomeTheShippedApp(_ language: String) throws {
        L10n.sourceOverrideForTesting = .bundle(try shippedBundle(language))
        L10n.contentLanguageOverrideForTesting = .init(value: language)
    }

    /// Run as an app in `language` whose tables lack `removed`: an lproj in a
    /// temporary folder holding the real tables minus those keys.
    private func becomeAnApp(_ language: String, missing removed: [String: Set<String>]) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fallback-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("\(language).lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        for table in ["Localizable", "Content"] {
            let kept = try shippedTable(table, language).filter { !(removed[table] ?? []).contains($0.key) }
            let data = try PropertyListSerialization.data(fromPropertyList: kept, format: .binary, options: 0)
            try data.write(to: lproj.appendingPathComponent("\(table).strings"))
        }
        temporaryRoots.append(root)
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
        L10n.contentLanguageOverrideForTesting = .init(value: language)
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

    private func translatedLessons(_ language: String, dropping drop: (String) -> Bool = { _ in false }) throws -> [Lesson] {
        try courses.flatMap { course -> [Lesson] in
            let english = LessonDataService.shared.loadLessonsForCourse(courseId: course.id)
            guard !english.isEmpty else { return [] }
            let overlay = try XCTUnwrap(LessonOverlay.load(courseId: course.id, language: language), "no \(language) for \(course.id)")
            return LessonOverlay.apply(overlay.filter { !drop($0.key) }, to: english)
        }
    }

    // MARK: - Scenario rows from the repository

    private struct ScenarioFile {
        let scenarioID: UUID
        let title: (en: String, tr: String)
        let summary: (en: String, tr: String)
        let screens: [String: (en: String, tr: String)]
        let options: [String: (en: String, tr: String)]
    }

    private func scenarioFolder(_ language: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("localization/\(language)/db")
    }

    private func scenarioFileNames(_ language: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: scenarioFolder(language).path)) ?? [])
            .filter { $0.hasPrefix("scenario_") && $0.hasSuffix(".json") }.sorted()
    }

    private func scenarioFiles(_ language: String) throws -> [ScenarioFile] {
        let folder = scenarioFolder(language)
        let names = scenarioFileNames(language)
        XCTAssertEqual(names.count, Self.scenarioCount, language)

        func pair(_ any: Any?) -> (en: String, tr: String) {
            let d = any as? [String: String] ?? [:]
            return (d["en"] ?? "", d[language] ?? "")
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
        for language in languages(with: .catalogs) {
            defer { resetToEnglish() }
            let localizable = try shippedTable("Localizable", language)
            let content = try shippedTable("Content", language)
            let removedLocalizable = sample(localizable.keys, every: 6)
            let removedContent = sample(content.keys, every: 6)
            try becomeAnApp(language, missing: ["Localizable": removedLocalizable, "Content": removedContent])
            guard case .bundle(let bundle) = L10n.source else { return XCTFail("not running as a translated app") }

            for key in removedLocalizable {
                XCTAssertEqual(bundle.localizedString(forKey: key, value: nil, table: "Localizable"), key, "\(language) removed: \(key)")
            }
            for key in removedContent {
                XCTAssertEqual(L10n.content(key), key, "\(language) removed: \(key)")
            }
            // The rest is still translated, and nothing that remains is blank.
            for (key, translated) in content where !removedContent.contains(key) {
                XCTAssertEqual(L10n.content(key), translated)
                XCTAssertFalse(translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language) \(key)")
            }
            for (key, translated) in localizable where !removedLocalizable.contains(key) {
                XCTAssertFalse(translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language) \(key)")
            }
            XCTAssertGreaterThan(removedLocalizable.count + removedContent.count, 80, language)
        }
    }

    func testRemovedCategoryAndCourseNamesShowEnglish() throws {
        for language in languages(with: .catalogs) {
            defer { resetToEnglish() }
            let names = categories.map(\.name) + courses.map(\.title)
            let removed = sample(names, every: 3)
            try becomeAnApp(language, missing: ["Content": removed])

            for category in categories {
                XCTAssertEqual(category.displayName == category.name, removed.contains(category.name), "\(language) \(category.name)")
            }
            for course in courses {
                XCTAssertEqual(course.displayTitle == course.title, removed.contains(course.title), "\(language) \(course.title)")
            }
        }
    }

    // MARK: - Fallback: lessons

    func testRemovedLessonTextShowsEnglish() throws {
        for language in languages(with: .lessons) {
            var removedKeys = Set<String>()
            let lessons = try translatedLessons(language) { key in
                // Every 5th key by a stable hash of its name.
                let drop = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % 5 == 0
                if drop { removedKeys.insert(key) }
                return drop
            }
            let english = Dictionary(uniqueKeysWithValues: englishLessons().map { ($0.id, $0) })
            XCTAssertGreaterThan(removedKeys.count, 200, language)

            var englishShown = 0, translatedShown = 0
            for lesson in lessons {
                let source = try XCTUnwrap(english[lesson.id])
                let titleRemoved = removedKeys.contains(LessonOverlay.titleKey(lessonId: lesson.id))
                XCTAssertEqual(lesson.displayTitle == source.title, titleRemoved, "\(language) \(lesson.id)")
                XCTAssertFalse(lesson.displayTitle.isEmpty)
                XCTAssertFalse(lesson.displaySummary.isEmpty)

                for (screen, sourceScreen) in zip(lesson.screens, source.screens) {
                    for (paragraph, sourceParagraph) in zip(screen.content, sourceScreen.content) {
                        XCTAssertFalse(paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, paragraph.id)
                        if removedKeys.contains(paragraph.id) {
                            XCTAssertEqual(paragraph.text, sourceParagraph.text, "\(language) removed: \(paragraph.id)")
                            englishShown += 1
                        } else if paragraph.text != sourceParagraph.text {
                            translatedShown += 1
                        }
                    }
                }
            }
            XCTAssertGreaterThan(englishShown, 200, language)
            XCTAssertGreaterThan(translatedShown, englishShown, "most \(language) paragraphs must still be translated")
        }
    }

    // MARK: - Fallback: quiz questions

    func testRemovedQuizTranslationsShowEnglish() throws {
        for language in languages(with: .quiz) {
            let rows = QuestionTranslationSeed.load(language: language)
            XCTAssertEqual(rows.count, Self.questionCount, language)
            let removed = sample(rows.map(\.questionId.uuidString), every: 7)
            let kept = rows.filter { !removed.contains($0.questionId.uuidString) }

            let english = englishLessons().flatMap { LessonQuestionStore.shared.questions(forLessonId: $0.id) }
            XCTAssertGreaterThan(english.count, 200)
            let shown = ContentOverlay.apply(kept, to: english)

            let translatedIDs = Set(kept.map(\.questionId))
            var fellBack = 0
            for (question, source) in zip(shown, english) {
                XCTAssertEqual(question.id, source.id)
                XCTAssertFalse(question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertEqual(question.options.count, source.options.count, "options never change shape")
                XCTAssertTrue(question.options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                XCTAssertEqual(question.correctAnswerIndex, source.correctAnswerIndex, "scoring never changes")
                if translatedIDs.contains(source.id) {
                    XCTAssertNotEqual(question.question, source.question, "\(language) expected: \(source.id)")
                } else {
                    XCTAssertEqual(question.question, source.question, "English expected: \(source.id)")
                    XCTAssertEqual(question.options, source.options)
                    fellBack += 1
                }
            }
            XCTAssertGreaterThan(fellBack, 10, "the \(language) sample must hit lesson questions")
        }
    }

    // MARK: - Fallback: scenarios

    func testRemovedScenarioRowsShowEnglish() throws {
        for language in languages(with: .scenarios) {
            var checked = 0
            for file in try scenarioFiles(language) {
                let scenes = englishScenes(file)
                let removedScreens = sample(file.screens.keys, every: 4)
                let removedOptions = sample(file.options.keys, every: 3)
                let shown = ContentOverlay.apply(
                    screens: file.screens.filter { !removedScreens.contains($0.key) }.compactMap { id, text in
                        UUID(uuidString: id).map { ScreenTranslation(screenId: $0, text: text.tr) }
                    },
                    options: file.options.filter { !removedOptions.contains($0.key) }.compactMap { id, text in
                        UUID(uuidString: id).map { OptionTranslation(optionId: $0, text: text.tr) }
                    },
                    to: scenes
                )
                for (scene, source) in zip(shown, scenes) {
                    XCTAssertFalse(scene.text.isEmpty)
                    XCTAssertEqual(scene.text, removedScreens.contains(source.id) ? source.text : file.screens[source.id]?.tr)
                    for (option, sourceOption) in zip(scene.options ?? [], source.options ?? []) {
                        XCTAssertEqual(option.text, removedOptions.contains(sourceOption.id) ? sourceOption.text : file.options[sourceOption.id]?.tr)
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
            XCTAssertGreaterThan(checked, 200, language)
        }
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

    func testTheShippedLanguagesSendTheSameLessonCourseAndCategoryValues() throws {
        let englishRun = try lessonAndCourseValues(englishLessons())
        XCTAssertGreaterThan(englishRun.count, 150)

        for language in languages(with: .catalogs, .lessons) {
            defer { resetToEnglish() }
            try becomeTheShippedApp(language)
            let lessons = try translatedLessons(language)
            // The translated run must really be showing the translation.
            XCTAssertGreaterThan(lessons.filter { $0.displayTitle != $0.title }.count, lessons.count * 9 / 10, language)
            XCTAssertTrue(categories.allSatisfy { $0.displayName != $0.name }, "every category shows \(language)")
            XCTAssertGreaterThan(courses.filter { $0.displayTitle != $0.title }.count, courses.count * 9 / 10, language)

            let translatedRun = try lessonAndCourseValues(lessons)
            XCTAssertEqual(translatedRun.count, englishRun.count, language)
            for (translated, english) in zip(translatedRun, englishRun) {
                XCTAssertEqual(translated, english, language)
            }
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

    func testTheShippedLanguagesStoreAndSendTheSameOnboardingAnswers() throws {
        let englishRun = onboardingValues()
        let englishLabels = MotivationOption.allCases.map(\.label)

        for language in languages(with: .catalogs) {
            defer { resetToEnglish() }
            try becomeTheShippedApp(language)
            XCTAssertNotEqual(MotivationOption.allCases.map(\.label), englishLabels, "the \(language) run must show \(language) labels")
            XCTAssertEqual(onboardingValues(), englishRun, language)
        }
    }

    func testTheShippedLanguagesSendTheSameScenarioValues() throws {
        for language in languages(with: .scenarios) {
            for file in try scenarioFiles(language) {
                let english = PracticeGameData(id: file.scenarioID.uuidString, title: file.title.en, scenes: englishScenes(file))
                let practice = ContentOverlay.apply(
                    [ScenarioTranslation(scenarioId: file.scenarioID, title: file.title.tr, summary: file.summary.tr)],
                    to: [Practice(
                        id: file.scenarioID, title: file.title.en, summary: file.summary.en, coverImageUrl: nil,
                        requiredLessonsCompleted: 0, womanName: nil, orderIndex: 1, isPublished: true,
                        createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
                    )]
                )[0]
                XCTAssertEqual(practice.displayTitle, file.title.tr, language)
                // What the game is built with: the English title, translated screens.
                let translated = PracticeGameData(
                    id: file.scenarioID.uuidString, title: practice.title,
                    scenes: ContentOverlay.apply(
                        screens: file.screens.compactMap { id, text in UUID(uuidString: id).map { ScreenTranslation(screenId: $0, text: text.tr) } },
                        options: [], to: englishScenes(file)
                    )
                )
                for walkthrough in [true, false] {
                    XCTAssertEqual(comparable(translated.analyticsProperties(duringWalkthrough: walkthrough)),
                                   comparable(english.analyticsProperties(duringWalkthrough: walkthrough)), language)
                }
            }
        }
    }
}
