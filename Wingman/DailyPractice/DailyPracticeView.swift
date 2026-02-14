//
//  PracticeView.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI
import Combine

struct DailyPracticeView: View {
    @StateObject private var viewModel = DailyPracticeViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityManager
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Top Row: Back Chevron + Progress Bar
            HStack(spacing: 10) {
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
            .padding(.leading, 8)
            .padding(.trailing, 59)
            .padding(.bottom, 12)
            
            // MARK: - Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Question Number and Text
                    Text("\(viewModel.currentQuestion.number). \(viewModel.currentQuestion.question)")
                        .font(.manropeMedium(size: 20))
                        .foregroundColor(.black)
                        .lineSpacing(2)
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
        .ignoresSafeArea(edges: .bottom) // Ignore bottom safe area to fill tab bar space
        .toolbar(.hidden, for: .tabBar) // Hide system tab bar if present
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasCheckedAnswer)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedOptionIndex)
        .onAppear {
            tabBarVisibility.hideTabBar()
            print("👁️ PracticeView appeared - Question \(viewModel.currentQuestionIndex + 1)/\(viewModel.questions.count)")
        }
        .onDisappear {
            tabBarVisibility.showTabBar()
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
                    .stroke(buttonBorderColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong), lineWidth: 1) // 1pt border
            )
        }
        .disabled(viewModel.hasCheckedAnswer)
    }
    
    private func buttonTextColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            // Correct option text should be green
            return Color(hex: "#3E8F6A")
        } else if isWrong {
            // Red text for wrong option
            return Color(hex: "#C9594C")
        } else if isSelected {
            return Color(hex: "#FFFFFF")
        } else {
            return Color(hex: "#1A1A1A")
        }
    }
    
    private func buttonBackgroundColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            // Keep your original correct background
            return Color(hex: "#DAF0E6")
        } else if isWrong {
            // Lighter red background for wrong option
            return Color(hex: "#F4DEDB")
        } else if isSelected {
            return Color(hex: "#000000")
        } else {
            return Color(hex: "#FFFFFF")
        }
    }
    
    private func buttonBorderColor(isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect {
            // Green border for correct option
            return Color(hex: "#3E8F6A")
        } else if isWrong {
            // Red border for wrong option
            return Color(hex: "#C9594C")
        } else if isSelected {
            return Color(hex: "#1A1A1A")
        } else {
            // Default border
            return Color(hex: "#1A1A1A").opacity(0.5)
        }
    }
    
    // MARK: - Explanation View WITH Next Button at Bottom of Screen
    private func explanationViewWithButton() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(viewModel.isAnswerCorrect ? "Correct Answer!" : "Incorrect Answer.")
                    .font(.manropeSemiBold(size: 18))
                    .foregroundColor(viewModel.isAnswerCorrect ? Color(hex: "#339966") : Color(hex: "#CC4D4D"))
            }
            
            
            // Explanation text
            Text(viewModel.isAnswerCorrect ? viewModel.currentQuestion.correctExplanation : viewModel.currentQuestion.incorrectExplanation)
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(Color(hex: "#1A1A1A").opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Next Button Inside
            Button(action: {
                handleNextButton()
            }) {
                Text("Next")
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(viewModel.isAnswerCorrect ? Color(hex: "#3E8F6A") : Color(hex: "#C9594C"))
                    .cornerRadius(5)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            viewModel.isAnswerCorrect
                ? Color(hex: "#E6F7F0")
                : Color(hex: "#FFEDED")
        )
        .cornerRadius(5)
        .padding(.horizontal,8)
    }
    
    // MARK: - Action Button (Check Answer - before checking)
    private func actionButton() -> some View {
        Button(action: {
            viewModel.checkAnswer()
        }) {
            Text("Check Answer")
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.selectedOptionIndex != nil ? Color(hex: "#000000") : Color(hex: "#000000").opacity(0.4))
                .cornerRadius(5) // Updated to 5px corner radius
        }
        .disabled(viewModel.selectedOptionIndex == nil)
    }
    
    // MARK: - Navigation Handlers
    private func handleBackButton() {
        if viewModel.currentQuestionIndex > 0 {
            print("⬅️ Back button: Going to previous question")
            viewModel.previousQuestion()
        } else {
            print("Practice session completed!")
            tabBarVisibility.showTabBar()
            dismiss()
        }
    }
    
    private func handleNextButton() {
        if viewModel.isLastQuestion {
            print("Practice session completed!")
            // TODO: Navigate to results screen or back to dashboard
            tabBarVisibility.showTabBar()
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
        DailyPracticeView()
            .environmentObject(TabBarVisibilityManager())
    }
}
