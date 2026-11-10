//
//  ContentLocalizer.swift
//  Wingman
//
//  Fetches translation rows for content the app has just loaded in English
//  and lays them over it (the rules are in `ContentOverlay`).
//
//  Three promises:
//
//    1. English makes no request. `L10n.contentLanguage` is nil while the
//       app runs in English, and every method returns its input at once.
//       An English user's network traffic is exactly what it was before
//       this file existed.
//    2. One extra request per content fetch in another language (two for a
//       scenario's screens, run together: screen texts and option texts).
//       Only the rows for the IDs just received, only the active language.
//    3. A failure costs nothing but the translation. If the request fails
//       (offline, the tables do not exist yet, a timeout) the English
//       content is returned as it was. Content never disappears because a
//       translation could not be fetched.
//

import Foundation
import Supabase

// MARK: - Fetching

/// Reads translation rows. A protocol so tests can count and fail requests.
protocol ContentTranslationFetching {
    func questionTranslations(ids: [UUID], language: String) async throws -> [QuestionTranslation]
    func scenarioTranslations(ids: [UUID], language: String) async throws -> [ScenarioTranslation]
    func screenTranslations(ids: [UUID], language: String) async throws -> [ScreenTranslation]
    func optionTranslations(ids: [UUID], language: String) async throws -> [OptionTranslation]
}

/// The four translation tables, read through the same Supabase client as
/// the English content.
struct SupabaseContentTranslationFetcher: ContentTranslationFetching {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    func questionTranslations(ids: [UUID], language: String) async throws -> [QuestionTranslation] {
        try await client
            .from("question_translations")
            .select("question_id, question_text, options, explanation")
            .eq("locale", value: language)
            .in("question_id", values: ids.map(\.uuidString))
            .execute()
            .value
    }

    func scenarioTranslations(ids: [UUID], language: String) async throws -> [ScenarioTranslation] {
        try await client
            .from("scenario_translations")
            .select("scenario_id, title, summary")
            .eq("locale", value: language)
            .in("scenario_id", values: ids.map(\.uuidString))
            .execute()
            .value
    }

    func screenTranslations(ids: [UUID], language: String) async throws -> [ScreenTranslation] {
        try await client
            .from("scenario_screen_translations")
            .select("screen_id, text")
            .eq("locale", value: language)
            .in("screen_id", values: ids.map(\.uuidString))
            .execute()
            .value
    }

    func optionTranslations(ids: [UUID], language: String) async throws -> [OptionTranslation] {
        try await client
            .from("screen_option_translations")
            .select("option_id, text")
            .eq("locale", value: language)
            .in("option_id", values: ids.map(\.uuidString))
            .execute()
            .value
    }
}

// MARK: - Localizing

struct ContentLocalizer {

    /// The language to ask for; nil means English, and no request.
    var language: () -> String? = { L10n.contentLanguage }
    var fetcher: ContentTranslationFetching = SupabaseContentTranslationFetcher()

    /// Daily practice and quiz questions.
    func localized(_ questions: [QuizQuestion]) async -> [QuizQuestion] {
        guard let language = language(), !questions.isEmpty else { return questions }
        do {
            let rows = try await fetcher.questionTranslations(ids: questions.map(\.id), language: language)
            return ContentOverlay.apply(rows, to: questions)
        } catch {
            log("🌍 Question translations unavailable (\(language)); showing English: \(error)")
            return questions
        }
    }

    /// The scenario list. Titles stay English; display titles are added.
    func localized(_ practices: [Practice]) async -> [Practice] {
        guard let language = language(), !practices.isEmpty else { return practices }
        do {
            let rows = try await fetcher.scenarioTranslations(ids: practices.map(\.id), language: language)
            return ContentOverlay.apply(rows, to: practices)
        } catch {
            log("🌍 Scenario translations unavailable (\(language)); showing English: \(error)")
            return practices
        }
    }

    /// One scenario's screens and their answer options.
    func localized(_ scenes: [GameScene]) async -> [GameScene] {
        guard let language = language(), !scenes.isEmpty else { return scenes }

        let screenIDs = scenes.compactMap { UUID(uuidString: $0.id) }
        let optionIDs = scenes.flatMap { $0.options ?? [] }.compactMap { UUID(uuidString: $0.id) }

        // Independent reads, run together. Each fails on its own: losing the
        // option texts must not also throw away the screen texts.
        async let screenRows = fetchOrEmpty(screenIDs) { try await fetcher.screenTranslations(ids: $0, language: language) }
        async let optionRows = fetchOrEmpty(optionIDs) { try await fetcher.optionTranslations(ids: $0, language: language) }

        return ContentOverlay.apply(screens: await screenRows, options: await optionRows, to: scenes)
    }

    private func fetchOrEmpty<Row>(_ ids: [UUID], _ fetch: ([UUID]) async throws -> [Row]) async -> [Row] {
        guard !ids.isEmpty else { return [] }
        do {
            return try await fetch(ids)
        } catch {
            log("🌍 Scenario text translations unavailable; showing English: \(error)")
            return []
        }
    }
}
