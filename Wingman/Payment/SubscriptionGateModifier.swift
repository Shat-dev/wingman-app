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

    /// Set by `PaywallView` when it has already captured `paywall_dismissed`
    /// for this presentation (X button or purchase). Read by the sheet's
    /// `onDismiss` so the swipe-away fallback below doesn't double-count them.
    @State private var paywallReportedDismissal = false

    /// When the sheet was asked to present. `PaywallView` owns its own
    /// `appearedAt` for the events it captures, but the swipe path never
    /// reaches that view's code, so the fallback needs its own timestamp —
    /// otherwise `time_on_screen_seconds` would be systematically absent on
    /// exactly the dismissals this fix exists to capture, and any average
    /// over the property would be biased toward the users who tap the X.
    @State private var presentedAt: Date?

    func body(content: Content) -> some View {
        content
            // `onDismiss` here is SwiftUI's own sheet-level callback, which
            // fires for EVERY dismissal path — the X button below (via
            // `isPresented = false`), an interactive swipe-down (which
            // bypasses PaywallView's X-button closure entirely), and the
            // purchase-triggered auto-dismiss in the .onChange below. That
            // last case is safe to route through the same hook: by the time
            // it fires, `hasActiveSubscription` is already true, so
            // `reportSwipeDismissalIfNeeded()`'s own guard no-ops immediately.
            .sheet(isPresented: $isPresented, onDismiss: {
                reportSwipeDismissalIfNeeded()
            }) {
                NavigationStack {
                    PaywallView(
                        authManager: authManager,
                        isDismissible: true,
                        onDismiss: { isPresented = false },
                        source: .featureGate,
                        onDismissReported: { paywallReportedDismissal = true }
                    )
                }
            }
            .onChange(of: isPresented) { presented in
                // Arm the fallback on the way in, not on the way out: by the
                // time `onDismiss` runs the presentation is already over.
                if presented {
                    paywallReportedDismissal = false
                    presentedAt = Date()
                }
            }
            .onChange(of: authManager.hasActiveSubscription) { newValue in
                if newValue && isPresented {
                    isPresented = false
                }
            }
    }

    /// Captures `paywall_dismissed` for the one exit `PaywallView` cannot see.
    ///
    /// This paywall is a sheet, so it can be swiped down. That path runs none
    /// of the view's own controls, so until this fallback existed those
    /// dismissals emitted no event at all, and `source = featureGate`
    /// dismissal counts were understated by however many users swipe rather
    /// than tap the X.
    ///
    /// `outcome` stays `dismissed_without_purchase` rather than gaining a new
    /// value, so existing insights filtering on it simply become correct
    /// instead of breaking; `dismiss_method` is what separates the two.
    private func reportSwipeDismissalIfNeeded() {
        // The subscription check is not redundant with the flag — it closes a
        // race the flag alone cannot.
        //
        // `PaywallViewModel.purchase(_:)` calls
        // `SubscriptionManager.handleCustomerInfoUpdate` *before* it returns,
        // so `hasActiveSubscription` can flip — and the `.onChange` above can
        // set `isPresented = false` — while the button's `await` is still
        // suspended, i.e. before `PaywallView` reaches its own capture and
        // sets the flag. Ordering between those two is not guaranteed either
        // way, and losing that race would file a paying user as a
        // dismissal-without-purchase: corrupting the exact number this
        // fallback exists to make correct.
        //
        // A purchase-driven auto-dismiss always has an active subscription by
        // definition, so keying on it is order-independent.
        guard !paywallReportedDismissal, !authManager.hasActiveSubscription else { return }

        var properties: [String: Any] = [
            "source": PaywallSource.featureGate.rawValue,
            "outcome": "dismissed_without_purchase",
            "dismiss_method": "swipe"
        ]
        if let presentedAt {
            properties["time_on_screen_seconds"] = Analytics.elapsedSeconds(since: presentedAt)
        }
        Analytics.capture("paywall_dismissed", properties)
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
