//
//  CommitmentPactRenderTests.swift
//  WingmanTests
//
//  Draws the commitment pact screen at real phone sizes, at rest and after
//  an early release ("Keep holding until the ring fills."), and attaches the
//  pictures. Run with `-testLanguage de` (or es, fr) to see a translation;
//  the onboarding sweep would create a user in production to reach this
//  screen, this does not.
//
//  The screen sends `commitment_pact_viewed` when it appears, so analytics
//  go to a recorder for the duration.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class CommitmentPactRenderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Analytics.recorderForTesting = { _ in }
    }

    override func tearDown() {
        Analytics.recorderForTesting = nil
        super.tearDown()
    }

    /// iPhone SE (and an iPhone app on iPad), a Pro with Display Zoom, and a
    /// 17 Pro. The pact screen has no top bar, so these are full screens.
    private static let sizes = [
        CGSize(width: 375, height: 667),
        CGSize(width: 320, height: 693),
        CGSize(width: 402, height: 874),
    ]

    private func draw(_ view: some View, size: CGSize, name: String) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))

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

    func testPactScreenAtRestAndAfterAnEarlyRelease() throws {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        for size in Self.sizes {
            let tag = "\(Int(size.width))x\(Int(size.height))"
            for releases in [0, 1] {
                let view = CommitmentPactView(earlyReleases: releases).environmentObject(AuthManager())
                let image = try draw(view, size: size, name: "pact-\(language)-\(releases == 0 ? "rest" : "keep-holding")-\(tag)")
                XCTAssertEqual(image.size, size)
            }
        }
    }

    /// The nudge must say something different from the first instruction,
    /// in every language, or an early release changes nothing on screen.
    func testKeepHoldingDiffersFromTheInstruction() {
        XCTAssertNotEqual(CommitmentPactCopy.keepHolding, CommitmentPactCopy.holdInstruction)
        XCTAssertFalse(CommitmentPactCopy.keepHolding.isEmpty)
    }
}
