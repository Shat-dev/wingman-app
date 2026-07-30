//
//  QuizProgressBar.swift
//  Wingman
//

import SwiftUI

/// The capsule progress track used above a run of quiz questions.
///
/// Lifted verbatim from `DailyPracticeView.progressBar(progress:)` — same 10pt
/// height, same grey track, same 0.25s ease-in-out fill animation.
///
/// Only the track is shared, not the row it sits in. The surrounding
/// chevron + `HStack` differs between screens (`DailyPracticeView` uses
/// `.leading 8 / .bottom 12`, `LessonView` uses `.leading 5 / .bottom 10`), so
/// each caller keeps its own row and drops this in as the bar.
struct QuizProgressBar: View {

    /// 0...1. Values outside that range are clamped rather than overflowing.
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)

                Capsule()
                    .fill(Color.wingmanBlack)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 10)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 10)
    }
}

#Preview {
    VStack(spacing: 24) {
        QuizProgressBar(progress: 0.0)
        QuizProgressBar(progress: 0.4)
        QuizProgressBar(progress: 1.0)
    }
    .padding()
}
