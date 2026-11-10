//
//  ProfileLanguageTests.swift
//  WingmanTests
//
//  WP7 of the localization plan, sixth slice: the app's language on the
//  user's profile.
//
//  The value rides along in the write that already stores country and
//  currency. A separate write may only happen when the language differs
//  from what was stored, and never for an English user whose profile has no
//  value yet, because English must not gain a request.
//

import XCTest
@testable import Wingman

@MainActor
final class ProfileLanguageTests: XCTestCase {

    func testTheFieldIsNotTheProvidersLocaleClaim() {
        XCTAssertEqual(ProfileLanguage.metadataKey, "app_language")
        XCTAssertNotEqual(ProfileLanguage.metadataKey, "locale")
    }

    func testTheAppRunsInEnglishHere() {
        XCTAssertEqual(ProfileLanguage.current, "en")
    }

    func testLanguageTags() {
        XCTAssertEqual(ProfileLanguage.tag("en"), "en")
        XCTAssertEqual(ProfileLanguage.tag("de"), "de")
        XCTAssertEqual(ProfileLanguage.tag("pt-BR"), "pt-br")
        XCTAssertEqual(ProfileLanguage.tag("zh_Hans"), "zh-hans")
        XCTAssertEqual(ProfileLanguage.tag(nil), "en")
        XCTAssertEqual(ProfileLanguage.tag(""), "en")
    }

    // MARK: - When a separate write happens

    /// The case that must never cost a request: every existing English user.
    func testAnEnglishUserWithNothingStoredIsLeftAlone() {
        XCTAssertNil(ProfileLanguage.languageNeedingAWrite(current: "en", lastStored: nil))
    }

    func testNothingIsWrittenWhenTheLanguageIsUnchanged() {
        XCTAssertNil(ProfileLanguage.languageNeedingAWrite(current: "en", lastStored: "en"))
        XCTAssertNil(ProfileLanguage.languageNeedingAWrite(current: "de", lastStored: "de"))
    }

    func testATranslatedAppWithNothingStoredWritesItsLanguage() {
        XCTAssertEqual(ProfileLanguage.languageNeedingAWrite(current: "de", lastStored: nil), "de")
    }

    func testAChangeOfLanguageIsWrittenInBothDirections() {
        XCTAssertEqual(ProfileLanguage.languageNeedingAWrite(current: "de", lastStored: "en"), "de")
        XCTAssertEqual(ProfileLanguage.languageNeedingAWrite(current: "en", lastStored: "de"), "en", "going back to English is recorded")
        XCTAssertEqual(ProfileLanguage.languageNeedingAWrite(current: "sv", lastStored: "de"), "sv")
    }

    func testTheStoredValueIsPerUser() {
        XCTAssertNotEqual(ProfileLanguage.storedKey(userId: "a"), ProfileLanguage.storedKey(userId: "b"))
        XCTAssertTrue(ProfileLanguage.storedKey(userId: "abc").hasSuffix("abc"))
    }
}
