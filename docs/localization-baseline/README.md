# Localization baseline (prerequisite P3)

English reference captured on 2026-11-10 from app code at commit `09b4700` (1.14 build 37), before any localization change. Used to show that Release A changes nothing for English users. See [../localization-implementation-plan.md](../localization-implementation-plan.md).

Everything here was produced by the `WingmanUITests` target, so it can be reproduced at any time, including against the baseline commit.

## Cold launch time

| Device | Build | Runs | Average | Spread | Values (s) |
|---|---|---|---|---|---|
| iPhone 17 Pro simulator, iOS 26.5 | Debug | 5 | **0.858 s** | 2.9% relative std dev | 0.831, 0.847, 0.904, 0.850, 0.857 |

Source: `LaunchPerformanceTests.testColdLaunch` (`XCTApplicationLaunchMetric`).

These are Debug-on-simulator numbers. They are only meaningful compared with another run on the same Mac and simulator; they say nothing about launch time on a real phone.

## Screenshots: landing to paywall

Source: `OnboardingSweepTests.testOnboardingToPaywall`. Fixed answers: "Want more confidence in general", "25-34", "Within the past month", "Sometimes", "Not knowing what to say or how to start", "Learning how to approach".

| Folder | Device | Screens |
|---|---|---|
| `iphone-17-pro/` | iPhone 17 Pro simulator | 17 |
| `iphone-se/` | iPhone SE (3rd generation) simulator | 17 |

Screens, in order: landing, six questions, four statistic interstitials, growth projection, loading, notification prompt, social proof, commitment pact, paywall.

## Screenshots: past the paywall (added during WP6)

`iphone-17-pro/18-…` to `26-…`, captured 2026-11-10 by the same sweep after it was extended: the five first-run walkthrough cards (each over a dimmed tab) and the four tabs as a new user who closed the paywall sees them.

These were captured **after** the WP5 and WP6 changes, so they are a reference for later work, not proof that those screens are unchanged from build 37. They also contain content that changes between runs (the greeting, the quote of the day), so compare them by eye, not pixel for pixel. The one-time offer is not among them: it closes itself in a Debug build because no products load.

## Screenshot: voluntary sign-in

`iphone-17-pro/auth-login-voluntary.png`, added 2026-11-10 during WP6. Source: `AuthScreenTests.testVoluntaryLoginScreen` (landing → "Log in"). Captured after the WP5 changes, and pixel-identical below the status bar to a capture taken the same day before the WP6 change to the sign-in screen. Creates no guest user. This screen has no legal line; that line is only on the sign-in screens reached after a purchase or from the profile's account prompt.

## Double-length pseudo-language run

`OnboardingSweepTests.testOnboardingInDoubleLengthPseudoLanguage` walks the same path with every localized string doubled and the translated-app layouts switched on. It needs no translation to exist. Its screenshots are read for cut, clipped or overlapping text; nothing is compared. It creates a guest user like the English run, so run one method per run.

## How to re-run

```bash
xcodebuild test -project Wingman.xcodeproj -scheme Wingman -destination 'platform=iOS Simulator,name=Wingman L10n 17 Pro' -skipMacroValidation -skipPackagePluginValidation -only-testing:WingmanUITests/OnboardingSweepTests/testOnboardingToPaywall -resultBundlePath /tmp/wingman-sweep.xcresult
```

```bash
xcrun xcresulttool export attachments --path /tmp/wingman-sweep.xcresult --output-path /tmp/wingman-sweep-shots
```

The sweep needs a clean install. On a simulator that has run it before, boot it, then uninstall the app and reset its keychain first (`xcrun simctl uninstall <udid> com.lazul.wingman`, `xcrun simctl keychain <udid> reset`). Use the throwaway simulators named "Wingman L10n …", not one that holds a real test install.

## Known limits

- **The paywall is captured without prices.** A Debug build cannot load offerings, so `17-paywall.png` shows "Can't load pricing". The priced paywall and the one-time offer need a Release build, and Release tags analytics events as production. Not captured yet.
- **Nothing past the paywall is captured.** Home, courses, lesson, quiz, scenario, profile and settings are not in the sweep yet.
- **Time to first paywall is not measured.** Only cold launch is.
- **The status bar clock differs between runs**, so compare images by eye or mask the top strip; an exact pixel diff will always differ there.
- **Each sweep run creates one anonymous user in the production Supabase project** (tapping "Get started" signs in a guest) and sends PostHog events tagged `environment = dev`. Do not run it in a loop.
- **The sweep finds elements by English text.** It will need accessibility identifiers before it can run in another language.
