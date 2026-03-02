//
//  QuestionFlowView.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

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
    @State private var stepIndex: Int = 0
    @State private var selectedOption: String? = nil
    @State private var userName: String = ""
    @State private var showStatistic: Bool = false
    @State private var currentStatistic: StatisticContent? = nil
    @State private var stepHistory: [Int] = []
    @State private var statisticSourceStepIndex: Int? = nil
    @State private var isGoingBack: Bool = false  // Track navigation direction

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @FocusState private var isNameFieldFocused: Bool

    let steps: [OnboardingStep] = extendedOnboardingSteps

    // Store answers for statistics logic
    @State private var answers: [String: String] = [:]

    var body: some View {
        ZStack {
            // Main content - hide when statistic is showing to prevent overlap
            if !showStatistic {
                VStack(spacing: 0) {

                    // NOTE: compute step early so we can conditionally show/hide top bar
                    let step = steps[stepIndex]

                    // MARK: - Top Row: Back Chevron + Progress Bar inline
                    // Hide both chevron and progress bar when we're on the loading state
                    if step.type != .loading {
                        HStack() {
                            Button {
                                handleBackButton()
                            } label: {
                                Image("auth_back")
                                    .frame(width: 44, height: 44, alignment: .center)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            progressBar(progress: CGFloat(steps[stepIndex].progress))
                                .frame(height: 10)
                        }
                        .padding(.top, 8)
                        .padding(.leading, 10)
                        .padding(.trailing,59)
                        .padding(.bottom, 12)
                    } else {
                        // Optional: keep a little top spacing while hiding the bar so layout doesn't jump
                        Spacer().frame(height: 20)
                    }

                    // MARK: - Content based on step type (wrapped for animation)
                    ZStack {
                        // Use ForEach with a single item to enable proper transition
                        ForEach([stepIndex], id: \.self) { index in
                            Group {
                                if steps[index].type == .name {
                                    nameInputView(step: steps[index])
                                } else if steps[index].type == .question {
                                    questionView(step: steps[index])
                                } else if steps[index].type == .loading {
                                    loadingView(step: steps[index])
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: isGoingBack ? .leading : .trailing),
                                removal: .move(edge: isGoingBack ? .trailing : .leading)
                            ))
                        }
                    }
                    .clipped() // Clip content during animation to prevent overlap
                }
                .transition(.asymmetric(
                    insertion: .move(edge: isGoingBack ? .leading : .trailing),
                    removal: .move(edge: isGoingBack ? .trailing : .leading)
                ))
            }

            // MARK: - Statistic Overlay
            if showStatistic, let statistic = currentStatistic {
                statisticOverlay(statistic: statistic)
                    .background(Color.white)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: isGoingBack ? .trailing : .leading)
                    ))
            }
        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.35), value: showStatistic)
    }

    // MARK: - Name Input View
    private func nameInputView(step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 20) {

            Text(step.title)
                .font(.manropeSemiBold(size: 24))

            // Name TextField
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
                .padding(.top, 10)

            // Buttons (moved closer to text field)
            VStack(spacing: 12) {
                // Full-area tappable Next button
                let isNameEmpty = userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                Button(action: {
                    isNameFieldFocused = false
                    answers["name"] = userName.trimmingCharacters(in: .whitespacesAndNewlines)
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
                .foregroundColor(.black)
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

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Options
            if let options = step.options {
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
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
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
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
                        .foregroundColor(.black)
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
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Loading Dots Animation (dots are below the text)
            LoadingDotsView()
                .padding(.top, 6)

            Spacer()
        }
        .onAppear {
            // Save name to Supabase
            saveUserName()

            // Wait 3 seconds then complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print("✅ Finished all questions")
                authManager.completeQuestions()
                // TODO: Navigate to Paywall here if needed
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
                    .fill(Color.black)
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
        }

        // Check if we should show statistic
        if shouldShowStatistic() {
            statisticSourceStepIndex = stepIndex   // 🔥 track source
            isGoingBack = false  // Forward direction
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

        // **Append the source question to history** so back-navigation from the next
        // question returns to the source (instead of skipping it).
        stepHistory.append(sourceIndex)

        // Set direction to forward (next screen slides in from right)
        isGoingBack = false

        // Close statistic and advance to the next step
        withAnimation(.easeInOut(duration: 0.35)) {
            showStatistic = false
            currentStatistic = nil
            statisticSourceStepIndex = nil
            stepIndex = sourceIndex + 1
        }
        restoreSelectionForCurrentStep()
    }

    // New helper to dismiss the statistic and return (without advancing)
    private func dismissStatisticAndReturnToSource() {
        // Set direction to back (previous screen slides in from left)
        isGoingBack = true
        
        // Close statistic overlay with animation
        withAnimation(.easeInOut(duration: 0.35)) {
            showStatistic = false
            currentStatistic = nil

            // If we have a recorded source index, go back to it (do NOT advance)
            if let sourceIndex = statisticSourceStepIndex {
                stepIndex = sourceIndex
                statisticSourceStepIndex = nil
            }
        }
        restoreSelectionForCurrentStep()
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
                    heading: "Almost half of men your age have not approached a women in the past year",
                    subheading: "You are not alone. Millions of men struggle with approaching.",
                    imageName: "stat_never_approached",
                    fact: "48% of men aged 26-40 have not approached a women in the past year"
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
        guard let userId = UserDefaults.standard.string(forKey: "current_user_id") else {
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
        // ✅ Back from statistic ALWAYS returns to source question
        if showStatistic {
            dismissStatisticAndReturnToSource()
            return
        }

        // Normal back navigation
        if let previousIndex = stepHistory.popLast() {
            // Set direction FIRST, then change stepIndex
            isGoingBack = true
            withAnimation(.easeInOut(duration: 0.35)) {
                stepIndex = previousIndex
            }
            restoreSelectionForCurrentStep()
            return
        }

        dismiss()
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
        title: "Do you often want to approach women in public but stop yourself?",
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
            "Fear of rejection or being embarrased, almost every time",
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
                    .fill(idx == activeIndex ? Color.black : Color.gray.opacity(0.45))
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
