//
//  OneTimeOfferCopyTests.swift
//  WingmanTests
//
//  WP4 of the localization plan, third slice: the one-time offer's sentences
//  about how long the discount lasts and what the plan renews into.
//
//  They were assembled from a word ("year", "2 years", "month", "6 months")
//  dropped into a sentence. Each case is now a whole sentence in the catalog.
//  These tests prove the English text of every case equals what the old
//  assembly produced, and check what a translated app gets for a billing
//  period the catalog has no sentence for.
//

import XCTest
@testable import Wingman

@MainActor
final class OneTimeOfferCopyTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    private func useATranslatedApp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("offer-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    // MARK: - The old assembly, kept as the reference

    /// `StoreProduct.durationPhrase(months:)` as it was before this slice.
    private func originalPhrase(months: Int) -> String {
        if months % 12 == 0 {
            let years = months / 12
            return years == 1 ? "year" : "\(years) years"
        }
        return months == 1 ? "month" : "\(months) months"
    }

    private func originalDisclosure(intro: String, introMonths: Int, full: String, renewalMonths: Int) -> String {
        "\(intro) billed today for your first \(originalPhrase(months: introMonths)), then \(full)/\(originalPhrase(months: renewalMonths)). Cancel anytime in App Store settings."
    }

    private typealias Duration = OneTimeOfferCopy.Duration

    // MARK: - Durations

    func testMonthsBecomeYearsWhenTheyDivideByTwelve() {
        XCTAssertEqual(Duration(months: 12), .years(1))
        XCTAssertEqual(Duration(months: 24), .years(2))
        XCTAssertEqual(Duration(months: 1), .months(1))
        XCTAssertEqual(Duration(months: 6), .months(6))
        XCTAssertEqual(Duration(months: 18), .months(18))
    }

    // MARK: - Today's offer (first year at a discount, renews yearly)

    func testTheRealConfiguration() {
        XCTAssertEqual(OneTimeOfferCopy.discountLine(first: .years(1)), "off your first year")
        XCTAssertEqual(OneTimeOfferCopy.priceLine(first: .years(1)), "for your first year")
        XCTAssertEqual(
            OneTimeOfferCopy.disclosure(introPrice: "$34.99", first: .years(1), fullPrice: "$69.99", renewal: .years(1)),
            "$34.99 billed today for your first year, then $69.99/year. Cancel anytime in App Store settings."
        )
    }

    // MARK: - Parity with the old assembly

    func testLinesUnderTheBigNumberEqualTheOriginalForEveryLength() {
        for months in 1...48 {
            let duration = Duration(months: months)
            XCTAssertEqual(
                OneTimeOfferCopy.discountLine(first: duration),
                "off your first \(originalPhrase(months: months))", "\(months) months"
            )
            XCTAssertEqual(
                OneTimeOfferCopy.priceLine(first: duration),
                "for your first \(originalPhrase(months: months))", "\(months) months"
            )
        }
    }

    /// Every discount length from 1 to 48 months against every renewal
    /// period from 1 to 36 months: 1,728 sentences, including the periods
    /// that have a sentence of their own and those that do not.
    func testDisclosureEqualsTheOriginalForEveryCombination() {
        var compared = 0
        for introMonths in 1...48 {
            for renewalMonths in 1...36 {
                XCTAssertEqual(
                    OneTimeOfferCopy.disclosure(
                        introPrice: "$34.99", first: Duration(months: introMonths),
                        fullPrice: "$69.99", renewal: Duration(months: renewalMonths)
                    ),
                    originalDisclosure(intro: "$34.99", introMonths: introMonths, full: "$69.99", renewalMonths: renewalMonths),
                    "\(introMonths) months, renewing every \(renewalMonths)"
                )
                compared += 1
            }
        }
        XCTAssertEqual(compared, 48 * 36)
    }

    /// Prices are passed through untouched, whatever their format.
    func testPricesAreInsertedAsGiven() {
        let sentence = OneTimeOfferCopy.disclosure(
            introPrice: "34,99 €", first: .years(1), fullPrice: "69,99 €", renewal: .years(1)
        )
        XCTAssertEqual(sentence, "34,99 € billed today for your first year, then 69,99 €/year. Cancel anytime in App Store settings.")
    }

    // MARK: - A translated app

    /// Yearly and monthly renewals have whole sentences, so a translated app
    /// reads them from the catalog (here: untranslated, so English).
    func testATranslatedAppUsesTheCatalogSentenceForSoldPeriods() throws {
        try useATranslatedApp()
        XCTAssertEqual(
            OneTimeOfferCopy.disclosure(introPrice: "A", first: .months(6), fullPrice: "B", renewal: .years(1)),
            "A billed today for your first 6 months, then B/year. Cancel anytime in App Store settings."
        )
        XCTAssertEqual(
            OneTimeOfferCopy.disclosure(introPrice: "A", first: .months(1), fullPrice: "B", renewal: .months(1)),
            "A billed today for your first month, then B/month. Cancel anytime in App Store settings."
        )
    }

    /// A renewal period with no sentence of its own: a translated app gets a
    /// complete sentence with both prices and no English word dropped in.
    func testATranslatedAppGetsAWholeSentenceForAnUnsoldPeriod() throws {
        try useATranslatedApp()
        let sentence = OneTimeOfferCopy.disclosure(introPrice: "A", first: .years(1), fullPrice: "B", renewal: .months(6))
        XCTAssertEqual(sentence, "A billed today, then B at each renewal. Cancel anytime in App Store settings.")
        XCTAssertFalse(sentence.contains("6 months"))
    }

    /// English keeps the old wording for that same case.
    func testEnglishKeepsTheOldWordingForAnUnsoldPeriod() {
        XCTAssertEqual(
            OneTimeOfferCopy.disclosure(introPrice: "A", first: .years(1), fullPrice: "B", renewal: .months(6)),
            "A billed today for your first year, then B/6 months. Cancel anytime in App Store settings."
        )
    }
}
