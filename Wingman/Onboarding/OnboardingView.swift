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

struct OnboardingView: View {
    // Optional binding to control navigation back to Landing
    var showLanding: Binding<Bool>?
    
    @State private var stepIndex: Int = 0
    @State private var selectedOption: String? = nil
    @State private var userName: String = ""
    @State private var showStatistic: Bool = false
    @State private var currentStatistic: StatisticContent? = nil
    @State private var stepHistory: [Int] = []
    @State private var statisticSourceStepIndex: Int? = nil
    @State private var statisticAnimationId: UUID = UUID()  // Unique ID to force view refresh
    @State private var isGoingBack: Bool = false  // Track navigation direction

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @FocusState private var isNameFieldFocused: Bool

    let steps: [OnboardingStep] = extendedOnboardingSteps
    
    // Default initializer for normal flow
    init() {
        self.showLanding = nil
        print("🎬 OnboardingView initialized (normal flow)")
    }
    
    // Initializer with showLanding binding for anonymous flow
    init(showLanding: Binding<Bool>) {
        self.showLanding = showLanding
        print("🎬 OnboardingView initialized (anonymous flow with showLanding binding)")
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
                statisticContentView(statistic: statistic)
                    .background(Color.white)
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
                        handleBackButton()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                            // DEBUG: Measure the top bar HStack's Y via its first child
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onChange(of: showStatistic) { newValue in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            let f = geo.frame(in: .global)
                                            print("🟣 [HStack Y showStatistic→\(newValue)] frame=\(f)")
                                        }
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)

                    progressBar(progress: currentProgress)
                        .frame(height: 10)
                        // DEBUG: Multiple redundant probes to capture the
                        // progress bar's actual Y coordinate. Remove after
                        // diagnosis.
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: ProgressBarYKey.self,
                                        value: geo.frame(in: .global).origin.y
                                    )
                                    .onAppear {
                                        let f = geo.frame(in: .global)
                                        print("🟢 [onAppear] ProgressBar frame=\(f) | size=\(geo.size) | stepIndex=\(stepIndex) | showStatistic=\(showStatistic) | heading='\(currentStatistic?.heading.prefix(45).description ?? "—")'")
                                    }
                                    .onChange(of: stepIndex) { _ in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            let f = geo.frame(in: .global)
                                            print("🔵 [stepIndex→\(stepIndex)] ProgressBar frame=\(f) | size=\(geo.size) | showStatistic=\(showStatistic)")
                                        }
                                    }
                                    .onChange(of: showStatistic) { newValue in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            let f = geo.frame(in: .global)
                                            print("🟠 [showStatistic→\(newValue)] ProgressBar frame=\(f) | size=\(geo.size) | heading='\(currentStatistic?.heading.prefix(45).description ?? "—")'")
                                        }
                                    }
                            }
                        )
                }
                .padding(.top, 8)
                .padding(.leading, 10)
                .padding(.trailing, 59)
                .padding(.bottom, 12)
                .background(Color.white)
            } else {
                // Keep spacing consistent when loading
                Spacer().frame(height: 20)
                    .background(Color.white)
            }
        }
        // DEBUG: Measure the content area's Y position (no longer a VStack wrapper)
        .background(
            GeometryReader { geo in
                Color.clear.onChange(of: showStatistic) { newValue in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let f = geo.frame(in: .global)
                        print("🔴 [ContentArea Y showStatistic→\(newValue)] frame=\(f)")
                    }
                }
            }
        )
        .background(Color.white)
        // DEBUG: print the progress bar's Y coordinate whenever it changes,
        // together with current screen identity. Remove after diagnosis.
        .onPreferenceChange(ProgressBarYKey.self) { y in
            let headingPrefix = currentStatistic?.heading.prefix(45).description ?? "—"
            print("📏 [ProgressBar Y pref] \(String(format: "%.2f", y))pt | stepIndex=\(stepIndex) | showStatistic=\(showStatistic) | heading='\(headingPrefix)'")
        }
        .onAppear {
            print("🎬 [OnboardingView appeared] stepIndex=\(stepIndex) | showStatistic=\(showStatistic)")
            // Also confirm safe area + nav bar setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                let window = scene?.windows.first { $0.isKeyWindow }
                let safeTop = window?.safeAreaInsets.top ?? -1
                let safeBottom = window?.safeAreaInsets.bottom ?? -1
                print("📐 [SafeArea] top=\(safeTop)pt bottom=\(safeBottom)pt | window=\(window?.bounds ?? .zero)")
            }
        }
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
        .animation(.easeInOut(duration: 0.35), value: stepIndex)
        .animation(.easeInOut(duration: 0.35), value: showStatistic)
        .animation(.easeInOut(duration: 0.35), value: isGoingBack)
        .animation(.easeInOut(duration: 0.35), value: statisticAnimationId)
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

                    handleBackButton()
                }
        )
    }

    // MARK: - Name Input Content View (without top bar)
    private func nameInputContentView(step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(step.title)
                .font(.manropeSemiBold(size: 24))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Name TextField with character limit
            VStack(alignment: .trailing, spacing: 4) {
                TextField("", text: $userName)
                    .placeholder(when: userName.isEmpty) {
                        Text("Enter your name")
                            .foregroundColor(.wingmanBlack.opacity(0.3))
                    }
                    .font(.manropeRegular(size: 18))
                    .padding(16)
                    .background(Color.wingmanBlack.opacity(0.10))
                    .cornerRadius(5)
                    .focused($isNameFieldFocused)
                    .onChange(of: userName) { newValue in
                        // Limit username to 10 characters
                        if newValue.count > 10 {
                            userName = String(newValue.prefix(10))
                        }
                    }
                    .padding(.top, 10)
                
                // Character counter
                Text("\(userName.count)/10")
                    .font(.caption)
                    .foregroundColor(userName.count > 8 ? .red : .gray)
                    .padding(.trailing, 4)
            }

            // Buttons (moved closer to text field)
            VStack(spacing: 12) {
                // Full-area tappable Next button
                let isNameEmpty = userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                Button(action: {
                    isNameFieldFocused = false
                    let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                    answers["name"] = trimmedName
                    
                    // Save to AnonymousUserManager if in anonymous mode
                    if authManager.isAnonymousUser {
                        AnonymousUserManager.shared.userName = trimmedName
                        print("👻 Saved name to anonymous storage: \(trimmedName)")
                    }
                    
                    moveToNext()
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .font(.manropeSemiBold(size: 16))
                        .padding()
                        .background(isNameEmpty ? Color.wingmanBlack.opacity(0.5) : Color.wingmanBlack)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(isNameEmpty)

                Button("Skip") {
                    isNameFieldFocused = false
                    moveToNext()
                }
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.wingmanBlack)
                .underline()
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .onAppear {
            isNameFieldFocused = true
        }
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

            // Options
            if let options = step.options {
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedOption = option
                        }) {
                            OptionButton(text: option, isSelected: selectedOption == option)
                        }
                    }
                }
            }

            Spacer()

            // Next Button (full-area tappable)
            let isDisabled = (step.type == .question && selectedOption == nil)

            Button(action: {
                moveToNext()
            }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.wingmanBlack)
                    .foregroundColor(.wingmanWhiteFF)
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
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
                print("✅ Finished all questions")
                
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
                        .lineLimit(nil)  // ← Explicitly allow unlimited lines
                        .fixedSize(horizontal: false, vertical: true)  // ← Allow vertical expansion
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Subheading
                    Text(statistic.subheading)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)  // ← Explicitly allow unlimited lines
                        .fixedSize(horizontal: false, vertical: true)  // ← Allow vertical expansion
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 40)

                    // Image
                    Image(statistic.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 250)

                    Spacer().frame(height: 40)

                    // Fact
                    Text(statistic.fact)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineLimit(nil)  // ← Explicitly allow unlimited lines
                        .fixedSize(horizontal: false, vertical: true)  // ← Allow vertical expansion

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
                        print("🚫 Left side tapped - no action")
                    }
                
                // Right half - tappable area for progression
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("✅ Right side tapped - continuing")
                        continueFromStatistic()
                    }
            }
        }
    }

    // MARK: - Name Input View
    private func nameInputView(step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 20) {

            Text(step.title)
                .font(.manropeSemiBold(size: 24))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Name TextField with character limit
            VStack(alignment: .trailing, spacing: 4) {
                TextField("", text: $userName)
                    .placeholder(when: userName.isEmpty) {
                        Text("Enter your name")
                            .foregroundColor(.wingmanBlack.opacity(0.3))
                    }
                    .font(.manropeRegular(size: 18))
                    .padding(16)
                    .background(Color.wingmanBlack.opacity(0.10))
                    .cornerRadius(5)
                    .focused($isNameFieldFocused)
                    .onChange(of: userName) { newValue in
                        // Limit username to 10 characters
                        if newValue.count > 10 {
                            userName = String(newValue.prefix(10))
                        }
                    }
                    .padding(.top, 10)
                
                // Character counter
                Text("\(userName.count)/10")
                    .font(.caption)
                    .foregroundColor(userName.count > 8 ? .red : .gray)
                    .padding(.trailing, 4)
            }

            // Buttons (moved closer to text field)
            VStack(spacing: 12) {
                // Full-area tappable Next button
                let isNameEmpty = userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                Button(action: {
                    isNameFieldFocused = false
                    let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                    answers["name"] = trimmedName
                    
                    // Save to AnonymousUserManager if in anonymous mode
                    if authManager.isAnonymousUser {
                        AnonymousUserManager.shared.userName = trimmedName
                        print("👻 Saved name to anonymous storage: \(trimmedName)")
                    }
                    
                    moveToNext()
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .font(.manropeSemiBold(size: 16))
                        .padding()
                        .background(isNameEmpty ? Color.wingmanBlack.opacity(0.5) : Color.wingmanBlack)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(isNameEmpty)
                

                Button("Skip") {
                    isNameFieldFocused = false
                    moveToNext()
                }
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.wingmanBlack)
                .underline()
            }
            
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .onAppear {
            isNameFieldFocused = true
        }
        
    }

    // MARK: - Question View (Your existing code)
    private func questionView(step: OnboardingStep) -> some View {
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

            // Options
            if let options = step.options {
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedOption = option
                        }) {
                            OptionButton(text: option, isSelected: selectedOption == option)
                        }
                    }
                }
            }

            Spacer()

            // Next Button (full-area tappable)
            let isDisabled = (step.type == .question && selectedOption == nil)

            Button(action: {
                moveToNext()
            }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.wingmanBlack)
                    .foregroundColor(.wingmanWhiteFF)
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.7 : 1)
            .disabled(isDisabled)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Statistic Overlay
    private func statisticOverlay(statistic: StatisticContent) -> some View {
        // compute a progress for the statistic overlay that sits halfway between
        // the source question progress and the next question's progress, so progress
        // moves equally: question -> stat -> next question
        let statProgress: Double = {
            if let src = statisticSourceStepIndex,
               src >= 0,
               src < steps.count - 1 {
                return (steps[src].progress + steps[src + 1].progress) / 2.0
            } else {
                // fallback to current step progress
                return steps[min(stepIndex, steps.count - 1)].progress
            }
        }()

        return ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // Top Bar
                HStack(spacing: 12) {
                    Button {
                        // Dismiss the statistic overlay and return to the source question
                        dismissStatisticAndReturnToSource()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    progressBar(progress: CGFloat(statProgress))
                        .frame(height: 10)
                }
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                // Main statistic content
                VStack(spacing: 20) {

                    // Heading
                    Text(statistic.heading)
                        .font(.manropeSemiBold(size: 24))
                        .foregroundColor(.wingmanBlack)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Subheading
                    Text(statistic.subheading)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 40)

                    // Image
                    Image(statistic.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 250)

                    Spacer().frame(height: 40)

                    // Fact
                    Text(statistic.fact)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

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
            // BUT exclude the top bar area so the back button remains clickable
            VStack(spacing: 0) {
                // Top area - no overlay (so back button is clickable)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 64) // Height of top bar area
                
                // Bottom area - split left/right for tap control
                HStack(spacing: 0) {
                    // Left half - blocks any tap gestures, not tappable for progression
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Explicitly do nothing - left side should not progress
                            print("🚫 Left side tapped - no action")
                        }
                    
                    // Right half - tappable area for progression
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("✅ Right side tapped - continuing")
                            continueFromStatistic()
                        }
                }
            }
        }
    }

    // MARK: - Loading View
    private func loadingView(step: OnboardingStep) -> some View {
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
                print("✅ Finished all questions")
                
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


    // MARK: - Progress Bar View
    private func progressBar(progress: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)

                Capsule()
                    .fill(Color.wingmanBlack)
                    .frame(width: geo.size.width * max(0, min(1, progress)), height: 10)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 10)
    }

    // MARK: - Move to Next
    func moveToNext() {
        let step = steps[stepIndex]

        // Save answer if it's a question
        if step.type == .question, let answer = selectedOption, let key = step.questionKey {
            answers[key] = answer
            print("Question \(stepIndex + 1): \(answer)")

            // Save to UserDefaults
            UserDefaults.standard.set(answer, forKey: "onboarding_\(key)")
            print("✅ Saved answer:", key, answer)
            
            // Save to AnonymousUserManager if in anonymous mode
            if authManager.isAnonymousUser {
                switch key {
                case "age":
                    AnonymousUserManager.shared.userAge = answer
                    print("👻 Saved age to anonymous storage: \(answer)")
                case "goals":
                    AnonymousUserManager.shared.userGoals = answer
                    print("👻 Saved goals to anonymous storage: \(answer)")
                default:
                    break
                }
            }
        }

        // Check if we should show statistic
        if shouldShowStatistic() {
            statisticSourceStepIndex = stepIndex   // 🔥 track source
            isGoingBack = false  // Forward direction
            statisticAnimationId = UUID()  // Generate new ID for fresh animation
            withAnimation(.easeInOut(duration: 0.35)) {
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
            withAnimation(.easeInOut(duration: 0.35)) {
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
            return
        }

        selectedOption = answers[key]
        print("🔁 Restored selection for \(key):", selectedOption ?? "none")
    }

    private func continueFromStatistic() {
        guard let sourceIndex = statisticSourceStepIndex else { return }

        // **Add both the source question AND the statistic to history** so back-navigation
        // from the next question goes: next question -> statistic -> source question
        stepHistory.append(sourceIndex)        // The source question
        stepHistory.append(-1)                 // Special marker for statistic screen
        
        print("📝 Added to step history: source=\(sourceIndex), statistic=-1")
        print("📝 Current step history: \(stepHistory)")

        // Set direction to forward (next screen slides in from right)
        isGoingBack = false

        // Close statistic and advance to the next step
        withAnimation(.easeInOut(duration: 0.35)) {
            showStatistic = false
            currentStatistic = nil
            statisticSourceStepIndex = nil
            stepIndex = sourceIndex + 1
        }
        
        print("📝 Advanced to step index: \(stepIndex)")
        restoreSelectionForCurrentStep()
    }

    // New helper to dismiss the statistic and return (without advancing)
    private func dismissStatisticAndReturnToSource() {
        print("🔙 dismissStatisticAndReturnToSource() called")
        
        guard let sourceIndex = statisticSourceStepIndex else {
            print("❌ No source index recorded")
            return
        }
        
        print("🔙 Returning to source question at index: \(sourceIndex)")
        
        // Set direction to back immediately (before any animation)
        isGoingBack = true
        print("🔙 Set isGoingBack = true - statistic will slide out RIGHT")
        
        // Close statistic overlay and navigate back in one animation
        withAnimation(.easeInOut(duration: 0.35)) {
            showStatistic = false
            stepIndex = sourceIndex
        }
        
        // Clean up and restore after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.currentStatistic = nil
            self.statisticSourceStepIndex = nil
            self.restoreSelectionForCurrentStep()
            print("✅ Returned to source question at index \(sourceIndex)")
        }
    }

    // MARK: - Statistics Logic
    private func shouldShowStatistic() -> Bool {
        let step = steps[stepIndex]

        guard step.type == .question,
              let key = step.questionKey,
              let answer = selectedOption else {
            return false
        }

        let ageGroup = answers["age"] ?? ""

        if let stat = getStatistic(ageGroup: ageGroup, questionKey: key, answer: answer) {
            currentStatistic = stat
            return true
        }

        return false
    }

    private func getStatistic(ageGroup: String, questionKey: String, answer: String) -> StatisticContent? {

        // After "last_approach" question
        if questionKey == "last_approach" {
            if ageGroup == "Under 18" || ageGroup == "18-24" {
                return StatisticContent(
                    heading: "Almost half of men your age have never approached a women",
                    subheading: "You are not alone. Millions of men struggle with approaching.",
                    imageName: "stat_never_approached",
                    fact: "45% of men aged 18-25 have never approached a woman"
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
            print("❌ No user ID available")
            return
        }

        print("📤 Saving name to Supabase: \(name)")

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

                print("✅ Name saved to Supabase")

            } catch {
                print("❌ Error saving name: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Save to Supabase (Auth User Metadata)
    private func saveUserName() {
        guard let name = answers["name"], !name.isEmpty else {
            print("❌ Name is empty, skipping save")
            return
        }

        let updatedAt = ISO8601DateFormatter().string(from: Date())

        print("📤 Saving user metadata to Supabase")
        print("   • name:", name)
        print("   • onboardingCompleted: true")
        print("   • updatedAt:", updatedAt)

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

                print("✅ User metadata saved successfully")

            } catch {
                print("❌ Error saving user metadata:", error.localizedDescription)
            }
        }
    }

    // MARK: - Back Button
    private func handleBackButton() {
        print("🔙 OnboardingView: handleBackButton called - stepIndex: \(stepIndex)")
        
        // ✅ Back from statistic ALWAYS returns to source question
        if showStatistic {
            print("🔙 Returning from statistic overlay")
            dismissStatisticAndReturnToSource()
            return
        }

        // If on first step (name input) and showLanding is bound, navigate back to Landing
        if stepIndex == 0 {
            if let binding = showLanding {
                print("🔙 On first step with showLanding binding - navigating back to Landing")
                binding.wrappedValue = false
                return
            } else {
                print("🔙 On first step but no showLanding binding")
            }
        }

        // Normal back navigation
        if let previousIndex = stepHistory.popLast() {
            print("🔙 Popped index from history: \(previousIndex)")
            print("🔙 Current step history after pop: \(stepHistory)")
            
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
                    print("🔙 Reconstructing statistic screen for source question: \(sourceIndex)")
                    print("🔙 Navigation depth: User has navigated back through \(stepHistory.count) steps")
                    
                    // Step 1: Clear current statistic state completely and force view refresh
                    currentStatistic = nil
                    showStatistic = false
                    statisticSourceStepIndex = nil
                    print("🔙 Step 1: Completely cleared existing statistic state")
                    
                    // Step 2: Force state update cycle to ensure SwiftUI recognizes changes
                    DispatchQueue.main.async {
                        // Step 3: Set up for back navigation
                        self.isGoingBack = true
                        self.statisticSourceStepIndex = sourceIndex
                        print("🔙 Step 3: Set isGoingBack = true, sourceIndex = \(sourceIndex)")
                        
                        // Step 4: Determine which statistic to show
                        let sourceStep = self.steps[sourceIndex]
                        if let questionKey = sourceStep.questionKey,
                           let answer = self.answers[questionKey] {
                            let ageGroup = self.answers["age"] ?? ""
                            
                            print("🔙 Step 4: Preparing statistic for \(questionKey) = \(answer)")
                            
                            // Step 5: Create new statistic with proper timing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                let newStatistic = self.getStatistic(ageGroup: ageGroup, questionKey: questionKey, answer: answer)
                                self.currentStatistic = newStatistic
                                print("🔙 Step 5: Set new statistic: \(newStatistic?.heading ?? "nil")")
                                
                                // Step 6: Use helper method for clean state management
                                self.animateStatisticFromBack()
                            }
                        }
                    }
                    return
                } else {
                    print("❌ No source question found in history for statistic")
                }
            } else {
                // Normal question navigation
                // Check if we're trying to navigate to the same step (means we need to pop again)
                if previousIndex == stepIndex {
                    print("🔙 Popped index equals current step, popping again...")
                    if let actualPreviousIndex = stepHistory.popLast() {
                        // Skip any -1 markers (statistics)
                        if actualPreviousIndex == -1 {
                            // There's a statistic screen before this question - show it
                            if let statSourceIndex = stepHistory.last, statSourceIndex != -1 {
                                print("🔙 Found statistic before question, reconstructing statistic for source: \(statSourceIndex)")
                                
                                // Set up for back navigation to statistic
                                DispatchQueue.main.async {
                                    self.isGoingBack = true
                                    self.statisticSourceStepIndex = statSourceIndex
                                    
                                    let sourceStep = self.steps[statSourceIndex]
                                    if let questionKey = sourceStep.questionKey,
                                       let answer = self.answers[questionKey] {
                                        let ageGroup = self.answers["age"] ?? ""
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            self.currentStatistic = self.getStatistic(ageGroup: ageGroup, questionKey: questionKey, answer: answer)
                                            self.animateStatisticFromBack()
                                        }
                                    }
                                }
                                return
                            }
                        }
                        
                        print("🔙 Navigating to actual previous step: \(actualPreviousIndex)")
                        isGoingBack = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            stepIndex = actualPreviousIndex
                        }
                        restoreSelectionForCurrentStep()
                        return
                    }
                } else {
                    print("🔙 Navigating to previous step: \(previousIndex)")
                    isGoingBack = true
                    withAnimation(.easeInOut(duration: 0.35)) {
                        stepIndex = previousIndex
                    }
                    restoreSelectionForCurrentStep()
                    return
                }
            }
        }

        print("🔙 No previous step - dismissing view")
        dismiss()
    }
    
    // MARK: - Helper for clean statistic animation from back navigation
    private func animateStatisticFromBack() {
        // Ensure isGoingBack is explicitly set to true
        isGoingBack = true
        
        // Generate a new unique ID to force SwiftUI to create a fresh view
        // This is crucial for ensuring animations work on multiple back navigations
        statisticAnimationId = UUID()
        
        print("🔙 animateStatisticFromBack() called")
        print("🔙 Generated new animation ID: \(statisticAnimationId)")
        print("🔙 State check - isGoingBack: \(isGoingBack), currentStatistic: \(currentStatistic?.heading ?? "nil")")
        
        // Small delay to ensure all state is properly set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            print("🔙 About to animate statistic from LEFT (back navigation)")
            print("🔙 Final state - isGoingBack: \(self.isGoingBack), showStatistic: \(self.showStatistic)")
            
            // Animate with explicit state check
            withAnimation(.easeInOut(duration: 0.35)) {
                self.showStatistic = true
            }
            
            // Verify animation completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                print("✅ Back navigation statistic animation completed")
                print("✅ Final state - shown: \(self.showStatistic), isGoingBack: \(self.isGoingBack)")
            }
        }
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
        options: ["Under 18", "18-24", "25-34", "35-44", "45+"],
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
        options: ["Yes, almost every time", "Sometimes", "Rarely", "No, I usually go for it"],
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
        title: "Personalizing an experience just for you...",
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
        Button(action: action) {
            Text("Tap to continue")
                .font(.manropeRegular(size: 16))
                .foregroundColor(.gray)
                .opacity(isVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: isVisible)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isVisible = true
            }
        }
    }
}

// MARK: - Loading Dots View (small carousel-like black/gray dots)
struct LoadingDotsView: View {
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let dotSize: CGFloat = 8

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { idx in
                Circle()
                    .fill(idx == activeIndex ? Color.wingmanBlack : Color.gray.opacity(0.45))
                    .frame(width: dotSize, height: dotSize)
                    .animation(.easeInOut(duration: 0.25), value: activeIndex)
            }
        }
        .onReceive(timer) { _ in
            withAnimation {
                activeIndex = (activeIndex + 1) % 3
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

// DEBUG: carries the progress bar's measured global Y coordinate up the
// view tree via `.preference` so the outer view can log it on change.
// Remove together with the two call sites after the diagnosis is done.
private struct ProgressBarYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
