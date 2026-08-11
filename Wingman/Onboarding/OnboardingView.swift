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

    // MARK: - Swipe-back state

    /// Horizontal offset of the current page while a swipe-back drag is in
    /// flight. Zero at rest; the page rides this 1:1 with the finger.
    @State private var dragX: CGFloat = 0

    /// True from the first tracked drag movement until the page is back at
    /// rest (or has been replaced). Gates the previous-page preview, and is
    /// held through the snap-back animation deliberately — keying the
    /// preview off `dragX > 0` alone would drop it the instant `dragX` was
    /// set to 0, leaving white behind a page that is still travelling.
    @State private var isDragging = false

    /// Guards against a second drag landing while the commit animation and
    /// its deferred swap are still in flight.
    @State private var isCommittingBack = false

    /// Progress-bar fill, held as its own state rather than derived from
    /// `screen` on the fly.
    ///
    /// `commitSwipeBack` swaps `screen` inside a `disablesAnimations`
    /// transaction, which would also suppress a derived bar and make it
    /// jump on every swipe. Holding it separately lets that path animate
    /// the bar explicitly while the page swap itself stays instant.
    ///
    /// Seeded from step 0 because `screen` starts at `.question(index: 0)`;
    /// `steps` is `extendedOnboardingSteps`, so the two agree by
    /// construction.
    @State private var displayedProgress: CGFloat = CGFloat(extendedOnboardingSteps[0].progress)

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
            // Previous page, drawn underneath at 30% parallax: it travels
            // from -0.3·width toward 0 as the current page is dragged right,
            // matching UIKit's pop where the revealed page moves a fraction
            // of the distance the top one does. Non-interactive — the drag
            // owns the whole surface until it resolves.
            if isDragging, let previous = swipeBackPreviewScreen {
                pageWrapper(for: previous)
                    .offset(x: 0.3 * (dragX - pageWidth))
                    .allowsHitTesting(false)
            }

            pageWrapper(for: screen)
                .id(screen)
                // `.push` rather than the hand-paired
                // `.asymmetric(.move, .move)` this replaces.
                //
                // That pair slid both pages edge-to-edge at full opacity, so
                // there was no seam anywhere in the frame. Question screens
                // carry no background of their own — the only white is the
                // root `.background` below, shared by both — which left the
                // eye with black text sliding across an unbroken white field
                // and nothing to read as a page boundary.
                //
                // `.push` translates *and* crossfades. Captured mid-flight in
                // the simulator, the outgoing page is dimmed and the incoming
                // one still faint, the two visibly separated rather than
                // locked together; that separation is what makes the step
                // read as a page turn instead of a carousel.
                //
                // It also declares insertion and removal as one value —
                // `.push(from: .trailing)` enters from the trailing edge and
                // exits to the leading one — so forward and back cannot be
                // wired inconsistently. Both directions were checked frame by
                // frame after this change.
                //
                // iOS 16.0+. The app target's floor is 16.6 (the 26.0 in the
                // project-level config is overridden there), so no guard.
                .transition(.push(from: isGoingBack ? .leading : .trailing))
                .offset(x: dragX)
        }
        .clipped() // Clip content during animation to prevent overlap
        // Pin the top bar to the top of the safe area. This decouples its
        // Y coordinate from any size demands placed by inner content —
        // SwiftUI's safe-area system positions the inset view at the
        // safe-area top regardless of whether the content area below
        // overflows. Fixes the 13pt center-overflow shift that used to
        // appear on statistic screens with longer copy.
        .safeAreaInset(edge: .top, spacing: 0) {
            // Chrome stays pinned while the page slides under it, rather
            // than travelling with the page. Moving it into `pageWrapper`
            // would mean re-deriving its Y from page content and give up
            // the `safeAreaInset` anchoring the comment above documents as
            // the fix for the statistic screens' 13pt shift.
            OnboardingTopBar(
                progress: displayedProgress,
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
        // Swipe-back: the page tracks the finger and commits to the same
        // back target as the chevron past a distance/velocity threshold.
        // `.simultaneousGesture` rather than `.gesture` so the option rows,
        // the Next button and the statistic screen's tap zones keep
        // receiving touches — SwiftUI gives tap recognition priority under
        // the drag's `minimumDistance`.
        .simultaneousGesture(swipeBackGesture)
        .onAppear {
            // PostHog: emit `onboarding_started` and step 0's `step_viewed`
            // exactly once per mount. The guard handles SwiftUI re-firing
            // `.onAppear` on incidental view re-mounts.
            //
            // Step 0 is now the name screen, so this is where its arrival is
            // recorded — `advanceTo` only fires for steps the user moves
            // *onto*, and nothing ever advances onto the first one.
            guard !didLogOnboardingStart else { return }
            didLogOnboardingStart = true
            Analytics.capture("onboarding_started")
            logStepViewed(screen)
        }
        .trackScreenView("Onboarding")
    }

    /// One onboarding page plus the opaque fill that makes two pages
    /// overlapping legal.
    ///
    /// The fill is load-bearing, not cosmetic. During a swipe-back drag the
    /// previous page renders underneath this one, and `QuestionScreen` and
    /// `LoadingScreen` draw no background of their own — the flow's only
    /// white is the root `.background` sitting behind both. Without a
    /// per-page fill the two pages' text renders on top of each other.
    /// `StatisticScreen` already stacks its own `Color.white`, so this
    /// brings the other two in line rather than special-casing them.
    ///
    /// `.background` (not a `ZStack`) plus an explicit greedy frame keeps
    /// this layout-neutral for the non-drag case: every screen already
    /// expands to fill, so the frame is non-binding and the fill simply
    /// paints behind what was already there.
    private func pageWrapper(for target: OnboardingScreen) -> some View {
        screenContent(for: target)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }

    @ViewBuilder
    private func screenContent(for target: OnboardingScreen) -> some View {
        switch target {
        case .question(let index):
            // The name and growth-projection steps travel as `.question`
            // screens so the whole navigation layer — history, progress,
            // swipe-back, analytics — needed no new case; only the body they
            // render differs.
            switch steps[index].type {
            case .name:
                NameScreen(
                    step: steps[index],
                    initialName: answerStore.answers[OnboardingNameKey.answerKey] ?? "",
                    onContinue: handleNameContinue
                )
            case .growthProjection:
                GrowthProjectionScreen(onContinue: proceedToNextStep)
            default:
                QuestionScreen(
                    step: steps[index],
                    initialSelection: initialSelection(for: steps[index]),
                    onNext: handleNext
                )
            }
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

    /// Progress-bar value for a given screen.
    ///
    /// Split out from the old `currentProgress` computed property so both
    /// back paths can set `displayedProgress` for the screen they are about
    /// to move to, instead of reading it back off `screen` afterwards —
    /// which on the swipe path would race the deferred swap.
    private func progress(for target: OnboardingScreen) -> CGFloat {
        switch target {
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
        // The loading screen fires a one-way ~6.2s sequence that transitions
        // past onboarding; a back affordance would leave that chain in
        // flight and trigger unexpected navigation after the user
        // returned.
        if case .loading = screen { return false }
        return true
    }

    // MARK: - Interactive swipe-back

    /// Width used for both the drag thresholds and the parallax offset.
    ///
    /// Deliberately still `UIScreen.main.bounds` (deprecated since iOS 16)
    /// rather than a `GeometryReader`. The app is portrait-locked to iPhone
    /// — `UISupportedInterfaceOrientations` is portrait-only — so this
    /// equals the container width, and wrapping the paging stack in a
    /// `GeometryReader` would restructure the `safeAreaInset` layout that
    /// the body documents as the fix for the statistic screens' 13pt shift.
    /// Swap it for a measured width if the app ever ships landscape or iPad.
    private var pageWidth: CGFloat { UIScreen.main.bounds.width }

    /// The screen drawn underneath the current one during a drag, or `nil`
    /// to suppress the preview.
    ///
    /// Two suppressed cases:
    ///   - `history` is empty. Back then hands off to LandingView (anonymous
    ///     flow) or dismisses — neither is a screen this view can render, so
    ///     the drag reveals the root white instead.
    ///   - `.loading`. Mounting it fires a Supabase write and a ~6.2s
    ///     auto-advance chain from `onAppear` that nothing cancels, so even
    ///     a brief preview would start the flow finishing itself (and start
    ///     its haptic tick loop). It is
    ///     never actually in `history` today — it is the terminal step, so
    ///     `advanceTo` never pushes it — but the guard keeps that from
    ///     becoming a latent trap if a step is ever added after it.
    private var swipeBackPreviewScreen: OnboardingScreen? {
        guard let previous = history.last else { return nil }
        if case .loading = previous { return nil }
        return previous
    }

    /// Drag gesture that lets the current page track the user's finger,
    /// committing to the chevron's back target past a distance or velocity
    /// threshold and snapping back otherwise.
    ///
    /// Replaces an `.onEnded`-only version that left the page motionless for
    /// the whole drag: a swipe that cleared the threshold jumped straight to
    /// the spring, and one that didn't gave no feedback at all, because
    /// nothing had ever moved.
    private var swipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                // Only handle when the back chevron would be visible —
                // matches the loading-screen suppression above.
                guard shouldShowBackButton, !isCommittingBack else { return }

                // Rightward only, and reject mostly-vertical drags — the
                // same two guards the pre-interactive version applied on
                // release, now applied per movement.
                guard value.translation.width > 0,
                      abs(value.translation.height) < 120 else { return }

                isDragging = true

                // Mild rubber-band past the edge so the page can't be
                // dragged arbitrarily far off-screen.
                let raw = value.translation.width
                dragX = raw <= pageWidth ? raw : pageWidth + (raw - pageWidth) * 0.3
            }
            .onEnded { value in
                guard shouldShowBackButton, !isCommittingBack else { return }

                // Thresholds unchanged from the pre-interactive version:
                // 30% of the width travelled, or a predicted end past 60%.
                let passedDistance = value.translation.width > pageWidth * 0.3
                let passedVelocity = value.predictedEndTranslation.width > pageWidth * 0.6

                guard value.translation.width > 0,
                      abs(value.translation.height) < 120,
                      passedDistance || passedVelocity else {
                    snapBack()
                    return
                }

                commitSwipeBack()
            }
    }

    /// Return the page to rest after a drag that didn't clear the threshold.
    private func snapBack() {
        guard isDragging else { return }

        withAnimation(.easeOut(duration: 0.18)) {
            dragX = 0
        }
        // Hold the preview until the page has finished covering it again.
        // Dropping it the moment `dragX` is assigned would blink white in
        // behind a page that is still travelling.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if dragX == 0 { isDragging = false }
        }
    }

    /// Carry the page the rest of the way off-screen, then swap to the
    /// previous screen underneath it.
    private func commitSwipeBack() {
        isCommittingBack = true
        // Belt-and-braces: a flick can clear the *velocity* threshold with
        // barely any travel, so `dragX` may still be near zero here. Forcing
        // the flag on guarantees the previous page is behind the departing
        // one for the slide-off below, instead of a flash of empty white.
        isDragging = true
        HapticManager.shared.tap()
        log("🔙 swipe-back commit from screen: \(screen)")

        withAnimation(.easeOut(duration: 0.22)) {
            dragX = pageWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // The swap and the offset reset land together with animations
            // off. Without that the revealed page would animate a second
            // time — its own `.push` insertion, plus the spring `goBack`
            // uses — on top of a gesture the user has already finished,
            // which reads as the page bouncing back in from the right.
            var transaction = Transaction()
            transaction.disablesAnimations = true

            let target = withTransaction(transaction) { () -> OnboardingScreen? in
                isGoingBack = true
                let previous = popBackTarget()
                if let previous {
                    screen = previous
                }
                dragX = 0
                isDragging = false
                return previous
            }

            // The bar is animated separately precisely because the swap
            // above is not — derived from `screen` it would jump on this
            // path. Same curve the chevron uses, so both back routes look
            // identical from the user's side.
            if let target {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    displayedProgress = progress(for: target)
                }
            }

            isCommittingBack = false
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
            displayedProgress = progress(for: newScreen)
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

        guard let previous = popBackTarget() else { return }

        isGoingBack = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            screen = previous
            displayedProgress = progress(for: previous)
        }
    }

    /// Where a back navigation from the current screen goes, popping
    /// `history` as a side effect.
    ///
    /// Returns `nil` when the navigation is fully handled here rather than
    /// by moving to another onboarding screen — the anonymous flow's
    /// hand-off back to LandingView, or a dismiss with nothing left to pop.
    ///
    /// Extracted from `goBack` so the chevron and the swipe share one
    /// definition of where "back" means. They differ only in how the
    /// resulting screen change is animated; if they each carried their own
    /// copy of this, the two routes could drift on the `showLanding` and
    /// empty-history edge cases.
    private func popBackTarget() -> OnboardingScreen? {
        // On the very first screen with a `showLanding` binding, flip the
        // binding to return the anonymous-flow user to LandingView.
        if case .question(let index) = screen,
           index == 0,
           history.isEmpty,
           let binding = showLanding {
            log("🔙 On first step with showLanding binding - returning to Landing")
            binding.wrappedValue = false
            return nil
        }

        guard let previous = history.popLast() else {
            log("🔙 No previous screen - dismissing view")
            dismiss()
            return nil
        }

        return previous
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
            // Keyed on `hasSession`, NOT `isLegacyAnonymousUser`. A guest holds a
            // real `auth.users` row, so their answers belong in user_metadata
            // like anyone else's — and unlike the old anonymous flow they never
            // run `syncAnonymousDataToBackend` (linking preserves the id, so
            // there is nothing to transfer). Branching on the legacy flag here
            // would strand every guest's age and goals in local-only storage
            // that nothing ever uploads.
            DispatchQueue.main.async {
                if !self.authManager.hasSession {
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
                HapticManager.shared.tap()  // Synchronized with the slide-in
                advanceTo(.statistic(sourceIndex: index, content: stat))
                return
            }
        }

        // No statistic — advance directly to the next step.
        proceedToNextStep()
    }

    // MARK: - NameScreen.onContinue

    /// Called when the user leaves the name screen, with the sanitised name
    /// or `""` for a skip.
    ///
    /// Deliberately not routed through `handleNext`: that path mirrors every
    /// answer into a PostHog person property, and a real name is exactly the
    /// thing that must not be shipped to analytics. Only the fact that one
    /// was given is recorded here.
    private func handleNameContinue(_ rawName: String) {
        let name = OnboardingNameKey.sanitized(rawName)

        if let name {
            answerStore.setAnswer(name, forKey: OnboardingNameKey.answerKey)
            log("👤 Onboarding name captured (\(name.count) chars)")
        } else {
            // Skipped. Clear rather than no-op: the user may have typed a
            // name, continued, swiped back, and changed their mind — leaving
            // the earlier value in place would have the pact address them by
            // a name they just declined to give.
            answerStore.clearAnswer(forKey: OnboardingNameKey.answerKey)
            log("👤 Onboarding name skipped")
        }

        // The name itself is never sent — only whether one was given, which
        // is all the funnel needs to split on.
        Analytics.capture(Analytics.Event.onboardingNameAnswered, ["provided": name != nil])
        Analytics.setPersonProperties([
            Analytics.Event.onboardingNameProvidedProperty: name != nil
        ])

        proceedToNextStep()
    }

    /// Push the captured name everywhere the app reads a display name from.
    ///
    /// Three destinations, because three different readers exist:
    ///   - `UserProfileStore` — the client-side source of truth (Profile,
    ///     `HomeViewModel.userName`, HomeView's fallback). Synchronous, so
    ///     the greeting is correct even with no network.
    ///   - Supabase `user_metadata.display_name` — what HomeView's greeting
    ///     prefers, and what survives a reinstall or new device.
    ///   - `AnonymousUserManager.userName` — the legacy no-session path.
    ///     `syncAnonymousDataToBackend` already carries that key into
    ///     `display_name` at signup, so that branch needs nothing new.
    ///
    /// Called once, at the end of the flow, rather than when the name screen
    /// is left. That ordering is what makes the skip clean: a user who types
    /// a name, goes back and skips has written nothing outside the answer
    /// store, so there is no display name to walk back — and in particular
    /// nothing has overwritten a name a social sign-in may already have
    /// supplied. It also keeps this `auth.update` clear of the one
    /// `LoadingScreen` fires on appear, instead of racing it.
    private func persistDisplayNameIfCaptured() {
        guard let name = OnboardingNameKey.sanitized(
            answerStore.answers[OnboardingNameKey.answerKey]
        ) else {
            log("👤 No onboarding name to persist — leaving display_name untouched")
            return
        }

        UserProfileStore.shared.apply(name: name)

        if authManager.hasSession {
            Task {
                await authManager.syncDisplayNameToBackend(name)
            }
        } else {
            AnonymousUserManager.shared.userName = name
            log("👻 Saved name to anonymous storage")
        }
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
        Analytics.capture("onboarding_completed")

        // Before handing off: the answers are final here, so this is where a
        // name the user actually gave becomes their display name. No-ops for
        // anyone who skipped.
        persistDisplayNameIfCaptured()

        if authManager.isLegacyAnonymousUser {
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
    /// `onboarding_started` and `onboarding_completed` is represented,
    /// including the name screen, which reports `question_key: "name"` like
    /// any other step — it is a `.question` screen with a `questionKey`, so it
    /// needed no special case here.
    ///
    /// Note for anyone reading historical data: `step_index` counts positions
    /// in the flow as the user sees them, so adding the name screen at the
    /// front shifted every later step by one. Split funnels on `question_key`
    /// / `screen_key`, which are stable, rather than on the index.
    private func logStepViewed(_ screen: OnboardingScreen) {
        var properties: [String: Any] = ["step_index": sequentialIndex(of: screen)]

        switch screen {
        case let .question(index):
            guard let key = steps[index].questionKey else { return }
            // The growth projection asks nothing, so it reports under
            // `screen_key` alongside the statistic and loading interstitials.
            // Keeping `question_key` to steps that actually take an answer is
            // what lets a funnel split on it without filtering.
            if steps[index].type == .growthProjection {
                properties["screen_key"] = key
            } else {
                properties["question_key"] = key
            }
        case let .statistic(sourceIndex, _):
            guard let key = steps[sourceIndex].questionKey else { return }
            properties["screen_key"] = "statistic_\(key)"
        case .loading:
            properties["screen_key"] = "loading"
        }

        // Through `Analytics`, not `PostHogSDK` directly. The name screen's
        // step_viewed is now the first event the flow emits, fired from
        // OnboardingView's `.onAppear` — the exact window where PostHog's
        // `setup(_:)` may not have completed and the SDK silently drops
        // whatever it is handed. `Analytics.capture` buffers until setup
        // lands and replays in order; see the setup-gate note in Analytics.
        Analytics.capture("onboarding_step_viewed", properties)
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
