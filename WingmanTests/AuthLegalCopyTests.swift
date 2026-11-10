//
//  AuthLegalCopyTests.swift
//  WingmanTests
//
//  WP6 of the localization plan, first slice: the sign-in legal line.
//
//  English keeps its row of four pieces. A translated app shows one sentence
//  with two links inside it. These tests pin the sentence, the pages its
//  links open, what happens when a translation breaks a link, and that the
//  sentence wraps where the row could not.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class AuthLegalCopyTests: XCTestCase {

    private var temporaryRoot: URL?

    override func tearDown() {
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    /// Puts `L10n` into "translated app" mode with an empty German table.
    private func useATranslatedApp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("legal-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    /// Link text and where it points, in reading order.
    private func links(in text: AttributedString) -> [String] {
        text.runs.compactMap { run in
            run.link.map { "\(String(text[run.range].characters)) -> \($0.absoluteString)" }
        }
    }

    // MARK: - The pages

    /// Requirement 12: the Terms and Privacy links keep opening these pages.
    func testDestinationsAreTheSamePagesAsBefore() {
        XCTAssertEqual(AuthLegalCopy.Destination.terms.url?.absoluteString, "https://www.getwingman.app/terms")
        XCTAssertEqual(AuthLegalCopy.Destination.privacy.url?.absoluteString, "https://www.getwingman.app/privacy")
    }

    func testOnlyTheTwoKnownLinksAreAccepted() throws {
        XCTAssertEqual(AuthLegalCopy.destination(for: try XCTUnwrap(URL(string: "terms"))), .terms)
        XCTAssertEqual(AuthLegalCopy.destination(for: try XCTUnwrap(URL(string: "privacy"))), .privacy)
        XCTAssertNil(AuthLegalCopy.destination(for: try XCTUnwrap(URL(string: "https://example.com"))))
        XCTAssertNil(AuthLegalCopy.destination(for: try XCTUnwrap(URL(string: "Terms"))))
    }

    // MARK: - The sentence

    func testEnglishSentence() {
        XCTAssertEqual(
            AuthLegalCopy.sentenceMarkdown,
            "By continuing you agree to our [Terms](terms) and [Privacy](privacy)"
        )
        XCTAssertEqual(AuthLegalCopy.sentenceMarkdown, AuthLegalCopy.englishSentenceMarkdown)
    }

    /// The sentence reads exactly as the English row does.
    func testSentenceReadsTheSameAsTheEnglishRow() {
        let sentence = AuthLegalCopy.sentence()
        XCTAssertEqual(String(sentence.characters), "By continuing you agree to our Terms and Privacy")
        XCTAssertEqual(links(in: sentence), ["Terms -> terms", "Privacy -> privacy"])
        XCTAssertEqual(AuthLegalCopy.destinations(in: sentence), [.terms, .privacy])
    }

    func testLinksAreUnderlinedAndNothingElseIs() {
        let sentence = AuthLegalCopy.sentence()
        for run in sentence.runs {
            XCTAssertEqual(run.underlineStyle == .single, run.link != nil, String(sentence[run.range].characters))
        }
    }

    /// A translation may reorder the links and move them inside the sentence.
    func testATranslationCanReorderTheLinks() {
        let german = "Mit dem Fortfahren akzeptierst du unsere [Datenschutzerklärung](privacy) und unsere [Nutzungsbedingungen](terms)."
        let sentence = AuthLegalCopy.sentence(markdown: german)
        XCTAssertEqual(
            String(sentence.characters),
            "Mit dem Fortfahren akzeptierst du unsere Datenschutzerklärung und unsere Nutzungsbedingungen."
        )
        XCTAssertEqual(
            links(in: sentence),
            ["Datenschutzerklärung -> privacy", "Nutzungsbedingungen -> terms"]
        )
    }

    // MARK: - Broken translations fall back to English

    private func assertFallsBackToEnglish(_ markdown: String, file: StaticString = #filePath, line: UInt = #line) {
        let sentence = AuthLegalCopy.sentence(markdown: markdown)
        XCTAssertEqual(
            String(sentence.characters), "By continuing you agree to our Terms and Privacy",
            file: file, line: line
        )
        XCTAssertEqual(AuthLegalCopy.destinations(in: sentence), [.terms, .privacy], file: file, line: line)
    }

    func testATranslationThatLostALinkFallsBackToEnglish() {
        assertFallsBackToEnglish("Mit dem Fortfahren akzeptierst du unsere [Nutzungsbedingungen](terms).")
    }

    func testATranslationWithNoLinksFallsBackToEnglish() {
        assertFallsBackToEnglish("Mit dem Fortfahren akzeptierst du unsere Nutzungsbedingungen und Datenschutzerklärung.")
    }

    func testATranslationWithATranslatedLinkTargetFallsBackToEnglish() {
        assertFallsBackToEnglish("Weiter: [Nutzungsbedingungen](bedingungen) und [Datenschutz](privacy)")
    }

    func testATranslationWithAnExtraLinkFallsBackToEnglish() {
        assertFallsBackToEnglish("[AGB](terms), [Datenschutz](privacy) und [mehr](https://example.com)")
    }

    func testATranslationThatLinksTheSamePageTwiceFallsBackToEnglish() {
        assertFallsBackToEnglish("[AGB](terms) und [Datenschutz](terms)")
    }

    func testAnEmptyTranslationFallsBackToEnglish() {
        assertFallsBackToEnglish("")
    }

    // MARK: - Which layout

    func testEnglishUsesTheOriginalRow() {
        XCTAssertTrue(L10n.usesSourceLanguageLayout)
        XCTAssertFalse(AuthLegalFooter(open: { _ in }).usesSentenceLayout)
    }

    func testATranslatedAppUsesTheSentence() throws {
        try useATranslatedApp()
        XCTAssertFalse(L10n.usesSourceLanguageLayout)
        XCTAssertTrue(AuthLegalFooter(open: { _ in }).usesSentenceLayout)
    }

    // MARK: - Rendering

    private func render(usesSentenceLayout: Bool, width: CGFloat, name: String) throws -> CGSize {
        let footer = AuthLegalFooter(usesSentenceLayout: usesSentenceLayout, open: { _ in })
            .frame(width: width)
            .background(Color.white)
        let renderer = ImageRenderer(content: footer)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image.size
    }

    /// Both layouts take one line on an ordinary phone and the same height.
    func testBothLayoutsAreOneLineAtPhoneWidth() throws {
        let row = try render(usesSentenceLayout: false, width: 402, name: "legal-english-row-402")
        let sentence = try render(usesSentenceLayout: true, width: 402, name: "legal-sentence-402")
        XCTAssertEqual(row.width, 402, accuracy: 0.5)
        XCTAssertEqual(sentence.width, 402, accuracy: 0.5)
        XCTAssertEqual(sentence.height, row.height, accuracy: 1.5)
    }

    /// The point of the sentence layout: with less room it grows onto more
    /// lines and stays inside the width it was given.
    func testTheSentenceWrapsWhenThereIsLessRoom() throws {
        let wide = try render(usesSentenceLayout: true, width: 402, name: "legal-sentence-402-again")
        let narrow = try render(usesSentenceLayout: true, width: 200, name: "legal-sentence-200")
        XCTAssertEqual(narrow.width, 200, accuracy: 0.5)
        XCTAssertGreaterThan(narrow.height, wide.height + 10)
    }
}
