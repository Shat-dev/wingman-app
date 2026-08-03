//
//  LessonQuestionStore.swift
//  Wingman
//
//  Single source of truth for end-of-lesson quiz questions on the client.
//  - Ships a **bundled seed** so a quiz is never blocked on the network, a
//    session, or a successful sync. Lessons work offline and must keep working
//    offline; a per-lesson fetch would put a network failure directly inside a
//    completion gate, which is the worst place for one. The seed is a
//    cold-start floor only — see `loadQuestions()`.
//  - Fetches the whole set and caches it to disk. Once a real snapshot exists
//    it is authoritative **wholesale**, and the seed is no longer consulted.
//  - Refreshes behind a count + `max(updated_at)` fingerprint, so a launch with
//    no content changes costs one tiny query and no payload. The count is there
//    because a timestamp alone cannot see a delete or an untag; see
//    `LessonQuestionService.fingerprint()`.
//  - Never wipes the cache on a failed refresh (preserves last-known-good) —
//    same rule as StreakStore. "Failed" includes a 200 that returns zero rows,
//    which is what an RLS-filtered read looks like; see `refresh()`.
//

import Foundation
import Combine

@MainActor
final class LessonQuestionStore: ObservableObject {

    static let shared = LessonQuestionStore(service: LessonQuestionService())

    // MARK: - State

    /// lesson_id → its quiz questions, ordered by slot.
    @Published private(set) var questionsByLesson: [String: [QuizQuestion]] = [:]
    @Published private(set) var isRefreshing: Bool = false

    // MARK: - Dependencies

    private let service: LessonQuestionServiceProtocol

    /// True while `questionsByLesson` holds the bundled seed rather than a
    /// synced snapshot. In-memory only — the presence of a non-empty disk
    /// snapshot is the persisted form of the same fact, so no extra
    /// UserDefaults key is needed.
    ///
    /// `refresh()` reads this to decide whether the fingerprint short-circuit is
    /// allowed to skip a fetch. Skipping while running on the seed would strand
    /// an install whose disk snapshot was lost but whose fingerprint survived:
    /// the seed would satisfy "not empty" forever and content edits would stop
    /// arriving.
    private var isRunningOnSeed: Bool = true

    // MARK: - Cache location
    //
    // A file rather than UserDefaults: the full set is ~100 KB today and grows
    // with the content, which is past what belongs in a defaults plist.
    // Not namespaced per user and not cleared on logout — these are global
    // content rows, not user data, so re-downloading them per account would be
    // pure waste. (Lesson *progress* is per-user and is namespaced; see
    // LessonDataService.)

    // Renamed from `lesson_questions_synced_updated_at` when the watermark
    // became a count+timestamp fingerprint. A new key rather than a reused one
    // so an upgrading install reads nil, fails the equality check, and re-syncs
    // exactly once instead of comparing a bare timestamp against the new format
    // forever. The old key is left orphaned; it is a single short string.
    private static let fingerprintKey = "lesson_questions_synced_fingerprint"

    /// Stand-in written when a sync succeeded but its fingerprint could not be
    /// computed. Deliberately not of the form `count:timestamp`, so it can never
    /// compare equal to a real one and always forces a re-fetch.
    private static let unverifiedFingerprint = "unverified"

    private var cacheURL: URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return dir.appendingPathComponent("lesson_questions.json")
    }

    /// The seed that ships in the app bundle. Regenerated per release by
    /// `supabase/scripts/generate_lesson_question_seed.sh`; see that script for
    /// why it is a release chore rather than a gate on editing content.
    private static let seedResourceName = "lesson_questions_seed"

    /// The service is injected rather than constructed inline so a test can
    /// drive the store against a stub.
    ///
    /// Note it is **not** a defaulted parameter. The project builds with
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so an unannotated type like
    /// `LessonQuestionService` is implicitly main-actor isolated — and default
    /// argument expressions are evaluated in a *nonisolated* context, which
    /// makes `= LessonQuestionService()` a cross-actor call. Passing it from
    /// `shared` (itself main-actor isolated) keeps the call inside the actor.
    /// `StreakStore` avoids the same trap by initialising its service as a
    /// stored property.
    init(service: LessonQuestionServiceProtocol) {
        self.service = service
        loadQuestions()
    }

    // MARK: - Read

    /// The quiz for a lesson, ordered by slot. Empty when neither the synced
    /// snapshot nor the bundled seed knows about the lesson — in practice a
    /// lesson added after the seed was last regenerated, on an install that has
    /// not synced yet. Callers must treat empty as "no quiz" and let the lesson
    /// complete as it always has.
    func questions(forLessonId lessonId: String) -> [QuizQuestion] {
        questionsByLesson[lessonId] ?? []
    }

    // MARK: - Refresh

    /// Pull the full set if the server has anything newer than the last sync.
    ///
    /// Call after a session exists — RLS on `questions` requires the
    /// `authenticated` role, so running this before auth bootstrap would 401 on
    /// cold start. It is hooked alongside `hydrateLessonProgressFromCloud()` in
    /// AuthManager for exactly that reason.
    func refresh() async {
        guard SupabaseManager.shared.currentUserId != nil else {
            log("ℹ️ LessonQuestionStore: no session yet — skipping refresh")
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            // Fingerprint check: one row, no payload, on the common path.
            // Compared for equality rather than ordering — any change at all
            // (including a question being edited backwards, deleted, or
            // untagged) means re-fetch.
            let current = try await service.fingerprint()
            let cached = UserDefaults.standard.string(forKey: Self.fingerprintKey)

            // `!isRunningOnSeed` rather than `!questionsByLesson.isEmpty`: the
            // seed makes the map non-empty from launch, so the old emptiness
            // test would let a stale fingerprint skip the fetch forever on an
            // install whose snapshot was lost. Only a real snapshot may be
            // trusted to match a fingerprint.
            if let current, let cached, current == cached, !isRunningOnSeed {
                log("✅ LessonQuestionStore: cache current (fingerprint \(cached)) — no fetch")
                return
            }

            let rows = try await service.fetchAllLessonQuestions()

            // An empty result is a failure, not a content state, and it does not
            // throw — so the catch below would never see it.
            //
            // RLS on `questions` grants SELECT to `authenticated` only. When
            // supabase-swift cannot mint an access token (expired refresh token,
            // a blip during rotation) `SupabaseClient.adapt(request:)` swallows
            // it with `try?` and leaves the default `Bearer <publishable key>`
            // header in place. The request then runs as `anon`, RLS filters
            // every row, and PostgREST answers 200 with `[]`. Writing that
            // through would replace a good cache with `{}` on disk — the exact
            // outcome the last-known-good rule at the top of this file exists to
            // prevent. There is no legitimate zero-row state: the feature cannot
            // function without questions, so zero always means the read failed.
            guard !rows.isEmpty else {
                log("⚠️ LessonQuestionStore: fetch returned 0 rows — treating as "
                    + "failure, keeping cache (\(questionsByLesson.count) lessons)")
                return
            }

            let grouped = Dictionary(grouping: rows, by: { $0.lessonId })
                .mapValues { rows in
                    rows.sorted { $0.lessonQuizOrder < $1.lessonQuizOrder }
                        .map(\.asQuizQuestion)
                }

            // Assigned wholesale, never merged with the seed. A merge would make
            // deletion un-expressible: emptying a lesson's questions in Supabase
            // leaves it absent from `grouped`, and a per-lesson fallback would
            // resurrect the seed's copy — a lesson that could not be turned off
            // from the backend. Wholesale assignment is what keeps Supabase
            // authoritative for adds, edits *and* removals.
            questionsByLesson = grouped
            isRunningOnSeed = false
            saveToCache(grouped)

            // Always written, so `loadQuestions()` can read "key present" as
            // "this snapshot was written by a version that syncs the whole set".
            // When the fingerprint could not be computed, a sentinel stands in:
            // it can never equal a real `count:timestamp`, so the next launch
            // re-fetches rather than trusting an unverified snapshot.
            UserDefaults.standard.set(
                current ?? Self.unverifiedFingerprint,
                forKey: Self.fingerprintKey
            )

            log("✅ LessonQuestionStore: synced \(rows.count) questions across \(grouped.count) lessons")

        } catch {
            // Preserve last-known-good. A store that empties itself on a flaky
            // network would silently disable the quiz for someone it worked for
            // yesterday.
            log("❌ LessonQuestionStore: refresh failed, keeping cache — \(error.localizedDescription)")
        }
    }

    // MARK: - Cache I/O

    /// Snapshot if there is a trustworthy one, bundled seed otherwise.
    /// Deliberately **not** a merge of the two — see the assignment in
    /// `refresh()` for why.
    ///
    /// "Trustworthy" means non-empty **and** accompanied by a fingerprint under
    /// the current key. Both halves are load-bearing:
    ///
    ///   - Non-empty, because an empty snapshot means the sync never landed.
    ///     The empty-fetch guard in `refresh()` is what makes that inference
    ///     safe: an empty snapshot can never be written, so empty always means
    ///     "never synced" and never "the backend is empty".
    ///   - Fingerprint present, because a snapshot without one predates this
    ///     version and is of unknown completeness. Devices that synced while the
    ///     question set was still being authored hold a *partial* snapshot — one
    ///     real device here has a single lesson in it. Non-empty alone would
    ///     trust that and shadow a 94-lesson seed, leaving 93 lessons with no
    ///     quiz until a sync landed, and forever if the device has no session.
    ///     Preferring the seed costs one re-fetch and cannot lose content.
    ///
    /// `refresh()` upholds the second half by always writing the key on a
    /// successful sync, so "snapshot ⇒ fingerprint" holds for anything this
    /// version writes.
    private func loadQuestions() {
        let hasCurrentFormatFingerprint =
            UserDefaults.standard.string(forKey: Self.fingerprintKey) != nil

        if hasCurrentFormatFingerprint, let snapshot = loadDiskSnapshot(), !snapshot.isEmpty {
            questionsByLesson = snapshot
            isRunningOnSeed = false
            log("📦 LessonQuestionStore: loaded \(snapshot.count) lessons from synced snapshot")
            return
        }

        let seed = loadBundledSeed()
        questionsByLesson = seed
        isRunningOnSeed = true
        log("🌱 LessonQuestionStore: running on bundled seed (\(seed.count) lessons) — "
            + "no trustworthy snapshot yet")
    }

    /// Returns nil when there is no readable snapshot. A snapshot written by an
    /// older shape is not worth crashing over — nil drops it, the seed covers
    /// the gap, and the next refresh repopulates.
    private func loadDiskSnapshot() -> [String: [QuizQuestion]]? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        do {
            return try JSONDecoder().decode([String: [QuizQuestion]].self, from: data)
        } catch {
            log("⚠️ LessonQuestionStore: snapshot unreadable, discarding — \(error.localizedDescription)")
            return nil
        }
    }

    /// The seed is written by `generate_lesson_question_seed.sh` in exactly the
    /// shape `saveToCache` writes, so both go through the same decode.
    ///
    /// A missing or unreadable seed is survivable, not fatal: the store simply
    /// starts empty and behaves as it did before the seed existed. It is still
    /// worth shouting about, because it means a release was cut without the
    /// resource and every fresh install is back to needing a successful sync
    /// before any quiz appears.
    private func loadBundledSeed() -> [String: [QuizQuestion]] {
        guard let url = Bundle.main.url(forResource: Self.seedResourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            log("❌ LessonQuestionStore: bundled seed MISSING — fresh installs have no quiz until they sync")
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: [QuizQuestion]].self, from: data)
        } catch {
            log("❌ LessonQuestionStore: bundled seed unreadable — \(error.localizedDescription)")
            return [:]
        }
    }

    private func saveToCache(_ value: [String: [QuizQuestion]]) {
        guard let url = cacheURL else { return }
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            log("⚠️ LessonQuestionStore: cache write failed — \(error.localizedDescription)")
        }
    }
}
