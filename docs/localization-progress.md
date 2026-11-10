# Localization progress log

Working log for Release A of [localization-implementation-plan.md](localization-implementation-plan.md). Branch: `localization-release-a`. Updated at the end of every work slice.

## Status

| Package | State | Notes |
|---|---|---|
| Prerequisites P1, P2, P5 | Done | Commit `6acc258` |
| Prerequisite P3 | Partly done | Priced paywall, screens past the paywall and time-to-paywall still to capture |
| WP1 Onboarding answer IDs | **Done** (see slice 1) | Supabase `age`/`goals` writes verified unchanged by reading the code path, not by a live write |
| WP2 Analytics values pinned to English | Next | |
| WP3 Error classification | Not started | Plan wants a few days of production logging first; cannot be done inside this loop |
| WP4 Paywall prices and disclosure | Not started | Blocked at the end on the priced-paywall capture decision (Release run vs dev-tag launch flag) |
| WP5 String Catalog and extraction | Not started | |
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

## Next

WP2: add `canonicalTitle` fields and point `lesson_name`, `category`, `lesson_title`, `course_title`, `previous_course_title`, `scenario_name`, `headline` and `level_name` at them; add `course_id` / `previous_course_id`; register `app_language`, `device_language` and `storefront` super properties. Start with an in-memory analytics recorder for tests so the values can be asserted (plan section 9).

## Open questions for Arthur

- **Priced paywall baseline:** one Release-build run (one test user in production analytics), or add a launch flag that tags automated runs as dev? Needed before WP4 can be signed off.
