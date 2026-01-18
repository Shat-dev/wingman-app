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
    let lessonNumber: Int
    let title: String
    let subtitle: String
    let duration: Int
    let summary: String
    var isCompleted: Bool
    var isLocked: Bool
    let content: [LessonContent]
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case courseSummary
        case lessonNumber
        case title
        case subtitle
        case duration
        case summary
        case isCompleted
        case isLocked
        case content
    }
}

// MARK: - Lesson Content Model
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
