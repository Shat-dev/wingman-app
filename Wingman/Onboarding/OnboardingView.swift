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
import UIKit  // for UIImage.preparingForDisplay() asset decode warmup

struct OnboardingView: View {
    // Optional binding to control navigation back to Landing
    var showLanding: Binding<Bool>?
    
    @State private var stepIndex: Int = 0
    @State private var selectedOption: String? = nil
    // Multi-select selections for questions where `step.isMultiSelect == true`
    // (currently `barriers` and `goals`). `[String]` preserves tap order so
    // the serialized value is stable; single-select questions ignore this
    // and continue to use `selectedOption`.
    @State private var selectedOptions: [String] = []
    @State private var showStatistic: Bool = false
    @State private var currentStatistic: StatisticContent? = nil
    @State private var stepHistory: [Int] = []
    @State private var statisticSourceStepIndex: Int? = nil
    // Monotonic Int instead of UUID: same `.id()` semantics (bump → view
    // rebuilds), smaller hash, no random allocation per bump.
    @State private var statisticAnimationId: Int = 0
    @State private var isGoingBack: Bool = false  // Track navigation direction

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let steps: [OnboardingStep] = extendedOnboardingSteps
    
    // Default initializer for normal flow
    init() {
        self.showLanding = nil
        log("🎬 OnboardingView initialized (normal flow)")
    }
    
    // Initializer with showLanding binding for anonymous flow
    init(showLanding: Binding<Bool>) {
        self.showLanding = showLanding
        log("🎬 OnboardingView initialized (anonymous flow with showLanding binding)")
    }

    // Store answers for statistics logic
    @State private var answers: [String: String] = [:]

    var body: some View {
        let step = steps[stepIndex]
        
        // Calculate progress for the current view (statistic or regular step)
        let currentProgress: CGFloat = {
            if showStatistic, let src = statisticSourceStepIndex, src >= 0, src < steps.count - 1 {
                // Statistic screen progress: halfway between source and next question
                return CGFloat((steps[src].progress + steps[src + 1].progress) / 2.0)
            } else {
                return CGFloat(step.progress)
            }
        }()
        
        // MARK: - Animated Content Area
        // The top bar is now pinned via `.safeAreaInset(edge: .top)` below so
        // its Y position is decoupled from this content's size. Even when the
        // inner content demands more vertical space than the parent has
        // (causing center-overflow in the old layout), the top bar stays
        // anchored to the safe-area top.
        ZStack {
            // Main content - hide when statistic is showing
            if !showStatistic {
                // Use ForEach with a single item to enable proper transition
                ForEach([stepIndex], id: \.self) { index in
                    Group {
                        if steps[index].type == .name {
                            nameInputContentView(step: steps[index])
                        } else if steps[index].type == .question {
                            questionContentView(step: steps[index])
                        } else if steps[index].type == .loading {
                            loadingContentView(step: steps[index])
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: isGoingBack ? .leading : .trailing),
                        removal: .move(edge: isGoingBack ? .trailing : .leading)
                    ))
                }
            }

            // MARK: - Statistic Content (without its own top bar)
            if showStatistic, let statistic = currentStatistic {
                // No `.background(Color.white)` here — the inner `Color.white`
                // inside `statisticContentView`'s top-anchored ZStack already
                // provides an opaque fill, and the root background covers the
                // rest of the view during the slide.
                statisticContentView(statistic: statistic)
                    .id(statisticAnimationId)
                    .transition(.asymmetric(
                        insertion: .move(edge: isGoingBack ? .leading : .trailing),
                        removal: .move(edge: isGoingBack ? .trailing : .leading)
                    ))
            }
        }
        .clipped() // Clip content during animation to prevent overlap
        // Pin the top bar to the top of the safe area via safe-area-inset.
        // This decouples the top bar's Y coordinate from any size demands
        // placed by inner content — SwiftUI's safe-area system positions
        // the inset view at the safe-area top regardless of whether the
        // content area below overflows. Fixes the 13pt center-overflow
        // shift observed on statistic screens.
        .safeAreaInset(edge: .top, spacing: 0) {
            if step.type != .loading || showStatistic {
                HStack {
                    Button {
                        HapticManager.shared.lightImpact()
                        handleBackButton()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    OnboardingProgressBar(progress: currentProgress)
                        .frame(height: 10)
                }
                .padding(.top, 8)
                .padding(.leading, 10)
                .padding(.trailing, 59)
                .padding(.bottom, 12)
                // Background hoisted to the root (see below) with
                // `.ignoresSafeArea()`, so the safeAreaInset doesn't need
                // its own opaque layer.
            } else {
                // Keep spacing consistent when loading
                Spacer().frame(height: 20)
            }
        }
        // Single opaque background for the whole view, extending through the
        // safe area. Previously there were four stacked `Color.white` layers
        // (root + safeAreaInset HStack + spacer fallback + statistic outer
        // `.background`); each was a separate CALayer, adding unnecessary
        // overdraw during transitions. Consolidated here.
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        // Force the NavigationStack's system nav bar to zero height on every
        // onboarding screen. Without this, iOS decides the empty bar's height
        // non-deterministically (content identity, layout timing, Dynamic
        // Type all factor in), which caused the progress bar on longer-copy
        // statistic screens (e.g. the 25+ age branch) to sit at a different
        // Y than on shorter screens. Hiding the bar entirely makes the custom
        // chevron+progress HStack the authoritative top element on every
        // screen, so its position is pixel-identical everywhere.
        .toolbar(.hidden, for: .navigationBar)
        // Implicit-animation observers were removed here. Every mutation of
        // `stepIndex` and `showStatistic` is already wrapped in an explicit
        // `withAnimation(...)` block at the call site, so removing the four
        // stacked `.animation(_:value:)` modifiers eliminates duplicate
        // transactions per state change without losing any user-visible
        // animation. `isGoingBack` and `statisticAnimationId` are direction
        // flags / view-identity values that should never have been animated.
        // Option A swipe-back: a rightward swipe past a distance/velocity
        // threshold invokes the existing back-button handler. Non-interactive
        // (the page doesn't follow the finger) so this preserves every
        // existing back-navigation path — including statistic dismissal,
        // history reconstruction, and the page-0-to-Landing affordance —
        // without touching handleBackButton() or the animation system.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Only handle when the system's own back chevron would be
                    // visible. The chevron is hidden on the loading page (see
                    // the `step.type != .loading || showStatistic` guard in
                    // the top bar) because that page fires a one-way 3s
                    // timer that transitions past onboarding; allowing a
                    // swipe-back here would leave that timer in flight and
                    // trigger unexpected navigation after the user returned.
                    let currentStep = steps[stepIndex]
                    guard currentStep.type != .loading || showStatistic else { return }

                    // Rightward only.
                    guard value.translation.width > 0 else { return }

                    // Reject mostly-vertical drags (e.g. future scroll views,
                    // incidental finger slips). 120pt of vertical tolerance
                    // matches the proposal's guidance.
                    guard abs(value.translation.height) < 120 else { return }

                    let width = UIScreen.main.bounds.width
                    let passedDistance = value.translation.width > width * 0.3
                    let passedVelocity = value.predictedEndTranslation.width > width * 0.6
                    guard passedDistance || passedVelocity else { return }

                    HapticManager.shared.lightImpact()
                    handleBackButton()
                }
        )
    }

    // MARK: - Name Input Content View (without top bar)
    // Delegates to `NameInputView` — extracted as its own struct so that
    // typing in the TextField only re-evaluates NameInputView, not the
    // entire OnboardingView body (which otherwise runs per keystroke
    // including the safeAreaInset HStack, progress-bar computation, and
    // simultaneousGesture closure re-capture).
    private func nameInputContentView(step: OnboardingStep) -> some View {
        NameInputView(
            title: step.title,
            onNext: { trimmedName in
                answers["name"] = trimmedName

                // Save to AnonymousUserManager if in anonymous mode
                if authManager.isAnonymousUser {
                    AnonymousUserManager.shared.userName = trimmedName
                    log("👻 Saved name to anonymous storage: \(trimmedName)")
                }

                moveToNext()
            },
            onSkip: {
                moveToNext()
            }
        )
    }


    // MARK: - Question Content View (without top bar)
    private func questionContentView(step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text(step.title)
                .font(.manropeSemiBold(size: 24))
                .multilineTextAlignment(.leading)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            // "Select all that apply" hint — rendered only for multi-select
            // questions (barriers, goals). Left-aligned via the parent VStack's
            // `alignment: .leading`. Subtle weight/size so it's read as a
            // functional hint rather than a second heading.
            if step.isMultiSelect {
                Text("Select all that apply")
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(.gray)
            }

            // Options
            if let options = step.options {
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            HapticManager.shared.selection()
                            if step.isMultiSelect {
                                // Toggle: tap again to deselect
                                if let idx = selectedOptions.firstIndex(of: option) {
                                    selectedOptions.remove(at: idx)
                                } else {
                                    selectedOptions.append(option)
                                }
                            } else {
                                selectedOption = option
                            }
                        }) {
                            OptionButton(
                                text: option,
                                isSelected: step.isMultiSelect
                                    ? selectedOptions.contains(option)
                                    : (selectedOption == option)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }

            Spacer()

            // Next Button (full-area tappable). Disabled when the user has made
            // no selection — for multi-select this means "empty selection set",
            // for single-select it means `selectedOption == nil`.
            let hasNoSelection = step.isMultiSelect
                ? selectedOptions.isEmpty
                : (selectedOption == nil)
            let isDisabled = (step.type == .question && hasNoSelection)

            Button(action: {
                HapticManager.shared.lightImpact()
                moveToNext()
            }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.wingmanBlack)
                    .foregroundColor(.wingmanWhiteFF)
                    .cornerRadius(5)
            }
            .buttonStyle(PressableButtonStyle())
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.7 : 1)
            .disabled(isDisabled)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Loading Content View (without top bar)
    private func loadingContentView(step: OnboardingStep) -> some View {
        // check if this exact text needs the smaller font
        let isPersonalizingText = step.title == "Personalizing an experience just for you..."

        return VStack(spacing: 12) {
            Spacer()

            // Loading Text (20pt only for the specific string)
            Text(step.title)
                .font(isPersonalizingText ? .manropeSemiBold(size: 20) : .manropeSemiBold(size: 24))
                .foregroundColor(.wingmanBlack)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Loading Dots Animation (dots are below the text)
            LoadingDotsView()
                .padding(.top, 6)

            Spacer()
        }
        .onAppear {
            // Save name to Supabase only if not anonymous
            if !authManager.isAnonymousUser {
                saveUserName()
            }

            // Wait 3 seconds then complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                log("✅ Finished all questions")
                
                if authManager.isAnonymousUser {
                    // Complete anonymous onboarding (store data locally)
                    authManager.completeAnonymousOnboarding()
                } else {
                    // Complete regular onboarding
                    authManager.completeQuestions()
                }
            }
        }
    }
    
    // MARK: - Statistic Content View (without top bar - uses shared top bar)
    private func statisticContentView(statistic: StatisticContent) -> some View {
        // Top-anchored ZStack so that if the inner content ever exceeds the
        // available vertical space (long headings / facts / large Dynamic
        // Type), the overflow drops downward and gets clipped at the bottom
        // rather than climbing upward into the top bar area — which is what
        // previously caused the progress bar to appear higher on statistic
        // screens with longer copy (e.g. the 25+ age branch).
        ZStack(alignment: .top) {
            Color.white

            VStack(spacing: 0) {
                // Main statistic content
                VStack(spacing: 20) {
                    // Heading
                    Text(statistic.heading)
                        .font(.manropeSemiBold(size: 24))
                        .foregroundColor(.wingmanBlack)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Subheading
                    Text(statistic.subheading)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 40)

                    // Image — reduced from 250pt to 220pt to free up
                    // ~30pt of vertical room for the `.fixedSize`-expanded
                    // text above/below. Without this headroom, the longer
                    // else-branch heading+fact would push the outer view
                    // past its proposed size and trigger center-overflow,
                    // shifting the top bar up by 13pt on statistic screens.
                    Image(statistic.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)

                    Spacer().frame(height: 40)

                    // Fact
                    Text(statistic.fact)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer() // push content up so the button sits at bottom
                }
                .padding(.horizontal, 24)

                // Bottom-right Tap to Continue
                HStack {
                    Spacer()
                    TapToContinueButton {
                        continueFromStatistic()
                    }
                    // make the tappable area a little larger
                    .padding(.trailing, 4)
                    .font(.manropeMedium(size: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Invisible overlay to control tap areas - only right side should progress
            HStack(spacing: 0) {
                // Left half - blocks any tap gestures, not tappable for progression
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Explicitly do nothing - left side should not progress
                        log("🚫 Left side tapped - no action")
                    }
                
                // Right half - tappable area for progression
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        log("✅ Right side tapped - continuing")
                        HapticManager.shared.lightImpact()
                        continueFromStatistic()
                    }
            }
        }
    }

    // MARK: - Move to Next
    func moveToNext() {
        let step = steps[stepIndex]

        // Resolve the answer string. For multi-select questions the chosen
        // options are serialized as a ", "-joined string in tap order — none
        // of the option literals contain ", " so this round-trips losslessly
        // via `components(separatedBy: ", ")` in `restoreSelectionForCurrentStep`.
        // For single-select questions the existing `selectedOption` is used.
        if step.type == .question, let key = step.questionKey {
            let answer: String? = step.isMultiSelect
                ? (selectedOptions.isEmpty ? nil : selectedOptions.joined(separator: ", "))
                : selectedOption

            if let answer = answer {
                answers[key] = answer
                log("Question \(stepIndex + 1): \(answer)")

                // Save to UserDefaults — deferred to the next runloop tick so the
                // disk-touching synchronous write does not happen between the tap
                // and the start of the slide animation. `restoreSelectionForCurrentStep`
                // reads from the in-memory `answers` dict above, not from
                // UserDefaults, so the deferred write is invisible to navigation.
                DispatchQueue.main.async {
                    UserDefaults.standard.set(answer, forKey: "onboarding_\(key)")
                    log("✅ Saved answer:", key, answer)

                    // Save to AnonymousUserManager if in anonymous mode (also
                    // deferred — same rationale, and the in-memory `answers`
                    // already holds the value for any subsequent SwiftUI read).
                    // For authenticated users, we additionally push `age` to
                    // the user_profiles.age_range column so it's available
                    // server-side for all users, not just anonymous-synced ones.
                    if self.authManager.isAnonymousUser {
                        switch key {
                        case "age":
                            AnonymousUserManager.shared.userAge = answer
                            log("👻 Saved age to anonymous storage: \(answer)")
                        case "goals":
                            // For multi-select `goals`, `answer` is the comma-joined
                            // string of chosen options. `AnonymousUserManager.userGoals`
                            // is a `String?` that is only passed through to Supabase
                            // as a String in `AuthManager` — no consumer parses it as
                            // a single option, so the comma-joined form is compatible.
                            AnonymousUserManager.shared.userGoals = answer
                            log("👻 Saved goals to anonymous storage: \(answer)")
                        default:
                            break
                        }
                    } else if key == "age" {
                        // Authenticated (non-anonymous) user — sync age_range
                        // straight to Supabase. Fire-and-forget; local answer
                        // is already persisted in UserDefaults above.
                        Task {
                            await self.authManager.syncAgeRangeToBackend(answer)
                        }
                    }
                }
            }
        }

        // Check if we should show statistic
        if shouldShowStatistic() {
            statisticSourceStepIndex = stepIndex   // 🔥 track source
            isGoingBack = false  // Forward direction
            statisticAnimationId += 1  // Bump identity for fresh animation
            HapticManager.shared.lightImpact()  // Synchronized with the slide-in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                showStatistic = true
            }
            return
        }

        // Move to next step
        proceedToNextStep()
    }

    private func proceedToNextStep() {
        // Set direction to forward
        isGoingBack = false
        
        stepHistory.append(stepIndex)

        if stepIndex < steps.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                stepIndex += 1
            }
            restoreSelectionForCurrentStep()
        }
    }

    private func restoreSelectionForCurrentStep() {
        let step = steps[stepIndex]

        guard step.type == .question,
              let key = step.questionKey else {
            selectedOption = nil
            selectedOptions = []
            return
        }

        if step.isMultiSelect {
            // Round-trip the ", "-joined string back into the ordered array.
            // Single-select state is cleared so there's no stale carry-over
            // if the user navigates from a single- into a multi-select step.
            selectedOption = nil
            if let stored = answers[key], !stored.isEmpty {
                selectedOptions = stored.components(separatedBy: ", ")
            } else {
                selectedOptions = []
            }
            log("🔁 Restored multi-selection for \(key):", selectedOptions)
        } else {
            selectedOptions = []
            selectedOption = answers[key]
            log("🔁 Restored selection for \(key):", selectedOption ?? "none")
        }
    }

    private func continueFromStatistic() {
        guard let sourceIndex = statisticSourceStepIndex else { return }

        // **Add both the source question AND the statistic to history** so back-navigation
        // from the next question goes: next question -> statistic -> source question
        stepHistory.append(sourceIndex)        // The source question
        stepHistory.append(-1)                 // Special marker for statistic screen
        
        log("📝 Added to step history: source=\(sourceIndex), statistic=-1")
        log("📝 Current step history: \(stepHistory)")

        // Set direction to forward (next screen slides in from right)
        isGoingBack = false

        // Close statistic and advance to the next step
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            showStatistic = false
            currentStatistic = nil
            statisticSourceStepIndex = nil
            stepIndex = sourceIndex + 1
        }
        
        log("📝 Advanced to step index: \(stepIndex)")
        restoreSelectionForCurrentStep()
    }

    // New helper to dismiss the statistic and return (without advancing)
    private func dismissStatisticAndReturnToSource() {
        log("🔙 dismissStatisticAndReturnToSource() called")
        
        guard let sourceIndex = statisticSourceStepIndex else {
            log("❌ No source index recorded")
            return
        }
        
        log("🔙 Returning to source question at index: \(sourceIndex)")
        
        // Set direction to back immediately (before any animation)
        isGoingBack = true
        log("🔙 Set isGoingBack = true - statistic will slide out RIGHT")
        
        // Close statistic overlay and navigate back in one animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            showStatistic = false
            stepIndex = sourceIndex
        }
        
        // Clean up and restore after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.currentStatistic = nil
            self.statisticSourceStepIndex = nil
            self.restoreSelectionForCurrentStep()
            log("✅ Returned to source question at index \(sourceIndex)")
        }
    }

    // MARK: - Statistics Logic
    private func shouldShowStatistic() -> Bool {
        let step = steps[stepIndex]

        guard step.type == .question,
              let key = step.questionKey else {
            return false
        }

        // Resolve the answer the same way `moveToNext` does — multi-select
        // joins chosen options, single-select uses `selectedOption`. For
        // `barriers` and `goals` (the only multi-select questions), the
        // returned `StatisticContent` in `getStatistic` is independent of
        // the answer content, so the joined string is accepted.
        let answer: String
        if step.isMultiSelect {
            guard !selectedOptions.isEmpty else { return false }
            answer = selectedOptions.joined(separator: ", ")
        } else {
            guard let single = selectedOption else { return false }
            answer = single
        }

        let ageGroup = answers["age"] ?? ""

        if let stat = getStatistic(ageGroup: ageGroup, questionKey: key, answer: answer) {
            currentStatistic = stat
            // Warm the image cache BEFORE the slide animation starts. The
            // statistic images are large PNGs whose decode would otherwise
            // land on the main thread inside the slide transition, costing
            // ~80-150ms (5-9 dropped frames at 60Hz) on older devices.
            // `preparingForDisplay()` does the decode on the provided queue
            // and caches the bitmap; the subsequent `Image(named:)` in
            // SwiftUI picks up the already-decoded version.
            Self.warmStatisticImage(stat.imageName)
            return true
        }

        return false
    }

    /// Force-decode a named asset off the main thread so the bitmap is ready
    /// by the time SwiftUI constructs the `Image`. Idempotent — UIKit caches
    /// the prepared image. No-op on failure (the `Image` will still resolve,
    /// just without the pre-warm benefit).
    private static func warmStatisticImage(_ name: String) {
        Task.detached(priority: .userInitiated) {
            _ = UIImage(named: name)?.preparingForDisplay()
        }
    }

    private func getStatistic(ageGroup: String, questionKey: String, answer: String) -> StatisticContent? {

        // After "last_approach" question
        if questionKey == "last_approach" {
            if ageGroup == "18-24" {
                return StatisticContent(
                    heading: "Almost half of men your age have never approached a women",
                    subheading: "You are not alone. Millions of men struggle with approaching.",
                    imageName: "stat_never_approached",
                    fact: "45% of men aged 18-24 have never approached a woman"
                )
            } else {
                return StatisticContent(
                    heading: "Almost half of men your age haven't approached in the past year",
                    subheading: "You are not alone. Millions of men struggle with approaching.",
                    imageName: "stat_never_approached",
                    fact: "48% of men aged 26-40 haven't approached in the past year"
                )
            }
        }

        // After "frequency" question
        if questionKey == "approach_frequency" {
            return StatisticContent(
                heading: "Most woman want to be talked to more",
                subheading: "They're just waiting for you to make the first move",
                imageName: "stat_frequency",
                fact: "77% of women aged between 18 and 30 want to be approached more"
            )
        }

        // After "barriers" question
        if questionKey == "barriers" {
            return StatisticContent(
                heading: "Most men regret the chances they didn't make",
                subheading: "Don't join that statistic. Your future self is counting on you.",
                imageName: "stat_regret",
                fact: "63% of single men regret not approaching women when they were younger"
            )
        }

        // After "goals" question
        if questionKey == "goals" {
            return StatisticContent(
                heading: "Half of men don't approach. Most who do, succeed.",
                    subheading: "Which side do you want to be on?",
                    imageName: "stat_success",
                    fact: "58% of men who consistently approach get a number, date, or relationship"
                )
        }

        return nil
    }

    // MARK: - Save to Supabase
    private func saveUserName1() {
        guard let name = answers["name"], !name.isEmpty else { return }
        // Route through SupabaseManager (single source of truth, backed by the
        // Supabase SDK session) instead of the UserDefaults cache which could
        // lag behind the SDK after `.initialSession` restoration.
        guard let userId = SupabaseManager.shared.currentUserId else {
            log("❌ No user ID available")
            return
        }

        log("📤 Saving name to Supabase: \(name)")

        struct UserUpdate: Codable {
            let name: String
            let onboardingCompleted: Bool
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case name
                case onboardingCompleted = "onboarding_completed"
                case updatedAt = "updated_at"
            }
        }

        Task {
            do {
                let update = UserUpdate(
                    name: name,
                    onboardingCompleted: true,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )

                try await SupabaseManager.shared.client
                    .from("users")
                    .update(update)
                    .eq("id", value: userId)
                    .execute()

                log("✅ Name saved to Supabase")

            } catch {
                log("❌ Error saving name: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Save to Supabase (Auth User Metadata)
    private func saveUserName() {
        // Pick the best available name, falling back when the user skipped
        // the name step. We intentionally do NOT derive a name from the
        // user's email — the email prefix can be long, unflattering, or
        // unrelated to their preferred name, and it bypasses the 10-char
        // cap enforced on the typed-name path. Skippers get "User" and can
        // change it from Profile.
        let typed = answers["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name: String
        if !typed.isEmpty {
            name = typed
        } else {
            name = "User"
            log("ℹ️ Name step skipped — using fallback display_name: User")
        }

        let updatedAt = ISO8601DateFormatter().string(from: Date())

        log("📤 Saving user metadata to Supabase")
        log("   • name:", name)
        log("   • onboardingCompleted: true")
        log("   • updatedAt:", updatedAt)

        // Push into the shared store immediately so Home/Profile can render
        // the new name without waiting for the next metadata fetch round-trip.
        UserProfileStore.shared.apply(name: name)

        Task {
            do {
                let client = SupabaseManager.shared.client

                try await client.auth.update(
                    user: UserAttributes(
                        data: [
                            "display_name": AnyJSON.string(name),
                            "onboarding_completed": AnyJSON.bool(true),
                            "updated_at": AnyJSON.string(updatedAt)
                        ]
                    )
                )

                log("✅ User metadata saved successfully")

            } catch {
                log("❌ Error saving user metadata:", error.localizedDescription)
            }
        }
    }

    // MARK: - Back Button
    private func handleBackButton() {
        log("🔙 OnboardingView: handleBackButton called - stepIndex: \(stepIndex)")
        
        // ✅ Back from statistic ALWAYS returns to source question
        if showStatistic {
            log("🔙 Returning from statistic overlay")
            dismissStatisticAndReturnToSource()
            return
        }

        // If on first step (name input) and showLanding is bound, navigate back to Landing
        if stepIndex == 0 {
            if let binding = showLanding {
                log("🔙 On first step with showLanding binding - navigating back to Landing")
                binding.wrappedValue = false
                return
            } else {
                log("🔙 On first step but no showLanding binding")
            }
        }

        // Normal back navigation
        if let previousIndex = stepHistory.popLast() {
            log("🔙 Popped index from history: \(previousIndex)")
            log("🔙 Current step history after pop: \(stepHistory)")
            
            // Check if this is a statistics screen marker
            if previousIndex == -1 {
                // This is a statistic screen - find the source question for this statistic
                // We need to find the most recent non-(-1) step in the history
                var sourceIndex: Int? = nil
                
                // Look backwards through the history to find the source question
                for i in stride(from: stepHistory.count - 1, through: 0, by: -1) {
                    if stepHistory[i] != -1 {
                        sourceIndex = stepHistory[i]
                        break
                    }
                }
                
                if let sourceIndex = sourceIndex {
                    log("🔙 Reconstructing statistic screen for source question: \(sourceIndex)")
                    log("🔙 Navigation depth: User has navigated back through \(stepHistory.count) steps")
                    
                    // Step 1: Clear current statistic state completely and force view refresh
                    currentStatistic = nil
                    showStatistic = false
                    statisticSourceStepIndex = nil
                    log("🔙 Step 1: Completely cleared existing statistic state")
                    
                    // Step 2: Force state update cycle to ensure SwiftUI recognizes changes
                    DispatchQueue.main.async {
                        // Step 3: Set up for back navigation
                        self.isGoingBack = true
                        self.statisticSourceStepIndex = sourceIndex
                        log("🔙 Step 3: Set isGoingBack = true, sourceIndex = \(sourceIndex)")
                        
                        // Step 4: Determine which statistic to show
                        let sourceStep = self.steps[sourceIndex]
                        if let questionKey = sourceStep.questionKey,
                           let answer = self.answers[questionKey] {
                            let ageGroup = self.answers["age"] ?? ""
                            
                            log("🔙 Step 4: Preparing statistic for \(questionKey) = \(answer)")
                            
                            // Step 5: Create new statistic with proper timing.
                            // Reduced from 0.1s to ~2 frames (0.033s) — still
                            // preserves the two-tick settle the dev added to
                            // work around a SwiftUI ordering bug, but cuts
                            // 67ms of perceived lag before the animation fires.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                                let newStatistic = self.getStatistic(ageGroup: ageGroup, questionKey: questionKey, answer: answer)
                                self.currentStatistic = newStatistic
                                log("🔙 Step 5: Set new statistic: \(newStatistic?.heading ?? "nil")")

                                // Step 6: Use helper method for clean state management
                                self.animateStatisticFromBack()
                            }
                        }
                    }
                    return
                } else {
                    log("❌ No source question found in history for statistic")
                }
            } else {
                // Normal question navigation
                // Check if we're trying to navigate to the same step (means we need to pop again)
                if previousIndex == stepIndex {
                    log("🔙 Popped index equals current step, popping again...")
                    if let actualPreviousIndex = stepHistory.popLast() {
                        // Skip any -1 markers (statistics)
                        if actualPreviousIndex == -1 {
                            // There's a statistic screen before this question - show it
                            if let statSourceIndex = stepHistory.last, statSourceIndex != -1 {
                                log("🔙 Found statistic before question, reconstructing statistic for source: \(statSourceIndex)")
                                
                                // Set up for back navigation to statistic
                                DispatchQueue.main.async {
                                    self.isGoingBack = true
                                    self.statisticSourceStepIndex = statSourceIndex
                                    
                                    let sourceStep = self.steps[statSourceIndex]
                                    if let questionKey = sourceStep.questionKey,
                                       let answer = self.answers[questionKey] {
                                        let ageGroup = self.answers["age"] ?? ""
                                        
                                        // Same 0.1s→0.033s reduction as above —
                                        // two-tick settle preserved, 67ms saved.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                                            self.currentStatistic = self.getStatistic(ageGroup: ageGroup, questionKey: questionKey, answer: answer)
                                            self.animateStatisticFromBack()
                                        }
                                    }
                                }
                                return
                            }
                        }
                        
                        log("🔙 Navigating to actual previous step: \(actualPreviousIndex)")
                        isGoingBack = true
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            stepIndex = actualPreviousIndex
                        }
                        restoreSelectionForCurrentStep()
                        return
                    }
                } else {
                    log("🔙 Navigating to previous step: \(previousIndex)")
                    isGoingBack = true
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        stepIndex = previousIndex
                    }
                    restoreSelectionForCurrentStep()
                    return
                }
            }
        }

        log("🔙 No previous step - dismissing view")
        dismiss()
    }
    
    // MARK: - Helper for clean statistic animation from back navigation
    private func animateStatisticFromBack() {
        // Ensure isGoingBack is explicitly set to true
        isGoingBack = true
        
        // Bump id to force SwiftUI to create a fresh view.
        // This is crucial for ensuring animations work on multiple back navigations.
        statisticAnimationId += 1
        
        log("🔙 animateStatisticFromBack() called")
        log("🔙 Generated new animation ID: \(statisticAnimationId)")
        log("🔙 State check - isGoingBack: \(isGoingBack), currentStatistic: \(currentStatistic?.heading ?? "nil")")
        
        // Small delay to ensure all state is properly set.
        // Reduced from 0.05s to ~1 frame (0.016s) — SwiftUI still gets one
        // render pass to observe the id/direction mutations before the
        // animation fires, but we no longer wait three full frames for it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
            log("🔙 About to animate statistic from LEFT (back navigation)")
            log("🔙 Final state - isGoingBack: \(self.isGoingBack), showStatistic: \(self.showStatistic)")
            
            // Animate with explicit state check
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                self.showStatistic = true
            }
            
            // Verify animation completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                log("✅ Back navigation statistic animation completed")
                log("✅ Final state - shown: \(self.showStatistic), isGoingBack: \(self.isGoingBack)")
            }
        }
    }
}

// MARK: - Name Input View
// Extracted from `OnboardingView.nameInputContentView` so state owned by the
// TextField (`name`, `focused`) stays local. Typing no longer re-evaluates
// the parent body, the safeAreaInset HStack, or the global swipe gesture —
// SwiftUI diff scope is limited to this struct.
//
// Haptics, trimming, 10-char limit, focus-on-appear, and the Skip affordance
// are preserved exactly; the only change is where the state lives.
struct NameInputView: View {
    let title: String
    let onNext: (String) -> Void  // receives trimmed name
    let onSkip: () -> Void

    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.manropeSemiBold(size: 24))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Name TextField with character limit
            VStack(alignment: .trailing, spacing: 4) {
                TextField("", text: $name)
                    .placeholder(when: name.isEmpty) {
                        Text("Enter your name")
                            .foregroundColor(.wingmanBlack.opacity(0.3))
                    }
                    .font(.manropeRegular(size: 18))
                    .padding(16)
                    .background(Color.wingmanBlack.opacity(0.10))
                    .cornerRadius(5)
                    .focused($focused)
                    .onChange(of: name) { newValue in
                        // Limit username to 10 characters
                        if newValue.count > 10 {
                            name = String(newValue.prefix(10))
                        }
                    }
                    .padding(.top, 10)

                // Character counter
                Text("\(name.count)/10")
                    .font(.caption)
                    .foregroundColor(name.count > 8 ? .red : .gray)
                    .padding(.trailing, 4)
            }

            // Buttons (moved closer to text field)
            VStack(spacing: 12) {
                // Full-area tappable Next button
                let isNameEmpty = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                Button(action: {
                    HapticManager.shared.lightImpact()
                    focused = false
                    onNext(name.trimmingCharacters(in: .whitespacesAndNewlines))
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .font(.manropeSemiBold(size: 16))
                        .padding()
                        .background(isNameEmpty ? Color.wingmanBlack.opacity(0.5) : Color.wingmanBlack)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .buttonStyle(PressableButtonStyle())
                .contentShape(Rectangle())
                .disabled(isNameEmpty)

                Button("Skip") {
                    HapticManager.shared.lightImpact()
                    focused = false
                    onSkip()
                }
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.wingmanBlack)
                .underline()
                .buttonStyle(PressableButtonStyle())
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .onAppear {
            focused = true
        }
    }
}

// MARK: - Pressable Button Style
// iOS-native press feedback: scale + dim on touch-down, snap back on release.
// Resting state is identical to the underlying view (scale 1.0, opacity 1.0)
// so this is purely additive — no layout or color change at rest. The 0.15s
// spring matches Apple's standard touch-down feel.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

// MARK: - Onboarding Progress Bar
// Extracted from a private method on `OnboardingView` so SwiftUI can give it
// stable identity. As a method it was being re-evaluated on every
// `OnboardingView.body` invocation — including every keystroke in the name
// field — and its `GeometryReader` was re-measuring on each one. As its own
// `View` struct, SwiftUI will skip body evaluation when `progress` hasn't
// changed.
private struct OnboardingProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)

                Capsule()
                    .fill(Color.wingmanBlack)
                    .frame(width: geo.size.width * max(0, min(1, progress)), height: 10)
                    // Heavily-damped spring (0.95) — visually a smooth ramp
                    // with no perceptible overshoot, but feels more native than
                    // an easeInOut sigmoid because the velocity comes off the
                    // user's tap, not from a fixed timing curve.
                    .animation(.spring(response: 0.5, dampingFraction: 0.95), value: progress)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Statistic Content
struct StatisticContent {
    let heading: String
    let subheading: String
    let imageName: String
    let fact: String
}

// MARK: - Extended Steps with Name and Loading
let extendedOnboardingSteps: [OnboardingStep] = [
    // Name Input
    OnboardingStep(
        type: .name,
        title: "What's your name?",
        subtitle: nil,
        options: nil,
        chartImage: nil,
        progress: 0.1,
        questionKey: "name"
    ),

    //1 Age Question
    OnboardingStep(
        type: .question,
        title: "How old are you?",
        subtitle: nil,
        options: ["18-24", "25-34", "35-44", "45+"],
        chartImage: nil,
        progress: 0.2,
        questionKey: "age"
    ),

    //2 Last Approach Question
    OnboardingStep(
        type: .question,
        title: "When was the last time you spoke to a woman in public?",
        subtitle: nil,
        options: ["Within the past week", "Within the past month", "More than a year ago", "Never approached before"],
        chartImage: nil,
        progress: 0.35,
        questionKey: "last_approach"
    ),

    //3 Frequency Question
    OnboardingStep(
        type: .question,
        title: "Do you often want to talk to women but don’t?",
        subtitle: nil,
        options: ["Every time", "Most times", "Sometimes", "Rarely", "No, I usually go for it"],
        chartImage: nil,
        progress: 0.5,
        questionKey: "approach_frequency"
    ),

    //4 Barriers Question
    OnboardingStep(
        type: .question,
        title: "What usually stops you from doing so?",
        subtitle: nil,
        options: [
            "Fear of rejection or being embarrased",
            "Fear of social consequences",
            "Not knowing what to say or how to start",
            "Worrying about coming across wrong",
            "Other"
        ],
        chartImage: nil,
        progress: 0.65,
        questionKey: "barriers"
    ),

    //5 Goals Question
    OnboardingStep(
        type: .question,
        title: "What are you mainly hoping to improve?",
        subtitle: nil,
        options: [
            "Better mindset & confidence",
            "Learning how to approach",
            "Keeping conversations going",
            "Creating attraction and romantic interest",
            "Other"
        ],
        chartImage: nil,
        progress: 0.8,
        questionKey: "goals"
    ),

    // Loading Screen
    OnboardingStep(
        type: .loading,
        title: "Preparing your experience",
        subtitle: nil,
        options: nil,
        chartImage: nil,
        progress: 1.0,
        questionKey: nil
    )
]

// MARK: - Tap to Continue Button
struct TapToContinueButton: View {
    let action: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            Text("Tap to continue")
                .font(.manropeRegular(size: 16))
                .foregroundColor(.gray)
                .opacity(isVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: isVisible)
        }
        .onAppear {
            // Reduced from 1.5s to 0.6s. The right-side tap zone in the
            // statistic view already accepts taps independent of this
            // button's visibility, so the user can always advance — this
            // delay is purely the visual hint reveal.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isVisible = true
            }
        }
    }
}

// MARK: - Loading Dots View (small carousel-like black/gray dots)
// Uses `TimelineView(.periodic)` so the cadence is anchored to a clean
// reference time (computed from `context.date`) rather than depending on
// when `Timer.publish` happened to fire. This eliminates the multi-ms drift
// that the old `Timer.publish` + `@State + onReceive` pattern introduced
// against the display refresh.
struct LoadingDotsView: View {
    private let dotSize: CGFloat = 8

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            // Phase derived from elapsed time — no @State, no Timer.
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.5) % 3

            HStack(spacing: 8) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(idx == phase ? Color.wingmanBlack : Color.gray.opacity(0.45))
                        .frame(width: dotSize, height: dotSize)
                        .animation(.easeInOut(duration: 0.25), value: phase)
                }
            }
        }
    }
}

 // MARK: - TextField Placeholder Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct QuestionFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AuthManager())
    }
}
