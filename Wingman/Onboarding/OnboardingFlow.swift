//
//  OnboardingFlow.swift
//  Wingman
//
//  The authoritative list of onboarding steps shown to the user, in order.
//  Each step's `progress` drives the top progress bar; `questionKey` is the
//  storage key for the answer (both in-memory and in UserDefaults via
//  `onboarding_<key>`). The final `.loading` step has no questionKey and
//  fires the completion handler after its fixed ~6.2s step sequence.
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
    //1 Name (skippable)
    //
    // Free text, and the only step in the flow the user is allowed to leave
    // unanswered. Skipping stores nothing, which is what every downstream
    // reader treats as "no name": the home greeting keeps saying "User" and
    // the commitment pact keeps its generic headline.
    OnboardingStep(
        type: .name,
        title: "What's your name?",
        subtitle: "So Wingman can talk to you, not at you.",
        options: nil,
        progress: 0.15,
        questionKey: OnboardingNameKey.answerKey
    ),

    //2 Age Question
    OnboardingStep(
        type: .question,
        title: "How old are you?",
        subtitle: nil,
        options: ["18-24", "25-34", "35-44", "45+"],
        progress: 0.3,
        questionKey: "age"
    ),

    //3 Last Approach Question
    OnboardingStep(
        type: .question,
        title: "When was the last time you spoke to a woman in public?",
        subtitle: nil,
        options: ["Within the past week", "Within the past month", "A few months ago", "More than a year ago", "Never approached before"],
        progress: 0.42,
        questionKey: "last_approach"
    ),

    //4 Frequency Question
    OnboardingStep(
        type: .question,
        title: "Do you often want to talk to women but don’t?",
        subtitle: nil,
        options: ["Every time", "Most times", "Sometimes", "Rarely", "No, I usually go for it"],
        progress: 0.55,
        questionKey: "approach_frequency"
    ),

    //5 Barriers Question
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
        progress: 0.68,
        questionKey: "barriers"
    ),

    //6 Goals Question
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
        progress: 0.82,
        questionKey: "goals"
    ),

    //7 Growth projection
    //
    // Placed after `goals` deliberately: the user has just said what they
    // want to improve, so the rising curve reads as an answer to that rather
    // than as a generic pitch.
    //
    // `title` and `subtitle` are unused — `GrowthProjectionScreen` carries its
    // own copy in `GrowthProjectionContent` so the wording can be swapped
    // without touching this list. They are filled in anyway because every
    // other step has them and a blank title here would look like an omission.
    //
    // `questionKey` is present only to give the step a stable `id` and an
    // analytics label; nothing is ever stored under it.
    OnboardingStep(
        type: .growthProjection,
        title: "Build the confidence to take action when it matters",
        subtitle: nil,
        options: nil,
        progress: 0.91,
        questionKey: "growth_projection"
    ),

    // Loading Screen
    //
    // `subtitle` is the static line under the step rows, not a question
    // subtitle — see `LoadingScreen`.
    OnboardingStep(
        type: .loading,
        title: "Optimizing your experience",
        subtitle: "Confidence is a skill. Skills are built.",
        options: nil,
        progress: 1.0,
        questionKey: nil
    ),

    //9 Social proof
    //
    // The one step that sits *after* the loading screen, and therefore the
    // step that ends onboarding: its Continue calls `completeQuestions()`,
    // which is what the loading screen's `onComplete` used to do directly.
    //
    // Placed last deliberately. Everything before it is about the user; this
    // is the one screen about everyone else, and it lands immediately before
    // the router shows the pact or the paywall.
    //
    // `title` and `subtitle` are unused — `SocialProofScreen` carries its own
    // copy in `SocialProofContent`, the same split `GrowthProjectionScreen`
    // uses. Filled in anyway so this entry doesn't read as an omission.
    //
    // `progress` matches the loading step's 1.0: the bar is already full by
    // the time the user gets here, and backing it off would read as the flow
    // having gained work rather than finished it.
    //
    // `questionKey` exists only to give the step a stable `id` and an
    // analytics label; nothing is ever stored under it.
    OnboardingStep(
        type: .socialProof,
        title: "Join the men taking action",
        subtitle: nil,
        options: nil,
        progress: 1.0,
        questionKey: "social_proof"
    )
]
