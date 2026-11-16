//
//  AppLanguageSettingsTests.swift
//  WingmanTests
//
//  Settings → Language: which languages are offered, how they are named,
//  what counts as the chosen one, and the "reopen" note in the new language.
//

import XCTest
@testable import Wingman

final class AppLanguageSettingsTests: XCTestCase {

    func testHiddenInAnEnglishOnlyBuild() {
        XCTAssertFalse(AppLanguageSettings.offersChoice(localizations: ["en", "Base"]))
        XCTAssertFalse(AppLanguageSettings.offersChoice(localizations: ["en"]))
    }

    func testShownOnceASecondLanguageShips() {
        XCTAssertTrue(AppLanguageSettings.offersChoice(localizations: ["en", "Base", "de"]))
    }

    func testEnglishIsListedFirst() {
        XCTAssertEqual(AppLanguageSettings.availableLanguageCodes(localizations: ["de", "Base", "en", "fr"]), ["en", "de", "fr"])
    }

    func testThisBuildOffersEnglishGermanSpanishFrenchAndJapanese() {
        XCTAssertEqual(AppLanguageSettings.availableLanguageCodes, ["en", "de", "es", "fr", "ja"])
    }

    /// Release D: the Settings menu lists Japanese last, as 日本語.
    func testTheMenuListsJapaneseByItsOwnName() {
        let codes = AppLanguageSettings.availableLanguageCodes(localizations: ["Base", "ja", "en", "de", "es", "fr"])
        XCTAssertEqual(codes, ["en", "de", "es", "fr", "ja"])
        XCTAssertEqual(codes.map(AppLanguageSettings.name(of:)), ["English", "Deutsch", "Español", "Français", "日本語"])
    }

    /// One Japanese: iOS stores "ja" or "ja-JP" (and "ja-US" on a phone set
    /// to another region); each lands on `ja`.
    func testRegionalJapaneseChoicesMapToTheOneShippedLanguage() {
        let available = ["en", "de", "es", "fr", "ja"]
        for stored in ["ja", "ja-JP", "ja-US"] {
            XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: [stored], available: available, running: "en"), "ja", stored)
        }
        // Adding Japanese moves no one else.
        XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: ["fr-CA"], available: available, running: "en"), "fr")
        XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: ["zh-Hans"], available: available, running: "en"), "en")
    }

    /// The Settings menu lists every shipped language under its own name.
    func testTheMenuListsSpanishAndFrenchByTheirOwnNames() {
        let codes = AppLanguageSettings.availableLanguageCodes(localizations: ["Base", "en", "de", "es", "fr"])
        XCTAssertEqual(codes, ["en", "de", "es", "fr"])
        XCTAssertEqual(codes.map(AppLanguageSettings.name(of:)), ["English", "Deutsch", "Español", "Français"])
    }

    func testLanguagesAreNamedInTheirOwnLanguage() {
        XCTAssertEqual(AppLanguageSettings.name(of: "en"), "English")
        XCTAssertEqual(AppLanguageSettings.name(of: "de"), "Deutsch")
        XCTAssertEqual(AppLanguageSettings.name(of: "es"), "Español")
        XCTAssertEqual(AppLanguageSettings.name(of: "fr"), "Français")
        XCTAssertEqual(AppLanguageSettings.name(of: "ja"), "日本語")
    }

    /// One Spanish and one French: every regional variant iOS stores lands on
    /// `es` or `fr` (Release C ships no es-419, es-MX or fr-CA).
    func testRegionalSpanishAndFrenchChoicesMapToTheOneShippedLanguage() {
        let available = ["en", "de", "es", "fr"]
        for stored in ["es", "es-MX", "es-ES", "es-419", "es-US", "es-CO", "es-AR"] {
            XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: [stored], available: available, running: "en"), "es", stored)
        }
        for stored in ["fr", "fr-FR", "fr-CA", "fr-BE", "fr-CH"] {
            XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: [stored], available: available, running: "en"), "fr", stored)
        }
    }

    func testChosenLanguageFollowsTheStoredChoice() {
        let available = ["en", "de"]
        XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: ["de"], available: available, running: "en"), "de")
        // iOS Settings stores region-qualified tags.
        XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: ["de-AT"], available: available, running: "en"), "de")
        XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: ["en-GB"], available: available, running: "de"), "en")
    }

    func testNoStoredChoiceMeansTheRunningLanguage() {
        XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: nil, available: ["en", "de"], running: "de"), "de")
        XCTAssertEqual(AppLanguageSettings.selectedLanguageCode(stored: [], available: ["en", "de"], running: "en"), "en")
    }

    func testReopenNoteIsReadInTheChosenLanguage() {
        XCTAssertEqual(AppLanguageSettings.string("Reopen Wingman to switch", in: "de"), "Öffne Wingman neu, um zu wechseln")
        XCTAssertEqual(AppLanguageSettings.string("Reopen Wingman to switch", in: "ja"), "切り替えるにはWingmanを開き直してください")
        XCTAssertEqual(AppLanguageSettings.string("Reopen Wingman to switch", in: "en"), "Reopen Wingman to switch")
        XCTAssertEqual(AppLanguageSettings.string("Reopen Wingman to switch", in: "xx"), "Reopen Wingman to switch")
    }

    func testReopenInstructionIsReadInTheChosenLanguage() {
        let english = "Go to your home screen, then open Wingman again."
        XCTAssertEqual(AppLanguageSettings.string(english, in: "de"), "Wechsle zum Home-Bildschirm und öffne Wingman dann erneut.")
        XCTAssertEqual(AppLanguageSettings.string(english, in: "en"), english)
    }

    @MainActor
    func testRelaunchIsArmedOnlyUntilTheUserGoesBack() {
        defer { LanguageRelaunch.disarm() }
        XCTAssertFalse(LanguageRelaunch.isArmed)
        LanguageRelaunch.arm()
        LanguageRelaunch.arm()
        XCTAssertTrue(LanguageRelaunch.isArmed)
        LanguageRelaunch.disarm()
        XCTAssertFalse(LanguageRelaunch.isArmed)
    }
}
