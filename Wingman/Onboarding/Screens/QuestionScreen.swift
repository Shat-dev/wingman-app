//
//  QuestionScreen.swift
//  Wingman
//
//  A single question within the onboarding flow. Owns its local selection
//  state for the lifetime of the view: when the parent coordinator
//  advances `stepIndex`, the enclosing `ForEach` identity changes and a
//  fresh `QuestionScreen` is constructed with a new `initialSelection`
//  seed from the answer store. This replaces the old pattern of the
//  coordinator manually calling `restoreSelectionForCurrentStep()` on
//  every navigation transition.
//
//  Single- and multi-select questions are handled uniformly: the view
//  always hands the parent a `[String]` via `onNext`, length-1 for
//  single-select and N-long (in tap order) for multi-select. The parent
//  serializes with `", "` for storage — the same scheme used before
//  extraction.
//

import SwiftUI

struct QuestionScreen: View {
    let step: OnboardingStep
    let onNext: ([String]) -> Void

    @State private var selectedOptions: [String]

    init(step: OnboardingStep, initialSelection: [String], onNext: @escaping ([String]) -> Void) {
        self.step = step
        self.onNext = onNext
        self._selectedOptions = State(initialValue: initialSelection)
    }

    private var hasSelection: Bool { !selectedOptions.isEmpty }

    var body: some View {
        // Question content scrolls; the Next button stays pinned to the
        // bottom. This is a no-op on every canvas the layout already fitted —
        // the ScrollView is greedy, so it absorbs exactly the slack the
        // `Spacer()` used to, leaving the title and the button on the same
        // pixels they were on before.
        //
        // It matters on short ones. Display Zoom (Settings → Display &
        // Brightness) renders the whole UI at a smaller *point* canvas: a
        // 6.1" iPhone drops from 390×844 to 320×693, i.e. ~620pt of usable
        // height. There is no API to opt out of it, and the app-wide
        // `.dynamicTypeSize(...large)` ceiling in WingmanApp does not help —
        // that caps text size, not the canvas. At 320pt wide the longer
        // options wrap to two lines, the content stops fitting, and SwiftUI
        // resolves the overflow by compressing whatever can be compressed:
        // the title collapsed to a single truncated line ("What usually
        // stops yo…") and the top bar was pushed off the top edge.
        // ~10% of users run Display Zoom.
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                questionContent
            }
            // No rubber-banding on the canvases where everything already
            // fits, so large screens keep behaving like the fixed layout
            // they were.
            .scrollBounceBehavior(.basedOnSize)

            nextButton
                .padding(.top, 20)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var questionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title. `.fixedSize` vertically so it always reports the full
            // height it needs and can never be compressed into a truncated
            // single line — the ScrollView above is what absorbs the extra.
            Text(step.title)
                .font(.manropeSemiBold(size: 24))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

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
                                selectedOptions = [option]
                            }
                        }) {
                            OptionButton(
                                text: option,
                                isSelected: selectedOptions.contains(option)
                            )
                        }
                        .buttonStyle(ScalePressStyle())
                    }
                }
            }
        }
        // The options stack is centred by default; keep the whole content
        // block full-width so the leading alignment survives the ScrollView,
        // which sizes to its content rather than its container.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Next Button (full-area tappable). Disabled when the user has made
    /// no selection — for multi-select this means "empty selection set",
    /// for single-select it means the first tap has not happened yet.
    private var nextButton: some View {
        let isDisabled = !hasSelection

        return Button(action: {
            HapticManager.shared.tap()
            onNext(selectedOptions)
        }) {
            Text("Next")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.wingmanBlack)
                .foregroundColor(.wingmanWhiteFF)
                .cornerRadius(5)
        }
        .buttonStyle(ScalePressStyle())
        .contentShape(Rectangle())
        .opacity(isDisabled ? 0.7 : 1)
        .disabled(isDisabled)
    }
}

#Preview("Single-select") {
    QuestionScreen(
        step: extendedOnboardingSteps[0],  // "How old are you?"
        initialSelection: [],
        onNext: { _ in }
    )
}

#Preview("Single-select restored") {
    QuestionScreen(
        step: extendedOnboardingSteps[0],
        initialSelection: ["25-34"],
        onNext: { _ in }
    )
}

#Preview("Multi-select") {
    QuestionScreen(
        step: extendedOnboardingSteps[3],  // "What usually stops you..."
        initialSelection: [],
        onNext: { _ in }
    )
}

#Preview("Multi-select restored") {
    QuestionScreen(
        step: extendedOnboardingSteps[3],
        initialSelection: ["Fear of rejection or being embarrased", "Other"],
        onNext: { _ in }
    )
}
