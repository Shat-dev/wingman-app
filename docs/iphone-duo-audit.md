# iPhone Duo readiness audit: Wingman

**Date:** 2026-11-19. **Branch:** `Shat` at `d2e1d91`. **Scope:** audit only. No code, build settings, or version were changed.

**Method:** I ran Xcode's `app-resizability` skill: its prerequisite checks, then detection for all five of its tasks (UIScreen.main, orientation, scene lifecycle, safe area, idiom). I also read all 142 Swift files under `Wingman/` (two read-only passes, with the serious findings spot-checked against the code), `Wingman/Info.plist`, the build settings in `Wingman.xcodeproj/project.pbxproj`, the resolved SPM packages, and `Wingman/Assets.xcassets`.

**Simulator:** I didn't test anything on the iPhone Duo simulator. Xcode 27.2 is installed and has the iPhone Duo device type, but that device needs a 27.1+ simulator runtime (`minRuntimeVersion = 27.1` in its profile), and only the iOS 26.5 runtime is installed. Every Duo behaviour below is therefore **predicted from the code**. Installing the iOS 27.2 simulator runtime (Xcode → Settings → Components, several GB) is step 0 of the test plan.

---

## 0. Status (2026-11-19, end of the work loop)

**Done and verified, all uncommitted on `Shat`.** The step-by-step record is in `docs/iphone-duo-loop.md`.

| Step | What | Verified |
|---|---|---|
| Build | RevenueCat 5.67.1 → **5.103.1** (`Package.resolved` only). 5.67.1 doesn't compile on Xcode 27.2, now the only Xcode on this Mac. | Builds on Xcode 27.2 / iOS 27.2 SDK; all tests pass. **Needs a sandbox purchase by Arthur before release.** |
| S0 | Baseline: 17 screens × en/tr + the real RootView window on SE 3, 17, 17e, 17 Pro Max (`docs/duo-baseline/`) | Two runs, 35/35 identical; 361 tests pass |
| S1 | `UIScreen.main` / `isSmallPhone` → measured `\.windowSize`, same predicate | 35/35 identical; tests show the size reaches the root, sheets and full-screen covers |
| S2 | Paywall + one-time offer: CTA, disclosure and Privacy/Restore/Terms pinned in short windows | 35/35 identical; footer drawn at 700×420, 600×400, 420×380 |
| S3 | Short-window scroll fallback: statistic, growth, pact, completion (Continue pinned), auth, loading, settings/edit-profile/reading-goal sheets | 35/35 identical |
| S4 | Invite Friends share-sheet popover anchor (B5) | 35/35 identical; presents in compact and regular windows |
| S5 | Readable centred columns (680 / 560 pt) in regular width on every screen in §5 | 35/35 identical; regular-width review renders in `docs/duo-regular-renders/s5/` |
| S6, S7 | Reactive inset reads; lesson scroll on resize | **Deferred:** no Duo benefit shown, real regression risk (see loop log) |
| S8 | Fold-aware Restore / pact hold target (`ReservedRegion`) | **Blocked:** needs the iPhone Duo simulator (iOS 27.1+ runtime, not installed) |

"Identical" means pixel-identical renders and the same test results compared with the baseline, on all four current-iPhone simulators, in English and in the translated layout.

**Still open before calling Duo support shipped:**
1. *(Mostly done 2026-11-19: live walk-through on the Duo simulator covered onboarding, paywall, walkthrough, tabs, the share sheet and Log Approach in both poses, with the fold mid-flow. Only paywall-gated content and the mid-purchase fold remain. See the loop log.)* Earlier: *(Partly done 2026-11-19: runtime installed; outer display measured at 466×678, inner at 951×669 landscape. Landing checked live in every pose, and all 17 rendered screens checked closed and open. See the loop log.)* Remaining on the iPhone Duo simulator:
   - Run the §8 pose walk-through.
   - Fold mid-purchase and mid-lesson.
   - Check the pact press-and-hold in a short window and the share sheet on the inner display.
   - Measure the real outer-display height, which decides how often the short-window paths run.
2. One check on a real current iPhone against App Store 1.17. The iOS 27 SDK itself (separate from these changes) could change system UI, and this Mac can no longer build on the iOS 26 SDK to compare.
3. A sandbox purchase on the RevenueCat 5.103.1 build.
4. Commit when happy. Nothing is committed. Another session's uncommitted Japanese copy change in `Localizable.xcstrings` / `localization/ja/catalogs.ja.json` is mixed into the working tree and isn't part of this work.

## 1. Summary

Wingman is in better shape than most iPhone-only apps.

- It's pure SwiftUI on a `WindowGroup`, so it already uses the scene lifecycle.
- No layout depends on the device idiom or on a device model.
- Only three places use `UIScreen.main`.
- Routing depends only on auth and subscription state, never on size.
- Lesson position, scenario branch, the onboarding step, paywall purchase state and the log-approach draft are all held in `@State` or `@StateObject`. They survive a resize because nothing swaps view identity based on size, with one exception: the translated-build `ViewThatFits` paths, covered in §5.

**Fold/unfold therefore shouldn't lose anyone's progress.**

The real exposure is in three areas:

1. **Short windows.** Apple says the outer display is "wider and shorter than the display on other iPhone devices". Several English screens have no scroll fallback: the paywall's pinned block, the one-time offer, the completion screen, the commitment pact, and growth projection. On a short enough window their bottom content (CTA, trial terms, Restore, Continue) can be clipped. This is the only class of issue that can break purchases.
2. **Wide windows.** On the regular-width inner display, nothing has a `maxWidth`. Every card, button and paragraph stretches edge to edge. It isn't broken, but it is off-brand, and it puts centred controls (Restore, the pact hold target) on the fold line.
3. **One likely crash.** The Invite Friends share sheet is presented with no popover anchor. In a regular-width window that probably throws.

**The live app isn't affected today.** 1.17 (41) was archived with Xcode 26.6 and the iOS 26.5 SDK (`DTSDKName = iphoneos26.5`). Per Apple's SDK table, an app built on iOS 26 or earlier "runs, but doesn't adapt": letterboxed on the inner display, pushed beside the status bar on the outer. Nothing above happens until the app is built with the iOS 27 SDK. This Mac now has Xcode 27.2, so **the next archive turns all of this on**. That SDK bump is the event to plan around, and it's also the main regression risk for existing iPhones (§3).

### Recommendation: the minimum set to ship for launch

Do these before (or in the same build as) the first iOS 27 SDK archive:

1. **Get a baseline before anything else.** Capture render and sweep baselines on the current SDK, then make the SDK bump alone and diff against them (§8). This is the only way to prove "pure upside" for the SDK change itself.
2. **Make the paywall and one-time offer safe on short windows.** When a window is shorter than any current iPhone, the CTA, trial disclosure and footer (Restore / Terms / Privacy) must stay pinned and visible, and everything else scrolls. Gate this on window height below 568pt so it can't run on any current iPhone. *(Critical.)*
3. **Anchor the share sheet's popover.** *(Breaks: likely crash on the inner display.)*
4. **Add a short-window scroll fallback** to the completion screen, commitment pact, growth projection, statistic screens, loading screen, auth screen and quiz explanation panel. English is untouched on every current iPhone. *(Breaks: Continue can't be reached, and it's the only exit.)*
5. **Replace `UIScreen.main` / `isSmallPhone`** with the measured window size, keeping the predicate identical on every current iPhone. *(Prerequisite for 2 and 4, and correct on resize.)*

**These can wait until after launch:**
- Readable-width columns on the inner display (looks bad, doesn't break).
- Moving Restore and the pact hold target off the fold with `ReservedRegion`.
- Adopting system tab bars so they go vertical.
- Any two-column `ArrangementView` / `NavigationSplitView` layout.

---

## 2. Apple ground truth (corrections to the brief)

Sources: [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [Designing for iPhone Duo (HIG)](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [Three steps to make your app shine on iPhone Duo](https://developer.apple.com/iphone-duo/prepare/), and the Xcode 27.2 iPhone Duo simulator profile.

| Brief said | What Apple says |
|---|---|
| Outer = compact width, inner = regular width | **Confirmed.** Apple adds: "Don't treat `horizontalSizeClass == .regular` as iPad. iPhone can now be regular width." |
| Size changes at runtime, size is a range | **Confirmed.** Apple adds that split-screen multitasking runs on the inner display. |
| Inner display ignores supported orientations | **Not stated** on any of the three pages. The HIG says games "can choose to lock to either portrait or landscape orientation, but be sure to fill the screen as the device pose changes", which suggests locks may still be honoured. **Unconfirmed: verify in the simulator.** Plan as if every pose happens. |
| Reserved regions for fold and camera, asymmetric safe areas | **Confirmed.** The outer front camera is *always* a reserved region. The inner camera is one only while active. The fold is one only when partially open. The SwiftUI API is `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, which returns `[ReservedRegion]`. System sheets, alerts and context menus move away from the fold automatically; custom views don't. |
| Only iOS 27.1 SDK builds get the full screen; older builds letterboxed | **Three tiers, not two.** iOS 26 SDK or earlier: letterboxed / beside the status bar. iOS 27 SDK: "resizes to fill most of the inner display but still avoids the status bar on the right edge". iOS 27.1+ SDK: edge to edge, with toolbars and tab bars vertical. Apps built with the iOS 27 SDK or later "resize dynamically". |
| Use size classes, not idiom; no `UIScreen.main.bounds` | **Confirmed.** Use `GeometryReader` / `onGeometryChange`. Also don't base layout on orientation or on specific device sizes. |
| *(not in brief)* | **Vertical bars.** On the outer display, and in landscape on the inner display, the system moves navigation bars, toolbars and tab bars to the side. This only applies to bars that come from `NavigationStack` / `TabView` / `.toolbar`. Custom-drawn bars stay where the app draws them. Wingman hides every system bar and draws its own (§4.6). |
| *(not in brief)* | **`ArrangementView`** (split / overlay) is new and maps directly onto HStack/VStack/ZStack layouts. Apple: keep navigation outside it. |
| *(not in brief)* | **App Store.** iPhone Duo screenshots earn an iPhone Duo badge. Featuring nominations can say "optimized for iPhone Duo, including support for all device poses". |

**Not known from the docs:** the outer and inner display sizes in points (the simulator profile doesn't contain them). Every "short window" finding below assumes the outer display, or a partially folded half, can be shorter than an iPhone SE's 667pt. Measure it in the simulator first. If the outer display turns out to be taller than about 600pt, most of the short-window findings drop to polish.

---

## 3. Blockers

| # | Blocker | Severity | Where |
|---|---|---|---|
| B1 | **The iOS 27 SDK bump is unproven on current iPhones.** Linked-on-or-after behaviour changes apply to every device, not just Duo. A layout audit can't guarantee this; only a before/after render diff can. | **RISK** | Build settings (`LastUpgradeCheck = 2660`, archives on SDK 26.5) |
| B2 | **Paywall: in a short window the pinned purchase block can clip Terms/Restore and squeeze the carousel to zero.** Plans + CTA + disclosure + footer total about 390pt, sit in a plain `VStack` outside the `ScrollView`, and have no `safeAreaInset`. | Breaks (purchase) | `Payment/PaywallView.swift:498-516` (pinned), `:348-465` (scroll area), `:805-812` (disclosure), `:987-1008` (footer) |
| B3 | **One-time offer has no `ScrollView` at all.** At about 480pt or more, its disclosure and Terms/Restore clip in a short window. | Breaks (purchase) | `Payment/OneTimeOfferView.swift:159-215` |
| B4 | **Completion screen can't fit a short window.** It's a fixed `VStack` of about 560pt with a 220pt mark. Continue is the only exit, and it's what marks the lesson complete and triggers the rating ask. | Breaks | `XP/CompletionScreen.swift:206-208, 231-302`; `Lesson/LessonView.swift:256, 289` |
| B5 | **The Invite Friends share sheet has no popover anchor.** `UIActivityViewController` is presented from `connectedScenes.first…rootViewController` with no `sourceView`. In regular width it presents as a popover, so this is likely an exception. | Breaks (likely crash; verify) | `Profile/ProfileView.swift:374-384` |
| B6 | **The device simulator can't run yet.** The iOS 27.x simulator runtime isn't installed. | Process | (environment) |

---

## 4. Phase 1: Inventory

### 4.0 Skill prerequisite checks (read-only)

| Check | Result |
|---|---|
| Launch screen | ✅ `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (`project.pbxproj:488, 527`). No `ITMS-90870` risk. |
| iPad orientations | n/a. `TARGETED_DEVICE_FAMILY = 1` (iPhone only, `:507, :546` and the test targets). There's no `~ipad` key. The plain declaration lists only `UIInterfaceOrientationPortrait` (`:490, :529`). The skill didn't look for `supportedInterfaceOrientations` overrides (a grep finds none). |
| Full-screen opt-out | ✅ `UIRequiresFullScreen` is absent from `Info.plist` and the build settings. |
| Scene lifecycle | ✅ Already scene-based: SwiftUI `App` + `WindowGroup` + `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES`. The `@UIApplicationDelegateAdaptor` AppDelegate (`WingmanApp.swift:22-49`) only starts the Facebook SDK and sets the notification delegate. It owns no window, so the skill's migration task doesn't apply. |

There are no `.xcconfig` files, so the project file is the only source of build settings.

### 4.1 `UIScreen.main`, hardcoded sizes, idiom/model checks, cached sizes

| Finding | file:line | Notes |
|---|---|---|
| `UIScreen.isSmallPhone` reads `UIScreen.main.bounds`, with predicate `width < height && height < 700` | `Util/Device+Screen.swift:18-21` | It's a static computed var read during `body`. It isn't reactive (a resize doesn't re-run the bodies that read it). On Duo it returns `false` in any wider-than-tall window, so the **shortest** windows get the **tallest** layout. It has 29 call sites (below). |
| `isSmallPhone` call sites | `Home/HomeView.swift:323`; `Profile/ApproachesLoggedListView.swift:186`; `Profile/ProfileView.swift:176`; `Profile/SettingsSheet.swift:92`; `Onboarding/Screens/SocialProofScreen.swift:72,75,91,92,117,118,133,141,145,152,179,182,185,192,194,195`; `Onboarding/Screens/GrowthProjectionScreen.swift:130,147,150,159`; `XP/CompletionScreen.swift:207` | Spacing, font sizes, sheet detents, the completion mark size. |
| `pageWidth = UIScreen.main.bounds.width` | `Onboarding/OnboardingView.swift:295` | Drives the swipe-back parallax (98), the rubber band (344), the 30%/60% thresholds (351-352) and the commit slide-off (393). The comment at 288-294 says it relies on the portrait lock. |
| `@State screenWidth = UIScreen.main.bounds.width` | `Home/HomeView.swift:359` | Only feeds `cardWidth` (368-370), which nothing reads. Layout already uses the live `GeometryReader` (385-400). It's dead, but still a `UIScreen.main` reference. |
| Device-idiom / model / orientation API checks | none | No `userInterfaceIdiom`, `UIDevice`, `interfaceOrientation`, `statusBarOrientation` or `utsname`. |
| Sizes cached in singletons / `@AppStorage` | none | — |
| Settings sheet fixed detent `.height(720/800 + 36)` | `Profile/ProfileView.swift:176-179` | Taller than a short window. It survives because of `ScrollIfTooTall` (`SettingsSheet.swift:850-861`). |
| Fixed heights that add up to a tall-screen layout | `XP/CompletionScreen.swift:206-208` (220 mark), `Commitment/CommitmentPactView.swift:200,208` (132 ring), `Onboarding/Components/GrowthChartView.swift:138,269` (min 170), `Onboarding/Screens/StatisticScreen.swift:205` (image min 120), `Home/HomeView.swift:180,379,476,594`, `Courses/CoursesView.swift:370,409` | Fine on their own. They only matter on screens without a scroll fallback. |
| Fixed trailing pads mirroring the back button | `Onboarding/Components/OnboardingTopBar.swift:40` (59), `Lesson/LessonView.swift:148` (59), `PracticeGame/PracticeGame.swift:380` (44) | Harmless. |

### 4.2 Orientation assumptions

- Portrait only: `INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait` (`project.pbxproj:490, 529`). The shipped 1.17 Info.plist confirms it.
- The `width < height` guard in `isSmallPhone` (`Device+Screen.swift:13-20`) is an orientation proxy.
- The `pageWidth` comment (`OnboardingView.swift:288-294`) explicitly depends on the portrait lock.
- **Recommendation:** keep the plist key as it is. Whether the inner display honours it is unconfirmed (§2), and the iOS 27 SDK may resize regardless. Every fix below is written so it doesn't care about orientation.

### 4.3 Layouts that stretch at regular width

- **There are no `maxWidth` constraints anywhere in the app** except `GrowthChartView.swift:375` (108pt). Everything full width stretches to the inner display's width.
- **Buttons:**
  - Onboarding Next/Continue: `QuestionScreen.swift:146`, LandingView (83, 113).
  - Paywall CTA and plan rows: `PaywallView.swift:738, 925`.
  - Auth: `AuthView.swift:368`.
  - Quiz options: `QuizQuestionView.swift:106,146`.
  - Home: `HomeView.swift:134,167,216`.
- **Text:**
  - Lesson paragraphs are `UILabel`s at full width minus 20 (`Lesson/LessonView.swift:566, 588-589`), which means very long lines.
  - Home quote: `HomeView.swift:239-243`.
- **Cards:**
  - Home Continue card (593).
  - PeekCarousel cards (`width − 72`, about 670pt wide × 430 tall, `HomeView.swift:379`).
  - Practice cards (`PracticeCardView.swift:65`).
  - Profile cards.
  - Walkthrough card (`Walkthrough/WalkthroughOverlayView.swift:46-48`).
  - Approaches list rows (`ApproachesLoggedListView.swift:256-265`, where the Spacers push date and level far apart).
- **Grids:**
  - Courses 2-column flexible grid (`Courses/CoursesView.swift:337-340`). Even column count, which is Apple's advice for the fold.
  - Profile 3 stat tiles (`ProfileStatsHeader.swift:167-174`), which puts the middle tile on the fold.

### 4.4 Content that could sit under the fold or a camera region

There are two cases: a vertical fold at x = width/2, when the inner display is partly folded like a book, and a camera region on the outer display's corner and side.

| Element | file:line | Concern |
|---|---|---|
| Paywall / one-time offer **Restore** (centre slot of `FooterLinksRow`) | `Payment/FooterLinksRow.swift:64-70`; `PaywallView.swift:987-1008`; `OneTimeOfferView.swift:303-308` | Lands on the crease. The brief requires Restore to be "fully visible and tappable in every pose". |
| Commitment pact hold target, logo centred | `Commitment/CommitmentPactView.swift:147-149` | A long press right on the crease. |
| Tap-to-advance halves split at width/2 | `Lesson/LessonView.swift:669`; `PracticeGame/PracticeGame.swift:533,577,583`; `Onboarding/Screens/StatisticScreen.swift:63-82,115` | The boundary sits on the fold. Each half stays tappable away from it, and "left page back / right page forward" reads naturally, so this is **polish, not a defect**. |
| Custom tab bar, 4 equal buttons | `Home/MainTabView.swift:231-262, 355` | The fold falls between Courses and Scenarios. That's clean. |
| Home carousel page dots, centred | `Home/HomeView.swift:439-445` | Small, but on the crease. |
| Outer front camera (always reserved) | — | Wingman keeps the system status bar and has no edge-to-edge interactive content. The `ignoresSafeArea()` calls are on backgrounds and scrims, except the custom log-approach sheet (`LogApproach/LogApproachBottomSheet.swift:32, 454`) and the walkthrough scrim (`WalkthroughOverlayView.swift:72`), which need a simulator check. |

### 4.5 State that could be lost on fold/unfold

Resizing keeps the same scene, and SwiftUI keeps `@State` unless view identity changes. Nothing in RootView's routing depends on size (`WingmanApp.swift:168-382`), so:

| State | Held in | Survives a resize? |
|---|---|---|
| Onboarding step + history | `@State screen/history` (`OnboardingView.swift:30-32`). Answers are in `@StateObject OnboardingAnswerStore` → UserDefaults (85). | ✅ (not persisted across a relaunch, same as today) |
| Paywall purchase in flight | `@StateObject PaywallViewModel` (`PaywallView.swift:37, 249`), `@Published isPurchasing` (`PaywallViewModel.swift:46`) | ✅ |
| One-time offer | `@StateObject` plus a static preloaded instance (`OneTimeOfferViewModel.swift:213-230`) | ✅ |
| Lesson position | `@State` (`LessonView.swift:17-18`); `.id` is keyed to the screen index, not geometry (170) | ✅, but **scroll position jumps**: `updateUIView` rebuilds every label on each update, including a resize (549, 615-628) |
| Scenario branch | `@StateObject`, `currentSceneId` (`PracticeGame.swift:27, 331-339`), persisted to Supabase on each step (234-245) | ✅ |
| Daily practice run | `@StateObject DailyPracticeViewModel` (`DailyPracticeView.swift:13,33`) | ✅ |
| Log-approach draft text | `@StateObject LogApproachViewModel` (`LogApproachViewModel.swift:13-16`) | ✅. Note `onAppear` → `resetForm()` (`LogApproachBottomSheet.swift:353-360`) would wipe the draft *if* `onAppear` ever re-fired. A resize doesn't re-fire it. |
| Walkthrough step | `@StateObject` coordinator (`MainTabView.swift:32`) | ✅ |
| **Translated builds only:** `ViewThatFits` subtrees | `Util/View+TranslatedTextFit.swift:98-118` (`scrollsWhenTooTallIfTranslated`), `StatisticScreen.swift:25-39`, `PracticeGame.swift:727`, `SettingsSheet.swift:850-861` | ⚠️ A fold that crosses the fit threshold swaps branches, which **resets child state and re-fires child `onAppear`**. The known effects are cosmetic: `TapToContinueButton.isVisible` replays its fade, and the Settings scroll position resets. Keep this in mind for the new fallback (§7, P3). |
| Side effects in `onAppear` | All latched by flags: `didLogOnboardingStart` (36), LoadingScreen `hasStarted` (98, 205; this guards the Supabase write and the notification prompt), `didLogPaywallView` (97), CompletionScreen `hasRunIntro` (440-442), lesson/quiz/scenario start events | ✅ for a resize. `commitmentPactViewed` (`CommitmentPactView.swift:176-185`) isn't latched, but resizing doesn't re-fire `onAppear`. |
| App lifecycle notifications | `willEnterForeground` refreshes the subscription; `didBecomeActive` drains the XP outbox (`WingmanApp.swift:95-106`) | Both are idempotent. **Unknown:** whether a fold sends the scene through inactive. Test this mid-purchase (§8). |

### 4.6 Navigation structure

- **Root:** RootView switches between `NavigationStack`s (onboarding, auth, paywall; `WingmanApp.swift:227-379`) and `MainTabView`.
- **Tabs:** a system `TabView` (`MainTabView.swift:42-69`) with `.toolbar(.hidden, for: .tabBar)` on every root, plus a hand-drawn `CustomTabBar` at the bottom (73, 231-262).
  - **So no Wingman bar ever goes vertical on Duo.** It stays at the bottom and full width, and on a short outer display it takes a bigger share of the height.
  - Unverified: whether iOS's regular-width tab style (top bar / sidebar) still respects `.toolbar(.hidden, for: .tabBar)` on the inner display. Check this in the simulator.
- **Per tab:** each tab owns a `NavigationStack` (Home 74, Courses 46, Scenarios/Practice 31, Profile 37). Navigation bars are hidden in favour of custom chevrons (onboarding 163, pact 175, CourseDetailSheet 46-61, LessonView top bar).
- **Presentations:**
  - `.sheet`: log approach, settings, edit profile, reading goal, create account, Safari, and the feature-gate paywall (`SubscriptionGateModifier.swift:60-72`).
  - `.fullScreenCover`: lesson quiz flow (`LessonView.swift:208`), game complete (`PracticeGame.swift:451`), approaches list (`ProfileView.swift:217`), one-time offer over the paywall (`PaywallView.swift:646`).
  - In regular width, a plain `.sheet` becomes a centred form sheet that the system moves away from the fold. That's free and good.
- **`NavigationSplitView` candidates:** Courses → course detail → lesson, and Scenarios list → scenario. Both are the "list + detail" shape Apple shows for Mail and Notes. **Not for launch** (§7, P8).
- **Window lookups through `connectedScenes`:**
  - `MainTabView.swift:315-323` and `LessonView.swift:102-110` read the key window's `safeAreaInsets` (not reactive).
  - `AuthManager.swift:2448, 3048` anchor Google and Apple sign-in to `connectedScenes.first`.
  - `ProfileView.swift:380` anchors the share sheet the same way.
  - `ReviewPromptManager.swift:256-260` uses the foreground-active scene, which is Duo-safe.
  - Wingman is single-scene, so `.first` is correct today. Only the share sheet is a launch issue.

### 4.7 Third-party SDKs

| Package | Resolved | Draws UI in Wingman? | Duo notes |
|---|---|---|---|
| RevenueCat (`purchases-ios-spm`) | 5.67.1 | No. The paywall is custom. `RevenueCatUI` is imported in `WingmanApp.swift:13` but no RevenueCatUI view is used. | No `UIScreen.main` in its shipped sources (3 hits, all in its tests). The purchase confirmation is StoreKit's own system sheet. |
| PostHog (`posthog-ios`) | 3.57.0 | Session replay in screenshot mode (`WingmanApp.swift:475-517`) | One `UIScreen.main.bounds` in `Surveys/SurveySheet.swift:155` (surveys aren't used). Replays will record resizes, which is fine. |
| Supabase (`supabase-swift`) | 2.38.1 | No | No UI. |
| Facebook (`facebook-ios-sdk`) | 18.1.0 | Login/app links only | 8 files use `UIScreen.main`, for device metrics in app events, not layout. |
| GoogleSignIn | 9.1.0 | Sign-in web sheet | 6 files use `UIScreen.main`. The sign-in UI is a system web-auth sheet anchored to our root view controller. |

**I haven't checked any vendor's own iOS 27 / iPhone Duo release notes.** Before the SDK bump, read RevenueCat's, PostHog's and Google's iOS 27 notes and take any patch release they recommend. No current package needs to change for layout reasons.

### 4.8 Assets

- **No video, Lottie, Rive or GIF.** The growth chart is hand-drawn (`GrowthChartView.swift:10`).
- Images are square, 2048–2100px (scenario art, course art, onboarding art) and almost all `scaledToFit`. On wide windows they letterbox inside their frames instead of cropping.
- The only `scaledToFill` is the pact logo, inside a fixed 108pt circle (`CommitmentPactView.swift:213-215`), which is fine.
- No asset assumes a portrait phone aspect ratio. **Nothing to do.**

---

## 5. Phase 2: Screen by screen

Key:
- **Outer:** Duo closed. Compact width, wider than tall, shorter than any current iPhone.
- **Inner:** open. Regular width, possibly any orientation.
- **Split:** inner display shared with another app. Width varies, height is full.
- **Severity:** Breaks / Looks bad / Polish.
- **Guarantee:** why existing iPhones (SE 2/3 → 17 Pro Max, portrait, including Display Zoom) render identically. The patterns P1–P8 are defined in §7.

All behaviour is **predicted** (no runtime).

| Screen | Outer | Inner / split | Issue · severity · file:line | Proposed fix | Regression guarantee on current iPhones |
|---|---|---|---|---|---|
| **Splash** | OK | Centred logo; OK | none (`Splash/SplashView.swift:30`) | — | — |
| **Landing** | Fits (the image shrinks between spacers) | Buttons span the full width and cross the fold | Looks bad · `Landing/LandingView.swift:39,83,113` | P2 readable column | P2 is a no-op at compact width (§7) |
| **Onboarding container / swipe-back** | Thresholds use the screen width, not the window | Same; wrong if Duo's `UIScreen.main` ≠ the window | Looks bad (gesture feel) · `Onboarding/OnboardingView.swift:295` | P1: replace `pageWidth` with the measured window width | Window width = screen width for a portrait full-screen app, so identical numbers |
| **Question screens** | ✅ ScrollView + pinned Next | Full-width Next | Looks bad · `Onboarding/Screens/QuestionScreen.swift:56-64,146` | P2 | P2 no-op |
| **Statistic screens (EN)** | **Clips** "Tap to continue": English always uses `fittedLayout` with no scroll | Stretches; the tap halves split at the fold | Breaks (outer) · `Onboarding/Screens/StatisticScreen.swift:22-23,52,205`; Polish · `:63-82,115` | P3 short-window fallback; P2 | P3 only activates below 568pt height, and English stays `fittedLayout` on every current iPhone |
| **Growth projection (EN)** | **Clips** Continue: chart min 170 + text + button ≈ 500pt+, no scroll | Chart stretches (proportional, fine) | Breaks (outer) · `Onboarding/Screens/GrowthProjectionScreen.swift:79-80`; `GrowthChartView.swift:138,250-269` | P3; P1 for `isSmallPhone` | P3 gated below 568pt; P1 keeps the predicate identical |
| **Loading** | Borderline (≈360pt); the consent overlay may cover the quote | OK | Looks bad · `Onboarding/Screens/LoadingScreen.swift:119-155` | P3 | P3 gated. `hasStarted` lives on the screen, so the Supabase write can't re-fire if P3 swaps a child subtree. Keep `.onAppear` outside the wrapped content. |
| **Social proof** | ✅ ScrollView + pinned Continue | Stretches | Looks bad · `SocialProofScreen.swift:71,95`; 16 `isSmallPhone` uses | P1, P2 | P1 identical predicate; P2 no-op |
| **Commitment pact (EN)** | **Clips** ≈550pt stack (`scrollsWhenTooTallIfTranslated` is a no-op in English) | Hold target centred on the fold | Breaks (outer) · `Commitment/CommitmentPactView.swift:117,142,171,200-208`; Looks bad/RISK to completion · `:147-149` | P3 (with scroll *disabled* while it fits, so the hold gesture isn't delayed); P6 for the fold | P3 gated below 568pt. P6 only runs while an active fold region exists, which never happens on current iPhones. |
| **Paywall (onboarding, post-demo, feature gate)** | **CTA block ≈390pt pinned; carousel squeezed to 0; footer (Restore/Terms) can clip** | Plan rows/CTA stretch; Restore centred on the fold. The feature gate becomes a centred form sheet (good). | **Breaks, critical** · `Payment/PaywallView.swift:498-516, 348-465, 805-812, 987-1008`; `FooterLinksRow.swift:64-70` | P4 (paywall short-window layout); P2 column (max about 560pt); P6 for Restore on the fold | P4 gated below 568pt height. The current pinned VStack is what renders at ≥ 568pt, which is every current iPhone, including the SE with Display Zoom (568pt). P2 is a no-op at compact width. |
| **One-time offer** | **No ScrollView; disclosure + Terms/Restore clip** | Stretches; Restore on the fold | **Breaks, critical** · `Payment/OneTimeOfferView.swift:64-65,159-215,303-308` | P4 (pin CTA + disclosure + footer, scroll the rest, below 568pt); P2; P6 | Same as the paywall. The existing `isCompact` (`height < 700`) path is unchanged. |
| **Auth (sign-up / sign-in)** | After purchase (≈460pt+), the legal footer clips | Buttons stretch | Breaks (outer, legal footer) · `Auth/AuthView.swift:83-240,368` | P3; P2 | P3 gated; P2 no-op |
| **Home** | ✅ scrolls under a ≈90pt header | Carousel cards ≈670×430 across the fold; buttons and quote stretch | Looks bad · `Home/HomeView.swift:134,167,216,239-243,379,439-445,593`; dead `UIScreen.main` (359) | P2 on the scroll content; delete the unused `screenWidth`/`cardWidth` (359, 368-370) | P2 no-op; the deleted state is never read |
| **Custom tab bar** | Stays at the bottom (doesn't go vertical) and takes height | Full width; fine | Polish · `Home/MainTabView.swift:231-262`; non-reactive inset read · `:315-323` | P5 (inset from geometry); P7 (system tab bar) can wait | P5 reads the same bottom inset value (34 / 0) through `GeometryProxy.safeAreaInsets` |
| **Walkthrough overlay** | Card + tab bar eat height | Card straddles the fold | Looks bad · `Walkthrough/WalkthroughOverlayView.swift:46-48,92` | P2 on the card | P2 no-op |
| **Courses list** | ✅ scrolls | 2-column grid; the gutter sits on the fold (Apple-recommended even columns) | Polish · `Courses/CoursesView.swift:337-340,370,409` | P2 (keep 2 columns, cap the width) | P2 no-op |
| **Course detail sheet** | ✅ | Full-width lesson cards | Looks bad · `Courses/CourseDetailSheet.swift:289` | P2 | P2 no-op |
| **Lesson player** | OK. The title strip uses a stale inset read. | Very long text lines; the tap split sits on the fold; **scroll jumps on resize** | Looks bad · `Lesson/LessonView.swift:566,588-589`; Polish · `:669`; Looks bad · `:549,615-628`; `:102-110` | P2 (text column 600–680pt); P5; keep scroll position across a size change (only re-scroll when the screen index changes) | P2 no-op. P5 gives the same inset value. The scroll fix changes behaviour only when the size changes, which never happens on current iPhones (portrait-locked). |
| **Lesson quiz / daily practice questions** | **Explanation panel + Next outside the ScrollView** can crowd out or clip the question | Options stretch | Breaks (outer, borderline) · `Quiz/QuizQuestionView.swift:79-87,290-331,304`; Looks bad · `:106,146` | P3 on the explanation panel; P2 | P3 gated; P2 no-op |
| **Completion screen** (lesson / scenario / daily) | **Clips Continue (only exit)**; `isSmallPhone` false → largest mark | Stretches | **Breaks** · `XP/CompletionScreen.swift:206-208,231-302` | P1 + P3. Add a short-window mark size (150, the SE value) when height < 568. | P1 keeps `isSmallPhone` identical; the new branch is unreachable on current iPhones |
| **Scenario list** (PracticeView) | ✅ scrolls | Cards stretch | Looks bad · `PracticeGame/PracticeCardView.swift:65` | P2 | P2 no-op |
| **Scenario game** (branching) | Image `scaledToFit` with no height cap; dialogue box pinned; verify it fits | Tap halves on the fold; dialogue stretches | Looks bad · `PracticeGame/PracticeGame.swift:546-551,645`; Polish · `:533,577,583` | P2 on the dialogue box; cap the image height to the remaining space in short windows (P3 style) | Both no-ops / gated |
| **Profile** | ✅ scrolls | Stat tile on the fold; cards stretch | Looks bad · `Profile/ProfileStatsHeader.swift:167-174`; Profile cards | P2 | P2 no-op |
| **Invite Friends share** | OK (compact → sheet) | **Popover with no anchor → likely exception** | **Breaks** · `Profile/ProfileView.swift:374-384` | Set `popoverPresentationController?.sourceView/sourceRect` (the Invite button's frame, or the window centre with no arrow) | UIKit adapts a popover to a sheet at compact width and ignores the anchor. This is documented adaptive behaviour, so identical. |
| **Settings sheet** | Fixed `.height(720–836)` detent > window; survives because of `ScrollIfTooTall`; the X's −20pt top padding may clip | Form-sheet-ish | Looks bad · `Profile/ProfileView.swift:176-179`; `SettingsSheet.swift:92,850-861` | P1: use `.large` when height < 568 (same branch the SE takes) | P1 keeps the SE/standard split identical; the new short case is unreachable today |
| **Edit profile / Daily reading goal** (`.medium`) | **No ScrollView; Save hidden** at ≈200pt detent / behind the keyboard | OK | Breaks (outer) · `Profile/EditProfileSheet.swift:34-136`; `Profile/DailyReadingGoalSheet.swift:35-136,60` | Add `.large` to the detents only when height < 568, plus P3 | Detent list unchanged at ≥ 568pt |
| **Approaches logged list** | ✅ | Rows stretch; date/level far apart | Looks bad · `Profile/ApproachesLoggedListView.swift:256-265` | P2 | P2 no-op |
| **Log approach sheet** (custom) | ✅ scrolls; `isSmallPhone` detent false on outer | Full width; custom drag-dismiss | Looks bad · `LogApproach/LogApproachBottomSheet.swift:54,316-334`; `HomeView.swift:323` | P1 (detent), P2 | P1 identical |
| **Rating prompt** | ✅ system alert, foreground scene lookup | ✅ (system moves alerts off the fold) | none · `Util/ReviewPromptManager.swift:256-260` | — | — |
| **Sign in with Apple / Google** | ✅ system sheets | ✅ | `connectedScenes.first` (`Auth/AuthManager.swift:2448,3048`): fine single-scene | Can wait | — |

---

## 6. What is *not* a problem (so nobody spends time on it)

- **Scene lifecycle, idiom checks, orientation APIs:** already clean.
- **State on fold/unfold:** preserved everywhere, apart from the cosmetic translated `ViewThatFits` resets.
- **Assets and media:** square, `scaledToFit`. No video or animation files.
- **System sheets, alerts and the rating prompt:** the system moves them away from the fold.
- **Tap halves at width/2:** they read naturally as left page / right page on a book fold.

---

## 7. Phase 3: Ordered implementation plan

The cheapest, widest-impact changes come first. Each pattern is built so that **at compact width and at window heights ≥ 568pt (every current iPhone, including SE 2/3 with Display Zoom) the rendered output is identical**. Any pattern that has to branch does it with a modifier value, not an `if` around views, so view identity (and `@State`) doesn't change on fold.

**Step 0. Baseline first (no app code).** Install the iOS 27.2 simulator runtime. Capture the §8 baselines on the **current** toolchain/SDK (26.5).

**Step 1. SDK bump on its own (B1, RISK).** Archive with Xcode 27.2 / iOS 27 SDK. Change nothing else. Diff every render and sweep against Step 0.
- Any diff is an SDK behaviour change on existing iPhones and gets fixed or accepted *before* the layout work starts.
- This is the only step whose "pure upside" can't be argued from code. The diff is the guarantee.
- On Duo, this step alone makes the app resize. Steps 2–4 have to ship in the same build.

**Step 2. P1: measured window size replaces `UIScreen.main`** (`Device+Screen.swift:18-21`, `OnboardingView.swift:295`, `HomeView.swift:359`).
- Measure the root window size once in RootView. Use a root `GeometryReader` with `ignoresSafeArea()` so it reports the full window, which equals `UIScreen.main.bounds` for a portrait full-screen app. Pass it down as an environment value.
- `isSmallPhone` keeps its exact predicate (`width < height && height < 700`), computed from that size. `pageWidth` becomes the measured width. The dead `screenWidth`/`cardWidth` in PeekCarousel get deleted.
- Add one new predicate, `isShortWindow = height < 568`. It's false on every current iPhone because the shortest is the SE with Display Zoom at exactly 568pt. All Duo-only height branches use it.
- **Guarantee:** same inputs → same booleans and widths on every current iPhone. **RISK (low):** the root `GeometryReader` wraps content that already fills the window, so layout is unchanged, but the snapshot diff has to confirm it.
- The skill's rule is followed: never `UIScreen.main`, `UIApplication.shared` or `UITraitCollection.current` as the replacement.

**Step 3. P4: paywall and one-time-offer short-window layout (B2, B3: critical).**
- When `isShortWindow`, keep **CTA + trial disclosure + footer (Privacy / Restore / Terms)** pinned. That's about 190pt.
- Move the plan rows into the existing `ScrollView` above, together with the carousel (whose height allowance drops to 0 so the plans are visible first).
- Use the same structure for `OneTimeOfferView`: its title, hero and image scroll, and the claim CTA + disclosure + footer stay pinned.
- Plan selection and `isPurchasing` live in the view models, so moving the rows between containers can't drop a selection or an in-flight purchase.
- **Guarantee:** the branch only runs below 568pt height. At ≥ 568pt the existing pinned `VStack` renders unchanged.
- **Non-dismissability is untouched:** same `isDismissible` inputs, same 3s close reveal.

**Step 4. P3: short-window scroll fallback** (completion screen, commitment pact, growth projection, statistic, loading, auth, quiz explanation panel, edit-profile and reading-goal sheets).
- Extend the existing `scrollsWhenTooTallIfTranslated` (`Util/View+TranslatedTextFit.swift:98`) so it also applies when `isShortWindow`. English stays `self` on every current iPhone.
- For the commitment pact, add `.scrollDisabled(true)` while the content fits, so the hold gesture isn't delayed by the scroll view.
- For the completion screen, use the SE mark size (150) when `isShortWindow`.
- **Rule:** apply the modifier *inside* any `.onAppear` / `.task` and below any latching `@State`, so a fold that swaps the `ViewThatFits` branch can't re-run side effects. This is already true for LoadingScreen's `hasStarted` and CompletionScreen's `hasRunIntro`.
- **Guarantee:** the English path is the identical `self` whenever `isShortWindow` is false.

**Step 5. Share sheet anchor (B5).** Set the popover `sourceView`/`sourceRect` before presenting (`ProfileView.swift:374-384`). Guarantee: in the table above.

**Step 6. P2: readable-width column.**
- Add one modifier: `.frame(maxWidth: hSizeClass == .regular ? 680 : .infinity).frame(maxWidth: .infinity)`. Use 560 for the paywall and offer, 680 for text-heavy screens (lesson, onboarding, auth), and keep cards and grids inside the same column.
- Apply it **only to containers that already span the full proposed width** (each listed in §5).
- This is Apple's "let the existing layout expand into more whitespace", and it adds no new visual elements. The brand stays soft black, off-white, one green accent and print-like calm.
- **Guarantee:** at compact width the modifier is `maxWidth: .infinity` around a container that already fills the width, so the size and position are identical. The value is a ternary, so the view identity is stable across fold. **RISK (low):** confirm with the snapshot diff, especially on screens whose root alignment isn't `.center`.

**Step 7. P5: reactive safe-area inset** (`MainTabView.swift:315-323`, `LessonView.swift:102-110`).
- Read `bottom` from the `GeometryProxy.safeAreaInsets` that's already in scope, or one added around the bar, instead of walking `UIApplication.shared.connectedScenes`.
- **Guarantee:** the same window inset (34pt on Face ID phones, 0 on the SE), so it returns the same −5/2 and −10/6. It's also correct after a fold.

**Step 8 (optional, can wait). P6: fold awareness for critical controls.**
- `if #available(iOS 27.1, *)`, read `GeometryProxy.reservedRegions(kind:…)` for an active vertical division. If one intersects the paywall/offer footer or the pact hold target, shift the column to one side of the fold.
- This is the overlay arrangement idea: primary content on the trailing half. Apple suggests `ArrangementView` for this, but a single-column screen only needs the offset.
- **Guarantee:** no current iPhone ever reports an active division, so the code path can't run. It compiles only with the 27.1+ SDK.

**Step 9 (optional, later). P7/P8:**
- P7: adopt the system `TabView` tab bar so it goes vertical on Duo. **RISK:** this changes the tab bar's look on every iPhone, so it isn't pure upside. It needs a design decision.
- P8: `NavigationSplitView` for Courses → lesson and Scenarios → scenario on the inner display. **RISK:** a navigation change. Post-launch.

---

## 8. Test plan

**0. Environment.**
- Install the iOS 27.2 simulator runtime.
- Create a throwaway "Wingman Duo" iPhone Duo simulator. Don't reuse or wipe the shared simulators (other sessions use them).
- Build with `xcodebuild` from Bash, then use the simulator MCP `launch` (the MCP build action hangs on this project).
- Paywall pricing needs a **Release** build, or the render tests' fixture packages.

**1. Baseline before any change (the regression proof).** Run on the *current* SDK and toolchain, then again after each step in §7.
- **Render tests** (`WingmanTests/PaywallRenderTests.swift`, `OnboardingScreenRenderTests.swift`, `PlanRowRenderTests.swift`, `CommitmentPactRenderTests.swift`). These already render at real phone sizes under stable attachment names built for before/after comparison.
- **Extend them to cover:** CompletionScreen, QuizQuestionView with the explanation shown, AuthView (both modes), Settings, Edit profile, Reading goal, Home, Lesson, Profile.
- **Sizes:**
  - SE 2/3: 375×667.
  - SE with Display Zoom: 320×568.
  - 17e/17: 390×844 and 402×874.
  - 17 Pro: 402×874.
  - 17 Pro Max: 440×956.
  - Each in English plus one translated language (de).
- **UI sweep:** `WingmanUITests/OnboardingSweepTests.swift` through `scripts/screenshots.py export` / `compare` on SE 3, 17 and 17 Pro Max against a fresh `docs/duo-baseline/<device>/`. The pass criterion is **zero pixel differences** (the script's `--ignore-top` handles the clock).
- **Duo-like sizes without the Duo runtime.** The render tests can render at any size and inject `horizontalSizeClass`. Add short/wide compact cases (for example 600×400 and 700×420) and regular-width cases (for example 800×1000, 1000×800, and a 500×1000 half for split screen). Use them to check P3/P4/P2 before the simulator exists. Replace these guessed sizes with the measured Duo outer/inner sizes once the simulator runs.

**2. Device Hub / iPhone Duo simulator, for each pose.** Poses: closed, open portrait, open landscape, partially folded (book and laptop), rotated, and split screen with Safari at each split.

Walk through Landing → full onboarding → paywall → one-time offer → walkthrough → each tab → course → lesson → quiz → completion → scenario → completion → daily practice → Profile → Settings / Edit profile / Reading goal / Invite Friends → log approach.

Check:
- Nothing is clipped, and every CTA, Restore, Terms and Privacy link is visible and tappable.
- Nothing interactive sits in the fold region.
- Nothing sits under the outer camera.
- Whether the portrait lock is honoured on the inner display. Record the answer in this doc.
- Whether `.toolbar(.hidden, for: .tabBar)` still hides the system tab bar at regular width.

**3. Fold/unfold mid-flow.** Fold, unfold, rotate and switch into split screen at each of these points:
- Onboarding question 3, and during the loading screen. Confirm no second Supabase write in the logs and no second `onboarding_started`.
- Mid-lesson on screen 3. Confirm the same screen and the scroll position.
- Mid-scenario after a branch choice. Confirm the same `currentSceneId`.
- Mid daily practice with an answer chosen.
- With log-approach text typed. Confirm the draft is kept.
- On the commitment pact while holding.
- **Mid-purchase.** Tap Continue, then fold while the StoreKit sheet is up. Do it again after confirming, before the result. Expect a single purchase, the entitlement granted, the paywall dismissed exactly once, and a single `paywall_*`/purchase event. Use a StoreKit sandbox account in a Release build. That's a test value in the app's own flow; the user must sign in to sandbox themselves.
- With the one-time offer showing.
- Watch for any `willEnterForeground` / `didBecomeActive` firing on fold (logs in `WingmanApp.swift:95-106`).

**4. Analytics parity.** After each fold test, compare PostHog event counts with an unfolded control run. No duplicate `*_viewed` / `*_started` events. Event names are unchanged by design.

---

## 9. Build and App Store notes

- **Toolchain:** Xcode 27.2 is already installed (`Build version 27B52`). Building with it uses the iOS 27.2 SDK, which is above 27.1, so the app becomes edge to edge with vertical system bars on Duo. That means the iOS 27 SDK bump and the Duo work are **the same release**. Don't archive a routine build on Xcode 27.2 until §7 Steps 1–5 are in.
- **Deployment target:** stays at 16.6. Nothing in Steps 1–7 needs a newer API. Fallbacks use `ViewThatFits`, `scrollBounceBehavior` (16.4) and `GeometryReader`. Step 8 is behind `#available(iOS 27.1, *)`.
- **Info.plist:** no change needed. Keep `UISupportedInterfaceOrientations = Portrait` and don't add `UIRequiresFullScreen` (the skill: iOS 27 ignores it anyway). The launch screen is already declared.
- **Project file:** Xcode 27.2 will offer "Update to recommended settings" (`LastUpgradeCheck = 2660`). Review it separately from layout work, because it can change build settings for every device.
- **Vendor SDKs:** read the iOS 27 release notes for RevenueCat 5.67.1, PostHog 3.57.0, GoogleSignIn 9.1.0 and Facebook 18.1.0 before Step 1.
- **App Store:**
  - Optional iPhone Duo screenshots earn the Duo badge. Use the App Store Connect preview tool.
  - "Optimized for iPhone Duo, including support for all device poses" goes in Helpful Details for featuring.
  - Nothing in this plan touches review-sensitive purchase copy: the CTA, disclosure, Restore and Terms stay exactly as they are and stay visible.
  - Apple caps waiting submissions at two, and subscription and retention items count toward that.
- **Versioning:** none in this pass. Check what's live before bumping.

---

## 10. Open questions

1. **Paywall dismissability.** The brief says the paywall "must stay non-dismissable". Today the onboarding paywall is built with `isDismissible: true` (`WingmanApp.swift:268, 359`) and shows a close X after 3s (`PaywallView.swift:559, 614-617`). The feature-gate paywall is a swipe-dismissable `.sheet` (`SubscriptionGateModifier.swift:60-72`), and the one-time offer shows an X after 3s. This plan **keeps the current behaviour exactly**. Is that what you meant, or did you want a stricter rule? Changing it would be a behaviour change and out of scope here.
2. **Outer display height in points.** It decides how much of B2–B4 is real. Measure it once the simulator runtime is installed. If it's ≥ about 600pt, the short-window fixes still help partial folds and split screen but stop being launch-critical.
3. **Portrait lock on the inner display.** Apple's pages don't say. The plan works either way, but record what the simulator shows.
4. **System tab bar (P7).** Do you want the tab bar to go vertical on Duo? That means adopting the system tab bar, which changes its look on every iPhone. My recommendation: no, not for launch.
5. **Snapshot tooling.** OK to extend the existing `WingmanTests` render tests and `scripts/screenshots.py`, which adds no dependency, rather than adding a snapshot-testing package?
6. **Readable widths.** 680pt for text screens and 560pt for the paywall/offer column. Confirm, or give your preferred numbers within the brief's 600–700pt range.
7. **Timing.** Is there a Duo launch date to aim for? It decides whether Steps 1–5 go into the next routine release or a dedicated one.

---

## Ship for launch vs can wait

| Ship with the first iOS 27 SDK build | Can wait |
|---|---|
| Step 0–1: baseline + SDK-only diff | Step 6 (P2): readable-width columns. Looks bad on the inner display, nothing breaks. **Do it soon after**, because it's the biggest visual win for the least risk. |
| Step 2: P1 window size (replace `UIScreen.main`) | Step 7: reactive inset reads |
| Step 3: P4 paywall + one-time offer short-window layout | Step 8: fold-aware Restore and pact target (`ReservedRegion`) |
| Step 4: P3 short-window scroll fallbacks | Step 9: system tab bar, `NavigationSplitView` |
| Step 5: share sheet popover anchor | Lesson scroll-position-on-resize fix |

Stopping here for your approval. No code has been changed.
