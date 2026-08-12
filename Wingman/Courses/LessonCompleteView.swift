//
//  LessonCompleteView.swift
//  Wingman
//

import SwiftUI

struct LessonCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    /// The lesson whose award this screen should display. Without it the
    /// screen would render whatever the previous completion earned.
    let lessonId: String
    let nextLessonInfo: NextLessonInfo?
    let onContinue: () -> Void

    var body: some View {
        CompletionScreen(
            title: "Lesson complete.",
            expectedSourceId: lessonId,
            onContinue: {
                // `onContinue` is what actually marks the lesson complete and
                // fires `lesson_completed` (LessonView), so it must run before
                // the dismiss, exactly as it did before.
                onContinue()
                dismiss()
            },
            detail: {
                if let nextLesson = nextLessonInfo {
                    VStack(spacing: 8) {
                        Text("Up Next")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(Color.wingmanBlack.opacity(0.7))

                        Text(nextLesson.title)
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.wingmanBlack)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    Text("Course complete.")
                        .font(.manropeMedium(size: 14))
                        .foregroundColor(.wingmanBlack)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        )
    }
}

#Preview {
    LessonCompleteView(
        lessonId: "lesson_1_1",
        nextLessonInfo: NextLessonInfo(
            title: "Rejection isn't personal",
            subtitle: "Beliefs & Reframes"
        ),
        onContinue: {}
    )
}

#Preview("Course Complete") {
    LessonCompleteView(
        lessonId: "lesson_1_1",
        nextLessonInfo: nil,
        onContinue: {}
    )
}
