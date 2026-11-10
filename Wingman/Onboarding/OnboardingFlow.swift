//
//  OnboardingFlow.swift
//  Wingman
//
//  The authoritative list of onboarding steps shown to the user, in order.
//  Each step's `progress` drives the top progress bar; `questionKey` is the
//  storage key for the answer (both in-memory and in UserDefaults via
//  `onboarding_<key>`). The final `.loading` step has no questionKey and
//  fires the completion handler after its fixed ~4.5s step sequence.
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
    // The name step was removed here: the flow now opens on the first real
    // question. It was the only screen asking for typed input, and it stood
    // between the landing screen and the first tap-to-answer question — the
    // point in the funnel where intent is cheapest to lose.
    //
    // Removing the *step* is the whole change. Everything that reads the name
    // is deliberately left in place, because it all already handles the
    // skipped case as a first-class state — skipping was always allowed, so
    // "no name" is a path that has shipped and been exercised since the screen
    // existed:
    //
    //   - `OnboardingNameKey.current` returns nil, and keeps returning the
    //     stored value for users who answered the screen before this change.
    //     Their commitment pact stays personalised; nobody is downgraded.
    //   - `CommitmentPactCopy.headline(for:)` falls back to the generic
    //     headline, which is byte-for-byte the pre-name-screen wording.
    //   - `HomeViewModel.userName` never read this key at all — it reads
    //     `UserProfileStore.displayName`, so the greeting is untouched.
    //
    // `StepType.name`, `NameScreen` and `handleNameContinue` are kept too.
    // They cost nothing while unreferenced by this array, and putting the
    // screen back — for an A/B test, or if the drop-off doesn't move — is
    // re-adding this one entry rather than restoring a deleted screen.
    //
    // Note for the funnel: `onboarding_name_answered` stops firing from this
    // build on, so any insight with that event as a step will read zero and
    // show a total drop there. The per-screen drop-off funnel needs that step
    // deleted, not reinterpreted.

    //1 Motivation Question
    //
    // Opens the flow on *why* they downloaded, before anything form-like.
    // Options describe a situation rather than a flaw ("Tired of being on my
    // own", not "I'm lonely") so nobody has to label themselves on the first
    // screen to answer it.
    //
    // Multi-select: stored ", "-joined, so no option's stored value may
    // contain ", ". The answers themselves are defined in `OnboardingOption.swift`.
    // Stored under `onboarding_motivation` in PostHog like every other answer.
    OnboardingStep(
        type: .question,
        title: "What brought you to Wingman?",
        subtitle: nil,
        choices: MotivationOption.options,
        progress: 0.13,
        questionKey: "motivation"
    ),

    //2 Age Question
    OnboardingStep(
        type: .question,
        title: "How old are you?",
        subtitle: nil,
        // "45+" was split into "45-54" and "55+". As one open-ended bracket it
        // held about 29% of answers and roughly half of the paid conversions,
        // so it was the one bracket worth being able to see inside.
        //
        // Nothing is migrated. Anyone who answered before the split keeps the
        // stored value "45+": `StatisticContent` handles it explicitly, and
        // the PostHog age tiles group by the raw string, so it simply stays a
        // bar of its own next to the two new ones.
        choices: AgeOption.options,
        // Progress rebalanced across the seven steps that now precede loading.
        // Left at the old 0.3 this would open the flow with the bar already a
        // third full, which reads as progress the user hasn't made yet.
        progress: 0.25,
        questionKey: "age"
    ),

    //3 Last Approach Question
    OnboardingStep(
        type: .question,
        title: "When was the last time you spoke to a woman in public?",
        subtitle: nil,
        choices: LastApproachOption.options,
        progress: 0.38,
        questionKey: "last_approach"
    ),

    //4 Frequency Question
    OnboardingStep(
        type: .question,
        title: "Do you often want to talk to women but don’t?",
        subtitle: nil,
        choices: ApproachFrequencyOption.options,
        progress: 0.50,
        questionKey: "approach_frequency"
    ),

    //5 Barriers Question
    OnboardingStep(
        type: .question,
        title: "What usually stops you from doing so?",
        subtitle: nil,
        // The stored value of the first option is misspelled on purpose
        // ("embarrased"); users read the corrected label. Both live in
        // `BarrierOption`.
        choices: BarrierOption.options,
        progress: 0.63,
        questionKey: "barriers"
    ),

    //6 Goals Question
    OnboardingStep(
        type: .question,
        title: "What are you mainly hoping to improve?",
        subtitle: nil,
        choices: GoalOption.options,
        progress: 0.75,
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
        choices: nil,
        progress: 0.88,
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
        choices: nil,
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
        choices: nil,
        progress: 1.0,
        questionKey: "social_proof"
    )
]
