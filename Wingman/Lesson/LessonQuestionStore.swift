//
//  LessonQuestionStore.swift
//  Wingman
//
//  Single source of truth for end-of-lesson quiz questions on the client.
//  - Fetches the whole set once and caches it to disk, so a quiz never waits on
//    the network. Lessons work offline today and must keep working offline; a
//    per-lesson fetch would put a network failure directly inside a completion
//    gate, which is the worst place for one.
//  - Refreshes behind a `max(updated_at)` watermark, so a launch with no
//    content changes costs one tiny query and no payload.
//  - Never wipes the cache on a failed refresh (preserves last-known-good) —
//    same rule as StreakStore.
//

import Foundation
import Combine

@MainActor
final class LessonQuestionStore: ObservableObject {

    static let shared = LessonQuestionStore()

    // MARK: - State

    /// lesson_id → its quiz questions, ordered by slot.
    @Published private(set) var questionsByLesson: [String: [QuizQuestion]] = [:]
    @Published private(set) var isRefreshing: Bool = false

    // MARK: - Dependencies

    private let service: LessonQuestionServiceProtocol

    // MARK: - Cache location
    //
    // A file rather than UserDefaults: the full set is ~100 KB today and grows
    // with the content, which is past what belongs in a defaults plist.
    // Not namespaced per user and not cleared on logout — these are global
    // content rows, not user data, so re-downloading them per account would be
    // pure waste. (Lesson *progress* is per-user and is namespaced; see
    // LessonDataService.)

    private static let watermarkKey = "lesson_questions_synced_updated_at"

    private var cacheURL: URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return dir.appendingPathComponent("lesson_questions.json")
    }

    private init(service: LessonQuestionServiceProtocol = LessonQuestionService()) {
        self.service = service
        loadFromCache()
    }

    // MARK: - Read

    /// The quiz for a lesson, ordered by slot. Empty when nothing is cached for
    /// it — un-authored content, or a cold cache on a fresh offline install.
    /// Callers must treat empty as "no quiz" and let the lesson complete as it
    /// always has.
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
            // Watermark check: one row, no payload, on the common path.
            // Compared for equality rather than ordering — any change at all
            // (including a question being edited backwards) means re-fetch.
            let latest = try await service.latestUpdatedAt()
            let cached = UserDefaults.standard.string(forKey: Self.watermarkKey)

            if let latest, let cached, latest == cached, !questionsByLesson.isEmpty {
                log("✅ LessonQuestionStore: cache current (watermark \(cached)) — no fetch")
                return
            }

            let rows = try await service.fetchAllLessonQuestions()
            let grouped = Dictionary(grouping: rows, by: { $0.lessonId })
                .mapValues { rows in
                    rows.sorted { $0.lessonQuizOrder < $1.lessonQuizOrder }
                        .map(\.asQuizQuestion)
                }

            questionsByLesson = grouped
            saveToCache(grouped)
            if let latest {
                UserDefaults.standard.set(latest, forKey: Self.watermarkKey)
            }

            log("✅ LessonQuestionStore: synced \(rows.count) questions across \(grouped.count) lessons")

        } catch {
            // Preserve last-known-good. A store that empties itself on a flaky
            // network would silently disable the quiz for someone it worked for
            // yesterday.
            log("❌ LessonQuestionStore: refresh failed, keeping cache — \(error.localizedDescription)")
        }
    }

    // MARK: - Cache I/O

    private func loadFromCache() {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else {
            log("📦 LessonQuestionStore: no cache on disk yet")
            return
        }

        do {
            questionsByLesson = try JSONDecoder().decode([String: [QuizQuestion]].self, from: data)
            log("📦 LessonQuestionStore: seeded \(questionsByLesson.count) lessons from cache")
        } catch {
            // A cache written by an older shape is not worth crashing over —
            // drop it and let the next refresh repopulate.
            log("⚠️ LessonQuestionStore: cache unreadable, discarding — \(error.localizedDescription)")
            questionsByLesson = [:]
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
