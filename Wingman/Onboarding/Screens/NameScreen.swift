//
//  NameScreen.swift
//  Wingman
//
//  The first onboarding screen: an optional name. Sibling of
//  `QuestionScreen` — same title treatment, same primary button, same
//  padding — but backed by a text field instead of options, and the only
//  screen in the flow with a Skip.
//
//  It reports through a single `onContinue(String)`. An empty string means
//  "skipped", whether the user tapped Skip or tapped Next on an empty (or
//  whitespace-only) field; the coordinator has one case to handle rather
//  than two paths that could drift.
//
//  Like `QuestionScreen`, local state is seeded once per construction. The
//  coordinator gives every screen a fresh identity via `.id(screen)`, so
//  returning here after a back navigation rebuilds the view with whatever
//  the answer store holds.
//

import SwiftUI

struct NameScreen: View {
    let step: OnboardingStep
    let onContinue: (String) -> Void

    @State private var name: String
    @FocusState private var isFocused: Bool

    init(step: OnboardingStep, initialName: String, onContinue: @escaping (String) -> Void) {
        self.step = step
        self.onContinue = onContinue
        self._name = State(initialValue: initialName)
    }

    /// What `onContinue` would receive right now — sanitised exactly as it
    /// will be stored, so the Next button's enabled state and the value that
    /// gets saved can never disagree.
    private var resolvedName: String? {
        OnboardingNameKey.sanitized(name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(step.title)
                .font(.manropeSemiBold(size: 24))
                .multilineTextAlignment(.leading)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }

            TextField("Your name", text: $name)
                .font(.manropeMedium(size: 16))
                .foregroundColor(.wingmanBlack)
                .focused($isFocused)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { submit() }
                // Hard cap at the input rather than at each render site, so
                // what the user sees typed is what the greeting and the pact
                // will show them later.
                .onChange(of: name) { newValue in
                    if newValue.count > OnboardingNameKey.maxLength {
                        name = String(newValue.prefix(OnboardingNameKey.maxLength))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                .cornerRadius(5)

            Spacer()

            // Primary action. Unlike `QuestionScreen`'s, this is never
            // disabled — an empty field is a valid answer here, and a dead
            // button on the very first screen of the app is a worse dead end
            // than a name we didn't need.
            Button(action: { submit() }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.wingmanBlack)
                    .foregroundColor(.wingmanWhiteFF)
                    .cornerRadius(5)
            }
            .buttonStyle(ScalePressStyle())
            .contentShape(Rectangle())

            Button(action: { skip() }) {
                Text("Skip")
                    .font(.manropeMedium(size: 15))
                    .foregroundColor(.wingmanBlack.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        // Session replay: deliberately NOT masked, unlike the other screens
        // that touch personal data (AuthView, SettingsSheet, EditProfileSheet,
        // LogApproachBottomSheet, ApproachesLoggedListView).
        //
        // Masking here bought no privacy. `CommitmentPactView` renders the same
        // name straight back as "I, <name>, am becoming a guy who takes action."
        // (CommitmentPactCopy.headline) and carries no mask, so the name was
        // already in replay one screen later — hiding it here only cost us the
        // ability to watch the screen itself. That screen is the one the
        // `onboarding_name_answered` / `onboarding_name_provided` instrumentation
        // exists to evaluate: whether asking for a name is worth a step in the
        // funnel. The skip-vs-answer number says what people did; the replay is
        // the only thing that shows why.
        //
        // These two are a pair. If the pact is ever masked, mask this with it —
        // leaving the field visible is only defensible while the name is already
        // visible downstream.
        .onAppear {
            // Deferred past the page transition. Raising the keyboard while
            // the push is still running re-lays-out the screen mid-slide,
            // which shows up as the title jumping as the page arrives.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                isFocused = true
            }
        }
    }

    private func submit() {
        HapticManager.shared.tap()
        isFocused = false
        onContinue(resolvedName ?? "")
    }

    private func skip() {
        HapticManager.shared.tap()
        isFocused = false
        onContinue("")
    }
}

/// The step this screen used to be driven by. Built literally rather than read
/// out of `extendedOnboardingSteps`, because the name step is no longer in that
/// array — index 0 is now the age question, and these previews would render the
/// name field under "How old are you?".
private let namePreviewStep = OnboardingStep(
    type: .name,
    title: "What's your name?",
    subtitle: "So Wingman can talk to you, not at you.",
    options: nil,
    progress: 0.15,
    questionKey: OnboardingNameKey.answerKey
)

#Preview("Empty") {
    NameScreen(
        step: namePreviewStep,
        initialName: "",
        onContinue: { _ in }
    )
}

#Preview("Restored") {
    NameScreen(
        step: namePreviewStep,
        initialName: "Arthur",
        onContinue: { _ in }
    )
}
