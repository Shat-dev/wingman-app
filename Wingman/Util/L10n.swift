//
//  L10n.swift
//  Wingman
//
//  Display-text lookup for strings that are also data.
//
//  Most UI strings need nothing from this file: a literal in `Text("…")` or
//  `String(localized: "…")` is looked up by the system, keyed by its English
//  text, and falls back to that English text when no translation exists.
//
//  This file is for the other kind — English strings the app holds as values
//  and passes around: onboarding answers, course titles, quotes, approach
//  level names. Those are also what gets stored and sent to analytics, so the
//  English value has to stay exactly what it is. `L10n.content(_:)` takes that
//  English value and returns what to *show* for it:
//
//      let stored = option.canonicalValue          // data: never changes
//      let shown  = L10n.content(stored)           // copy: may be translated
//
//  Three properties the rest of the localization work relies on:
//
//    1. English in, English out. While the app is running in its source
//       language the input is returned untouched, with no table lookup at
//       all — English users run the same code path they always have.
//    2. A missing translation is the English text. The English string is both
//       the lookup key and the fallback value, so nothing can ever render as
//       a raw key, and an empty translation counts as missing.
//    3. It only ever produces display text. Never store, compare or send what
//       it returns.
//
//  Translations for these strings live in the `Content` table
//  (`Content.xcstrings`), separate from the UI strings in `Localizable`.
//

import Foundation

nonisolated enum L10n {

    /// Where display text is looked up.
    enum Source: @unchecked Sendable {
        /// The app is running in its source language: return the English
        /// input as is.
        case sourceLanguage
        /// Look translations up in this bundle's tables.
        case bundle(Bundle)
    }

    /// The table holding translations of data-like strings.
    static let contentTable = "Content"

    /// Decided once per launch. iOS relaunches the app when its language
    /// changes, so this cannot go stale within a process.
    private static let appSource: Source = {
        let development = Bundle.main.developmentLocalization ?? "en"
        let active = Bundle.main.preferredLocalizations.first ?? development
        return active == development ? .sourceLanguage : .bundle(.main)
    }()

    /// Tests set this to exercise a translated app without shipping a
    /// language. Always nil in the app.
    nonisolated(unsafe) static var sourceOverrideForTesting: Source?

    static var source: Source { sourceOverrideForTesting ?? appSource }

    /// True while the app is showing its source language (English). For the
    /// few places that must keep an English-only behaviour exactly as it was
    /// and do the locale-aware thing only in a translated app.
    static var isSourceLanguage: Bool {
        if case .sourceLanguage = source { return true }
        return false
    }

    /// Debug builds only: launching with `-l10nForceTranslatedLayout YES`
    /// shows the layouts built for translated apps while the text is still
    /// English, so they can be looked at before any translation exists.
    /// Always false in a Release build.
    private static let forcesTranslatedLayout: Bool = {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "l10nForceTranslatedLayout")
        #else
        return false
        #endif
    }()

    /// True when a screen should use its original English layout.
    ///
    /// A few lines are laid out differently for translated apps (one wrapping
    /// sentence in place of a fixed row of pieces). English keeps the layout
    /// it has always had; this says which one to use.
    static var usesSourceLanguageLayout: Bool {
        isSourceLanguage && !forcesTranslatedLayout
    }

    /// A message that ends in developer-facing detail ("Failed to fetch
    /// daily questions: <SDK error text>").
    ///
    /// English users get `english`, exactly as the app has always shown it.
    /// That detail is English whatever the app's language, so a translated
    /// app shows `translated` instead: a complete sentence of its own with no
    /// English tail. Only one of the two is evaluated.
    static func withTechnicalDetail(
        english: @autoclosure () -> String,
        translated: @autoclosure () -> String
    ) -> String {
        isSourceLanguage ? english() : translated()
    }

    /// What to show for an English data string. See the file header.
    static func content(_ english: String) -> String {
        guard !english.isEmpty else { return english }
        switch source {
        case .sourceLanguage:
            return english
        case .bundle(let bundle):
            let translated = bundle.localizedString(forKey: english, value: english, table: contentTable)
            return translated.isEmpty ? english : translated
        }
    }
}
