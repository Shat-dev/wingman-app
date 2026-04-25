//
//  SubscriptionGateModifier.swift
//  Wingman
//
//  Shared presentation layer for feature-level subscription gating.
//
//  Usage:
//    @State private var showPaywall = false
//
//    Button {
//        if authManager.hasActiveSubscription {
//            // do the gated action
//        } else {
//            showPaywall = true
//        }
//    }
//    ...
//    .subscriptionGate(isPresented: $showPaywall)
//
//  The modifier owns the sheet presentation and two behaviors the callers
//  shouldn't have to re-implement:
//    1. The X (dismiss) on the presented PaywallView just closes the sheet —
//       it does NOT call `completePaywallFlow()` because the user already
//       completed that flow to reach MainTabView. Calling it again would be
//       idempotent-but-wrong semantically.
//    2. If the user purchases from the gate paywall, `hasActiveSubscription`
//       flips to true and the sheet auto-dismisses, returning the user to the
//       screen they came from. They re-tap the gated action to proceed.
//

import SwiftUI

private struct SubscriptionGate: ViewModifier {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    PaywallView(
                        authManager: authManager,
                        isDismissible: true,
                        onDismiss: { isPresented = false },
                        source: .featureGate
                    )
                }
            }
            .onChange(of: authManager.hasActiveSubscription) { newValue in
                if newValue && isPresented {
                    isPresented = false
                }
            }
    }
}

extension View {
    /// Attach a feature-gate paywall sheet. Pair with a local
    /// `@State private var showPaywall = false` and trigger by setting it to
    /// true in the gated action when `authManager.hasActiveSubscription`
    /// is false.
    func subscriptionGate(isPresented: Binding<Bool>) -> some View {
        modifier(SubscriptionGate(isPresented: isPresented))
    }
}
