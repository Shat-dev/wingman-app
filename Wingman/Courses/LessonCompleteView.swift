//
//  LessonCompleteView.swift
//  Wingman
//

import SwiftUI

struct LessonCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var xpStore = XPStore.shared
    let nextLessonInfo: NextLessonInfo?
    let onContinue: () -> Void

    var body: some View {
        CompletionScreen(
            title: "Lesson complete.",
            award: xpStore.lastAward,
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
        nextLessonInfo: NextLessonInfo(
            title: "Rejection isn't personal",
            subtitle: "Beliefs & Reframes"
        ),
        onContinue: {}
    )
}

#Preview("Course Complete") {
    LessonCompleteView(
        nextLessonInfo: nil,
        onContinue: {}
    )
}
