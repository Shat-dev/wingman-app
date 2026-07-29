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
    case requiredAfterPaywall
}
