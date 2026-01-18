//
//  Lesson.swift
//  Wingman
//
//  Created by Adnan Khan on 08/01/2026.
//


//
//  Lesson.swift
//  Wingman
//

import Foundation

// MARK: - Lesson Model
struct Lesson: Identifiable, Codable {
    let id: String
    let courseId: String
    let lessonNumber: Int
    let title: String
    let subtitle: String
    let duration: Int
    let content: [LessonContent]
    var isCompleted: Bool = false
    var isLocked: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, courseId, lessonNumber, title, subtitle, duration, content, isCompleted, isLocked
    }
}

// MARK: - Lesson Content (Line by line)
struct LessonContent: Identifiable, Codable {
    let id: String
    let text: String
    let order: Int
    
    init(id: String = UUID().uuidString, text: String, order: Int) {
        self.id = id
        self.text = text
        self.order = order
    }
}

// MARK: - Next Lesson Info
struct NextLessonInfo {
    let title: String
    let subtitle: String
}
