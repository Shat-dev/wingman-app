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
    /// Free-text name capture. Rendered by `NameScreen` rather than
    /// `QuestionScreen`, but still travels the flow as an `.question`
    /// *screen* so every existing `OnboardingScreen` switch keeps working
    /// unchanged — see `OnboardingView.screenContent(for:)`.
    case name
    /// The animated growth-curve projection. Asks nothing and stores nothing;
    /// it exists to make the payoff concrete right before the loading step.
    ///
    /// Travels as a `.question` screen for the same reason `.name` does — the
    /// navigation layer (history, progress, swipe-back, analytics) needed no
    /// new case, only a different body.
    case growthProjection
    /// Testimonials + "you're not the only one", shown after the loading
    /// screen as the last beat before pricing. Asks nothing and stores
    /// nothing, and travels as a `.question` screen like the two above.
    ///
    /// It is the only step that comes *after* `.loading`, which is what makes
    /// it the step that ends onboarding — see `handleSocialProofContinue`.
    case socialProof
}

struct OnboardingStep: Identifiable {
    // Deterministic id derived from `questionKey` so the same logical step
    // has the same identity across reconstructions. The loading step has a
    // nil `questionKey`; there's only one loading step in the flow, so the
    // "loading" fallback is unique.
    var id: String { questionKey ?? "loading" }
    let type: StepType

    let title: String
    let subtitle: String?

    let options: [String]?        // for questions

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

    /// What an option reads as on screen, where that differs from the value
    /// stored for it. Keyed by the stored value; anything not listed displays
    /// as itself.
    ///
    /// An option string is two things at once: the label on the button, and
    /// the value written to the answer store, to Supabase and to the
    /// `onboarding_<key>` PostHog person property. Correcting a typo in the
    /// string itself would start a second value in every breakdown of that
    /// answer, split from its own history by one letter. Listing the corrected
    /// wording here fixes what the user reads and leaves the stored value
    /// byte-for-byte what it has always been.
    private static let displayLabels: [String: String] = [
        "Fear of rejection or being embarrased": "Fear of rejection or being embarrassed"
    ]

    func displayLabel(for option: String) -> String {
        Self.displayLabels[option] ?? option
    }
}
