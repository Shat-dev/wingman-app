//
//  OnboardingTopBar.swift
//  Wingman
//
//  The chevron + progress-bar strip pinned to the top of the onboarding
//  flow via `.safeAreaInset(.top)`. The back button is suppressed on
//  screens where there is no valid back target (currently: the loading
//  screen when no statistic is showing) by passing `showBackButton: false`;
//  in that case a placeholder spacer of equivalent height is rendered so
//  the layout doesn't jump.
//

import SwiftUI

struct OnboardingTopBar: View {
    let progress: CGFloat
    let showBackButton: Bool
    let onBack: () -> Void

    var body: some View {
        if showBackButton {
            HStack {
                Button {
                    HapticManager.shared.tap()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22))
                        .foregroundColor(.wingmanBlack)
                        .frame(width: 44, height: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScalePressStyle())

                OnboardingProgressBar(progress: progress)
                    .frame(height: 10)
            }
            .padding(.top, 8)
            .padding(.leading, 10)
            .padding(.trailing, 59)
            .padding(.bottom, 12)
        } else {
            // Keep spacing consistent when loading
            Spacer().frame(height: 20)
        }
    }
}

#Preview("20% progress with back") {
    OnboardingTopBar(progress: 0.2, showBackButton: true, onBack: {})
}

#Preview("65% progress with back") {
    OnboardingTopBar(progress: 0.65, showBackButton: true, onBack: {})
}

#Preview("Loading (no back)") {
    OnboardingTopBar(progress: 1.0, showBackButton: false, onBack: {})
}
