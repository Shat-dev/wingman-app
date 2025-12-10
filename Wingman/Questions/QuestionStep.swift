//
//  QuestionStep.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import SwiftUI

enum StepType {
    case question
    case statistic
}

struct QuestionStep: Identifiable {
    let id = UUID()
    let type: StepType
    
    let title: String
    let subtitle: String?
    
    let options: [String]?        // for questions
    let chartImage: String?       // for statistics
    
    let progress: Double          // 0.0—1.0
}
