//
//  QuestionTranslationCache.swift
//  Wingman
//
//  Translated quiz questions, kept on the device for the app's language.
//
//  Lesson quizzes read from an on-device snapshot of the English questions
//  (`LessonQuestionStore`), so they work offline and open instantly. That
//  snapshot, its file and its sync fingerprint are not touched by any of
//  this: English is English, exactly as before.
//
//  A translated app keeps a second, separate file beside it: the translation
//  rows for its language, keyed by question ID. A quiz is the English
//  questions with those rows laid over (`ContentOverlay`), so a question
//  with no translation, or one whose translation no longer lines up, shows
//  in English.
//
//    - English: no file is read, no request is made, questions pass through.
//    - One file and one fingerprint per language. Only the language the app
//      is running in is ever downloaded.
//    - The fingerprint is the row count and newest change for that language.
//      When it matches, a refresh costs one tiny request and no download.
//    - A failed refresh keeps whatever is cached. Offline, a translated app
//      shows the translations it last synced, or the bundled ones.
//    - The app ships each language's translations
//      (`question_translations_seed.<lang>.json`, written by
//      scripts/question_translations_seed.py from the same files as the
//      database rows). They are used until the first download lands, so a
//      quiz is translated from the first launch, offline included, instead
//      of racing the background download. A downloaded file replaces them.
//    - A download that comes back empty is treated as a failed read, never
//      stored: a request that went out without a session passes RLS as
//      `anon` and gets 200 with no rows.
//

import Foundation
import Supabase

// MARK: - Fetching

protocol QuestionTranslationSyncing {
    /// Row count and newest `updated_at` for a language, as one opaque
    /// string. Nil when the server did not answer the question asked.
    func fingerprint(language: String) async throws -> String?

    /// Every question translation for a language.
    func allTranslations(language: String) async throws -> [QuestionTranslation]
}

struct SupabaseQuestionTranslationSync: QuestionTranslationSyncing {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    private struct UpdatedAtRow: Decodable {
        let updatedAt: String
        enum CodingKeys: String, CodingKey { case updatedAt = "updated_at" }
    }

    func fingerprint(language: String) async throws -> String? {
        let response: PostgrestResponse<[UpdatedAtRow]> = try await client
            .from("question_translations")
            .select("updated_at", count: .exact)
            .eq("locale", value: language)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()

        guard let count = response.count else { return nil }
        return "\(count):\(response.value.first?.updatedAt ?? "-")"
    }

    /// Read in pages: the API caps a single response (1,000 rows by
    /// default), and a silently cut-off answer would leave some questions
    /// in English for no visible reason.
    func allTranslations(language: String) async throws -> [QuestionTranslation] {
        let pageSize = 1000
        var all: [QuestionTranslation] = []
        var start = 0

        while true {
            let page: [QuestionTranslation] = try await client
                .from("question_translations")
                .select("question_id, question_text, options, explanation")
                .eq("locale", value: language)
                .order("question_id", ascending: true)
                .range(from: start, to: start + pageSize - 1)
                .execute()
                .value

            all.append(contentsOf: page)
            if page.count < pageSize { break }
            start += pageSize
        }
        return all
    }
}

// MARK: - Bundled translations

/// The translations shipped in the app bundle for a language.
nonisolated enum QuestionTranslationSeed {

    static func resourceName(_ language: String) -> String {
        "question_translations_seed.\(language)"
    }

    /// Empty when the build ships none for the language, or the file is
    /// unreadable (English, in effect, never a crash).
    static func load(language: String, bundle: Bundle = .main) -> [QuestionTranslation] {
        guard let url = bundle.url(forResource: resourceName(language), withExtension: "json") else { return [] }
        do {
            return try JSONDecoder().decode([QuestionTranslation].self, from: Data(contentsOf: url))
        } catch {
            log("⚠️ QuestionTranslationSeed: \(language) unreadable — \(error)")
            return []
        }
    }
}

// MARK: - Cache

@MainActor
final class QuestionTranslationCache {

    static let shared = QuestionTranslationCache()

    private let language: () -> String?
    private let sync: QuestionTranslationSyncing
    private let directory: URL?
    private let defaults: UserDefaults
    private let seed: (String) -> [QuestionTranslation]

    /// Translations for `loadedLanguage`, by question ID.
    private(set) var translations: [UUID: QuestionTranslation] = [:]
    private var loadedLanguage: String?

    init(
        language: @escaping () -> String? = { L10n.contentLanguage },
        sync: QuestionTranslationSyncing = SupabaseQuestionTranslationSync(),
        directory: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ),
        defaults: UserDefaults = .standard,
        seed: @escaping (String) -> [QuestionTranslation] = { QuestionTranslationSeed.load(language: $0) }
    ) {
        self.language = language
        self.sync = sync
        self.directory = directory
        self.defaults = defaults
        self.seed = seed
        loadFromDisk()
    }

    // MARK: Read

    /// The questions with this language's cached translations laid over.
    /// In English, and for any question with no translation, the input.
    func apply(to questions: [QuizQuestion]) -> [QuizQuestion] {
        guard language() != nil, loadedLanguage == language(), !translations.isEmpty else { return questions }
        return ContentOverlay.apply(questions.compactMap { translations[$0.id] }, to: questions)
    }

    // MARK: Refresh

    /// Brings the cache up to date for the app's language. Returns true when
    /// the cached translations changed.
    ///
    /// English: returns at once, no request. Otherwise one small request to
    /// compare fingerprints, and a download only when they differ.
    @discardableResult
    func refresh() async -> Bool {
        guard let language = language() else { return false }
        if loadedLanguage != language { loadFromDisk() }

        do {
            let current = try await sync.fingerprint(language: language)
            let cached = defaults.string(forKey: Self.fingerprintKey(language))

            if let current, let cached, current == cached {
                log("✅ QuestionTranslationCache: \(language) current (\(cached)) — no fetch")
                return false
            }

            let rows = try await sync.allTranslations(language: language)

            // A shipped language always has translations, so none means the
            // read failed (typically no session yet: RLS answers `anon` with
            // 200 and no rows). Keep what is cached and store no
            // fingerprint, so the next refresh downloads again.
            guard !rows.isEmpty else {
                log("⚠️ QuestionTranslationCache: \(language) download returned 0 rows — "
                    + "treating as failure, keeping \(translations.count) cached")
                return false
            }

            let fresh = Dictionary(rows.map { ($0.questionId, $0) }, uniquingKeysWith: { first, _ in first })
            let changed = fresh != translations

            translations = fresh
            loadedLanguage = language
            save(rows, language: language)
            // No fingerprint means the count could not be confirmed; leave
            // none stored so the next refresh checks again.
            if let current {
                defaults.set(current, forKey: Self.fingerprintKey(language))
            } else {
                defaults.removeObject(forKey: Self.fingerprintKey(language))
            }

            log("✅ QuestionTranslationCache: synced \(rows.count) \(language) translations")
            return changed
        } catch {
            log("🌍 QuestionTranslationCache: refresh failed for \(language), keeping cache — \(error)")
            return false
        }
    }

    // MARK: Disk

    static func fingerprintKey(_ language: String) -> String {
        "question_translations_synced_fingerprint.\(language)"
    }

    static func fileName(_ language: String) -> String {
        "question_translations.\(language).json"
    }

    /// The downloaded file if there is a readable one, the bundled
    /// translations otherwise.
    private func loadFromDisk() {
        translations = [:]
        loadedLanguage = language()
        guard let language = language() else { return }

        if let url = directory?.appendingPathComponent(Self.fileName(language)),
           let data = try? Data(contentsOf: url) {
            do {
                let rows = try JSONDecoder().decode([QuestionTranslation].self, from: data)
                translations = Self.byID(rows)
                return
            } catch {
                // An unreadable file is the same as no file: the bundled
                // translations, and the missing fingerprint match will
                // fetch it again.
                defaults.removeObject(forKey: Self.fingerprintKey(language))
                log("⚠️ QuestionTranslationCache: \(language) file unreadable, discarding — \(error)")
            }
        }

        translations = Self.byID(seed(language))
    }

    private static func byID(_ rows: [QuestionTranslation]) -> [UUID: QuestionTranslation] {
        Dictionary(rows.map { ($0.questionId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func save(_ rows: [QuestionTranslation], language: String) {
        guard let url = directory?.appendingPathComponent(Self.fileName(language)) else { return }
        do {
            try JSONEncoder().encode(rows).write(to: url, options: .atomic)
        } catch {
            log("⚠️ QuestionTranslationCache: write failed — \(error)")
        }
    }
}
