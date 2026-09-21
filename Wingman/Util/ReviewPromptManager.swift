//
//  ReviewPromptManager.swift
//  Wingman
//
//  Decides whether to ask for an App Store rating, and remembers that we did.
//
//  BACKGROUND — read this before moving the ask.
//
//  Build 1.0.7 (27) was rejected under guideline 5.6.3 for a rating screen in
//  onboarding that fired `requestReview()` on appear. The screen and the call
//  were both removed (see the note in `WingmanApp.RootView`).
//
//  The first version of this type brought the ask back behind the strictest
//  gate that rejection could imply: a paying subscriber, a full day after a
//  real charge had settled. It was safe and it was nearly silent. In its first
//  two weeks live it asked exactly one person, because only a trial conversion
//  could ever qualify and there are a handful of those a month. An app with a
//  steady stream of downloads was collecting no ratings.
//
//  So the gate is now *engagement*, not payment: the ask happens when a user
//  finishes an activity — a lesson, a scenario, or daily practice — or logs an
//  approach they made in the real world, whoever they are. Free users reach
//  that moment too (logging is free, scenario 1 is free for
//  everyone, and the walkthrough hands out one free lesson), which is the
//  point: about a quarter of the people who decline the first paywall still go
//  on to finish something, and until now none of them could be asked.
//
//  What keeps this on the right side of 5.6.3 is the same thing that makes it
//  a good moment: the user has completed a whole piece of the product, by their
//  own choice, before anything is asked of them. The rejected screen asked
//  during onboarding, before the app had been used at all. Do not move the
//  trigger earlier than a finished activity — in particular not to the end of
//  the walkthrough, which is a tour rather than use, a minute or two after the
//  paywall.
//
//  WHY THERE ARE STILL RULES
//
//  `requestReview` is not a prompt we control. iOS decides whether to show
//  anything at all, and Apple caps it at three appearances per user per 365
//  days. Every call spent on a badly-chosen moment is a call that is gone —
//  so the rules below are about spending few asks well, not many asks often.
//
//  The single most damaging moment is right after the user has been shown a
//  price. `noteFriction()` exists for that. It used to disqualify the whole
//  session, which cost nothing when the audience was subscribers and would be
//  fatal now: every new user meets the onboarding paywall minutes before their
//  first completion, so a session-wide rule would silence exactly the asks
//  this design exists to make. It is a short cooldown instead — see
//  `paywallCooldownSeconds`.
//
//  WHY THIS TYPE PRESENTS THE ALERT ITSELF
//
//  The trigger is the Continue tap on the completion screen, because that is
//  the one thing every finished activity passes through. (An earlier version
//  asked on a timer while the screen was up, and silently lost everyone who
//  tapped Continue first.) But Continue is also what tears that screen down,
//  so the ask has to outlive the view that triggers it — which rules out
//  SwiftUI's `@Environment(\.requestReview)`, an action that is only good
//  while its view is installed. `requestAfterDismissal(trigger:)` therefore
//  waits for the transition and presents on the active window scene, which
//  does not care what is on screen. The rules stay separate from the
//  presenting, in `requestIfEligible(trigger:present:)`.
//
//  Logging an approach is the one finished thing that never reaches a
//  completion screen: its sheet shows "Saved!" and closes itself. So that
//  sheet calls the same entry point as it closes, under its own `trigger`. It
//  is by far the rarest of these moments — four logs in six weeks, against
//  roughly a hundred finished scenarios — and the best qualified: the user has
//  just done, in the real world, the thing the app exists for. Expect it to
//  add a trickle of asks, not a second stream.
//

import Foundation
import StoreKit
import UIKit

@MainActor
final class ReviewPromptManager {

    static let shared = ReviewPromptManager()

    // MARK: - Tuning

    /// How long after a paywall was last put on screen before we will ask.
    ///
    /// A backstop rather than a filter. By construction a whole activity sits
    /// between any paywall and a completion screen, and in production nobody
    /// reaches their first completion within 60 seconds of a paywall — the
    /// 10th percentile is about 107 seconds, and a three-minute cooldown would
    /// have deferred more than a third of first completions. So at this value
    /// the rule costs no reach; what it buys is protection against a future
    /// flow that puts a price and a completion screen back to back.
    private static var paywallCooldownSeconds: Double {
        // Launch argument: -reviewPromptPaywallCooldown 0
        //
        // Not behind `#if DEBUG`, same as the flag override in FeatureFlags.
        // Safe to ship: launch arguments reach `NSArgumentDomain` from the
        // process's argv, and an App Store app launched from the home screen
        // has none.
        if UserDefaults.standard.object(forKey: "reviewPromptPaywallCooldown") != nil {
            return UserDefaults.standard.double(forKey: "reviewPromptPaywallCooldown")
        }
        return 60
    }

    /// How long after a screen starts leaving before the alert is requested.
    ///
    /// Long enough for that screen to finish leaving — a full-screen cover or
    /// a sheet dismissing, or a navigation pop — so the alert lands
    /// on a settled screen instead of arriving mid-transition. Short enough
    /// that it still reads as the consequence of finishing, not as something
    /// that interrupted whatever the user did next.
    private static let presentationDelay: Double = 0.8

    /// Apple's own ceiling is three appearances per 365 days, after which
    /// `requestReview` silently does nothing. Matching it here means our
    /// bookkeeping and iOS's agree, instead of us "asking" into a void and
    /// recording it as an ask that happened.
    private static let maximumLifetimeRequests = 3

    /// Minimum gap between two asks. Well inside Apple's window on purpose —
    /// if the first ask did not land, the second one is worth more months
    /// later than weeks later.
    private static let minimumDaysBetweenRequests: Double = 120

    /// Skip reasons that are NOT worth an event.
    ///
    /// `requestIfEligible` runs on every completion screen and every logged
    /// approach, for every user, and now that everyone is eligible the rate limits are what answer
    /// almost every call after a user's first: once someone has been asked,
    /// each later completion on that version would emit "already asked". That
    /// is derivable from `review_prompt_requested` itself, grows with
    /// engagement rather than with anything going wrong, and is billed per
    /// event.
    ///
    /// The one reason left reportable is the near-miss that cannot be derived
    /// from anything else: a user who would have been asked, but for a paywall
    /// shown moments earlier. Its rate is the number that says whether
    /// `paywallCooldownSeconds` is set anywhere near right — and
    /// `ineligibilityReason()` checks it LAST so that is all it can mean.
    private static let unreportedReasons: Set<String> = [
        "flag_off",
        "already_asked_this_version",
        "lifetime_cap_reached",
        "asked_too_recently",
    ]

    // MARK: - Persisted state

    private static let lastRequestedVersionKey = "review_prompt_last_version"
    private static let lastRequestedAtKey      = "review_prompt_last_requested_at"
    private static let requestCountKey         = "review_prompt_request_count"

    /// Deliberately NOT cleared on sign-out.
    ///
    /// These keys are global for the same reason the subscription cache is:
    /// the thing being rate-limited is a person and their Apple ID, not an app
    /// account. Wiping them on logout would hand anyone a fresh set of asks by
    /// signing out and back in, which is exactly the abuse Apple's cap exists
    /// to stop — and we would be burning the user's three real chances against
    /// a counter we had reset for ourselves.
    static let persistedKeys = [lastRequestedVersionKey, lastRequestedAtKey, requestCountKey]

    // MARK: - Session state

    /// Set by `noteFriction()`. In-memory on purpose: by the time a user has
    /// relaunched the app and finished an activity, a paywall seen before the
    /// relaunch is comfortably outside any cooldown worth having.
    private var lastPaywallShownAt: Date?

    private init() {}

    // MARK: - Friction

    /// Call when the user is shown a price, i.e. a paywall. Restarts the
    /// cooldown during which we will not ask.
    ///
    /// Cheap, so call it freely — a missed call is a real bug (an ask chasing
    /// a payment screen) while a redundant one only moves the clock to where
    /// it already was.
    func noteFriction(source: String) {
        lastPaywallShownAt = Date()
        log("⭐️ ReviewPrompt: paywall cooldown started — \(source)")
    }

    // MARK: - The ask

    /// The production entry point: call at the moment a screen starts leaving
    /// because the user finished something — the Continue tap of a completion
    /// screen, or the log-approach sheet closing itself after a save. Waits
    /// for that screen to finish leaving, then runs the rules and, if they
    /// pass, asks iOS to show the rating alert.
    ///
    /// Fire-and-forget by design — the caller is a view that is about to stop
    /// existing, so nothing here may depend on it. If the app is no longer in
    /// the foreground once the wait is over there is no scene to present on,
    /// and the rules are deliberately NOT run: nothing is recorded, so the
    /// user's next completion gets the ask instead of finding it already spent.
    func requestAfterDismissal(trigger: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.presentationDelay * 1_000_000_000))

            guard let scene = Self.foregroundScene else {
                log("⭐️ ReviewPrompt: no foreground scene at trigger=\(trigger) — leaving the ask for the next completion")
                return
            }
            requestIfEligible(trigger: trigger) {
                AppStore.requestReview(in: scene)
            }
        }
    }

    /// The window scene the user is actually looking at, if any.
    private static var foregroundScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    /// Runs the eligibility rules and, if they all pass, calls `present`.
    ///
    /// `present` is injected rather than hard-wired so that every rule, and
    /// the bookkeeping, can be exercised without StoreKit or a window scene.
    /// `requestAfterDismissal(trigger:)` is what supplies the real one.
    ///
    /// Note what is deliberately *not* measured: whether the alert appeared,
    /// and what the user rated. iOS reports neither, by design. `trigger` is
    /// therefore the only lever the analytics can compare, so it should name
    /// the moment, not the screen class.
    func requestIfEligible(trigger: String, present: () -> Void) {
        if let reason = ineligibilityReason() {
            log("⭐️ ReviewPrompt: skipped (\(reason)) at trigger=\(trigger)")
            if !Self.unreportedReasons.contains(reason) {
                Analytics.capture(Analytics.Event.reviewPromptSkipped, [
                    "trigger": trigger,
                    "reason": reason,
                ])
            }
            return
        }

        let count = UserDefaults.standard.integer(forKey: Self.requestCountKey) + 1
        UserDefaults.standard.set(count, forKey: Self.requestCountKey)
        UserDefaults.standard.set(Date(), forKey: Self.lastRequestedAtKey)
        UserDefaults.standard.set(Self.currentVersion, forKey: Self.lastRequestedVersionKey)

        log("⭐️ ReviewPrompt: requesting review — trigger=\(trigger), lifetime=\(count)")

        // Recorded BEFORE presenting, and recorded even though iOS may show
        // nothing. The counter's job is to bound how often we call, not to
        // count alerts — treating a silent no-op as "did not ask" would let us
        // call on every completion screen forever.
        var properties: [String: Any] = [
            "trigger": trigger,
            "lifetime_request_count": count,
            // The gate used to imply who was being asked (a paid subscriber).
            // It no longer does, so the event has to say — it is the only way
            // to tell later whether the asks are landing on free users,
            // trialists or subscribers.
            "subscription_state": Self.subscriptionState,
        ]
        // Built conditionally rather than with `as Any` — a wrapped `nil`
        // reaches PostHog as a null property, which is not the same thing as
        // an absent one and quietly breaks any average taken over it.
        if let hours = Self.hoursSinceCharge() {
            properties["hours_since_charge"] = Int(hours)
        }
        if let seconds = secondsSincePaywall() {
            properties["seconds_since_paywall"] = Int(seconds)
        }
        Analytics.capture(Analytics.Event.reviewPromptRequested, properties)

        present()
    }

    // MARK: - Rules

    /// Returns `nil` when the user is eligible, otherwise a short snake_case
    /// reason suitable for both the log line and the analytics property.
    ///
    /// The rate limits come BEFORE the cooldown, and the order is load-bearing
    /// for the analytics rather than for the outcome: `paywall_cooldown` is
    /// the only reason that emits an event, so it must only ever be returned
    /// for someone who would otherwise have been asked. Checked first, it
    /// would also swallow every already-asked user who happened to pass a
    /// paywall — which is how the previous `friction_this_session` reason came
    /// to be reported 37 times for people who were never in the audience.
    private func ineligibilityReason() -> String? {
        guard FeatureFlags.shared.reviewPromptEnabled else { return "flag_off" }

        // Never twice on the same build. A user who was asked and declined
        // should not meet the same alert again because they finished another
        // lesson.
        let lastVersion = UserDefaults.standard.string(forKey: Self.lastRequestedVersionKey)
        if lastVersion == Self.currentVersion { return "already_asked_this_version" }

        let count = UserDefaults.standard.integer(forKey: Self.requestCountKey)
        if count >= Self.maximumLifetimeRequests { return "lifetime_cap_reached" }

        if let last = UserDefaults.standard.object(forKey: Self.lastRequestedAtKey) as? Date {
            let days = Date().timeIntervalSince(last) / 86_400
            // Negative means the device clock moved backwards since the last
            // ask. Treat that as "too soon" rather than as a very old ask —
            // the permissive read is the one that burns Apple's cap.
            if days < Self.minimumDaysBetweenRequests { return "asked_too_recently" }
        }

        // Same conservative reading of a backwards clock: a negative interval
        // is below any cooldown, so it blocks.
        if let seconds = secondsSincePaywall(), seconds < Self.paywallCooldownSeconds {
            return "paywall_cooldown"
        }

        return nil
    }

    /// Seconds since a paywall was last put on screen in this process, or
    /// `nil` if none has been.
    private func secondsSincePaywall() -> Double? {
        guard let shownAt = lastPaywallShownAt else { return nil }
        return Date().timeIntervalSince(shownAt)
    }

    /// "free", "trial" or "paid" — see `subscription_state` above.
    private static var subscriptionState: String {
        let subscriptions = SubscriptionManager.shared
        guard subscriptions.isSubscriptionActive else { return "free" }
        return subscriptions.isInTrial ? "trial" : "paid"
    }

    /// Hours since the last charge that actually settled, or `nil` if we have
    /// never observed one. No longer a gate — kept on the event because for
    /// subscribers it is still the most useful thing to know about the moment.
    private static func hoursSinceCharge() -> Double? {
        guard let charged = SubscriptionManager.shared.lastPaidChargeAt else { return nil }
        return Date().timeIntervalSince(charged) / 3_600
    }

    /// Marketing version ("1.0.8"), not the build number.
    ///
    /// Per-release rather than per-build on purpose: a TestFlight build bump
    /// is not a new experience for the user, and keying on it would let an
    /// internal tester's device ask again every upload.
    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Testing

    /// Clears the rate-limiting state so the ask can be exercised more than
    /// once on a device. Launch argument: `-resetReviewPrompt YES`.
    ///
    /// The ask itself is now reachable in a Debug build — finish any activity
    /// and tap Continue, or log an approach — and a development build is the
    /// one place iOS always
    /// shows the alert
    /// (TestFlight never does; the App Store decides for itself). This stays
    /// outside `#if DEBUG` anyway, because confirming the *event* from a
    /// TestFlight or Release build is still worth doing and that is exactly
    /// where a `#if DEBUG` escape hatch is compiled out.
    ///
    /// Safe to ship: launch arguments reach `NSArgumentDomain` from the
    /// process's argv, and an App Store app launched from the home screen has
    /// none. Only Xcode or `simctl` can set this, and it only affects the
    /// process they spawn.
    func resetForTestingIfRequested() {
        guard UserDefaults.standard.bool(forKey: "resetReviewPrompt") else { return }
        Self.persistedKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        log("⭐️ ReviewPrompt: rate-limit state RESET via launch argument")
    }
}
