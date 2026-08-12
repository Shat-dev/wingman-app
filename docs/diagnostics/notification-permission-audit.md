# Notification Permissions & Subscriber Gating — Diagnosis

**Date:** 2026-08-12
**Branch:** `Shat` @ `f252c46`
**Scope:** Diagnosis only. No application code was written, edited, or scaffolded.

---

## 0. Corrections to the framing

Five assumptions in the brief are contradicted by the code or by Apple's documentation. They are listed here because three of them change what the implementation prompt should say.

**0.1 — "Wingman currently has no notification permission prompt that I am aware of." False.**
`NotificationManager.swift` exists, is committed (`9f10db8 Add NotificationManager, assets, and hooks`), is compiled into the target, and calls `requestAuthorization` at [Wingman/Util/NotificationManager.swift:25](Wingman/Util/NotificationManager.swift:25). It is reachable in production from the "Goal Notifications" toggle in Settings ([Wingman/Profile/SettingsSheet.swift:194-206](Wingman/Profile/SettingsSheet.swift:194)). The one-shot system prompt is therefore already *spendable* by any user who opens Settings and flips that switch. Full analysis in §B.1 and §B.3.

**0.2 — The intended behaviour does not require remote push, and is materially safer without it.**
"Never notify a subscriber" is **guaranteeable today with local notifications** and **not guaranteeable at all with remote push** in the current architecture. This is the central finding of the audit. See §C.5.

**0.3 — There is no server-side subscriber state to gate on.**
Not "unreliable" — absent. No table, no column, no webhook, no edge function. See §C.1 and §C.2.

**0.4 — The one already-scheduled notification is copy from a different app.**
[Wingman/Util/NotificationManager.swift:75-76](Wingman/Util/NotificationManager.swift:75) schedules `"Daily Reading Reminder"` / `"Time for your daily reading! Your goal is N minutes today."` Wingman has no reading feature. The `daily_reading_goal` / `goal_notifications` UserDefaults keys carry the same lineage.

**0.5 — Provisional authorization is not a viable fit for this app.**
The brief asks for an assessment; the answer is no, and it is not close. See §A.2.

---

## Part A — Apple platform and policy constraints

### A.1 Can notifications be delivered without user authorization?

**No, for anything the user can see or hear — local and remote alike.**

Apple, *Asking permission to use notifications*:

> "Local and remote notifications get a person's attention by displaying an alert, playing sounds, or badging your app's icon. These interactions occur when your app isn't running or is in the background. They let people know that your app has relevant information for them to view. Because a person might consider notification-based interactions disruptive, you must obtain permission to use them."

— https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications

The requirement is stated over "Local and remote notifications" jointly. There is no local-notification exemption. The same document instructs:

> "Always check your app's authorization status before scheduling local notifications."

**The single exception, stated precisely:** a *background* (silent) remote notification carrying only `content-available` is not user-visible and needs no notification authorization.

> "To send a background notification, create a remote notification with an `aps` dictionary that includes only the `content-available` key… the `aps` dictionary must not contain any keys that would trigger user interactions."

> "a remote notification that doesn't display an alert, play a sound, or badge your app's icon"

— https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app

This exception is irrelevant to the intended behaviour: a background push cannot nudge anyone. It is only listed so the implementation prompt does not mistake it for a loophole. It also carries its own capability cost — the Background Modes → Remote notifications capability — which Wingman does not have (§B.2).

**Additional constraint separate from authorization:** remote push requires an entitlement Wingman does not possess.

> "To add the required entitlements to your app, enable the Push Notifications capability in your Xcode project… Enabling this option in iOS adds the [aps-environment] to the app."

— https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns

### A.2 Provisional authorization (`.provisional`)

**What it delivers.** Apple, same document, §"Use provisional authorization to send trial notifications":

> "Unlike explicitly requesting authorization, this code doesn't prompt the person for permission to receive notifications. Instead, the first time you call this method, it automatically grants authorization."

> "The system delivers provisional notifications quietly — they don't interrupt the person with a sound or banner, or appear on the lock screen. Instead, they only appear in the notification center's history. These notifications also include buttons that prompt the person to keep or turn off the notification."

**What it does not deliver — including in the best case.** Apple is explicit that even a user who accepts does not restore alert/sound/badge:

> "If a person presses the Keep button, the system prompts them to choose between two options: Deliver Immediately or Deliver in Scheduled Summary. Deliver Immediately delivers future notifications quietly. The system authorizes your app to send notifications, but it doesn't give your app permission to show alerts, play sounds, or badge the app icon. Your notification only appears in the notification center history unless they change their notification settings."

> "If the person presses the Turn Off button, the system confirms the selection before denying your app authorization to send additional notifications."

**Verdict for a habit/streak app: not viable as the primary channel. Definitive.**

The mechanism of a streak reminder is interruption — a lock-screen banner at a chosen hour. Provisional authorization removes exactly and only that: no banner, no sound, no lock screen. The notification lands in a history list the user must choose to open, which inverts the causality the feature depends on (the nudge is supposed to cause the app open, not require one). And the ceiling on success is a *quiet* notification — "Keep → Deliver Immediately" still withholds alerts, sounds, and badges. Provisional trades the entire value of the channel for the avoidance of one dialog, and its best outcome is still a broken channel.

There is one legitimate use for `.provisional` here, noted for completeness and not recommended as the plan: as a fallback ask for users who explicitly decline the soft prompt, where the alternative is no channel at all. That is a second-order optimization, not a design.

### A.3 Does the intended behaviour fall under Guideline 4.5.4?

**Yes. Definitively.**

Guideline 4.5.4, verbatim:

> "**4.5.4 Push Notifications** must not be required for the app to function, and should not be used to send sensitive personal or confidential information. Push Notifications should not be used for promotions or direct marketing purposes unless customers have explicitly opted in to receive them via consent language displayed in your app's UI, and you provide a method in your app for a user to opt out from receiving such messages. Abuse of these services may result in revocation of your privileges."

— https://developer.apple.com/app-store/review/guidelines/

**Why the answer is yes and not "it depends on the payload."** The brief defines the audience by commercial status and terminates the program on purchase. A notification stream whose membership rule is *"has not paid"* and whose exit condition is *"has paid"* is, by construction, a conversion instrument. The targeting rule is the marketing, independent of the words in the body. A reviewer does not need to read a payload to characterize a channel that switches off at checkout. And the moment any payload mentions a trial, a discount, a locked lesson, or the second-chance offer — all of which exist in this app — the classification stops being arguable at all.

The contrary reading ("streak reminders are functional, the non-subscriber targeting is incidental") is available only if the targeting is incidental, and the brief states it is the defining rule.

There is also no reason to fight this. Compliance costs one screen and one toggle, both of which independently raise grant rate and reduce uninstalls.

**What 4.5.4 then requires, and where each piece must live:**

| Requirement | Guideline text | Where it must live |
|---|---|---|
| **Explicit opt-in** | "customers have explicitly opted in to receive them via consent language displayed in your app's UI" | An in-app screen you control, shown *before* the iOS system prompt, whose primary button is an affirmative act. The iOS system alert does **not** satisfy this — its text is Apple's, not "displayed in your app's UI." The copy must state what will be sent and how often, and be legible without scrolling. |
| **In-app opt-out** | "you provide a method in your app for a user to opt out from receiving such messages" | Inside the app, not "go to iOS Settings." Wingman already has the correct control: the "Goal Notifications" toggle at [SettingsSheet.swift:177-207](Wingman/Profile/SettingsSheet.swift:177). It must actually stop delivery, which today means cancelling the local schedule ([NotificationManager.swift:104-109](Wingman/Util/NotificationManager.swift:104)) and, if remote push is ever added, also clearing the server-side token/flag. |
| **Not required to function** | "must not be required for the app to function" | The permission screen must be skippable with no penalty and no reduced content. |

**Also binding — Guideline 5.1.2(i):**

> "Your app may not require users to enable system functionalities (e.g. push notifications, location services, tracking) in order to access functionality, content, use the app, or receive monetary or other compensation, including but not limited to gift cards and codes."

This forecloses the two obvious growth patterns: no "enable reminders to unlock your free lesson," no "turn on notifications for 3 extra trial days," no XP award for granting. The permission screen must offer nothing in exchange.

### A.4 Re-prompt rules

**The system prompt is shown exactly once, ever.** Apple, *Asking permission to use notifications*:

> "The first time your app makes this authorization request, the system prompts the person to grant or deny the request and records that response. Subsequent authorization requests don't prompt the person."

**On denial:** every later `requestAuthorization` call returns `granted == false` immediately, silently, with no UI. There is no API to re-present the system alert, no entitlement that unlocks one, and no reset short of the user deleting and reinstalling the app.

**The only remaining path after denial is iOS Settings**, changed by the user:

> "People can change your app's authorization settings at any time. They can also change the type of interactions allowed by your app — which may cause you to alter the number or type of notifications your app sends."

The app's sole affordance is deep-linking there via `UIApplication.openSettingsURLString` — which navigates, but cannot grant. Practically, denial is permanent.

The existing code already understands this. [NotificationManager.swift:15-22](Wingman/Util/NotificationManager.swift:15) reads `authorizationStatus` *before* asking, precisely so a re-request by an already-answered user is not miscounted as a fresh grant. That instrumentation is correct and should be preserved.

**Consequence that drives Part D:** the one-shot property means the system prompt is a non-renewable asset. Spending it on a user who has not yet been given a reason is the single most expensive mistake available in this feature.

---

## Part B — Audit of the current implementation

### B.1 Is `UNUserNotificationCenter` referenced? Is `requestAuthorization` called?

**Yes to both.** All references live in one file: [Wingman/Util/NotificationManager.swift](Wingman/Util/NotificationManager.swift) (154 lines total).

| Lines | What |
|---|---|
| [11-52](Wingman/Util/NotificationManager.swift:11) | `requestPermission(source:) async -> Bool` |
| [21-22](Wingman/Util/NotificationManager.swift:21) | Reads prior `authorizationStatus`, computes `wasPrompted` |
| **[25](Wingman/Util/NotificationManager.swift:25)** | **`center.requestAuthorization(options: [.alert, .sound, .badge])`** — no `.provisional` |
| [31-37](Wingman/Util/NotificationManager.swift:31) | PostHog `notification_permission_result` with `granted` / `was_prompted` / `prior_status` / `source` |
| [56-65](Wingman/Util/NotificationManager.swift:56) | `statusName(_:)` — stable strings for all five `UNAuthorizationStatus` cases |
| [68-101](Wingman/Util/NotificationManager.swift:68) | `scheduleDailyReadingGoalNotification(goalMinutes:)` |
| [74-79](Wingman/Util/NotificationManager.swift:74) | Content — `"Daily Reading Reminder"`, badge 1 |
| [80-85](Wingman/Util/NotificationManager.swift:80) | `UNCalendarNotificationTrigger`, hardcoded 09:00, `repeats: true` |
| [88-92](Wingman/Util/NotificationManager.swift:88) | `UNNotificationRequest(identifier: "daily_reading_goal", …)` |
| [104-109](Wingman/Util/NotificationManager.swift:104) | `cancelDailyReadingGoalNotification()` — `removePendingNotificationRequests` |
| [112-121](Wingman/Util/NotificationManager.swift:112) | `updateDailyReadingGoalNotification(enabled:goalMinutes:source:)` — the only caller of `requestPermission` |
| [124-140](Wingman/Util/NotificationManager.swift:124) | `clearNotificationBadgeAndDelivered()` |
| [143-153](Wingman/Util/NotificationManager.swift:143) | `setupNotificationsOnLaunch()` |

**The analytics event is registered:** `notification_permission_result` at [Wingman/Util/Analytics.swift:193](Wingman/Util/Analytics.swift:193).

**Two defects worth carrying into the implementation prompt:**

1. **`setupNotificationsOnLaunch()` schedules without checking authorization** ([NotificationManager.swift:143-153](Wingman/Util/NotificationManager.swift:143)). It reads `goal_notifications` from UserDefaults and calls `scheduleDailyReadingGoalNotification` directly. This contradicts Apple's explicit instruction ("Always check your app's authorization status before scheduling local notifications"). It is currently harmless — an unauthorized schedule silently never delivers — but it means the app has no idea whether its own reminders work.

2. **No `UNUserNotificationCenterDelegate` is set anywhere in the codebase.** An `AppDelegate` exists at [WingmanApp.swift:22-43](Wingman/WingmanApp.swift:22), bridged via `@UIApplicationDelegateAdaptor` at [WingmanApp.swift:47](Wingman/WingmanApp.swift:47), but it handles only the Facebook SDK. There is no `willPresent`, no `didReceive response`, no `registerForRemoteNotifications`, no `didRegisterForRemoteNotificationsWithDeviceToken`. Consequence: a notification tapped from the lock screen cold-launches the app to whatever route `RootView` computes, with no deep-link and no attribution; and a notification arriving while the app is foregrounded is suppressed entirely.

### B.2 Push Notifications capability / APNs credentials

**Not enabled. No APNs key or certificate is configured or referenced.**

- [Wingman/Wingman.entitlements:1-10](Wingman/Wingman.entitlements) — the complete file. One key: `com.apple.developer.applesignin` = `["Default"]`. **No `aps-environment`.**
- Referenced from the build settings at [Wingman.xcodeproj/project.pbxproj:327](Wingman.xcodeproj/project.pbxproj:327) (Debug) and [:366](Wingman.xcodeproj/project.pbxproj:366) (Release) — one entitlements file for both configurations, so the absence is total.
- [Wingman/Info.plist:1-51](Wingman/Info.plist) — the complete file. No `UIBackgroundModes`, therefore no `remote-notification` background mode. Keys present are Google Sign-In URL scheme, Facebook, `SKAdNetworkItems`, and `UIAppFonts`.
- No push SDK in the dependency graph. `Package.resolved` resolves: app-check, AppAuth-iOS, facebook-ios-sdk, GoogleSignIn-iOS, GoogleUtilities, gtm-session-fetcher, GTMAppAuth, plcrashreporter, posthog-ios, promises, purchases-ios-spm, supabase-swift, swift-asn1, swift-clocks, swift-concurrency-extras, swift-crypto, swift-http-types, xctest-dynamic-overlay. **No Firebase Messaging, no OneSignal, no Airship.**
- No `.mobileprovision`, no `.p8`, no `.p12` anywhere in the repo.

**Wingman cannot receive a remote push today.** Adding the capability is a signing-and-provisioning change, not a code change.

### B.3 Existing scheduled local notifications

**One, and it is effectively dormant.**

The only scheduled notification is `"daily_reading_goal"` ([NotificationManager.swift:88-92](Wingman/Util/NotificationManager.swift:88)) — daily at 09:00, title `"Daily Reading Reminder"`, body `"Time for your daily reading! Your goal is N minutes today."` ([:75-76](Wingman/Util/NotificationManager.swift:75)). **There are no streak reminders and no daily-practice nudges.**

**The three call sites, and exactly when the system prompt can fire:**

| Site | Behaviour |
|---|---|
| [SettingsSheet.swift:194-206](Wingman/Profile/SettingsSheet.swift:194) | `.onChange(of: goalNotifications)` → `updateDailyReadingGoalNotification(enabled:goalMinutes:source: "goal_toggle")`. **A manual toggle-on here is the only path that fires the system prompt in production.** |
| [DailyReadingGoalSheet.swift:158-167](Wingman/Profile/DailyReadingGoalSheet.swift:158) | Reschedules on goal change, but **only if `goal_notifications` is already true** — so it can never be the first prompt. |
| [WingmanApp.swift:628](Wingman/WingmanApp.swift:628) | `setupNotificationsOnLaunch()` in `RootView`'s launch task. Schedules only; never requests permission. |

**On the `loadSettings()` default-write path** ([SettingsSheet.swift:433-435](Wingman/Profile/SettingsSheet.swift:433) → [:452-467](Wingman/Profile/SettingsSheet.swift:452)): `@State goalNotifications` initializes to `true` ([:15](Wingman/Profile/SettingsSheet.swift:15)); `loadSettings()` writes `false` from UserDefaults, then writes `true` back for first-time users ([:461-465](Wingman/Profile/SettingsSheet.swift:461)). Both writes happen synchronously inside one `onAppear`, so SwiftUI compares `true` against `true` at the next body evaluation and `.onChange` does not fire. **Merely opening Settings does not prompt.** The prompt requires a deliberate toggle.

Net: for a user who never opens Settings and toggles, `requestAuthorization` is never reached, `goal_notifications` stays `false`, and `setupNotificationsOnLaunch()` schedules nothing. The one-shot prompt is intact for the overwhelming majority of the install base — but it is *reachable*, and the implementation prompt must account for the minority who have already spent it.

### B.4 Backend / Supabase capable of sending pushes today

**None. Nothing in the project can send a push.**

- `supabase/functions/` contains exactly two entries: `_shared/cors.ts` and `delete-user-account/` (`index.ts`, `index_new.ts`, `README.md`). No sender, no scheduler, no cron.
- `supabase/migrations/` contains four files. Every `create table` across all of them: `public.lessons` and `public.lesson_questions` (`20260730000000_create_lesson_questions.sql:17,143`), `public.user_lesson_quiz_answers` (`20260730010000_lesson_questions_by_column.sql:86`), `public.user_daily_practice_streaks` and `public.user_daily_practice_sessions` (`20260811160658_baseline_daily_practice_streaks.sql:89,104`), `public.xp_rules` and `public.user_xp_events` (`20260811161839_xp_ledger.sql:77,110`). **No device-token table. No subscription table.**
- No `pg_cron`, no `pg_net`, no scheduled job in any migration.
- The only edge-function invocation in the app is the account-deletion call at [AuthManager.swift:3084](Wingman/Auth/AuthManager.swift:3084).

**UNDETERMINED — live Supabase schema.** The app points at project `bnckmgnysfliiypvxxii` ([SupabaseManager.swift:17](Wingman/Supabase/SupabaseManager.swift:17), [AuthManager.swift:3084](Wingman/Auth/AuthManager.swift:3084)). The Supabase MCP connection available in this session lists only one project, `rdgtvavltiqmwfzcadcv` ("Clera-App") — a different account or organization. I could not enumerate live tables or deployed edge functions for the Wingman project. What is established is that the repository contains no push infrastructure; a table or function created directly in the dashboard and never committed would not appear here. **This should be confirmed in the Supabase dashboard before the implementation prompt is written.**

### B.5 Per-user notification state

**None anywhere. All notification state is device-global UserDefaults, unkeyed by user.**

Two keys only:

- `goal_notifications` (Bool) — written at [SettingsSheet.swift:196](Wingman/Profile/SettingsSheet.swift:196) and [:464](Wingman/Profile/SettingsSheet.swift:464); read at [NotificationManager.swift:144](Wingman/Util/NotificationManager.swift:144), [SettingsSheet.swift:457](Wingman/Profile/SettingsSheet.swift:457), [DailyReadingGoalSheet.swift:158](Wingman/Profile/DailyReadingGoalSheet.swift:158).
- `daily_reading_goal` (Int) — read at [NotificationManager.swift:145](Wingman/Util/NotificationManager.swift:145).

Both are cleared on identity change ([SupabaseManager.swift:63-83](Wingman/Supabase/SupabaseManager.swift:63), inside `clearCurrentUser()`) and on full local wipe ([AuthManager.swift:3232-3233](Wingman/Auth/AuthManager.swift:3232)).

**The structural point:** every other user-scoped flag in this codebase is written as `key_<userId>` — `hasCompletedQuestions_<id>`, `hasCompletedPaywallFlow_<id>`, `hasDismissedPostDemoWall_<id>` ([AuthManager.swift:3215-3219](Wingman/Auth/AuthManager.swift:3215)), `postPurchaseAskKey(_:)` ([:2640-2642](Wingman/Auth/AuthManager.swift:2640)). The notification keys are not. They are global to the device and shared across every account that signs in on it, and they exist on the device only — the server has no idea whether any user wants reminders.

### B.6 Complete onboarding sequence, in order

Router: [WingmanApp.swift:164-395](Wingman/WingmanApp.swift:164) (`RootView.body`).

| # | Screen | File | Notes |
|---|---|---|---|
| 0 | `SplashView` | [Wingman/Splash/SplashView.swift](Wingman/Splash/SplashView.swift) | While `isCheckingSession` ([WingmanApp.swift:168-170](Wingman/WingmanApp.swift:168)) |
| 1 | `LandingView` | [Wingman/Landing/LandingView.swift](Wingman/Landing/LandingView.swift) | Gated by `showLanding` ([WingmanApp.swift:156-159](Wingman/WingmanApp.swift:156)). "Get started" ([:109-111](Wingman/Landing/LandingView.swift:109)) calls `startAnonymousOnboarding()`, which fires guest-session bootstrap ([AuthManager.swift:1810-1817](Wingman/Auth/AuthManager.swift:1810)) and pushes `OnboardingView` |
| — | **Guest session created** | [AuthManager.swift:1706-1770](Wingman/Auth/AuthManager.swift:1706) | `signInAnonymously()` at [:1758](Wingman/Auth/AuthManager.swift:1758) → `adoptGuestIdentity()` at [:1612](Wingman/Auth/AuthManager.swift:1612). **This is the first moment a Supabase `user_id` exists.** |
| 2 | Name | `NameScreen` — [Screens/NameScreen.swift](Wingman/Onboarding/Screens/NameScreen.swift) | Step 1, [OnboardingFlow.swift:48-55](Wingman/Onboarding/OnboardingFlow.swift:48). Skippable |
| 3 | Age | `QuestionScreen` | Step 2, [:58-65](Wingman/Onboarding/OnboardingFlow.swift:58), key `age` |
| 4 | Last approach | `QuestionScreen` | Step 3, [:68-75](Wingman/Onboarding/OnboardingFlow.swift:68), key `last_approach` |
| 5 | Statistic interstitial | `StatisticScreen` | [StatisticContent.swift:22-38](Wingman/Onboarding/Statistics/StatisticContent.swift:22), branches on age group |
| 6 | Approach frequency | `QuestionScreen` | Step 4, [:78-85](Wingman/Onboarding/OnboardingFlow.swift:78) |
| 7 | Statistic interstitial | `StatisticScreen` | [StatisticContent.swift:41-48](Wingman/Onboarding/Statistics/StatisticContent.swift:41) |
| 8 | Barriers (multi-select) | `QuestionScreen` | Step 5, [:88-101](Wingman/Onboarding/OnboardingFlow.swift:88) |
| 9 | Statistic interstitial | `StatisticScreen` | [StatisticContent.swift:51-58](Wingman/Onboarding/Statistics/StatisticContent.swift:51) |
| 10 | Goals (multi-select) | `QuestionScreen` | Step 6, [:104-117](Wingman/Onboarding/OnboardingFlow.swift:104) |
| 11 | Statistic interstitial | `StatisticScreen` | [StatisticContent.swift:61-68](Wingman/Onboarding/Statistics/StatisticContent.swift:61) |
| 12 | Growth projection | [Screens/GrowthProjectionScreen.swift](Wingman/Onboarding/Screens/GrowthProjectionScreen.swift) | Step 7, [:132-139](Wingman/Onboarding/OnboardingFlow.swift:132) |
| 13 | Loading (~6.2s) | [Screens/LoadingScreen.swift](Wingman/Onboarding/Screens/LoadingScreen.swift) | Step 8, [:145-152](Wingman/Onboarding/OnboardingFlow.swift:145). Fires `onboarding_completed` at [OnboardingView.swift:724](Wingman/Onboarding/OnboardingView.swift:724) |
| 14 | Social proof | [Screens/SocialProofScreen.swift](Wingman/Onboarding/Screens/SocialProofScreen.swift) | Step 9, [:174-181](Wingman/Onboarding/OnboardingFlow.swift:174). **Last step.** Continue → `finishOnboarding()` ([OnboardingView.swift:751-763](Wingman/Onboarding/OnboardingView.swift:751)) |
| 15 | Commitment pact | [Wingman/Commitment/CommitmentPactView.swift](Wingman/Commitment/CommitmentPactView.swift) | [WingmanApp.swift:253-259](Wingman/WingmanApp.swift:253). Flag-gated on `commitmentPactEnabled`; **off by default** |
| **16** | **`PaywallView` (`.onboarding`)** | [Wingman/Payment/PaywallView.swift](Wingman/Payment/PaywallView.swift) | **[WingmanApp.swift:262-266](Wingman/WingmanApp.swift:262). Dismissible.** ← the paywall's position |
| 17 | Post-purchase account ask | `AuthView(.signup, .afterPurchase)` | [WingmanApp.swift:279-288](Wingman/WingmanApp.swift:279). Guests who purchased. **Skippable** |
| 18 | `MainTabView` — demo mode | [Wingman/Home/MainTabView.swift](Wingman/Home/MainTabView.swift) | [WingmanApp.swift:302-304](Wingman/WingmanApp.swift:302). Mascot walkthrough, 1 free scenario + 1 free lesson |
| 19 | `PaywallView` (`.postDemo`) | | [WingmanApp.swift:317-335](Wingman/WingmanApp.swift:317). Hard/soft per `postDemoWallIsHard` |
| 20 | `MainTabView` — gated | | [WingmanApp.swift:338-340](Wingman/WingmanApp.swift:338). Per-feature gates + `SecondChanceOfferView` ([SubscriptionGateModifier.swift:114](Wingman/Payment/SubscriptionGateModifier.swift:114)) |

**Fallback path — legacy anonymous, no session** ([WingmanApp.swift:355-380](Wingman/WingmanApp.swift:355)): reached when `guestSessionsEnabled` is off ([FeatureFlags.swift:59](Wingman/Util/FeatureFlags.swift:59)) or bootstrap failed. Sequence: pact → paywall → forced `AuthView(.requiredAfterPaywall)`. **These users reach and can complete the paywall with no Supabase `user_id` at all.** This is load-bearing for §C.

---

## Part C — Can subscriber state gate this?

### C.1 Where subscription status is determined

**Source of truth: RevenueCat, on device.** Chain:

1. **RevenueCat SDK** — `customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive` ([RevenueCatManager.swift:28-30](Wingman/Payment/RevenueCatManager.swift:28)). `ENTITLEMENT_ID` = `RevenueCatConfig.premiumEntitlementId` ([Constants.swift:13](Wingman/Resources/Constants.swift:13)).
2. **`SubscriptionManager.isSubscriptionActive`** ([SubscriptionManager.swift:21](Wingman/Payment/SubscriptionManager.swift:21)) — set by `handleCustomerInfoUpdate` ([:206-273](Wingman/Payment/SubscriptionManager.swift:206)) via `updateSubscriptionStatus` ([:278-297](Wingman/Payment/SubscriptionManager.swift:278)). Refreshed by a 5-minute timer ([:359-370](Wingman/Payment/SubscriptionManager.swift:359)) and on foreground ([WingmanApp.swift:101-105](Wingman/WingmanApp.swift:101)).
3. **UserDefaults cache** — `cached_subscription_active` / `cached_subscription_expiry` ([SubscriptionManager.swift:47-48](Wingman/Payment/SubscriptionManager.swift:47)), written at [:313-320](Wingman/Payment/SubscriptionManager.swift:313), replayed at cold start by `loadSubscriptionCache()` ([:330-355](Wingman/Payment/SubscriptionManager.swift:330)) with a local clock check against stored expiry. **Deliberately global, not per-user** — see the comment at [:41-46](Wingman/Payment/SubscriptionManager.swift:41): *"the entitlement is device-scoped."*
4. **`AuthManager.hasActiveSubscription`** ([AuthManager.swift:214-218](Wingman/Auth/AuthManager.swift:214)) — mirrored by `syncSubscriptionStatus()` ([:506-543](Wingman/Auth/AuthManager.swift:506)) on every `subscriptionStatusChangedNotification`. This is what every gate and route reads ([WingmanApp.swift:291](Wingman/WingmanApp.swift:291), [HomeView.swift:163](Wingman/Home/HomeView.swift:163), [MainTabView.swift:103](Wingman/Home/MainTabView.swift:103), [AuthManager.swift:587,598](Wingman/Auth/AuthManager.swift:587)).

There is a StoreKit-direct path for local testing only, behind `RevenueCatConfig.useStoreKitTestingMode` ([SubscriptionManager.swift:84-90](Wingman/Payment/SubscriptionManager.swift:84)).

### C.2 Is subscription status available server-side at send time?

**No. Device only.**

A backend dispatching a notification today would read **nothing**, because nothing exists to read:

- No subscription table in any migration (§B.4). No `.from("subscriptions")`, `.from("entitlements")`, or equivalent anywhere in the Swift sources — the complete set of tables the app touches is `approach_logs`, `course_categories`, `courses`, `practice_details`, `questions`, `scenarios`, `user_daily_practice_sessions`, `user_lesson_quiz_answers`, `user_practice_progress`, `user_question_completions`, `user_scenario_completions`, `user_scenario_progress`.
- No RevenueCat webhook receiver. The only reference to a RevenueCat webhook in the entire repo is a comment about **PostHog** revenue events ([WingmanApp.swift:462](Wingman/WingmanApp.swift:462)) — that webhook, if configured, targets PostHog, not Supabase, and PostHog is an analytics sink, not a queryable gate.
- `hasCompletedPaywallFlow` is best-effort mirrored to Supabase `user_metadata` ([AuthManager.swift:535-542](Wingman/Auth/AuthManager.swift:535) comment). That flag means *"has seen and passed the paywall,"* not *"is paying"* — `effectivePaywallFlowCompleted` ([:552-554](Wingman/Auth/AuthManager.swift:552)) is explicitly `hasCompletedPaywallFlow || hasActiveSubscription`, i.e. every user who dismissed the paywall sets it too. **It is not a subscription signal and must never be used as one.**

RevenueCat *does* hold authoritative server-side state and exposes both a REST API and webhooks. Nothing in this project consumes either.

### C.3 Can a pre-auth device token be tied to the post-auth subscriber record?

**Split answer, and the split is the whole point.**

**On the primary path — yes, reliably.** The architecture is unusually good here, deliberately so:

- The Supabase `user_id` is minted at "Get started," *before* onboarding ([LandingView.swift:109-111](Wingman/Landing/LandingView.swift:109) → [AuthManager.swift:1810-1817](Wingman/Auth/AuthManager.swift:1810) → [:1758](Wingman/Auth/AuthManager.swift:1758)).
- `adoptGuestIdentity()` ([AuthManager.swift:1612-1652](Wingman/Auth/AuthManager.swift:1612)) immediately points **PostHog** ([:1635](Wingman/Auth/AuthManager.swift:1635)) and **RevenueCat** ([:1651](Wingman/Auth/AuthManager.swift:1651)) at that same id, with a deferred-application path for the RevenueCat-not-yet-configured race ([:1644-1648](Wingman/Auth/AuthManager.swift:1644) → [:1686-1692](Wingman/Auth/AuthManager.swift:1686), drained at [WingmanApp.swift:438](Wingman/WingmanApp.swift:438)).
- Account creation **preserves the id**: `linkIdentityWithIdToken` attaches the provider to the existing row rather than creating a new user ([AuthManager.swift:2586-2597](Wingman/Auth/AuthManager.swift:2586)); `promoteGuestToPermanent` logs *"id preserved"* ([:2657-2666](Wingman/Auth/AuthManager.swift:2657)).

So a token captured **at or after step 2 of the onboarding sequence** keys to an id that never changes through purchase, account creation, and beyond. The identity fragmentation named in the brief is a solved problem on this path — the comment at [AuthManager.swift:1605-1611](Wingman/Auth/AuthManager.swift:1605) states the invariant directly, and supersedes the older accepted-gap note at [RevenueCatManager.swift:85-89](Wingman/Payment/RevenueCatManager.swift:85).

**On three secondary paths — no. Plainly, no.**

1. **Legacy-anonymous (no session at all).** When `guestSessionsEnabled` is off ([FeatureFlags.swift:59](Wingman/Util/FeatureFlags.swift:59)) or bootstrap fails, the user runs onboarding *and the paywall* with no Supabase user ([WingmanApp.swift:355-380](Wingman/WingmanApp.swift:355)). A purchase here attaches to a RevenueCat `$RCAnonymousID`. There is no id to key a token to, and no join available later.
2. **Create-Account-first.** Guest bootstrap is fired only by "Get started"; the comment at [AuthManager.swift:1812-1814](Wingman/Auth/AuthManager.swift:1812) states that users who tap "Create Account" *should never get a guest row*. A token captured on `LandingView` — before any branch is chosen — has no id.
3. **`identityAlreadyExists` link failure** ([AuthManager.swift:2598-2601](Wingman/Auth/AuthManager.swift:2598)). The user's Apple/Google identity already belongs to another account, the link throws, and they remain a guest on a **different** id from the subscriber record that holds their entitlement.

**Bottom line: a token captured after the guest session lands is reliably associable. A token captured before it, or on the legacy path, is not — and the legacy path can reach the paywall.**

### C.4 Failure modes that would deliver a non-subscriber notification to a paying subscriber

Each with the code path that permits it.

| # | Failure mode | Code path |
|---|---|---|
| **1** | **Server has no subscription state to consult.** Any backend send is blind by construction. | Absence across `supabase/migrations/*.sql` and `supabase/functions/`; no `.from()` on any subscription table (§B.4, §C.2) |
| **2** | **Purchase completed with no Supabase user.** Entitlement lands on `$RCAnonymousID`; no id exists to mark as subscribed. | [WingmanApp.swift:369-373](Wingman/WingmanApp.swift:369) — legacy-anonymous branch renders `PaywallView` with no session |
| **3** | **Remote push cannot be suppressed client-side.** A device-side `if !hasActiveSubscription` gate runs *after* APNs has already displayed the notification. Only a *local* notification is cancellable on device. | `hasActiveSubscription` is a `@Published` on `AuthManager` ([:214-218](Wingman/Auth/AuthManager.swift:214)) with no server mirror; no `UNUserNotificationCenterDelegate` exists to even intercept ([WingmanApp.swift:22-43](Wingman/WingmanApp.swift:22)) |
| **4** | **Purchase→send race.** Conversion flips state on device only; `updateSubscriptionStatus` posts a local `NotificationCenter` message ([SubscriptionManager.swift:296](Wingman/Payment/SubscriptionManager.swift:296)) that propagates nowhere off-device. A queued send fires against stale state. | [SubscriptionManager.swift:206-273](Wingman/Payment/SubscriptionManager.swift:206), [AuthManager.swift:506-543](Wingman/Auth/AuthManager.swift:506) |
| **5** | **Identity-link failure orphans the subscriber record.** Token is on guest id A; entitlement is on account id B. | [AuthManager.swift:2598-2601](Wingman/Auth/AuthManager.swift:2598) |
| **6** | **Cross-device / Family Sharing.** The entitlement follows the Apple ID; a token registered on device A under one guest id says nothing about device B. The cache is explicitly documented as device-scoped. | [SubscriptionManager.swift:41-48](Wingman/Payment/SubscriptionManager.swift:41) |
| **7** | **Shared device / second account.** `cached_subscription_active` is global and is *not* in the per-user clear list — `clearCurrentUser()` removes `goal_notifications` and `daily_reading_goal` but not the subscription cache keys. A second user inherits the first's cached "active." | [SupabaseManager.swift:63-83](Wingman/Supabase/SupabaseManager.swift:63) vs. [SubscriptionManager.swift:47-48](Wingman/Payment/SubscriptionManager.swift:47) |
| **8** | **Stale-cache cold start.** `loadSubscriptionCache()` sets `hasCheckedAtLeastOnce = true` from cache alone ([:352](Wingman/Payment/SubscriptionManager.swift:352)), so gates answer before any network check. Correct for its purpose (avoids paywalling a paying user offline), but it means the device's own answer is provisional for the first seconds of every launch. | [SubscriptionManager.swift:330-355](Wingman/Payment/SubscriptionManager.swift:330) |

**Modes 1–2 and 4–7 are all specific to remote push. For local notifications, only mode 8 applies, and it fails safe:** a stale cache errs toward "active," which *suppresses* the notification rather than sending it.

### C.5 Is "never notify a subscriber" guaranteeable?

**With local notifications: yes, today, with no backend work.**

The guarantee holds because scheduling and cancellation both happen on the device that owns the authoritative answer:

- `hasActiveSubscription` updates on every RevenueCat customer-info change ([SubscriptionManager.swift:278-297](Wingman/Payment/SubscriptionManager.swift:278) posts unconditionally — see the comment at [:283-295](Wingman/Payment/SubscriptionManager.swift:283) explaining why it is not transition-gated), on a 5-minute timer ([:359-370](Wingman/Payment/SubscriptionManager.swift:359)), and on every foreground ([WingmanApp.swift:101-105](Wingman/WingmanApp.swift:101)).
- `RootView` already observes it ([WingmanApp.swift:663-666](Wingman/WingmanApp.swift:663)).
- Cancellation is synchronous and local ([NotificationManager.swift:104-109](Wingman/Util/NotificationManager.swift:104)).
- The one residual gap — a notification *already delivered* before the purchase completes — is already handled: `clearNotificationBadgeAndDelivered()` calls `removeAllDeliveredNotifications()` ([:138](Wingman/Util/NotificationManager.swift:138)) and runs both on launch ([WingmanApp.swift:596](Wingman/WingmanApp.swift:596)) and on every foreground ([:98](Wingman/WingmanApp.swift:98)).

**With remote push: no. Not today, and not with any amount of client-side code.**

To make it guaranteeable, all five of the following must exist. None do:

1. **Push Notifications capability + APNs auth key**, and the `aps-environment` entitlement (§B.2).
2. **A `device_tokens` table** keyed on `auth.uid()` with RLS, written only after a session exists — which, per §C.3, means after guest bootstrap, never on `LandingView`.
3. **A RevenueCat webhook → Supabase receiver** maintaining a subscription-state table (`user_id`, `is_active`, `expires_at`, `updated_at`), so entitlement changes are visible server-side within seconds rather than never.
4. **A sender that joins the two and excludes active entitlements at dispatch time**, re-reading state at send rather than at enqueue — closing failure mode 4.
5. **A reconciliation for the sessionless paths.** Either eliminate them (retire the legacy-anonymous branch at [WingmanApp.swift:355-380](Wingman/WingmanApp.swift:355), which its own comment says disappears in "Phase H"), or accept that users who purchased without a Supabase id are unreachable-and-unexcludable and therefore must never be enrolled at all.

**Recommendation implied by this section, stated plainly: build the feature on local notifications.** It satisfies the stated requirement exactly, it is the only design where the guarantee is real rather than aspirational, and it requires zero backend, zero entitlement changes, and zero new provisioning. Remote push buys reach the app does not currently need and costs a guarantee the brief treats as non-negotiable.

---

## Part D — Where the prompt should go

### D.1 Recommendation: a new screen, appended as step 10, after `SocialProofScreen` and before the paywall

**A new screen is required.** No existing screen is a defensible host:

- `LoadingScreen` ([Screens/LoadingScreen.swift](Wingman/Onboarding/Screens/LoadingScreen.swift)) is a fixed ~6.2s animation with no user input — a permission prompt over it is the definition of an arbitrary interruption.
- `GrowthProjectionScreen` and `SocialProofScreen` are narrative payoff beats that ask nothing and store nothing ([OnboardingFlow.swift:119-139, 154-181](Wingman/Onboarding/OnboardingFlow.swift:119)); bolting a permission onto either destroys the beat.
- `CommitmentPactView` is behind `commitmentPactEnabled`, which is **off by default** ([WingmanApp.swift:253-255](Wingman/WingmanApp.swift:253)). Hosting the permission there makes the entire feature contingent on an unrelated flag.
- `SettingsSheet` is where the *opt-out* belongs, not the ask — a first-run permission that only fires if someone opens Settings will reach almost nobody.

**Placement:** a new `StepType` case appended to `extendedOnboardingSteps` ([OnboardingFlow.swift:41-182](Wingman/Onboarding/OnboardingFlow.swift:41)) after the `.socialProof` entry, rendered from `OnboardingView.screenContent(for:)` ([OnboardingView.swift:209-253](Wingman/Onboarding/OnboardingView.swift:209)). The terminal handoff moves from `handleSocialProofContinue()` ([:751-753](Wingman/Onboarding/OnboardingView.swift:751)) to the new screen's continue, which then calls `finishOnboarding()` ([:757-763](Wingman/Onboarding/OnboardingView.swift:757)).

This slot exists structurally already. `.socialProof` is documented as *"the one step that comes after `.loading`, which is what makes it the step that ends onboarding"* ([OnboardingFlow.swift:154-158](Wingman/Onboarding/OnboardingFlow.swift:154)), and `handleLoadingComplete()` already contains the generic forward-check that makes appending safe ([OnboardingView.swift:736-743](Wingman/Onboarding/OnboardingView.swift:736)).

### D.2 What the screen should ask, and why the framing raises grant rate

**Ask for a reminder time, not for permission.** Headline in the shape of *"When should Wingman check in?"*, with three or four time chips (e.g. Morning / Midday / Evening / Night), one pre-selected. The primary button commits the choice **and** triggers `requestAuthorization`. A secondary "Not now" exits without touching the system prompt.

Three reasons this beats a bare permission ask:

1. **It converts a permission into a plan the user authored.** The system alert then reads as confirmation of a decision already made, not as an interruption. This is precisely Apple's own guidance: *"Make the request in a context that helps people understand why your app needs authorization… Sending the request in context provides a better experience than automatically requesting authorization on first launch, because people can see the purpose your apps notifications serve."* (https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
2. **It lands on accumulated commitment.** By this point the user has given a name, four answers about a genuinely uncomfortable subject, watched a growth curve built from those answers ([OnboardingFlow.swift:119-123](Wingman/Onboarding/OnboardingFlow.swift:119)), and seen social proof. Naming a time is the smallest possible next step, and it is consistent with everything they just did.
3. **It produces a usable value even on denial.** The chosen hour is worth storing regardless — it replaces the hardcoded 09:00 at [NotificationManager.swift:81-85](Wingman/Util/NotificationManager.swift:81) and gives you an in-app reminder surface for users who said no.

**One binding constraint on the copy, per Guideline 5.1.2(i):** the screen must offer nothing in exchange. No XP, no extra trial days, no unlocked lesson. "Not now" must lead to exactly the same next screen as "Set my reminder."

### D.3 Before or after the paywall? **Before.**

The tension in the brief is real: users who convert immediately are the ones you never want to notify, so asking them first looks wasteful. It resolves decisively toward *before* anyway, for four reasons:

1. **After the paywall, you only ever ask people who just declined to pay.** Converters skip past. Everyone who reaches a post-paywall prompt does so seconds after refusing a purchase — the worst emotional moment in the entire flow for a permission ask, and the one that most reliably produces a reflexive dismissal. Because denial is permanent (§A.4), that dismissal is not recoverable. You would be spending the one-shot prompt on your *least* receptive audience, by design.
2. **Asking a converter costs nothing.** They grant, the gate suppresses everything, no notification is ever sent. An unused authorization has no downside — no policy exposure, no user-visible effect.
3. **Churn is the case that decides this.** A subscriber who lapses in month three is the single highest-value re-engagement target the app has, and `handleCustomerInfoUpdate` already detects that transition with a `churn_type` split ([SubscriptionManager.swift:227-267](Wingman/Payment/SubscriptionManager.swift:227)). If you never asked them, you have no channel at the exact moment you most need one — and you cannot ask retroactively. Asking after the paywall permanently forecloses your best future audience to protect against a cost that is zero.
4. **Placing it before the paywall creates no compliance risk** provided skip is free (§D.2), because 5.1.2(i) prohibits *conditioning access* on the permission, not *sequencing* the ask before a purchase screen.

The gating rule the brief asks for is enforced at *send* time, not at *ask* time. Conflating the two is what makes the placement look like a trade-off; it isn't one.

### D.4 Soft pre-permission screen before the system prompt? **Yes — and the screen in D.1 is it.**

Do not build two screens. The reminder-time screen *is* the soft ask: it carries the value explanation, the consent language, and the affirmative action, and its primary button is what calls `requestAuthorization`.

This matters more here than in a typical app because of the one-shot rule (§A.4). Without a soft ask, a reflexive "Don't Allow" costs the channel forever. With one, a user who is not interested taps "Not now" and **never reaches the system prompt at all** — leaving the single system prompt unspent and available for a genuinely in-context re-ask later (after a first logged approach, or on first streak). That preservation is the entire reason the soft ask earns its screen.

**Complication that must be handled:** as established in §B.3, the system prompt is already reachable from the Settings toggle ([SettingsSheet.swift:194-206](Wingman/Profile/SettingsSheet.swift:194)). A returning user may have spent it. The new screen must read `notificationSettings().authorizationStatus` before rendering and skip itself entirely when the status is not `.notDetermined` — the same check `requestPermission` already performs at [NotificationManager.swift:21-22](Wingman/Util/NotificationManager.swift:21).

### D.5 Where the 4.5.4 artifacts must live

Both are required (§A.3).

**Consent language — on the new screen from D.1.** Immediately above the primary button, as visible body copy the user affirms by tapping it. Requirements: states what will be sent (practice reminders), states the cadence (daily, at the chosen time), legible without scrolling, not hidden behind a disclosure or a link. It must be *your* UI — the iOS system alert does not satisfy "consent language displayed in your app's UI" because its text is Apple's.

**In-app opt-out — the existing Settings toggle.** [SettingsSheet.swift:177-207](Wingman/Profile/SettingsSheet.swift:177), "Goal Notifications." The location is already correct and already reachable without leaving the app. Two changes are needed for it to satisfy the guideline in substance:

1. **It must actually stop delivery.** Today it calls `removePendingNotificationRequests` ([NotificationManager.swift:104-109](Wingman/Util/NotificationManager.swift:104)), which is sufficient for local notifications and sufficient for the recommended design. If remote push is ever added, this toggle must additionally clear the server-side token or flag, or the opt-out becomes cosmetic.
2. **Its label and the notification copy must describe Wingman.** "Goal Notifications" driving a `"Daily Reading Reminder"` ([NotificationManager.swift:75-76](Wingman/Util/NotificationManager.swift:75)) is not a recognizable opt-out for a feature the user consented to as practice reminders. A reviewer comparing the consent screen to the settings control will not match them.

---

## Appendix — Undetermined

**A. Live Supabase schema and deployed edge functions for project `bnckmgnysfliiypvxxii`.**
Checked: all four files in `supabase/migrations/`, both directories in `supabase/functions/`, every `.from(` call site in the Swift sources, and every edge-function invocation. The available Supabase MCP connection lists only project `rdgtvavltiqmwfzcadcv` ("Clera-App"), a different account or organization, so the live Wingman database could not be enumerated. Missing: confirmation that no device-token table, subscription table, or push-sending edge function was created directly in the dashboard without a committed migration. **Confirm in the Supabase dashboard before the implementation prompt.**

**B. Whether a RevenueCat webhook is configured in the RevenueCat dashboard, and its destination.**
Checked: every `webhook` reference in the repo — one comment at [WingmanApp.swift:462](Wingman/WingmanApp.swift:462) describing PostHog revenue events, and one in `docs/second-chance-paywall-plan.md:207`. Missing: the RevenueCat dashboard's webhook configuration. If one already points at PostHog, redirecting or duplicating it to a Supabase receiver is item 3 of §C.5's list rather than net-new work.

**C. Production grant/denial rate for the existing Settings-toggle prompt.**
The instrumentation exists and is correct — `notification_permission_result` with `granted`, `was_prompted`, `prior_status`, `source` ([NotificationManager.swift:31-37](Wingman/Util/NotificationManager.swift:31), [Analytics.swift:193](Wingman/Util/Analytics.swift:193)). Missing: the PostHog query. This determines how much of the install base has already spent its one-shot prompt (§D.4) and is worth running before implementation.
