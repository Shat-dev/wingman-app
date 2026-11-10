//
//  AuthCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, eleventh slice: sign-in.
//  Pins the user-facing sign-in messages, and the rule for failures that
//  only have a developer-facing description.
//

import XCTest
@testable import Wingman

@MainActor
final class AuthCopyTests: XCTestCase {

    func testRetryMessage() {
        XCTAssertEqual(AuthCopy.signInFailedRetry, "Sign-in failed. Please try again.")
    }

    /// English users see the technical description, as they always have.
    func testInternalFailureInEnglishShowsTheDescription() {
        XCTAssertEqual(
            AuthCopy.internalFailure(GoogleSignInError.noRootViewController.localizedDescription),
            "Unable to find root view controller"
        )
        XCTAssertEqual(
            AuthCopy.internalFailure(GoogleSignInError.noIdToken.localizedDescription),
            "Unable to get ID token from Google"
        )
    }

    /// A translated app shows the retry message, not an English technical
    /// sentence.
    func testInternalFailureInATranslatedAppShowsTheRetryMessage() {
        XCTAssertEqual(
            AuthCopy.internalFailure("Unable to find root view controller", isSourceLanguage: false),
            "Sign-in failed. Please try again."
        )
    }

    func testAccountLinkConflictMessage() {
        XCTAssertEqual(
            AuthManager.AccountLinkError.identityAlreadyExists.localizedDescription,
            "That account is already linked to another Wingman login. Log in with it instead \u{2014} progress from this session won't carry over."
        )
    }

    /// Developer-facing descriptions stay as they are: they also go to logs.
    func testTechnicalErrorDescriptionsAreUnchanged() {
        XCTAssertEqual(GoogleSignInError.signInFailed("x").errorDescription, "Sign-in failed: x")
        XCTAssertEqual(AppleSignInError.noNonce.errorDescription, "Invalid state: A nonce was not generated")
        XCTAssertEqual(AppleSignInError.noIdentityToken.errorDescription, "Unable to get identity token from Apple")
        XCTAssertEqual(AppleSignInError.invalidIdentityToken.errorDescription, "Unable to serialize identity token")
        XCTAssertEqual(AppleSignInError.noAuthorizationCode.errorDescription, "Unable to get authorization code from Apple")
        XCTAssertEqual(
            AppleSignInError.nonceGenerationFailed(-1).errorDescription,
            "Couldn't generate sign-in security token (OSStatus -1)"
        )
    }
}
