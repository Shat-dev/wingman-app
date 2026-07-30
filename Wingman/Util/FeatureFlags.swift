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

    /// Whether the app may create Supabase anonymous ("guest") sessions.
    ///
    /// **Ships `true` — fail open.** This flipped from `false` in Phase E, as
    /// planned. While Phase B stood alone the safe default was off (nothing
    /// routed on a guest session, so creating rows would have been pure
    /// downside). Now that routing depends on a session existing, a `/decide`
    /// failure defaulting to `false` would drop users into the legacy
    /// no-session branch and wall them at account creation — the failure mode
    /// the whole plan exists to remove.
    ///
    /// It remains the rollback lever: if the bootstrap guard misfires in the
    /// wild, setting `guest_sessions_enabled` to false in PostHog stops guest
    /// creation server-side with no App Store release. Users who already hold a
    /// guest session keep it; the flag gates creation, not use.
    @Published private(set) var guestSessionsEnabled: Bool = true

    private static let postDemoWallHardKey = "post_demo_wall_hard"

    /// Deliberately phrased as a **kill switch**, not an enable switch.
    ///
    /// `isFeatureEnabled` returns `false` for a flag that does not exist in the
    /// PostHog project, and for any launch before `/decide` answers. With an
    /// `enabled`-style key that reads as "off", which would silently defeat the
    /// fail-open default above and wall every user at account creation. Phrased
    /// as `disabled`, the absent/unknown case reads as "not disabled" — open —
    /// and only an explicitly created-and-enabled flag can turn guest sessions
    /// off.
    private static let guestSessionsDisabledKey = "guest_sessions_disabled"

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

        readGuestSessionsEnabled()
    }

    private func readGuestSessionsEnabled() {
        #if DEBUG
        // Launch argument: -guestSessionsEnabled YES
        // Required to exercise Phase B at all, since the flag ships false.
        if UserDefaults.standard.object(forKey: "guestSessionsEnabled") != nil {
            let forced = UserDefaults.standard.bool(forKey: "guestSessionsEnabled")
            if guestSessionsEnabled != forced {
                guestSessionsEnabled = forced
            }
            log("🚩 FeatureFlags: guestSessionsEnabled OVERRIDDEN locally = \(forced)")
            return
        }
        #endif

        // Inverted on purpose — see `guestSessionsDisabledKey`. Absent or
        // not-yet-loaded reads as "not disabled", so the default stays open.
        let value = !PostHogSDK.shared.isFeatureEnabled(Self.guestSessionsDisabledKey)
        if guestSessionsEnabled != value {
            log("🚩 FeatureFlags: guestSessionsEnabled \(guestSessionsEnabled) → \(value)")
            guestSessionsEnabled = value
        }
    }
}
