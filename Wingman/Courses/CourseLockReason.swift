//
//  CourseLockReason.swift
//  Wingman
//

import Foundation

/// Describes why a course is (or isn't) locked.
/// Drives the grid's visual state and the CourseDetailSheet banner.
enum CourseLockReason: Equatable {
    /// The course is accessible. User can enter and tap lessons.
    case unlocked

    /// Content is not yet shipped ("coming soon" — from the hardcoded
    /// `Course.isLocked` flag). Independent of user progress.
    ///
    /// NOTE: currently unreachable — every shipped course has a lesson
    /// JSON file and is gated by progression only. Kept as a dormant
    /// option for potential future placeholder/preview courses.
    case comingSoon

    /// The previous course in the category has not been fully completed.
    /// `previousCourseTitle` is used by the banner copy.
    case awaitingPrevious(previousCourseTitle: String)

    var isLocked: Bool {
        switch self {
        case .unlocked: return false
        case .comingSoon, .awaitingPrevious: return true
        }
    }
}
