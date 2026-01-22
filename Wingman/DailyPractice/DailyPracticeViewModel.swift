//
//  PracticeViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//


//
//  PracticeViewModel.swift
//  Wingman
//

import Foundation
import Combine

final class DailyPracticeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentQuestionIndex: Int = 0
    @Published var selectedOptionIndex: Int? = nil
    @Published var hasCheckedAnswer: Bool = false
    @Published var isAnswerCorrect: Bool = false
    
    // MARK: - Data
    let questions: [DailyPracticeQuestion] = practiceQuestions
    
    // MARK: - Computed Properties
    var currentQuestion: DailyPracticeQuestion {
        questions[currentQuestionIndex]
    }
    
    var progress: Double {
        Double(currentQuestionIndex + 1) / Double(questions.count)
    }
    
    var isCheckAnswerEnabled: Bool {
        selectedOptionIndex != nil && !hasCheckedAnswer
    }
    
    var buttonTitle: String {
        if hasCheckedAnswer {
            return "Next"
        } else {
            return "Check Answer"
        }
    }
    
    var buttonBackgroundColor: ButtonColorState {
        if !hasCheckedAnswer && selectedOptionIndex == nil {
            return .disabled // Gray
        } else if hasCheckedAnswer && isAnswerCorrect {
            return .correct // Green
        } else if hasCheckedAnswer && !isAnswerCorrect {
            return .incorrect // Red
        } else {
            return .enabled // Black
        }
    }
    
    var isLastQuestion: Bool {
        currentQuestionIndex == questions.count - 1
    }
    
    // MARK: - Actions
    func selectOption(at index: Int) {
        guard !hasCheckedAnswer else {
            print("⚠️ Cannot select option after checking answer")
            return
        }
        
        print("📝 User selected option \(index): \(currentQuestion.options[index])")
        selectedOptionIndex = index
    }
    
    func checkAnswer() {
        guard let selected = selectedOptionIndex else {
            print("❌ No option selected")
            return
        }
        
        hasCheckedAnswer = true
        isAnswerCorrect = (selected == currentQuestion.correctAnswerIndex)
        
        print("\n✅ Answer checked!")
        print("   - Selected: \(currentQuestion.options[selected])")
        print("   - Correct answer: \(currentQuestion.options[currentQuestion.correctAnswerIndex])")
        print("   - Result: \(isAnswerCorrect ? "CORRECT ✅" : "INCORRECT ❌")")
    }
    
    func nextQuestion() {
        guard hasCheckedAnswer else {
            print("⚠️ Must check answer before proceeding")
            return
        }
        
        if currentQuestionIndex < questions.count - 1 {
            print("\n➡️ Moving to next question (\(currentQuestionIndex + 2)/\(questions.count))")
            currentQuestionIndex += 1
            resetQuestion()
        } else {
            print("\n🎉 All questions completed!")
            // Handle completion - could navigate to results screen
        }
    }
    
    func previousQuestion() {
        if currentQuestionIndex > 0 {
            print("\n⬅️ Moving to previous question (\(currentQuestionIndex)/\(questions.count))")
            currentQuestionIndex -= 1
            resetQuestion()
        }
    }
    
    private func resetQuestion() {
        selectedOptionIndex = nil
        hasCheckedAnswer = false
        isAnswerCorrect = false
        print("🔄 Question state reset")
    }
    
    func reset() {
        print("🔄 Resetting entire practice session")
        currentQuestionIndex = 0
        resetQuestion()
    }
}

// MARK: - Button Color State
enum ButtonColorState {
    case disabled
    case enabled
    case correct
    case incorrect
}
