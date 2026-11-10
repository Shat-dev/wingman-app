//
//  LabelHeightTests.swift
//  WingmanTests
//
//  WP6 of the localization plan, fourth slice: fixed-height buttons.
//
//  22 button labels had a fixed height (40 to 56pt). `labelHeight(_:)` keeps
//  it for English and makes it a minimum for a translated app. These tests
//  compare the English result pixel for pixel with the original markup, and
//  show that a long translated label makes the button taller instead of
//  being clipped.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class LabelHeightTests: XCTestCase {

    private func render(_ view: some View, width: CGFloat, name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: width).background(Color.white))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func pixels(_ image: UIImage) throws -> Data {
        try XCTUnwrap(image.cgImage?.dataProvider?.data as Data?)
    }

    /// The primary button label as the app writes it everywhere, with the
    /// original fixed height.
    private func originalLabel(_ title: String, height: CGFloat, fontSize: CGFloat = 16) -> some View {
        Text(title)
            .font(.manropeSemiBold(size: fontSize))
            .foregroundColor(.wingmanWhiteFF)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.wingmanBlack)
            .cornerRadius(5)
    }

    private func label(_ title: String, height: CGFloat, fontSize: CGFloat = 16, english: Bool) -> some View {
        Text(title)
            .font(.manropeSemiBold(size: fontSize))
            .foregroundColor(.wingmanWhiteFF)
            .frame(maxWidth: .infinity)
            .labelHeight(height, usesSourceLanguageLayout: english)
            .background(Color.wingmanBlack)
            .cornerRadius(5)
    }

    // MARK: - English is unchanged

    /// Every height the app uses, at SE and 17 Pro content widths.
    func testEnglishLabelIsPixelIdenticalToTheOriginalMarkup() throws {
        let cases: [(String, CGFloat, CGFloat)] = [
            ("Create a free account", 40, 14),
            ("Not now", 44, 16),
            ("Open", 50, 16),
            ("Get started", 52, 16),
            ("Check Answer", 52, 16),
            ("Start Practice", 56, 16)
        ]
        for (title, height, fontSize) in cases {
            for width in [335.0, 362.0] {
                let before = try render(
                    originalLabel(title, height: height, fontSize: fontSize),
                    width: width, name: "label-original-\(Int(height))-\(Int(width))"
                )
                let after = try render(
                    label(title, height: height, fontSize: fontSize, english: true),
                    width: width, name: "label-english-\(Int(height))-\(Int(width))"
                )
                XCTAssertEqual(after.size, before.size, "\(title) at \(width)")
                XCTAssertEqual(try pixels(after), try pixels(before), "\(title) at \(width)")
            }
        }
    }

    /// The default is the English layout while the app runs in English.
    func testTheDefaultIsTheEnglishLayout() throws {
        let explicit = try render(label("Get started", height: 52, english: true), width: 362, name: "label-explicit")
        let byDefault = try render(
            Text("Get started")
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.wingmanWhiteFF)
                .frame(maxWidth: .infinity)
                .labelHeight(52)
                .background(Color.wingmanBlack)
                .cornerRadius(5),
            width: 362, name: "label-default"
        )
        XCTAssertEqual(try pixels(byDefault), try pixels(explicit))
    }

    // MARK: - Translated apps

    /// Share of bytes that differ between two pictures of the same size.
    private func differingShare(_ a: UIImage, _ b: UIImage) throws -> Double {
        let first = try pixels(a), second = try pixels(b)
        guard first.count == second.count, !first.isEmpty else { return 1 }
        var differing = 0
        for index in first.indices where first[index] != second[index] {
            differing += 1
        }
        return Double(differing) / Double(first.count)
    }

    /// A label that fits on one line gives the same button as in English:
    /// same size, same place.
    ///
    /// Not required to be pixel-identical. Centring a label so that it wraps
    /// well makes the system space a few letter pairs a fraction of a point
    /// differently ("t'" in "Los geht's"), which no one can see but a byte
    /// comparison can. English never takes this path.
    func testAShortTranslatedLabelLooksLikeTheEnglishButton() throws {
        for (title, height) in [("Los geht's", 52.0), ("Speichern", 52.0), ("Nicht jetzt", 44.0)] {
            let english = try render(label(title, height: height, english: true), width: 335, name: "label-short-english-\(title)")
            let translated = try render(label(title, height: height, english: false), width: 335, name: "label-short-translated-\(title)")
            XCTAssertEqual(translated.size, english.size, title)
            XCTAssertLessThan(try differingShare(translated, english), 0.01, title)
        }
    }

    /// A label too long for one line grows the button. With the fixed height
    /// the same label has to fit in 52pt whatever its length.
    func testALongTranslatedLabelMakesTheButtonTaller() throws {
        let long = "Jetzt kostenlos testen und anschließend zum reduzierten Jahrespreis weitermachen, jederzeit kündbar"
        let fixed = try render(label(long, height: 52, english: true), width: 280, name: "label-long-fixed-height")
        let grown = try render(label(long, height: 52, english: false), width: 280, name: "label-long-grown")
        XCTAssertEqual(fixed.size.height, 52, accuracy: 0.5)
        XCTAssertEqual(grown.size.width, 280, accuracy: 0.5)
        // Three lines of 16pt text and the padding do not fit in 52pt.
        XCTAssertGreaterThan(grown.size.height, 52 + 10)
        // The grown button is not just the fixed one stretched: the text
        // that was cut is drawn.
        XCTAssertGreaterThan(grown.size.height, fixed.size.height + 20)
    }

    /// A two-line label still gets padding above and below.
    func testATwoLineTranslatedLabelKeepsItsPadding() throws {
        let twoLines = "Kostenloses Konto erstellen und Fortschritt sichern"
        let oneLine = try render(
            Text("Kostenloses Konto").font(.manropeSemiBold(size: 16)).fixedSize(),
            width: 280, name: "label-line-height"
        )
        let grown = try render(label(twoLines, height: 52, english: false), width: 280, name: "label-two-lines")
        XCTAssertGreaterThanOrEqual(
            grown.size.height,
            min(2 * oneLine.size.height * TranslatedLabel.minimumScaleFactor, 52) + 0
        )
        XCTAssertGreaterThanOrEqual(grown.size.height, 52)
    }
}
