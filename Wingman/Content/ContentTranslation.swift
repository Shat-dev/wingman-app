//
//  ContentTranslation.swift
//  Wingman
//
//  Translated database content, laid over the English rows by ID.
//
//  The English tables stay the source of everything that is not display
//  text: which answer is correct, where a scenario branches, what order
//  things come in, and every ID. A translation row carries text for one
//  English row in one language and nothing else (see
//  supabase/migrations/20261110000000_content_translations.sql). The app
//  fetches English exactly as it always has and, only when its language is
//  not English, fetches the translation rows for the IDs it just received
//  and lays them over.
//
//  The rules, all in `ContentOverlay`:
//
//    1. No translation, or an empty list of them, returns the English input
//       unchanged.
//    2. Fallback is per field. A row that translates the question but not
//       the explanation shows the translated question and the English
//       explanation. Blank text counts as missing, so nothing can render
//       empty.
//    3. Translated answer options are used only if there are exactly as many
//       as the English ones and none is blank. The correct answer is an
//       index into that list; a list of a different length would move it.
//    4. Only text changes. IDs, answer indexes, `isCorrect`, next-screen
//       pointers and order are copied from the English row every time.
//    5. A scenario's English title stays in `Practice.title`, because it is
//       what analytics records. The translated one goes in a separate field
//       and is read through `displayTitle`.
//

import Foundation

// MARK: - Rows

/// One row of `question_translations`.
struct QuestionTranslation: nonisolated Decodable, Sendable, Equatable {
    let questionId: UUID
    let questionText: String?
    let options: [String]?
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case questionText = "question_text"
        case options
        case explanation
    }
}

/// One row of `scenario_translations`.
struct ScenarioTranslation: nonisolated Decodable, Sendable, Equatable {
    let scenarioId: UUID
    let title: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case scenarioId = "scenario_id"
        case title
        case summary
    }
}

/// One row of `scenario_screen_translations`.
struct ScreenTranslation: nonisolated Decodable, Sendable, Equatable {
    let screenId: UUID
    let text: String

    enum CodingKeys: String, CodingKey {
        case screenId = "screen_id"
        case text
    }
}

/// One row of `screen_option_translations`.
struct OptionTranslation: nonisolated Decodable, Sendable, Equatable {
    let optionId: UUID
    let text: String

    enum CodingKeys: String, CodingKey {
        case optionId = "option_id"
        case text
    }
}

// MARK: - Overlay

enum ContentOverlay {

    // MARK: Fields

    /// The translated text, or the English when there is none or it is blank.
    static func text(_ translated: String?, fallback english: String) -> String {
        guard let translated,
              !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return english }
        return translated
    }

    /// The translated options, or the English ones unless the translation
    /// has exactly as many entries and none is blank.
    static func options(_ translated: [String]?, english: [String]) -> [String] {
        guard let translated,
              translated.count == english.count,
              translated.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return english
        }
        return translated
    }

    // MARK: Questions

    static func apply(_ translations: [QuestionTranslation], to questions: [QuizQuestion]) -> [QuizQuestion] {
        guard !translations.isEmpty else { return questions }
        let byID = Dictionary(translations.map { ($0.questionId, $0) }, uniquingKeysWith: { first, _ in first })

        return questions.map { question in
            guard let translation = byID[question.id] else { return question }
            return QuizQuestion(
                id: question.id,
                number: question.number,
                question: text(translation.questionText, fallback: question.question),
                options: options(translation.options, english: question.options),
                questionType: question.questionType,
                correctAnswerIndex: question.correctAnswerIndex,
                correctAnswerIndices: question.correctAnswerIndices,
                explanation: text(translation.explanation, fallback: question.explanation)
            )
        }
    }

    static func apply(_ translations: [QuestionTranslation], to rows: [LessonQuestionRow]) -> [LessonQuestionRow] {
        guard !translations.isEmpty else { return rows }
        let byID = Dictionary(translations.map { ($0.questionId, $0) }, uniquingKeysWith: { first, _ in first })

        return rows.map { row in
            guard let translation = byID[row.id] else { return row }
            return LessonQuestionRow(
                id: row.id,
                lessonId: row.lessonId,
                lessonQuizOrder: row.lessonQuizOrder,
                questionType: row.questionType,
                questionText: text(translation.questionText, fallback: row.questionText),
                options: options(translation.options, english: row.options),
                correctAnswerIndex: row.correctAnswerIndex,
                correctAnswerIndices: row.correctAnswerIndices,
                explanation: text(translation.explanation, fallback: row.explanation)
            )
        }
    }

    // MARK: Scenarios

    /// Sets each scenario's translated title and summary. `title` and
    /// `summary` themselves stay English.
    static func apply(_ translations: [ScenarioTranslation], to practices: [Practice]) -> [Practice] {
        guard !translations.isEmpty else { return practices }
        let byID = Dictionary(translations.map { ($0.scenarioId, $0) }, uniquingKeysWith: { first, _ in first })

        return practices.map { practice in
            guard let translation = byID[practice.id] else { return practice }
            var translated = practice
            translated.translatedTitle = nonBlank(translation.title)
            translated.translatedSummary = nonBlank(translation.summary)
            return translated
        }
    }

    /// Replaces screen and option text. Everything that decides where the
    /// scenario goes is copied from the English scene.
    static func apply(
        screens: [ScreenTranslation],
        options: [OptionTranslation],
        to scenes: [GameScene]
    ) -> [GameScene] {
        guard !screens.isEmpty || !options.isEmpty else { return scenes }
        let screenText = Dictionary(screens.map { (key($0.screenId), $0.text) }, uniquingKeysWith: { first, _ in first })
        let optionText = Dictionary(options.map { (key($0.optionId), $0.text) }, uniquingKeysWith: { first, _ in first })

        return scenes.map { scene in
            GameScene(
                id: scene.id,
                type: scene.type,
                characterName: scene.characterName,
                text: text(screenText[key(scene.id)], fallback: scene.text),
                imageName: scene.imageName,
                options: scene.options?.map { option in
                    GameOption(
                        id: option.id,
                        text: text(optionText[key(option.id)], fallback: option.text),
                        nextSceneId: option.nextSceneId,
                        isCorrect: option.isCorrect,
                        orderIndex: option.orderIndex
                    )
                },
                order: scene.order,
                defaultNextScreenId: scene.defaultNextScreenId,
                retryTargetScreenId: scene.retryTargetScreenId
            )
        }
    }

    // MARK: Helpers

    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    /// Scene and option IDs are UUID strings whose case depends on who wrote
    /// them; compare them case-insensitively.
    private static func key(_ id: UUID) -> String { id.uuidString.lowercased() }
    private static func key(_ id: String) -> String { id.lowercased() }
}
