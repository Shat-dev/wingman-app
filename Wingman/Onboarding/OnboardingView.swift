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

    // Store answers for statistics logic. Owns its own persistence (see
    // `OnboardingAnswerStore`), which dispatches UserDefaults writes off
    // the main thread so the disk I/O doesn't land inside the slide
    // animation.
    @StateObject private var answerStore = OnboardingAnswerStore()

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
                        if steps[index].type == .question {
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
                // In-memory dict updated synchronously (so read-after-write in
                // the current runloop tick sees the new value); UserDefaults
                // persistence is dispatched to a background queue inside the
                // store so the disk write doesn't overlap the slide animation.
                answerStore.setAnswer(answer, forKey: key)
                log("Question \(stepIndex + 1): \(answer)")

                // AuthManager-specific side effects stay deferred to the next
                // runloop tick (same as the pre-refactor behavior): the
                // `isAnonymousUser` read touches main-actor state, so we keep
                // this block on main. The in-memory `answerStore.answers`
                // dict already holds the value for any subsequent SwiftUI read.
                // For authenticated users, we additionally push `age` to
                // user_metadata via Supabase so it's available server-side
                // for all users, not just anonymous-synced ones.
                DispatchQueue.main.async {
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
                        // is already persisted in UserDefaults via the store.
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
            if let stored = answerStore.answers[key], !stored.isEmpty {
                selectedOptions = stored.components(separatedBy: ", ")
            } else {
                selectedOptions = []
            }
            log("🔁 Restored multi-selection for \(key):", selectedOptions)
        } else {
            selectedOptions = []
            selectedOption = answerStore.answers[key]
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

        // Guard: don't show a statistic until the user has actually answered.
        // Multi-select requires at least one selection, single-select requires
        // a non-nil `selectedOption`. The statistic content itself depends only
        // on (questionKey, ageGroup), not on the answer value.
        if step.isMultiSelect {
            guard !selectedOptions.isEmpty else { return false }
        } else {
            guard selectedOption != nil else { return false }
        }

        let ageGroup = answerStore.answers["age"] ?? ""

        if let stat = StatisticContent.for(questionKey: key, ageGroup: ageGroup) {
            currentStatistic = stat
            // Warm the image cache BEFORE the slide animation starts. The
            // statistic images are large PNGs whose decode would otherwise
            // land on the main thread inside the slide transition, costing
            // ~80-150ms (5-9 dropped frames at 60Hz) on older devices.
            // `preparingForDisplay()` does the decode on the provided queue
            // and caches the bitmap; the subsequent `Image(named:)` in
            // SwiftUI picks up the already-decoded version.
            StatisticContent.warmImage(named: stat.imageName)
            return true
        }

        return false
    }

    // MARK: - Save to Supabase
    private func saveUserName1() {
        guard let name = answerStore.answers["name"], !name.isEmpty else { return }
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
        // Name is no longer collected during onboarding (SIWA/Google already
        // supply it; email-signup users can set one from Profile). This call
        // only stamps onboarding_completed — it must not write display_name,
        // because doing so would overwrite the SIWA/Google-provided name
        // already stored in user_metadata.
        let updatedAt = ISO8601DateFormatter().string(from: Date())

        log("📤 Marking onboarding complete in Supabase")

        Task {
            do {
                let client = SupabaseManager.shared.client

                try await client.auth.update(
                    user: UserAttributes(
                        data: [
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

        // If on first step (age question) and showLanding is bound, navigate back to Landing
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
                           let answer = self.answerStore.answers[questionKey] {
                            let ageGroup = self.answerStore.answers["age"] ?? ""
                            
                            log("🔙 Step 4: Preparing statistic for \(questionKey) = \(answer)")
                            
                            // Step 5: Create new statistic with proper timing.
                            // Reduced from 0.1s to ~2 frames (0.033s) — still
                            // preserves the two-tick settle the dev added to
                            // work around a SwiftUI ordering bug, but cuts
                            // 67ms of perceived lag before the animation fires.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                                let newStatistic = StatisticContent.for(questionKey: questionKey, ageGroup: ageGroup)
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
                                       self.answerStore.answers[questionKey] != nil {
                                        let ageGroup = self.answerStore.answers["age"] ?? ""
                                        
                                        // Same 0.1s→0.033s reduction as above —
                                        // two-tick settle preserved, 67ms saved.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                                            self.currentStatistic = StatisticContent.for(questionKey: questionKey, ageGroup: ageGroup)
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
