//
//  AuthMode.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

enum AuthMode {
    case signup
    case login
}

/// How the user arrived at an `AuthView`.
///
/// Deliberately separate from `AuthMode`: `mode` decides *what* the screen does
/// (sign up vs. log in), `AuthContext` decides how it has to *behave and read*
/// given how the user got there. The two are orthogonal — a required screen is
/// always `.signup` today, but the copy and the back affordance are driven by
/// arrival, not by mode.
enum AuthContext {
    /// The user asked to be here: LandingView's Create Account / Log In, and
    /// the unauthenticated login routing branch. Backing out is allowed and the
    /// copy is a straightforward pitch.
    case voluntary

    /// The forced account-creation step after paywall #1 (RootView's anonymous
    /// branch). The user declined to pay and did not ask for this screen, so it
    /// arrives unrequested, immediately after a wall, with no way back.
    ///
    /// That combination is why users were dropping here: it reads as a second
    /// paywall. The copy for this context therefore has three jobs the
    /// voluntary copy doesn't — say this is the *last* gate, say *why* the
    /// account exists, and say what's on the other side.
    ///
    /// Reachable only when no guest session could be created (kill switch on,
    /// or bootstrap failed). Retired with the legacy flow.
    case requiredAfterPaywall

    /// Shown once, immediately after a successful purchase made on a guest
    /// session.
    ///
    /// This is the moment the ask justifies itself: the user just spent money
    /// and has something concrete to lose. It is also the cohort most worth
    /// identifying — refunds, chargebacks, support, device changes.
    ///
    /// **Deliberately skippable.** A wall here sits between a paying customer
    /// and the thing they just paid for, so any OAuth hiccup — no network, a
    /// revoked token, an SDK error — would brick the app for someone who has
    /// already been charged. That is the same reasoning as the offline escape
    /// hatch on PaywallView, with higher stakes. Blocking would buy a few
    /// points of link rate and take on a tail risk carried entirely by payers.
    case afterPurchase

    /// Offered from Profile to a guest who has accumulated something worth
    /// losing — not on arrival.
    ///
    /// A guest's approach log is the only thing in this app that cannot be
    /// regenerated: courses, scenarios and streaks are content or derived
    /// state, but the log is a record of things that happened in the user's
    /// life. That, and only that, is what this prompt protects — which is why
    /// it is threshold-triggered. Shown to a day-one guest with zero logs it
    /// would be nagging about nothing.
    case saveProgress
}
