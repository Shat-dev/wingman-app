//
//  PressableButtonStyle.swift
//  Wingman
//

import SwiftUI

// iOS-native press feedback: scale + dim on touch-down, snap back on release.
// Resting state is identical to the underlying view (scale 1.0, opacity 1.0)
// so this is purely additive — no layout or color change at rest. The 0.15s
// spring matches Apple's standard touch-down feel.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.9), value: configuration.isPressed)
    }
}
