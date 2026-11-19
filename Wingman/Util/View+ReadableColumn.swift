//
//  View+ReadableColumn.swift
//  Wingman
//

import SwiftUI

/// Column widths for a regular-width window — the iPhone Duo's inner display.
/// Content keeps its phone layout and gains whitespace either side instead of
/// stretching edge to edge.
enum ReadableColumn {
    /// Reading screens: lessons, onboarding, quizzes, Home, Profile.
    static let text: CGFloat = 680
    /// Decision screens built around one button: paywall, offer, sign-in.
    static let narrow: CGFloat = 560
}

extension View {
    /// Caps this view's width and centres it in a regular-width window.
    ///
    /// In compact width — every current iPhone, which the app only runs on in
    /// portrait — both frames get `nil` for every parameter, which leaves the
    /// view's size and position exactly as they were. It is one modifier whose
    /// values change, never an `if`, so nothing inside loses its state when
    /// the device folds or unfolds.
    func readableColumn(_ maxWidth: CGFloat = ReadableColumn.text) -> some View {
        modifier(ReadableColumnModifier(maxWidth: maxWidth))
    }
}

private struct ReadableColumnModifier: ViewModifier {
    let maxWidth: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        let isRegular = horizontalSizeClass == .regular
        content
            .frame(maxWidth: isRegular ? maxWidth : nil)
            .frame(maxWidth: isRegular ? .infinity : nil)
    }
}
