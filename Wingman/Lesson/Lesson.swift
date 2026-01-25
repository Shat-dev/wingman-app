//
//  Lesson.swift
//  Wingman
//

import Foundation

// MARK: - Lesson Model
struct Lesson: Identifiable, Codable {
    let id: String
    let courseId: String
    let courseSummary: String?
    let courseTitle: String  // Replaces subtitle - shows course title at bottom
    let lessonNumber: Int
    let title: String
    let duration: Int
    let summary: String
    var isCompleted: Bool
    var isLocked: Bool
    let screens: [LessonScreen]  // Changed from content to screens
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case courseSummary
        case courseTitle
        case lessonNumber
        case title
        case duration
        case summary
        case isCompleted
        case isLocked
        case screens
    }
}

// MARK: - Lesson Screen Model (represents a "screen" in the lesson)
struct LessonScreen: Identifiable, Codable {
    let id: String
    let order: Int
    let content: [LessonContent]  // Paragraphs within this screen
    
    enum CodingKeys: String, CodingKey {
        case id
        case order
        case content
    }
}

// MARK: - Lesson Content Model (individual paragraphs)
struct LessonContent: Identifiable, Codable {
    let id: String
    let text: String
    let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case order
    }
}

// MARK: - Next Lesson Info (for completion screen)
struct NextLessonInfo {
    let title: String
    let subtitle: String
}
