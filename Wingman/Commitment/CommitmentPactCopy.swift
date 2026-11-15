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
        headline: String(localized: "I am becoming a guy who takes action."),
        body: String(localized: "To achieve what I want, I must grow. I won’t let fear make the decision for me. I’ll take my chance, and learn from what happens.")
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
        return String(localized: "I, \(name), am becoming a guy who takes action.")
    }

    /// Instruction under the logo. Names the gesture explicitly — a hold with
    /// no affordance reads as a dead button, and users who tap and release get
    /// nothing without being told why.
    /// What the `headline` property of the commitment pact events carries.
    /// It has always been this fixed English sentence — never the rendered
    /// headline, so never the user's name — and it stays this sentence when
    /// `pact.headline` is translated. Deliberately a separate literal from
    /// the one shown on screen: one is data, the other is copy.
    static let analyticsHeadline = "I am becoming a guy who takes action."

    static let holdInstruction = String(localized: "Tap and hold to commit.")

    /// Replaces `holdInstruction` after a press that ends before the ring
    /// fills. About half of users tap first (replays, Nov 2026); the ring
    /// rewinding on its own doesn't say why nothing happened, and some
    /// German users left after a single tap.
    static let keepHolding = String(
        localized: "Keep holding until the ring fills.",
        comment: "Commitment pact screen, under the logo, after the user let go before the press-and-hold finished. The ring is the circle around the logo that fills while holding."
    )

    /// Replaces the instruction once the hold completes, for the beat before
    /// the screen hands off to the paywall.
    static let committed = String(localized: "Committed.")
}
