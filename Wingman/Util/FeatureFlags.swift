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

    /// Whether a lesson requires passing a short knowledge check before it can
    /// be marked complete.
    ///
    /// **Ships `true` — fail open.** This flipped from `false`, and the flag
    /// flipped with it from `lesson_quiz_enabled` to `lesson_quiz_disabled`.
    ///
    /// While the questions were being authored, off was the safe default: the
    /// check adds friction to the single path that drives next-lesson unlock,
    /// next-course unlock, all fifteen scenario unlocks, and the Home progress
    /// card. That reasoning has expired. All 94 lessons now have questions, so
    /// an absent flag or a `/decide` failure defaulting to `false` no longer
    /// means "behave as before" — it means the feature is silently off for
    /// everyone, which is the state it was actually in.
    ///
    /// Phrased as a kill switch for the same reason as
    /// `guest_sessions_disabled`: `isFeatureEnabled` returns `false` both for a
    /// flag that does not exist and for every launch before `/decide` answers.
    /// With an `enabled`-style key those cases read as "off" and defeat the
    /// default. Phrased as `disabled`, they read as "not disabled" — on — and
    /// only an explicitly created-and-enabled flag can turn the quiz off.
    ///
    /// The number that decides whether to pull it is `lesson_completed` per
    /// `lesson_started`, against `lesson_quiz_abandoned`.
    @Published private(set) var lessonQuizEnabled: Bool = true

    private static let postDemoWallHardKey = "post_demo_wall_hard"

    /// Inverted on purpose — see `lessonQuizEnabled`.
    private static let lessonQuizDisabledKey = "lesson_quiz_disabled"

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

        // `sendFeatureFlagEvent: false` — see `recordPostDemoWallExposure()`.
        let value = PostHogSDK.shared.isFeatureEnabled(
            Self.postDemoWallHardKey,
            sendFeatureFlagEvent: false
        )
        if postDemoWallIsHard != value {
            log("🚩 FeatureFlags: postDemoWallIsHard \(postDemoWallIsHard) → \(value)")
            postDemoWallIsHard = value
        }

        readGuestSessionsEnabled()
        readLessonQuizEnabled()
    }

    /// Records experiment exposure for `post_demo_wall_hard`, at the moment the
    /// post-demo wall is actually put in front of the user.
    ///
    /// PostHog attributes experiment results to `$feature_flag_called`. This
    /// method exists because `read()` runs on the launch path for **every**
    /// user, which meant the exposure event fired for the whole install base
    /// while only the fraction who finish the demo ever see either variant.
    /// That inflates the denominator with users who could not possibly have
    /// been affected, shrinking the measured effect toward zero — on precisely
    /// the number that is supposed to decide whether the wall gets hardened.
    ///
    /// So `read()` now reads the value silently and the exposure is recorded
    /// here instead. Calling `isFeatureEnabled` *with* the event is the SDK's
    /// own way to do that; the value it returns is ignored because
    /// `postDemoWallIsHard` already carries it. This is safe to pair with the
    /// silent read: the SDK's once-per-value de-duplication is populated inside
    /// `reportFeatureFlagCalled`, which a `sendFeatureFlagEvent: false` read
    /// never reaches — so suppressing the launch event cannot suppress this one.
    ///
    /// The caller is responsible for firing this exactly once per presentation;
    /// `PaywallView` hangs it off the same one-shot guard as `paywall_viewed`.
    func recordPostDemoWallExposure() {
        #if DEBUG
        // A locally-forced flag makes the app behave one way while PostHog
        // still reports the server's value. Recording that would file the
        // developer under a variant they did not actually experience.
        if UserDefaults.standard.object(forKey: "postDemoWallIsHard") != nil {
            log("🚩 FeatureFlags: skipping post-demo wall exposure — locally overridden")
            return
        }
        #endif

        _ = PostHogSDK.shared.isFeatureEnabled(Self.postDemoWallHardKey)
        log("🚩 FeatureFlags: recorded post_demo_wall_hard exposure (\(postDemoWallIsHard))")
    }

    private func readLessonQuizEnabled() {
        // Launch argument: -lessonQuizEnabled NO
        //
        // Now that the default is on, the useful direction is forcing it *off*
        // — walking 94 lessons through a mandatory check is punishing to QA.
        // (`-skipLessonQuiz YES` in LessonView does the same thing one layer
        // down, leaving the flag on but serving no questions.)
        //
        // Deliberately NOT behind `#if DEBUG`, unlike the two overrides below.
        // Subscription pricing and purchases only work in a Release build, so
        // every end-to-end test of a paywalled surface — which a lesson is —
        // has to happen in Release. A Debug-only override is unusable for
        // exactly the flows most worth testing.
        //
        // Safe to ship: launch arguments populate `NSArgumentDomain` from the
        // process's argv, and an App Store app launched from the home screen
        // has no argv beyond its own path. Only a developer running via Xcode
        // or `simctl` can set this. Note the corollary — the argument applies
        // *only* to the process Xcode spawns, so re-opening the app from the
        // home screen silently drops it and falls back to the flag below.
        if UserDefaults.standard.object(forKey: "lessonQuizEnabled") != nil {
            let forced = UserDefaults.standard.bool(forKey: "lessonQuizEnabled")
            if lessonQuizEnabled != forced {
                lessonQuizEnabled = forced
            }
            log("🚩 FeatureFlags: lessonQuizEnabled OVERRIDDEN locally = \(forced)")
            return
        }

        // Inverted on purpose — see `lessonQuizDisabledKey`. Absent or
        // not-yet-loaded reads as "not disabled", so the default stays on.
        let value = !PostHogSDK.shared.isFeatureEnabled(Self.lessonQuizDisabledKey)
        if lessonQuizEnabled != value {
            log("🚩 FeatureFlags: lessonQuizEnabled \(lessonQuizEnabled) → \(value)")
            lessonQuizEnabled = value
        }
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
