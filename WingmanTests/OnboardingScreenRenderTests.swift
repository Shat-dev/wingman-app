//
//  OnboardingScreenRenderTests.swift
//  WingmanTests
//
//  Draws whole onboarding screens in a test window at real phone sizes.
//
//  Two uses:
//
//  1. Before/after proof for English. Every English render is attached under
//     a stable name ("english-<screen>-<width>x<height>"). Export the
//     attachments from a run before a layout change and from a run after it,
//     and the pictures must be identical. This is how a layout change to
//     these screens is checked without the onboarding sweep, which creates a
//     user in production every time it runs.
//
//  2. Long text. The statistic and growth screens did not fit an iPhone SE
//     when every string was doubled (the pseudo-language run of 2026-11-10):
//     the top of the screen was pushed off and the bottom was cut. In a
//     translated app these screens now scroll when their content is too
//     tall. The tests draw them with doubled text and check that the content
//     starts at the top and stays inside the screen.
//
//  Only screens that send no analytics when shown are drawn here.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class OnboardingScreenRenderTests: XCTestCase {

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
            .appendingPathComponent("screen-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    // MARK: - Drawing

    /// The area a screen gets below the onboarding top bar, on an iPhone SE
    /// and on an iPhone 17 Pro.
    private static let sizes = [CGSize(width: 375, height: 580), CGSize(width: 402, height: 740)]
    private static let small = sizes[0]

    private func draw(_ view: some View, size: CGSize, name: String, wait: TimeInterval = 1.4) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view.background(Color.white))
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        window.isHidden = true
        window.rootViewController = nil

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    /// Share of pixels in `rect` (points) that are not near-white.
    private func inkShare(of image: UIImage, in rect: CGRect) throws -> Double {
        let cgImage = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cgImage.width) / image.size.width
        let pixelRect = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale).integral
        let cropped = try XCTUnwrap(cgImage.cropping(to: pixelRect))
        let width = cropped.width, height = cropped.height
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        var ink = 0
        for pixel in stride(from: 0, to: bytes.count, by: 4) where bytes[pixel] < 215 || bytes[pixel + 1] < 215 || bytes[pixel + 2] < 215 {
            ink += 1
        }
        return Double(ink) / Double(width * height)
    }

    private func tag(_ size: CGSize) -> String { "\(Int(size.width))x\(Int(size.height))" }

    // MARK: - Content

    /// The four statistics the sweep's fixed answers produce.
    private static let statisticKeys = ["last_approach", "approach_frequency", "barriers", "goals"]

    private func statistic(_ key: String) throws -> StatisticContent {
        try XCTUnwrap(StatisticContent.for(questionKey: key, ageGroup: "25-34"), key)
    }

    private func doubled(_ text: String) -> String { "\(text) \(text)" }

    private func doubled(_ statistic: StatisticContent) -> StatisticContent {
        StatisticContent(
            heading: doubled(statistic.heading),
            subheading: doubled(statistic.subheading),
            imageName: statistic.imageName,
            fact: doubled(statistic.fact)
        )
    }

    private var doubledGrowth: GrowthProjectionContent {
        let english = GrowthProjectionContent.default
        return GrowthProjectionContent(
            headline: doubled(english.headline),
            bullets: english.bullets.map {
                .init(systemImage: $0.systemImage, emphasis: $0.emphasis, text: doubled($0.text))
            },
            positiveLabel: doubled(english.positiveLabel),
            negativeLabel: doubled(english.negativeLabel),
            footnote: nil
        )
    }

    // MARK: - English renders (compare across runs)

    func testEnglishStatisticScreensRender() throws {
        for key in Self.statisticKeys {
            for size in Self.sizes {
                let image = try draw(
                    StatisticScreen(statistic: try statistic(key), onContinue: {}),
                    size: size, name: "english-statistic-\(key)-\(tag(size))"
                )
                // Heading at the top, "Tap to continue" at the bottom right.
                XCTAssertGreaterThan(try inkShare(of: image, in: CGRect(x: 24, y: 0, width: size.width - 48, height: 60)), 0.02, key)
                XCTAssertGreaterThan(
                    try inkShare(of: image, in: CGRect(x: size.width / 2, y: size.height - 56, width: size.width / 2 - 20, height: 40)),
                    0.01, key
                )
            }
        }
    }

    func testEnglishGrowthProjectionRenders() throws {
        for size in Self.sizes {
            let image = try draw(
                GrowthProjectionScreen(onContinue: {}),
                size: size, name: "english-growth-\(tag(size))", wait: 3.5
            )
            // The Continue button is a dark bar across the bottom.
            XCTAssertGreaterThan(
                try inkShare(of: image, in: CGRect(x: 30, y: size.height - 62, width: size.width - 60, height: 40)), 0.7
            )
        }
    }

    // MARK: - Long text on a small phone

    /// The problem, kept on record: with doubled text the original layout
    /// has more content than screen, and "Tap to continue" ends up below the
    /// bottom edge.
    func testTheOriginalStatisticLayoutLosesItsHintWithDoubledText() throws {
        let image = try draw(
            StatisticScreen(statistic: doubled(try statistic("last_approach")), onContinue: {}),
            size: Self.small, name: "english-layout-doubled-statistic-last_approach-\(tag(Self.small))"
        )
        let hint = CGRect(x: Self.small.width / 2, y: Self.small.height - 56, width: Self.small.width / 2 - 20, height: 40)
        XCTAssertLessThan(try inkShare(of: image, in: hint), 0.2)
    }

    /// In a translated app the same content scrolls: the heading starts at
    /// the top and "Tap to continue" stays on screen, for all four.
    func testTranslatedStatisticScreensKeepTheirHintWithDoubledText() throws {
        try useATranslatedApp()
        for key in Self.statisticKeys {
            let size = Self.small
            let image = try draw(
                StatisticScreen(statistic: doubled(try statistic(key)), onContinue: {}),
                size: size, name: "translated-doubled-statistic-\(key)-\(tag(size))"
            )
            XCTAssertGreaterThan(try inkShare(of: image, in: CGRect(x: 24, y: 0, width: size.width - 48, height: 60)), 0.02, key)
            // The hint row: grey text on white at the bottom right, and no
            // body text running through the bottom-left of that row.
            let hint = CGRect(x: size.width / 2, y: size.height - 56, width: size.width / 2 - 20, height: 40)
            let share = try inkShare(of: image, in: hint)
            XCTAssertGreaterThan(share, 0.01, key)
            XCTAssertLessThan(share, 0.2, key)
            XCTAssertLessThan(
                try inkShare(of: image, in: CGRect(x: 24, y: size.height - 56, width: size.width / 2 - 40, height: 40)), 0.005, key
            )
        }
    }

    /// With text that fits, a translated app gets the original layout, and
    /// the same picture as English.
    func testTranslatedStatisticScreensMatchEnglishWhenTheTextFits() throws {
        var english: [String: UIImage] = [:]
        for key in Self.statisticKeys {
            for size in Self.sizes {
                english["\(key)-\(tag(size))"] = try draw(
                    StatisticScreen(statistic: try statistic(key), onContinue: {}),
                    size: size, name: "english-again-statistic-\(key)-\(tag(size))"
                )
            }
        }
        try useATranslatedApp()
        for key in Self.statisticKeys {
            for size in Self.sizes {
                let translated = try draw(
                    StatisticScreen(statistic: try statistic(key), onContinue: {}),
                    size: size, name: "translated-statistic-\(key)-\(tag(size))"
                )
                let reference = try XCTUnwrap(english["\(key)-\(tag(size))"])
                XCTAssertEqual(translated.pngData(), reference.pngData(), "\(key) at \(tag(size))")
            }
        }
    }

    /// Growth projection with doubled text on a small phone: the Continue
    /// button stays a dark bar at the bottom and the chart starts at the top.
    func testTranslatedGrowthProjectionKeepsItsButtonWithDoubledText() throws {
        try useATranslatedApp()
        let size = Self.small
        let image = try draw(
            GrowthProjectionScreen(content: doubledGrowth, onContinue: {}),
            size: size, name: "translated-doubled-growth-\(tag(size))", wait: 3.5
        )
        XCTAssertGreaterThan(
            try inkShare(of: image, in: CGRect(x: 30, y: size.height - 62, width: size.width - 60, height: 40)), 0.7
        )
        XCTAssertGreaterThan(try inkShare(of: image, in: CGRect(x: 24, y: 0, width: size.width - 48, height: 120)), 0.01)
    }

    func testTranslatedGrowthProjectionMatchesEnglishWhenTheTextFits() throws {
        let size = Self.sizes[1]
        let english = try draw(GrowthProjectionScreen(onContinue: {}), size: size, name: "english-again-growth-\(tag(size))", wait: 3.5)
        try useATranslatedApp()
        let translated = try draw(GrowthProjectionScreen(onContinue: {}), size: size, name: "translated-growth-\(tag(size))", wait: 3.5)
        XCTAssertEqual(translated.size, english.size)
        // Same layout; the nested stack may place the chart a fraction of a
        // point differently, so compare the Continue button's place, not bytes.
        XCTAssertGreaterThan(
            try inkShare(of: translated, in: CGRect(x: 30, y: size.height - 62, width: size.width - 60, height: 40)), 0.7
        )
    }

    // MARK: - The scroll-when-too-tall rule

    private func block(lines: Int) -> some View {
        VStack(spacing: 10) {
            ForEach(0..<lines, id: \.self) { index in
                Text("Line \(index + 1) of the content")
                    .font(.manropeRegular(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 20)
            Color.wingmanBlack.frame(height: 40)
        }
        .padding(16)
    }

    func testEnglishContentIsLeftExactlyAsItIs() throws {
        let size = CGSize(width: 320, height: 300)
        for lines in [4, 20] {
            let plain = try draw(block(lines: lines), size: size, name: "rule-plain-\(lines)", wait: 0.3)
            let viaRule = try draw(
                block(lines: lines).scrollsWhenTooTallIfTranslated(usesSourceLanguageLayout: true),
                size: size, name: "rule-english-\(lines)", wait: 0.3
            )
            XCTAssertEqual(viaRule.pngData(), plain.pngData(), "\(lines) lines")
        }
    }

    func testTranslatedContentThatFitsIsLeftAsItIs() throws {
        let size = CGSize(width: 320, height: 300)
        let plain = try draw(block(lines: 4), size: size, name: "rule-plain-fits", wait: 0.3)
        let viaRule = try draw(
            block(lines: 4).scrollsWhenTooTallIfTranslated(usesSourceLanguageLayout: false),
            size: size, name: "rule-translated-fits", wait: 0.3
        )
        XCTAssertEqual(viaRule.pngData(), plain.pngData())
    }

    /// Too tall: the first line is at the top (a centred, overflowing stack
    /// would have pushed it off) and the content runs to the bottom edge.
    func testTranslatedContentThatIsTooTallScrollsFromTheTop() throws {
        let size = CGSize(width: 320, height: 300)
        let image = try draw(
            block(lines: 20).scrollsWhenTooTallIfTranslated(usesSourceLanguageLayout: false),
            size: size, name: "rule-translated-too-tall", wait: 0.3
        )
        XCTAssertGreaterThan(try inkShare(of: image, in: CGRect(x: 16, y: 12, width: 200, height: 26)), 0.03)
        // The dark bar that ends the block is far below the visible area.
        XCTAssertLessThan(try inkShare(of: image, in: CGRect(x: 0, y: 250, width: 320, height: 50)), 0.5)
    }
}
