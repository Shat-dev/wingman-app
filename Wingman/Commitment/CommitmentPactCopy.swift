//
//  CommitmentPactCopy.swift
//  Wingman
//
//  Every word on the commitment pact screen lives here, so tuning the copy
//  never means touching the view. If you are A/B-ing wording, this is the
//  only file that needs to change — and `commitment_pact_viewed` /
//  `commitment_pact_committed` both carry `headline`, so variants split in
//  PostHog without any further plumbing.
//
//  One pact for everyone, deliberately. An earlier draft derived the headline
//  from the user's `goals` answer; this copy is written to speak to the whole
//  audience instead, and a single string is the honest way to ship that. The
//  hook for personalisation is a switch in `pact` away if that changes.
//
//  A note on what the pact promises, because it is the design of the screen:
//  it commits the user to *effort*, never to an outcome. "I'll approach
//  without freezing up" is a promise about a reaction they don't control —
//  easy to fail in week one, and a pact you have already broken is worse than
//  no pact. "Take my chance, and learn from what happens" is a promise the
//  user can keep by choosing to keep it.
//

import Foundation

enum CommitmentPactCopy {

    struct Pact {
        let headline: String
        let body: String
    }

    static let pact = Pact(
        headline: "I am becoming a guy who takes action.",
        body: "To achieve what I want, I must grow. I won’t let fear make the "
            + "decision for me. I’ll take my chance, and learn from what happens."
    )

    /// The headline as rendered, with the user's own name folded in when they
    /// gave one on the first onboarding screen: "I, Arthur, am becoming a guy
    /// who takes action."
    ///
    /// Falls back to `pact.headline` verbatim for everyone who skipped, so
    /// the screen a skipper sees is byte-for-byte the one that shipped before
    /// the name question existed.
    ///
    /// Personalisation is keyed to the *onboarding answer*, not to whatever
    /// display name happens to be on the account — see `OnboardingNameKey`.
    /// A user who skipped is not addressed by a name Apple supplied.
    ///
    /// This is presentation only. `pact.headline` remains the value both pact
    /// events carry, so A/B splits keep grouping by wording variant rather
    /// than fragmenting into one bucket per user — and no real name is ever
    /// sent to analytics.
    static func headline(for name: String?) -> String {
        guard let name, !name.isEmpty else { return pact.headline }
        return "I, \(name), am becoming a guy who takes action."
    }

    /// Instruction under the logo. Names the gesture explicitly — a hold with
    /// no affordance reads as a dead button, and users who tap and release get
    /// nothing without being told why.
    static let holdInstruction = "Tap and hold to commit."

    /// Replaces the instruction once the hold completes, for the beat before
    /// the screen hands off to the paywall.
    static let committed = "Committed."
}
