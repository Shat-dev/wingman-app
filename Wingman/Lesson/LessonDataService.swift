//
//  LessonDataService.swift
//  Wingman
//

import Foundation

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
            print("📚 Returning cached lessons for course: \(courseId)")
            return cached
        }
        
        // Get JSON filename for this course
        guard let jsonFilename = courseJsonMapping[courseId] else {
            print("⚠️ No JSON mapping found for course: \(courseId)")
            print("💡 Add '\(courseId)' to courseJsonMapping in LessonDataService")
            return []
        }
        
        // Load from JSON file
        guard let url = Bundle.main.url(forResource: jsonFilename, withExtension: "json") else {
            print("❌ Could not find \(jsonFilename).json in bundle")
            print("💡 Make sure \(jsonFilename).json exists and is added to the project")
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
            
            print("✅ Loaded \(lessons.count) lessons for course: \(courseId) from \(jsonFilename).json")
            return lessons
            
        } catch {
            print("❌ Error loading lessons from \(jsonFilename).json: \(error)")
            if let decodingError = error as? DecodingError {
                print("📋 Decoding error details: \(decodingError)")
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
            
            // Persist to UserDefaults
            saveLessonProgress(courseId: courseId, lessons: lessons)
            
            print("✅ Marked lesson \(lessonId) as completed")
            if nextIndex < lessons.count {
                print("🔓 Unlocked next lesson: \(lessons[nextIndex].id)")
            }
        }
    }
    
    // MARK: - Persistence (UserDefaults)
    private func saveLessonProgress(courseId: String, lessons: [Lesson]) {
        let completedIds = lessons.filter { $0.isCompleted }.map { $0.id }
        let unlockedIds = lessons.filter { !$0.isLocked }.map { $0.id }
        
        UserDefaults.standard.set(completedIds, forKey: "completed_lessons_\(courseId)")
        UserDefaults.standard.set(unlockedIds, forKey: "unlocked_lessons_\(courseId)")
    }
    
    func loadLessonProgress(courseId: String) -> (completed: [String], unlocked: [String]) {
        let completed = UserDefaults.standard.stringArray(forKey: "completed_lessons_\(courseId)") ?? []
        let unlocked = UserDefaults.standard.stringArray(forKey: "unlocked_lessons_\(courseId)") ?? []
        return (completed, unlocked)
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        lessonsCache.removeAll()
        print("🗑️ Cleared all lessons cache")
    }
    
    // MARK: - Reset Progress (for testing)
    func resetProgress(courseId: String) {
        UserDefaults.standard.removeObject(forKey: "completed_lessons_\(courseId)")
        UserDefaults.standard.removeObject(forKey: "unlocked_lessons_\(courseId)")
        lessonsCache.removeValue(forKey: courseId)
        print("🔄 Reset progress for course: \(courseId)")
    }
    
    // MARK: - Reset All Progress (for testing)
    func resetAllProgress() {
        for courseId in courseJsonMapping.keys {
            resetProgress(courseId: courseId)
        }
        print("🔄 Reset all course progress")
    }
}
