# Localization baseline (prerequisite P3)

English reference captured on 2026-11-10 from app code at commit `09b4700` (1.14 build 37), before any localization change. Used to show that Release A changes nothing for English users. See [../localization-implementation-plan.md](../localization-implementation-plan.md).

Everything here was produced by the `WingmanUITests` target, so it can be reproduced at any time, including against the baseline commit.

## Cold launch time

| Device | Build | Runs | Average | Spread | Values (s) |
|---|---|---|---|---|---|
| iPhone 17 Pro simulator, iOS 26.5 | Debug | 5 | **0.858 s** | 2.9% relative std dev | 0.831, 0.847, 0.904, 0.850, 0.857 |

Source: `LaunchPerformanceTests.testColdLaunch` (`XCTApplicationLaunchMetric`).

**Re-measured after Release A's changes** (2026-11-10, branch `localization-release-a` at `c258391`, same simulator, clean install, Debug):

| Run | Runs | Average | Spread | Values (s) |
|---|---|---|---|---|
| 1 | 5 | **0.752 s** | 1.8% | 0.752, 0.778, 0.747, 0.742, 0.739 |
| 2 | 5 | **0.739 s** | 0.2% | 0.739, 0.738, 0.740, 0.736, 0.740 |

No slowdown: both runs are below the baseline's 0.858 s. I would not read the difference as a speed-up from this work; the baseline was taken hours earlier in a different state of the same Mac.

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

`pseudo-language-se-2026-11-10/` holds the five screens from the first such run (iPhone SE, 2026-11-10) that showed cut or overflowing text, before any fix. Placeholders and plurals look broken in every pseudo-language screenshot ("lld", "@", "#@value@"); that is how the system doubles format strings, not an app bug.

## The paywall with real prices (Release build)

`iphone-17-pro-priced/`, captured 2026-11-10 from branch `localization-release-a` in the one Release-build run Arthur approved: the paywall with the yearly plan selected, with the monthly plan selected, and the one-time offer. US storefront, fresh install, so a user with no purchase history.

These are the first pictures of these screens with products loaded; there is no earlier picture to compare them with. On that run the paywall offered no free trial for either plan (button "Continue", line "Billed immediately…", no badge), which may just be the simulator having no Apple ID, and the offer read 40% ($29.99 against $49.99).

The monthly-selected picture exists because that run tapped the plan rows, which sends `paywall_plan_selected` to production. The sweep no longer does that by default; see `selectsPlansOnThePaywall` in `OnboardingSweepTests.swift`.

To repeat it (it creates a guest user and sends production-tagged analytics, so only with Arthur's say-so):

```bash
xcodebuild build-for-testing -project Wingman.xcodeproj -scheme Wingman -configuration Release -destination 'platform=iOS Simulator,name=Wingman L10n 17 Pro' -skipMacroValidation -skipPackagePluginValidation ENABLE_TESTABILITY=YES
```

```bash
xcodebuild test-without-building -project Wingman.xcodeproj -scheme Wingman -configuration Release -destination 'platform=iOS Simulator,name=Wingman L10n 17 Pro' -only-testing:WingmanUITests/OnboardingSweepTests/testOnboardingToPaywall -resultBundlePath /tmp/wingman-release-sweep.xcresult ENABLE_TESTABILITY=YES
```

## Comparing a new run with these screenshots

`scripts/screenshots.py` pulls the numbered screenshots out of a test result and compares them with a folder here, pixel for pixel below the status bar:

```bash
python3 scripts/screenshots.py export /tmp/wingman-sweep.xcresult /tmp/wingman-sweep
```

```bash
python3 scripts/screenshots.py compare docs/localization-baseline/iphone-17-pro /tmp/wingman-sweep --only-numbered-to 17 --allow 14-loading-notification-prompt
```

Screen 14 is allowed to differ because the loading animation behind the system prompt is caught at a different frame from run to run. Screens 18 and later show content that changes between runs and are compared by eye.

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

## German content run (Release B, G7)

`german-content-se-2026-11-11/`, iPhone SE simulator, branch `localization-release-b`, 2026-11-11, after the German database rows went live. Source: `OnboardingSweepTests.testOnboardingAndContentInGerman`: the German onboarding walk, then a relaunch with the Debug-only `-forcePremium YES` and walks through lesson 1_1 and its quiz, today's Daily Practice and the "Bar Window" scenario played to the end. Screens 23 to 117, plus 20 (the scenario-list walkthrough card, now showing the German titles). Screens 01 to 19 and 21 to 22 are pixel-identical to `german-se-2026-11-11/` and are not repeated. Saved as 128-colour PNGs to keep the folder small; read them for layout, don't diff them.

The run created one guest user in production and recorded the lesson, the Daily Practice set and the scenario as completed for that user.

`german-content-se-2026-11-11-fixes/`: the same test re-run at about 23:00 the same day, after three layout fixes (lesson title strip, time-of-day greeting, lesson auto-scroll). Only the screens those fixes change are kept: 23 (Home, "Guten Abend,") and 30 to 44 (lesson intro and pages). Every other screen matched the earlier run, apart from the loading animation, the random quote and the German scenario titles. This run created one more guest user in production.
