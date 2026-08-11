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
                    // Deliberately no `.animation(_:value:)` here.
                    //
                    // An explicit `.animation(_:value:)` overrides the ambient
                    // transaction for its subtree, so the spring that used to
                    // sit here (response 0.5, damping 0.95) ran on its own
                    // clock while the page slid on the coordinator's (response
                    // 0.35, damping 0.86) — a longer settle time off the same
                    // tap, so the bar was still moving after the page landed.
                    //
                    // Without the modifier the fill inherits whatever
                    // transaction changed `progress` — always the
                    // `withAnimation` block in `OnboardingView.advanceTo` or
                    // `goBack`, since `progress` derives from `screen` and
                    // `screen` is never mutated outside one. Bar and page now
                    // settle on the same frame, and stay in sync on their own
                    // if the slide is ever retuned.
            }
        }
        .frame(height: 10)
    }
}
