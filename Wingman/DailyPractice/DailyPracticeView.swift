//
//  DailyPracticeView.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI
import Combine

struct DailyPracticeView: View {
    @StateObject private var viewModel: DailyPracticeViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityManager
    
    // Default initializer for production use
    init() {
        self._viewModel = StateObject(wrappedValue: DailyPracticeViewModel())
    }
    
    // Preview initializer for Canvas testing
    init(previewViewModel: DailyPracticeViewModel) {
        self._viewModel = StateObject(wrappedValue: previewViewModel)
    }
    
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
                
                if !viewModel.questions.isEmpty {
                    progressBar(progress: CGFloat(viewModel.progress))
                        .frame(height: 10)
                } else {
                    // Placeholder progress bar while loading
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                }
            }
            .padding(.top, 8)
            .padding(.leading, 8)
            .padding(.trailing, 59)
            .padding(.bottom, 12)
            
            // MARK: - Main Content Area
            if viewModel.isLoading {
                loadingView()
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.questions.isEmpty {
                emptyStateView()
            } else {
                questionContentView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(edges: .bottom)
        .toolbar(.hidden, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasCheckedAnswer)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedOptionIndex)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedOptionIndices)
        .onAppear {
            tabBarVisibility.hideTabBar()
            print("👁️ PracticeView appeared - Loading questions from Supabase")
            
            // Only load from Supabase if questions are empty (not in preview mode)
            if viewModel.questions.isEmpty {
                viewModel.loadTodayQuestions()
            }
        }
        .onDisappear {
            tabBarVisibility.showTabBar()
        }
    }
    
    // MARK: - Loading View
    private func loadingView() -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading today's practice questions...")
                .font(.manropeMedium(size: 18))
                .foregroundColor(.black.opacity(0.7))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        print("ErrorView message: \(message)")
        return ZStack {
           
            
            VStack {
                
                Spacer()
                
                // Center Content
                VStack() {
                    
                    Text("Oops!")
                        .font(.manropeSemiBold(size: 24))
                        .foregroundColor(.black)
                    Text("Somthing went wrong")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.black)
                        .padding(.top,2)
                    Text("Please Try again!")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.black)
                    
//                    Text(message)
//                        .font(.manropeSemiBold(size: 16))
//                        .foregroundColor(.black.opacity(0.7))
//                        .multilineTextAlignment(.center)

                    
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                
                // Bottom Button
                Button(action: {
                    viewModel.loadTodayQuestions()
                }) {
                    Text("Try Again")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .cornerRadius(5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Empty State View
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.gray)
            
            Text("No questions available")
                .font(.manropeSemiBold(size: 20))
                .foregroundColor(.black)
            
            Text("Check back later for new practice questions.")
                .font(.manropeMedium(size: 16))
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Question Content View
    private func questionContentView() -> some View {
        VStack(spacing: 0) {
            // Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Question Number and Text
                    Text("\(viewModel.currentQuestion.number). \(viewModel.currentQuestion.question)")
                        .font(.manropeMedium(size: 20))
                        .foregroundColor(.black)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // MARK: - Options
                    VStack(spacing: 12) {
                        ForEach(Array(viewModel.currentQuestion.options.enumerated()), id: \.offset) { index, option in
                            if viewModel.currentQuestion.questionType == .singleSelect {
                                singleSelectOptionButton(
                                    text: option,
                                    index: index,
                                    isSelected: viewModel.isOptionSelected(index),
                                    isCorrect: viewModel.isOptionCorrect(index),
                                    isWrong: viewModel.isOptionIncorrect(index)
                                )
                            } else {
                                multipleSelectOptionButton(
                                    text: option,
                                    index: index,
                                    isSelected: viewModel.isOptionSelected(index),
                                    isCorrect: viewModel.isOptionCorrect(index),
                                    isWrong: viewModel.isOptionIncorrect(index),
                                    shouldShowCorrectButNotSelected: viewModel.shouldShowCorrectButNotSelected(index)
                                )
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
            if viewModel.hasCheckedAnswer {
                // Explanation with Next Button at Bottom
                explanationViewWithButton()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Check Answer Button
                actionButton()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
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
    
    // MARK: - Single Select Option Button
    private func singleSelectOptionButton(text: String, index: Int, isSelected: Bool, isCorrect: Bool, isWrong: Bool) -> some View {
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
                    .stroke(buttonBorderColor(isSelected: isSelected, isCorrect: isCorrect, isWrong: isWrong), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.0002), radius: 0.03, x: 0, y: 0.01)
        }
        .disabled(viewModel.hasCheckedAnswer)
    }
    
    // MARK: - Multiple Select Option Button with Checkbox
    private func multipleSelectOptionButton(text: String, index: Int, isSelected: Bool, isCorrect: Bool, isWrong: Bool, shouldShowCorrectButNotSelected: Bool) -> some View {
        Button(action: {
            viewModel.selectOption(at: index)
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
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .disabled(viewModel.hasCheckedAnswer)
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
               
            } else if isSelected && (isCorrect || (!viewModel.hasCheckedAnswer)) {
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
            return Color.black
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
            return Color.black // Black background for selected items before checking
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
            return Color.black
        } else {
            return Color.customDark.opacity(0.5)
        }
    }
    
    // MARK: - Explanation View WITH Next Button at Bottom of Screen
    private func explanationViewWithButton() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(viewModel.isAnswerCorrect ? "Correct Answer!" : "Incorrect Answer.")
                    .font(.manropeSemiBold(size: 18))
                    .foregroundColor(viewModel.isAnswerCorrect ? Color.customCorrectGreen : Color.customIncorrectRed)
            }
            
            // Explanation text
            Text(viewModel.isAnswerCorrect ? viewModel.currentQuestion.correctExplanation : viewModel.currentQuestion.incorrectExplanation)
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(Color.customDark.opacity(0.85))
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
                    .background(viewModel.isAnswerCorrect ? Color.customGreen : Color.customRed)
                    .cornerRadius(5)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            viewModel.isAnswerCorrect
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
            viewModel.checkAnswer()
        }) {
            Text("Check Answer")
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.isCheckAnswerEnabled ? Color.black : Color.black.opacity(0.4))
                .cornerRadius(5)
        }
        .disabled(!viewModel.isCheckAnswerEnabled)
    }
    
    // MARK: - Navigation Handlers
    private func handleBackButton() {
        if !viewModel.questions.isEmpty && viewModel.currentQuestionIndex > 0 {
            print("⬅️ Back button: Going to previous question")
            viewModel.previousQuestion()
        } else {
            print("Exiting practice session")
            tabBarVisibility.showTabBar()
            dismiss()
        }
    }
    
    private func handleNextButton() {
        if viewModel.isLastQuestion {
            print("Practice session completed!")
            tabBarVisibility.showTabBar()
            dismiss()
        } else {
            viewModel.nextQuestion()
        }
    }
}

// MARK: - Custom Button Style
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.manropeSemiBold(size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.black)
            .cornerRadius(5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Custom Color Extensions
extension Color {
    static let customGreen = Color(red: 0.243, green: 0.561, blue: 0.416) // #3E8F6A
    static let customRed = Color(red: 0.788, green: 0.349, blue: 0.298) // #C9594C
    static let customDark = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
    static let customLightGreen = Color(red: 0.855, green: 0.941, blue: 0.902) // #DAF0E6
    static let customLightRed = Color(red: 0.957, green: 0.871, blue: 0.859) // #F4DEDB
    static let customLightGray = Color(red: 0.953, green: 0.953, blue: 0.953) // #F3F3F3
    static let customCorrectGreen = Color(red: 0.2, green: 0.6, blue: 0.4) // #339966
    static let customIncorrectRed = Color(red: 0.8, green: 0.302, blue: 0.302) // #CC4D4D
    static let customExplanationGreen = Color(red: 0.902, green: 0.969, blue: 0.941) // #E6F7F0
    static let customExplanationRed = Color(red: 1.0, green: 0.929, blue: 0.929) // #FFEDED
}



#Preview {
    NavigationStack {
        // Create a view model with dummy data for Canvas preview
        let previewViewModel = DailyPracticeViewModel()
        
        // Add dummy questions - 2 multiple choice and 1 single option
        let dummyQuestions = [
            // Question 1: Multiple Select
            DailyPracticeQuestion(
                number: 1,
                question: "Which are key for confident body language?",
                options: [
                    "Eye contact",
                    "Good posture",
                    "Fidgeting",
                    "Speaking clearly"
                ],
                correctAnswerIndices: [0, 1, 3],
                correctExplanation: "Great! Maintaining eye contact, standing with good posture, and speaking clearly all project confidence and make a positive first impression.",
                incorrectExplanation: "Remember that confident body language includes maintaining eye contact, good posture, and clear speech. Avoid fidgeting or defensive postures as they can signal nervousness or discomfort."
            ),
            
            // Question 2: Multiple Select
            DailyPracticeQuestion(
                number: 2,
                question: "Effective ways to start a conversation?",
                options: [
                    "Compliment outfit",
                    "Ask about venue",
                    "Generic pickup line",
                    "Observe environment"
                ],
                correctAnswerIndices: [0, 1, 3],
                correctExplanation: "Excellent! Specific compliments, asking about the event, and making environmental observations are all natural conversation starters that feel genuine and engaging.",
                incorrectExplanation: "Focus on authentic conversation starters. Avoid generic pickup lines or immediately asking for contact information, as these can feel forced or pushy."
            ),
            
            // Question 3: Single Select
            DailyPracticeQuestion(
                number: 3,
                question: "Best mindset when approaching someone?",
                options: [
                    "Need to impress",
                    "Hope they like me",
                    "Genuinely curious",
                    "Need to be perfect"
                ],
                correctAnswerIndex: 2,
                correctExplanation: "Perfect! Approaching with genuine curiosity takes the pressure off and makes the interaction more natural and enjoyable for both people.",
                incorrectExplanation: "The best mindset is one of genuine curiosity. Trying to impress, seeking validation, or fearing imperfection creates pressure and can make interactions feel forced."
            )
        ]
        
        // Configure the preview view model with dummy data
        previewViewModel.questions = dummyQuestions
        previewViewModel.isLoading = false
        previewViewModel.errorMessage = nil
        
        return DailyPracticeView(previewViewModel: previewViewModel)
            .environmentObject(TabBarVisibilityManager())
    }
}
