//
//  StringCatalogTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, second slice: the two String Catalogs.
//
//    - `Localizable.xcstrings` holds UI strings, extracted by the compiler.
//    - `Content.xcstrings` holds data-like strings looked up through
//      `L10n.content`, maintained by hand (the compiler cannot see them).
//
//  These tests guard Release A's rules: the app still ships English only,
//  English text is unchanged by the catalogs existing, and every string that
//  is routed through `L10n.content` has a catalog entry for a translator to
//  fill in.
//

import XCTest
@testable import Wingman

@MainActor
final class StringCatalogTests: XCTestCase {

    // MARK: - Release A ships English only

    func testAppBundleDeclaresOnlyEnglish() {
        let localizations = Set(Bundle.main.localizations).subtracting(["Base"])
        XCTAssertEqual(localizations, ["en"], "A language was added. Release A must stay English-only.")
        XCTAssertEqual(Bundle.main.developmentLocalization, "en")
        XCTAssertEqual(Bundle.main.preferredLocalizations.first, "en")
    }

    // MARK: - English is unchanged by the catalog

    func testLocalizedLookupsReturnTheEnglishText() {
        XCTAssertEqual(String(localized: "Get started"), "Get started")
        XCTAssertEqual(String(localized: "Tap to continue"), "Tap to continue")
        XCTAssertEqual(String(localized: "Select all that apply"), "Select all that apply")
        // A string the catalog has never seen falls back to itself, not to a
        // key or a blank.
        XCTAssertEqual(
            Bundle.main.localizedString(forKey: "A sentence no catalog contains.", value: nil, table: nil),
            "A sentence no catalog contains."
        )
    }

    func testFormattedStringsKeepTheirEnglishShape() {
        XCTAssertEqual(String(localized: "\(3) day streak"), "3 day streak")
        XCTAssertEqual(String(localized: "Level \(4)"), "Level 4")
        XCTAssertEqual(String(localized: "Confidence: \(7)/10"), "Confidence: 7/10")
    }

    // MARK: - Content catalog covers what the code looks up

    /// The compiled English `Content` table. For the source language each
    /// entry maps to itself, so its keys are the catalog's entries.
    private func contentCatalogKeys() throws -> Set<String> {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: L10n.contentTable, withExtension: "strings"),
            "Content.xcstrings is not being built into the app"
        )
        let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return Set(table.keys)
    }

    func testEveryOnboardingLabelHasAContentCatalogEntry() throws {
        let catalog = try contentCatalogKeys()
        let labels: [String] =
            MotivationOption.allCases.map(\.englishLabel)
            + AgeOption.allCases.map(\.englishLabel)
            + LastApproachOption.allCases.map(\.englishLabel)
            + ApproachFrequencyOption.allCases.map(\.englishLabel)
            + BarrierOption.allCases.map(\.englishLabel)
            + GoalOption.allCases.map(\.englishLabel)

        for label in labels {
            XCTAssertTrue(catalog.contains(label), "\"\(label)\" is shown through L10n.content but has no Content.xcstrings entry")
        }
    }

    func testContentCatalogSourceEntriesMapToThemselves() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: L10n.contentTable, withExtension: "strings"))
        let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        for (key, value) in table {
            XCTAssertEqual(value, key, "The English Content entry for \"\(key)\" rewrites the text")
        }
    }

    /// The stored (misspelled) barrier value is data and must never be a
    /// catalog key: translators see the corrected label only.
    func testStoredOnlyValuesAreNotInTheContentCatalog() throws {
        let catalog = try contentCatalogKeys()
        XCTAssertFalse(catalog.contains(BarrierOption.fearOfRejection.canonicalValue))
        XCTAssertTrue(catalog.contains(BarrierOption.fearOfRejection.englishLabel))
    }
}
