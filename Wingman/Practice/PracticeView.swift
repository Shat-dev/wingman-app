//
//  PracticeView.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//


//
//  PracticeView.swift
//  Wingman
//

//
//  PracticeView.swift
//  Wingman
//

//
//  PracticeView.swift
//  Wingman
//

import SwiftUI

struct PracticeView: View {
    @StateObject private var viewModel = PracticeViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Top Row: Back Chevron + Progress Bar
            HStack(spacing: 12) {
                Button {
                    handleBackButton()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                progressBar(progress: CGFloat(viewModel.progress))
                    .frame(height: 10)
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // MARK: - Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Question Number and Text
                    Text("\(viewModel.currentQuestion.number). \(viewModel.currentQuestion.question)")
                        .font(.manropeSemiBold(size: 24))
                        .foregroundColor(.black)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // MARK: - Options
                    VStack(spacing: 12) {
                        ForEach(Array(viewModel.currentQuestion.options.enumerated()), id: \.offset) { index, option in
                            optionButton(
                                text: option,
                                index: index,
                                isSelected: viewModel.selectedOptionIndex == index,
                                isCorrect: viewModel.hasCheckedAnswer && index == viewModel.currentQuestion.correctAnswerIndex,
                                isWrong: viewModel.hasCheckedAnswer && viewModel.selectedOptionIndex == index && !viewModel.isAnswerCorrect
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 100) // Extra space for bottom section
            }
            
            Spacer()
            
            // MARK: - Bottom Section (Check Answer Button OR Explanation + Next)
            if viewModel.hasCheckedAnswer {
                // Explanation with Next Button at Bottom
                explanationViewWithButton()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Check Answer Button
                actionButton()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasCheckedAnswer)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedOptionIndex)
        .onAppear {
            print("👁️ PracticeView appeared - Question \(viewModel.currentQuestionIndex + 1)/\(viewModel.questions.count)")
        }
    }
    
    // MARK: - Progress Bar
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
    
    // MARK: - Option Button
    private func optionButton(text: String, index: Int, isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> some View {
        Button(action: {
            viewModel.selectOption(at: index)
        }) {
            HStack {
                Text(text)
                    .font(.manropeRegular(size: 16))
                    .foregroundColor(buttonTextColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(buttonBackgroundColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(buttonBorderColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong), lineWidth: 1)
            )
        }
        .disabled(viewModel.hasCheckedAnswer)
    }
    
    private func buttonTextColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            return Color(red: 0.0, green: 0.5, blue: 0.3) // Dark green text
        } else if isWrong {
            return .white
        } else if isSelected {
            return .white
        } else {
            return .black
        }
    }
    
    private func buttonBackgroundColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            return Color(red: 0.85, green: 0.95, blue: 0.90) // Light green
        } else if isWrong {
            return Color(red: 0.85, green: 0.3, blue: 0.3) // Red
        } else if isSelected {
            return .black
        } else {
            return .white
        }
    }
    
    private func buttonBorderColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            return Color(red: 0.0, green: 0.6, blue: 0.4) // Green border
        } else if isWrong {
            return Color(red: 0.85, green: 0.3, blue: 0.3) // Red border
        } else if isSelected {
            return .black
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    // MARK: - Explanation View WITH Next Button at Bottom of Screen
    private func explanationViewWithButton() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(viewModel.isAnswerCorrect ? "Correct Answer!" : "Incorrect Answer.")
                    .font(.manropeSemiBold(size: 18))
                    .foregroundColor(viewModel.isAnswerCorrect ? Color(red: 0.2, green: 0.6, blue: 0.4) : Color(red: 0.8, green: 0.3, blue: 0.3))
            }
            
            
            // Explanation text
            Text(viewModel.isAnswerCorrect ? viewModel.currentQuestion.correctExplanation : viewModel.currentQuestion.incorrectExplanation)
                .font(.manropeRegular(size: 16))
                .foregroundColor(.black.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Next Button Inside
            Button(action: {
                handleNextButton()
            }) {
                Text("Next")
                    .font(.manropeSemiBold(size: 17))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(viewModel.isAnswerCorrect ? Color(red: 0.3, green: 0.7, blue: 0.5) : Color(red: 0.8, green: 0.4, blue: 0.4))
                    .cornerRadius(5)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            viewModel.isAnswerCorrect
                ? Color(red: 0.9, green: 0.97, blue: 0.94)
                : Color(red: 1.0, green: 0.93, blue: 0.93)
        )
        .cornerRadius(16)
        .padding(.horizontal,12)
    }
    
    // MARK: - Action Button (Check Answer - before checking)
    private func actionButton() -> some View {
        Button(action: {
            viewModel.checkAnswer()
        }) {
            Text("Check Answer")
                .font(.manropeSemiBold(size: 17))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.selectedOptionIndex != nil ? Color.black : Color.gray.opacity(0.4))
                .cornerRadius(10)
        }
        .disabled(viewModel.selectedOptionIndex == nil)
    }
    
    // MARK: - Navigation Handlers
    private func handleBackButton() {
        if viewModel.currentQuestionIndex > 0 {
            print("⬅️ Back button: Going to previous question")
            viewModel.previousQuestion()
        } else {
            print("⬅️ Back button: Returning to Dashboard")
            dismiss()
        }
    }
    
    private func handleNextButton() {
        if viewModel.isLastQuestion {
            print("🎉 Practice session completed!")
            // TODO: Navigate to results screen or back to dashboard
            dismiss()
        } else {
            viewModel.nextQuestion()
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        PracticeView()
    }
}
