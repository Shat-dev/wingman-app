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
| WP5 String Catalog and extraction | **Done except what WP4 owns** (slices 4–17) | `Localizable` 386 strings, `Content` 174. Left on purpose: paywall price and disclosure strings (WP4). A translated display title for lessons and scenarios comes with WP7 |
| WP6 Layout and legal links | In progress (slices 17–21) | Done: sign-in legal line, paywall and offer footer links, line caps, fixed-height buttons. **WP6 sweep spent** (slice 21): English unchanged on all 17 baseline screens. Pseudo-language run done (slice 22); its overflow findings fixed (slice 23). Still to do: paywall ticks and plan rows (with WP4, includes finding 5), image check |
| WP7 Content translation plumbing | Not started | Migration files only; nothing applied to the live database |
| WP8 Tooling and tests | In progress (**WP8 sweep spent**, slice 22) | Done: unit and UI test targets (189 unit tests, 5 of them pseudo-language probes that skip in a normal run), whole-screen renders in a test window for before/after checks without a sweep, onboarding sweep (now through the walkthrough and the four tabs, with a double-length pseudo-language mode), sign-in screen UI test, catalog validator (`scripts/check_string_catalogs.py`). Still to build: checked-in screenshot comparison, performance comparison, analytics parity recorder (section 9 of the plan) |

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

### Slice 15 — WP5 part 12: walkthrough and remaining error messages (2026-11-10)

**What changed**

- `WalkthroughOverlayView`: the five tour cards (multi-line strings with deliberate line breaks), the three tap hints and the three nudge lines. They were `private`; they are internal now so tests can pin them.
- `DailyPracticeViewModel`: the "Next" / "Check Answer" button title. `DailyPracticeServiceProtocol`: the "Correct answer!" / "Incorrect answer." result message and the three plain `DailyPracticeError` messages. `QuizEngine`: the "Loading..." / "Please wait..." placeholder question.
- New `L10n.withTechnicalDetail(english:translated:)` for messages that end in SDK or database text. English users get the existing message unchanged; a translated app gets a complete sentence of its own with no English tail. Used by five `DailyPracticeError` cases and the four `RevenueCatError` cases (audit D-6).
- Left as they are: the daily-practice category display names (brand terms; note they read "Conversational Skills" and "Mastery & Integration" here but "Conversation Flow" and "Integration & Mastery" in the course catalog, an existing inconsistency), and all preview and mock data.
- The lesson screen needed nothing: its own text was already direct SwiftUI literals. Lesson content is WP7.

**Behaviour for English users:** unchanged.

**Tests:** new `WalkthroughAndErrorCopyTests` (8): the five cards character for character including line breaks; hints and nudges; English keeps technical detail; a translated app gets the whole sentence and never builds the English one; daily practice and RevenueCat errors in both modes. 136 unit tests pass. Catalog: 385 entries.

**Not verified**

- The walkthrough was not run on a simulator.
- The nine new "translated app" sentences are only ever shown outside English, so nobody has seen them on screen. They are in the catalog for a translator to review.

### Slice 16 — WP5 final pass and catalog validator (2026-11-10)

**Final scan.** A scan of every Swift file for string literals that look like prose and are not localizable came back with nothing left to move. What remains is intentional:

- data looked up through `L10n.content` (quotes, course titles, option labels);
- analytics constants and canonical values;
- developer-facing error descriptions (sign-in internals, account deletion, XP, Supabase);
- brand terms (category names);
- the paywall price and disclosure strings, which WP4 owns;
- unused code (`ErrorViewScreen`, `AppStrings`, the two never-shown onboarding step titles, preview and mock data).

**Fragments and number formats.** No code change was needed:

- Percent values, "n/10", "n min", "n min / day", "Level n: title" and "category: course" are all single catalog entries with placeholders, so a translator can already reorder or re-space them.
- The bold "3x" + sentence bullet stays as two entries. Turning it into one styled sentence would mean re-rendering that line, with a real chance of a visible English difference, for little gain in European languages. Both entries now carry a comment explaining that they are joined.

**Translator comments.** 82 comments added to `Localizable.xcstrings` (91 entries have one now) for short labels, placeholders and anything ambiguous out of context: what each placeholder is, which strings are joined to others, which are brand terms, and which strings are about to be replaced by WP4 or WP6 and should not be translated yet. Comments written in the catalog survive `xcstringstool sync`.

**New tool: `scripts/check_string_catalogs.py`** (plan WP8, translation validator). Run from the repo root:

- `python3 scripts/check_string_catalogs.py` — Release A mode. Fails if any language other than English is present.
- `python3 scripts/check_string_catalogs.py --languages de` — once German exists. Also reports how many strings still fall back to English.

It checks: source language; no unexpected language; every translation keeps its English placeholders; plural variants include "other"; no empty translations; do-not-translate entries are untranslated; brand terms (Wingman, XP) survive; `Content` entries are marked manual. It was tested against six deliberately broken translations and reported all six. Current result: no problems, English only.

**Behaviour for English users:** unchanged (no Swift source changed in this slice). 136 unit tests pass.

**Not verified**

- The validator has no length limits yet (paywall ticks, tab labels, buttons). Those belong with the layout work, once WP6 has settled what the limits are.
- The catalogs have still not been opened in Xcode's editor.

### Slice 17 — WP6 part 1: the sign-in legal line (2026-11-10)

**The problem.** "By continuing you agree to our · Terms · and · Privacy" was four separate pieces in a fixed row. Every language would have been forced into English word order, and a row cannot wrap, so a longer sentence would have been squeezed or cut off.

**What changed.** The line moved out of `AuthView` into its own file, `Wingman/Auth/AuthLegalFooter.swift`, with two layouts:

- **English: the original row,** the same code moved unchanged.
- **Translated apps: one sentence** — `By continuing you agree to our [Terms](terms) and [Privacy](privacy)` — translated as a whole. The translator can move the two links anywhere in the sentence, and it wraps onto as many lines as it needs.

Both layouts open the same two pages (`getwingman.app/terms`, `/privacy`) in the same in-app browser sheet.

**Safety net for the links (requirement 12).** The sentence carries the short words `terms` and `privacy` as link targets, not web addresses, so a translator cannot damage a URL. If a translation loses a link, adds an unknown one, links the same page twice, or is not valid Markdown, the app shows the English sentence instead. The validator now also fails on any translation whose link targets differ from the English ones (tested with a planted `[AGB](agb)`: reported; a correct reordered German sentence: passes).

**Catalog.** One new entry (the sentence, with a translator comment). The two old pieces, "By continuing you agree to our" and "and", are now marked do-not-translate, since only the English layout uses them. 386 strings, 9 do-not-translate.

**New: `L10n.usesSourceLanguageLayout`,** the single switch for "keep the original English layout". Debug builds can launch with `-l10nForceTranslatedLayout YES` to see the translated-app layouts with English text; a Release build ignores it.

**Tests.** 16 new unit tests in `AuthLegalCopyTests` (152 total, all passing): the two destinations, the English sentence, link order and underlining, a reordered German sentence, six kinds of broken translation falling back to English, which layout each kind of app gets, and two rendering tests (both layouts are one line of the same height at phone width; the sentence grows to two lines at 200 pt). New UI test `AuthScreenTests` captures the voluntary sign-in screen (`18-auth-login.png` added to the 17 Pro baseline) without creating a guest user.

**Behaviour for English users:** unchanged. The row is the same code, and the voluntary sign-in screen is pixel-identical before and after this slice.

**Found along the way.** The legal line is not on the "Log in" screen reached from the landing screen. It only appears on the sign-in screens that follow the paywall or a purchase, which the onboarding sweep does not reach yet.

**Not verified**

- The legal line has not been seen inside the running app in either layout, and its links have not been tapped there: the screens that show it sit past the paywall. Both layouts were rendered and looked at off-screen in the unit tests. Extending the sweep past the paywall (already on the WP8 list) will cover this; it should happen before the WP6 sweep is spent.
- The `-l10nForceTranslatedLayout` launch flag has not been exercised yet.
- Link tap targets in the sentence layout are text-height (about 17 pt), the same as the English row's. Not changed here.

### Slice 18 — WP6 part 2: paywall and offer footer links (2026-11-10)

**The problem.** Privacy · Restore · Terms sit in a row with 60 pt of padding each side, which leaves 255 pt on an iPhone SE. The German labels need about 330 pt. Rendered in the original row they break in the middle of a word ("Wiederherstell / en", "Nutzungsbedi / ngungen").

**What changed.** New `Wingman/Payment/FooterLinksRow.swift`, used by both `PaywallView` and `OneTimeOfferView`. Each screen still passes in its own three buttons, so actions, the restore spinner and disabled states are untouched.

- **English: the original row,** same markup.
- **Translated apps** take the first of these that fits: the same row with 60 pt padding; the same row with 20 pt padding; the three links stacked and centred.

**Tests.** 7 new unit tests in `FooterLinksRowTests` (159 total, all passing). The row is rendered off-screen and compared pixel for pixel:

- the English row equals a copy of the pre-change markup at 375, 402 and 440 pt wide;
- the adaptive row with English labels equals the English row (a translated app with short labels looks the same);
- German labels stay on one 44 pt row at 375, 402 and 440 pt;
- the German labels are measured to be wider than the original row's inner width on an SE and narrower than the 20 pt-padded row;
- labels too long for any row stack (132 pt tall).

**Behaviour for English users:** unchanged, by the pixel comparison above. No string changed; the catalog is the same.

**Not verified**

- Neither footer has been looked at in the running app since this change. The paywall is the last screen of the onboarding sweep, so the WP6 sweep will compare it with the baseline. The one-time offer is past the paywall and is not covered until the sweep is extended.
- The stacked fallback makes the footer 88 pt taller. On the paywall that pushes into a fixed-height layout; no European language I measured needs it on a current phone, so I have not checked what the paywall does with the extra height.

### Slice 19 — WP6 part 3: line caps (2026-11-10)

**Inventory.** The app has 13 `lineLimit` sites. Six hold text that will be translated and would be cut with "…" when the translation is longer. The rest are already safe (no cap, already shrink, or user-written notes).

| Where | English (unchanged) | Translated app |
|---|---|---|
| Scenario answer buttons (`OptionsContentView`) | 2 lines | No cap; the button grows; the list scrolls if it no longer fits |
| Tab bar labels | 1 line at natural size | 1 line inside its quarter of the bar, shrinking to 70% |
| Scenario card title and summary | 2 and 3 lines | No cap (the card is in a scrolling list and grows) |
| Course tile title | 2 lines | 3 lines, shrinking to 85% |
| Lesson title under a lesson | 1 line | 1 line, shrinking to 75% |
| Onboarding question subtitle | 2 lines | No cap (no question has a subtitle today) |

Left alone: onboarding answer buttons (they already grow, inside a scroll view), the one-time-offer price and profile stat labels (already shrink), approach notes (the user's own text, capped on purpose).

**How.** One new modifier, `lineLimit(_:whenTranslated:shrinkingTo:)` in `Wingman/Util/View+TranslatedTextFit.swift`. In English it resolves to the same `.lineLimit(n)` the call site had and a scale factor of 1, SwiftUI's default.

**Checked against real content.** The longest English scenario answer in the database is 72 characters; it fits in two lines at iPhone SE width, so English answers are not being cut today. A German-length version of the same answer needs four lines and was cut mid-sentence by the two-line cap.

**Tests.** 10 new unit tests in `TranslatedTextFitTests` (169 total, all passing):

- the rule in both modes;
- English pixel comparisons against copies of the pre-change markup: a capped text at 1, 2 and 3 lines; the tab bar at 375 and 402 pt; the scenario answer list at SE, 17 Pro and Pro Max widths;
- a translated answer list is taller than the capped one (nothing cut);
- on a short screen the translated list scrolls (drawn in a real window: first answer shown from the top, list continues past the bottom edge), and with room to spare it does not;
- long translated tab labels render inside a 320 pt bar.

**Behaviour for English users:** unchanged, by the pixel comparisons above. No string changed.

**Not verified**

- None of these six has been looked at inside the running app since the change. Scenario answers, cards, course tiles and the tab bar are all past the paywall, which the sweep does not reach yet.
- Course tile, lesson title and question subtitle have no test of their own beyond the shared modifier's.
- A course tile that grows to three lines is taller than its neighbour in the same grid row. I have not looked at how that row lines up.

### Slice 20 — WP6 part 4: fixed-height buttons (2026-11-10)

**Inventory.** 74 fixed-height frames in the app. 22 of them are button labels holding translated text, at 40, 44, 50, 52 or 56 pt. The rest are images, progress bars, spacers and icon tap targets. A label that wraps to a third line inside a fixed 52 pt was cut with "…".

**What changed.** New modifier `labelHeight(_:)` (same file as the line-cap rule), applied to all 22 by replacing `.frame(height: N)` with `.labelHeight(N)`:

- **English:** `.frame(height: N)`, the same call as before.
- **Translated apps:** N is a minimum. A long label shrinks to 85%, then wraps centred, and the button grows around it with 6 pt above and below and 12 pt at the sides. A label that fits on one line gives a button of exactly N, as in English.

The 22: landing "Get started" and "Log in"; home daily practice, "Log Approach" and course card "Open"; daily practice and scenario "Try Again"; "Start Practice"; sign-in "Not now"; paywall purchase and retry buttons; one-time offer claim button; approach sheet save; quiz "Next" and "Check Answer"; edit profile and reading goal "Save"; both "Create a free account" buttons; "Log Out"; name screen "Skip"; completion screen continue.

Left alone: the onboarding "Next" button (sized by padding, already grows), the scenario speaker-name row (a name, 25 pt), `ErrorViewScreen` (unused code).

**Tests.** 5 new unit tests in `LabelHeightTests` (174 total, all passing):

- English labels are pixel-identical to the original markup at every height in use (40, 44, 50, 52, 56) and at SE and 17 Pro widths;
- the default is the English layout while the app runs in English;
- a short translated label gives a button of the same size (see note below);
- a long translated label grows the button where the fixed height cut it; a two-line label keeps its padding.

**Found while looking at the renders.** The first version wrapped a long label left-aligned and edge to edge. Fixed before commit (centred, side padding). Centring makes the system space a few letter pairs a fraction of a point differently, so a short translated label is the same size and position as the English one but not byte-identical; that test checks size and under 1% differing pixels. English does not take this path.

**Behaviour for English users:** unchanged, by the pixel comparison above. No string changed.

**Not verified**

- None of the 22 buttons has been looked at in the running app since the change; the shared modifier is tested, the call sites are a mechanical one-line replacement each. The landing "Get started" button and the paywall button are in the sweep.
- A grown button pushes its neighbours. On screens without scrolling (paywall, one-time offer, completion) I have not checked where the extra height comes from. It only happens when a label needs a second line.

### Slice 21 — WP8 tooling: sweep past the paywall, pseudo-language mode, and the WP6 sweep (2026-11-10)

**Sweep extended.** `OnboardingSweepTests` now continues after the paywall: it closes the paywall, captures the one-time offer if it is shown, taps through the five walkthrough cards and then opens each of the four tabs. 26 screenshots in place of 17. Everything up to the paywall is still asserted; the part after it is best effort and never fails the run.

**Pseudo-language mode.** New method `testOnboardingInDoubleLengthPseudoLanguage`: the same walk launched with `-NSDoubleLocalizedStrings YES` (the system doubles every localized string) and `-l10nForceTranslatedLayout YES` (the layouts from slices 17–20). No language has to exist. Element lookups now match the start of a label so they still work when the text is doubled. **Not run yet.**

**The WP6 sweep (the one run for this work package).** English, iPhone 17 Pro throwaway simulator, clean install. One guest user created in production.

| Screens | Result |
|---|---|
| 16 of the 17 baseline screens | Pixel-identical below the status bar |
| 14 loading screen under the notification prompt | 5.6% of pixels differ. Same layout; the progress bars behind the system prompt were caught at a later point of their animation, and the prompt's glass blur spreads that over its whole area |
| 18–26 (new) | Walkthrough cards over all four tabs, then Home, Courses, Scenarios, Profile. Looked at by eye: nothing cut, overlapping or misplaced |

So slices 17–20 changed nothing visible in English on the path from landing to paywall, including the landing "Get started" and "Log in" buttons, the commitment pact and the paywall footer links. The nine new screens are saved in `docs/localization-baseline/iphone-17-pro/` as a reference for later work (they were captured after the WP6 changes, so they are not a before/after proof for those screens). The voluntary sign-in capture was renamed `auth-login-voluntary.png` to free the number 18.

**Finding: where the legal line actually appears.** As a guest, closing the paywall leads to the one-time offer and then straight into the app. The sign-in screen with the legal line is shown only (a) after a purchase, (b) from the profile's account prompt once the user has logged approaches, or (c) in the fallback path where no guest session could be created. None can be reached by the sweep without a purchase or without writing approach rows to production, so that line stays verified by its unit-test renders only.

**Behaviour for English users:** unchanged. No app source changed in this slice; 174 unit tests pass.

**Not verified**

- The pseudo-language method has compiled but has never run.
- The one-time offer has still never been captured (Debug builds have no products).
- The legal line and its links inside the running app (see the finding above).
- iPhone SE: the English sweep was run on the 17 Pro only.

### Slice 22 — WP8: the double-length pseudo-language run on an iPhone SE (2026-11-10)

**Probe first.** Before spending a run, `PseudoLanguageProbeTests` (new, 5 tests, skipped in a normal run) checked what the system's pseudo-language does to this app's strings. It is switched on for a simulator with `xcrun simctl spawn <udid> defaults write com.lazul.wingman NSDoubleLocalizedStrings -bool YES` and must be switched off again afterwards. Result:

- nothing crashes;
- plain strings double cleanly ("Get started Get started");
- a string with a placeholder shows one garbled copy and one correct one ("lld days ago 15 days ago", "… in @ to unlock … in Beliefs & Reframes to unlock …");
- plural strings show raw format codes ("#@value@ %#@value@").

The last two are how the system doubles a format string. They are not app bugs and do not happen in a real language; they are noise to ignore in the screenshots.

**The run (WP8's one sweep).** `testOnboardingInDoubleLengthPseudoLanguage` on the "Wingman L10n SE" simulator, clean install, translated-app layouts forced on. All 26 screens captured. One guest user created in production.

**What held up.** Landing, all six question screens (they scroll), loading, the walkthrough cards (they grow), Home, Courses, Scenarios, Profile, the tab bar (labels shrink and stay in their own quarter), profile stat labels, and the paywall footer links (Privacy · Restore · Terms stay on one row). Nothing in slices 17–20 misbehaved.

**Findings: text cut or pushed off screen at double length on an SE**

| # | Screen | What happens | Owner |
|---|---|---|---|
| 1 | The four statistic screens after questions 3–6 | The content is taller than the screen and does not scroll: the back button and progress bar are pushed up under the status bar and "Tap to continue" is cut at the bottom | WP6, next slice |
| 2 | Growth projection | Same overflow: the chart's top label is cut and the Continue button runs off the bottom | WP6, next slice |
| 3 | Social proof | The third testimonial card runs under the Continue button | WP6, next slice |
| 4 | Commitment pact | "Tap and hold to commit." is held to one line and cut with "…" | WP6, next slice |
| 5 | Paywall | The third tick is cut after its first copy (the ticks sit in a fixed-height carousel) | WP6 item 3, with WP4 |

Double length is a deliberately harsh test: German runs about 30% longer than English, not 100%. Findings 1–3 may not occur in German on current phones, but the fix is the same either way (let the screen scroll when its content does not fit), and the plan's exit test for WP6 is this run. The five screenshots are in `docs/localization-baseline/pseudo-language-se-2026-11-10/`.

**Behaviour for English users:** unchanged. No app source changed in this slice. 179 unit tests: 174 pass, 5 skipped (the probes).

**Not verified**

- The pseudo-language run covered the path the sweep walks. Lessons, quizzes, scenarios in play, the approach sheet, settings and the one-time offer were not opened.
- Both sweep allowances that were open are now spent (WP6: English, slice 21; WP8: pseudo-language, this slice). The fixes for findings 1–4 will be checked by rendering each screen in a test window at SE size with doubled text, not by another run. A final in-app confirmation needs one more sweep, which is yours to allow.

### Slice 23 — WP6 part 5: screens that overflowed with long text (2026-11-10)

Fixes for the findings of slice 22, for translated apps only.

| Finding | Outcome |
|---|---|
| 1. Statistic screens | **Fixed.** A translated app keeps the original layout whenever its text fits. When it does not, the heading, illustration and fact scroll, and "Tap to continue" stays pinned at the bottom. The right half of the screen still moves on and the left half still does nothing |
| 2. Growth projection | **Fixed.** Chart, headline and bullets scroll as one block when too tall; Continue stays on screen |
| 3. Social proof | **Not a bug.** That screen already scrolls; the third testimonial was simply below the fold |
| 4. Commitment pact | **Fixed in code, not rendered.** The line under the logo was cut because the screen ran out of height. The pact now scrolls when too tall. Drawing this screen in a test would send its "pact viewed" analytics event, so it was not drawn |
| 5. Paywall third tick | Open; goes with the paywall rows in WP4 |

**How.** New helper `scrollsWhenTooTallIfTranslated()`: English gets the view untouched; a translated app gets it as it is when it fits and in a scroll view when it does not. The statistic screen needed more care, because its two invisible tap zones would have swallowed a scroll: its scrolling variant reads the tap alongside scrolling instead.

**A wrong first version, caught by the renders.** "Does it fit" is decided from each piece's ideal size. My first measurement was more optimistic than the layout the screen really settles into, so one statistic screen kept the fixed layout and its fact ran into "Tap to continue". The measurement now counts the gaps at their full height and the illustration at its minimum, which is what the stack actually does.

**New test tooling: whole-screen renders.** `OnboardingScreenRenderTests` draws real screens in a test window at iPhone SE and 17 Pro sizes, with no sweep and no production user. It gives a true before/after check: the English renders were exported from a run on the unchanged code, confirmed repeatable (two runs, identical), and compared with a run after the change.

**Tests.** 10 new (189 total: 184 pass, 5 probes skipped).

- English, before vs after: all 10 renders (4 statistic screens and the growth projection, at both sizes) pixel-identical.
- Translated app with text that fits: the 8 statistic renders are byte-identical to English.
- Translated app with doubled text at SE size: all 4 statistic screens start at the top and keep "Tap to continue" clear; the growth projection keeps its Continue button.
- The original layout with doubled text loses its hint (the problem, kept on record).
- The helper: untouched in English, untouched when it fits, scrolls from the top when too tall.

**Behaviour for English users:** unchanged, by the before/after renders. No string changed.

**Not verified**

- None of this has been seen in the running app; no sweep run is left. The renders draw the screen's content area without the onboarding top bar above it.
- The commitment pact fix (see finding 4).
- Scrolling by hand and tapping the right half of a scrolling statistic screen. The render shows the layout, not the gesture.
- Residual: on the growth chart, a label that wraps to four lines pokes out of the top of the chart and is clipped. Seen only with doubled text; "Using Wingman every day" would need to roughly double in length.
- When a statistic screen scrolls, nothing tells the user there is more below the illustration.

## Next

WP6 item 8, the image check: look at the 25 course thumbnails, the statistic and onboarding illustrations and the remote scenario images for words baked into the artwork. Read-only; produces a list.

Then WP4 (paywall prices and disclosure), which also takes WP6 items 3–4 and finding 5 (ticks and plan rows), since they are the same paywall rows. WP4 ends on the priced-paywall question that only you can answer (one Release run, or a dev-tag launch flag).

After WP4: WP7 (content plumbing), WP3 (error classification), remaining WP8 tooling.

## Open questions for Arthur

- **Dates for English users outside the US:** the approach list shows "Nov 3, 2026" to every English user, including Australian and British ones (your second and fourth largest markets), because the format is fixed. I kept that unchanged, since Release A must not change what English users see. Switching English to a locale-aware date would show "3 Nov 2026" in those regions. Say if you want that; it is a one-line change.
- **Unused code:** `CommonComponents/ErrorViewScreen.swift`, `Resources/AppStrings.swift` and the Poppins font styles in `Resources/App.swift` appear to be unused. May I delete them? Otherwise the error screen's three strings stay in the catalog and get translated for nothing.
- **Priced paywall baseline:** one Release-build run (one test user in production analytics), or add a launch flag that tags automated runs as dev? Needed before WP4 can be signed off.
