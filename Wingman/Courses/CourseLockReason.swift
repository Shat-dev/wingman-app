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

    /// The previous course in the category has not been fully completed.
    /// `previousCourseTitle` is what the banner shows. The id and the
    /// canonical (English) title are for analytics only, so that what is sent
    /// does not depend on what the banner reads; the id is nil when the
    /// previous course could not be resolved.
    case awaitingPrevious(previousCourseTitle: String, previousCourseID: String?, previousCourseCanonicalTitle: String)

    var isLocked: Bool {
        switch self {
        case .unlocked: return false
        case .awaitingPrevious: return true
        }
    }
}
