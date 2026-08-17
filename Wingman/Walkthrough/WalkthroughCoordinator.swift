//
//  WalkthroughCoordinator.swift
//  Wingman
//
//  Owns the first-run walkthrough script. See docs/walkthrough-plan.md.
//
//  The walkthrough is a short linear script, not a mode the user lives in —
//  that distinction is why there is no `.demoMode` lock reason anywhere in the
//  app and why `PracticeService` / `CoursesViewModel` are untouched. This type
//  holds the whole script; the surfaces it drives stay ignorant of it.
//
//  A CARD PER TAB, A SIGN-OFF, AND NOTHING IS REQUIRED.
//
//  The script used to gate itself behind the free scenario: `scenarioPrompt`
//  had no skip by design, so the only way forward was to play a roleplay
//  through to its final scene. Measured on US App Store users (the AU traffic
//  in PostHog is developer speed-runs and has to be filtered out first), that
//  beat cost 11 of the 18 people who reached it, took a median 151 seconds
//  rather than the ~20 the speed-runs suggested, and five of the six who did
//  finish had bailed out of it at least once on the way. It also withheld the
//  free lesson from 14 of 20 starters, because `hasCompletedFreeDemo` — the
//  flag that releases the credit — only flips when the script completes.
//
//  So the scenario is now a tab the tour walks past rather than a toll gate, and
//  the whole script is five taps of showing the app. Nothing in it can fail to
//  load, which is why the whole of the old suppression layer 2
//  (`noteScenarioList`, `noteScenarioUnavailable`, `skipScenarioBeat`) is gone:
//  there is no longer a beat that can strand a user by pointing at content that
//  isn't there.
//
//  DORMANT BY DEFAULT. `start(...)` is the only thing that activates it.
//

import Foundation
import Combine

@MainActor
final class WalkthroughCoordinator: ObservableObject {

    // MARK: - Script

    /// Beats of the script, in order.
    ///
    /// `dormant` and `finished` are both "not running", kept apart so the
    /// difference between *never started* and *just ended* stays legible —
    /// only the second should flip `hasCompletedFreeDemo`.
    ///
    /// Tab order is Home, Courses, Scenarios, Profile, and then back to
    /// Scenarios for the sign-off. Courses comes before Scenarios because the
    /// lessons are where the rest of the app comes from, and a scenario reads as
    /// an invitation rather than a chore once the user knows what else is here.
    /// Profile is last because its copy leans on being empty, which only lands
    /// once the user has seen what fills it.
    ///
    /// The script then returns to Scenarios to close. That is deliberate: the
    /// tour should end on the thing the user can act on, not on the empty chart
    /// it just finished describing. `finish()` and `MainTabView`'s handoff both
    /// agree on that tab.
    ///
    /// Raw values are the `step` property on `walkthrough_step_viewed`, so they
    /// are the funnel's dimension. They changed wholesale with this rewrite;
    /// `walkthrough_completed` is the metric that stays comparable across it.
    enum Step: String {
        case dormant
        case welcome        // Home
        case coursesTour    // Courses
        case scenarioTour   // Scenarios — walked past, never required
        case progressTour   // Profile
        case signOff        // Scenarios again, to close
        case finished
    }

    /// An off-script tap the script answers instead of the app acting on it.
    ///
    /// Every case must resolve to a line of copy and nothing else. **A nudge may
    /// never present a paywall** — an interrupting purchase screen during the
    /// sell is the single worst thing this feature could do.
    ///
    /// Only `.lesson` is reachable today: `coursesTour` is the one beat whose
    /// scrim lets touches through (its copy asks the user to scroll the course
    /// list), and everywhere else the card is the only thing that can be tapped.
    /// The other two are kept because they are the correct answer if any future
    /// beat becomes permeable.
    enum Nudge: String {
        case lesson
        case dailyPractice
        case lockedScenario
    }

    /// Tabs, mirroring the `.tag(_:)` values in `MainTabView`. Kept as an enum
    /// so the script never carries bare integers; the raw values and the tags
    /// must stay in step.
    enum Tab: Int {
        case home = 0
        case courses = 1
        case scenarios = 2
        case profile = 3
    }

    // MARK: - State

    @Published private(set) var step: Step = .dormant {
        didSet {
            guard oldValue != step else { return }
            log("🎬 Walkthrough step: \(oldValue.rawValue) → \(step.rawValue)")

            // One event per beat the user actually reaches. This is the
            // walkthrough's drop-off funnel, and it replaces the abandonment
            // event the plan originally called for — see Analytics.Event.
            // `finished` is excluded because `walkthrough_completed` covers it
            // with a duration.
            guard step != .dormant, step != .finished else { return }
            Analytics.capture(Analytics.Event.walkthroughStepViewed, [
                "step": step.rawValue
            ])
        }
    }

    @Published private(set) var nudge: Nudge?

    /// Set when the script wants the user moved to another tab. The host clears
    /// it via `tabApplied()` once applied, so a repeat of the same tab later in
    /// the script still registers as a change.
    @Published private(set) var requestedTab: Tab?

    /// The step to enter once the host confirms it has switched tabs.
    ///
    /// Only ever set alongside a `requestedTab`, and cleared by `tabApplied()`,
    /// `finish()` and `interrupt()` — so it cannot outlive the request that
    /// created it or strand the script in a half-advanced state.
    private var pendingStep: Step?

    /// Whether the script is currently running.
    var isRunning: Bool {
        step != .dormant && step != .finished
    }

    /// Whether off-script taps should be answered by the script rather than
    /// acted on.
    ///
    /// Identical to `isRunning` now that no beat sends the user off the tab
    /// surfaces — the old `scenarioRunning` exception existed because the user
    /// was inside `PracticeGame` at that point. Kept as its own name because
    /// that is what the call sites mean.
    var isIntercepting: Bool {
        isRunning
    }

    // MARK: - Activation

    /// Starts the script, or leaves it dormant if this user should not see it.
    ///
    /// Idempotent: safe to call from an `onAppear` that fires more than once.
    ///
    /// The two conditions are the whole of suppression layer 1 — a user who has
    /// completed (or been suppressed out of) the demo carries
    /// `hasCompletedFreeDemo == true`, and a subscriber never reaches the demo
    /// branch of RootView in the first place.
    func start(hasCompletedFreeDemo: Bool, hasActiveSubscription: Bool) {
        guard !hasEvaluated else { return }
        hasEvaluated = true

        guard !hasCompletedFreeDemo, !hasActiveSubscription else {
            // Stays `dormant`. Emphatically NOT `finished` — that state means
            // "the user completed the script", and MainTabView hangs
            // `markFreeDemoCompleted()` off reaching it. Sending an ineligible
            // user there would write the demo flag for someone who never saw
            // the walkthrough: harmless for a suppressed user (already set),
            // but for a subscriber it would sit there until their subscription
            // lapsed and then drop them on the post-demo paywall.
            log("🎬 Walkthrough stays dormant — demoSpent: \(hasCompletedFreeDemo), "
                + "subscribed: \(hasActiveSubscription)")
            return
        }

        log("🎬 Walkthrough starting")
        startedAt = Date()
        Analytics.capture(Analytics.Event.walkthroughStarted)
        step = .welcome
    }

    /// Stamped when the script starts, so `walkthrough_completed` can report
    /// how long the whole thing took. Nil for a user who never started it.
    private var startedAt: Date?

    /// Guards `start(...)` instead of `step == .dormant`, because an ineligible
    /// user correctly *stays* dormant and would otherwise re-evaluate (and
    /// re-log) on every `onAppear`.
    private var hasEvaluated = false

    // MARK: - Advancement

    /// The user tapped through a beat.
    ///
    /// Every beat advances from its own card, and every card is tappable —
    /// there is no beat that waits on the user doing something in the app. That
    /// is the whole change: the script can no longer hold anyone anywhere.
    func advance() {
        switch step {
        case .welcome:
            requestTab(.courses, then: .coursesTour)

        case .coursesTour:
            requestTab(.scenarios, then: .scenarioTour)

        case .scenarioTour:
            requestTab(.profile, then: .progressTour)

        case .progressTour:
            // Back to Scenarios to close. The Profile card is the one that
            // reads as an ending ("Last one"), so the sign-off lands on the tab
            // the user is being left on rather than on the empty chart.
            requestTab(.scenarios, then: .signOff)

        case .signOff:
            // Ends the script on Scenarios. `MainTabView` hands the rebuilt tab
            // view back to `.scenarios` so the branch swap does not undo this —
            // see its `onChange`.
            finish()

        case .dormant, .finished:
            break
        }
    }

    /// Ends the script without the user having finished it.
    ///
    /// The case this exists for: a subscription resolving mid-walkthrough.
    /// RevenueCat refreshes on foreground and on a timer, so someone who bought
    /// on paywall #1 can have their entitlement land seconds into the script —
    /// RootView then moves branch 4b → 4a and rebuilds `MainTabView`, taking
    /// the coordinator with it. Left alone, `hasCompletedFreeDemo` was never
    /// written, so if that subscription ever lapsed the whole walkthrough
    /// replayed for someone who had been using the app for a year.
    ///
    /// Reports separately from `finish()` on purpose. Counting these as
    /// completions would inflate the one number that says whether the script
    /// works.
    func interrupt(reason: String) {
        guard isRunning else { return }
        log("🎬 Walkthrough interrupted at \(step.rawValue) — \(reason)")

        var properties: [String: Any] = ["reason": reason, "step": step.rawValue]
        if let startedAt {
            properties["duration_seconds"] = Analytics.elapsedSeconds(since: startedAt)
        }
        Analytics.capture(Analytics.Event.walkthroughInterrupted, properties)

        nudge = nil
        requestedTab = nil
        pendingStep = nil
        step = .finished
    }

    /// Ends the script. The host is responsible for calling
    /// `AuthManager.markFreeDemoCompleted(handoffTo:)` in response, which is
    /// what releases the free lesson credit and routes RootView out of the demo
    /// branch.
    func finish() {
        guard isRunning else { return }
        log("🎬 Walkthrough finished")

        // Captured before the step change, so the event ordering in PostHog
        // matches the causal ordering.
        var properties: [String: Any] = [:]
        if let startedAt {
            properties["duration_seconds"] = Analytics.elapsedSeconds(since: startedAt)
        }
        Analytics.capture(Analytics.Event.walkthroughCompleted, properties)

        nudge = nil
        requestedTab = nil
        pendingStep = nil
        step = .finished
    }

    // MARK: - Nudges

    func showNudge(_ nudge: Nudge) {
        guard isIntercepting else { return }
        log("🎬 Walkthrough nudge: \(nudge.rawValue)")
        self.nudge = nudge

        // What users reach for when told not to. If one surface dominates, the
        // script is pointing at the wrong thing — or the copy is.
        Analytics.capture(Analytics.Event.walkthroughNudgeShown, [
            "surface": nudge.rawValue,
            "step": step.rawValue
        ])
    }

    func dismissNudge() {
        nudge = nil
    }

    // MARK: - Tab request

    /// Called by the host once it has actually switched tabs.
    ///
    /// Applying the pending step here rather than at `advance()` time is what
    /// removes the flash of the *old* tab with no card on it. `step` takes
    /// effect during the render; `requestedTab` is applied from an `onChange`,
    /// which runs *after* the body has been computed. Setting both together
    /// therefore produced one render showing the previous tab with the card
    /// already gone — a visible half-second of Home before Scenarios appeared,
    /// stretched further by the overlay's fade.
    ///
    /// Deferring means the tab switch and the card change land in the same
    /// render instead.
    func tabApplied() {
        requestedTab = nil
        guard let pendingStep else { return }
        self.pendingStep = nil
        step = pendingStep
    }

    /// Moves to `step` only once the host has switched to `tab`. See
    /// `tabApplied()`.
    private func requestTab(_ tab: Tab, then step: Step) {
        pendingStep = step
        requestedTab = tab
    }
}
