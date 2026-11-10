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

## How to re-run

```bash
xcodebuild test -project Wingman.xcodeproj -scheme Wingman -destination 'platform=iOS Simulator,name=Wingman L10n 17 Pro' -skipMacroValidation -skipPackagePluginValidation -only-testing:WingmanUITests -resultBundlePath /tmp/wingman-sweep.xcresult
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
