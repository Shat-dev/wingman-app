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
//  nothing calls that yet — the mascot overlay (W5) is what starts the script,
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

    /// An off-script tap the mascot answers instead of the app acting on it.
    ///
    /// Every case must resolve to a mascot line and nothing else. **A nudge may
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
    /// it via `clearTabRequest()` once applied, so a repeat of the same tab
    /// later in the script still registers as a change.
    @Published private(set) var requestedTab: Tab?

    /// True when the scenario beat was skipped rather than played. Copy
    /// branches on this — congratulating someone for something they did weeks
    /// ago reads wrong.
    @Published private(set) var didSkipScenario = false

    /// How many scenarios the catalogue actually contains, learned from the
    /// list the app already fetches. Nil until then.
    ///
    /// The closing beat used to quote a hardcoded "15 scenarios", which is a
    /// live database table — publish a sixteenth and the pitch is quietly
    /// wrong. Copy degrades to a numberless phrasing while this is nil.
    @Published private(set) var scenarioCount: Int?

    /// How many lessons the app actually ships. Nil until counted.
    ///
    /// Counted on a hop off the launch frame rather than inline, because it
    /// parses every bundled course file. The closing beat that quotes it is
    /// four taps and a scenario away, so it is always ready in practice; the
    /// copy degrades to a numberless phrasing if it somehow is not.
    @Published private(set) var lessonCount: Int?

    /// Set when the scenario list arrives before the script has reached the
    /// prompt, and says the beat is not worth playing.
    ///
    /// Recorded rather than acted on, because jumping the step out from under
    /// a beat the user is currently reading desynchronises their next tap: a
    /// jump straight to `lessonsTour` during `welcome` means the pending tap
    /// advances to `benefits` and the tour is never shown. `advance()` reads
    /// this instead, so the skip happens at a beat boundary.
    private var scenarioBeatUnavailable = false

    /// Whether the script is currently running.
    var isRunning: Bool {
        step != .dormant && step != .finished
    }

    /// Whether off-script taps should be answered by the mascot rather than
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

        // Off this frame: MainTabView is mid-first-render and this parses every
        // bundled course file. Only the closing beat needs the answer.
        Task { [weak self] in
            let count = LessonDataService.shared.totalLessonCount()
            self?.lessonCount = count
            log("🎬 Walkthrough: catalogue has \(count) lessons")
        }
    }

    /// Stamped when the script starts, so `walkthrough_completed` can report
    /// how long the whole thing took. Nil for a user who never started it.
    private var startedAt: Date?

    /// Guards `start(...)` instead of `step == .dormant`, because an ineligible
    /// user correctly *stays* dormant and would otherwise re-evaluate (and
    /// re-log) on every `onAppear`.
    private var hasEvaluated = false

    // MARK: - Advancement

    /// The user tapped through a mascot beat.
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
                step = .lessonsTour
                requestedTab = .courses
            } else {
                step = .scenarioPrompt
                requestedTab = .scenarios
            }

        case .scenarioPrompt, .scenarioRunning:
            break

        case .scenarioDone:
            step = .lessonsTour
            requestedTab = .courses

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
    /// Hands the script back to the prompt so the mascot re-appears and asks
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
        step = .scenarioPrompt
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

        // Recorded regardless of step, because the closing beat quotes it and
        // that beat comes long after this runs.
        scenarioCount = practices.count

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
            step = .lessonsTour
            requestedTab = .courses
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

    func clearTabRequest() {
        requestedTab = nil
    }
}
