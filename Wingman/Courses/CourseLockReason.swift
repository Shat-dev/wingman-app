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
    /// `previousCourseTitle` is what the banner shows (already in the app's
    /// language; nil if the previous course is unknown). The id and the
    /// canonical (English) title are for analytics only, so that what is sent
    /// does not depend on what the banner reads; the id is nil when the
    /// previous course could not be resolved.
    case awaitingPrevious(previousCourseTitle: String?, previousCourseID: String?, previousCourseCanonicalTitle: String)

    /// The banner explaining the lock, or nil when the course is open. A
    /// complete sentence in each case, so a translation can order the words
    /// as its language needs; `previousCourseTitle` is nil when the previous
    /// course could not be resolved.
    var bannerText: String? {
        switch self {
        case .unlocked:
            return nil
        case .awaitingPrevious(let previousTitle?, _, _):
            return String(localized: "Complete all lessons in \(previousTitle) to unlock this course.")
        case .awaitingPrevious(nil, _, _):
            return String(localized: "Complete all lessons in the previous course to unlock this course.")
        }
    }

    var isLocked: Bool {
        switch self {
        case .unlocked: return false
        case .awaitingPrevious: return true
        }
    }
}
