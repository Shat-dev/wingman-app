//
//  ProfileLanguage.swift
//  Wingman
//
//  The app's language, recorded on the user's profile as `app_language`
//  beside the `country` and `currency` already kept there.
//
//  The plan called the field `locale`. It is `app_language` because sign-in
//  providers put their own claims into the same metadata, and `locale` is a
//  standard one (Google's is the account's language, not the app's); a
//  provider sign-in could overwrite ours. `app_language` is also the name
//  analytics already uses for the same value.
//
//  It exists so that things sent from the server on the user's behalf (the
//  sign-in emails, first of all) can be in the language the user actually
//  runs the app in.
//
//  It must not cost English users anything: the plan's test for this work
//  is that an English device makes exactly the requests it made before.
//
//    - A new profile gets `app_language` in the SAME write that stores
//      country and currency. No extra request.
//    - After that, a separate write happens only when the language differs
//      from what was last stored. An English user whose profile has no
//      `app_language` yet is left alone: a missing value means English.
//

import Foundation

nonisolated enum ProfileLanguage {

    /// The `user_metadata` field.
    static let metadataKey = "app_language"

    /// The language the interface is running in, as a lowercase tag:
    /// "en", "de", "pt-br". The same language analytics reports as
    /// `app_language`.
    static var current: String {
        tag(Bundle.main.preferredLocalizations.first)
    }

    static func tag(_ localization: String?) -> String {
        guard let localization, !localization.isEmpty else { return "en" }
        return localization.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    /// The language to store in a later, separate write; nil for "nothing
    /// to do".
    ///
    /// - `lastStored` is what this install last wrote for this user, nil if
    ///   it never wrote one.
    static func languageNeedingAWrite(current: String, lastStored: String?) -> String? {
        if let lastStored {
            return lastStored == current ? nil : current
        }
        // Never stored. English is the meaning of "no value", so only a
        // translated app has something to say.
        return current == "en" ? nil : current
    }

    static func storedKey(userId: String) -> String {
        "capturedProfileLanguage_\(userId)"
    }
}
