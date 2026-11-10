# Localization progress log

Working log for Release A of [localization-implementation-plan.md](localization-implementation-plan.md). Branch: `localization-release-a`. Updated at the end of every work slice.

## Status

| Package | State | Notes |
|---|---|---|
| Prerequisites P1, P2, P5 | Done | Commit `6acc258` |
| Prerequisite P3 | Partly done | Priced paywall, screens past the paywall and time-to-paywall still to capture |
| WP1 Onboarding answer IDs | **Done** (slice 1, `fa213f2`) | Verified on device by the slice 3 sweep. Supabase `age`/`goals` writes checked by reading the code path, not by a live write |
| WP2 Analytics values pinned to English | **Done** (slices 2–3, `9a853f0`, `38f4330`) | New properties not yet observed arriving in PostHog |
| WP3 Error classification | Not started | Plan wants a few days of production logging first; cannot be done inside this loop |
| WP4 Paywall prices and disclosure | Not started | Blocked at the end on the priced-paywall capture decision (Release run vs dev-tag launch flag) |
| WP5 String Catalog and extraction | **In progress** (slices 4–14) | `Localizable` holds 364 strings, `Content` 174. Done: onboarding, commitment, non-disclosure paywall copy, notifications, home, quotes, course catalog, approach logging, profile, settings, practice, XP, auth. Still to move: walkthrough, daily practice and quiz, lesson screen chrome, remaining error wrappers (RevenueCat, daily practice), then the fragment and number-format leftovers |
| WP6 Layout and legal links | Not started | |
| WP7 Content translation plumbing | Not started | Migration files only; nothing applied to the live database |
| WP8 Tooling and tests | Started | Unit and UI test targets exist; parity recorder, validator and fallback tests still to build |

## Slices

### Slice 1 — WP1: onboarding answers get IDs (2026-11-10)

**What changed**

- New `Wingman/Onboarding/OnboardingOption.swift`. Every onboarding answer is defined once as an enum case with three separate things: an `id` (compared in code), a `canonicalValue` (the frozen English string that is stored and sent, including the "embarrased" misspelling) and a `label` (what the user reads).
- `OnboardingStep` now holds `choices: [OnboardingOption]?`. `options` is kept as a computed list of the canonical values.
- `QuestionScreen` selects by option id and shows `label`. The typo-fix label map in `OnboardingStep` is gone; the corrected spelling lives on `BarrierOption.fearOfRejection.label`.
- `OnboardingView` turns selected ids into the stored value through `OnboardingAnswerCoding` and restores a selection the same way in reverse. The value written to UserDefaults, to the PostHog `onboarding_<key>` person property and passed on to the Supabase `age` / `goals` sync is the canonical value, joined with ", " in tap order exactly as before.
- `PaywallCopy`, `MarketingNotifications` and `StatisticContent` resolve the stored value to a typed option and `switch` on the case. No `switch` on English answer text remains (audit findings C-1, C-2, C-3, C-5).

**Behaviour for English users:** unchanged. Same labels, same stored values, same paywall ticks, reminder lines and statistics, same handling of legacy values such as "45+".

**Tests**

- `OnboardingCanonicalValuesTests` and `PersonalisationCharacterizationTests` (written before the change) pass untouched.
- New `OnboardingOptionTests`: catalog shape, id uniqueness, label vs stored value, selection ↔ stored value round trips, legacy values, and `testStoredValueDoesNotDependOnLabels`, which relabels every option as a translation would and checks the stored value is byte-identical.

**Not verified**

- No on-device run of the onboarding flow after the change (UI sweep not re-run in this slice; it is limited to once per work package).
- The Supabase `user_metadata` write was checked by reading the code path only.

### Slice 2 — WP2 part 1: analytics values read canonical fields (2026-11-10)

**What changed**

- New `Wingman/Util/AnalyticsProperties.swift`. `lesson_name`, `category`, `lesson_title`, `course_title`, `previous_course_title`, `scenario_name` and `level_name` are now built from `canonical…` accessors in one place, not read off whatever the view shows.
- Rule adopted for models (documented in that file): the existing `title` / `name` field stays the English source text; analytics reads `canonicalTitle`; translated text shown on screen must come from a separate display accessor added later, never by changing what `title` holds.
- `headline` on the commitment events now reads `CommitmentPactCopy.analyticsHeadline`, a literal separate from the on-screen headline.
- `CourseLockReason.awaitingPrevious` carries the previous course's id and canonical title alongside the banner title.
- New properties (additive): `course_id` on lesson and lesson-quiz events; `previous_course_id` on `course_locked_encountered`.
- New super properties (additive), registered with `environment` and restored after every reset: `app_language`, `device_language`. `storefront` is registered when the paywall already asks StoreKit for it and is cached in UserDefaults; no new StoreKit call was added.

**Behaviour for English users:** every pre-existing property keeps its value.

**Tests:** new `AnalyticsPropertiesTests` (11). `testLessonNamesAndCategoriesMatchProductionBaseline` loads all 94 bundled lessons and checks `lesson_name` and `category` against the PostHog baseline (fixture `WingmanTests/Fixtures/lesson-analytics-baseline.json`). Course titles are checked against the 16 locked-course rows seen in production, including the "Small talk" / "Small Talk" difference between the two sources. 44 tests pass.

**Corrections to earlier docs:** the audit (B-5) and the analytics baseline said the personalised commitment headline sends the user's first name. It does not; both are corrected.

**Not verified**

- The new super properties have not been observed arriving in PostHog (no app run in this slice).
- `storefront` only appears after a paywall has loaded offerings once on that install; a Debug build cannot load offerings, so it cannot be checked without a Release run.
- Nothing yet proves the canonical accessors ignore a translation, because no translation mechanism exists. **WP5 must add a test with a fake translation table** showing that `canonicalTitle`, `analyticsHeadline` and the option `canonicalValue`s do not change when display strings do.

### Slice 3 — WP2 part 2: prices, error identity, screen names (2026-11-10)

**What changed**

- `Analytics.Screen`: the 17 screen names are now constants in one place, documented as identifiers that must never be localized. All `.trackScreenView` call sites and `AuthView` use them. Values unchanged.
- `price_amount` (number) and `currency` (ISO code) added to the six purchase events on the main paywall (`paywall_purchase_started` / `_succeeded` / `_failed` ×2 / `_cancelled` ×2) and to every one-time-offer event; the offer also gets `intro_price_amount`. `price_amount` is always the product's regular price per period.
- `error_domain` and `error_code` added beside `error_message` on the four events that send it (`purchases_restore_failed` ×3, `approach_log_failed`). `error_message` itself is left as it is.
- `Analytics.properties(_:adding:)` does the merging; an existing key always keeps its value, so adding properties cannot change one an event already sends.

**Behaviour for English users:** every pre-existing property keeps its value. Additions only.

**Tests:** new `AnalyticsScreenNameTests` (10). 54 unit tests pass.

**On-device check (the one sweep for WP1 + WP2):** `OnboardingSweepTests` passed on the iPhone 17 Pro throwaway simulator from a clean install. Compared with the baseline screenshots, ignoring the status bar: 15 of 17 screens are pixel-identical, including the paywall with its two personalised ticks. The two loading-screen frames differ by under 0.03% of pixels, in the animated step rows (capture timing). This run created one guest user in production Supabase.

**Not verified**

- The new properties (`price_amount`, `currency`, `intro_price_amount`, `error_domain`, `error_code`, `course_id`, `previous_course_id`, `app_language`, `device_language`, `storefront`) have not been looked up in PostHog. The purchase ones cannot fire in a Debug build.
- The iPhone SE sweep was not re-run.

**Tooling note:** the screenshot comparison was an inline script. It should become a checked-in tool under WP8.

### Slice 4 — WP5 part 1: the lookup layer (2026-11-10)

**What changed**

- New `Wingman/Util/L10n.swift`. `L10n.content(_:)` takes an English data string and returns what to show for it. In the source language it returns the input untouched with no table lookup. In a translated app it looks the string up in the `Content` table, keyed by the English text, and falls back to English when the entry or the whole table is missing, or the translation is empty.
- Onboarding option labels now go through it: each option has an `englishLabel`, and `label` is that passed through `L10n.content`. `canonicalValue` is untouched.

**Behaviour for English users:** identical. The app ships only English, so every call takes the pass-through branch (`testAppRunsInItsSourceLanguage` pins this).

**Tests:** new `L10nContentTests` (12). They build a throwaway bundle with a German `Content` table at runtime and point `L10n` at it, which is how Release A can test translation behaviour without shipping a language. Covered: translated text returned; missing entry, empty entry and missing table all fall back to English; option labels translate while canonical values, the stored answer, the restored selection, the paywall tick and the reminder line stay exactly as for an English user; a German label is rejected as a stored value; lesson, course, level, headline and category analytics values ignore translations. 66 tests pass.

This closes the gap noted in slice 2 (nothing proved the canonical accessors ignore a translation).

**Not verified**

- No on-device run in this slice (labels are unchanged in English, and the sweep for WP5 is being saved for after strings are actually moved).
- Lookup cost in a translated app has not been measured. It only matters once a language ships.

### Slice 5 — WP5 part 2: the two String Catalogs (2026-11-10)

**What changed**

- New `Wingman/Resources/Localizable.xcstrings`: 158 UI strings, filled from the compiler's own extraction (`xcstringstool sync` over the build's `.stringsdata`), so it is exactly what SwiftUI already treats as localizable. Source language `en`, no other language.
- Seven non-linguistic keys are marked do-not-translate with a comment: the empty string, `%lld`, `%lld/400`, `+%lld`, `•`, `V %@` and the brand term `XP`.
- New `Wingman/Resources/Content.xcstrings`: hand-maintained table for strings shown through `L10n.content`. Holds the 29 onboarding option labels so far. Every later slice that routes a string through `L10n.content` must add its entry here.
- No Swift source changed in this slice.

**Behaviour for English users:** unchanged. The built app gains `en.lproj/Content.strings`, where every entry maps to itself; nothing is emitted for `Localizable` because no entry overrides its English text.

**Tests:** new `StringCatalogTests` (6): the app bundle declares only English (the guard against a language being added by accident); localized lookups, including formatted ones, return the same English text; every onboarding label has a `Content` entry; the stored-only misspelled value is not a catalog key. 72 tests pass.

**Audit Open Question 9 answered:** literal ternaries such as `Text(cond ? "1 day streak" : "\(n) day streak")` and the `.alert(cond ? … : …)` titles are extracted by the compiler ("1 day streak", "%lld day streak", "Delete my data", "Delete Account", "ON", "OFF" are all in the catalog), so they do resolve to the localizable overload.

**Things to know**

- When the project is built in Xcode (not from the command line), Xcode re-syncs `Localizable.xcstrings` itself and may rewrite or reorder the file. That is expected; commit the result.
- `Content.xcstrings` entries are marked `manual`, so Xcode will not flag or remove them.

**Not verified**

- The catalogs have not been opened in Xcode's catalog editor.
- No on-device run in this slice (no source change).

### Slice 6 — WP5 part 3: onboarding and commitment copy (2026-11-10)

**What changed**

- 47 strings that lived in models and constants are now `String(localized:)` and extracted into `Localizable.xcstrings` (205 entries): the six question titles; the loading title, subtitle and three step rows; all statistic headings, subheadings and facts; growth projection headline, bullets and chart labels ("TODAY", "IN 1 MONTH"); social proof headline, subtitle, footnote and four testimonials; commitment pact headline, body, named headline, hold instruction and "Committed.".
- The pact body was two literals joined with `+`; it is one sentence now (same text).
- The step titles for the growth-projection and social-proof steps were left as plain strings: the code comments say they are never shown.
- `CommitmentPactCopy.analyticsHeadline` stays a separate plain literal, so the displayed headline being localizable does not touch the analytics value.

**Behaviour for English users:** unchanged, verified three ways. `PersonalisationCharacterizationTests` (untouched) still passes on every statistic string. New `OnboardingCopyTests` (8) pins the rest character for character, including curly apostrophes, the em dash, literal "%" and a name containing format characters. And the on-device sweep below.

**On-device check (the one sweep for WP5):** `OnboardingSweepTests` passed on the iPhone 17 Pro throwaway simulator from a clean install. 15 of 17 screens are pixel-identical to the baseline; the two loading frames differ by about 0.01% of pixels in the animated rows, the same as in slice 3. One more guest user was created in production Supabase.

**Tests:** 80 unit tests pass.

**Known fragment left in place:** the first growth-projection bullet is drawn as a bold "3x" followed by "faster progress than watching generic advice videos" (`GrowthProjectionScreen.swift`, two strings joined so the emphasis stays inline). A translation may need different word order. It is a WP5 item-5 (fragments) fix for later.

**Not verified**

- The WP5 sweep is now used. Later WP5 slices (paywall, home, profile and so on) will rely on unit tests and on the WP6 sweep, and none of those screens are in the sweep yet anyway.
- iPhone SE was not re-run.

### Slice 7 — WP5 part 4: paywall and offer copy that is not disclosure (2026-11-10)

**What changed** (all `String(localized:)`, extracted into `Localizable.xcstrings`, now 240 entries)

- `PaywallCopy`: the headline, the closing tick and the ten personalised tick lines.
- Plan titles ("Yearly Plan", "Monthly Plan", "%lld-month Plan", "Plan") and the non-trial CTA "Continue".
- `PurchaseFailure`: both alert titles, the nine failure messages and the generic one.
- User-facing error strings set in `PaywallViewModel` (5) and `OneTimeOfferViewModel` (3), and the "An error occurred" fallbacks.
- The one-time offer's Privacy / Restore / Terms footer labels, which were plain strings passed to a helper and so were not being extracted. (The main paywall's were already literals.)

**Deliberately not touched** (they belong to WP4, prices and disclosure): "per year", "per month", the "only … per week" line, the "3-day Free Trial" badge, "Try for …", both disclosure sentences on the main paywall, and the offer's "billed today … then …" sentence and "off / for your first …" lines.

**Behaviour for English users:** unchanged. `PersonalisationCharacterizationTests` (untouched) still pins every tick line.

**Tests:** new `PaywallCopyTests` (7): the main page headline and ticks with and without stored answers; alert titles; every mapped RevenueCat error code → message and `reason`; and that `reason` (sent to analytics as `failure_reason`) is a plain identifier independent of the message. 87 unit tests pass.

**Not verified**

- No on-device run: the paywall with these strings needs loaded prices (a Release build), and the sweep for WP5 is used.
- Purchase failure alerts were not triggered for real.

### Slice 8 — WP5 part 5: notifications (2026-11-10, `041434f`)

**What changed**

- `MarketingNotifications`: the 16 reminder lines are now `LocalizedStringResource`s (`motivationResource`, `barrierResource`, `goalResource`). The existing `…Line` functions remain and return the same English strings.
- The reminder body is handed to the system as the string's key (`deliveryLocalized`, using the notification-specific localized string API), so it is localized when the notification is **delivered**. These reminders are scheduled once, up to seven days ahead, and never rescheduled; resolving the text at scheduling time would have frozen the language. The key is the English sentence, so an untranslated reminder is delivered in English.
- The title stays the literal brand name "Wingman" (`brandTitle`).
- `NotificationManager`: the daily reading reminder's title and body come from `dailyReadingText(goalMinutes:)`, localized when scheduled. That is safe because this reminder is rescheduled on every launch, and iOS relaunches the app when its language changes. The body's key carries the count, so languages that need plural forms can have them.

**Behaviour for English users:** unchanged. `PersonalisationCharacterizationTests` (untouched) still pins every reminder line.

**Tests:** new `NotificationCopyTests` (8): daily reminder text; brand title; reminder keys are the English sentences; each line matches its resource; no reminder key contains a percent sign (they are passed as format keys with no arguments); the delivery-localized body reads as English today; bodies for a user with and without stored answers. 95 unit tests pass. Catalog: 257 entries.

**Not verified**

- No notification was actually delivered. Delivery-time localization is the documented behaviour of the API, but it has not been observed on a device, in English or in another language. Worth one manual check in Release B.
- English keeps "Your goal is 1 minutes today." for a goal of 1, as before; no English plural variant was added, to keep English output identical. If a goal of 1 minute is selectable, that is a small existing grammar bug to fix on purpose later.

### Slice 9 — WP5 part 6: home screen and quotes (2026-11-10)

**What changed**

- The 120 daily quotes are shown through `Quotes.display(at:)`, which passes the English quote to `L10n.content`. `Quotes.all` stays English and is the lookup key. All 120 quotes were added to `Content.xcstrings` (149 entries now).
- The quote rotation was already tracked by index in UserDefaults, not by text, so nothing about which quote is shown, or when, changes.
- Home strings that were plain `String` values are now `String(localized:)`: the daily practice button states ("Start", "Completed", "No Connection"), the "User" name fallback (two places), and the four tab bar titles ("Home", "Courses", "Scenarios", "Profile").
- Left as they are: the five category names in `HomeView` (brand terms, decision D2).

**Behaviour for English users:** unchanged.

**Tests:** new `QuotesTests` (5): the pool is 120 unique quotes; every quote is shown as written in English; the one quote with a literal percent sign is shown literally, in English and when translated; every quote has a `Content` entry; a fake translation changes what is displayed for that quote only and never the pool. 100 unit tests pass.

**Not verified**

- The home screen was not opened on a simulator (it sits behind the paywall and is not in the sweep).
- The tab titles and button states have no direct unit test; they rely on the general `String(localized:)` checks in `StringCatalogTests`.

### Slice 10 — WP5 part 7: course catalog (2026-11-10)

**What changed**

- `Course.displayTitle` shows the course title through `L10n.content`; `Course.title` stays English and is what `canonicalTitle` (analytics) reads. The course grid, the course detail header and the Home "continue" card now use `displayTitle`.
- `CourseCategory.displayName` exists for the views but returns the English name on purpose: category names are brand terms (decision D2).
- The 25 course titles were added to `Content.xcstrings` (174 entries).
- The lock banner moved to `CourseLockReason.bannerText` and is now two complete, localizable sentences, one for a known previous course and one for an unknown one. Before, the unknown case inserted the English fragment "the previous course" into the sentence. English output is the same in both cases.
- `CourseLockReason.awaitingPrevious` now carries an optional display title (nil when unknown) next to the id and canonical title added in slice 2.
- Not touched: `Course.description` and the catalog's own `courseSummary` are never shown (the summary on screen comes from the lesson JSON, which is WP7), so they were not made translatable.

**Behaviour for English users:** unchanged.

**Tests:** new `CourseCatalogDisplayTests` (7): 25 courses in 5 categories; display titles equal the English titles; every title has a `Content` entry; both banner sentences; the view model's lock reason carries display title, id and canonical title; a fake translation changes the displayed title while `title`, `canonicalTitle` and the `course_locked_encountered` properties stay English; category names are not translated even when a translation for the same text exists. 107 unit tests pass.

**Not verified**

- The courses screen was not opened on a simulator.
- The lesson list inside a course still shows lesson titles, summaries and the course summary straight from the bundled English JSON. That is expected until WP7.

### Slice 11 — WP5 part 8: approach logging and profile (2026-11-10)

**What changed** (`String(localized:)` unless noted; catalog now 321 entries)

- `LogApproachViewModel`: notes placeholder, button and header titles, the ten confidence descriptions and the fallback, the title validation message.
- The save failure message is now two whole sentences (`saveFailureMessage(isEdit:)`: "Failed to save. Please try again." / "Failed to update. Please try again.") where a verb used to be inserted into one sentence. Same English text. (Audit D-3.)
- `ApproachLevelGuideSheet`: the four level titles, descriptions and twelve examples. `LogApproachBottomSheet`: the four level card titles. `ApproachService`: the four breakdown names, the "Level n" fallback and three error messages.
- `ProfileStatsHeader`: the level line (three variants) and the three tile labels. `ProfileView`: the share text.
- The approach list's date text moved to `ApproachDateText`. "Today", "1 day ago" and "n days ago" are localizable. For entries a week or more old, English keeps the fixed "MMM d, yyyy" form exactly as before; a translated app uses a locale-aware date (day, month, year in the order that language expects). (Audit E-6.)
- New `L10n.isSourceLanguage`, used for that one English-only branch.
- Approach level titles on the view model were left as plain English: they are only used for analytics (`level_name`) and logs, never shown.

**Left as found, on purpose:** the four places that name the approach levels use slightly different English ("Social Warm-up", "Social warm-up", and "Social Practice" for level 1 in the guide). Each keeps its current wording as its own catalog entry; unifying them would be a visible English change.

**Behaviour for English users:** unchanged.

**Tests:** new `ApproachCopyTests` (7): confidence descriptions for all ten levels and the fallback; form titles and placeholder; both failure sentences; analytics level names unchanged; relative day text; older dates keep the English format regardless of device region; in a translated app a German locale gives a day-first date with a German month. 114 unit tests pass.

**Not verified**

- None of these screens were opened on a simulator.
- The level line, tile labels, share text and guide sheet strings have no direct unit test.
- "n days ago" has no plural variants in English (it never shows 1, which has its own string). Languages with more plural forms will need them added to that catalog entry in Release B.

### Slice 12 — WP5 part 9: settings alerts (2026-11-10)

**What changed**

- New `Wingman/Profile/SettingsCopy.swift` holds the Settings screen's alert messages, which were inline literals assigned inside async handlers (not extractable, not testable): three restore-purchase messages and four account-deletion messages. `SettingsSheet` reads them from there. Also the "Unknown" version fallback.
- `SettingsCopy.deletionFailed(serverMessage:)`: when the server refuses a deletion, English keeps showing "Deletion failed: " followed by the server's text, exactly as before. In a translated app the alert shows the app's own complete sentence instead, so the Edge Function's English never appears inside a translated alert (plan WP5 item 8, audit G-5).
- `AccountDeletionError`'s descriptions were left as plain English on purpose: they go to logs and error tracking, never to the user.
- `EditProfileSheet` and `DailyReadingGoalSheet` needed nothing: all their text was already direct SwiftUI literals in the catalog.

**Behaviour for English users:** unchanged.

**Tests:** new `SettingsCopyTests` (5). 119 unit tests pass. Catalog: 326 entries.

**Apparently unused code, left alone:** `CommonComponents/ErrorViewScreen.swift` has no call sites, and `Resources/AppStrings.swift` and the Poppins styles in `Resources/App.swift` are referenced nowhere. `ErrorViewScreen`'s three strings ("Oops!", "Please try again!", "Try Again") are in the catalog because the compiler extracts them. Removing dead code was in the plan (WP5 item 10) but deleting files is not something to do unasked; see the open question below.

**Not verified**

- The Settings alerts were not triggered on a simulator. Restore and delete-account failures are hard to provoke on demand.

### Slice 13 — WP5 part 10: practice (scenarios) and XP (2026-11-10)

**What changed**

- The scenario lesson-count label ("3 lessons", "3 lessons required") moved to `PracticeCopy.lessonCountLabel(count:isLocked:)` and is the **first catalog plural** in the app: the code passes the count, and the singular ("1 lesson", "1 lesson required") comes from English plural variants in `Localizable.xcstrings`. Before, the noun was picked in code and " required" was appended (audit D-1). The built app now contains `en.lproj/Localizable.stringsdict`.
- Scenario player: the "You" name fallback (three places), the "Her" and "Feedback" speaker labels, and "Tap to retry" / "Tap to continue".
- Completion screens: "Scenario complete.", "Lesson complete.", "Daily practice complete." and the default "Continue" button title.
- XP breakdown labels in `XPStore`: "Completed", "1 correct" / "n correct", "All correct".
- `PracticeServiceError` messages, which reach the user through the practice screens' error state.
- Left as plain English: `XPError` descriptions (logs and analytics only) and the mock scenario and mock practice data.

**Behaviour for English users:** unchanged. The plural path is the one place where English now depends on the catalog, so it is pinned for counts 0, 1, 2, 5, 12 and 21, locked and unlocked.

**Tests:** new `PracticeCopyTests` (4). 123 unit tests pass. Catalog: 342 entries; `xcstringstool sync` preserved the hand-written plural variants.

**Not verified**

- The scenario list, player and completion screens were not opened on a simulator.
- Speaker labels, completion titles and the "You" fallback have no direct unit test.
- `Data error: …` still appends a developer-written detail in English after a translatable prefix. It is rare and was left that way.

### Slice 14 — WP5 part 11: sign-in (2026-11-10)

**What changed**

- `AuthView`: the header title, subtitle and reassurance line for each of the four contexts (11 strings plus "Create Account" / "Welcome Back"), and the two provider buttons with their "Signing in..." state. They were plain `String` values and so were not being extracted.
- `AuthManager`: the ten Apple sign-in failure messages, the two "Sign-in failed: …" wrappers, and the account-link conflict message (which was two literals joined with `+`; one sentence now, same text).
- New `Auth/AuthCopy.swift`. `internalFailure(_:)` decides what to show when a failure only has a developer-facing description (`GoogleSignInError`: "Unable to find root view controller"). English shows that description as before; a translated app shows the ordinary retry message. The technical descriptions themselves stay English, since they also go to the log.
- The legal sentence under the buttons ("By continuing you agree to our Terms and Privacy") is untouched: it is four fragments in a row and is a WP6 item.

**Behaviour for English users:** unchanged.

**Tests:** new `AuthCopyTests` (5). 128 unit tests pass. Catalog: 364 entries.

**Not verified**

- The sign-in screens were not opened on a simulator, and no sign-in failure was provoked.
- The per-context titles and subtitles in `AuthView` have no direct unit test (they are private to the view).
- Errors that arrive from the Google or Apple SDKs with their own `localizedDescription` are shown as the SDK gives them. Whether those SDKs translate their messages was not checked.

## Next

WP5 part 12: the remaining screens in one pass, since each has only a few indirect strings left: walkthrough overlay copy (`WalkthroughOverlayView`), daily practice and quiz chrome (`DailyPracticeView`, `DailyPracticeQuestion` category names — brand terms, `QuizQuestionView`), the lesson screen, and the error wrappers in `RevenueCatManager` and `DailyPracticeServiceProtocol`. Then a final WP5 pass over fragments and number formats (percent signs, "min / day", the "3x" bullet, "Level n: title"), after which WP6 (layout and the legal sentence) starts.

## Open questions for Arthur

- **Dates for English users outside the US:** the approach list shows "Nov 3, 2026" to every English user, including Australian and British ones (your second and fourth largest markets), because the format is fixed. I kept that unchanged, since Release A must not change what English users see. Switching English to a locale-aware date would show "3 Nov 2026" in those regions. Say if you want that; it is a one-line change.
- **Unused code:** `CommonComponents/ErrorViewScreen.swift`, `Resources/AppStrings.swift` and the Poppins font styles in `Resources/App.swift` appear to be unused. May I delete them? Otherwise the error screen's three strings stay in the catalog and get translated for nothing.
- **Priced paywall baseline:** one Release-build run (one test user in production analytics), or add a launch flag that tags automated runs as dev? Needed before WP4 can be signed off.
