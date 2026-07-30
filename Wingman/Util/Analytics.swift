//
//  Analytics.swift
//  Wingman
//
//  Thin façade over PostHogSDK for product analytics.
//
//  Why this exists: the original instrumentation (onboarding, paywall, auth)
//  calls `PostHogSDK.shared.capture` inline at each site. Those calls are
//  deliberately left alone — dashboards depend on them and rewriting them
//  buys nothing. Everything added from here on routes through this type so
//  there's a single place to see which events the app emits, event names
//  live as constants rather than scattered string literals, and swapping or
//  wrapping the SDK later touches one file.
//

import Foundation
import PostHog

enum Analytics {

    /// Canonical event names. snake_case, matching the existing convention
    /// (`paywall_viewed`, `onboarding_step_viewed`, …).
    enum Event {
        // Content engagement — lessons
        static let lessonStarted = "lesson_started"
        static let lessonCompleted = "lesson_completed"

        // End-of-lesson knowledge check. `lesson_quiz_abandoned` is the
        // friction signal that decides whether the feature flag stays on;
        // `lesson_quiz_unavailable` surfaces lessons with no authored
        // questions, and users whose question cache is still cold — without it
        // the graceful fallthrough is invisible in the funnel.
        static let lessonQuizStarted = "lesson_quiz_started"
        static let lessonQuizCompleted = "lesson_quiz_completed"
        static let lessonQuizAbandoned = "lesson_quiz_abandoned"
        static let lessonQuizUnavailable = "lesson_quiz_unavailable"

        // Content engagement — practice scenarios
        static let practiceScenarioStarted = "practice_scenario_started"
        static let practiceScenarioCompleted = "practice_scenario_completed"

        // Content engagement — daily practice questions
        static let dailyChallengeStarted = "daily_challenge_started"
        static let dailyChallengeCompleted = "daily_challenge_completed"

        // Second-chance recovery offer (one-time 50%-off-year-1, shown after
        // a feature-gate paywall dismissal). Mirrors the existing inline
        // `paywall_*` naming so it segments cleanly alongside it.
        static let recoveryOfferViewed = "recovery_offer_viewed"
        static let recoveryOfferDismissed = "recovery_offer_dismissed"
        static let recoveryOfferPurchaseStarted = "recovery_offer_purchase_started"
        static let recoveryOfferPurchased = "recovery_offer_purchased"
        static let recoveryOfferPurchaseFailed = "recovery_offer_purchase_failed"
        static let recoveryOfferNotEligible = "recovery_offer_not_eligible"
    }

    /// Capture an event. Properties are merged with PostHog's automatic ones
    /// (including the `environment` super-property registered at launch).
    static func capture(_ event: String, _ properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    /// Set person properties on the current PostHog person (a `$set`, so
    /// last-write-wins). Works for anonymous users too: passing person
    /// properties opts them into PostHog person processing, so someone who
    /// onboards without ever creating an account still gets a profile you can
    /// view in the Persons list. When they later sign in and `identify` runs
    /// with their real user id, PostHog merges these onto the identified
    /// person, so nothing set here is lost. The SDK de-dupes identical
    /// consecutive calls, so setting the same value twice is a no-op.
    static func setPersonProperties(_ properties: [String: Any]) {
        PostHogSDK.shared.setPersonProperties(userPropertiesToSet: properties)
    }

    /// Seconds between `start` and now, rounded to milliseconds.
    ///
    /// Used for the `duration_seconds` / `time_on_screen_seconds` properties.
    /// Rounding keeps the values readable in PostHog's UI without losing
    /// meaningful precision — nothing here is measured finer than a frame.
    static func elapsedSeconds(since start: Date) -> Double {
        (Date().timeIntervalSince(start) * 1000).rounded() / 1000
    }
}
