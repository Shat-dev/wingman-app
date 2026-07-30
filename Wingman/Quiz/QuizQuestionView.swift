//
//  QuizQuestionView.swift
//  Wingman
//

import SwiftUI

/// One quiz question: prompt, options, and the bottom bar that switches between
/// "Check Answer" and the explanation panel with "Next".
///
/// Extracted verbatim from `DailyPracticeView`'s private view builders
/// (`questionContentView`, `singleSelectOptionButton`, `multipleSelectOptionButton`,
/// `checkboxView`, `explanationViewWithButton`, `actionButton`, and the eight
/// colour resolvers). Every font, padding, corner radius, shadow, transition
/// and colour branch is carried across unchanged — this is a move, not a
/// redesign, and Daily Practice must be pixel-identical afterwards.
///
/// State comes in as a `QuizQuestionState` value and actions go out as
/// closures, so the view has no opinion about where questions come from or what
/// happens when one is answered. Side effects the caller owns — haptics,
/// analytics, advancing the run — deliberately live in those closures rather
/// than in here.
struct QuizQuestionView: View {

    let state: QuizQuestionState

    /// Tapped an option. Callers are expected to ignore this once the answer
    /// has been checked; the buttons are also `.disabled` in that state, which
    /// mirrors the original.
    let onSelectOption: (Int) -> Void

    /// Tapped "Check Answer".
    let onCheckAnswer: () -> Void

    /// Tapped "Next" in the explanation panel.
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Question Number and Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(state.number). \(state.text)")
                            .font(.manropeMedium(size: 20))
                            .foregroundColor(.wingmanBlack)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)

                        if state.isMultipleSelect {
                            Text("Select all that apply")
                                .font(.manropeRegular(size: 13))
                                .foregroundColor(.wingmanBlack.opacity(0.45))
                        }
                    }

                    // MARK: - Options
                    VStack(spacing: 12) {
                        ForEach(Array(state.options.enumerated()), id: \.offset) { index, option in
                            if state.isMultipleSelect {
                                multipleSelectOptionButton(text: option, index: index)
                            } else {
                                singleSelectOptionButton(text: option, index: index)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // Extra space for bottom section
            }

            Spacer()

            // MARK: - Bottom Section (Check Answer Button OR Explanation + Next)
            if state.hasCheckedAnswer {
                explanationViewWithButton()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                actionButton()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Single Select Option Button
    private func singleSelectOptionButton(text: String, index: Int) -> some View {
        let isSelected = state.isSelected(index)
        let isCorrect = state.isCorrect(index)
        let isWrong = state.isIncorrect(index)

        return Button(action: {
            onSelectOption(index)
        }) {
            HStack {
                Text(text)
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(buttonTextColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(buttonBackgroundColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(buttonBorderColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong), lineWidth: 1)
            )
            .shadow(color: Color.wingmanBlack.opacity(0.0002), radius: 0.03, x: 0, y: 0.01)
        }
        .buttonStyle(ScalePressStyle())
        .disabled(state.hasCheckedAnswer)
    }

    // MARK: - Multiple Select Option Button with Checkbox
    private func multipleSelectOptionButton(text: String, index: Int) -> some View {
        let isSelected = state.isSelected(index)
        let isCorrect = state.isCorrect(index)
        let isWrong = state.isIncorrect(index)
        let shouldShowCorrectButNotSelected = state.showsCorrectButNotSelected(index)

        return Button(action: {
            onSelectOption(index)
        }) {
            HStack(spacing: 12) {
                // Checkbox
                checkboxView(
                    isSelected: isSelected,
                    isCorrect: isCorrect,
                    isWrong: isWrong,
                    shouldShowCorrectButNotSelected: shouldShowCorrectButNotSelected
                )

                Text(text)
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(multipleSelectTextColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong, shouldShowCorrectButNotSelected: shouldShowCorrectButNotSelected))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(multipleSelectBackgroundColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong, shouldShowCorrectButNotSelected: shouldShowCorrectButNotSelected))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(multipleSelectBorderColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong, shouldShowCorrectButNotSelected: shouldShowCorrectButNotSelected), lineWidth: 1)
            )
            .shadow(color: .wingmanBlack.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(ScalePressStyle())
        .disabled(state.hasCheckedAnswer)
    }

    // MARK: - Checkbox View
    private func checkboxView(isSelected: Bool, isCorrect: Bool, isWrong: Bool, shouldShowCorrectButNotSelected: Bool) -> some View {
        ZStack {
            // Background rectangle with rounded corners
            RoundedRectangle(cornerRadius: 4)
                .fill(checkboxBackgroundColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong, shouldShowCorrectButNotSelected: shouldShowCorrectButNotSelected))
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(checkboxBorderColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong, shouldShowCorrectButNotSelected: shouldShowCorrectButNotSelected), lineWidth: 1)
                )

            // Checkmark or X
            if shouldShowCorrectButNotSelected {
                // Show empty checkbox for correct answers not selected by user

            } else if isSelected && (isCorrect || (!state.hasCheckedAnswer)) {
                // White checkmark for selected items (before checking) or correct selected items
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            } else if isSelected && isWrong {
                // Red X for wrong selected items
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white)
            }
        }
    }

    // MARK: - Color Functions for Single Select
    private func buttonTextColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            return Color.customGreen
        } else if isWrong {
            return Color.customRed
        } else if isSelected {
            return Color.white
        } else {
            return Color.customDark
        }
    }

    private func buttonBackgroundColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            return Color.customLightGreen
        } else if isWrong {
            return Color.customLightRed
        } else if isSelected {
            return Color.wingmanBlack
        } else {
            return Color.white
        }
    }

    private func buttonBorderColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            return Color.customGreen
        } else if isWrong {
            return Color.customRed
        } else {
            return Color.customDark.opacity(0.5)
        }
    }

    // MARK: - Color Functions for Multiple Select
    private func multipleSelectTextColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool, shouldShowCorrectButNotSelected: Bool) -> Color {
        if isCorrect || shouldShowCorrectButNotSelected {
            return Color.customGreen
        } else if isWrong {
            return Color.customRed
        } else {
            return Color.customDark
        }
    }

    private func multipleSelectBackgroundColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool, shouldShowCorrectButNotSelected: Bool) -> Color {
        if isCorrect || shouldShowCorrectButNotSelected {
            return Color.customLightGreen
        } else if isWrong {
            return Color.customLightRed
        } else {
            return Color.white
        }
    }

    private func multipleSelectBorderColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool, shouldShowCorrectButNotSelected: Bool) -> Color {
        if isCorrect || shouldShowCorrectButNotSelected {
            return Color.customGreen
        } else if isWrong {
            return Color.customRed
        } else {
            return Color.customDark.opacity(0.5)
        }
    }

    // MARK: - Checkbox Color Functions
    private func checkboxBackgroundColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool, shouldShowCorrectButNotSelected: Bool) -> Color {
        if shouldShowCorrectButNotSelected {
            return Color.white // White background for correct but unselected (empty checkbox)
        } else if isSelected && isCorrect {
            return Color.customGreen // Green background for selected correct items
        } else if isSelected && isWrong {
            return Color.customRed
        } else if isSelected {
            return Color.wingmanBlack // Black background for selected items before checking
        } else {
            return Color.customLightGray
        }
    }

    private func checkboxBorderColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool, shouldShowCorrectButNotSelected: Bool) -> Color {
        if shouldShowCorrectButNotSelected {
            return Color.customDark.opacity(0.5) // Black border for correct but unselected
        } else if isCorrect {
            return Color.customGreen
        } else if isWrong {
            return Color.customRed
        } else if isSelected {
            return Color.wingmanBlack
        } else {
            return Color.customDark.opacity(0.5)
        }
    }

    // MARK: - Explanation View WITH Next Button at Bottom of Screen
    private func explanationViewWithButton() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(state.isAnswerCorrect ? "Correct Answer!" : "Incorrect Answer.")
                    .font(.manropeSemiBold(size: 18))
                    .foregroundColor(state.isAnswerCorrect ? Color.customCorrectGreen : Color.customIncorrectRed)
            }

            // Explanation text
            Text(state.explanation)
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(Color.customDark.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Next Button Inside
            Button(action: {
                onNext()
            }) {
                Text("Next")
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(state.isAnswerCorrect ? Color.customGreen : Color.customRed)
                    .cornerRadius(5)
            }
            .buttonStyle(ScalePressStyle())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            state.isAnswerCorrect
                ? Color.customExplanationGreen
                : Color.customExplanationRed
        )
        .cornerRadius(10)
        .padding(.horizontal, 10)
        .padding(.bottom,33)
    }

    // MARK: - Action Button (Check Answer - before checking)
    private func actionButton() -> some View {
        Button(action: {
            onCheckAnswer()
        }) {
            Text("Check Answer")
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(state.isCheckAnswerEnabled ? Color.wingmanBlack : Color.wingmanBlack.opacity(0.4))
                .cornerRadius(5)
        }
        .buttonStyle(ScalePressStyle())
        .disabled(!state.isCheckAnswerEnabled)
    }
}

#Preview("Single select — unanswered") {
    QuizQuestionView(
        state: QuizQuestionState(
            number: 1,
            text: "Best mindset when approaching someone?",
            options: ["Need to impress", "Hope they like me", "Genuinely curious", "Need to be perfect"],
            isMultipleSelect: false,
            selectedIndices: [],
            correctIndices: [2],
            hasCheckedAnswer: false,
            isAnswerCorrect: false,
            explanation: "The best mindset is genuine curiosity."
        ),
        onSelectOption: { _ in },
        onCheckAnswer: {},
        onNext: {}
    )
}

#Preview("Multi select — checked, partially right") {
    QuizQuestionView(
        state: QuizQuestionState(
            number: 2,
            text: "Which are key for confident body language?",
            options: ["Eye contact", "Good posture", "Fidgeting", "Speaking clearly"],
            isMultipleSelect: true,
            selectedIndices: [0, 2],
            correctIndices: [0, 1, 3],
            hasCheckedAnswer: true,
            isAnswerCorrect: false,
            explanation: "Confident body language includes eye contact, good posture and speaking clearly."
        ),
        onSelectOption: { _ in },
        onCheckAnswer: {},
        onNext: {}
    )
}
