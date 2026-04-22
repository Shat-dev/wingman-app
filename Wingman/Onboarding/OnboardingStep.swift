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
    case loading
}

struct OnboardingStep: Identifiable {
    let id = UUID()
    let type: StepType

    let title: String
    let subtitle: String?

    let options: [String]?        // for questions
    let chartImage: String?       // for statistics

    let progress: Double          // 0.0–1.0
    let questionKey: String?      // for saving answers

    /// Questions that allow multiple selections ("Select all that apply").
    /// Computed from `questionKey` so existing call-sites that construct
    /// `OnboardingStep` don't need to pass a new parameter — any step whose
    /// key is in this set renders with a multi-select label and toggles
    /// selection on tap; everything else remains single-select.
    var isMultiSelect: Bool {
        guard let key = questionKey else { return false }
        return key == "barriers" || key == "goals"
    }
}
