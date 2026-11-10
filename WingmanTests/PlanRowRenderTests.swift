//
//  PlanRowRenderTests.swift
//  WingmanTests
//
//  WP4 of the localization plan, fifth slice: the paywall's plan rows.
//
//  A Debug build loads no products, so the plan rows never appear in the
//  onboarding sweep. These tests draw the row directly, with the texts a
//  real product would give it.
//
//  The plan asked for the row to be hardened so that a long plan name can
//  never cut the price. Drawing it showed that it already behaves that way:
//  the left side wraps and the price keeps its full width. So `PlanRow` was
//  left alone, and these tests are the guard that keeps it so.
//
//  English renders are attached under stable names ("english-planrow-…") so
//  a run before a future layout change can be compared with a run after it.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class PlanRowRenderTests: XCTestCase {

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
            .appendingPathComponent("planrow-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    private func render(_ view: some View, width: CGFloat, name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: width).padding(4).background(Color.white))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    /// The paywall's content width on an iPhone SE and an iPhone 17 Pro
    /// (screen width minus the 20pt section inset on each side).
    private static let widths: [CGFloat] = [335, 362]

    private func row(
        title: String, price: String, weekly: String, subtitle: String,
        isSelected: Bool, badge: String?
    ) -> PlanRow {
        PlanRow(
            title: title, price: price, weekly: weekly, weeklySubtitle: subtitle,
            isSelected: isSelected, badgeText: badge, onSelect: {}
        )
    }

    // MARK: - English renders (compare across runs)

    func testEnglishPlanRowsRender() throws {
        for width in Self.widths {
            let tag = "\(Int(width))"
            _ = try render(
                row(title: "Yearly Plan", price: "only $1.35 per week", weekly: "$69.99", subtitle: "per year", isSelected: true, badge: "3-day Free Trial"),
                width: width, name: "english-planrow-yearly-selected-trial-\(tag)"
            )
            _ = try render(
                row(title: "Yearly Plan", price: "only $1.35 per week", weekly: "$69.99", subtitle: "per year", isSelected: true, badge: nil),
                width: width, name: "english-planrow-yearly-selected-\(tag)"
            )
            _ = try render(
                row(title: "Monthly Plan", price: "only $3.00 per week", weekly: "$12.99", subtitle: "per month", isSelected: false, badge: nil),
                width: width, name: "english-planrow-monthly-\(tag)"
            )
        }
    }

    // MARK: - Long text

    /// Width of the price column when nothing competes with it.
    private func naturalPriceWidth(_ price: String) throws -> CGFloat {
        let renderer = ImageRenderer(content: Text(price).font(.manropeSemiBold(size: 16)).fixedSize())
        return try XCTUnwrap(renderer.uiImage).size.width
    }

    /// A very long plan name and weekly line wrap on the left; the price on
    /// the right is drawn in full, as it is next to a short name.
    func testALongPlanNameNeverCutsThePrice() throws {
        try useATranslatedApp()
        let width: CGFloat = 335
        let price = "1.299,99 kr"

        let short = try render(
            row(title: "Jahr", price: "nur 25 kr", weekly: price, subtitle: "pro Jahr", isSelected: true, badge: nil),
            width: width, name: "translated-planrow-short"
        )
        let long = try render(
            row(
                title: "Jahresabonnement mit vollem Zugriff auf alle Inhalte",
                price: "nur 25,00 kr pro Woche bei jährlicher Abrechnung im Voraus",
                weekly: price, subtitle: "pro Jahr", isSelected: true, badge: nil
            ),
            width: width, name: "translated-planrow-long"
        )

        // The long row is taller: its left side wrapped.
        XCTAssertGreaterThan(long.size.height, short.size.height)
        let needed = try naturalPriceWidth(price)
        XCTAssertGreaterThan(needed, 70)

        // The right-hand strip (price, period, radio button) holds as much
        // ink in the long row as in the short one: no part of the price was
        // replaced by an ellipsis.
        let shortInk = try inkCount(in: short, rightStrip: needed + 60)
        let longInk = try inkCount(in: long, rightStrip: needed + 60)
        XCTAssertGreaterThanOrEqual(longInk, shortInk * 95 / 100)
    }

    private func inkCount(in image: UIImage, rightStrip: CGFloat) throws -> Int {
        let cgImage = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cgImage.width) / image.size.width
        let width = Int(rightStrip * scale), height = cgImage.height
        let strip = CGRect(x: cgImage.width - width, y: 0, width: width, height: height)
        let cropped = try XCTUnwrap(cgImage.cropping(to: strip))
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        var ink = 0
        for pixel in stride(from: 0, to: bytes.count, by: 4) where bytes[pixel] < 200 {
            ink += 1
        }
        return ink
    }
}
