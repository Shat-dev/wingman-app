//
//  View+DynamicType.swift
//  Wingman
//

import SwiftUI

extension View {
    /// Applies the app-wide Dynamic Type ceiling to this view's subtree.
    ///
    /// The ceiling is set once at the app root (`WingmanApp` → `RootView`), but
    /// `.sheet` / `.fullScreenCover` present their content in a separate context
    /// that does not reliably inherit that environment value across iOS
    /// versions. Apply this at the root of every modally-presented view so the
    /// ceiling is enforced directly on its own subtree, independent of
    /// inheritance. Applied under an already-clamped context it is a harmless
    /// no-op (both cap at the same size).
    ///
    /// The value is centralized here so it can be raised in ONE place once the
    /// fragile layouts are made adaptive (see the growth-fix plan). Keep it in
    /// sync with the global clamp in `WingmanApp`.
    func appDynamicTypeCeiling() -> some View {
        dynamicTypeSize(...DynamicTypeSize.large)
    }
}
