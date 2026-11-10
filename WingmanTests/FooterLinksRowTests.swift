//
//  FooterLinksRowTests.swift
//  WingmanTests
//
//  WP6 of the localization plan, second slice: the Privacy · Restore · Terms
//  row under the paywall and the one-time offer.
//
//  The row is rendered off-screen and compared pixel for pixel:
//    - the English row against a copy of the markup the app shipped with;
//    - the adaptive row with English labels against the English row;
//  and measured with German-length labels at phone widths.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class FooterLinksRowTests: XCTestCase {

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
            .appendingPathComponent("footer-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    // MARK: - Fixtures

    private static let english = ["Privacy", "Restore", "Terms"]
    private static let german = ["Datenschutz", "Wiederherstellen", "Nutzungsbedingungen"]

    /// One footer link, styled as both screens style theirs.
    private func link(_ title: String) -> some View {
        Button(action: {}) {
            Text(title)
                .font(.manropeMedium(size: 12))
                .foregroundColor(Color(hex: "6B7280"))
                .underline()
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle())
    }

    /// The row exactly as PaywallView and OneTimeOfferView wrote it before
    /// FooterLinksRow existed.
    private func originalMarkup(_ labels: [String]) -> some View {
        HStack(spacing: 0) {
            link(labels[0])
            Spacer()
            link(labels[1])
            Spacer()
            link(labels[2])
        }
        .padding(.horizontal, 60)
    }

    private func row(_ labels: [String], adapts: Bool) -> some View {
        FooterLinksRow(adaptsToLongLabels: adapts) {
            self.link(labels[0])
        } center: {
            self.link(labels[1])
        } trailing: {
            self.link(labels[2])
        }
    }

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

    // MARK: - English is unchanged

    func testEnglishRowIsPixelIdenticalToTheOriginalMarkup() throws {
        for width in [375.0, 402.0, 440.0] {
            let before = try render(originalMarkup(Self.english), width: width, name: "footer-original-\(Int(width))")
            let after = try render(row(Self.english, adapts: false), width: width, name: "footer-english-\(Int(width))")
            XCTAssertEqual(after.size, before.size, "width \(width)")
            XCTAssertEqual(try pixels(after), try pixels(before), "width \(width)")
        }
    }

    /// With labels as short as the English ones, a translated app gets the
    /// same picture.
    func testAdaptiveRowWithShortLabelsLooksLikeTheEnglishRow() throws {
        for width in [375.0, 402.0] {
            let english = try render(row(Self.english, adapts: false), width: width, name: "footer-english-again-\(Int(width))")
            let adaptive = try render(row(Self.english, adapts: true), width: width, name: "footer-adaptive-english-\(Int(width))")
            XCTAssertEqual(adaptive.size, english.size, "width \(width)")
            XCTAssertEqual(try pixels(adaptive), try pixels(english), "width \(width)")
        }
    }

    // MARK: - Long labels

    /// German fits on one row on every current phone, the SE included.
    func testGermanLabelsStayOnOneRow() throws {
        for width in [375.0, 402.0, 440.0] {
            let image = try render(row(Self.german, adapts: true), width: width, name: "footer-adaptive-german-\(Int(width))")
            XCTAssertEqual(image.size.width, width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, 44, accuracy: 0.5, "width \(width)")
        }
    }

    /// The reason for the adaptive row: the original markup has too little
    /// room for German on an SE. It is 255pt wide inside its padding; the
    /// three German labels alone need more than that.
    func testTheOriginalRowIsTooNarrowForGermanOnAnSE() throws {
        let labelsOnly = HStack(spacing: 0) {
            link(Self.german[0])
            link(Self.german[1])
            link(Self.german[2])
        }
        .fixedSize()
        let renderer = ImageRenderer(content: labelsOnly)
        let natural = try XCTUnwrap(renderer.uiImage).size.width
        XCTAssertGreaterThan(natural, 375 - 2 * FooterLinksRow<EmptyView, EmptyView, EmptyView>.widePadding)
        XCTAssertLessThan(
            natural + 2 * FooterLinksRow<EmptyView, EmptyView, EmptyView>.minimumGap,
            375 - 2 * FooterLinksRow<EmptyView, EmptyView, EmptyView>.narrowPadding
        )
        _ = try render(originalMarkup(Self.german), width: 375, name: "footer-original-german-375")
    }

    /// When even the narrow padding is not enough, the links stack.
    func testLabelsThatCannotShareARowStack() throws {
        let long = ["Datenschutzerklärung", "Käufe wiederherstellen", "Allgemeine Nutzungsbedingungen"]
        let image = try render(row(long, adapts: true), width: 375, name: "footer-adaptive-stacked-375")
        XCTAssertEqual(image.size.width, 375, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 132, accuracy: 0.5)
    }

    // MARK: - Which layout

    func testEnglishGetsTheOriginalRow() {
        XCTAssertFalse(row(Self.english, adapts: false).adaptsToLongLabelsDefault)
    }

    func testATranslatedAppGetsTheAdaptiveRow() throws {
        try useATranslatedApp()
        XCTAssertTrue(row(Self.english, adapts: false).adaptsToLongLabelsDefault)
    }
}

private extension View {
    /// What `FooterLinksRow` decides when the caller does not say.
    @MainActor var adaptsToLongLabelsDefault: Bool {
        FooterLinksRow(leading: { EmptyView() }, center: { EmptyView() }, trailing: { EmptyView() }).adaptsToLongLabels
    }
}
