//
//  BreathingHighlight.swift
//  Wingman
//
//  Marks the one thing the walkthrough is asking the user to tap.
//
//  Replaces the mascot figure that used to stand on the scenario list. A character
//  next to the instruction competes with the thing the instruction is about —
//  and on a list it inevitably covers a row. Animating the target itself points
//  at it without occluding anything.
//

import SwiftUI

struct BreathingHighlight: ViewModifier {

    let isActive: Bool

    /// A slow pulse is the point of this modifier, so it has to have a
    /// non-animated form rather than simply being switched off. Reduce Motion
    /// gets the same emphasis held still — a heavier shadow and a slight lift.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathing = false

    private var animates: Bool { isActive && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .scaleEffect(animates && breathing ? 1.025 : 1.0)
            .shadow(
                color: Color.wingmanBlack.opacity(shadowOpacity),
                radius: isActive ? 16 : 0,
                y: isActive ? 5 : 0
            )
            .animation(
                animates
                    ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.25),
                value: breathing
            )
            .onAppear { breathing = animates }
            .onChange(of: isActive) { _ in breathing = animates }
            .onChange(of: reduceMotion) { _ in breathing = animates }
    }

    private var shadowOpacity: Double {
        guard isActive else { return 0 }
        if reduceMotion { return 0.22 }
        return breathing ? 0.20 : 0.08
    }
}

extension View {
    /// Draws slow attention to a control the walkthrough is waiting on.
    func breathingHighlight(_ isActive: Bool) -> some View {
        modifier(BreathingHighlight(isActive: isActive))
    }
}
