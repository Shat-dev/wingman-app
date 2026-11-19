//
//  Device+Screen.swift
//  Wingman
//

import SwiftUI

/// The size of the window the app is drawn in, measured once at the root
/// (`WingmanApp` → `.readsWindowSize()`) and handed down the environment.
///
/// Replaces `UIScreen.main.bounds`, which is deprecated and wrong whenever the
/// window is not the whole screen or changes size while the app runs (iPhone
/// Duo folding and unfolding, split screen). On every current iPhone the app is
/// a portrait full-screen window, so this is the same size `UIScreen.main`
/// reported, and every layout decision below comes out exactly as before.
///
/// `.zero` until the root has been laid out once.
private struct WindowSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
    var windowSize: CGSize {
        get { self[WindowSizeKey.self] }
        set { self[WindowSizeKey.self] = newValue }
    }
}

enum WindowMetrics {
    /// True for an iPhone SE–class window (~667pt tall or less) held upright.
    /// Used to gate narrow, targeted layout adjustments that must NOT affect
    /// standard or large iPhones.
    ///
    /// The same predicate `UIScreen.isSmallPhone` used, applied to the measured
    /// window instead of the main screen. The `width < height` guard keeps a
    /// landscape window from tripping it.
    static func isSmallPhone(_ windowSize: CGSize) -> Bool {
        windowSize.width < windowSize.height && windowSize.height < 700
    }

    /// The shortest window any current iPhone gives the app: an iPhone SE with
    /// Display Zoom, 320 × 568pt.
    static let shortestPhoneWindowHeight: CGFloat = 568

    /// True only for a window shorter than every current iPhone's — the iPhone
    /// Duo's outer display, a partly folded half, a short split-screen pane.
    /// Never true on a current iPhone, so anything gated on it leaves those
    /// phones untouched.
    static func isShortWindow(_ windowSize: CGSize) -> Bool {
        windowSize.height > 0 && windowSize.height < shortestPhoneWindowHeight
    }
}

private struct WindowSizeReader: ViewModifier {
    @State private var windowSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .environment(\.windowSize, windowSize)
            // Fills the window and centres the content in it — what the
            // hosting window does with a root view anyway — so the background
            // below spans the whole window whatever size the content is.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // Measured in the background so the content's own layout is
                // untouched. The safe-area region plus its insets is the whole
                // window; a keyboard moves height from one to the other, so
                // the sum holds still while it is up. (An `ignoresSafeArea()`
                // view in a background is not stretched under the bars, so
                // it cannot be used to measure the window directly.)
                Color.clear
                    .onGeometryChange(for: CGSize.self) { proxy in
                        let insets = proxy.safeAreaInsets
                        return CGSize(
                            width: proxy.size.width + insets.leading + insets.trailing,
                            height: proxy.size.height + insets.top + insets.bottom
                        )
                    } action: { size in
                        windowSize = size
                    }
            }
    }
}

extension View {
    /// Measures the window this view fills and publishes it as
    /// `\.windowSize` to everything inside. Apply once, at the app root.
    func readsWindowSize() -> some View {
        modifier(WindowSizeReader())
    }
}
