//
//  LessonDataService.swift
//  Wingman
//
//  Created by Adnan Khan on 08/01/2026.
//


//
//  LessonDataService.swift
//  Wingman
//

import Foundation

class LessonDataService {
    static let shared = LessonDataService()
    
    private init() {}
    
    // MARK: - Load Lessons from Local JSON
    func loadLessonsForCourse(courseId: String) -> [Lesson] {
        // Try to load from JSON file
        if let lessons = loadFromJSON(courseId: courseId) {
            return lessons
        }
        
        // Fallback to sample data
        return getSampleLessons(courseId: courseId)
    }
    
    private func loadFromJSON(courseId: String) -> [Lesson]? {
        guard let url = Bundle.main.url(forResource: "course_\(courseId)_lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lessons = try? JSONDecoder().decode([Lesson].self, from: data) else {
            return nil
        }
        return lessons
    }
    
    // MARK: - Get Next Lesson Info
    func getNextLesson(currentLessonId: String, courseId: String) -> NextLessonInfo? {
        let lessons = loadLessonsForCourse(courseId: courseId)
        
        guard let currentIndex = lessons.firstIndex(where: { $0.id == currentLessonId }),
              currentIndex + 1 < lessons.count else {
            return nil
        }
        
        let nextLesson = lessons[currentIndex + 1]
        return NextLessonInfo(title: nextLesson.title, subtitle: nextLesson.subtitle)
    }
    
    // MARK: - Sample Data (for testing)
    private func getSampleLessons(courseId: String) -> [Lesson] {
        return [
            Lesson(
                id: "lesson_1",
                courseId: courseId,
                lessonNumber: 1,
                title: "Your are not your thoughts",
                subtitle: "Courage Comes first, Confidence follows",
                duration: 3,
                content: [
                    LessonContent(text: "When you know you smell fresh, look clean, and feel put together, you can stop worrying about how you come across.", order: 0),
                    LessonContent(text: "Good hygiene is about removing the invisible barriers that push people away. Foul scent, dirty nails, or stale breath override everything else, no matter how confident or charming you are.", order: 1),
                    LessonContent(text: "Good hygiene also gives you a sense of internal certainty. When you know you are clean, you can move closer, speak freely, and interact more easily.", order: 2),
                    LessonContent(text: "That ease helps you become more confident in social settings.", order: 3)
                ],
                isCompleted: false,
                isLocked: false
            ),
            Lesson(
                id: "lesson_2",
                courseId: courseId,
                lessonNumber: 2,
                title: "Building Confidence",
                subtitle: "Step by step approach",
                duration: 5,
                content: [
                    LessonContent(text: "Confidence isn't something you're born with.", order: 0),
                    LessonContent(text: "It's built through consistent action and experience.", order: 1),
                    LessonContent(text: "Every small step you take builds momentum.", order: 2)
                ],
                isCompleted: false,
                isLocked: true
            )
        ]
    }
}