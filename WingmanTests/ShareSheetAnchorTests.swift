//
//  ShareSheetAnchorTests.swift
//  WingmanTests
//
//  Profile's Invite Friends button presents a `UIActivityViewController`. In a
//  regular-width window (the iPhone Duo's inner display) that presents as a
//  popover, which needs a source to point at or UIKit throws. These tests
//  present it the way `InviteFriendsCard.shareApp()` does, after
//  `InviteFriendsCard.anchorPopover(_:in:)`, in both a compact and a regular window.
//

import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class ShareSheetAnchorTests: XCTestCase {

    private func present(regularWidth: Bool) throws -> UIViewController? {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        let root = UIViewController()
        if regularWidth {
            guard #available(iOS 17.0, *) else { throw XCTSkip("traitOverrides needs iOS 17") }
            root.traitOverrides.horizontalSizeClass = .regular
        }
        window.rootViewController = root
        window.makeKeyAndVisible()
        // iOS 27 defers a presentation whose presenter is not in the window
        // yet; give the fresh test window time to settle first.
        let deadline = Date().addingTimeInterval(3.0)
        while root.view.window == nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let activity = UIActivityViewController(activityItems: ["Join me on Wingman!"], applicationActivities: nil)
        InviteFriendsCard.anchorPopover(activity, in: window)
        root.present(activity, animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        let presented = root.presentedViewController

        root.dismiss(animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        window.isHidden = true
        window.rootViewController = nil
        return presented
    }

    func testTheShareSheetPresentsInACompactWindow() throws {
        XCTAssertTrue(try present(regularWidth: false) is UIActivityViewController)
    }

    func testTheShareSheetPresentsInARegularWidthWindow() throws {
        XCTAssertTrue(try present(regularWidth: true) is UIActivityViewController)
    }
}
