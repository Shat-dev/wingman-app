//
//  ContentLocalizerTests.swift
//  WingmanTests
//
//  WP7 of the localization plan, third slice: fetching translation rows and
//  applying them.
//
//  The three promises of `ContentLocalizer`, tested with a fetcher that
//  counts its requests and can be told to fail:
//    - English makes no request at all;
//    - another language makes one request per content fetch (two, run
//      together, for a scenario's screens);
//    - a failed request leaves the English content exactly as it was.
//

import XCTest
@testable import Wingman

@MainActor
final class ContentLocalizerTests: XCTestCase {

    // MARK: - A fetcher that counts

    private final class CountingFetcher: ContentTranslationFetching {
        struct Failure: Error {}

        var requests: [String] = []
        var failing: Set<String> = []
        /// Tables whose next request fails, after which they answer.
        var failingOnce: Set<String> = []

        var questions: [QuestionTranslation] = []
        var scenarios: [ScenarioTranslation] = []
        var screens: [ScreenTranslation] = []
        var options: [OptionTranslation] = []

        private func record(_ table: String, _ ids: [UUID], _ language: String) throws {
            requests.append("\(table) \(language) \(ids.count)")
            if failing.contains(table) { throw Failure() }
            if failingOnce.remove(table) != nil { throw Failure() }
        }

        func questionTranslations(ids: [UUID], language: String) async throws -> [QuestionTranslation] {
            try record("questions", ids, language)
            return questions
        }

        func scenarioTranslations(ids: [UUID], language: String) async throws -> [ScenarioTranslation] {
            try record("scenarios", ids, language)
            return scenarios
        }

        func screenTranslations(ids: [UUID], language: String) async throws -> [ScreenTranslation] {
            try record("screens", ids, language)
            return screens
        }

        func optionTranslations(ids: [UUID], language: String) async throws -> [OptionTranslation] {
            try record("options", ids, language)
            return options
        }
    }

    private func localizer(
        language: String?, fetcher: CountingFetcher, bundled: [QuestionTranslation] = []
    ) -> ContentLocalizer {
        ContentLocalizer(language: { language }, fetcher: fetcher, retryDelay: .zero, bundledQuestions: { _ in bundled })
    }

    // MARK: - Fixtures

    private let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let optionID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    private var questions: [QuizQuestion] {
        [
            QuizQuestion(
                id: firstID, number: 1, question: "What do you say first?",
                options: ["Hi", "Nothing"], questionType: .singleSelect,
                correctAnswerIndex: 0, correctAnswerIndices: nil, explanation: "Simple works."
            ),
            QuizQuestion(
                id: secondID, number: 2, question: "And then?",
                options: ["Listen", "Leave"], questionType: .singleSelect,
                correctAnswerIndex: 0, correctAnswerIndices: nil, explanation: "Stay curious."
            )
        ]
    }

    private var practices: [Practice] {
        [
            Practice(
                id: firstID, title: "Bar Window", summary: "Loud music.", coverImageUrl: nil,
                requiredLessonsCompleted: 0, womanName: "Amber", orderIndex: 1, isPublished: true,
                createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
            )
        ]
    }

    private var scenes: [GameScene] {
        [
            GameScene(
                id: firstID.uuidString.lowercased(), type: .context, characterName: nil,
                text: "You walk in.", imageName: nil, options: nil, order: 1,
                defaultNextScreenId: secondID.uuidString.lowercased(), retryTargetScreenId: nil
            ),
            GameScene(
                id: secondID.uuidString.lowercased(), type: .options, characterName: nil,
                text: "What now?", imageName: nil,
                options: [GameOption(id: optionID.uuidString.lowercased(), text: "Say hi", nextSceneId: nil, isCorrect: true, orderIndex: 0)],
                order: 2, defaultNextScreenId: nil, retryTargetScreenId: nil
            )
        ]
    }

    // MARK: - English makes no request

    func testEnglishMakesNoRequestAndReturnsItsInput() async {
        let fetcher = CountingFetcher()
        fetcher.questions = [QuestionTranslation(questionId: firstID, questionText: "Übersetzt", options: nil, explanation: nil)]
        let english = localizer(language: nil, fetcher: fetcher)

        let resultQuestions = await english.localized(questions)
        let resultPractices = await english.localized(practices)
        let resultScenes = await english.localized(scenes)

        XCTAssertEqual(fetcher.requests, [], "an English app must not touch the translation tables")
        XCTAssertEqual(resultQuestions.map(\.question), questions.map(\.question))
        XCTAssertEqual(resultPractices, practices)
        XCTAssertEqual(resultScenes.map(\.text), scenes.map(\.text))
    }

    /// The default localizer, as the services use it, is in English here.
    func testTheDefaultLocalizerIsEnglishInAnEnglishApp() async {
        let result = await ContentLocalizer().localized(questions)
        XCTAssertEqual(result.map(\.question), questions.map(\.question))
        XCTAssertNil(L10n.contentLanguage)
    }

    // MARK: - Another language: one request per fetch

    func testQuestionsCostOneRequestForExactlyTheirIDs() async {
        let fetcher = CountingFetcher()
        fetcher.questions = [QuestionTranslation(questionId: firstID, questionText: "Was sagst du zuerst?", options: nil, explanation: nil)]

        let result = await localizer(language: "de", fetcher: fetcher).localized(questions)

        XCTAssertEqual(fetcher.requests, ["questions de 2"])
        XCTAssertEqual(result[0].question, "Was sagst du zuerst?")
        XCTAssertEqual(result[0].options, ["Hi", "Nothing"], "untranslated field stays English")
        XCTAssertEqual(result[1].question, "And then?", "untranslated question stays English")
    }

    func testScenarioListCostsOneRequest() async {
        let fetcher = CountingFetcher()
        fetcher.scenarios = [ScenarioTranslation(scenarioId: firstID, title: "Am Bartresen", summary: nil)]

        let result = await localizer(language: "de", fetcher: fetcher).localized(practices)

        XCTAssertEqual(fetcher.requests, ["scenarios de 1"])
        XCTAssertEqual(result[0].displayTitle, "Am Bartresen")
        XCTAssertEqual(result[0].title, "Bar Window")
        XCTAssertEqual(result[0].displaySummary, "Loud music.")
    }

    func testScenarioScreensCostTwoRequests() async {
        let fetcher = CountingFetcher()
        fetcher.screens = [ScreenTranslation(screenId: firstID, text: "Du kommst rein.")]
        fetcher.options = [OptionTranslation(optionId: optionID, text: "Hallo sagen")]

        let result = await localizer(language: "de", fetcher: fetcher).localized(scenes)

        XCTAssertEqual(Set(fetcher.requests), ["screens de 2", "options de 1"])
        XCTAssertEqual(fetcher.requests.count, 2)
        XCTAssertEqual(result[0].text, "Du kommst rein.")
        XCTAssertEqual(result[1].text, "What now?")
        XCTAssertEqual(result[1].options?.first?.text, "Hallo sagen")
        XCTAssertEqual(result[1].options?.first?.isCorrect, true)
    }

    /// A scenario with no answer options asks only for screen texts.
    func testNoOptionsMeansNoOptionRequest() async {
        let fetcher = CountingFetcher()
        _ = await localizer(language: "de", fetcher: fetcher).localized([scenes[0]])
        XCTAssertEqual(fetcher.requests, ["screens de 1"])
    }

    func testEmptyContentMakesNoRequest() async {
        let fetcher = CountingFetcher()
        let german = localizer(language: "de", fetcher: fetcher)
        _ = await german.localized([QuizQuestion]())
        _ = await german.localized([Practice]())
        _ = await german.localized([GameScene]())
        XCTAssertEqual(fetcher.requests, [])
    }

    // MARK: - A failed request leaves English in place

    func testAFailedQuestionRequestReturnsTheEnglishQuestions() async {
        let fetcher = CountingFetcher()
        fetcher.failing = ["questions"]
        let result = await localizer(language: "de", fetcher: fetcher).localized(questions)
        XCTAssertEqual(fetcher.requests.count, 2, "tried, then retried once, no more")
        XCTAssertEqual(result.map(\.question), questions.map(\.question))
        XCTAssertEqual(result.map(\.options), questions.map(\.options))
        XCTAssertEqual(result.map(\.explanation), questions.map(\.explanation))
    }

    func testAFailedScenarioRequestReturnsTheEnglishList() async {
        let fetcher = CountingFetcher()
        fetcher.failing = ["scenarios"]
        let result = await localizer(language: "de", fetcher: fetcher).localized(practices)
        XCTAssertEqual(result, practices)
        XCTAssertEqual(result[0].displayTitle, "Bar Window")
    }

    /// Screens and options fail independently: losing one keeps the other.
    func testAFailedOptionRequestStillTranslatesTheScreens() async {
        let fetcher = CountingFetcher()
        fetcher.screens = [ScreenTranslation(screenId: firstID, text: "Du kommst rein.")]
        fetcher.failing = ["options"]

        let result = await localizer(language: "de", fetcher: fetcher).localized(scenes)

        XCTAssertEqual(result[0].text, "Du kommst rein.")
        XCTAssertEqual(result[1].options?.first?.text, "Say hi")
    }

    func testBothScreenRequestsFailingReturnsTheEnglishScenes() async {
        let fetcher = CountingFetcher()
        fetcher.failing = ["screens", "options"]
        let result = await localizer(language: "de", fetcher: fetcher).localized(scenes)
        XCTAssertEqual(result.map(\.text), scenes.map(\.text))
        XCTAssertEqual(result[1].options?.map(\.text), ["Say hi"])
    }

    // MARK: - One retry, then the bundled questions

    func testAQuestionRequestThatFailsOnceIsRetriedAndTranslated() async {
        let fetcher = CountingFetcher()
        fetcher.questions = [QuestionTranslation(questionId: firstID, questionText: "Was sagst du zuerst?", options: nil, explanation: nil)]
        fetcher.failingOnce = ["questions"]

        let result = await localizer(language: "de", fetcher: fetcher).localized(questions)

        XCTAssertEqual(fetcher.requests.count, 2)
        XCTAssertEqual(result[0].question, "Was sagst du zuerst?")
    }

    func testAScenarioListRequestThatFailsOnceIsRetriedAndTranslated() async {
        let fetcher = CountingFetcher()
        fetcher.scenarios = [ScenarioTranslation(scenarioId: practices[0].id, title: "Barfenster", summary: nil)]
        fetcher.failingOnce = ["scenarios"]

        let result = await localizer(language: "de", fetcher: fetcher).localized(practices)

        XCTAssertEqual(fetcher.requests.count, 2)
        XCTAssertEqual(result[0].displayTitle, "Barfenster")
    }

    func testScreenAndOptionRequestsThatFailOnceAreRetried() async {
        let fetcher = CountingFetcher()
        fetcher.screens = [ScreenTranslation(screenId: firstID, text: "Du kommst rein.")]
        fetcher.options = [OptionTranslation(optionId: optionID, text: "Sag hallo")]
        fetcher.failingOnce = ["screens", "options"]

        let result = await localizer(language: "de", fetcher: fetcher).localized(scenes)

        XCTAssertEqual(fetcher.requests.count, 4)
        XCTAssertEqual(result[0].text, "Du kommst rein.")
        XCTAssertEqual(result[1].options?.first?.text, "Sag hallo")
    }

    func testFailedQuestionRequestsFallBackToTheBundledTranslations() async {
        let fetcher = CountingFetcher()
        fetcher.failing = ["questions"]
        let bundled = [
            QuestionTranslation(questionId: firstID, questionText: "Was sagst du zuerst?", options: nil, explanation: nil),
            QuestionTranslation(questionId: UUID(), questionText: "Eine andere Frage", options: nil, explanation: nil)
        ]

        let result = await localizer(language: "de", fetcher: fetcher, bundled: bundled).localized(questions)

        XCTAssertEqual(result[0].question, "Was sagst du zuerst?")
        XCTAssertEqual(result.count, questions.count, "no extra questions from the bundle")
    }
}
