//
//  QuestionTranslationCacheTests.swift
//  WingmanTests
//
//  WP7 of the localization plan, fourth slice: translated lesson-quiz
//  questions and their on-device cache.
//
//  The English question snapshot is not touched by any of this. These tests
//  cover the second, per-language file beside it: English reads nothing and
//  requests nothing; a matching fingerprint costs one request and no
//  download; a failed refresh keeps what is cached; languages never share a
//  file.
//

import XCTest
@testable import Wingman

@MainActor
final class QuestionTranslationCacheTests: XCTestCase {

    // MARK: - A sync that counts

    private final class CountingSync: QuestionTranslationSyncing {
        struct Failure: Error {}

        var requests: [String] = []
        var fingerprintValue: String? = "1:2026-11-10T00:00:00Z"
        var rows: [QuestionTranslation] = []
        var fails = false

        func fingerprint(language: String) async throws -> String? {
            requests.append("fingerprint \(language)")
            if fails { throw Failure() }
            return fingerprintValue
        }

        func allTranslations(language: String) async throws -> [QuestionTranslation] {
            requests.append("download \(language)")
            if fails { throw Failure() }
            return rows
        }
    }

    // MARK: - Fixtures

    private var directory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("translation-cache-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "translation-cache-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

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

    private var german: [QuestionTranslation] {
        [QuestionTranslation(questionId: firstID, questionText: "Was sagst du zuerst?", options: ["Hi", "Nichts"], explanation: nil)]
    }

    private func cache(language: String?, sync: CountingSync) -> QuestionTranslationCache {
        QuestionTranslationCache(language: { language }, sync: sync, directory: directory, defaults: defaults)
    }

    private func files() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
    }

    // MARK: - English

    func testEnglishReadsNothingRequestsNothingAndPassesQuestionsThrough() async {
        let sync = CountingSync()
        sync.rows = german
        let english = cache(language: nil, sync: sync)

        let changed = await english.refresh()

        XCTAssertFalse(changed)
        XCTAssertEqual(sync.requests, [], "an English app must not touch the translation table")
        XCTAssertEqual(files(), [], "and must not write a translation file")
        XCTAssertEqual(english.apply(to: questions).map(\.question), questions.map(\.question))
    }

    /// A translation file left by another language is not read in English.
    func testEnglishIgnoresAnotherLanguagesFile() async {
        let sync = CountingSync()
        sync.rows = german
        _ = await cache(language: "de", sync: sync).refresh()
        XCTAssertEqual(files(), ["question_translations.de.json"])

        let english = cache(language: nil, sync: CountingSync())
        XCTAssertEqual(english.apply(to: questions).map(\.question), questions.map(\.question))
    }

    // MARK: - First sync

    func testFirstRefreshDownloadsStoresAndApplies() async {
        let sync = CountingSync()
        sync.rows = german
        let cache = cache(language: "de", sync: sync)

        XCTAssertEqual(cache.apply(to: questions).map(\.question), questions.map(\.question), "English before any sync")

        let changed = await cache.refresh()

        XCTAssertTrue(changed)
        XCTAssertEqual(sync.requests, ["fingerprint de", "download de"])
        XCTAssertEqual(files(), ["question_translations.de.json"])
        XCTAssertEqual(defaults.string(forKey: QuestionTranslationCache.fingerprintKey("de")), "1:2026-11-10T00:00:00Z")

        let result = cache.apply(to: questions)
        XCTAssertEqual(result[0].question, "Was sagst du zuerst?")
        XCTAssertEqual(result[0].options, ["Hi", "Nichts"])
        XCTAssertEqual(result[0].explanation, "Simple works.", "untranslated field stays English")
        XCTAssertEqual(result[0].correctAnswerIndex, 0)
        XCTAssertEqual(result[1].question, "And then?", "untranslated question stays English")
    }

    // MARK: - A current cache costs one request

    func testAMatchingFingerprintMeansNoDownload() async {
        let sync = CountingSync()
        sync.rows = german
        let cache = cache(language: "de", sync: sync)
        _ = await cache.refresh()
        sync.requests = []

        let changed = await cache.refresh()

        XCTAssertFalse(changed)
        XCTAssertEqual(sync.requests, ["fingerprint de"])
    }

    func testAChangedFingerprintDownloadsAgain() async {
        let sync = CountingSync()
        sync.rows = german
        let cache = cache(language: "de", sync: sync)
        _ = await cache.refresh()

        sync.requests = []
        sync.fingerprintValue = "2:2026-11-11T00:00:00Z"
        sync.rows = german + [QuestionTranslation(questionId: secondID, questionText: "Und dann?", options: nil, explanation: nil)]

        let changed = await cache.refresh()

        XCTAssertTrue(changed)
        XCTAssertEqual(sync.requests, ["fingerprint de", "download de"])
        XCTAssertEqual(cache.apply(to: questions).map(\.question), ["Was sagst du zuerst?", "Und dann?"])
    }

    /// With no confirmed fingerprint the cache is not trusted next time.
    func testAnUnconfirmedFingerprintIsNotStored() async {
        let sync = CountingSync()
        sync.rows = german
        sync.fingerprintValue = nil
        let cache = cache(language: "de", sync: sync)

        _ = await cache.refresh()
        XCTAssertNil(defaults.string(forKey: QuestionTranslationCache.fingerprintKey("de")))

        sync.requests = []
        _ = await cache.refresh()
        XCTAssertEqual(sync.requests, ["fingerprint de", "download de"], "checked and downloaded again")
    }

    // MARK: - Survives a relaunch and a failure

    func testTranslationsAreReadBackFromDiskOnTheNextLaunch() async {
        let sync = CountingSync()
        sync.rows = german
        _ = await cache(language: "de", sync: sync).refresh()

        // A new cache, as after a relaunch, with a sync that is never used.
        let offline = CountingSync()
        let relaunched = cache(language: "de", sync: offline)
        XCTAssertEqual(relaunched.apply(to: questions)[0].question, "Was sagst du zuerst?")
        XCTAssertEqual(offline.requests, [])
    }

    func testAFailedRefreshKeepsTheCachedTranslations() async {
        let sync = CountingSync()
        sync.rows = german
        let cache = cache(language: "de", sync: sync)
        _ = await cache.refresh()

        sync.fails = true
        let changed = await cache.refresh()

        XCTAssertFalse(changed)
        XCTAssertEqual(cache.apply(to: questions)[0].question, "Was sagst du zuerst?")
        XCTAssertEqual(defaults.string(forKey: QuestionTranslationCache.fingerprintKey("de")), "1:2026-11-10T00:00:00Z")
    }

    func testAFailedFirstRefreshShowsEnglish() async {
        let sync = CountingSync()
        sync.fails = true
        let cache = cache(language: "de", sync: sync)

        _ = await cache.refresh()

        XCTAssertEqual(cache.apply(to: questions).map(\.question), questions.map(\.question))
        XCTAssertEqual(files(), [])
    }

    func testAnUnreadableFileIsDiscardedAndFetchedAgain() async throws {
        try Data("not json".utf8).write(to: directory.appendingPathComponent(QuestionTranslationCache.fileName("de")))
        defaults.set("1:2026-11-10T00:00:00Z", forKey: QuestionTranslationCache.fingerprintKey("de"))

        let sync = CountingSync()
        sync.rows = german
        let cache = cache(language: "de", sync: sync)
        XCTAssertEqual(cache.apply(to: questions).map(\.question), questions.map(\.question), "English until it syncs")

        _ = await cache.refresh()
        XCTAssertEqual(sync.requests, ["fingerprint de", "download de"], "the stale fingerprint was dropped with the file")
        XCTAssertEqual(cache.apply(to: questions)[0].question, "Was sagst du zuerst?")
    }

    // MARK: - Languages are separate

    func testEachLanguageHasItsOwnFileAndFingerprint() async {
        let germanSync = CountingSync()
        germanSync.rows = german
        _ = await cache(language: "de", sync: germanSync).refresh()

        let swedishSync = CountingSync()
        swedishSync.fingerprintValue = "1:2026-11-12T00:00:00Z"
        swedishSync.rows = [QuestionTranslation(questionId: firstID, questionText: "Vad säger du först?", options: nil, explanation: nil)]
        let swedish = cache(language: "sv", sync: swedishSync)
        XCTAssertEqual(swedish.apply(to: questions)[0].question, "What do you say first?", "German is not shown to a Swedish app")

        _ = await swedish.refresh()

        XCTAssertEqual(swedishSync.requests, ["fingerprint sv", "download sv"], "German's fingerprint does not count for Swedish")
        XCTAssertEqual(files(), ["question_translations.de.json", "question_translations.sv.json"])
        XCTAssertEqual(swedish.apply(to: questions)[0].question, "Vad säger du först?")
        XCTAssertEqual(defaults.string(forKey: QuestionTranslationCache.fingerprintKey("de")), "1:2026-11-10T00:00:00Z")
        XCTAssertEqual(defaults.string(forKey: QuestionTranslationCache.fingerprintKey("sv")), "1:2026-11-12T00:00:00Z")
    }

    // MARK: - The English snapshot's own files are not this cache's

    func testFileAndKeyNamesDoNotCollideWithTheEnglishSnapshot() {
        XCTAssertNotEqual(QuestionTranslationCache.fileName("de"), "lesson_questions.json")
        XCTAssertNotEqual(QuestionTranslationCache.fingerprintKey("de"), "lesson_questions_synced_fingerprint")
        XCTAssertTrue(QuestionTranslationCache.fileName("de").contains("de"))
        XCTAssertTrue(QuestionTranslationCache.fingerprintKey("pt-br").hasSuffix("pt-br"))
    }
}
