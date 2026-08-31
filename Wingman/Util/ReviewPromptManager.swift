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
//  were both removed (see the note in `WingmanApp.RootView`), and for several
//  builds the app asked for a rating exactly zero times.
//
//  This brings the ask back, behind the gate that rejection implies: the user
//  must have judged the app with their own money. Concretely, the ask happens
//  a full day after a **real charge** has settled — not after a purchase, and
//  not during the trial. Someone still inside the 3-day trial has paid nothing
//  and is about to be asked to; someone charged 24 hours ago has already made
//  that decision and kept the app. Those are opposite populations to put a
//  five-star prompt in front of, which is the whole design.
//
//  WHY THE ELIGIBILITY RULES ARE STRICTER THAN "IS SUBSCRIBED"
//
//  `requestReview` is not a prompt we control. iOS decides whether to show
//  anything at all, and Apple caps it at three appearances per user per 365
//  days. Every call spent on a badly-chosen moment is a call that is gone —
//  so the rules below are about spending few asks well, not many asks often.
//
//  The single most damaging moment is right after the user has been shown a
//  price. `noteFriction()` exists for that: any paywall or recovery offer in
//  this session disqualifies the whole session, because a five-star prompt
//  chasing a payment ask is how an app collects one-star reviews.
//
//  This type only *decides*. Presenting is the caller's job — see the
//  `requestIfEligible(trigger:present:)` contract below.
//

import Foundation

@MainActor
final class ReviewPromptManager {

    static let shared = ReviewPromptManager()

    // MARK: - Tuning

    /// How long after the money actually leaves the account before we ask.
    ///
    /// A day. Long enough that the charge is a settled fact rather than a
    /// fresh notification the user is still reacting to, short enough that
    /// they are still inside the stretch where the app is a habit worth
    /// rating. Wall-clock, deliberately: sandbox accelerates *subscription
    /// periods*, not purchase timestamps, so this stays 24 real hours in
    /// review builds too and App Review cannot trip the ask by accident.
    private static var minimumHoursSinceCharge: Double {
        // Launch argument: -reviewPromptMinHours 0
        //
        // Not behind `#if DEBUG`, same as the flag override in FeatureFlags —
        // and this one is what makes the feature testable at all. Sandbox
        // compresses the 3-day trial to a couple of minutes, so a tester can
        // reach a converted, non-trial entitlement quickly; what they cannot
        // compress is `latestPurchaseDate`, which is real wall-clock. Without
        // this, verifying the ask end-to-end means waiting a literal day.
        if UserDefaults.standard.object(forKey: "reviewPromptMinHours") != nil {
            return UserDefaults.standard.double(forKey: "reviewPromptMinHours")
        }
        return 24
    }

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
    /// `requestIfEligible` runs on every completion screen, for every user. If
    /// each one emitted a skip, the overwhelming majority of the events would
    /// say "this person is not a paying subscriber" — true, already known from
    /// subscription data, and billed per event.
    ///
    /// What is actually worth measuring is the near-miss: someone who IS in
    /// the target audience and still did not get asked. Every reason left
    /// reportable below describes that case, so the event count stays
    /// proportional to the population the feature is about.
    private static let unreportedReasons: Set<String> = [
        "flag_off",
        "not_subscribed",
        "in_trial",
        "no_charge_recorded",
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

    /// Set by `noteFriction()`, cleared only by a fresh process. Session-scoped
    /// rather than persisted: seeing a paywall poisons *this* sitting, not the
    /// user's whole relationship with the app.
    private var sawFrictionThisSession = false

    private init() {}

    // MARK: - Friction

    /// Call when the user is shown a price: a paywall, or the second-chance
    /// recovery offer. Disqualifies the rest of this session.
    ///
    /// Cheap and idempotent, so call it freely — a missed call is a real bug
    /// (an ask chasing a payment screen) while a redundant one costs nothing.
    func noteFriction(source: String) {
        guard !sawFrictionThisSession else { return }
        sawFrictionThisSession = true
        log("⭐️ ReviewPrompt: session disqualified by friction — \(source)")
    }

    // MARK: - The ask

    /// Runs the eligibility rules and, if they all pass, calls `present`.
    ///
    /// The closure exists because the actual request belongs to SwiftUI's
    /// `@Environment(\.requestReview)` action, which can only be read inside a
    /// `View`. Splitting it this way keeps every rule in one testable place
    /// and leaves the view holding nothing but the trigger.
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
        ]
        // Built conditionally rather than with `as Any` — a wrapped `nil`
        // reaches PostHog as a null property, which is not the same thing as
        // an absent one and quietly breaks any average taken over it.
        if let hours = Self.hoursSinceCharge() {
            properties["hours_since_charge"] = Int(hours)
        }
        Analytics.capture(Analytics.Event.reviewPromptRequested, properties)

        present()
    }

    // MARK: - Rules

    /// Returns `nil` when the user is eligible, otherwise a short snake_case
    /// reason suitable for both the log line and the analytics property.
    ///
    /// Ordered cheapest-and-most-common first so the usual "not eligible" path
    /// is a couple of comparisons.
    private func ineligibilityReason() -> String? {
        guard FeatureFlags.shared.reviewPromptEnabled else { return "flag_off" }

        if sawFrictionThisSession { return "friction_this_session" }

        let subscriptions = SubscriptionManager.shared
        guard subscriptions.isSubscriptionActive else { return "not_subscribed" }

        // The rule the whole feature is built around. An active entitlement is
        // not enough — a trialist has an active entitlement and has paid
        // nothing, and asking them is asking someone mid-decision.
        guard !subscriptions.isInTrial else { return "in_trial" }

        guard let hours = Self.hoursSinceCharge() else { return "no_charge_recorded" }
        guard hours >= Self.minimumHoursSinceCharge else { return "charge_too_recent" }

        // Never twice on the same build. A user who was asked and declined
        // should not meet the same alert again because they opened the app on
        // a different day.
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

        return nil
    }

    /// Hours since the last charge that actually settled, or `nil` if we have
    /// never observed one.
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
    /// Deliberately NOT behind `#if DEBUG`, for the same reason
    /// `FeatureFlags.readCommitmentPactEnabled` is not: this feature cannot be
    /// tested in a Debug build at all. It requires a real settled charge,
    /// which means real StoreKit, which means Release — precisely where a
    /// `#if DEBUG` escape hatch is compiled out and useless.
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
