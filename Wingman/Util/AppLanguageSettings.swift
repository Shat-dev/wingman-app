//
//  AppLanguageSettings.swift
//  Wingman
//
//  Backs Settings → Language: an in-app choice between the languages this
//  build ships.
//
//  The choice is stored the way iOS's own per-app language menu stores it:
//  `AppleLanguages` in the app's defaults. iOS reads that once, at launch,
//  for the whole process, so the switch happens when Wingman is next opened.
//  The interface, the Info.plist permission prompts and the content all
//  follow it together, which a live in-process switch could not do.
//
//  Why not just link to iOS Settings: iOS shows its per-app language menu
//  only when the phone has more than one language in its list, so a German
//  speaker with an English-only iPhone would find nothing there.
//

import Foundation
import PostHog
import UIKit

nonisolated enum AppLanguageSettings {

    /// The defaults key iOS reads for the app's language at launch.
    static let defaultsKey = "AppleLanguages"

    /// The languages this build ships, English first, as lowercase tags.
    static var availableLanguageCodes: [String] {
        availableLanguageCodes(localizations: Bundle.main.localizations)
    }

    static func availableLanguageCodes(localizations: [String]) -> [String] {
        let codes = Set(localizations.filter { $0 != "Base" }.map { $0.lowercased() })
        return codes.sorted { a, b in
            if a == "en" { return true }
            if b == "en" { return false }
            return a < b
        }
    }

    /// True when the build ships more than one language. An English-only
    /// build hides the row.
    static var offersChoice: Bool {
        availableLanguageCodes.count > 1
    }

    static func offersChoice(localizations: [String]) -> Bool {
        availableLanguageCodes(localizations: localizations).count > 1
    }

    /// The language the app is running in now ("en", "de").
    static var currentLanguageCode: String {
        (Bundle.main.preferredLocalizations.first ?? "en").lowercased()
    }

    /// The running language's name in that language: "English", "Deutsch".
    static var currentLanguageName: String {
        name(of: currentLanguageCode)
    }

    /// The language Wingman will run in from its next launch: the one picked
    /// here (or in iOS Settings) if any, otherwise the one running now.
    static var selectedLanguageCode: String {
        let stored = UserDefaults.standard
            .persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?[defaultsKey] as? [String]
        return selectedLanguageCode(stored: stored, available: availableLanguageCodes, running: currentLanguageCode)
    }

    /// `stored` is the app's own `AppleLanguages` value, not the merged one
    /// (which always includes the phone's languages).
    static func selectedLanguageCode(stored: [String]?, available: [String], running: String) -> String {
        guard let first = stored?.first,
              let match = Bundle.preferredLocalizations(from: available, forPreferences: [first]).first
        else { return running }
        return match.lowercased()
    }

    /// Stores the choice for the next launch. Returns true when Wingman has
    /// to be reopened to show it.
    @discardableResult
    static func select(_ code: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.set([code], forKey: defaultsKey)
        return code != currentLanguageCode
    }

    /// A language's own name for itself, capitalised as that language
    /// writes it at the start of a line. Falls back to the code.
    static func name(of code: String) -> String {
        let locale = Locale(identifier: code)
        guard let name = locale.localizedString(forLanguageCode: code), !name.isEmpty else {
            return code
        }
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    /// A UI string in a given language rather than the running one, so the
    /// "reopen Wingman" note is readable by someone who just switched away
    /// from a language they don't read. English text if there is no
    /// translation.
    static func string(_ english: String, in code: String) -> String {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return english }
        let value = bundle.localizedString(forKey: english, value: english, table: nil)
        return value.isEmpty ? english : value
    }
}

/// After a language change, quits Wingman the next time the user leaves it,
/// so opening it again from the home screen starts it in the new language.
///
/// iOS fixes an app's language when the process starts, so the change needs
/// a fresh launch. Without this, swiping up only backgrounds the app and the
/// next tap brings back the same English process; people would have to know
/// to close it from the app switcher. Quitting only ever happens in the
/// background, never in front of the user, and only after they picked a
/// language other than the running one.
@MainActor
enum LanguageRelaunch {
    private static var observer: NSObjectProtocol?

    static var isArmed: Bool { observer != nil }

    /// Quit on the next trip to the background.
    static func arm() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { quitWhileInBackground() }
        }
    }

    /// The user went back to the running language: nothing to relaunch for.
    static func disarm() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private static func quitWhileInBackground() {
        // Give PostHog a moment to send the queued events (the language
        // choice among them), then quit, unless the user came straight back,
        // in which case wait for the next time they leave.
        var task = UIBackgroundTaskIdentifier.invalid
        task = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(task)
        }
        PostHogSDK.shared.flush()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard UIApplication.shared.applicationState == .background else {
                UIApplication.shared.endBackgroundTask(task)
                return
            }
            log("Quitting in the background to relaunch in the chosen language")
            exit(0)
        }
    }
}
