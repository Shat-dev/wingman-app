//
//  QuestionFlowView.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import SwiftUI
import Combine
import Supabase
import Auth
import UIKit  // for UIScreen in the swipe-back gesture threshold
import PostHog

struct OnboardingView: View {
    // Optional binding to control navigation back to Landing (anonymous flow)
    var showLanding: Binding<Bool>?

    // MARK: - State
    //
    // A single `screen` enum holds "where am I in the flow" — which
    // collapses the pre-Phase-4 triple of (stepIndex, showStatistic,
    // currentStatistic) plus the (statisticSourceStepIndex,
    // statisticAnimationId) tracking vars. Navigation is push-on-advance /
    // pop-on-back against `history`: no `-1` sentinel, no timed state
    // flips, no forced-identity bumps.
    //
    // `isGoingBack` is kept separate from `screen` because it drives the
    // transition direction (read at the moment of the screen change);
    // baking it into the enum would double the case count for no benefit.
    @State private var screen: OnboardingScreen = .question(index: 0)
    @State private var history: [OnboardingScreen] = []
    @State private var isGoingBack: Bool = false
    // PostHog: fire `onboarding_started` + step 0's `step_viewed` once per
    // mount. SwiftUI's `.onAppear` can re-fire on navigation transitions, so
    // this guard ensures the initial events are emitted exactly once.
    @State private var didLogOnboardingStart = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let steps: [OnboardingStep] = extendedOnboardingSteps

    init() {
        self.showLanding = nil
        log("🎬 OnboardingView initialized (normal flow)")
    }

    init(showLanding: Binding<Bool>) {
        self.showLanding = showLanding
        log("🎬 OnboardingView initialized (anonymous flow with showLanding binding)")
    }

    // Answer persistence. Dispatches UserDefaults writes off the main
    // thread so disk I/O doesn't land inside the slide animation.
    @StateObject private var answerStore = OnboardingAnswerStore()

    // MARK: - Body

    var body: some View {
        ZStack {
            screenContent
                .id(screen)
                .transition(.asymmetric(
                    insertion: .move(edge: isGoingBack ? .leading : .trailing),
                    removal: .move(edge: isGoingBack ? .trailing : .leading)
                ))
        }
        .clipped() // Clip content during animation to prevent overlap
        // Pin the top bar to the top of the safe area. This decouples its
        // Y coordinate from any size demands placed by inner content —
        // SwiftUI's safe-area system positions the inset view at the
        // safe-area top regardless of whether the content area below
        // overflows. Fixes the 13pt center-overflow shift that used to
        // appear on statistic screens with longer copy.
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingTopBar(
                progress: currentProgress,
                showBackButton: shouldShowBackButton,
                onBack: goBack
            )
        }
        // Single opaque background for the whole view, extending through
        // the safe area. Consolidated from 4 previously-stacked white
        // layers (root + safeAreaInset HStack + spacer fallback +
        // statistic outer `.background`) to reduce overdraw during slides.
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        // Force the NavigationStack's system nav bar to zero height on
        // every onboarding screen. Without this, iOS decides the empty
        // bar's height non-deterministically (content identity, layout
        // timing, Dynamic Type all factor in), which caused the progress
        // bar to sit at a different Y on longer-copy screens. Hiding the
        // bar makes the custom chevron+progress HStack the authoritative
        // top element, so its position is pixel-identical everywhere.
        .toolbar(.hidden, for: .navigationBar)
        // Swipe-back: a rightward swipe past a distance/velocity threshold
        // invokes the same back path as the chevron. Non-interactive
        // (the page doesn't follow the finger).
        .simultaneousGesture(swipeBackGesture)
        .onAppear {
            // PostHog: emit `onboarding_started` and step 0's `step_viewed`
            // exactly once per mount. The guard handles SwiftUI re-firing
            // `.onAppear` on incidental view re-mounts.
            guard !didLogOnboardingStart else { return }
            didLogOnboardingStart = true
            PostHogSDK.shared.capture("onboarding_started")
            logStepViewed(screen)
        }
        .postHogScreenView("Onboarding")
    }

    @ViewBuilder
    private var screenContent: some View {
        switch screen {
        case .question(let index):
            QuestionScreen(
                step: steps[index],
                initialSelection: initialSelection(for: steps[index]),
                onNext: handleNext
            )
        case .statistic(_, let content):
            StatisticScreen(
                statistic: content,
                onContinue: continueFromStatistic
            )
        case .loading(let index):
            LoadingScreen(
                step: steps[index],
                onComplete: handleLoadingComplete
            )
        }
    }

    // MARK: - Derived view state

    private var currentProgress: CGFloat {
        switch screen {
        case .question(let index), .loading(let index):
            return CGFloat(steps[index].progress)
        case .statistic(let sourceIndex, _):
            // Halfway between the source question and the next step
            guard sourceIndex + 1 < steps.count else {
                return CGFloat(steps[sourceIndex].progress)
            }
            return CGFloat((steps[sourceIndex].progress + steps[sourceIndex + 1].progress) / 2.0)
        }
    }

    private var shouldShowBackButton: Bool {
        // The loading screen fires a one-way 3s timer that transitions
        // past onboarding; a back affordance would leave the timer in
        // flight and trigger unexpected navigation after the user
        // returned.
        if case .loading = screen { return false }
        return true
    }

    // MARK: - Swipe-back gesture

    private var swipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                // Only handle when the back chevron would be visible —
                // matches the loading-screen suppression above.
                guard shouldShowBackButton else { return }

                // Rightward only.
                guard value.translation.width > 0 else { return }

                // Reject mostly-vertical drags (e.g. future scroll views,
                // incidental finger slips).
                guard abs(value.translation.height) < 120 else { return }

                let width = UIScreen.main.bounds.width
                let passedDistance = value.translation.width > width * 0.3
                let passedVelocity = value.predictedEndTranslation.width > width * 0.6
                guard passedDistance || passedVelocity else { return }

                HapticManager.shared.lightImpact()
                goBack()
            }
    }

    // MARK: - Navigation

    /// Push the current screen onto history, then animate to `newScreen`.
    /// Use for any forward navigation — the history entry is what
    /// `goBack` will return to.
    private func advanceTo(_ newScreen: OnboardingScreen) {
        history.append(screen)
        isGoingBack = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            screen = newScreen
        }
        // PostHog: emit `onboarding_step_viewed` on every forward advance,
        // whatever the screen type. Only forward navigation fires it —
        // `goBack` stays silent so the funnel counts arrivals rather than
        // inflating on back-and-forth.
        logStepViewed(newScreen)
    }

    /// Pop one entry from history and animate back to it. A single
    /// implementation handles back-from-question, back-from-statistic
    /// (returns to source question), and back-from-statistic-that-was-
    /// reached-via-back — history ordering makes all three cases collapse
    /// to a single pop with no special casing.
    private func goBack() {
        log("🔙 goBack from screen: \(screen)")

        // On the very first screen with a `showLanding` binding, flip the
        // binding to return the anonymous-flow user to LandingView.
        if case .question(let index) = screen,
           index == 0,
           history.isEmpty,
           let binding = showLanding {
            log("🔙 On first step with showLanding binding - returning to Landing")
            binding.wrappedValue = false
            return
        }

        guard let previous = history.popLast() else {
            log("🔙 No previous screen - dismissing view")
            dismiss()
            return
        }

        isGoingBack = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            screen = previous
        }
    }

    // MARK: - QuestionScreen.onNext

    /// Called when the user taps Next on a question. Persists the answer,
    /// fires auth-manager side effects, then advances to either a
    /// statistic interstitial or the next step.
    private func handleNext(selection: [String]) {
        guard case .question(let index) = screen else {
            proceedToNextStep()
            return
        }
        let step = steps[index]

        if let key = step.questionKey, !selection.isEmpty {
            // Multi-select: ", "-joined in tap order. Single-select:
            // 1-element array joins to just the chosen option. No option
            // contains ", " so this round-trips losslessly via
            // `components(separatedBy: ", ")` in `initialSelection(for:)`.
            let answer = selection.joined(separator: ", ")

            // In-memory dict updated synchronously (so read-after-write
            // in the current runloop tick sees the new value); the
            // UserDefaults write is dispatched to a background queue
            // inside the store so the disk I/O doesn't overlap the slide.
            answerStore.setAnswer(answer, forKey: key)
            log("Question \(index + 1): \(answer)")

            // Mirror every answer to a PostHog person property, namespaced
            // `onboarding_<key>`, so each user — anonymous ones included — is
            // viewable in PostHog's Persons list with the onboarding answers
            // they gave. Set per-answer rather than at completion so users who
            // drop off partway still record the answers they did give.
            Analytics.setPersonProperties(["onboarding_\(key)": answer])

            // AuthManager-specific side effects stay deferred to the next
            // runloop tick (same as the pre-refactor behavior). The
            // in-memory `answerStore.answers` already holds the value for
            // any subsequent SwiftUI read. For authenticated users, we
            // additionally push `age` to Supabase user_metadata so it's
            // available server-side for all users, not just anonymous
            // ones that get synced at signup.
            DispatchQueue.main.async {
                if self.authManager.isAnonymousUser {
                    switch key {
                    case "age":
                        AnonymousUserManager.shared.userAge = answer
                        log("👻 Saved age to anonymous storage: \(answer)")
                    case "goals":
                        // For multi-select `goals`, `answer` is the
                        // comma-joined string. `AnonymousUserManager.userGoals`
                        // is a `String?` passed through to Supabase as a
                        // String — no consumer parses it as a single
                        // option, so the joined form is compatible.
                        AnonymousUserManager.shared.userGoals = answer
                        log("👻 Saved goals to anonymous storage: \(answer)")
                    default:
                        break
                    }
                } else if key == "age" {
                    // Authenticated user — sync age_range to Supabase.
                    // Fire-and-forget; local answer is already persisted
                    // in UserDefaults via the store.
                    Task {
                        await self.authManager.syncAgeRangeToBackend(answer)
                    }
                }
            }

            // Between-questions statistic? Same (key, age) lookup used
            // before the refactor.
            let ageGroup = answerStore.answers["age"] ?? ""
            if let stat = StatisticContent.for(questionKey: key, ageGroup: ageGroup) {
                // Warm the image cache BEFORE the slide animation starts.
                // The statistic images are large PNGs whose decode would
                // otherwise land on the main thread inside the slide
                // transition, costing ~80–150ms on older devices.
                StatisticContent.warmImage(named: stat.imageName)
                HapticManager.shared.lightImpact()  // Synchronized with the slide-in
                advanceTo(.statistic(sourceIndex: index, content: stat))
                return
            }
        }

        // No statistic — advance directly to the next step.
        proceedToNextStep()
    }

    // MARK: - StatisticScreen.onContinue

    private func continueFromStatistic() {
        proceedToNextStep()
    }

    // MARK: - Shared forward-step routine

    /// Advance to the step after the current one. Works from either a
    /// `.question` (continue after answering with no statistic) or a
    /// `.statistic` (continue after the interstitial).
    private func proceedToNextStep() {
        let currentIndex: Int
        switch screen {
        case .question(let i), .loading(let i):
            currentIndex = i
        case .statistic(let source, _):
            currentIndex = source
        }
        let nextIndex = currentIndex + 1
        guard nextIndex < steps.count else { return }

        let nextScreen: OnboardingScreen = steps[nextIndex].type == .loading
            ? .loading(index: nextIndex)
            : .question(index: nextIndex)
        advanceTo(nextScreen)
    }

    // MARK: - LoadingScreen.onComplete

    private func handleLoadingComplete() {
        // PostHog: completion is the single most important onboarding event.
        // Fires once per user reaching the end of the question flow.
        PostHogSDK.shared.capture("onboarding_completed")

        if authManager.isAnonymousUser {
            authManager.completeAnonymousOnboarding()
        } else {
            authManager.completeQuestions()
        }
    }

    // MARK: - Analytics

    /// Position of `screen` in the full onboarding sequence — question,
    /// statistic and loading screens all counted, in the order the user
    /// actually sees them.
    ///
    /// Derived by walking `steps` rather than tracked with a running counter,
    /// so revisiting a screen after `goBack` reports the same index it did
    /// the first time. Whether a step is followed by a statistic depends only
    /// on its `questionKey` — the `ageGroup` argument picks *which* statistic,
    /// never whether one exists — so the walk is stable regardless of answers.
    private func sequentialIndex(of target: OnboardingScreen) -> Int {
        let ageGroup = answerStore.answers["age"] ?? ""
        var position = 0

        for (index, step) in steps.enumerated() {
            if !target.isStatistic, target.stepIndex == index {
                return position
            }
            position += 1

            guard let key = step.questionKey,
                  StatisticContent.for(questionKey: key, ageGroup: ageGroup) != nil else {
                continue
            }
            if target.isStatistic, target.stepIndex == index {
                return position
            }
            position += 1
        }

        return position
    }

    /// PostHog: `onboarding_step_viewed` for any screen in the flow.
    ///
    /// Question screens carry `question_key`; statistic interstitials and the
    /// loading screen carry `screen_key` instead. Every position between
    /// `onboarding_started` and `onboarding_completed` is now represented,
    /// where previously only the five question screens were.
    private func logStepViewed(_ screen: OnboardingScreen) {
        var properties: [String: Any] = ["step_index": sequentialIndex(of: screen)]

        switch screen {
        case let .question(index):
            guard let key = steps[index].questionKey else { return }
            properties["question_key"] = key
        case let .statistic(sourceIndex, _):
            guard let key = steps[sourceIndex].questionKey else { return }
            properties["screen_key"] = "statistic_\(key)"
        case .loading:
            properties["screen_key"] = "loading"
        }

        PostHogSDK.shared.capture("onboarding_step_viewed", properties: properties)
    }

    // MARK: - QuestionScreen seeding

    /// Each time `screen` changes to a `.question` case, a fresh
    /// `QuestionScreen` is constructed (new identity from `.id(screen)`).
    /// This helper hydrates its initial selection from the in-memory
    /// answer store so a previously-answered question is restored with
    /// the chosen option(s) highlighted.
    private func initialSelection(for step: OnboardingStep) -> [String] {
        guard step.type == .question,
              let key = step.questionKey,
              let stored = answerStore.answers[key],
              !stored.isEmpty else {
            return []
        }
        // For single-select this yields a 1-element array; for
        // multi-select it restores the comma-joined list in tap order.
        // No option contains ", " so the round-trip is lossless.
        return stored.components(separatedBy: ", ")
    }

}

#Preview {
    OnboardingView()
        .environmentObject(AuthManager())
}
