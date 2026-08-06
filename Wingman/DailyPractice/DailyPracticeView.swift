//
//  DailyPracticeView.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI
import Combine
import PostHog

struct DailyPracticeView: View {
    @StateObject private var viewModel: DailyPracticeViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityManager

    // Closure owned by the outer NavigationStack (HomeView) that flips its
    // `navigateToPractice` binding to false. Used from QuestionsCompleteView's
    // Continue button — DailyPracticeView's own @Environment(\.dismiss) is a
    // no-op once QuestionsCompleteView is pushed on top, so we bypass it and
    // let the outermost binding unwind the whole stack in one shot.
    private let onCompletionDismiss: () -> Void

    // Analytics: stamped once the day's questions are actually on screen, so
    // `daily_challenge_completed` can report how long the set took. A failed
    // or empty load never stamps it, which keeps aborted loads out of the
    // started/completed funnel entirely.
    @State private var startedAt: Date?

    // Default initializer for production use
    init(onCompletionDismiss: @escaping () -> Void = {}) {
        self.onCompletionDismiss = onCompletionDismiss
        self._viewModel = StateObject(wrappedValue: DailyPracticeViewModel())
    }

    // Preview initializer for Canvas testing
    init(previewViewModel: DailyPracticeViewModel) {
        self.onCompletionDismiss = {}
        self._viewModel = StateObject(wrappedValue: previewViewModel)
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Top Row: Back Chevron + Progress Bar
            // Hide when showing error (e.g., no internet)
            if viewModel.errorMessage == nil {
                HStack(spacing: 10) {
                    Button {
                        handleBackButton()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScalePressStyle())
                    
                    if !viewModel.questions.isEmpty {
                        QuizProgressBar(progress: viewModel.progress)
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
            }
            
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
        .navigationDestination(isPresented: $viewModel.showCompletionView) {
            QuestionsCompleteView(
                currentStreak: viewModel.currentStreak,
                dismissDailyPractice: onCompletionDismiss
            )
            .environmentObject(tabBarVisibility)
        }
        .onChange(of: viewModel.questions.isEmpty) { isEmpty in
            // Analytics: the day's questions have rendered — this is the point
            // the user genuinely enters the content, as opposed to landing on
            // a spinner that may yet fail.
            if !isEmpty { logChallengeStarted() }
        }
        .onChange(of: viewModel.showCompletionView) { showing in
            guard showing else { return }

            // Analytics: genuine completion only. The view model sets this
            // flag after the final question is answered and the streak write
            // resolves; backing out with the chevron never sets it.
            var properties: [String: Any] = ["question_count": viewModel.questions.count]
            if let startedAt {
                properties["duration_seconds"] = Analytics.elapsedSeconds(since: startedAt)
            }
            Analytics.capture(Analytics.Event.dailyChallengeCompleted, properties)
        }
        .onAppear {
            tabBarVisibility.hideTabBar()
            log("👁️ PracticeView appeared - Loading questions from Supabase")

            // Only load from Supabase if questions are empty (not in preview mode)
            if viewModel.questions.isEmpty {
                viewModel.loadTodayQuestions()
            } else {
                // Preview / already-warm path: `onChange` won't fire because
                // the value never transitions, so start the run here instead.
                logChallengeStarted()
            }
        }
        .onDisappear {
            log("👋 PracticeView disappeared")
        }
        .trackScreenView("Daily Practice")
    }
    
    // MARK: - Analytics

    /// Fire `daily_challenge_started` once per run. Guarded on `startedAt` so
    /// a silent background refresh that repopulates `questions` can't emit a
    /// second start for the same sitting.
    private func logChallengeStarted() {
        guard startedAt == nil else { return }
        startedAt = Date()
        Analytics.capture(Analytics.Event.dailyChallengeStarted, [
            "question_count": viewModel.questions.count
        ])
    }

    // MARK: - Loading View
    private func loadingView() -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading today's practice questions...")
                .font(.manropeMedium(size: 18))
                .foregroundColor(.wingmanBlack.opacity(0.7))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        log("ErrorView message: \(message)")
        return ZStack {
            
            VStack {
                
                // Back button at top
                HStack {
                    Button {
                        // Use the shared back handler so the custom tab bar is
                        // always restored before dismissing, regardless of
                        // which exit path the user takes.
                        handleBackButton()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScalePressStyle())

                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.top, 8)
                
                Spacer()
                
                // Center Content
                VStack() {
                    
                    Text("Oops!")
                        .font(.manropeSemiBold(size: 24))
                        .foregroundColor(.wingmanBlack)
                    Text("Something went wrong")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .padding(.top,2)
                    Text("Please Try again!")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)
                    
//                    Text(message)
//                        .font(.manropeSemiBold(size: 16))
//                        .foregroundColor(.wingmanBlack.opacity(0.7))
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
                        .background(Color.wingmanBlack)
                        .cornerRadius(5)
                }
                .buttonStyle(ScalePressStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
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
                .foregroundColor(.wingmanBlack)
            
            Text("Check back later for new practice questions.")
                .font(.manropeMedium(size: 16))
                .foregroundColor(.wingmanBlack.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Question Content View
    //
    // The question prompt, options, explanation panel and Check/Next button
    // now live in the shared `QuizQuestionView` so the end-of-lesson quiz can
    // render the identical UI. Everything visual moved across verbatim; this
    // view keeps the parts that are specific to Daily Practice — loading,
    // error and empty states, analytics, streaks, and navigation.
    private func questionContentView() -> some View {
        QuizQuestionView(
            state: viewModel.questionState,
            onSelectOption: { index in
                viewModel.selectOption(at: index)
            },
            onCheckAnswer: {
                // Haptic stays here rather than inside QuizQuestionView: the
                // shared view renders, the caller owns side effects.
                HapticManager.shared.mediumImpact()
                viewModel.checkAnswer()
            },
            onNext: {
                handleNextButton()
            }
        )
    }

    
    // MARK: - Navigation Handlers
    private func handleBackButton() {
        if !viewModel.questions.isEmpty && viewModel.currentQuestionIndex > 0 {
            log("⬅️ Back button: Going to previous question")
            viewModel.previousQuestion()
        } else {
            log("Exiting practice session")
            tabBarVisibility.showTabBar()
            dismiss()
        }
    }
    
    private func handleNextButton() {
        if viewModel.isLastQuestion {
            // IMPORTANT: Call nextQuestion() first to trigger completion logic
            // This will update streak, show completion view, etc.
            log("📍 Last question - calling nextQuestion() to trigger completion logic")
            viewModel.nextQuestion()
            
            // Don't dismiss here - let the completion view sheet handle navigation
            // The completion view will dismiss this view when user taps "Continue"
            log("✅ Completion logic triggered - completion view will be shown")
        } else {
            log("Moving to next question")
            viewModel.nextQuestion()
        }
    }
}

// MARK: - Custom Color Extensions

#Preview {
    NavigationStack {
        // Create a view model with dummy data for Canvas preview
        let previewViewModel = DailyPracticeViewModel()
        
        // Add dummy questions - 2 multiple choice and 1 single option
        let dummyQuestions = [
            // Question 1: Multiple Select
            QuizQuestion(
                number: 1,
                question: "Which are key for confident body language?",
                options: [
                    "Eye contact",
                    "Good posture",
                    "Fidgeting",
                    "Speaking clearly"
                ],
                correctAnswerIndices: [0, 1, 3],
                explanation: "Confident body language includes maintaining eye contact, standing with good posture, and speaking clearly. These all project confidence and make a positive first impression. Avoid fidgeting as it can signal nervousness."
            ),
            
            // Question 2: Multiple Select
            QuizQuestion(
                number: 2,
                question: "Effective ways to start a conversation?",
                options: [
                    "Compliment outfit",
                    "Ask about venue",
                    "Generic pickup line",
                    "Observe environment"
                ],
                correctAnswerIndices: [0, 1, 3],
                explanation: "Effective conversation starters include specific compliments, asking about the event or venue, and making environmental observations. These feel natural and engaging. Avoid generic pickup lines as they can feel forced."
            ),
            
            // Question 3: Single Select
            QuizQuestion(
                number: 3,
                question: "Best mindset when approaching someone?",
                options: [
                    "Need to impress",
                    "Hope they like me",
                    "Genuinely curious",
                    "Need to be perfect"
                ],
                correctAnswerIndex: 2,
                explanation: "The best mindset is genuine curiosity. This takes the pressure off and makes the interaction more natural and enjoyable for both people. Avoid trying to impress or seeking validation as this creates unnecessary pressure."
            )
        ]
        
        // Configure the preview view model with dummy data
        previewViewModel.loadForPreview(dummyQuestions)
        
        return DailyPracticeView(previewViewModel: previewViewModel)
            .environmentObject(TabBarVisibilityManager())
    }
}
