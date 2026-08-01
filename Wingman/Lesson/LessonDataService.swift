//
//  LessonDataService.swift
//  Wingman
//

import Foundation
import Supabase

// MARK: - Notification Names
extension Notification.Name {
    /// Posted when a lesson is marked completed. Observers that derive state
    /// from lesson progress (e.g. CoursesViewModel's course-lock derivation)
    /// listen for this to invalidate their computed view state.
    static let lessonCompleted = Notification.Name("lessonCompleted")

    /// Posted after lesson progress is hydrated from Supabase `user_metadata`.
    /// Views that render course unlock state can listen and refresh.
    static let lessonProgressHydrated = Notification.Name("lessonProgressHydrated")
}

final class LessonDataService {
    
    // MARK: - Singleton
    static let shared = LessonDataService()
    
    private init() {}
    
    // MARK: - Cache
    private var lessonsCache: [String: [Lesson]] = [:]
    
    // MARK: - Course ID to JSON filename mapping
    // Maps courseId to JSON filename (without .json extension)
    // Format: {category}_{course_name}
    private let courseJsonMapping: [String: String] = [
        // Mindset & Foundations (cat_1)
        "course_1": "1_1_mindset_foundations_beliefs_reframes",
        "course_2": "2_1_mindset_foundations_fear_exposure",
        "course_3": "3_1_mindset_foundations_presence_expression",
        "course_4": "4_1_mindset_foundations_inner_stability",
        "course_5": "5_1_mindset_foundations_non-negotiables",

        // Approach Mechanics (cat_2)
        "course_6": "1_2_approach_mechanics_approach_readiness",
        "course_7": "2_2_approach_mechanics_the_physical_approach",
        "course_8": "3_2_approach_mechanics_the_opener",
        "course_9": "4_2_approach_mechanics_reading_responding",
        "course_10": "5_2_approach_mechanics_situational_specific_approaches",
        "course_11": "6_2_approach_mechanics_advanced_opening_techniques",

        // Conversation Flow (cat_3)
        "course_12": "1_3_conversational_flow_small_talk_momentum",
        "course_13": "2_3_conversational_flow_listening_attunement",
        "course_14": "3_3_conversational_flow_sharing_vulnerability",
        "course_15": "4_3_conversational_flow_closing",
        "course_16": "5_3_conversational_flow_advanced_conversational_skills",

        // Flirting & Chemistry (cat_4)
        "course_17": "1_4_flirting_chemistry_flirting_prerequisites",
        "course_18": "2_4_flirting_chemistry_playfulness_spark",
        "course_19": "3_4_flirting_chemistry_compliments_verbal_chemistry",
        "course_20": "4_4_flirting_chemistry_physical_presence_escalation",
        "course_21": "5_4_flirting_chemistry_advanced_flirting_skills",

        // Integration & Mastery (cat_5)
        "course_22": "1_5_integration_mastery_upgrading_lifestyle",
        "course_23": "2_5_integration_mastery_creating_opportunities",
        "course_24": "3_5_integration_mastery_mastery_identity",
        "course_25": "4_5_integration_mastery_learning_self-discovery"
    ]
    
    // MARK: - Load Lessons for a Course
    func loadLessonsForCourse(courseId: String) -> [Lesson] {
        // Check cache first
        if let cached = lessonsCache[courseId] {
            log("📚 Returning cached lessons for course: \(courseId)")
            return cached
        }
        
        // Get JSON filename for this course
        guard let jsonFilename = courseJsonMapping[courseId] else {
            log("⚠️ No JSON mapping found for course: \(courseId)")
            log("💡 Add '\(courseId)' to courseJsonMapping in LessonDataService")
            return []
        }
        
        // Load from JSON file
        guard let url = Bundle.main.url(forResource: jsonFilename, withExtension: "json") else {
            log("❌ Could not find \(jsonFilename).json in bundle")
            log("💡 Make sure \(jsonFilename).json exists and is added to the project")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var lessons = try decoder.decode([Lesson].self, from: data)
            
            // Sort by lesson number
            lessons.sort { $0.lessonNumber < $1.lessonNumber }
            
            // Apply saved progress
            let progress = loadLessonProgress(courseId: courseId)
            for i in 0..<lessons.count {
                if progress.completed.contains(lessons[i].id) {
                    lessons[i].isCompleted = true
                }
                if progress.unlocked.contains(lessons[i].id) {
                    lessons[i].isLocked = false
                }
            }
            
            // Cache the results
            lessonsCache[courseId] = lessons
            
            log("✅ Loaded \(lessons.count) lessons for course: \(courseId) from \(jsonFilename).json")
            return lessons
            
        } catch {
            log("❌ Error loading lessons from \(jsonFilename).json: \(error)")
            if let decodingError = error as? DecodingError {
                log("📋 Decoding error details: \(decodingError)")
            }
            return []
        }
    }
    
    // MARK: - Get Single Lesson
    func getLesson(lessonId: String, courseId: String) -> Lesson? {
        let lessons = loadLessonsForCourse(courseId: courseId)
        return lessons.first { $0.id == lessonId }
    }
    
    // MARK: - Get Next Lesson
    func getNextLesson(after currentLesson: Lesson) -> Lesson? {
        let lessons = loadLessonsForCourse(courseId: currentLesson.courseId)
        guard let currentIndex = lessons.firstIndex(where: { $0.id == currentLesson.id }) else {
            return nil
        }
        
        let nextIndex = currentIndex + 1
        guard nextIndex < lessons.count else {
            return nil // No more lessons
        }
        
        return lessons[nextIndex]
    }
    
    // MARK: - Mark Lesson as Completed
    func markLessonCompleted(lessonId: String, courseId: String) {
        guard var lessons = lessonsCache[courseId] else { return }
        
        if let index = lessons.firstIndex(where: { $0.id == lessonId }) {
            lessons[index].isCompleted = true
            
            // Unlock next lesson
            let nextIndex = index + 1
            if nextIndex < lessons.count {
                lessons[nextIndex].isLocked = false
            }
            
            lessonsCache[courseId] = lessons

            // Persist to UserDefaults (local, fast)
            saveLessonProgress(courseId: courseId, lessons: lessons)

            // Fire-and-forget sync to Supabase user_metadata so progress
            // survives uninstall / device change. Non-blocking; if the
            // network call fails the local state is still correct and the
            // next successful sync (on the next lesson completion or next
            // session hydration merge) will catch the cloud up.
            syncLessonProgressToCloud()

            // Notify observers (e.g. CoursesViewModel) that derived state
            // such as course-level unlock may need to refresh.
            NotificationCenter.default.post(name: .lessonCompleted, object: nil)

            log("✅ Marked lesson \(lessonId) as completed")
            if nextIndex < lessons.count {
                log("🔓 Unlocked next lesson: \(lessons[nextIndex].id)")
            }
        }
    }

    // MARK: - Course-level completion check
    /// Returns true iff the course has at least one lesson and every lesson
    /// in it is marked completed. Used by CoursesViewModel to derive the
    /// progression-unlock state of the next course in the same category.
    func isCourseCompleted(courseId: String) -> Bool {
        let lessons = loadLessonsForCourse(courseId: courseId)
        guard !lessons.isEmpty else { return false }
        return lessons.allSatisfy { $0.isCompleted }
    }

    // MARK: - Total lessons completed (across all courses)
    /// Sum of completed lesson counts across every known course. Used by
    /// PracticeService.fetchPractices to gate scenario unlocks on cumulative
    /// lesson progress.
    /// How many lessons the app actually ships, counted from the bundled JSON.
    ///
    /// Deliberately NOT `sum(Course.lessonsCount)` from `CourseCategory`. Those
    /// literals currently total 171 against 94 real lessons, so quoting them
    /// anywhere user-facing would overstate the catalogue by ~80%. This reads
    /// the same files the app serves, so it cannot disagree with what the user
    /// can open.
    ///
    /// Loads and parses every course, so it is not free — call it off the
    /// critical render path. It populates `lessonsCache` on the way through,
    /// which the Courses tab then reuses.
    func totalLessonCount() -> Int {
        courseJsonMapping.keys.reduce(0) { total, courseId in
            total + loadLessonsForCourse(courseId: courseId).count
        }
    }

    func totalLessonsCompleted() -> Int {
        courseJsonMapping.keys.reduce(0) { total, courseId in
            total + loadLessonProgress(courseId: courseId).completed.count
        }
    }

    // MARK: - Persistence (UserDefaults, namespaced per-user)
    //
    // Keys are namespaced by the current Supabase user ID so different users
    // on the same device don't leak lesson progress into each other. When
    // no user is authenticated (anonymous flow) we fall back to an
    // "anonymous" namespace.

    /// Namespace segment for UserDefaults keys — current Supabase user ID or "anonymous".
    private var userNamespace: String {
        return SupabaseManager.shared.currentUserId ?? "anonymous"
    }

    private func completedKey(courseId: String) -> String {
        return "completed_lessons_\(userNamespace)_\(courseId)"
    }

    private func unlockedKey(courseId: String) -> String {
        return "unlocked_lessons_\(userNamespace)_\(courseId)"
    }

    private func saveLessonProgress(courseId: String, lessons: [Lesson]) {
        let completedIds = lessons.filter { $0.isCompleted }.map { $0.id }
        let unlockedIds = lessons.filter { !$0.isLocked }.map { $0.id }

        UserDefaults.standard.set(completedIds, forKey: completedKey(courseId: courseId))
        UserDefaults.standard.set(unlockedIds, forKey: unlockedKey(courseId: courseId))
    }

    func loadLessonProgress(courseId: String) -> (completed: [String], unlocked: [String]) {
        let completed = UserDefaults.standard.stringArray(forKey: completedKey(courseId: courseId)) ?? []
        let unlocked = UserDefaults.standard.stringArray(forKey: unlockedKey(courseId: courseId)) ?? []
        return (completed, unlocked)
    }

    // MARK: - Cloud Sync via Supabase user_metadata
    //
    // Lesson progress is mirrored into the user's `raw_user_meta_data` under
    // a `lesson_progress` key so it survives uninstall / device change.
    // Shape:
    //   {
    //     "course_1": { "completed": ["lesson_1_1", ...], "unlocked": [...] },
    //     "course_2": { ... }
    //   }
    // We always write the FULL state (not deltas) so concurrent writes
    // converge under last-write-wins semantics.

    /// Builds the current full lesson_progress dictionary from local state.
    private func buildLessonProgressDict() -> [String: [String: [String]]] {
        var progress: [String: [String: [String]]] = [:]
        for courseId in courseJsonMapping.keys {
            let (completed, unlocked) = loadLessonProgress(courseId: courseId)
            if !completed.isEmpty || !unlocked.isEmpty {
                progress[courseId] = [
                    "completed": completed,
                    "unlocked": unlocked
                ]
            }
        }
        return progress
    }

    /// Converts a Swift progress dictionary into an `AnyJSON` value.
    private func anyJSONForProgress(_ dict: [String: [String: [String]]]) -> AnyJSON {
        var coursesObj: [String: AnyJSON] = [:]
        for (courseId, lists) in dict {
            var courseObj: [String: AnyJSON] = [:]
            for (listKey, ids) in lists {
                courseObj[listKey] = AnyJSON.array(ids.map { AnyJSON.string($0) })
            }
            coursesObj[courseId] = AnyJSON.object(courseObj)
        }
        return AnyJSON.object(coursesObj)
    }

    /// Fire-and-forget: push the full local lesson progress state to
    /// Supabase `user_metadata`. No-op if unauthenticated.
    func syncLessonProgressToCloud() {
        guard SupabaseManager.shared.currentUserId != nil else {
            return
        }

        let progress = buildLessonProgressDict()
        let payload = anyJSONForProgress(progress)

        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(data: [
                        "lesson_progress": payload
                    ])
                )
                log("☁️ Lesson progress synced to cloud (\(progress.keys.count) courses)")
            } catch {
                log("⚠️ Lesson progress sync failed (will retry on next completion): \(error.localizedDescription)")
            }
        }
    }

    /// Reads `lesson_progress` from Supabase `user_metadata` and merges it
    /// with local UserDefaults state (union). Writes the merged state back
    /// to cloud so any offline-only local progress is preserved server-side.
    /// Called from AuthManager after `.signedIn` and `.initialSession`.
    func hydrateLessonProgressFromCloud() async {
        guard let user = SupabaseManager.shared.client.auth.currentUser else {
            log("ℹ️ hydrateLessonProgressFromCloud: no current user — skipping")
            return
        }

        // Parse cloud state, if present.
        var cloudProgress: [String: [String: [String]]] = [:]
        if let progressObj = user.userMetadata["lesson_progress"]?.objectValue {
            for (courseId, courseValue) in progressObj {
                guard let courseObj = courseValue.objectValue else { continue }
                var lists: [String: [String]] = [:]
                if let completedArr = courseObj["completed"]?.arrayValue {
                    lists["completed"] = completedArr.compactMap { $0.stringValue }
                }
                if let unlockedArr = courseObj["unlocked"]?.arrayValue {
                    lists["unlocked"] = unlockedArr.compactMap { $0.stringValue }
                }
                cloudProgress[courseId] = lists
            }
            log("☁️ Cloud lesson progress found: \(cloudProgress.keys.count) courses")
        } else {
            log("ℹ️ No cloud lesson progress yet — may be first sync for this user")
        }

        // Merge cloud into local (union of sets).
        for courseId in courseJsonMapping.keys {
            let localCompleted = Set(UserDefaults.standard.stringArray(forKey: completedKey(courseId: courseId)) ?? [])
            let localUnlocked = Set(UserDefaults.standard.stringArray(forKey: unlockedKey(courseId: courseId)) ?? [])

            let cloudCompleted = Set(cloudProgress[courseId]?["completed"] ?? [])
            let cloudUnlocked = Set(cloudProgress[courseId]?["unlocked"] ?? [])

            let mergedCompleted = Array(localCompleted.union(cloudCompleted))
            let mergedUnlocked = Array(localUnlocked.union(cloudUnlocked))

            if !mergedCompleted.isEmpty || !mergedUnlocked.isEmpty {
                UserDefaults.standard.set(mergedCompleted, forKey: completedKey(courseId: courseId))
                UserDefaults.standard.set(mergedUnlocked, forKey: unlockedKey(courseId: courseId))
            }
        }

        // Invalidate the lesson cache so the next loadLessonsForCourse picks
        // up the freshly-merged UserDefaults state.
        lessonsCache.removeAll()
        log("🔄 Lesson cache invalidated after hydration")

        // Push merged state back to cloud (captures any local-only offline progress).
        syncLessonProgressToCloud()

        // Notify views to refresh derived state (course unlock, continue card).
        await MainActor.run {
            NotificationCenter.default.post(name: .lessonProgressHydrated, object: nil)
            NotificationCenter.default.post(name: .lessonCompleted, object: nil)
        }
    }

    // MARK: - Clear Cache
    func clearCache() {
        lessonsCache.removeAll()
        log("🗑️ Cleared all lessons cache")
    }
}
