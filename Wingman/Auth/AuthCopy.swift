//
//  AuthCopy.swift
//  Wingman
//
//  Sign-in messages that need more than a plain localized string.
//

import Foundation

enum AuthCopy {

    /// The catch-all the sign-in screens already use.
    static var signInFailedRetry: String {
        String(localized: "Sign-in failed. Please try again.")
    }

    /// What to show for a sign-in failure whose only description is a
    /// sentence written for developers (`GoogleSignInError`,
    /// `AppleSignInError`: "Unable to find root view controller").
    ///
    /// In English the screen shows that sentence, as it always has. Those
    /// descriptions are not translated — they are diagnostics, and also what
    /// the log records — so a translated app shows the ordinary retry message
    /// instead of an English technical sentence.
    static func internalFailure(_ technicalDescription: String, isSourceLanguage: Bool = L10n.isSourceLanguage) -> String {
        isSourceLanguage ? technicalDescription : signInFailedRetry
    }
}
