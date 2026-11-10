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
| WP5 String Catalog and extraction | **In progress** (slice 4: lookup layer) | No catalog file yet; no UI strings moved yet |
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

## Next

WP5 part 2: add `Localizable.xcstrings` and `Content.xcstrings`, and populate `Localizable` from the compiler's extracted strings (`xcstringstool sync` over the build's `.stringsdata`) so the catalog reflects what SwiftUI already treats as localizable. Then move the indirect `String` values area by area, onboarding first: question titles, statistics, social proof, growth projection, commitment pact. Each area gets a test that its English output is unchanged.

## Open questions for Arthur

- **Priced paywall baseline:** one Release-build run (one test user in production analytics), or add a launch flag that tags automated runs as dev? Needed before WP4 can be signed off.
