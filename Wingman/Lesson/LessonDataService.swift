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
        "course_3": "mindset_foundations_presence_expressions",
        "course_4": "mindset_foundations_inner_stability",
        "course_5": "mindset_foundations_non_negotiables",
        
        // Approach Mechanics (cat_2)
        "course_6": "approach_mechanics_approach_readiness",
        "course_7": "approach_mechanics_physical_approach",
        "course_8": "approach_mechanics_the_opener",
        "course_9": "approach_mechanics_reading_responding",
        "course_10": "approach_mechanics_situational_approaches",
        "course_11": "approach_mechanics_advanced_opening",
        
        // Conversation Flow (cat_3)
        "course_12": "conversation_flow_small_talk_momentum",
        "course_13": "conversation_flow_listening_attunement",
        "course_14": "conversation_flow_sharing_vulnerability",
        "course_15": "conversation_flow_closing",
        "course_16": "conversation_flow_advanced_skills",
        
        // Flirting & Chemistry (cat_4)
        "course_17": "flirting_chemistry_prerequisites",
        "course_18": "flirting_chemistry_playfulness_spark",
        "course_19": "flirting_chemistry_compliments_verbal",
        "course_20": "flirting_chemistry_physical_escalation",
        "course_21": "flirting_chemistry_advanced_skills",
        
        // Integration & Mastery (cat_5)
        "course_22": "integration_mastery_lifestyle_upgrade",
        "course_23": "integration_mastery_creating_opportunities",
        "course_24": "integration_mastery_mastery_identity",
        "course_25": "integration_mastery_learning_discovery"
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
