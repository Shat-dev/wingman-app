//
//  ScenarioCharacterNameTests.swift
//  WingmanTests
//
//  The name above her speech bubble in a scenario comes from the database
//  (`scenarios.woman_name`) and is shown through `L10n.content`. The Japanese
//  story text writes the names in katakana, so the label has to as well; the
//  other languages spell them as English does and must show them unchanged.
//
//  These read the tables that ship in the app, so a name added to the
//  database without a catalog entry shows up here as a Latin label.
//

import XCTest
@testable import Wingman

@MainActor
final class ScenarioCharacterNameTests: XCTestCase {

    /// The 15 names in production on 2026-11-16, with the spelling the
    /// Japanese scenario text uses for each.
    private let japaneseNames: [String: String] = [
        "Sophie": "ソフィー", "Lauren": "ローレン", "Naomi": "ナオミ",
        "Katie": "ケイティ", "Amber": "アンバー", "Mel": "メル",
        "Sara": "サラ", "Emily": "エミリー", "Claire": "クレア",
        "Zoe": "ゾーイ", "Natalie": "ナタリー", "Lulu": "ルル",
        "Molly": "モリー", "Ellie": "エリー", "Aurelie": "オレリー"
    ]

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        super.tearDown()
    }

    private func useShippedLanguage(_ language: String) throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: language, withExtension: "lproj"),
            "\(language).lproj is not in the app bundle"
        )
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: url)))
    }

    func testEnglishShowsTheNameAsStored() {
        for name in japaneseNames.keys {
            XCTAssertEqual(L10n.content(name), name)
        }
    }

    func testJapaneseShowsTheKatakanaName() throws {
        try useShippedLanguage("ja")
        for (name, katakana) in japaneseNames {
            XCTAssertEqual(L10n.content(name), katakana, name)
        }
    }

    func testGermanSpanishAndFrenchShowTheNameUnchanged() throws {
        for language in ["de", "es", "fr"] {
            try useShippedLanguage(language)
            for name in japaneseNames.keys {
                XCTAssertEqual(L10n.content(name), name, "\(language): \(name)")
            }
        }
    }

    func testANameWithNoEntryIsShownAsStored() throws {
        try useShippedLanguage("ja")
        XCTAssertEqual(L10n.content("Wilhelmina"), "Wilhelmina")
    }
}
