//
//  LessonOverlay.swift
//  Wingman
//
//  Translated lesson text, laid over the bundled English lessons by ID.
//
//  The 25 English lesson files stay exactly where they are and remain the
//  source of everything structural: which lessons exist, their order, IDs,
//  durations and lock state. A translation is one small file per course per
//  language that maps existing IDs to translated text:
//
//      {
//        "lesson_14_1.title":   "…",
//        "lesson_14_1.summary": "…",
//        "course_14.summary":   "…",
//        "content_14_1_1_1":    "…"
//      }
//
//  named `lesson_overlay_<courseId>_<language>.json` (for example
//  `lesson_overlay_course_14_de.json`) and shipped in the app bundle.
//
//    - English never looks for an overlay. Lessons load as they always have.
//    - No overlay file for a course, or a file that cannot be read: that
//      course is shown in English.
//    - Any ID missing from the overlay, or with blank text, keeps its
//      English text. IDs the lessons do not have are ignored.
//    - A lesson's `title` stays English, because it is what analytics
//      records (`canonicalTitle`). The translation is read through
//      `displayTitle`. Paragraph text is display only and is replaced in
//      place.
//

import Foundation

enum LessonOverlay {

    // MARK: Keys

    static func titleKey(lessonId: String) -> String { "\(lessonId).title" }
    static func summaryKey(lessonId: String) -> String { "\(lessonId).summary" }
    static func courseSummaryKey(courseId: String) -> String { "\(courseId).summary" }
    // A paragraph's key is its own ID ("content_14_1_1_1").

    static func resourceName(courseId: String, language: String) -> String {
        "lesson_overlay_\(courseId)_\(language)"
    }

    // MARK: Loading

    /// The overlay for a course in a language, or nil when the bundle has
    /// none or it cannot be read.
    static func load(courseId: String, language: String, bundle: Bundle = .main) -> [String: String]? {
        let name = resourceName(courseId: courseId, language: language)
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            log("⚠️ LessonOverlay: \(name).json unreadable, showing English — \(error)")
            return nil
        }
    }

    // MARK: Applying

    static func apply(_ overlay: [String: String], to lessons: [Lesson]) -> [Lesson] {
        guard !overlay.isEmpty else { return lessons }

        return lessons.map { lesson in
            Lesson(
                id: lesson.id,
                courseId: lesson.courseId,
                courseSummary: lesson.courseSummary,
                courseTitle: lesson.courseTitle,
                lessonNumber: lesson.lessonNumber,
                title: lesson.title,
                duration: lesson.duration,
                summary: lesson.summary,
                isCompleted: lesson.isCompleted,
                isLocked: lesson.isLocked,
                screens: lesson.screens.map { screen in
                    LessonScreen(
                        id: screen.id,
                        order: screen.order,
                        content: screen.content.map { paragraph in
                            LessonContent(
                                id: paragraph.id,
                                text: ContentOverlay.text(overlay[paragraph.id], fallback: paragraph.text),
                                order: paragraph.order
                            )
                        }
                    )
                },
                translatedTitle: nonBlank(overlay[titleKey(lessonId: lesson.id)]),
                translatedSummary: nonBlank(overlay[summaryKey(lessonId: lesson.id)]),
                translatedCourseSummary: lesson.courseSummary == nil
                    ? nil
                    : nonBlank(overlay[courseSummaryKey(courseId: lesson.courseId)])
            )
        }
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
