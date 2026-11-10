//
//  AnalyticsProperties.swift
//  Wingman
//
//  The analytics values that used to be read straight off whatever the screen
//  was showing: lesson names, course titles, scenario names, approach level
//  names, the commitment headline.
//
//  They are gathered here for one reason: a title shown to the user will be
//  translated, and a title sent to PostHog must not be. Every property built
//  in this file reads a `canonical…` value — the English text the app has
//  always sent — so breakdowns keep one value per lesson / course / scenario
//  whatever language the app is running in. `AnalyticsPropertiesTests` pins
//  the values against what PostHog already holds
//  (docs/localization-analytics-baseline.md).
//
//  The rule for the models below:
//
//    - the existing `title` / `name` field is, and stays, the English source
//      text (from the bundled lesson JSON, the Swift course catalog, or the
//      English Supabase row);
//    - `canonicalTitle` is the name analytics uses for it;
//    - anything shown on screen in another language must come from a separate
//      display accessor added by the localization work, never by changing
//      what `title` holds.
//
//  Each event also carries a stable id (`lesson_id`, `course_id`,
//  `scenario_id`, `approach_level`). Prefer those for new insights; the names
//  are kept because existing ones use them.
//

import Foundation

// MARK: - Lessons

extension Lesson {
    /// English lesson title, as sent in `lesson_name` / `lesson_title`.
    var canonicalTitle: String { title }

    /// English course title, as sent in `category`. (The property is called
    /// `category` for historical reasons; it has always held the course.)
    var canonicalCourseTitle: String { courseTitle }

    /// Identity properties shared by every lesson and lesson-quiz event.
    /// `course_id` was added with the localization work; the other three are
    /// unchanged.
    var analyticsProperties: [String: Any] {
        [
            "lesson_id": id,
            "lesson_name": canonicalTitle,
            "category": canonicalCourseTitle,
            "course_id": courseId
        ]
    }
}

// MARK: - Courses

extension Course {
    /// English course title from the Swift catalog, as sent in `course_title`.
    var canonicalTitle: String { title }
}

extension CourseCategory {
    /// English category name. A brand term: it is not translated on screen
    /// either (localization plan, decision D2).
    var canonicalName: String { name }
}

enum CourseAnalytics {
    /// What `previous_course_title` has always carried when the previous
    /// course could not be resolved.
    static let unknownPreviousCourseTitle = "the previous course"

    /// `lesson_gate_blocked`: a free user tapped an unlocked lesson.
    static func lessonGateBlocked(lesson: Lesson, course: Course) -> [String: Any] {
        [
            "lesson_id": lesson.id,
            "lesson_title": lesson.canonicalTitle,
            "course_id": course.id,
            "course_title": course.canonicalTitle
        ]
    }

    /// `course_locked_encountered`: the user opened a course that is waiting
    /// on the one before it. `previous_course_id` was added with the
    /// localization work and is omitted when the previous course is unknown.
    static func courseLockedEncountered(
        course: Course,
        previousCourseID: String?,
        previousCourseCanonicalTitle: String
    ) -> [String: Any] {
        var properties: [String: Any] = [
            "course_id": course.id,
            "course_title": course.canonicalTitle,
            "category_id": course.categoryId,
            "previous_course_title": previousCourseCanonicalTitle
        ]
        if let previousCourseID {
            properties["previous_course_id"] = previousCourseID
        }
        return properties
    }
}

// MARK: - Scenarios

extension PracticeGameData {
    /// English scenario title from the `scenarios` row, as sent in
    /// `scenario_name` (or the "Practice Scenario" fallback when the title
    /// lookup failed — an existing value in the data).
    var canonicalTitle: String { title }

    /// Identity properties shared by the practice scenario events.
    func analyticsProperties(duringWalkthrough: Bool) -> [String: Any] {
        [
            "scenario_id": id,
            "scenario_name": canonicalTitle,
            "during_walkthrough": duringWalkthrough
        ]
    }
}

// MARK: - Approach levels

extension ApproachLevel {
    /// English level name, as sent in `level_name`.
    var canonicalTitle: String { title }
}
