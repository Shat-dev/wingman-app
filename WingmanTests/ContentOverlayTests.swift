//
//  ContentOverlayTests.swift
//  WingmanTests
//
//  WP7 of the localization plan, second slice: laying translated database
//  content over the English rows.
//
//  What must hold whatever a translation table contains: no translation
//  means the English input back unchanged; a missing or blank field falls
//  back to English on its own; answer options are only used when they line
//  up with the English ones; and nothing that decides correctness, branching
//  or analytics ever comes from a translation.
//

import XCTest
@testable import Wingman

@MainActor
final class ContentOverlayTests: XCTestCase {

    override func tearDown() {
        L10n.contentLanguageOverrideForTesting = nil
        L10n.sourceOverrideForTesting = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let unknownID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

    private var questions: [QuizQuestion] {
        [
            QuizQuestion(
                id: firstID, number: 1, question: "What do you say first?",
                options: ["Hi", "Nothing", "A line"], questionType: .singleSelect,
                correctAnswerIndex: 0, correctAnswerIndices: nil, explanation: "Simple works."
            ),
            QuizQuestion(
                id: secondID, number: 2, question: "Which of these help?",
                options: ["Eye contact", "Rushing", "Smiling", "Looking away"], questionType: .multipleSelect,
                correctAnswerIndex: nil, correctAnswerIndices: [0, 2], explanation: "Warmth reads as confidence."
            )
        ]
    }

    private func assertSameQuestion(_ a: QuizQuestion, _ b: QuizQuestion, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.id, b.id, file: file, line: line)
        XCTAssertEqual(a.number, b.number, file: file, line: line)
        XCTAssertEqual(a.question, b.question, file: file, line: line)
        XCTAssertEqual(a.options, b.options, file: file, line: line)
        XCTAssertEqual(a.questionType, b.questionType, file: file, line: line)
        XCTAssertEqual(a.correctAnswerIndex, b.correctAnswerIndex, file: file, line: line)
        XCTAssertEqual(a.correctAnswerIndices, b.correctAnswerIndices, file: file, line: line)
        XCTAssertEqual(a.explanation, b.explanation, file: file, line: line)
    }

    // MARK: - Fields

    func testTextFallsBackToEnglishWhenMissingOrBlank() {
        XCTAssertEqual(ContentOverlay.text("Hallo", fallback: "Hello"), "Hallo")
        XCTAssertEqual(ContentOverlay.text(nil, fallback: "Hello"), "Hello")
        XCTAssertEqual(ContentOverlay.text("", fallback: "Hello"), "Hello")
        XCTAssertEqual(ContentOverlay.text("  \n ", fallback: "Hello"), "Hello")
    }

    func testOptionsAreOnlyUsedWhenTheyLineUp() {
        let english = ["Yes", "No", "Maybe"]
        XCTAssertEqual(ContentOverlay.options(["Ja", "Nein", "Vielleicht"], english: english), ["Ja", "Nein", "Vielleicht"])
        XCTAssertEqual(ContentOverlay.options(nil, english: english), english)
        XCTAssertEqual(ContentOverlay.options(["Ja", "Nein"], english: english), english, "one too few")
        XCTAssertEqual(ContentOverlay.options(["Ja", "Nein", "Vielleicht", "Nie"], english: english), english, "one too many")
        XCTAssertEqual(ContentOverlay.options(["Ja", " ", "Vielleicht"], english: english), english, "a blank option")
        XCTAssertEqual(ContentOverlay.options([], english: english), english)
    }

    // MARK: - Questions

    /// Parity: with no translation rows the questions come back as they went
    /// in. This is what every user gets while the tables are empty.
    func testNoTranslationsLeavesQuestionsUnchanged() {
        let result = ContentOverlay.apply([QuestionTranslation](), to: questions)
        XCTAssertEqual(result.count, 2)
        for (before, after) in zip(questions, result) {
            assertSameQuestion(before, after)
        }
    }

    func testAFullTranslationReplacesTextOnly() {
        let translation = QuestionTranslation(
            questionId: firstID, questionText: "Was sagst du zuerst?",
            options: ["Hi", "Nichts", "Einen Spruch"], explanation: "Einfach funktioniert."
        )
        let result = ContentOverlay.apply([translation], to: questions)

        XCTAssertEqual(result[0].question, "Was sagst du zuerst?")
        XCTAssertEqual(result[0].options, ["Hi", "Nichts", "Einen Spruch"])
        XCTAssertEqual(result[0].explanation, "Einfach funktioniert.")
        // Everything that is not text is the English row's.
        XCTAssertEqual(result[0].id, firstID)
        XCTAssertEqual(result[0].number, 1)
        XCTAssertEqual(result[0].questionType, .singleSelect)
        XCTAssertEqual(result[0].correctAnswerIndex, 0)
        // The untranslated question is untouched.
        assertSameQuestion(result[1], questions[1])
    }

    func testFallbackIsPerField() {
        let translation = QuestionTranslation(
            questionId: firstID, questionText: "Was sagst du zuerst?", options: nil, explanation: "  "
        )
        let result = ContentOverlay.apply([translation], to: questions)
        XCTAssertEqual(result[0].question, "Was sagst du zuerst?")
        XCTAssertEqual(result[0].options, ["Hi", "Nothing", "A line"])
        XCTAssertEqual(result[0].explanation, "Simple works.")
    }

    /// The English question gained or lost an option after it was
    /// translated: the translated options are dropped, the rest is kept, and
    /// the correct answers still point at the right entries.
    func testOptionsOfTheWrongLengthAreIgnoredAndCorrectnessIsSafe() {
        let translation = QuestionTranslation(
            questionId: secondID, questionText: "Was davon hilft?",
            options: ["Blickkontakt", "Hetzen", "Lächeln"], explanation: "Wärme wirkt selbstbewusst."
        )
        let result = ContentOverlay.apply([translation], to: questions)
        XCTAssertEqual(result[1].question, "Was davon hilft?")
        XCTAssertEqual(result[1].options, ["Eye contact", "Rushing", "Smiling", "Looking away"])
        XCTAssertEqual(result[1].correctAnswerIndices, [0, 2])
        XCTAssertEqual(result[1].explanation, "Wärme wirkt selbstbewusst.")
    }

    func testTranslationsForUnknownQuestionsAreIgnored() {
        let stray = QuestionTranslation(questionId: unknownID, questionText: "Fremd", options: nil, explanation: nil)
        let result = ContentOverlay.apply([stray], to: questions)
        for (before, after) in zip(questions, result) {
            assertSameQuestion(before, after)
        }
    }

    func testLessonQuestionRowsAreOverlaidTheSameWay() {
        let row = LessonQuestionRow(
            id: firstID, lessonId: "lesson_1_1", lessonQuizOrder: 2, questionType: "single_select",
            questionText: "What do you say first?", options: ["Hi", "Nothing", "A line"],
            correctAnswerIndex: 0, correctAnswerIndices: nil, explanation: "Simple works."
        )
        let translation = QuestionTranslation(
            questionId: firstID, questionText: "Was sagst du zuerst?", options: ["Hi", "Nichts"], explanation: nil
        )
        let result = ContentOverlay.apply([translation], to: [row])
        XCTAssertEqual(result[0].questionText, "Was sagst du zuerst?")
        XCTAssertEqual(result[0].options, ["Hi", "Nothing", "A line"], "wrong length, English kept")
        XCTAssertEqual(result[0].explanation, "Simple works.")
        XCTAssertEqual(result[0].lessonId, "lesson_1_1")
        XCTAssertEqual(result[0].lessonQuizOrder, 2)
        XCTAssertEqual(result[0].correctAnswerIndex, 0)

        let untouched = ContentOverlay.apply([QuestionTranslation](), to: [row])
        XCTAssertEqual(untouched[0].questionText, row.questionText)
        XCTAssertEqual(untouched[0].options, row.options)
    }

    // MARK: - Scenarios

    private func practice(_ id: UUID, title: String, summary: String) -> Practice {
        Practice(
            id: id, title: title, summary: summary, coverImageUrl: "scenario_amber",
            requiredLessonsCompleted: 0, womanName: "Amber", orderIndex: 1, isPublished: true,
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testScenarioKeepsItsEnglishTitleAndGainsADisplayTitle() {
        let english = practice(firstID, title: "Bar Window", summary: "Loud music, crowded space.")
        let translation = ScenarioTranslation(scenarioId: firstID, title: "Am Bartresen", summary: "Laute Musik, volle Bar.")
        let result = ContentOverlay.apply([translation], to: [english])

        XCTAssertEqual(result[0].title, "Bar Window", "the English title is what analytics records")
        XCTAssertEqual(result[0].summary, "Loud music, crowded space.")
        XCTAssertEqual(result[0].displayTitle, "Am Bartresen")
        XCTAssertEqual(result[0].displaySummary, "Laute Musik, volle Bar.")
        XCTAssertEqual(result[0].id, firstID)
        XCTAssertEqual(result[0].orderIndex, 1)
    }

    func testScenarioWithoutATranslationShowsEnglish() {
        let english = practice(firstID, title: "Bar Window", summary: "Loud music, crowded space.")
        XCTAssertEqual(english.displayTitle, "Bar Window")
        XCTAssertEqual(english.displaySummary, "Loud music, crowded space.")

        let untouched = ContentOverlay.apply([ScenarioTranslation](), to: [english])
        XCTAssertEqual(untouched, [english])

        let partial = ContentOverlay.apply(
            [ScenarioTranslation(scenarioId: firstID, title: " ", summary: "Laute Musik.")], to: [english]
        )
        XCTAssertEqual(partial[0].displayTitle, "Bar Window", "blank title falls back")
        XCTAssertEqual(partial[0].displaySummary, "Laute Musik.")
    }

    // MARK: - Scenes and options

    private var scenes: [GameScene] {
        [
            GameScene(
                id: firstID.uuidString.lowercased(), type: .context, characterName: nil,
                text: "You walk into the bar.", imageName: "game_person_m", options: nil, order: 1,
                defaultNextScreenId: secondID.uuidString.lowercased(), retryTargetScreenId: nil
            ),
            GameScene(
                id: secondID.uuidString.lowercased(), type: .options, characterName: nil,
                text: "What do you do?", imageName: nil,
                options: [
                    GameOption(id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", text: "Say hi", nextSceneId: "next-good", isCorrect: true, orderIndex: 0),
                    GameOption(id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", text: "Leave", nextSceneId: "next-bad", isCorrect: false, orderIndex: 1)
                ],
                order: 2, defaultNextScreenId: nil, retryTargetScreenId: firstID.uuidString.lowercased()
            )
        ]
    }

    func testNoTranslationsLeavesScenesUnchanged() {
        let result = ContentOverlay.apply(screens: [], options: [], to: scenes)
        XCTAssertEqual(result.map(\.text), scenes.map(\.text))
        XCTAssertEqual(result[1].options?.map(\.text), ["Say hi", "Leave"])
    }

    /// Text changes; where the scenario goes and what counts as right do not.
    func testScreenAndOptionTextIsReplacedAndBranchingIsNot() {
        let result = ContentOverlay.apply(
            screens: [ScreenTranslation(screenId: firstID, text: "Du betrittst die Bar.")],
            options: [OptionTranslation(optionId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, text: "Hallo sagen")],
            to: scenes
        )
        XCTAssertEqual(result[0].text, "Du betrittst die Bar.")
        XCTAssertEqual(result[1].text, "What do you do?", "untranslated screen keeps English")
        XCTAssertEqual(result[1].options?.map(\.text), ["Hallo sagen", "Leave"], "matched whatever the ID's case; untranslated option keeps English")

        for (before, after) in zip(scenes, result) {
            XCTAssertEqual(after.id, before.id)
            XCTAssertEqual(after.type, before.type)
            XCTAssertEqual(after.order, before.order)
            XCTAssertEqual(after.imageName, before.imageName)
            XCTAssertEqual(after.defaultNextScreenId, before.defaultNextScreenId)
            XCTAssertEqual(after.retryTargetScreenId, before.retryTargetScreenId)
            XCTAssertEqual(after.options?.map(\.id), before.options?.map(\.id))
            XCTAssertEqual(after.options?.map(\.nextSceneId), before.options?.map(\.nextSceneId))
            XCTAssertEqual(after.options?.map(\.isCorrect), before.options?.map(\.isCorrect))
            XCTAssertEqual(after.options?.map(\.orderIndex), before.options?.map(\.orderIndex))
        }
    }

    func testABlankScreenTranslationFallsBackToEnglish() {
        let result = ContentOverlay.apply(
            screens: [ScreenTranslation(screenId: firstID, text: "   ")], options: [], to: scenes
        )
        XCTAssertEqual(result[0].text, "You walk into the bar.")
    }

    // MARK: - Rows decode from the table's column names

    func testRowsDecodeFromTheDatabaseShape() throws {
        let decoder = JSONDecoder()
        let question = try decoder.decode([QuestionTranslation].self, from: Data("""
        [{"question_id":"11111111-1111-1111-1111-111111111111","question_text":"Frage","options":["a","b"],"explanation":null}]
        """.utf8))
        XCTAssertEqual(question, [QuestionTranslation(questionId: firstID, questionText: "Frage", options: ["a", "b"], explanation: nil)])

        let scenario = try decoder.decode([ScenarioTranslation].self, from: Data("""
        [{"scenario_id":"11111111-1111-1111-1111-111111111111","title":"Titel","summary":null}]
        """.utf8))
        XCTAssertEqual(scenario, [ScenarioTranslation(scenarioId: firstID, title: "Titel", summary: nil)])

        let screen = try decoder.decode([ScreenTranslation].self, from: Data("""
        [{"screen_id":"11111111-1111-1111-1111-111111111111","text":"Text"}]
        """.utf8))
        XCTAssertEqual(screen, [ScreenTranslation(screenId: firstID, text: "Text")])

        let option = try decoder.decode([OptionTranslation].self, from: Data("""
        [{"option_id":"11111111-1111-1111-1111-111111111111","text":"Text"}]
        """.utf8))
        XCTAssertEqual(option, [OptionTranslation(optionId: firstID, text: "Text")])
    }

    // MARK: - Which language to ask for

    /// English asks for nothing, so English makes no extra request.
    func testEnglishHasNoContentLanguage() {
        XCTAssertNil(L10n.contentLanguage)
    }

    func testLanguageTags() {
        XCTAssertEqual(L10n.languageTag("de"), "de")
        XCTAssertEqual(L10n.languageTag("pt-BR"), "pt-br")
        XCTAssertEqual(L10n.languageTag("zh_Hans"), "zh-hans")
        XCTAssertNil(L10n.languageTag("en"), "the development language is not a translation")
        XCTAssertNil(L10n.languageTag(nil))
        XCTAssertNil(L10n.languageTag(""))
    }

    func testTheContentLanguageCanBePinnedInTests() {
        L10n.contentLanguageOverrideForTesting = .init(value: "de")
        XCTAssertEqual(L10n.contentLanguage, "de")
        L10n.contentLanguageOverrideForTesting = .init(value: nil)
        XCTAssertNil(L10n.contentLanguage)
    }
}
