//
//  WindowSizeEnvironmentTests.swift
//  WingmanTests
//
//  `\.windowSize` replaces `UIScreen.main.bounds` for layout decisions
//  (Util/Device+Screen.swift). It is measured once at the app root, so these
//  tests check the two things the replacement relies on:
//
//    * it equals the window — on a portrait full-screen iPhone, the screen
//      size `UIScreen.main` used to report — so every `isSmallPhone` decision
//      comes out as before;
//    * it reaches content presented in a `.sheet` and a `.fullScreenCover`,
//      where several of those decisions are made (the Settings close button,
//      CompletionScreen inside the lesson's full-screen cover).
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class WindowSizeEnvironmentTests: XCTestCase {

    private final class Box {
        var sizes: [String: CGSize] = [:]
    }

    private struct Probe: View {
        let name: String
        let box: Box
        @Environment(\.windowSize) private var windowSize

        var body: some View {
            Color.clear
                .onAppear { box.sizes[name] = windowSize }
                .onChange(of: windowSize) { newValue in box.sizes[name] = newValue }
        }
    }

    private func host(_ view: some View) throws -> (UIWindow, CGSize) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let size = scene.screen.bounds.size
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: view.readsWindowSize())
        window.isHidden = false
        window.rootViewController?.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        return (window, size)
    }

    private func tearDown(_ window: UIWindow) {
        window.rootViewController?.dismiss(animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        window.isHidden = true
        window.rootViewController = nil
    }

    func testTheRootGetsTheWindowSize() throws {
        let box = Box()
        let (window, size) = try host(Probe(name: "root", box: box))
        defer { tearDown(window) }
        XCTAssertEqual(box.sizes["root"], size)
    }

    func testASheetGetsTheWindowSize() throws {
        let box = Box()
        let (window, size) = try host(
            Color.white.sheet(isPresented: .constant(true)) { Probe(name: "sheet", box: box) }
        )
        defer { tearDown(window) }
        XCTAssertEqual(box.sizes["sheet"], size)
    }

    func testAFullScreenCoverGetsTheWindowSize() throws {
        let box = Box()
        let (window, size) = try host(
            Color.white.fullScreenCover(isPresented: .constant(true)) { Probe(name: "cover", box: box) }
        )
        defer { tearDown(window) }
        XCTAssertEqual(box.sizes["cover"], size)
    }

    func testTheSmallPhonePredicateIsUnchanged() {
        // The phones the app runs on today, portrait.
        XCTAssertTrue(WindowMetrics.isSmallPhone(CGSize(width: 375, height: 667)))   // SE 2/3
        XCTAssertTrue(WindowMetrics.isSmallPhone(CGSize(width: 320, height: 568)))   // SE, Display Zoom
        XCTAssertTrue(WindowMetrics.isSmallPhone(CGSize(width: 320, height: 693)))   // mini/Pro, Display Zoom
        XCTAssertFalse(WindowMetrics.isSmallPhone(CGSize(width: 375, height: 812)))  // mini
        XCTAssertFalse(WindowMetrics.isSmallPhone(CGSize(width: 402, height: 874)))  // 17 / 17 Pro
        XCTAssertFalse(WindowMetrics.isSmallPhone(CGSize(width: 440, height: 956)))  // 17 Pro Max
        // Landscape never counts, as before.
        XCTAssertFalse(WindowMetrics.isSmallPhone(CGSize(width: 667, height: 375)))
        // Not measured yet.
        XCTAssertFalse(WindowMetrics.isSmallPhone(.zero))
    }

    func testNoCurrentPhoneIsAShortWindow() {
        for size in [
            CGSize(width: 320, height: 568), CGSize(width: 375, height: 667), CGSize(width: 320, height: 693),
            CGSize(width: 375, height: 812), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956),
        ] {
            XCTAssertFalse(WindowMetrics.isShortWindow(size), "\(size)")
        }
        XCTAssertFalse(WindowMetrics.isShortWindow(.zero))
        XCTAssertTrue(WindowMetrics.isShortWindow(CGSize(width: 700, height: 420)))
    }
}
