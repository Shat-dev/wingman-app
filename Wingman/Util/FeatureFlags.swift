//
//  FeatureFlags.swift
//  Wingman
//
//  Remote configuration backed by PostHog feature flags.
//
//  Why this exists rather than reading `PostHogSDK.shared.isFeatureEnabled`
//  at the call site:
//
//    1. `isFeatureEnabled` is a side-effecting call — it emits a
//       `$feature_flag_called` event, which is what PostHog uses to attribute
//       experiment results. Calling it from inside a SwiftUI `body` would fire
//       it on every re-render.
//    2. Flags arrive asynchronously from `/decide`. A value read mid-render
//       can change between two renders of the same screen, which for a
//       paywall means the dismiss button could appear or vanish under the
//       user's finger.
//
//  So flags are read once into `@Published` state and views observe that.
//

import Foundation
import PostHog
import Combine

@MainActor
final class FeatureFlags: ObservableObject {

    static let shared = FeatureFlags()

    /// Controls whether the post-demo ask is a hard wall (no dismiss) or a
    /// dismissible paywall.
    ///
    /// Ships **false** — the ask is dismissible in v1.0. The point of routing
    /// this through PostHog is that flipping it later is a server-side change
    /// with no App Store release, and can run as a proper A/B test rather than
    /// a one-way bet. The number that should decide the flip is purchase rate
    /// at `source=post_demo` versus `source=onboarding`.
    ///
    /// False is also the safe default: if `/decide` never responds, or the
    /// flag is deleted from the PostHog project, users get the softer
    /// experience rather than being unexpectedly walled.
    @Published private(set) var postDemoWallIsHard: Bool = false

    private static let postDemoWallHardKey = "post_demo_wall_hard"

    private init() {}

    /// Pull the latest flag values from PostHog, then publish them.
    ///
    /// Safe to call repeatedly. Call after SDK setup at launch and again after
    /// `identify()` — flag evaluation is per-distinct-id, so the values for an
    /// anonymous launch and the same person once signed in are not necessarily
    /// the same.
    func refresh() {
        PostHogSDK.shared.reloadFeatureFlags { [weak self] in
            Task { @MainActor in
                self?.read()
            }
        }
    }

    /// Read currently-cached flag values without a network round trip. Used on
    /// the launch path so a warm cache from a previous session applies
    /// immediately instead of waiting on `/decide`.
    func read() {
        #if DEBUG
        // Local override for testing both branches without touching the
        // PostHog project. Launch argument: -postDemoWallIsHard YES
        if UserDefaults.standard.object(forKey: "postDemoWallIsHard") != nil {
            let forced = UserDefaults.standard.bool(forKey: "postDemoWallIsHard")
            if postDemoWallIsHard != forced {
                postDemoWallIsHard = forced
            }
            log("🚩 FeatureFlags: postDemoWallIsHard OVERRIDDEN locally = \(forced)")
            return
        }
        #endif

        let value = PostHogSDK.shared.isFeatureEnabled(Self.postDemoWallHardKey)
        if postDemoWallIsHard != value {
            log("🚩 FeatureFlags: postDemoWallIsHard \(postDemoWallIsHard) → \(value)")
            postDemoWallIsHard = value
        }
    }
}
