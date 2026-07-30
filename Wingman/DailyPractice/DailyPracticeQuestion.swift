//
//  DailyPracticeQuestion.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//
//  The question model itself moved to `Wingman/Quiz/QuizQuestion.swift` — it is
//  shared with the end-of-lesson quiz, which reads the same `public.questions`
//  rows. `QuestionType` moved with it. What remains here is the Daily
//  Practice-specific wire format for recording an answer.
//

import Foundation

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
