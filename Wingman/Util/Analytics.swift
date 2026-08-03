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

        // First-run walkthrough.
        //
        // `walkthrough_suppressed` is the odd one out: it shipped ahead of the
        // rest because it is the only way to see the suppression decision,
        // which is otherwise silent and changes the denominator of every
        // funnel below it. `reason` distinguishes the layers
        // (`existingProgress`, `scenarioAlreadyComplete`, `freeScenarioUnavailable`,
        // `scenarioLoadFailed`).
        //
        // There is deliberately NO `walkthrough_abandoned`. Abandonment is a
        // force-quit, which cannot be captured honestly at the moment it
        // happens; firing something on backgrounding instead would conflate
        // "took a phone call" with "gave up". `walkthrough_step_viewed` answers
        // the same question better — it shows exactly which beat loses people,
        // rather than collapsing all of them into one number.
        static let walkthroughSuppressed = "walkthrough_suppressed"
        static let walkthroughStarted = "walkthrough_started"
        static let walkthroughStepViewed = "walkthrough_step_viewed"
        static let walkthroughNudgeShown = "walkthrough_nudge_shown"
        static let walkthroughCompleted = "walkthrough_completed"

        /// The user opened the free scenario and left before finishing it.
        ///
        /// The one genuinely interactive beat in the script, and the only one
        /// a user can enter and back out of. It was technically observable —
        /// returning to the prompt re-fires `walkthrough_step_viewed` with
        /// `step = scenarioPrompt` — but only as a *repeat* of a beat, which
        /// is indistinguishable from ordinary re-entry and quietly inflates
        /// that step's count in the drop-off funnel. Naming it directly keeps
        /// the step funnel honest and makes the retry loop countable.
        static let walkthroughScenarioAbandoned = "walkthrough_scenario_abandoned"

        /// Ended without the user finishing it, for a reason the app knows
        /// about — today, a subscription landing mid-script. Kept apart from
        /// `walkthrough_completed` so these can never inflate the completion
        /// rate, which is the one number that says whether the script works.
        static let walkthroughInterrupted = "walkthrough_interrupted"

        // The one free lesson, released when the walkthrough finishes.
        // Completion is not a separate event — `lesson_completed` carries an
        // `is_free_lesson` property instead, so the two never disagree about
        // what counts as finishing a lesson.
        static let freeLessonClaimed = "free_lesson_claimed"

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

        /// Dismissing Apple's payment sheet, on each of the two paywalls.
        ///
        /// Not a failure — nothing broke, the user said no — so these are
        /// deliberately kept out of `*_purchase_failed`, whose rate is a
        /// health metric rather than a demand one. But they are the largest
        /// single drop in the purchase funnel, and without them
        /// `*_purchase_started` has no terminal event for its most common
        /// outcome: the only way to count cancellations was
        /// `started − succeeded − failed`, which silently absorbs dropped
        /// events, crashes and app kills, and cannot be broken down.
        ///
        /// RevenueCat surfaces the same user action two ways — a
        /// `userCancelled` flag on the success path and error code 1 on the
        /// throwing path — so both emit this event and distinguish
        /// themselves with `detection` rather than splitting into two names.
        static let paywallPurchaseCancelled = "paywall_purchase_cancelled"
        static let recoveryOfferPurchaseCancelled = "recovery_offer_purchase_cancelled"

        // Approach logging — the app's core value action, and until now the
        // only major loop with no instrumentation at all. Everything else
        // here (lessons, practice, streaks) is content consumption; this is
        // the one event that says a user did the thing the app is for, so it
        // belongs in every activation and retention cohort.
        static let approachLogged = "approach_logged"
        static let approachLogFailed = "approach_log_failed"
        static let approachDeleted = "approach_deleted"

        // What happens upstream of the paywall.
        //
        // `paywall_viewed` already fires, but it cannot say what sent the
        // user there. `lesson_gate_blocked` is the specific tap that hit the
        // subscription gate, which is what makes the lesson→purchase funnel
        // measurable rather than inferred.
        //
        // `course_locked_encountered` is the progression gate, not the
        // paywall — a user who keeps hitting it is blocked by content
        // sequencing, and no amount of pricing work fixes that.
        static let courseLockedEncountered = "course_locked_encountered"
        static let lessonGateBlocked = "lesson_gate_blocked"

        /// The entitlement going active → inactive. Revenue churn was
        /// previously invisible: purchases were captured on the way in and
        /// nothing on the way out, so no insight could separate a retained
        /// subscriber from a lapsed one. Fires on the edge only — see
        /// SubscriptionManager, where a cold cache read must not emit it.
        static let subscriptionExpired = "subscription_expired"

        // Account deletion. `account_deletion_started` is client-side and
        // deliberately fires before the request leaves, because the client's
        // PostHog person is reset moments later. The completion half is
        // captured server-side by the edge function — see
        // supabase/functions/delete-user-account/index.ts.
        static let accountDeletionStarted = "account_deletion_started"

        // Restore. A subscriber who cannot restore looks exactly like churn
        // in every revenue metric while actually being a support ticket.
        static let purchasesRestored = "purchases_restored"
        static let purchasesRestoreFailed = "purchases_restore_failed"

        // Re-engagement channel. The grant rate gates whether daily reminders
        // can be a retention lever at all.
        static let notificationPermissionResult = "notification_permission_result"
        static let dailyReadingGoalSet = "daily_reading_goal_set"

        // The two screens between the end of onboarding and the paywall.
        // Drop-off here never reaches pricing, so without these it reads as
        // paywall drop-off and points optimisation at the wrong screen.
        static let ratingPromptContinued = "rating_prompt_continued"
        static let referralStepCompleted = "referral_step_completed"
    }

    /// Capture an event. Properties are merged with PostHog's automatic ones
    /// (including the `environment` super-property registered at launch).
    static func capture(_ event: String, _ properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    /// Report a caught error to PostHog error tracking.
    ///
    /// Routes to `captureException`, which emits `$exception` with the
    /// error's domain, code and stack metadata already extracted — so these
    /// land in the Errors view and group with each other, rather than
    /// becoming yet another custom event nobody builds an insight on.
    ///
    /// `context` names the operation that failed (`"approach_save"`,
    /// `"purchases_restore"`), since `NSError.domain` alone rarely says which
    /// call site produced it. Pair it with a domain event where the failure
    /// is also a product signal and not just a defect — a restore that finds
    /// no entitlement isn't an error, but a restore that throws is both.
    static func captureError(
        _ error: Error,
        context: String,
        _ properties: [String: Any]? = nil
    ) {
        var merged: [String: Any] = ["context": context]
        properties?.forEach { merged[$0.key] = $0.value }
        PostHogSDK.shared.captureException(error, properties: merged)
    }

    /// The current distinct ID and session ID, for handing to server-side
    /// code so its events land on the same person and session as the client's.
    ///
    /// Returns the header pair PostHog's backend SDKs read
    /// (`X-POSTHOG-DISTINCT-ID` / `X-POSTHOG-SESSION-ID`). Used by the
    /// account-deletion call, where the server has to be the one to record
    /// the outcome but must not invent its own identity for the user: the
    /// Supabase user id is a *lowercase* UUID, while `identify()` on the
    /// client passes Swift's `uuidString`, which is uppercase. Sending the
    /// raw id from the server would silently create a second person for
    /// every deletion.
    static func correlationHeaders() -> [String: String] {
        var headers = ["X-POSTHOG-DISTINCT-ID": PostHogSDK.shared.getDistinctId()]
        if let sessionId = PostHogSDK.shared.getSessionId() {
            headers["X-POSTHOG-SESSION-ID"] = sessionId
        }
        return headers
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
