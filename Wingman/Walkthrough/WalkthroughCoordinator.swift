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
//  DORMANT BY DEFAULT. `start(...)` is the only thing that activates it, and
//  nothing calls that yet — the overlay (W5) is what starts the script,
//  because a running script with nothing rendering it would intercept taps and
//  give the user no feedback. Until then every method here is a no-op and
//  every published value holds its initial state.
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
    enum Step: String {
        case dormant
        case welcome
        case scenarioPrompt
        case scenarioRunning
        case scenarioDone
        case lessonsTour
        case benefits
        case finished
    }

    /// An off-script tap the script answers instead of the app acting on it.
    ///
    /// Every case must resolve to a line of copy and nothing else. **A nudge may
    /// never present a paywall** — an interrupting purchase screen during the
    /// sell is the single worst thing this feature could do.
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
                "step": step.rawValue,
                "skipped_scenario": didSkipScenario
            ])
        }
    }

    @Published private(set) var nudge: Nudge?

    /// Set when the script wants the user moved to another tab. The host clears
    /// it via `tabApplied()` once applied, so a repeat of the same tab later in
    /// the script still registers as a change.
    @Published private(set) var requestedTab: Tab?

    /// True when the scenario beat was skipped rather than played. Copy
    /// branches on this — congratulating someone for something they did weeks
    /// ago reads wrong.
    @Published private(set) var didSkipScenario = false

    /// Set when the scenario list arrives before the script has reached the
    /// prompt, and says the beat is not worth playing.
    ///
    /// Recorded rather than acted on, because jumping the step out from under
    /// a beat the user is currently reading desynchronises their next tap: a
    /// jump straight to `lessonsTour` during `welcome` means the pending tap
    /// advances to `benefits` and the tour is never shown. `advance()` reads
    /// this instead, so the skip happens at a beat boundary.
    private var scenarioBeatUnavailable = false

    /// Whether the user has tapped Next on the scenario instruction card.
    ///
    /// Separate from `step` because dismissing that card must NOT advance the
    /// script — the scenario is still the only way forward. Reset by
    /// `noteScenarioAbandoned()` so someone who backs out of the scenario is
    /// told what to do again.
    @Published private(set) var scenarioPromptAcknowledged = false

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

    /// Whether the script is currently waiting for this specific scenario to be
    /// opened — i.e. whether its card should be drawing attention to itself.
    ///
    /// Asked by the scenario list rather than pushed at it, so the coordinator
    /// stays ignorant of how the emphasis is drawn.
    func isAwaitingScenario(orderIndex: Int) -> Bool {
        step == .scenarioPrompt && orderIndex == AuthManager.freeScenarioOrderIndex
    }

    /// Whether off-script taps should be answered by the script rather than
    /// acted on.
    ///
    /// False during `scenarioRunning` because the user is inside `PracticeGame`
    /// at that point — the tab surfaces are not visible, and the overlay is
    /// hidden for the same reason (see `TabBarVisibilityManager`).
    var isIntercepting: Bool {
        isRunning && step != .scenarioRunning
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
            // "the user completed the script", and W6 hangs
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
    /// Deliberately does nothing at `scenarioPrompt`: that beat ends when the
    /// user actually opens the scenario, which is the one required action in
    /// the whole script. There is no skip.
    func advance() {
        switch step {
        case .welcome:
            // The scenario list may already have told us the beat is not worth
            // playing. Acting on it here rather than the moment we learned it
            // keeps every step change on a beat boundary.
            if scenarioBeatUnavailable {
                didSkipScenario = true
                requestTab(.courses, then: .lessonsTour)
            } else {
                requestTab(.scenarios, then: .scenarioPrompt)
            }

        case .scenarioPrompt, .scenarioRunning:
            break

        case .scenarioDone:
            requestTab(.courses, then: .lessonsTour)

        case .lessonsTour:
            step = .benefits

        case .benefits:
            finish()

        case .dormant, .finished:
            break
        }
    }

    /// The user opened the free scenario.
    func noteScenarioOpened() {
        guard step == .scenarioPrompt else { return }
        step = .scenarioRunning
    }

    /// The free scenario reached its final scene.
    ///
    /// Hooks the existing completion signal rather than a new one —
    /// `PracticeGameViewModel.gameCompleted` is set only by `triggerCompletion()`,
    /// so dismissing partway through never lands here.
    func noteScenarioCompleted() {
        guard step == .scenarioRunning else { return }
        step = .scenarioDone
    }

    /// The user left the scenario without finishing it.
    ///
    /// Hands the script back to the prompt so the card re-appears and asks
    /// again. There is no skip, but there is also no trap: `scenarioRunning`
    /// has no other exit, and the overlay is deliberately hidden in that step,
    /// so without this a back-tap would strand the walkthrough with nothing on
    /// screen to advance it.
    ///
    /// No-ops after a genuine completion, which has already moved the step to
    /// `scenarioDone`.
    func noteScenarioAbandoned() {
        guard step == .scenarioRunning else { return }
        log("🎬 Walkthrough: scenario left unfinished — returning to the prompt")

        // Captured before the step change, so it lands ahead of the
        // `walkthrough_step_viewed` that returning to the prompt emits and the
        // ordering in PostHog matches the causal ordering.
        //
        // `attempt` counts how many times this user has bailed out of the
        // scenario within one run of the script: a first bail is a distraction,
        // a third is the beat not working.
        scenarioAbandonCount += 1
        Analytics.capture(Analytics.Event.walkthroughScenarioAbandoned, [
            "attempt": scenarioAbandonCount
        ])

        // Show the instruction again. They left without playing it, so the
        // prompt has not done its job yet.
        scenarioPromptAcknowledged = false

        step = .scenarioPrompt
    }

    /// The user tapped Next on the scenario instruction.
    ///
    /// Dismisses the card only. The step deliberately stays at
    /// `scenarioPrompt`: the scenario itself is still the one required action,
    /// so this is an acknowledgement, not an advance. `advance()` remains a
    /// no-op at this step for exactly that reason.
    func acknowledgeScenarioPrompt() {
        guard step == .scenarioPrompt else { return }
        log("🎬 Walkthrough: scenario instruction acknowledged")
        scenarioPromptAcknowledged = true
    }

    /// Times the user has entered and left the free scenario without finishing
    /// it, for this run of the script. Not persisted — a force-quit ends the
    /// run, and carrying the count across launches would conflate two separate
    /// sittings.
    private var scenarioAbandonCount = 0

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
    /// `AuthManager.markFreeDemoCompleted()` in response (W6), which is what
    /// routes RootView into the post-demo ask.
    func finish() {
        guard isRunning else { return }
        log("🎬 Walkthrough finished (scenario skipped: \(didSkipScenario))")

        // Captured before the step change, so the event ordering in PostHog
        // matches the causal ordering: completed → (RootView re-renders) →
        // paywall_viewed(source=postDemo).
        var properties: [String: Any] = ["skipped_scenario": didSkipScenario]
        if let startedAt {
            properties["duration_seconds"] = Analytics.elapsedSeconds(since: startedAt)
        }
        Analytics.capture(Analytics.Event.walkthroughCompleted, properties)

        nudge = nil
        requestedTab = nil
        pendingStep = nil
        step = .finished
    }

    // MARK: - Suppression layer 2

    /// Feeds the scenario list to the script so it can decide whether the
    /// scenario beat is worth playing.
    ///
    /// Two reasons to skip it, both of which would otherwise strand the user on
    /// a beat with no way forward:
    ///
    ///   1. **Already completed.** Layer 2 of the existing-user suppression.
    ///      Layer 1 (`AuthManager.userHasPreExistingProgress`) only sees lesson
    ///      progress, because scenario progress lives in a table rather than in
    ///      `user_metadata` and is not worth a fetch on the launch path. This
    ///      catches the cohort layer 1 misses — chiefly a lapsed ex-subscriber
    ///      with scenario progress and no completed lessons — and doubles as
    ///      the resume path for anyone who force-quit mid-walkthrough.
    ///   2. **Not there at all.** The free scenario is identified by
    ///      `order_index`, so unpublishing or reordering it in the `scenarios`
    ///      table would leave the script pointing at nothing. Skipping beats
    ///      trapping the user on an instruction they cannot follow.
    ///
    /// Safe to call repeatedly and from any step; it only acts while the script
    /// is waiting on the scenario.
    func noteScenarioList(_ practices: [Practice]) {
        guard !practices.isEmpty else { return }

        guard step == .welcome || step == .scenarioPrompt else { return }

        guard let free = practices.first(where: {
            $0.orderIndex == AuthManager.freeScenarioOrderIndex
        }) else {
            skipScenarioBeat(reason: "freeScenarioUnavailable")
            return
        }

        if free.isCompleted {
            skipScenarioBeat(reason: "scenarioAlreadyComplete")
        }
    }

    /// The free scenario could not be opened — its game data failed to load.
    ///
    /// Skips the beat. This is the only escape from `scenarioPrompt` that is
    /// not the user playing the scenario, and it exists because the beat has no
    /// skip control by design: an offline user who taps the card and gets
    /// nothing would otherwise sit there permanently, with lessons and daily
    /// practice nudge-blocked behind a script that cannot advance.
    ///
    /// Note this is not a skip *offered* to the user — it fires only when the
    /// app has already failed to deliver the scenario.
    func noteScenarioUnavailable() {
        guard step == .welcome || step == .scenarioPrompt else { return }
        skipScenarioBeat(reason: "scenarioLoadFailed")
    }

    /// Marks the scenario beat as not worth playing.
    ///
    /// Applied immediately only when the user is already looking at the prompt;
    /// otherwise it is recorded and `advance()` acts on it at the next beat
    /// boundary. Jumping the step under a beat the user is mid-read of
    /// desynchronises their pending tap.
    ///
    /// Skips to `lessonsTour` rather than `scenarioDone` — the congratulations
    /// beat exists to land a scenario the user just played, and firing it for
    /// someone who played it weeks ago (or not at all) reads as a bug.
    private func skipScenarioBeat(reason: String) {
        guard !scenarioBeatUnavailable else { return }
        log("🎬 Walkthrough skipping scenario beat — \(reason)")
        scenarioBeatUnavailable = true

        if step == .scenarioPrompt {
            didSkipScenario = true
            requestTab(.courses, then: .lessonsTour)
        }

        Analytics.capture(Analytics.Event.walkthroughSuppressed, ["reason": reason])
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
