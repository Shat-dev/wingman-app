//
//  SettingsCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, ninth slice: the Settings alerts.
//  Pins the English wording, and the one message that carries server text:
//  shown as before in English, replaced by the app's own sentence once the
//  app is translated.
//

import XCTest
@testable import Wingman

@MainActor
final class SettingsCopyTests: XCTestCase {

    func testRestoreMessages() {
        XCTAssertEqual(SettingsCopy.restoreSucceeded, "Purchases restored successfully!")
        XCTAssertEqual(SettingsCopy.nothingToRestore, "No active subscriptions found to restore")
        XCTAssertEqual(SettingsCopy.restoreFailed, "Failed to restore purchases. Please try again.")
    }

    func testDeletionErrorMessages() {
        XCTAssertEqual(SettingsCopy.deletionNetworkError, "Network error: Please check your connection and try again.")
        XCTAssertEqual(SettingsCopy.deletionServerError, "Server error: Please try again later.")
        XCTAssertEqual(SettingsCopy.deletionUnexpectedError, "An unexpected error occurred. Please try again.")
    }

    /// English users see the server's text after the prefix, as they always
    /// have.
    func testDeletionFailedInEnglishShowsTheServerMessage() {
        XCTAssertEqual(
            SettingsCopy.deletionFailed(serverMessage: "Invalid or expired token"),
            "Deletion failed: Invalid or expired token"
        )
        XCTAssertEqual(SettingsCopy.deletionFailed(serverMessage: "HTTP 500"), "Deletion failed: HTTP 500")
        // Server text with format characters must come through literally.
        XCTAssertEqual(SettingsCopy.deletionFailed(serverMessage: "100% %@"), "Deletion failed: 100% %@")
    }

    /// A translated app never shows the server's English sentence.
    func testDeletionFailedInATranslatedAppUsesTheAppsOwnSentence() {
        let message = SettingsCopy.deletionFailed(serverMessage: "Invalid or expired token", isSourceLanguage: false)
        XCTAssertFalse(message.contains("Invalid or expired token"))
        // English here only because no translation exists yet; the point is
        // that it is a complete sentence the catalog owns.
        XCTAssertEqual(message, "Deletion failed. Please try again later.")
    }

    /// `AccountDeletionError` descriptions go to logs and error tracking, not
    /// to the user, so they stay plain English.
    func testAccountDeletionErrorDescriptionsStayEnglish() {
        XCTAssertEqual(AccountDeletionError.notAuthenticated.errorDescription, "User not authenticated")
        XCTAssertEqual(AccountDeletionError.invalidSession.errorDescription, "Invalid session")
        XCTAssertEqual(AccountDeletionError.networkError("offline").errorDescription, "Network error: offline")
        XCTAssertEqual(AccountDeletionError.deletionFailed("HTTP 500").errorDescription, "Account deletion failed: HTTP 500")
        XCTAssertEqual(AccountDeletionError.invalidResponse.errorDescription, "Invalid response from server")
    }
}
