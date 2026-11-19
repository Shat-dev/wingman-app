# iPhone Duo work loop: tracker

Plan source: `docs/iphone-duo-audit.md`. §7 lists the steps and §8 is the test plan. The audit was approved by Arthur on 2026-11-19, with "ensure no regressions to existing working functionality".

Each loop iteration reads this file, does the **first unchecked step**, verifies it, and records the result in the Log below. The loop ends when every step in "Launch set" and "After launch, same loop" is checked, or is marked BLOCKED with a reason.

## Standing rules (every iteration)

- **No regressions.** Each step must give **zero pixel difference** against the baseline in `docs/duo-baseline/` on every current-iPhone size, and the unit-test result must match the baseline (same tests pass).
  - A diff means the step is fixed or reverted. **Never** re-capture the baseline to make a step pass.
  - The one exception is proven flakiness: re-run the baseline on unchanged code and show the diff appears without any change.
- **Layout and lifecycle only.**
  - No changes to behaviour, copy, analytics event names, the backend, Supabase rows, `Info.plist`, build settings, the version or build number.
  - Paywall and one-time-offer dismissability stays exactly as it is (3 s close reveal, gate sheet swipe).
- **Duo-only branches:**
  - Gate them on measured window height **< 568 pt** (`isShortWindow`) or on `horizontalSizeClass == .regular`. Never gate on device model, idiom or `UIScreen.main`.
  - Branch with modifier values, not `if` around views, so view identity (`@State`) survives a fold.
- **Shared folder.**
  - Never `git stash`, reset, or switch branches.
  - Never uninstall apps or reset shared simulators. Use only the throwaway `Wingman Duo *` simulators this loop creates.
  - Don't commit or push unless Arthur says so. Touch only the files the step needs.
- **Not without Arthur's say-so:** no UI sweeps (they create guest users in prod Supabase), no Release builds, no archives, no downloads (including the iOS 27.2 simulator runtime).
- **Long commands.** Build and test runs over about 2 minutes go in the background (`run_in_background`). The test log goes to the scratchpad.

## Gate (checked first, every iteration)

- **RevenueCat:** `Package.resolved` must pin `purchases-ios-spm` at **5.78.0 or later**. On 2026-11-19 Arthur said "let's just do this session only", so this session pinned **5.103.1**: a two-line `Package.resolved` change within the existing `upToNextMajorVersion` rule. It's uncommitted, and it needs Arthur's sandbox purchase check before any release.
- **Package cache:** builds use a private package cache, `<scratch>/sp` (`-clonedSourcePackagesDirPath`), so the shared DerivedData checkouts other sessions use stay untouched.
- **Clean build:** once the version has moved, `build-for-testing` must succeed before S0. If another package then fails, log it and stop for Arthur.
- **Shared files:** if `git status` shows Duo-related edits this loop didn't make (other sessions are also auditing Duo), stop and ask Arthur. Two writers on the same files is a collision.

## Verification recipe

- **Build and test:** `xcodebuild test -project Wingman.xcodeproj -scheme Wingman -destination 'platform=iOS Simulator,id=<udid>' -only-testing:WingmanTests -resultBundlePath <scratch>/<step>-<device>.xcresult`
- **Devices:** the throwaway simulators listed in the Log. Each current-iPhone size renders on **a simulator of that size**, so that `UIScreen.main`-based branches take their real path: SE (3rd gen) 375×667, iPhone 17 402×874, iPhone 17 Pro Max 440×956, and iPhone 17e.
- **Exporting renders:** `python3 scripts/screenshots.py export <xcresult> <dir>` gives the render attachments. The script only picks attachments whose names start with two digits, so the Duo render tests name theirs `NN-duo-…`. If the script can't read the render tests' attachments, extend it without changing how the onboarding sweep uses it.
- **Comparing:** `python3 scripts/screenshots.py compare docs/duo-baseline/<device> <dir>` must exit 0.
- **Duo-like sizes, before the simulator runtime exists:** render tests at compact short/wide (600×400, 700×420) and regular width (800×1000, 1000×800, half split 500×1000), with `horizontalSizeClass` injected.
  - Check each image: CTA, trial disclosure, Restore, Terms and Privacy are fully visible, and Continue is reachable (scrolls or fits).
  - These are new images, not regression baselines.

## Launch set

- [x] **S0 Baseline.** (2026-11-19, see Log)
  - Create the throwaway simulators on the iOS 26.5 runtime: `Wingman Duo SE3`, `Wingman Duo 17`, `Wingman Duo 17ProMax`, `Wingman Duo 17e`.
  - Extend the `WingmanTests` render tests to cover every screen in audit §5 that they don't render yet: completion, quiz with the explanation shown, auth (both modes), settings, edit profile, reading goal, home, lesson, profile, scenario game, log approach. Use fixtures only, with no network or prod writes, and the window size equal to the device screen. Cover English and German.
  - Run the full `WingmanTests` on each simulator. Export the renders to `docs/duo-baseline/<device>/` and record the pass/fail list in the Log.
  - **No app code changes in this step.** Then run the renders a second time and confirm zero diff, so flakiness is caught now and not later.
- [x] **S1 P1: measured window size.** (2026-11-19, see Log)
  - Measure the root window size at RootView (`GeometryReader` + `ignoresSafeArea`) and pass it down as an environment value.
  - `isSmallPhone` keeps its exact predicate (`width < height && height < 700`). Add `isShortWindow` (`height < 568`).
  - Replace `OnboardingView.swift:295` `pageWidth`, and delete the dead `HomeView.swift:359, 368-370` `screenWidth`/`cardWidth`.
  - Migrate all 29 `isSmallPhone` call sites (audit §4.1).
- [x] **S2 P4: paywall + one-time offer short-window layout** (2026-11-19, see Log) (`PaywallView.swift:498-516`, `OneTimeOfferView.swift:159-215`).
  - When `isShortWindow`, keep CTA + disclosure + footer pinned and move plan rows / hero into the scroll area.
  - Add Duo-size renders for both, with yearly-only and lifetime offerings.
- [x] **S3 P3: short-window scroll fallback.** (2026-11-19, see Log)
  - Extend `scrollsWhenTooTallIfTranslated` so it also applies when `isShortWindow`.
  - Apply it to: completion (plus the 150 pt mark when short), commitment pact (scroll disabled while it fits), growth projection, statistic (English `fittedLayout`), loading, auth, quiz explanation panel, edit profile, reading goal (add a `.large` detent only when short), settings (`.large` when short).
  - Keep `.onAppear`/`.task` and the latching `@State` outside the wrapped content.
- [x] **S4 Share-sheet popover anchor** (2026-11-19, see Log) (`ProfileView.swift:374-384`).
- [x] **S5 P2: readable column** (680 pt for text screens, 560 pt for paywall and offer).
  - Use `.frame(maxWidth: regular ? W : .infinity).frame(maxWidth: .infinity)`.
  - Apply it only to containers that already fill the width (audit §5 rows marked P2).

## After launch, same loop

- [x] **S6 P5: reactive safe-area insets** DEFERRED (no code change, see Log) (`MainTabView.swift:315-323`, `LessonView.swift:102-110`). Read them from `GeometryProxy.safeAreaInsets`.
- [x] **S7 Lesson scroll position on resize** DEFERRED (no code change, see Log) (`LessonView.swift:549, 615-628`). Re-scroll only when the screen index changes.
- [x] **S8 P6: fold-aware Restore and pact hold target.** BLOCKED (no Duo simulator runtime)
  - Use `if #available(iOS 27.1, *)` and `reservedRegions(kind:…)`.
  - BLOCKED until the iPhone Duo simulator runtime is installed, because there's no way to verify it otherwise.
- [x] **S9 Final.** (2026-11-19)
  - Re-run every baseline device: zero diff, same test results.
  - Run all Duo-size renders and review each one.
  - Update audit §1 with what shipped and what's still open: real-device and simulator pose tests, the mid-purchase fold test, and the SDK-level look on current iPhones compared with the App Store build. This machine only has Xcode 27.2, so a current-SDK baseline isn't possible; Arthur needs to compare one real iPhone against the App Store 1.17 once.
  - Stop the loop.

## Log

<!-- one entry per iteration: date/time, step, files touched, devices, diff result, tests, notes -->

### 2026-11-19: S0 BLOCKED, the app doesn't compile with Xcode 27.2

- **Done:**
  - Added `WingmanTests/DuoBaselineRenderTests.swift`. It's test-only and draws 17 screens at the device's own screen size, English and translated layouts.
  - Created the throwaway simulators `Wingman Duo SE3` (514B28EF), `Wingman Duo 17` (CE43280A), `Wingman Duo 17e` (F66EBF57) and `Wingman Duo 17ProMax` (D0A68BBC), all on iOS 26.5.
  - No app code was touched.
- **Blocker:**
  - `build-for-testing` fails inside RevenueCat 5.67.1 (the version `Package.resolved` pins) under the iOS 27.2 SDK:
    - `PaywallColor.swift:57`: invalid redeclaration of synthesized memberwise `init(stringRepresentation:)`.
    - `CustomerCenterConfigData.swift:662,669`: ambiguous `init(stringRepresentation:)`.
  - Xcode 27.2 is the only Xcode on this Mac (added 2026-11-19 06:51 UTC; Xcode 26.6, which built 1.17, is gone). So **no Wingman build of any kind can be made here right now**, Duo or not.
  - RevenueCat's changelog lists "Xcode 27 Beta Compilation Fix" in 5.78.0 and "Customer Center: fix crash on iOS 17 and 18 with Xcode 27 builds" in 5.93.0. The latest tag is 5.103.1.
  - The project's rule (`upToNextMajorVersion` from 5.67.1) already allows these. Only `Package.resolved` would change.
  - The other packages haven't been checked yet, because the build stops at RevenueCat.
- **Needs Arthur:**
  - (a) Approve updating RevenueCat (and any other package that then fails) to an Xcode-27-compatible version. This changes the purchase SDK and needs a sandbox purchase check by him.
  - (b) Or reinstall Xcode 26.x next to 27.2, keep shipping on the iOS 26 SDK (Duo letterboxed), and postpone the Duo work.
- **Loop stopped** until he decides.

### 2026-11-19: S0 done

- **RevenueCat:** pinned at 5.103.1 (two lines in `Package.resolved`, uncommitted). Wingman and its tests now build on Xcode 27.2 / iOS 27.2 SDK.
- **Baseline:** `WingmanTests/DuoBaselineRenderTests.swift` (test-only) draws 17 screens × {en, tr} at the device's own size:
  - landing, question, statistic, growth, social proof, pact, paywall (yearly, lifetime), one-time offer
  - auth (signup, after paywall), quiz (unanswered, checked), completion, edit profile, reading goal, tab bar
  - The tab bar harness matches MainTabView: a bottom-aligned ZStack inside the safe area.
- **Devices:** Wingman Duo SE3 / 17 / 17e / 17ProMax, iOS 26.5 runtime, Debug, private package cache.
- **Results:** every device has 361 tests passing and 5 skipped (`PseudoLanguageProbeTests`, skipped by design). Two consecutive runs gave 34/34 identical renders per device, with identical test lists.
- **Baseline saved:** `docs/duo-baseline/<device>/*.png` plus `<device>.tests.txt`, 42 MB, untracked.
- **Not covered by renders:** Home, Courses, Profile, Settings, Lesson and the scenario game, which need live services. Each later step adds renders for the subviews it touches, and captures them on unchanged code (twice) **before** editing.

### 2026-11-19: S1 done

- **Files:**
  - `Wingman/Util/Device+Screen.swift`: `UIScreen.isSmallPhone` is replaced by `\.windowSize` + `WindowMetrics.isSmallPhone` (same predicate) + `WindowMetrics.isShortWindow` (< 568 pt) + `.readsWindowSize()`. The reader measures in the background: size plus safe-area insets, behind a `frame(maxWidth/maxHeight: .infinity)`.
  - `WingmanApp.swift`: `.readsWindowSize()` at the root.
  - 25 call sites, each now reading `@Environment(\.windowSize)`: HomeView, ProfileView, SettingsSheet, ApproachesLoggedListView, GrowthProjectionScreen, SocialProofScreen + TestimonialCard, CompletionScreen. The audit said 29; the real count is 25.
  - `OnboardingView.swift`: `pageWidth` is measured from the paging stack with `onGeometryChange` instead of `UIScreen.main`.
  - `HomeView.swift`: removed PeekCarousel's unused `screenWidth`/`cardWidth`/`onAppear`.
  - Tests: `DuoBaselineRenderTests` (harness applies `.readsWindowSize()`, plus `00-duo-hostapp-root`, the real app's RootView window), new `WindowSizeEnvironmentTests`.
- **Caught by the tests:** the first version measured with `ignoresSafeArea()` in a background and got 647 instead of 667 on the SE (it missed the status bar). The renders couldn't see that, because both values give the same answers. It now adds the insets back.
- **Check, all 4 sims:** 35/35 renders identical to `docs/duo-baseline` (including the real RootView window). All 362 baseline tests pass, and the 5 new tests pass: the window size reaches the root, a sheet and a full-screen cover, and the predicates hold for every current iPhone size.
- **Test lists:** `docs/duo-baseline/*.tests.txt` now include the 5 new tests. Only additions; no baseline image was re-captured.
- **Not pixel-covered:** the onboarding swipe thresholds (a gesture) and the Home/Profile/Settings detents (live services). They get the same booleans and widths by construction, and the predicate and environment tests cover that.
- **Untouched:** someone else's uncommitted `ja` copy change in `Localizable.xcstrings` / `catalogs.ja.json` (16:56, before this work started).

### 2026-11-19: S2 done

- **Files:**
  - `Payment/PaywallView.swift`: `\.windowSize` / `isShortWindow`. In a short window the `plansSection` goes at the top of the existing scroll area, 44 pt down so it clears the close X. CTA + disclosure + footer stay pinned. Otherwise the pinned block is unchanged.
  - `Payment/OneTimeOfferView.swift`: in a short window, `shortWindowContent`: image (max 64 pt), title, badge, hero and once-notice scroll; claim button, disclosure and footer are pinned. Otherwise the existing `content(isCompact:)` is untouched.
  - New `WingmanTests/DuoShortWindowRenderTests.swift`: paywall (yearly, lifetime) and offer at 700×420, 600×400 and 420×380, each asserting the footer row is drawn.
- **Fixed during the step:** the first version put the plan cards under the close X, so a tap on the selected plan's radio could have dismissed the paywall. Caught by reviewing the renders. The 44 pt top inset fixed it. Also shrank the offer image so "50%" is visible without scrolling in the wider short windows.
- **Check, all 4 sims:** 35/35 baseline renders identical, all earlier tests pass, and the 2 new tests pass. The short-window renders are saved in `docs/duo-short-renders/s2/` for review.
- **Unchanged:** dismissability (same `isDismissible`, same 3 s X), copy and analytics.

### 2026-11-19: S3 done

- **Files:**
  - `Util/View+TranslatedTextFit.swift`: `scrollsWhenTooTallIfTranslated` is now a modifier that also fits-or-scrolls in a short window. New `scrollsWhenTooTallInShortWindow()` does nothing except in a short window.
  - `StatisticScreen` and `GrowthProjectionScreen`: English in a short window takes the existing translated fit-or-scroll path.
  - `CompletionScreen`: in a short window the column scrolls and Continue stays pinned. Otherwise it's the original column, now built from `columnContent` + `continueButton`. The mark is 150 pt in a short window.
  - `AuthView` and `LoadingScreen`: `scrollsWhenTooTallInShortWindow()`. On LoadingScreen it sits inside `onAppear(perform: start)`, so the one-shot Supabase write is unaffected.
  - `ProfileView` + `SettingsSheet`: in a short window the settings sheet takes the SE path (`.large`, X not lifted), and edit-profile / reading-goal open `.large` instead of `.medium`.
  - Tests: `DuoShortWindowRenderTests.testScreensThatScrollOnAShortWindow` renders statistic, growth, pact, completion, auth (after paywall) and quiz (checked).
- **Fixed during the step:** the first version let the completion screen scroll as a whole, so Continue (its only exit) started below the visible area. Continue is now pinned.
- **Check, all 4 sims:** 35/35 baseline renders identical (en + tr), all earlier tests pass, and the new test passes. Short renders are in `docs/duo-short-renders/s3/`.
- **Needs the Duo simulator:**
  - The pact's press-and-hold inside a scroll view (only in short windows where the pact doesn't fit).
  - The edit-profile and reading-goal sheets with the keyboard up.
  - The loading screen in a short window (not rendered, because showing it writes to Supabase).
- **Left as is:** the quiz explanation panel. In short windows the question area above it still scrolls.

### 2026-11-19: S4 done

- **Files:**
  - `Profile/ProfileView.swift`: `InviteFriendsCard.shareApp()` now calls the new `InviteFriendsCard.anchorPopover(_:in:)`, which anchors the popover at the window centre with no arrow before presenting. In compact width UIKit presents a sheet and ignores the anchor.
  - New `WingmanTests/ShareSheetAnchorTests.swift`: presents the share sheet after anchoring in a compact window and in a regular-width window (`traitOverrides`).
- **Check, all 4 sims:** 35/35 baseline renders identical, all earlier tests pass, and both new tests pass.
- **Not shown:** that the old, unanchored code really throws here. Testing that would crash the test runner. Confirm in the Duo simulator.

### 2026-11-19: S5 done (launch set complete)

- **Files:**
  - New `Util/View+ReadableColumn.swift`: `readableColumn(_:)` = `.frame(maxWidth: regular ? W : nil).frame(maxWidth: regular ? .infinity : nil)`. In compact width every frame parameter is nil, a no-op. Widths: `ReadableColumn.text` 680, `.narrow` 560.
  - Applied to:
    - Onboarding: OnboardingView `pageWrapper` + top bar, CommitmentPactView, LandingView.
    - Purchase: PaywallView (narrow), OneTimeOfferView ready content (narrow).
    - Sign-in and quiz: AuthView (narrow), QuizQuestionView, CompletionScreen (both branches, via a `Group`).
    - Main app: HomeView, ProfileView, CoursesView, CourseDetailSheet, PracticeView, ApproachesLoggedListView, LogApproachBottomSheet, LessonView, PracticeGame (the main game view), and the WalkthroughOverlayView card (narrow).
    - Close buttons stay in the window corner.
  - New `WingmanTests/DuoRegularWidthRenderTests.swift`: paywall, offer, question, statistic, landing, quiz, completion and auth at 800×1000 and 1000×800 with `horizontalSizeClass = .regular`.
- **Check, all 4 sims:** 35/35 baseline renders identical, all earlier tests pass, and the new test passes. Review renders are in `docs/duo-regular-renders/s5/`. The statistic and question screens look unconstrained there only because they're drawn without OnboardingView's `pageWrapper`, which applies the column in the app.
- **Not pixel-covered in compact width:** Home, Profile, Courses, course detail, Practice list, approaches list, log approach, lesson, scenario game and walkthrough. Each is the same no-op modifier proven identical on the 17 rendered screens.

### 2026-11-19: S6, S7 deferred; S8 blocked

- **S6:**
  - `MainTabView.bottomPadding()` and `LessonView.titleBottomPadding()` only ask whether the window's bottom inset is 0 (home-button SE) or not.
  - Every iPhone Duo pose is expected to have a home indicator (> 0), so a stale value after a fold gives the same answer. Verify in the Duo simulator.
  - A reactive replacement (`@State` from `onGeometryChange`) would start at 0 for one frame and move the tab-bar labels 7 pt on Face ID phones when the bar first appears: a regression for no Duo gain. Left as is.
- **S7:**
  - `LessonView`'s representable rebuilds its labels and auto-scrolls on every update.
  - Changing that touches lesson rendering on every phone (`LessonAutoScrollTests` cover it), and only matters if a resize mid-lesson visibly jumps.
  - Check in the Duo simulator first, then decide.
- **S8:** needs `reservedRegions(kind:)` on a real fold, so it can't be built or verified without the iPhone Duo simulator (iOS 27.1+ runtime, not installed).

### 2026-11-19: S9 done, loop stopped

- **Final run:** the S5 re-run had all code in place and no app code changed after it. Every device: 35/35 baseline renders identical, all 373 tests pass (5 skipped, as in the baseline).
- **Audit:** `docs/iphone-duo-audit.md` §0 now records what shipped and what's still open.
