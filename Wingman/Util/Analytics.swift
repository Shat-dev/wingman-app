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
import SwiftUI

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

        /// The 30-minute discount window (AuthManager.secondChanceDiscountWindow)
        /// carrying the offer past the modal itself.
        ///
        /// `window_opened` fires when the feature-gate paywall starts serving
        /// the discounted year, `window_expired` when it stops. Together with
        /// `recovery_offer_dismissed` they answer the question the window
        /// exists to answer: how many people come back for the price after
        /// closing the sheet, and how many let the clock run out. Without the
        /// pair, a purchase inside the window is indistinguishable from any
        /// other feature-gate purchase.
        static let recoveryOfferWindowOpened = "recovery_offer_window_opened"
        static let recoveryOfferWindowExpired = "recovery_offer_window_expired"

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

        // The screen between the end of onboarding and the paywall. Drop-off
        // here never reaches pricing, so without it that loss reads as paywall
        // drop-off and points optimisation at the wrong screen.
        //
        // There was a second event here, `referral_step_completed`. It never
        // fired once: the referral screen was cut from the flow long ago and
        // ReferralView was left in the tree unreferenced, so the only thing it
        // ever did was hold a permanently-zero step in the
        // "Onboarding → Pricing Drop-off" funnel. View and event are both gone;
        // if a referral system is built later this comes back with it.
        //
        // Both pact events carry `headline`, which identifies the goal-derived
        // variant the user was shown — the two together are what say whether a
        // given pact wording holds people or loses them.
        static let commitmentPactViewed = "commitment_pact_viewed"
        static let commitmentPactCommitted = "commitment_pact_committed"

        // The optional name screen, first in the onboarding flow.
        //
        // It rides the normal `onboarding_step_viewed` for arrivals
        // (`question_key: "name"`), like every other step. This event is the
        // half that step_viewed cannot express: the screen is the only one a
        // user can leave *unanswered*, and skip-vs-answer is the number that
        // decides whether asking for a name is worth a step in the funnel.
        //
        // It carries `provided` (Bool) and never the name itself — the same
        // reason the person property below is a flag rather than a value.
        // The pact events' `personalized` is the downstream half of the same
        // question: whether being addressed by name converts any better.
        static let onboardingNameAnswered = "onboarding_name_answered"

        /// Person property set alongside the event above, so any funnel or
        /// cohort can be split by whether the user gave a name.
        static let onboardingNameProvidedProperty = "onboarding_name_provided"
    }

    // MARK: - Setup gate
    //
    // PostHog's `setup(_:)` runs on a detached task at launch so the /decide
    // round-trip doesn't compete with OnboardingView's first render. The cost
    // is that anything captured before it lands is *silently dropped* —
    // `isEnabled()` returns false and the SDK just logs.
    //
    // That is not a theoretical window. `LandingView` renders within a few
    // hundred milliseconds of launch, and it lost the race roughly four times
    // out of five: over 30 days 243 people fired `onboarding_started` but only
    // 52 had a Landing screen event, and every new install has to pass through
    // Landing to reach onboarding. In the traces where it survived, the screen
    // event beat setup by as little as 76ms.
    //
    // So calls made before setup are buffered here and replayed in order once
    // it completes, rather than thrown away. The flush happens after
    // `registerEnvironment()`, so replayed events carry `environment` like any
    // other. They do carry the flush timestamp rather than the moment they were
    // fired — the SDK stamps at capture time and exposes no override — but the
    // gap is sub-second and relative order is preserved, so funnels are unaffected.
    //
    // `nonisolated(unsafe)` + an explicit lock rather than an actor: the state
    // is touched from both the main actor (view appearance) and the detached
    // setup task, and the buffered closures capture `[String: Any]` property
    // dictionaries, which aren't Sendable. The lock is the whole contract.

    private nonisolated static let gateLock = NSLock()
    private nonisolated(unsafe) static var isReady = false
    private nonisolated(unsafe) static var pending: [() -> Void] = []

    /// Called once `PostHogSDK.setup(_:)` and the super-property registration
    /// have both run. Replays anything captured before that point, in order.
    nonisolated static func markReady() {
        gateLock.lock()
        guard !isReady else {
            gateLock.unlock()
            return
        }
        isReady = true
        let buffered = pending
        pending = []
        gateLock.unlock()

        buffered.forEach { $0() }
    }

    /// Run `work` now if the SDK is up, otherwise buffer it until it is.
    nonisolated static func whenReady(_ work: @escaping () -> Void) {
        gateLock.lock()
        if isReady {
            gateLock.unlock()
            work()
            return
        }
        pending.append(work)
        gateLock.unlock()
    }

    /// Capture an event. Properties are merged with PostHog's automatic ones
    /// (including the `environment` super-property registered at launch).
    static func capture(_ event: String, _ properties: [String: Any]? = nil) {
        whenReady { PostHogSDK.shared.capture(event, properties: properties) }
    }

    /// Capture a screen view.
    ///
    /// Use `.trackScreenView(_:)` rather than posthog-ios's own
    /// `.postHogScreenView(_:)` — the SDK modifier calls straight through to
    /// `PostHogSDK.screen()` on appear, which is exactly the call that gets
    /// dropped when a screen renders before setup finishes.
    static func screen(_ name: String, _ properties: [String: Any]? = nil) {
        whenReady { PostHogSDK.shared.screen(name, properties: properties) }
    }

    /// Register the `environment` super-property, which every dashboard tile
    /// filters on with an exact `environment = "prod"` match.
    ///
    /// Must run after *every* `PostHogSDK.shared.reset()`, not just once at
    /// launch. reset() deletes the persisted super-properties along with the
    /// distinct_id — posthog-ios's `PostHogStorage.reset()` removes
    /// `.registerProperties` outright — so without a re-register everything
    /// captured for the remainder of that launch carries no `environment` at
    /// all, and an exact-match filter can never match a missing property.
    ///
    /// This was not hypothetical. The one-time identity repair below in
    /// WingmanApp is keyed on a UserDefaults flag that a *fresh* install
    /// doesn't have either, so it fired on the first launch of every new
    /// download and silently unlabelled that entire session — which is the
    /// only session that ever sees the Landing screen. The landing funnels
    /// read zero while the events were arriving normally.
    ///
    /// `nonisolated` because the launch-time caller is a detached task and
    /// this target's default actor isolation is MainActor.
    nonisolated static func registerEnvironment() {
        #if DEBUG
        PostHogSDK.shared.register(["environment": "dev"])
        #else
        PostHogSDK.shared.register(["environment": "prod"])
        #endif
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
        whenReady { PostHogSDK.shared.captureException(error, properties: merged) }
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
        whenReady { PostHogSDK.shared.setPersonProperties(userPropertiesToSet: properties) }
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

extension View {
    /// Capture a `$screen` event when this view appears.
    ///
    /// Drop-in replacement for posthog-ios's `.postHogScreenView(_:)`, with the
    /// same on-appear semantics — the only difference is that it routes through
    /// `Analytics.screen`, so a screen that renders before `PostHogSDK.setup()`
    /// finishes is buffered instead of silently dropped. Landing was losing
    /// roughly four of every five views that way.
    ///
    /// Use this everywhere rather than the SDK modifier: which screens can
    /// render inside the setup window changes with routing, and a screen that
    /// is safe today (Onboarding for a returning user mid-flow, say) is one
    /// launch-path change away from not being.
    func trackScreenView(_ name: String) -> some View {
        onAppear { Analytics.screen(name) }
    }
}
