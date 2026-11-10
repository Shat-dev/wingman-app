//
//  TranslatedTextFitTests.swift
//  WingmanTests
//
//  WP6 of the localization plan, third slice: line caps.
//
//  Six texts were capped at one or two lines. English keeps every cap; a
//  translated app gets more lines or a mild shrink. These tests pin the rule,
//  prove by pixel comparison that English renders as the original markup did,
//  and show that a longer answer is no longer cut in a translated app.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class TranslatedTextFitTests: XCTestCase {

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
            .appendingPathComponent("fit-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
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

    private func assertSamePicture(_ a: UIImage, _ b: UIImage, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(a.size, b.size, message, file: file, line: line)
        XCTAssertEqual(try pixels(a), try pixels(b), message, file: file, line: line)
    }

    // MARK: - The rule

    func testEnglishKeepsItsCapAndNeverShrinks() {
        XCTAssertEqual(
            TextFit.resolve(english: 2, translated: nil, shrinkingTo: 0.7, usesSourceLanguageLayout: true),
            TextFit(lineLimit: 2, minimumScaleFactor: 1)
        )
        XCTAssertEqual(
            TextFit.resolve(english: 1, translated: 3, usesSourceLanguageLayout: true),
            TextFit(lineLimit: 1, minimumScaleFactor: 1)
        )
    }

    func testATranslatedAppGetsTheRoomierFit() {
        XCTAssertEqual(
            TextFit.resolve(english: 2, translated: nil, usesSourceLanguageLayout: false),
            TextFit(lineLimit: nil, minimumScaleFactor: 1)
        )
        XCTAssertEqual(
            TextFit.resolve(english: 2, translated: 3, shrinkingTo: 0.85, usesSourceLanguageLayout: false),
            TextFit(lineLimit: 3, minimumScaleFactor: 0.85)
        )
    }

    func testTheDefaultFollowsTheAppLanguage() throws {
        XCTAssertEqual(TextFit.resolve(english: 2, translated: nil), TextFit(lineLimit: 2, minimumScaleFactor: 1))
        try useATranslatedApp()
        XCTAssertEqual(TextFit.resolve(english: 2, translated: nil), TextFit(lineLimit: nil, minimumScaleFactor: 1))
    }

    // MARK: - English renders as before

    private static let longText = "Tell her the spot and give her instructions on how to get there, then ask what settings she's using and tell her your recommendation before you leave."

    /// A text long enough to hit the cap is cut in the same place.
    func testTheModifierInEnglishIsPixelIdenticalToAPlainLineLimit() throws {
        for (cap, width) in [(1, 200.0), (2, 250.0), (3, 250.0)] {
            let text = Text(Self.longText).font(.manropeMedium(size: 14))
            let before = try render(text.lineLimit(cap), width: width, name: "cap-\(cap)-plain")
            let after = try render(
                text.lineLimit(cap, whenTranslated: nil, shrinkingTo: 0.7),
                width: width, name: "cap-\(cap)-modifier"
            )
            try assertSamePicture(after, before, "cap \(cap)")
        }
    }

    /// The tab bar exactly as `MainTabView` wrote it before this slice.
    private func originalTabButton(icon: String, title: String, isSelected: Bool) -> some View {
        Button(action: {}) {
            VStack() {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSelected ? .wingmanBlack : Color(red: 0.6, green: 0.6, blue: 0.6))

                Text(title)
                    .font(.manropeMedium(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle())
    }

    private static let tabs = [("home", "Home"), ("map", "Courses"), ("calendar", "Scenarios"), ("user", "Profile")]

    func testEnglishTabLabelsArePixelIdenticalToTheOriginalMarkup() throws {
        let before = HStack(spacing: 0) {
            ForEach(Self.tabs, id: \.1) { tab in
                self.originalTabButton(icon: tab.0, title: tab.1, isSelected: tab.1 == "Home")
            }
        }
        let after = HStack(spacing: 0) {
            ForEach(Self.tabs, id: \.1) { tab in
                TabBarButton(icon: tab.0, title: tab.1, isSelected: tab.1 == "Home", action: {})
            }
        }
        for width in [375.0, 402.0] {
            try assertSamePicture(
                try render(after, width: width, name: "tabs-english-\(Int(width))"),
                try render(before, width: width, name: "tabs-original-\(Int(width))"),
                "width \(width)"
            )
        }
    }

    /// A translated label stays inside its quarter of the bar.
    func testALongTranslatedTabLabelStaysInItsOwnQuarter() throws {
        try useATranslatedApp()
        let long = [("home", "Startseite"), ("map", "Kursübersicht"), ("calendar", "Übungsszenarien"), ("user", "Mein Profil")]
        let bar = HStack(spacing: 0) {
            ForEach(long, id: \.1) { tab in
                TabBarButton(icon: tab.0, title: tab.1, isSelected: tab.1 == "Startseite", action: {})
            }
        }
        // 320pt is the narrowest canvas the app runs on (Display Zoom).
        let image = try render(bar, width: 320, name: "tabs-translated-long-320")
        XCTAssertEqual(image.size.width, 320, accuracy: 0.5)
    }

    // MARK: - Scenario answer buttons

    /// The option list exactly as `OptionsContentView` wrote it before this
    /// slice, in its idle state.
    private func originalOptionList(_ options: [GameOption]) -> some View {
        VStack(spacing: 12) {
            ForEach(options.sorted { $0.orderIndex < $1.orderIndex }) { option in
                Button {} label: {
                    Text(option.text)
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.wingmanBlack.opacity(0.1), lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                                .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
                        )
                }
                .buttonStyle(ScalePressStyle())
                .opacity(1.0)
                .disabled(false)
            }

            Text("Choose an option to continue")
                .font(.manropeMedium(size: 14))
                .foregroundColor(.wingmanBlack.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 1)
                .padding(.trailing, 8)
                .opacity(1.0)
        }
    }

    private func options(_ texts: [String]) -> [GameOption] {
        texts.enumerated().map { index, text in
            GameOption(id: "option-\(index)", text: text, nextSceneId: nil, isCorrect: index == 0, orderIndex: index)
        }
    }

    /// The three longest kinds of answer the scenarios hold today.
    private static let englishAnswers = [
        "\"I know it's random but do you want to go get coffee? Only if you want.\"",
        "Tell her the spot and give her instructions on how to get there",
        "\"Nice to meet you.\""
    ]

    /// About a third longer, as German runs.
    private static let translatedAnswers = [
        "„Ich weiß, das kommt jetzt etwas plötzlich, aber hättest du Lust, mit mir einen Kaffee trinken zu gehen? Nur wenn du magst.“",
        "Nenne ihr den Ort und erkläre ihr Schritt für Schritt, wie sie am besten dorthin kommt",
        "„Schön, dich kennenzulernen.“"
    ]

    func testEnglishOptionListIsPixelIdenticalToTheOriginalMarkup() throws {
        let list = options(Self.englishAnswers)
        // Scenario screen width minus its 24pt side padding, on an SE, a 17 Pro and a Pro Max.
        for width in [327.0, 354.0, 392.0] {
            let before = try render(originalOptionList(list), width: width, name: "options-original-\(Int(width))")
            let after = try render(
                OptionsContentView(options: list, pendingSelection: nil, onSelectOption: { _ in }),
                width: width, name: "options-english-\(Int(width))"
            )
            try assertSamePicture(after, before, "width \(width)")
        }
    }

    /// The capped list cuts a long translated answer; the translated layout
    /// grows instead.
    func testATranslatedOptionListGrowsInsteadOfCuttingTheAnswer() throws {
        let list = options(Self.translatedAnswers)
        let capped = try render(originalOptionList(list), width: 327, name: "options-translated-with-english-cap-327")

        try useATranslatedApp()
        let grown = try render(
            OptionsContentView(options: list, pendingSelection: nil, onSelectOption: { _ in }),
            width: 327, name: "options-translated-327"
        )
        XCTAssertEqual(grown.size.width, 327, accuracy: 0.5)
        // At least one more line of 16pt text than the capped list.
        XCTAssertGreaterThan(grown.size.height, capped.size.height + 18)
    }

    /// Draws `view` in a real window. `ImageRenderer` cannot draw the inside
    /// of a ScrollView, so the scrolling case needs this.
    private func drawInWindow(_ view: some View, size: CGSize, name: String) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view.background(Color.white))
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let image = UIGraphicsImageRenderer(size: size).image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        window.isHidden = true

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    /// Share of pixels in `rect` (in points) that are not white.
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
        for pixel in stride(from: 0, to: bytes.count, by: 4) where bytes[pixel] < 200 || bytes[pixel + 1] < 200 || bytes[pixel + 2] < 200 {
            ink += 1
        }
        return Double(ink) / Double(width * height)
    }

    /// With too little height for the grown list, it scrolls: the first
    /// answer is shown in full from the top, and nothing is squeezed.
    func testATranslatedOptionListScrollsOnAShortScreen() throws {
        try useATranslatedApp()
        let list = options(Self.translatedAnswers)
        let view = OptionsContentView(options: list, pendingSelection: nil, onSelectOption: { _ in })
        let size = CGSize(width: 327, height: 220)
        let image = try drawInWindow(view, size: size, name: "options-translated-short-327x220")

        // Text is drawn in the top band (the first answer starts at the top
        // of the scroll view) and all the way down to the bottom edge (the
        // list continues past it).
        XCTAssertGreaterThan(try inkShare(of: image, in: CGRect(x: 20, y: 10, width: 287, height: 100)), 0.03)
        XCTAssertGreaterThan(try inkShare(of: image, in: CGRect(x: 20, y: 150, width: 287, height: 60)), 0.02)
    }

    /// With room to spare the same list does not scroll and is centred by
    /// its container, as the English one is.
    func testATranslatedOptionListDoesNotScrollWhenItFits() throws {
        try useATranslatedApp()
        let list = options(Self.translatedAnswers)
        let fitted = try render(
            OptionsContentView(options: list, pendingSelection: nil, onSelectOption: { _ in }),
            width: 327, name: "options-translated-natural"
        )
        let roomy = try render(
            OptionsContentView(options: list, pendingSelection: nil, onSelectOption: { _ in })
                .frame(height: fitted.size.height + 200),
            width: 327, name: "options-translated-roomy"
        )
        // ImageRenderer draws nothing inside a ScrollView, so ink in the
        // middle of the picture means the plain list was chosen.
        XCTAssertGreaterThan(
            try inkShare(of: roomy, in: CGRect(x: 20, y: 100, width: 287, height: fitted.size.height)), 0.02
        )
    }
}
