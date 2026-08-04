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
import RevenueCat

private struct SubscriptionGate: ViewModifier {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthManager

    /// Drives the one-time 50%-off-year-1 recovery offer, chained off a
    /// no-purchase dismissal of the feature-gate paywall above. See
    /// docs/second-chance-paywall-plan.md for the full design.
    @State private var showSecondChanceOffer = false

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

    /// Set by `SecondChanceOfferView` when it has already captured an outcome
    /// for this presentation. Read by the recovery sheet's `onDismiss` so the
    /// swipe fallback below doesn't double-count a tap or a purchase.
    @State private var secondChanceReportedOutcome = false

    /// When the recovery sheet was asked to present. Its own `appearedAt` is
    /// inside the view, which the swipe path never reaches — same reasoning as
    /// `presentedAt` above.
    @State private var secondChancePresentedAt: Date?

    func body(content: Content) -> some View {
        content
            // `onDismiss` here is SwiftUI's own sheet-level callback, which
            // fires for EVERY dismissal path — the X button below (via
            // `isPresented = false`), an interactive swipe-down (which
            // bypasses PaywallView's X-button closure entirely and was
            // silently skipping the recovery-offer check), and the
            // purchase-triggered auto-dismiss in the .onChange below. That
            // last case is safe to route through the same hook: by the time
            // it fires, `hasActiveSubscription` is already true, so
            // `evaluateSecondChanceOffer()`'s own guard no-ops immediately.
            .sheet(isPresented: $isPresented, onDismiss: {
                reportSwipeDismissalIfNeeded()
                evaluateSecondChanceOffer()
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
            // Same `onDismiss` treatment the paywall sheet above already has,
            // and for the same reason: a swipe-down bypasses every control
            // inside the sheet, so without this the recovery offer's only
            // terminal event (`recovery_offer_dismissed`) never fired for the
            // most common exit. It had never fired once in the project's
            // history — everybody swipes, nobody taps the X.
            .sheet(isPresented: $showSecondChanceOffer, onDismiss: {
                reportSecondChanceSwipeDismissalIfNeeded()
            }) {
                NavigationStack {
                    SecondChanceOfferView(
                        onDismiss: { showSecondChanceOffer = false },
                        onOutcomeReported: { secondChanceReportedOutcome = true }
                    )
                }
            }
            .onChange(of: showSecondChanceOffer) { presented in
                // Armed on the way in, not the way out — by the time `onDismiss`
                // runs the presentation is already over.
                if presented {
                    secondChanceReportedOutcome = false
                    secondChancePresentedAt = Date()
                }
            }
    }

    /// Captures `recovery_offer_dismissed` for the swipe-down exit, which runs
    /// none of `SecondChanceOfferView`'s own controls.
    ///
    /// Note this is only about *observability*. The "shown once, ever" guarantee
    /// no longer depends on any exit path: `SecondChanceOfferView` burns
    /// `markSecondChanceOfferShown` when it appears, precisely because this path
    /// used to skip it and re-arm the offer indefinitely.
    private func reportSecondChanceSwipeDismissalIfNeeded() {
        // `hasActiveSubscription` covers the purchase-driven auto-dismiss for
        // the same order-independence reason as `reportSwipeDismissalIfNeeded`.
        guard !secondChanceReportedOutcome, !authManager.hasActiveSubscription else { return }

        var properties: [String: Any] = ["dismiss_method": "swipe"]
        if let secondChancePresentedAt {
            properties["time_on_screen_seconds"] = Analytics.elapsedSeconds(since: secondChancePresentedAt)
        }
        Analytics.capture(Analytics.Event.recoveryOfferDismissed, properties)
    }

    /// Captures `paywall_dismissed` for the one exit `PaywallView` cannot see.
    ///
    /// This paywall is a sheet, so it can be swiped down. That path runs none
    /// of the view's own controls — the same bypass that was already noted
    /// above for the recovery-offer trigger — so until now those dismissals
    /// emitted no event at all, and `source = featureGate` dismissal counts
    /// were understated by however many users swipe rather than tap the X.
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
        // so `hasActiveSubscription` can flip — and the `.onChange` below can
        // set `isPresented = false` — while the button's `await` is still
        // suspended, i.e. before `PaywallView` reaches its own capture and
        // sets the flag. Ordering between those two is not guaranteed either
        // way, and losing that race would file a paying user as a
        // dismissal-without-purchase: corrupting the exact number this
        // fallback exists to make correct.
        //
        // A purchase-driven auto-dismiss always has an active subscription by
        // definition, so keying on it is order-independent. It also matches
        // the first gate `evaluateSecondChanceOffer()` already applies below.
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

    /// Decides whether to chain the recovery offer in after a no-purchase
    /// dismissal. Four independent gates, per the plan — none of them
    /// sufficient alone:
    ///   1. Not already subscribed (and not anonymous — this screen is only
    ///      reachable post-account-creation by construction, but the check
    ///      is defensive against future flow changes).
    ///   2. Not already shown to this user, ever (AuthManager, mirrored to
    ///      Supabase user_metadata).
    ///   3. The walkthrough is behind them — see `midWalkthrough` below.
    ///   4. StoreKit/RevenueCat confirms live introductory-offer eligibility
    ///      for the discounted product — never claim a discount Apple won't
    ///      actually honor (e.g. a user whose earlier free trial lapsed
    ///      unconverted has already consumed their one intro-offer
    ///      eligibility for the subscription group).
    private func evaluateSecondChanceOffer() {
        let subscribed = authManager.hasActiveSubscription
        // "No durable identity to attach a purchase to" — which since guest
        // sessions exist means *no session at all*, not merely "no permanent
        // account". A guest has a real user id and a RevenueCat identity, so
        // the offer is safe to show them. Left as the legacy flag this would
        // have silently suppressed the second-chance offer for every guest,
        // i.e. the majority path.
        let anonymous = !authManager.hasSession
        let alreadyShown = authManager.hasSeenSecondChanceOffer
        // The offer is once-ever, so it has to be spent at the moment it is
        // worth the most: after the free lesson, when the user reaches for the
        // second one. The walkthrough's scrim passes taps through on two beats
        // (`scenarioPrompt` / `lessonsTour` — WalkthroughOverlayView.swift:58),
        // and demo-mode locking was cancelled, so these gates ARE reachable
        // mid-script. Without this, a stray tap on a locked course during the
        // course tour burns the offer before the user has completed anything.
        //
        // `hasResolvedDemoPath`, not `hasCompletedFreeDemo`: the latter is
        // never set for pre-update users with existing progress, who are
        // suppressed out of the walkthrough instead. Gating on it alone would
        // disable this feature permanently for the whole existing install base.
        let midWalkthrough = !authManager.hasResolvedDemoPath
        log("🎁 SubscriptionGate: evaluating second-chance offer — subscribed=\(subscribed) anonymous=\(anonymous) alreadyShown=\(alreadyShown) midWalkthrough=\(midWalkthrough)")

        guard !subscribed, !anonymous, !alreadyShown, !midWalkthrough else {
            log("🎁 SubscriptionGate: second-chance offer skipped by sync gate")

            // Without this the sync gate is a black hole: the offer simply
            // fails to appear and nothing distinguishes "correctly withheld"
            // from "the feature is broken".
            //
            // Two of the four conditions are deliberately NOT reported:
            //
            //   `subscribed` is the normal post-purchase auto-dismiss path. It
            //   fires on every successful conversion and would swamp the
            //   genuine skip reasons with the one outcome that is
            //   unambiguously good.
            //
            //   `alreadyShown` is exactly derivable from data already
            //   collected, so reporting it buys nothing. `hasSeenSecondChanceOffer`
            //   is set only by `markSecondChanceOfferShown`, called only from
            //   `SecondChanceOfferView.finish(outcome:)`, which is only
            //   reachable from inside that view — and its `onAppear` fires
            //   `recovery_offer_viewed` before any `finish` can run. (The one
            //   path that dismisses without firing it, package/intro-offer
            //   unavailable, calls bare `onDismiss()` precisely so it does not
            //   burn the flag.) So the flag is burned if and only if
            //   `recovery_offer_viewed` fired, and "already shown" is a cohort
            //   filter over that once-per-person event. Emitting a repeating
            //   event on every feature-gate dismissal, forever, to re-derive
            //   it would be the wrong trade at any volume.
            //
            // What remains is the pair that is genuinely not derivable, and
            // near-zero volume by construction: `mid_walkthrough` only during
            // the script, and `no_session` which should never fire at all —
            // which is the entire reason to watch for it.
            if !subscribed, !alreadyShown {
                // The guard failed and neither excluded condition holds, so
                // one of these two must be true; `anonymous` is the remainder.
                let reason = midWalkthrough ? "mid_walkthrough" : "no_session"
                Analytics.capture(Analytics.Event.recoveryOfferNotEligible, [
                    "reason": reason
                ])
            }
            return
        }

        Task { @MainActor in
            guard let package = await resolveSecondChancePackage() else {
                log("🎁 SubscriptionGate: second-chance package unavailable — skipping")
                return
            }
            log("🎁 SubscriptionGate: second-chance package resolved: \(package.storeProduct.productIdentifier)")

            let eligible = await isSecondChanceEligible()
            log("🎁 SubscriptionGate: intro-offer eligibility = \(eligible)")

            // Re-check right before presenting: state may have changed while
            // the eligibility check was in flight (e.g. an entitlement
            // arriving from another in-flight event).
            guard eligible, !authManager.hasActiveSubscription, !isPresented else {
                if !eligible {
                    Analytics.capture(Analytics.Event.recoveryOfferNotEligible, [
                        "reason": "not_intro_eligible"
                    ])
                }
                log("🎁 SubscriptionGate: second-chance offer skipped after eligibility check — eligible=\(eligible) subscribed=\(authManager.hasActiveSubscription) isPresented=\(isPresented)")
                return
            }

            log("🎁 SubscriptionGate: presenting second-chance offer")
            showSecondChanceOffer = true
        }
    }

    /// Fetches offerings live rather than reading `RevenueCatManager.shared
    /// .offerings` — that cache is populated exactly once, at app launch
    /// before sign-in, and is never refreshed anywhere else in the app. A
    /// dashboard change (or simply a long-lived app session) would never be
    /// reflected in it, silently making this gate a permanent no-op for that
    /// process lifetime. The fresh `Offerings` is also written back onto
    /// `RevenueCatManager.shared.offerings` so `SecondChanceOfferView`'s own
    /// synchronous, cache-reading `load()` sees it too.
    ///
    /// Timeout-guarded like `PaywallViewModel`'s offerings load, so a hung
    /// network call can't leave the paywall-dismiss flow stuck — fails safe
    /// (no offer shown) rather than blocking or crashing.
    private func resolveSecondChancePackage() async -> Package? {
        let offerings = await withTaskGroup(of: Offerings?.self) { group in
            group.addTask {
                try? await Purchases.shared.offerings()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        // The three exits below were the feature's biggest blind spot. Two of
        // them are pure *configuration* faults — renaming the offering or the
        // package in the RevenueCat dashboard turns this whole feature into a
        // silent no-op with no App Store release and, until now, no signal
        // anywhere in PostHog. Someone would have had to notice the revenue
        // was missing.
        guard let offerings else {
            log("🎁 SubscriptionGate: offerings fetch failed or timed out")
            Analytics.capture(Analytics.Event.recoveryOfferNotEligible, [
                "reason": "offerings_unavailable",
                "is_connected": NetworkMonitor.shared.isConnected
            ])
            return nil
        }

        RevenueCatManager.shared.offerings = offerings

        guard let offering = offerings.all[Constants.SECOND_CHANCE_OFFERING_ID] else {
            log("🎁 SubscriptionGate: offering '\(Constants.SECOND_CHANCE_OFFERING_ID)' not found — available offerings: \(offerings.all.keys.joined(separator: ", "))")
            Analytics.capture(Analytics.Event.recoveryOfferNotEligible, [
                "reason": "offering_not_found",
                "expected_offering_id": Constants.SECOND_CHANCE_OFFERING_ID,
                "available_offering_ids": offerings.all.keys.sorted().joined(separator: ",")
            ])
            return nil
        }

        guard let package = offering.package(identifier: Constants.SECOND_CHANCE_PACKAGE_ID) else {
            log("🎁 SubscriptionGate: package '\(Constants.SECOND_CHANCE_PACKAGE_ID)' not found in offering '\(Constants.SECOND_CHANCE_OFFERING_ID)' — available packages: \(offering.availablePackages.map { $0.identifier }.joined(separator: ", "))")
            Analytics.capture(Analytics.Event.recoveryOfferNotEligible, [
                "reason": "package_not_found",
                "expected_package_id": Constants.SECOND_CHANCE_PACKAGE_ID,
                "available_package_ids": offering.availablePackages
                    .map { $0.identifier }.sorted().joined(separator: ",")
            ])
            return nil
        }

        // The whole screen is an introductory-offer pitch: every price it shows
        // comes from `introductoryDiscount`, and its CTA reads "Get 50% Off".
        // If App Store Connect has no such offer on this product — never
        // configured, misconfigured, or still pending review — that discount
        // does not exist and StoreKit will charge the standard price.
        //
        // The eligibility check below looks like it already covers this, but it
        // does not: it treats `.unknown` as "show it", and `.unknown` is exactly
        // what a fresh install with no App Store receipt returns (see
        // PaywallViewModel.swift:158-162), i.e. most of this feature's target
        // population. So without this guard the screen renders a blank price
        // ("Billed  today for your first year"), keeps its "Get 50% Off" button,
        // and charges full price — a Guideline 3.1.2 violation and a chargeback,
        // caused by a dashboard state the app cannot otherwise see.
        //
        // Fail closed: no offer shown beats the wrong offer shown.
        guard package.storeProduct.introductoryDiscount != nil else {
            log("🎁 SubscriptionGate: '\(package.storeProduct.productIdentifier)' carries no introductory offer — skipping (check App Store Connect)")
            Analytics.capture(Analytics.Event.recoveryOfferNotEligible, [
                "reason": "no_intro_offer_on_product",
                "product_id": package.storeProduct.productIdentifier
            ])
            return nil
        }

        return package
    }

    /// Races RevenueCat's eligibility check against a timeout so a hung
    /// network call can't leave the paywall-dismiss flow stuck — on timeout
    /// (or any missing/unexpected result) this fails safe and simply doesn't
    /// present the offer, mirroring PaywallViewModel's offerings-load timeout
    /// pattern. `.eligible`/`.unknown` both mean "show it" (Apple honors
    /// `.unknown`, the no-receipt-yet answer, the same way `.eligible` is
    /// honored); only an authoritative `.ineligible`/`.noIntroOfferExists`
    /// blocks presentation.
    private func isSecondChanceEligible() async -> Bool {
        let productId = Constants.SECOND_CHANCE_YEARLY_PRODUCT_ID

        let result = await withTaskGroup(of: [String: IntroEligibility]?.self) { group in
            group.addTask {
                await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: [productId])
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        guard let status = result?[productId]?.status else {
            log("🎁 SubscriptionGate: eligibility check returned no result for \(productId)")
            return false
        }
        log("🎁 SubscriptionGate: eligibility status raw value = \(status.rawValue)")

        switch status {
        case .eligible, .unknown: return true
        case .ineligible, .noIntroOfferExists: return false
        @unknown default: return true
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
