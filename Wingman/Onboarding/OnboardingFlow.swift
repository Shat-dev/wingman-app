//
//  OnboardingFlow.swift
//  Wingman
//
//  The authoritative list of onboarding steps shown to the user, in order.
//  Each step's `progress` drives the top progress bar; `questionKey` is the
//  storage key for the answer (both in-memory and in UserDefaults via
//  `onboarding_<key>`). The final `.loading` step has no questionKey and
//  fires the completion handler after a 3s dwell.
//

import Foundation

/// The three screen categories the coordinator can display, with the
/// contextual data each needs baked into the associated values. Hashable
/// conformance is required so `.id(screen)` can force SwiftUI to run the
/// enter/exit transitions on every navigation.
enum OnboardingScreen: Hashable {
    case question(index: Int)
    case statistic(sourceIndex: Int, content: StatisticContent)
    case loading(index: Int)

    /// Index into `extendedOnboardingSteps` this screen derives from. For
    /// `.statistic` that's the question it was shown after, since statistic
    /// interstitials have no step of their own.
    var stepIndex: Int {
        switch self {
        case let .question(index), let .loading(index):
            return index
        case let .statistic(sourceIndex, _):
            return sourceIndex
        }
    }

    var isStatistic: Bool {
        if case .statistic = self { return true }
        return false
    }
}

let extendedOnboardingSteps: [OnboardingStep] = [
    //1 Age Question
    OnboardingStep(
        type: .question,
        title: "How old are you?",
        subtitle: nil,
        options: ["18-24", "25-34", "35-44", "45+"],
        progress: 0.2,
        questionKey: "age"
    ),

    //2 Last Approach Question
    OnboardingStep(
        type: .question,
        title: "When was the last time you spoke to a woman in public?",
        subtitle: nil,
        options: ["Within the past week", "Within the past month", "A few months ago", "More than a year ago", "Never approached before"],
        progress: 0.35,
        questionKey: "last_approach"
    ),

    //3 Frequency Question
    OnboardingStep(
        type: .question,
        title: "Do you often want to talk to women but don’t?",
        subtitle: nil,
        options: ["Every time", "Most times", "Sometimes", "Rarely", "No, I usually go for it"],
        progress: 0.5,
        questionKey: "approach_frequency"
    ),

    //4 Barriers Question
    OnboardingStep(
        type: .question,
        title: "What usually stops you from doing so?",
        subtitle: nil,
        options: [
            "Fear of rejection or being embarrased",
            "Fear of social consequences",
            "Not knowing what to say or how to start",
            "Worrying about coming across wrong",
            "Other"
        ],
        progress: 0.65,
        questionKey: "barriers"
    ),

    //5 Goals Question
    OnboardingStep(
        type: .question,
        title: "What are you mainly hoping to improve?",
        subtitle: nil,
        options: [
            "Better mindset & confidence",
            "Learning how to approach",
            "Keeping conversations going",
            "Creating attraction and romantic interest",
            "Other"
        ],
        progress: 0.8,
        questionKey: "goals"
    ),

    // Loading Screen
    OnboardingStep(
        type: .loading,
        title: "Preparing your experience",
        subtitle: nil,
        options: nil,
        progress: 1.0,
        questionKey: nil
    )
]
