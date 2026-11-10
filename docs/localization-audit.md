# Wingman localization audit

Date: 2026-11-10 · Scope: `Wingman/` (123 Swift files, ~31.8k lines), `supabase/`, project settings · Build audited: 1.14 (37), branch `Shat` at `09b4700`.

Read-only audit. No source, asset, project setting or Supabase data was changed. Paths are relative to the repo root. Line numbers are from the commit above.

Severity: **BLOCKER** = would break data, analytics, revenue or compliance · **HIGH** = visible breakage · **MEDIUM** · **LOW**.
"Req N" refers to the 14 requirements in the audit brief.

Coverage: sections B, C and H were audited call by call. A, D, E, F, I and J were audited by pattern search plus reading the hits. G is **partial**: the live Wingman database could not be reached, so it rests on the app's queries and the 7 migration files in the repo.

---

## 1. Executive summary

**Readiness: not ready.** The app has no localization infrastructure and, more importantly, uses English display text as data in four places. Translating strings before those are fixed would silently corrupt analytics and switch off personalisation, with no crash and no error to warn anyone.

12 BLOCKER findings, which reduce to 4 root causes.

**Top 5 risks**

1. **Onboarding answers are stored and sent as English display text (BLOCKER).** The option label is the stored value. It is written to UserDefaults, the PostHog person properties `onboarding_<key>`, and Supabase `user_metadata` (`age`, `goals`). 18 of the 43 saved PostHog insights reference `onboarding_` properties. Translating an option creates a new value per language in every one of them. (B-1, C-1, C-4)
2. **App logic switches on that same English text (BLOCKER).** The paywall's personalised ticks and the day 1/3/7 reminder notifications match the stored answer against English literals. A translated answer falls through to the generic default, so personalisation disappears without any visible fault. (C-2, C-3)
3. **Content titles are sent as analytics property values (BLOCKER).** `lesson_name`, `category`, `lesson_title`, `course_title`, `previous_course_title`, `scenario_name`, `headline` and `level_name` carry display text. Stable IDs already travel alongside most of them, but the text values would fork per language. (B-2 to B-6)
4. **Paywall price and disclosure text is assembled by hand (BLOCKER).** The weekly price is computed in code and formatted with the device region, not the product's currency. The one-time offer's legal line is built from English fragments ("year", "6 months"). The "3-day Free Trial" badge is a literal, not read from StoreKit. (E-1, H-4, H-5)
5. **About 840 hardcoded strings and several layouts with no room to grow (HIGH).** Roughly 146 are SwiftUI literals that would extract automatically; roughly 693 are plain `String` values that will not. Onboarding and scenario answer buttons are capped at two lines, the legal footers are single-row stacks, and paywall ticks are hand-fitted to 36 characters. (A, F)

**What already holds**

- Scenario branching, quiz scoring, XP awards and course locking all run on IDs, flags and indexes, not text (Req 6, 7).
- RevenueCat product and entitlement IDs are constants; no display text is sent to RevenueCat. Meta events use standard event names with currency and product ID only (Req 8).
- Privacy and Terms buttons use two constants and closures; nothing keys off the label. Both URLs return HTTP 200 (Req 12).
- Bundled fonts cover every European Latin language, plus Cyrillic and Greek.
- The 8 runtime illustrations that were opened contain no words.

---

## 2. Findings

### A. Hardcoded user-facing strings

**A-1 · No localization resources exist · HIGH · Req 9**
No `.xcstrings`, `.strings`, `.stringsdict` or `.lproj` anywhere in the repo. Every string is an inline literal.

**A-2 · String inventory · HIGH · Req 9**
Counts come from a heuristic scan (comments, `log()`, analytics calls and `#Preview` blocks excluded). Treat them as ±10%.

- **Direct SwiftUI literals: ~146.** `Text("…")`, `Button("…")`, `.alert("…")`, `TextField("…")` and similar. These take a `LocalizedStringKey` and would be picked up by a String Catalog.
- **Indirect `String` literals: ~693.** Held in view models, copy enums, arrays and error types, then shown through `Text(variable)` (106 such call sites). These are **not** extracted automatically and display verbatim.

| Area | Direct | Indirect | Notes |
|---|---|---|---|
| Home | 7 | 135 | 120 are the quotes in `Home/Quotes.swift` |
| PracticeGame | 13 | 102 | ~74 are the mock scenario in `PracticeGame.swift:776+` (see Open Question 6) |
| Profile | 52 | 46 | Settings, approach list, stats header |
| Payment | 17 | 74 | Paywall, offer, purchase errors, `PaywallCopy` |
| Onboarding | 9 | 76 | Questions, options, statistics, social proof |
| LogApproch | 12 | 50 | Level names, confidence labels, guide sheet |
| Auth | 5 | 51 | Mostly error messages in `AuthManager` |
| Courses | 4 | 51 | 44 are the course catalog in `CourseCategory.swift:60+` |
| Util | 0 | 33 | Notification copy |
| DailyPractice | 7 | 17 | |
| Other (XP, Quiz, Lesson, Walkthrough, Commitment, Landing, root, Resources, Supabase, Common, Splash) | 20 | 58 | |

Representative examples:

| Kind | Location | Text |
|---|---|---|
| Tab titles (indirect) | `Home/MainTabView.swift:234-252` | "Home", "Courses", "Scenarios", "Profile" |
| Button (direct) | `Landing/LandingView.swift:80` | "Get started" |
| Onboarding question (indirect) | `Onboarding/OnboardingFlow.swift:82` | "What brought you to Wingman?" |
| Paywall headline (indirect) | `Payment/PaywallCopy.swift:32` | "Day 1 of becoming the guy who goes for it" |
| Alert title (direct) | `Profile/ApproachesLoggedListView.swift:162` | "Delete Approach" |
| Alert title (ternary) | `Profile/SettingsSheet.swift:471` | "Delete my data" / "Delete Account" |
| Placeholder (direct) | `LogApproch/LogApproachBottomSheet.swift:182` | "E.g. Approached at Cafe" |
| Placeholder (direct) | `Profile/EditProfileSheet.swift:89`, `Onboarding/Screens/NameScreen.swift:56` | "Enter your name", "Your name" |
| Accessibility (direct) | `Landing/LandingView.swift:51`, `Payment/PaywallView.swift:595`, `Commitment/CommitmentPactView.swift:173` | Image description, "Close paywall", "Commit" |
| Error shown to user (indirect) | `Payment/PurchaseFailure.swift:93-139` | 10 purchase failure messages |
| Error shown to user (indirect) | `Payment/PaywallViewModel.swift:441,612,700,721,743` | "Please select a subscription plan" … |
| Notification (indirect) | `Util/NotificationManager.swift:80-81` | "Daily Reading Reminder" + body |
| Notification (indirect) | `Util/MarketingNotifications.swift:180-221` | 15 reminder lines |
| Walkthrough (indirect) | `Walkthrough/WalkthroughOverlayView.swift:191-244` | "Tap to continue", "Start filling it" … |
| Unused legacy | `Resources/AppStrings.swift:11-23` | 8 onboarding strings |

**A-3 · Only 5 accessibility labels exist app-wide · LOW · Req 9**
All five are English literals (list above plus `Payment/OneTimeOfferView.swift:89`).

**A-4 · System and server error text shown raw · MEDIUM · Req 9**
`error.localizedDescription` is assigned straight to user-visible state in `DailyPractice/DailyPracticeViewModel.swift:87`, `PracticeGame/PracticeViewModel.swift:175,336,373`, `PracticeGame/PracticeDetailViewModel.swift:40,55`, `Auth/AuthManager.swift:2502-2521,2652-2717`. System errors will arrive in the device language while app and SDK errors stay English, giving mixed-language alerts.

### B. Analytics and attribution

About 130 capture/screen call sites were read. Full table in section 3.

**B-1 · `onboarding_<key>` person properties carry the answer text · BLOCKER · Req 5**
`Onboarding/OnboardingView.swift:535,549`. The value is the selected option label (multi-select joined with ", "). Source strings: `Onboarding/OnboardingFlow.swift:84-91,109,122,132,142-149,161-167`. Keys affected: `onboarding_motivation`, `_age`, `_last_approach`, `_approach_frequency`, `_barriers`, `_goals`. 18 of 43 saved insights reference these.

**B-2 · `lesson_name` and `category` on lesson and quiz events · BLOCKER · Req 5**
`Lesson/LessonView.swift:28-33` and `Lesson/LessonQuizFlowView.swift:91-97`. Values are `lesson.title` and `lesson.courseTitle` from the bundled lesson JSON. Events: `lesson_started`, `lesson_completed`, `lesson_quiz_started`, `lesson_quiz_completed`, `lesson_quiz_abandoned`, `lesson_quiz_unavailable`. `lesson_id` is sent alongside. No saved insight references `lesson_name` today.

**B-3 · `lesson_title`, `course_title`, `previous_course_title` on gate events · BLOCKER · Req 5**
`Courses/CourseDetailSheet.swift:145-150` (`lesson_gate_blocked`) and `:200-205` (`course_locked_encountered`). `lesson_id`, `course_id`, `category_id` are sent alongside; there is no ID for the previous course.

**B-4 · `scenario_name` on scenario events · BLOCKER · Req 5**
`PracticeGame/PracticeGame.swift:321-331`. Value is the scenario title from Supabase. `scenario_id` is sent alongside.

**B-5 · `headline` on commitment pact events · BLOCKER · Req 5**
`Commitment/CommitmentPactView.swift:114,223`. Value is the generic headline sentence from `Commitment/CommitmentPactCopy.swift:34`. One saved insight references `headline`.

*Correction, 2026-11-10:* an earlier version of this finding said the personalised variant puts the user's first name in the property. It does not. The code sends `pact.headline`, never the rendered headline, and PostHog shows a single value for both personalised and generic events (1,277 events over 90 days). The finding stands as a display-text value, without the name concern.

**B-6 · `level_name` on `approach_logged` · BLOCKER · Req 5**
`LogApproch/LogApproachViewModel.swift:167`. Value is the level title from `:27-30`. `approach_level` (integer) is sent alongside.

**B-7 · `intro_price` and `full_price` are formatted price strings · MEDIUM · Req 5**
`Payment/OneTimeOfferViewModel.swift:248-249`. Values such as "$49.99" or "59,99 €". They already vary by storefront today; no numeric amount or currency code is sent.

**B-8 · `error_message` carries `error.localizedDescription` · MEDIUM · Req 5**
`Payment/PaywallViewModel.swift:751`, `Payment/OneTimeOfferViewModel.swift:360`, `LogApproch/LogApproachViewModel.swift:218`, `Profile/SettingsSheet.swift:618`. Also `reason: String(describing: error)` at `XP/XPStore.swift:262`. Once the app declares more languages, system error text arrives in the device language and these values fragment.

**B-9 · No locale super property · MEDIUM · Req 5**
The only registered super property is `environment` (`Util/Analytics.swift:386-391`). PostHog's automatic `$locale` currently reads "en" for every user and will start varying once the app supports other languages. Nothing records device language or storefront on events.

**B-10 · Screen names are stable literals · LOW · Req 5**
16 `.trackScreenView("…")` calls pass plain `String` constants ("Home", "Paywall", "Course Detail", …) and `Auth/AuthView.swift:65-72` returns fixed identifiers. They are not localized today. They must stay plain strings; 7 saved insights filter on screen name.

**B-11 · Meta SDK events: no display text · PASS · Req 8**
`.completedRegistration` with `registrationMethod` (`Auth/AuthManager.swift:676`); `.startTrial` / `.subscribe` with `valueToSum`, `currency`, `contentID` = product identifier (`Payment/PaywallViewModel.swift:565-575`, `Payment/OneTimeOfferViewModel.swift:304-311`). All inputs come from StoreKit or constants. The `.startTrial` standard event is what Meta reports as Start Trial.

**B-12 · RevenueCat: no attributes or metadata sent · PASS · Req 8**
Only `Purchases.configure` and `Purchases.shared.logIn(userID)` (`Payment/RevenueCatManager.swift:90,104,157,161`). Product, entitlement, offering and package IDs are constants in `Resources/Constants.swift:13-25` / `Payment/RevenueCatConfig.swift`. The `plan` event value is derived from product IDs (`Payment/PaywallViewModel.swift:454-456`).

### C. Logic depending on text

**C-1 · An onboarding option string is both label and stored value · BLOCKER · Req 5, 7**
Root cause of B-1, C-2, C-3, C-4.
- Options defined as display strings: `Onboarding/OnboardingFlow.swift:84-167`.
- Selection tracked by option text: `Onboarding/Screens/QuestionScreen.swift:106`.
- Stored under `onboarding_<key>`: `Onboarding/OnboardingAnswerStore.swift:37`.
- Multi-select joined with ", " and restored by splitting on ", ": `Onboarding/OnboardingView.swift:535,873`. A translated option containing ", " would split into phantom selections; a stored English answer would not match translated options on resume.
- A typo fix is already handled by a display-label map keyed by the stored value (`Onboarding/OnboardingStep.swift:72-78`), which shows the team has hit this coupling before.

**C-2 · Paywall ticks switch on the English answer · BLOCKER · Req 7**
`Payment/PaywallCopy.swift:52-66` (barriers) and `:68-82` (goals), reading `onboarding_barriers` / `onboarding_goals` from UserDefaults at `:41-42`. Unmatched text returns the generic line.

**C-3 · Reminder notifications switch on the English answer · BLOCKER · Req 7**
`Util/MarketingNotifications.swift:176-192` (motivation), `:194-209` (barriers), `:211-222` (goals), reading at `:165-166`.

**C-4 · Supabase `user_metadata` receives answer text · BLOCKER · Req 5, 6**
`age` and `goals` are written as display strings: `Auth/AuthManager.swift:1844-1850` (anonymous sync) and `:1913-1930` (`syncAgeRangeToBackend`), fed from `Onboarding/OnboardingView.swift:566-590`.

**C-5 · Statistic screens switch on the age label · MEDIUM · Req 7**
`Onboarding/Statistics/StatisticContent.swift:36-58` matches "18-24", "25-34", "35-44". Safe only while the age options stay byte-identical in every language (for example no en dash).

**C-6 · Sign-out decision uses keywords in localized error text · HIGH · Req 7**
`Auth/AuthManager.swift:1307` (`contains("Timeout")`), `:1342-1344` (network keywords), `:1349-1351` (auth keywords: "unauthorized", "invalid", "expired", "token" …). The second and third decide whether a failed session check signs the user out (`:1310-1313`). System errors are localized by iOS once the app declares the language, so the English keywords stop matching. The `NSURLErrorDomain` code check at `:1325-1338` covers most network cases first.

**C-7 · Daily practice category display names · LOW · Req 14**
`DailyPractice/DailyPracticeQuestion.swift:22-28` maps stable raw values to English names. Logic uses the raw values; only display is affected.

**C-8 · Verified ID-based (no finding) · PASS · Req 6, 7**
- Scenario branching: `nextSceneId`, `defaultNextScreenId`, `retryTargetScreenId`, the `"complete"` sentinel, `isCorrect` flag (`PracticeGame/PracticeGame.swift:106-107,124,177-199,223,235`).
- Quiz scoring: `correct_answer_index` / `correct_answer_indices` and `question_type` raw values (`Lesson/LessonQuestionService.swift:48,107-110`, `DailyPractice/DailyPracticeServiceProtocol.swift:146-156`). Translations must keep option **order** identical.
- XP: `source_type` + `source_id` (`XP/XPStore.swift`, `supabase/migrations/20260812130331_xp_award_breakdown.sql`).
- Course thumbnails and lesson files: keyed by course ID (`Courses/CoursesView.swift:422-454`, `Home/HomeViewModel.swift:206+`, `Lesson/LessonDataService.swift:34`).
- No comparison, sort or lookup on `title`, `name` or `text` fields was found anywhere.

### D. Concatenation, plurals, interpolation

**D-1 · Manual plural for "lesson(s)" · HIGH · Req 3, 10**
`PracticeGame/PracticeDetailView.swift:25-27` and `PracticeGame/PracticeCardView.swift:25-27`: noun chosen by `n == 1`, then assembled as `"\(n) \(noun)\(suffix)"`.

**D-2 · Duration phrase fragments · see H-4 · Req 3, 10**
`Payment/StoreProduct+IntroDiscount.swift:85-91` returns "year", "2 years", "month", "6 months" for insertion into other sentences.

**D-3 · Verb fragment inserted into a sentence · HIGH · Req 3**
`LogApproch/LogApproachViewModel.swift:208`: `"Failed to \(action). Please try again."`

**D-4 · Count-in-sentence strings with no plural handling · MEDIUM · Req 10**

| Location | String |
|---|---|
| `XP/CompletionScreen.swift:394` | `"1 day streak"` / `"\(n) day streak"` |
| `XP/CompletionScreen.swift:405-406` | `"Level \(n) reached."` / `"Level \(n)"` |
| `XP/XPStore.swift:63` | `"1 correct"` / `"\(n) correct"` |
| `Profile/ApproachesLoggedListView.swift:292-296` | "Today" / "1 day ago" / `"\(days) days ago"` |
| `Profile/ProfileView.swift:274` | `"Save your \(approachCount) approaches"` |
| `Profile/ProfileStatsHeader.swift:51,53` | `"Level \(l) · \(x) XP to Level \(l+1)"` |
| `Util/NotificationManager.swift:81` | `"… Your goal is \(goalMinutes) minutes today."` |
| `PracticeGame/PracticeDetailView.swift:155` | `"\(detail.duration) minutes"` |
| `Courses/CourseDetailSheet.swift:279` | `"\(lesson.duration) min"` |
| `Profile/SettingsSheet.swift:184`, `Profile/DailyReadingGoalSheet.swift:78` | `"\(goal) min / day"` |
| `Payment/OneTimeOfferViewModel.swift:84` | `"\(months)-month Plan"` |

**D-5 · Sentences split across views or built with `+` · MEDIUM · Req 3**

| Location | What |
|---|---|
| `Auth/AuthView.swift:345-367` | "By continuing you agree to our" + "Terms" + "and" + "Privacy" as four separate texts (see H-2) |
| `Landing/LandingView.swift:98-100` | "Already have an account?" + "Log in" |
| `Payment/PaywallView.swift:715,737,1015` | `"only " + price` then `"… per week"` (see E-1) |
| `Payment/OneTimeOfferView.swift:235-236` | `"off your first \(phrase)"` / `"for your first \(phrase)"` |
| `Courses/CourseDetailSheet.swift:217` | `"Complete all lessons in \(previousTitle) to unlock this course."` |
| `Commitment/CommitmentPactCopy.swift:57` | `"I, \(name), am becoming a guy who takes action."` |
| `Home/HomeView.swift:535` | `"\(categoryName): \(courseName)"` |
| `LogApproch/ApproachLevelGuideSheet.swift:154`, `Profile/ApproachesLoggedListView.swift:262,271` | `"Level \(n): \(title)"`, `"Level \(n)"`, `"Confidence: \(n)/10"` |

**D-6 · Error prefix + raw message · MEDIUM · Req 3, 9**
`Payment/RevenueCatManager.swift:318-324`, `DailyPractice/DailyPracticeServiceProtocol.swift:432-440`, `Auth/AccountDeletionModels.swift:32-34`, `Auth/AuthManager.swift:2521,2659,3011,3035`, `Profile/SettingsSheet.swift:721`, `PracticeGame/PracticeServiceProtocol.swift:350`. Pattern: `"Purchase failed: \(message)"` where the message is a system, SDK or server string.

### E. Prices, dates, numbers

**E-1 · Weekly price is computed in code and formatted with the device region · BLOCKER · Req 11**
`Payment/PaywallView.swift:997-1015`. Price ÷ 52 (or ÷ 4.33), formatted with `Locale.current`, prefixed with the literal "only ", fallback literal "$0.00". Shown on both plan rows (`:715,737`). Two issues: the figure does not come from StoreKit, and when device region differs from the storefront it prints the storefront's amount with the device's currency symbol. This exists today and is independent of translation.

**E-2 · Per-month price is derived, not from StoreKit · MEDIUM · Req 11**
`Payment/OneTimeOfferViewModel.swift:93-103`. Intro price ÷ months. It does use the product's own formatter locale, so the currency is right.

**E-3 · "3-day Free Trial" is a literal · HIGH · Req 11, 13**
`Payment/PaywallView.swift:719,741`. Trial length is not read from the product's introductory offer. The local StoreKit config does define 3-day free trials (`Wingman/storekitconfig.storekit`), so it is accurate today, but nothing keeps it accurate.

**E-4 · Hardcoded dollar fallbacks · LOW · Req 11**
`Payment/PaywallView.swift:1015` and `Payment/PaywallViewModel.swift:138` (`"$0.00"`); `currencyCode ?? "USD"` at `Payment/PaywallViewModel.swift:563` and `Payment/OneTimeOfferViewModel.swift:308`. Code comments say these paths are unreachable once offerings load. `Payment/PlanRow.swift:98-111` has dollar literals in a `#Preview` only.

**E-5 · StoreKit-sourced prices (no finding) · PASS · Req 11**
`localizedPriceString` for plan prices (`Payment/PaywallViewModel.swift:114,118`), intro price (`Payment/StoreProduct+IntroDiscount.swift:97`), full price (`Payment/OneTimeOfferViewModel.swift:62`); zero price from the product's own formatter (`Payment/PaywallViewModel.swift:134-140`); savings percent computed from real prices.

**E-6 · Fixed display date format · MEDIUM · Req 11**
`Profile/ApproachesLoggedListView.swift:299-300,306-307`: `dateFormat = "MMM d, yyyy"`. Month names follow the device, but the order and comma are US.

**E-7 · Machine date keys formatted without a fixed locale or calendar · MEDIUM · Req 11**
`DailyPractice/StreakStore.swift:145-146,222-223,257-258` and `DailyPractice/DailyPracticeServiceProtocol.swift:409-411` build `yyyy-MM-dd` keys with a default `DateFormatter`. `Home/HomeViewModel.swift:301-303` and `XP/XPSource.swift:62-67` do pin `en_US_POSIX`. On Gregorian European devices the output is the same; a device set to a non-Gregorian calendar would produce different keys for streaks and daily practice.

**E-8 · Hand-built number formats · LOW · Req 11**
`Home/HomeView.swift:564` (`"\(n)%"`), `Payment/OneTimeOfferView.swift:224` (`"\(percent)%"`), `:287` (`"Claim \(n)% off"`), `Profile/SettingsSheet.swift:387` (`"V \(version)"`). Percent spacing and position differ by language.

**E-9 · ISO 8601 timestamps and `.formatted()` (no finding) · PASS**
All `ISO8601DateFormatter` uses are for storage or analytics. Every `.formatted()` call is inside `log()`.

### F. Layout risk

Mitigating factor: Dynamic Type is capped at `.large` app-wide (`Util/View+DynamicType.swift`), so text growth comes only from translation.

**Ranked: most likely to break at +40% text length**

| # | Screen | Why | Severity | Req |
|---|---|---|---|---|
| 1 | Paywall | Ticks hand-fitted to 36 characters so the last one stays above the plan cards (`Payment/PaywallCopy.swift:17-19`). Plan row puts title+price and price+period in one row with no line limit or scaling (`Payment/PlanRow.swift:39-63`). Three footer links share one row inside 60pt side padding (`Payment/PaywallView.swift:933-986`). CTA is a fixed 52pt (`:888`). | HIGH | 2, 12, 13 |
| 2 | One-time offer | Same three-link footer (`Payment/OneTimeOfferView.swift:301-313`); 12pt letter-spaced "ONE-TIME OFFER" (`:182`); 22–26pt "off your first year" line (`:235`); fixed 52pt CTA (`:291`). The big price is the one place that already scales down (`:231-232`). | HIGH | 2, 12 |
| 3 | Onboarding questions | Option buttons capped at 2 lines (`Onboarding/Screens/QuestionScreen.swift:84`). Longest English option is 45 characters; longer translations lose their ending. | HIGH | 2 |
| 4 | Scenario game | Answer options capped at 2 lines (`PracticeGame/PracticeGame.swift:728`). Text comes from Supabase; a truncated option hides the choice being made. | HIGH | 2 |
| 5 | Sign-in | Legal footer is a single row of four texts that cannot wrap as a sentence (`Auth/AuthView.swift:343-372`); fixed 44pt buttons (`:223`). | HIGH | 2, 12 |
| 6 | Home | Fixed card heights 200 and 280 (`Home/HomeView.swift:161,457`); fixed 52/56/50pt buttons (`:149,198,483`). | MEDIUM | 2 |
| 7 | Profile | "Create a free account" in a fixed 40pt button (`Profile/ProfileView.swift:304`); level line limited to 1 line at 0.85 scale (`Profile/ProfileStatsHeader.swift:145-146`). | MEDIUM | 2 |
| 8 | Scenario list and detail | Title 2 lines, summary 3 lines, beside a fixed 70×110 image (`PracticeGame/PracticeCardView.swift:40,61,73`). | MEDIUM | 2 |
| 9 | Courses | Course title 2 lines with tail truncation (`Courses/CoursesView.swift:400-401`); course name 1 line in the lesson header (`Lesson/LessonView.swift:170-171`). | MEDIUM | 2 |
| 10 | Tab bar | 10pt label, 1 line, `fixedSize()` so it overflows its slot instead of truncating (`Home/MainTabView.swift:343-347`). | MEDIUM | 2 |

**F-11 · Fixed-height single-line buttons throughout · MEDIUM · Req 2**
Pattern `.frame(height: 52)` on a text label: `Landing/LandingView.swift:84`, `DailyPractice/DailyPracticeView.swift:231`, `PracticeGame/PracticeView.swift:262`, `PracticeGame/PracticeDetailView.swift:220`, `Quiz/QuizQuestionView.swift:314,342`, `LogApproch/LogApproachBottomSheet.swift:295`, `Profile/EditProfileSheet.swift:127`, `Profile/DailyReadingGoalSheet.swift:128`, `Profile/SettingsSheet.swift:416`, `XP/CompletionScreen.swift:295`, `CommonComponents/ErrorViewScreen.swift:56`. Only two views in the app use `minimumScaleFactor`.

**F-12 · Text in images · LOW (partial) · Req 2**
Opened and checked: `paywall_1`, `landing_what_if`, `onboard_img_1`, `stat_frequency`, `stat_never_approached`, `stat_regret`, `stat_success`, `checklist`. None contain words; `paywall_1` shows the numeral "1" on a calendar. Not opened: the 25 course thumbnails, `Invite_Friends`, the logo assets, and remote images loaded from Supabase URLs (Open Question 10).

### G. Supabase content (partial)

**G-1 · User-facing text columns · MEDIUM · Req 6**
From app queries and migrations only.

| Table / RPC | Text fields | App code |
|---|---|---|
| `questions` | `question_text`, `options` (JSON array of strings), `explanation` | `Lesson/LessonQuestionService.swift:107-121` |
| RPC `get_or_create_daily_questions` | same fields per question | `DailyPractice/DailyPracticeServiceProtocol.swift:136-157` |
| `scenarios` | `title`, `summary`, `woman_name`, `cover_image_url` | `PracticeGame/Practice.swift:25-29`, `PracticeServiceProtocol.swift:121-127` |
| RPC `get_scenario_screens` | `text`, `image_url`, options `{id, text, next_screen_id, is_correct, order_index}` | `PracticeGame/PracticeServiceProtocol.swift:238-266` |
| `practice_details`, `practice_steps` | `content`, `title`, `description` | `PracticeGame/Practice.swift:177-197`, `PracticeServiceProtocol.swift:178-185` |
| `lessons` (reference mirror) | `category_name`, `course_title`, `lesson_title` | Not queried by the app; `supabase/migrations/20260730000000_create_lesson_questions.sql:17-24` |
| `course_categories`, `courses` | `name`, `title`, `description` | Fetch is commented out (G-2) |
| `approach_logs` | `title`, `notes` | User-written; not translatable content |
| `auth.users.user_metadata` | `age`, `goals` (answer text), `country`, `currency`, `display_name` | C-4; **no locale field** |

**G-2 · The course catalog and lesson bodies are not in Supabase · HIGH · Req 6**
Requirement 6 assumes Supabase holds the canonical English content. In practice:
- Course and category titles come from a hardcoded Swift array, `CourseCategory.dummyCategories` (`Courses/CourseCategory.swift:60+`), used by `Courses/CoursesViewModel.swift:68`, `Home/HomeView.swift:48,324` and `Home/HomeViewModel.swift:132-136,192`. The Supabase fetch is commented out (`Courses/CoursesViewModel.swift:78+`).
- Lesson bodies are 25 bundled JSON files (~36,800 words, 492 KB) loaded with `Bundle.main.url(forResource:)` (`Lesson/LessonDataService.swift:87`).
- The same titles therefore exist in up to four places: the Swift catalog, the lesson JSON (`courseTitle`), the `lessons` table, and the `courses` tables.

**G-3 · Lesson question cache is not language-aware · HIGH · Req 4, 9**
`fetchAllLessonQuestions` downloads every lesson question in one request (`Lesson/LessonQuestionService.swift:112-121`). The result is cached on disk and considered current while the fingerprint `count:latest updated_at` is unchanged (`:124-139`, `Lesson/LessonQuestionStore.swift:138-192,233-236`). Neither the cache file nor the fingerprint includes a language. Consequences: after a device language change the old-language cache still reads as current, and if translations are added as rows the single download grows with every language.

**G-4 · How each fetch would take a locale filter with English fallback · MEDIUM · Req 4, 6, 9**

| Fetch | Fit |
|---|---|
| Lesson JSON from bundle | Clean. `Bundle` resolves localized resources and falls back to the development language by itself. In-memory cache is per course ID. Progress keys use lesson IDs (`LessonDataService.swift:217,221`). |
| `scenarios` (direct select of all columns, no client cache) | Needs a join or view for translated columns with fallback; IDs untouched. |
| `get_scenario_screens(p_scenario_id)` | RPC has no language parameter. Screen and option IDs carry the branching, so text can vary independently. |
| `get_or_create_daily_questions(p_user_id, p_date)` | RPC has no language parameter. Function body is not in the repo (Open Question 2). |
| `questions` (all at once, cached) | See G-3. |
| Course catalog | Not a fetch (G-2). |

**G-5 · Server-generated text that reaches users · MEDIUM · Req 9**
- Edge Function `delete-user-account` returns English messages (`supabase/functions/delete-user-account/index.ts:101-171,362`). The app shows the `error` field: `Auth/AuthManager.swift:2928-2936` → `Profile/SettingsSheet.swift:721`.
- Postgres `raise exception` messages in the XP functions are developer-facing; they reach analytics (`XP/XPStore.swift:262`), not the UI.
- Push notifications: none server-side. All notifications are scheduled locally; the entitlements file has no push capability.
- `pg_cron`: none in the repo's migrations. Live database unverified.
- Auth emails: email sign-up exists (`Auth/AuthService.swift:17`), so Supabase's email templates are in play. They are configured in the dashboard, not the repo (Open Question 3).

**G-6 · Local notifications freeze their text when scheduled · MEDIUM · Req 9**
`Util/MarketingNotifications.swift:102-103` and `Util/NotificationManager.swift:80-81` assign plain strings. The day 1/3/7 reminders are scheduled once and the daily reminder repeats, so a later language change is not reflected. `localizedUserNotificationString` is not used anywhere.

### H. Legal links and paywall

**H-1 · Privacy and Terms links · PASS · Req 12**
- URLs: `Resources/Constants.swift:28-29` (`https://www.getwingman.app/privacy`, `/terms`). Both return HTTP 200.
- Buttons: paywall `Payment/PaywallView.swift:935-944,974-983` → `Payment/PaywallViewModel.swift:687,762`; one-time offer `Payment/OneTimeOfferView.swift:303,311,332`; sign-in `Auth/AuthView.swift:348-369`; settings `Profile/SettingsSheet.swift:331-355`.
- All open an in-app Safari sheet from a closure. No code matches on the label, so translating labels cannot break the action.
- The destination pages are English-only (Open Question 17).

**H-2 · Sign-in legal sentence is four fragments in one row · HIGH · Req 2, 3, 12**
`Auth/AuthView.swift:343-372`. Word order cannot change per language, and a longer sentence compresses or truncates the two tappable labels.

**H-3 · Paywall and offer footers: three links in one fixed row · HIGH · Req 2, 12**
`Payment/PaywallView.swift:933-986`, `Payment/OneTimeOfferView.swift:301-313`. 60pt padding each side leaves about 255pt on a 375pt phone for "Privacy", "Restore", "Terms". German equivalents will not fit on one line at 12pt.

**H-4 · One-time offer disclosure is built from English fragments · BLOCKER · Req 3, 10, 13**
`Payment/OneTimeOfferView.swift:203`:
`"\(introPrice) billed today for your first \(introDurationPhrase), then \(fullPrice)/\(renewalPeriodPhrase). Cancel anytime in App Store settings."`
The two phrases are English words produced in code (`Payment/StoreProduct+IntroDiscount.swift:85-91`). The sentence itself can be translated as a unit, but the inserted "year" / "6 months" cannot, and their grammatical form is fixed. This is the offer's only renewal disclosure.

**H-5 · "3-day Free Trial" literal · HIGH · Req 13** — see E-3.

**H-6 · Inventory of disclosure text**

Main paywall (`Payment/PaywallView.swift`):

| Element | Source | Location |
|---|---|---|
| Plan titles "Yearly Plan" / "Monthly Plan" | Literal | `:714,736` |
| Plan price | StoreKit `localizedPriceString` | `PaywallViewModel.swift:114,118` |
| "per year" / "per month" | Literal | `:717,739` |
| "only {weekly} per week" | Computed in code + literals | `:715,737,997-1015` (E-1) |
| "3-day Free Trial" badge | Literal, gated on StoreKit trial eligibility | `:719,741` |
| CTA "Try for {zero price}" / "Continue" | Literal + product formatter | `:846-851` |
| "No payment now. Cancel anytime before your trial ends." | Literal | `:786` |
| "Billed immediately. Cancel anytime in App Store settings." | Literal | `:787` |
| Privacy / Restore / Terms | Literals | `:941,963,979` |

One-time offer (`Payment/OneTimeOfferView.swift`):

| Element | Source | Location |
|---|---|---|
| Intro price, full price | StoreKit | `OneTimeOfferViewModel.swift:59,62` |
| "{n}%" saving | Computed from the two StoreKit prices | `:224` |
| "off your first {phrase}" / "for your first {phrase}" | Literal + code fragment | `:235-236` |
| Disclosure sentence | Literal + 2 StoreKit prices + 2 code fragments | `:203` (H-4) |
| "Close this and it's gone for good" | Literal | `:260` |
| CTA "Claim {n}% off" / "Claim my discount" | Literal | `:287` |

Observation: the main paywall has no sentence stating that the subscription renews automatically or what is charged after the trial; price and period appear only in the plan row (Open Question 8).

### I. Fonts

**I-1 · Manrope: sufficient for European languages · PASS**
Bundled and registered: `Wingman/Fonts/Manrope-{Regular,Medium,SemiBold,Bold}.ttf` (679 code points each), via `UIAppFonts` in `Wingman/Info.plist`. Used through `Util/Font+Manrope.swift:12-37` across the whole app. Character maps were read directly from the files:

| Script | Result |
|---|---|
| Western and Nordic Latin (de, sv, no, da, fi, fr, es, it, pt, nl) incl. € „ " « » | Complete |
| Central and Eastern Latin (pl, cs, sk, hu, ro, hr, tr) | Complete |
| Cyrillic, Greek, Vietnamese | Complete |
| CJK, Kana, Hangul, Arabic, Hebrew | Absent (iOS would substitute a system font) |

**I-2 · Georgia Italic · PASS**
`Util/Font+Manrope.swift:40-44`, a system font. Covers Latin, Cyrillic, Greek; not Vietnamese.

**I-3 · Poppins styles reference a font that is not bundled · LOW**
`Resources/App.swift:14-29` defines `Font.App` using Poppins. Poppins is not in the bundle or `UIAppFonts`. No call site uses `Font.App`, so it is dead code.

### J. Existing localization config

| Item | State | Location |
|---|---|---|
| Development region | `en` | `Wingman.xcodeproj/project.pbxproj:153` |
| Known regions | `en`, `Base` | `:155-158` |
| String Catalog / `.strings` / `.lproj` | None | — |
| `LOCALIZATION_PREFERS_STRING_CATALOGS` | `YES` (project level) | `:253,312` |
| `SWIFT_EMIT_LOC_STRINGS` | `YES` (target) | `:354,393` |
| `STRING_CATALOG_GENERATE_SYMBOLS` | `YES` | `:258,316,351,390` |
| Info.plist | Generated + `Wingman/Info.plist`; no `CFBundleLocalizations`, no `CFBundleDevelopmentRegion`, no usage-description strings | `:333-334` |
| Project structure | File-system-synchronized groups | `:40-49,115` |
| In-app language picker or override | None (`AppleLanguages`, `.environment(\.locale)`, custom bundles: no matches) | — |
| Right-to-left handling | None | — |
| StoreKit test config | `en_US` / USA storefront only | `Wingman/storekitconfig.storekit` |
| Deployment target | iOS 16.6 (target) | `:342,381` |

**J-1 · Greenfield configuration · LOW**
The build settings needed for a String Catalog are already on. Nothing conflicts with adding languages. Because `$locale` in PostHog currently resolves to "en" for everyone, its values will change the moment a second language is declared (B-9).

---

## 3. Analytics impact table

Only properties whose value is, or derives from, display or locale-dependent text. Every other property on these events is already a constant, number, boolean or ID.

| Event(s) | Property | Current value source | Risk | Proposed stable ID |
|---|---|---|---|---|
| Person `$set` | `onboarding_motivation`, `onboarding_barriers`, `onboarding_goals` (multi-select, ", "-joined) | Option label, `OnboardingFlow.swift:84-91,142-149,161-167` | BLOCKER. 18/43 insights use `onboarding_*` | Per-option key (e.g. `breakup`, `freeze`, `fear_rejection`); list property, not a joined string |
| Person `$set` | `onboarding_last_approach`, `onboarding_approach_frequency` | Option label, `:122,132` | BLOCKER | Per-option key (e.g. `past_week`, `never`) |
| Person `$set` | `onboarding_age` | Option label "18-24" … "55+", `:109` | MEDIUM (numeric; safe only if never translated) | Keep current strings as the fixed IDs |
| `lesson_started`, `lesson_completed`, `lesson_quiz_*` | `lesson_name` | `lesson.title` from bundled JSON | BLOCKER | `lesson_id` (already sent) |
| same | `category` | `lesson.courseTitle` from bundled JSON | BLOCKER | `course_id` (available on `Lesson`, not currently sent) |
| `lesson_gate_blocked` | `lesson_title`, `course_title` | Lesson JSON / Swift catalog | BLOCKER | `lesson_id`, `course_id` (already sent) |
| `course_locked_encountered` | `course_title`, `previous_course_title` | Swift catalog | BLOCKER | `course_id` (sent); add `previous_course_id` |
| `practice_scenario_started`, `_completed` | `scenario_name` | Supabase `scenarios.title` | BLOCKER | `scenario_id` (already sent) |
| `commitment_pact_viewed`, `_committed` | `headline` | Fixed generic sentence (never includes the name) | BLOCKER. 1 insight | Variant key; `personalized` boolean already sent |
| `approach_logged` | `level_name` | Level title, `LogApproachViewModel.swift:27-30` | BLOCKER | `approach_level` integer (already sent) |
| `paywall_viewed` (one-time offer) | `intro_price`, `full_price` | StoreKit formatted strings | MEDIUM (varies by storefront today) | Numeric amount + ISO currency code |
| `paywall_purchase_*`, `purchases_restore_failed`, `approach_log_failed` | `error_message` | `error.localizedDescription` | MEDIUM | Error domain + code (already sent on some events) |
| `xp_award_failed` | `reason` (queued case) | `String(describing: error)` | LOW | Error code |
| `$screen` | `$screen_name` | Plain string constants | LOW (stable today; 7 insights) | Keep as non-localized constants |
| All events | `$locale` (automatic) | Resolves to "en" for all users today | MEDIUM (starts varying) | Add explicit device-language and app-language super properties |

Unaffected and verified: every event name (all constants), `plan`, `product_id`, `source`, `offer`, `question_key`, `screen_key`, `step`, `source_type`, `trigger`, `reason` (enumerated cases), `method`, `churn_type`, Meta event names and parameters, RevenueCat identifiers.

---

## 4. Effort estimate

Estimate only. S = days, M = about a week, L = multiple weeks. Excludes translation itself.

| Section | Effort | Driver |
|---|---|---|
| A. Strings | L | ~840 strings, most of them not auto-extractable |
| B. Analytics | M | 6 blocker properties plus continuity of 18 existing insights |
| C. Text-dependent logic | M | One root cause (answer IDs) touching 5 files and stored user data |
| D. Concatenation and plurals | M | ~30 sites |
| E. Prices, dates, numbers | S | ~8 sites, concentrated in the paywall |
| F. Layout | M | 10 screens; needs on-device checking per language |
| G. Supabase content | L | Schema for 5–6 content sources, 2 RPCs, cache, plus deciding the canonical home for course titles |
| H. Legal and paywall | S | 3 layouts and 1 disclosure sentence |
| I. Fonts | S | No work for European languages |
| J. Config | S | Settings already in place |

---

## 5. Open questions

1. **Live Supabase state.** The database connector available to this audit reaches a different account. Actual columns, row counts, RPC bodies, `pg_cron` jobs and region for the Wingman project are unverified.
2. **Daily question sets.** `get_or_create_daily_questions` and `generate_daily_question_set` are referenced but their bodies are not in the repo. Do stored daily sets reference question IDs or copy text?
3. **Auth emails.** Which Supabase email templates are active (confirmation, reset), and in what language?
4. **Scope of "module names" (Req 14).** Does it cover the 5 category names only, or also the 25 course titles, 94 lesson titles, the 4 approach level names, and tab names such as "Scenarios" and "Daily Practice"? This decides how much of B-2 to B-6 remains a problem.
5. **Onboarding answer IDs and history.** Should the existing English strings (including the deliberate "embarrased" misspelling) remain the stored values so PostHog history is continuous, or should new IDs be introduced and old values mapped?
6. **Mock scenario.** `MockData.barWindow` is the default argument at `PracticeGame/PracticeGame.swift:335` and is returned at `PracticeGame/PracticeServiceProtocol.swift:381`. Can a real user ever see it?
7. **Canonical source for course titles.** Swift catalog, lesson JSON, `lessons` table or `courses` table? Is the commented-out Supabase course fetch meant to come back?
8. **Main paywall disclosure.** There is no auto-renewal or post-trial price sentence on the main paywall. Is that intentional? It affects what "complete" means for Req 13 before any translation.
9. **Ternaries of string literals.** `Text(cond ? "a" : "b")` and `.alert(cond ? "a" : "b", …)` (for example `XP/CompletionScreen.swift:394`, `Profile/SettingsSheet.swift:471`): whether these resolve to the localizable overload can only be confirmed by compiling, which this audit did not do.
10. **Unopened images.** 25 course thumbnails, `Invite_Friends`, logo assets, and remote scenario and cover images served from Supabase URLs were not checked for embedded text.
11. **Target languages.** European Latin languages need no font or direction work. Anything beyond that changes sections F and I.
12. **Trial length.** Is 3 days guaranteed for both products in every storefront? The badge is shown for the monthly plan too when StoreKit reports eligibility.
13. **App Store Connect and RevenueCat dashboards.** Subscription display names, offering metadata and RevenueCat customer attributes set outside the app were not inspected.
14. **Notification language policy.** If the device language changes after reminders are scheduled, should pending reminders be rescheduled?
15. **Legal pages.** Should non-English users be sent to translated Privacy and Terms pages? Both current pages load, but their HTML title reads "Page Not Found".
16. **`growth-command-centre` and `wingman-revenue-receiver`.** A search of the dashboard's `lib`, `app` and `components` found no consumer of the affected Wingman properties. Neither sibling project was audited further.
17. **`C-6` reach.** Which errors actually arrive at `isAuthenticationError` in production (Supabase SDK errors are English regardless of device language; system errors are not)? This decides whether C-6 is a real sign-out risk or theoretical.
