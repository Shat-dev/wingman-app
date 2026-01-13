//
//  CourseCategory.swift
//  Wingman
//
//  Created by Adnan Khan on 07/01/2026.
//


//
//  CoursesModels.swift
//  Wingman
//

import Foundation

// MARK: - Course Category Model
struct CourseCategory: Identifiable, Codable {
    let id: String
    let name: String
    let displayOrder: Int
    var courses: [Course]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayOrder = "display_order"
        case courses
    }
}

// MARK: - Course Model
struct Course: Identifiable, Codable {
    let id: String
    let categoryId: String
    let title: String
    let description: String?
    let thumbnailName: String
    let lessonsCount: Int
    let duration: Int? // in minutes
    let isLocked: Bool
    let displayOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case title
        case description
        case thumbnailName = "thumbnail_name"
        case lessonsCount = "lessons_count"
        case duration
        case isLocked = "is_locked"
        case displayOrder = "display_order"
    }
}

// MARK: - Dummy Data (Future: Replace with Supabase fetch)
extension CourseCategory {
    static let dummyCategories: [CourseCategory] = [
        CourseCategory(
            id: "cat_1",
            name: "Mindset & Foundations",
            displayOrder: 1,
            courses: [
                Course(
                    id: "course_1",
                    categoryId: "cat_1",
                    title: "Beliefs & Reframes",
                    description: "Transform limiting beliefs into empowering mindsets",
                    thumbnailName: "course_beliefs",
                    lessonsCount: 8,
                    duration: 45,
                    isLocked: false,
                    displayOrder: 1
                ),
                Course(
                    id: "course_2",
                    categoryId: "cat_1",
                    title: "Fear & Exposure",
                    description: "Overcome approach anxiety through gradual exposure",
                    thumbnailName: "course_fear",
                    lessonsCount: 6,
                    duration: 35,
                    isLocked: false,
                    displayOrder: 2
                ),
                Course(
                    id: "course_3",
                    categoryId: "cat_1",
                    title: "Presence & Expressions",
                    description: "Develop authentic presence and body language",
                    thumbnailName: "course_presence",
                    lessonsCount: 7,
                    duration: 40,
                    isLocked: false,
                    displayOrder: 3
                ),
                Course(
                    id: "course_4",
                    categoryId: "cat_1",
                    title: "Inner Stability",
                    description: "Build unshakeable confidence from within",
                    thumbnailName: "course_stability",
                    lessonsCount: 5,
                    duration: 30,
                    isLocked: false,
                    displayOrder: 4
                ),
                Course(
                    id: "course_5",
                    categoryId: "cat_1",
                    title: "Non-negotiables",
                    description: "Define your standards and boundaries",
                    thumbnailName: "course_nonnegotiables",
                    lessonsCount: 4,
                    duration: 25,
                    isLocked: true,
                    displayOrder: 5
                )
            ]
        ),
        CourseCategory(
            id: "cat_2",
            name: "Approach Mechanics",
            displayOrder: 2,
            courses: [
                Course(
                    id: "course_6",
                    categoryId: "cat_2",
                    title: "Approach Readiness",
                    description: "Prepare mentally and physically for approaches",
                    thumbnailName: "course_readiness",
                    lessonsCount: 5,
                    duration: 28,
                    isLocked: false,
                    displayOrder: 1
                ),
                Course(
                    id: "course_7",
                    categoryId: "cat_2",
                    title: "The Physical Approach",
                    description: "Master the mechanics of approaching",
                    thumbnailName: "course_physical",
                    lessonsCount: 6,
                    duration: 32,
                    isLocked: false,
                    displayOrder: 2
                ),
                Course(
                    id: "course_8",
                    categoryId: "cat_2",
                    title: "The Opener",
                    description: "Craft effective opening lines",
                    thumbnailName: "course_opener",
                    lessonsCount: 8,
                    duration: 42,
                    isLocked: true,
                    displayOrder: 3
                ),
                Course(
                    id: "course_9",
                    categoryId: "cat_2",
                    title: "Reading & Responding",
                    description: "Develop social calibration skills",
                    thumbnailName: "course_reading",
                    lessonsCount: 7,
                    duration: 38,
                    isLocked: true,
                    displayOrder: 4
                ),
                Course(
                    id: "course_10",
                    categoryId: "cat_2",
                    title: "Situational specific Approaches",
                    description: "Adapt to different social contexts",
                    thumbnailName: "course_situational",
                    lessonsCount: 9,
                    duration: 48,
                    isLocked: true,
                    displayOrder: 5
                ),
                Course(
                    id: "course_11",
                    categoryId: "cat_2",
                    title: "Advanced Opening Techniques",
                    description: "Master advanced strategies",
                    thumbnailName: "course_advanced",
                    lessonsCount: 10,
                    duration: 55,
                    isLocked: true,
                    displayOrder: 6
                )
            ]
        ),
        CourseCategory(
            id: "cat_3",
            name: "Conversation Flow",
            displayOrder: 3,
            courses: [
                Course(
                    id: "course_12",
                    categoryId: "cat_3",
                    title: "Small talk & Momentum",
                    description: "Keep conversations flowing naturally",
                    thumbnailName: "course_smalltalk",
                    lessonsCount: 6,
                    duration: 35,
                    isLocked: true,
                    displayOrder: 1
                ),
                Course(
                    id: "course_13",
                    categoryId: "cat_3",
                    title: "Listening & Attunement",
                    description: "Develop active listening skills",
                    thumbnailName: "course_listening",
                    lessonsCount: 5,
                    duration: 30,
                    isLocked: true,
                    displayOrder: 2
                ),
                Course(
                    id: "course_14",
                    categoryId: "cat_3",
                    title: "Sharing & Vulnerability",
                    description: "Build deeper connections",
                    thumbnailName: "course_vulnerability",
                    lessonsCount: 7,
                    duration: 40,
                    isLocked: true,
                    displayOrder: 3
                ),
                Course(
                    id: "course_15",
                    categoryId: "cat_3",
                    title: "Closing",
                    description: "Exchange contacts confidently",
                    thumbnailName: "course_closing",
                    lessonsCount: 4,
                    duration: 22,
                    isLocked: true,
                    displayOrder: 4
                ),
                Course(
                    id: "course_16",
                    categoryId: "cat_3",
                    title: "Advanced conversation skills",
                    description: "Master complex conversation dynamics",
                    thumbnailName: "course_advconvo",
                    lessonsCount: 8,
                    duration: 45,
                    isLocked: true,
                    displayOrder: 5
                )
            ]
        ),
        CourseCategory(
            id: "cat_4",
            name: "Flirting & Chemistry",
            displayOrder: 4,
            courses: [
                Course(
                    id: "course_17",
                    categoryId: "cat_4",
                    title: "Flirting Prerequisites",
                    description: "Understand flirting fundamentals",
                    thumbnailName: "course_flirtprereq",
                    lessonsCount: 5,
                    duration: 28,
                    isLocked: true,
                    displayOrder: 1
                ),
                Course(
                    id: "course_18",
                    categoryId: "cat_4",
                    title: "Playfulness & Spark",
                    description: "Create fun, engaging interactions",
                    thumbnailName: "course_playfulness",
                    lessonsCount: 6,
                    duration: 32,
                    isLocked: true,
                    displayOrder: 2
                ),
                Course(
                    id: "course_19",
                    categoryId: "cat_4",
                    title: "Compliments & Verbal Chemistry",
                    description: "Give genuine, impactful compliments",
                    thumbnailName: "course_compliments",
                    lessonsCount: 7,
                    duration: 38,
                    isLocked: true,
                    displayOrder: 3
                ),
                Course(
                    id: "course_20",
                    categoryId: "cat_4",
                    title: "Physical Presence & Escalation",
                    description: "Navigate physical connection",
                    thumbnailName: "course_physical_presence",
                    lessonsCount: 8,
                    duration: 42,
                    isLocked: true,
                    displayOrder: 4
                ),
                Course(
                    id: "course_21",
                    categoryId: "cat_4",
                    title: "Advanced Flirting Skills",
                    description: "Master advanced attraction techniques",
                    thumbnailName: "course_advflirt",
                    lessonsCount: 9,
                    duration: 48,
                    isLocked: true,
                    displayOrder: 5
                )
            ]
        ),
        CourseCategory(
            id: "cat_5",
            name: "Integration & Mastery",
            displayOrder: 5,
            courses: [
                Course(
                    id: "course_22",
                    categoryId: "cat_5",
                    title: "Upgrading your lifestyle",
                    description: "Become the best version of yourself",
                    thumbnailName: "course_lifestyle",
                    lessonsCount: 10,
                    duration: 55,
                    isLocked: true,
                    displayOrder: 1
                ),
                Course(
                    id: "course_23",
                    categoryId: "cat_5",
                    title: "Creating Opportunities",
                    description: "Design your social environment",
                    thumbnailName: "course_opportunities",
                    lessonsCount: 6,
                    duration: 35,
                    isLocked: true,
                    displayOrder: 2
                ),
                Course(
                    id: "course_24",
                    categoryId: "cat_5",
                    title: "Mastery & Identity",
                    description: "Embody your new confident self",
                    thumbnailName: "course_mastery",
                    lessonsCount: 8,
                    duration: 45,
                    isLocked: true,
                    displayOrder: 3
                ),
                Course(
                    id: "course_25",
                    categoryId: "cat_5",
                    title: "Learning & Self Discovery",
                    description: "Continue your growth journey",
                    thumbnailName: "course_selfdiscovery",
                    lessonsCount: 7,
                    duration: 40,
                    isLocked: true,
                    displayOrder: 4
                )
            ]
        )
    ]
}
