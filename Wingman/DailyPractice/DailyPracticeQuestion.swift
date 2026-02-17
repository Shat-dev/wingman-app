//
//  DailyPracticeQuestion.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import Foundation

enum QuestionType: String, Codable, CaseIterable {
    case singleSelect = "single_select"
    case multipleSelect = "multiple_select"
}

enum QuestionModule: String, CaseIterable, Codable {
    case mindsetFoundations = "mindset_foundations"
    case approachMechanics = "approach_mechanics"
    case conversationalSkills = "conversational_skills"
    case flirtingChemistry = "flirting_chemistry"
    case masteryIntegration = "mastery_integration"
    
    var displayName: String {
        switch self {
        case .mindsetFoundations: return "Mindset & Foundations"
        case .approachMechanics: return "Approach Mechanics"
        case .conversationalSkills: return "Conversational Skills"
        case .flirtingChemistry: return "Flirting & Chemistry"
        case .masteryIntegration: return "Mastery & Integration"
        }
    }
}

struct DailyPracticeQuestion: Identifiable, Codable {
    let id: UUID
    let number: Int
    let question: String
    let options: [String]
    let questionType: QuestionType
    let correctAnswerIndex: Int? // For single select
    let correctAnswerIndices: [Int]? // For multiple select
    let correctExplanation: String
    let incorrectExplanation: String
    
    // Single select initializer
    init(number: Int, question: String, options: [String], correctAnswerIndex: Int, correctExplanation: String, incorrectExplanation: String) {
        self.id = UUID()
        self.number = number
        self.question = question
        self.options = options
        self.questionType = .singleSelect
        self.correctAnswerIndex = correctAnswerIndex
        self.correctAnswerIndices = nil
        self.correctExplanation = correctExplanation
        self.incorrectExplanation = incorrectExplanation
    }
    
    // Multiple select initializer
    init(number: Int, question: String, options: [String], correctAnswerIndices: [Int], correctExplanation: String, incorrectExplanation: String) {
        self.id = UUID()
        self.number = number
        self.question = question
        self.options = options
        self.questionType = .multipleSelect
        self.correctAnswerIndex = nil
        self.correctAnswerIndices = correctAnswerIndices
        self.correctExplanation = correctExplanation
        self.incorrectExplanation = incorrectExplanation
    }
    
    // Full initializer for Supabase
    init(id: UUID, number: Int, question: String, options: [String], questionType: QuestionType, correctAnswerIndex: Int?, correctAnswerIndices: [Int]?, correctExplanation: String, incorrectExplanation: String) {
        self.id = id
        self.number = number
        self.question = question
        self.options = options
        self.questionType = questionType
        self.correctAnswerIndex = correctAnswerIndex
        self.correctAnswerIndices = correctAnswerIndices
        self.correctExplanation = correctExplanation
        self.incorrectExplanation = incorrectExplanation
    }
}

// MARK: - Supporting Models
struct SelectedAnswers: Codable {
    let singleSelect: Int?
    let multipleSelect: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case singleSelect = "single_select"
        case multipleSelect = "multiple_select"
    }
    
    init(singleSelect: Int) {
        self.singleSelect = singleSelect
        self.multipleSelect = nil
    }
    
    init(multipleSelect: [Int]) {
        self.singleSelect = nil
        self.multipleSelect = multipleSelect
    }
}

struct CompletionResponse: Codable {
    let success: Bool
    let message: String
    let isCorrect: Bool
}
