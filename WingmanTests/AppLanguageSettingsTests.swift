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

    func testThisBuildOffersEnglishAndGerman() {
        XCTAssertEqual(AppLanguageSettings.availableLanguageCodes, ["en", "de"])
    }

    func testLanguagesAreNamedInTheirOwnLanguage() {
        XCTAssertEqual(AppLanguageSettings.name(of: "en"), "English")
        XCTAssertEqual(AppLanguageSettings.name(of: "de"), "Deutsch")
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
        XCTAssertEqual(AppLanguageSettings.string("Reopen Wingman to switch", in: "en"), "Reopen Wingman to switch")
        XCTAssertEqual(AppLanguageSettings.string("Reopen Wingman to switch", in: "xx"), "Reopen Wingman to switch")
    }
}
