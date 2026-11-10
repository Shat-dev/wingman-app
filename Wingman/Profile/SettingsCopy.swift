//
//  SettingsCopy.swift
//  Wingman
//
//  Messages the Settings screen shows in its success and error alerts. They
//  were inline string literals assigned from inside async handlers, which the
//  compiler does not treat as localizable and which could not be tested.
//

import Foundation

enum SettingsCopy {

    // MARK: - Restore purchases

    static var restoreSucceeded: String { String(localized: "Purchases restored successfully!") }
    static var nothingToRestore: String { String(localized: "No active subscriptions found to restore") }
    static var restoreFailed: String { String(localized: "Failed to restore purchases. Please try again.") }

    // MARK: - Delete account

    static var deletionNetworkError: String {
        String(localized: "Network error: Please check your connection and try again.")
    }

    static var deletionServerError: String {
        String(localized: "Server error: Please try again later.")
    }

    static var deletionUnexpectedError: String {
        String(localized: "An unexpected error occurred. Please try again.")
    }

    /// The deletion request reached the server and was refused.
    ///
    /// `serverMessage` is whatever the Edge Function sent back, which is
    /// English text written for developers ("Invalid or expired token",
    /// "HTTP 500"). In English the alert shows it, exactly as it always has.
    /// In a translated app it would put an English sentence inside a
    /// translated alert, so there the user gets a complete sentence of the
    /// app's own instead; the server text still goes to the log.
    static func deletionFailed(serverMessage: String, isSourceLanguage: Bool = L10n.isSourceLanguage) -> String {
        if isSourceLanguage {
            return "Deletion failed: \(serverMessage)"
        }
        return String(localized: "Deletion failed. Please try again later.")
    }
}
