//
//  OnboardingProgressBar.swift
//  Wingman
//

import SwiftUI

// Extracted from a private method on `OnboardingView` so SwiftUI can give it
// stable identity. As a method it was being re-evaluated on every
// `OnboardingView.body` invocation — including every keystroke in the name
// field — and its `GeometryReader` was re-measuring on each one. As its own
// `View` struct, SwiftUI will skip body evaluation when `progress` hasn't
// changed.
struct OnboardingProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)

                Capsule()
                    .fill(Color.wingmanBlack)
                    .frame(width: geo.size.width * max(0, min(1, progress)), height: 10)
                    // Heavily-damped spring (0.95) — visually a smooth ramp
                    // with no perceptible overshoot, but feels more native than
                    // an easeInOut sigmoid because the velocity comes off the
                    // user's tap, not from a fixed timing curve.
                    .animation(.spring(response: 0.5, dampingFraction: 0.95), value: progress)
            }
        }
        .frame(height: 10)
    }
}
