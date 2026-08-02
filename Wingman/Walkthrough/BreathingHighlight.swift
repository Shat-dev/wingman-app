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
    /// gets the same emphasis held still, at the enlarged scale.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathing = false

    private var animates: Bool { isActive && !reduceMotion }

    /// Scale only. A ring and a drop shadow were tried and both read as the
    /// card being broken rather than being pointed at — the shadow in
    /// particular showed as a grey smear against the app's flat white.
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
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

    private var scale: CGFloat {
        guard isActive else { return 1 }
        // Reduce Motion holds the enlarged state instead of pulsing. It cannot
        // simply drop to nothing: the scenario beat shows no copy at all, so
        // this card is the entire instruction on that screen.
        if reduceMotion { return 1.03 }
        return breathing ? 1.03 : 1.0
    }
}

extension View {
    /// Draws slow attention to a control the walkthrough is waiting on.
    func breathingHighlight(_ isActive: Bool) -> some View {
        modifier(BreathingHighlight(isActive: isActive))
    }
}
