//
//  ScalePressStyle.swift
//  Wingman
//

import SwiftUI

/// The app's single press-feedback language. Replaces SwiftUI's default
/// opacity flash (and the several one-off styles that predated this) so every
/// button — primary CTA, back chevron, icon button, card — squishes the same
/// way.
///
/// Press-down scales the whole label uniformly from centre; release springs
/// back with a deliberately under-damped 0.55, so it visibly overshoots and
/// settles rather than easing linearly. Both directions are driven by the one
/// animation, keyed on `isPressed`.
///
/// Deliberately does *not* touch opacity, in either the pressed or the
/// disabled direction. Resting appearance is byte-identical to the bare label,
/// which makes this safe to drop onto buttons that already express their own
/// state through colour — the daily-practice options that turn green/red, the
/// paywall button that dims while purchasing, the locked practice cards. Those
/// sites hand-roll their disabled look already; a style-level dim would
/// multiply with it.
///
/// No haptic here either: call sites that want one already fire it in their
/// action closure, and doing it in both places double-taps.
struct ScalePressStyle: ButtonStyle {
    /// Lower = squishier. Tuned down from an initial 0.88, which read as too
    /// much travel in the hand — the button visibly shrank rather than
    /// flexing. 0.94 halves it: still clearly a squish, but the button reads
    /// as pressed rather than resized. Change this one value to retune
    /// app-wide; individual call sites can override per-button if a
    /// particularly large or small control needs it.
    var pressedScale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55),
                       value: configuration.isPressed)
    }
}
