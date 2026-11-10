//
//  QuotesTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, sixth slice: the Home screen's daily quote.
//  The rotation is tracked by index, so only what is shown goes through
//  `L10n.content`. These tests check that English is unchanged, that every
//  quote has a `Content` catalog entry, and that a translation affects one
//  quote without disturbing the pool.
//

import XCTest
@testable import Wingman

@MainActor
final class QuotesTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    private func useTranslations(_ translations: [String: String]) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotes-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: translations, format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    func testPoolIs120UniqueQuotes() {
        XCTAssertEqual(Quotes.all.count, 120)
        XCTAssertEqual(Set(Quotes.all).count, 120)
        XCTAssertFalse(Quotes.all.contains { $0.isEmpty })
    }

    func testEveryQuoteIsShownAsWrittenInEnglish() {
        for index in Quotes.all.indices {
            XCTAssertEqual(Quotes.display(at: index), Quotes.all[index])
        }
        XCTAssertEqual(Quotes.display(at: 0), "You cannot change what you refuse to confront.")
        XCTAssertEqual(Quotes.display(at: 1), "If you don\u{2019}t risk anything, you risk everything.")
    }

    /// One quote has a literal "%"; it must not be read as a format string.
    func testQuoteWithAPercentSignIsShownLiterally() throws {
        let index = try XCTUnwrap(Quotes.all.firstIndex { $0.contains("%") })
        XCTAssertEqual(Quotes.display(at: index), "You miss 100% of the shots you don\u{2019}t take")
    }

    func testEveryQuoteHasAContentCatalogEntry() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: L10n.contentTable, withExtension: "strings"),
            "Content.xcstrings is not being built into the app"
        )
        let catalog = Set((try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])).keys)
        for quote in Quotes.all {
            XCTAssertTrue(catalog.contains(quote), "No Content.xcstrings entry for the quote: \(quote)")
        }
    }

    /// A translated quote is shown translated; the others stay English; the
    /// pool the rotation indexes into does not change.
    func testTranslationChangesDisplayOnly() throws {
        let english = Quotes.all
        try useTranslations([
            "Energy and persistence conquer all things.": "Energie und Ausdauer überwinden alles.",
            "You miss 100% of the shots you don\u{2019}t take": "Du verfehlst 100% der Schüsse, die du nicht abgibst"
        ])

        let translatedIndex = try XCTUnwrap(english.firstIndex(of: "Energy and persistence conquer all things."))
        XCTAssertEqual(Quotes.display(at: translatedIndex), "Energie und Ausdauer überwinden alles.")

        let percentIndex = try XCTUnwrap(english.firstIndex { $0.contains("%") })
        XCTAssertEqual(Quotes.display(at: percentIndex), "Du verfehlst 100% der Schüsse, die du nicht abgibst")

        XCTAssertEqual(Quotes.display(at: 0), english[0], "An untranslated quote must fall back to English")
        XCTAssertEqual(Quotes.all, english, "The pool itself must never be translated")
    }
}
