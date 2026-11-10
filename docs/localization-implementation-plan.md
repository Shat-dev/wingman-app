# Wingman localization: implementation plan

Date: 2026-11-10 · Based on [localization-audit.md](localization-audit.md) (finding IDs such as B-1, C-2 refer to it) · Baseline: 1.14 (37).

Pilot language: **German**. PostHog shows Germany as the largest non-English European market (17 onboardings, 5 purchases in 90 days). The plan is language-agnostic; German is only the first set of translation files.

---

## 1. Strategy

Two releases, in this order.

- **Release A — English only, no visible change.** All code, schema and tooling work. Removes every place where English display text is used as data, moves strings into a catalog, makes prices and disclosure come from StoreKit, and adds the content-translation plumbing. `knownRegions` stays `en`, so no user can see another language.
- **Soak — one week in production.** Prove from live PostHog data that nothing moved for English users.
- **Release B — adds German.** Translation files, translated content rows, layout fixes found in German, App Store listing. No logic changes.

Why split it: the 12 blockers in the audit are all in Release A, and each one fails silently. Shipping them alone, with English output required to be identical, turns "did we break analytics" into a yes/no check before any translation money is spent.

After Release B, each further language is translation files plus database rows only (Req 4).

---

## 2. Design rules

These six rules are what make the 14 requirements hold. Every task below applies one of them.

**R1. English canonical value, separate from display.**
Anything that is stored, sent to analytics, sent to Supabase, or compared in code uses a frozen English constant or an ID. Display goes through a separate localized lookup. The two never share a variable. (Req 5, 6, 7, 8)

**R2. Existing stored and analytics values do not change at all.**
The current English answer strings, including the deliberate "embarrased" misspelling, become the permanent canonical values. They are no longer shown to anyone, so they are IDs in practice, and history, the 18 saved insights, UserDefaults on existing installs and Supabase metadata all stay continuous with zero migration. (Req 5, 1)

**R3. English text is the lookup key, with English as the fallback value.**
String Catalog keys are the English strings themselves, never symbolic keys like `paywall.title`. A missing translation then resolves to the English sentence by construction; a raw key can never reach the screen. Content lookups (lessons, database rows) fall back per field, and an empty translation counts as missing. (Req 9)

**R4. English users run exactly the code path they run today.**
Same bundle files, same Supabase queries, same cache file. Translation is an overlay loaded only when the app language is not English, and only for that one language. (Req 1, 4)

**R5. Whole sentences, never fragments.**
Each translatable unit is a full sentence with positional placeholders. Counts use the catalog's plural variants. Prices, dates and numbers are inserted already formatted by a system formatter. (Req 3, 10, 11)

**R6. Translations are additive.**
New files and new tables only. No existing column, row, ID, foreign key, RPC signature, product ID or event name is edited. Old app versions keep working against the same backend. (Req 6, 8)

---

## 3. Decisions

**Confirmed 2026-11-10: all six defaults accepted.** The "Default" column below is the decision.

| # | Decision | Default (accepted) | Why it matters |
|---|---|---|---|
| D1 | Keep the existing English answer strings as the canonical stored/analytics values (rule R2), or introduce new short IDs and map history? | **Keep existing strings.** Optionally add parallel `onboarding_<key>_ids` properties later. | New IDs would break 18 saved insights and need a data migration. |
| D2 | What counts as an untranslated "module name" (Req 14)? | **Wingman, XP, and the 5 category names stay English.** Course titles, lesson titles, approach level names and tab labels are translated for display. Analytics always sends the English canonical title either way. | Sets the do-not-translate glossary. |
| D3 | Weekly price on plan rows. Use RevenueCat's `localizedPricePerWeek`, or keep today's arithmetic and only fix the formatter? | **Keep today's arithmetic, format with the product's own price formatter.** | RevenueCat rounds down and uses different week constants, so English prices would shift by 1–3 cents (for example $1.35 → $1.34 per week on yearly). Keeping the arithmetic leaves the English paywall pixel-identical. Strictest reading of Req 11 favours the RevenueCat value; say so if you want it. |
| D4 | Main paywall has no auto-renewal sentence (audit Open Question 8). Add one? | **Add one full sentence under the CTA**, per trial/no-trial variant, built from StoreKit values. | Req 13 asks for a complete disclosure; this is the one visible English copy change in the plan. Can be dropped if you consider the current paywall compliant. |
| D5 | Lesson bodies stay bundled in the app, or move to Supabase? | **Stay bundled.** | No performance change, works offline, about 0.5 MB per language. |
| D6 | Should German users get German Privacy/Terms pages? | **No. Same two URLs for everyone.** | Req 12 only requires the buttons to keep working. Translated legal pages are a separate legal task. |

---

## 4. Prerequisites (before any code)

| # | Task | Output |
|---|---|---|
| P1 | Export the live Wingman schema and keep it under `supabase/`. The audit could not see the live database. | **Done 2026-11-10:** `supabase/snapshots/live-schema-2026-11-10.md` (catalog snapshot via the connector, not a `pg_dump`). Tables, RPC bodies, RLS policies, triggers; no cron jobs exist. |
| P2 | Confirm whether stored daily question sets hold question IDs or copied text (audit Open Question 2). | **Done 2026-11-10:** IDs (`question_ids uuid[]`). Overlay approach confirmed for daily practice. |
| P3 | Record English baselines on build 37: cold-launch time, time to first paywall, and screenshots of every screen on iPhone SE and a 17 Pro. | **Partly done 2026-11-10:** `docs/localization-baseline/`. Cold launch 0.858 s (Debug, 17 Pro simulator, 5 runs). 17 screens from landing to paywall on both devices. **Still open:** priced paywall and one-time offer (need a Release build), every screen past the paywall, and time to first paywall. The sweep is the `WingmanUITests` target and can be re-run against the baseline commit at any time. |
| P4 | Snapshot analytics baseline: for each property in the audit's impact table, the distinct values seen in the last 30 days. | Reference set for the parity check in section 9. |
| P5 | Add a unit-test target. The project has none. | **Done 2026-11-10:** `WingmanTests` (18 tests passing; they pin today's onboarding values and personalisation outputs ahead of WP1) and `WingmanUITests` (launch timing, onboarding sweep). Both are in the shared `Wingman` scheme. |
| P6 | Answer decisions D1–D6. | Done 2026-11-10: defaults accepted. |

---

## 5. Release A — work packages

### WP1. Onboarding answers become IDs (fixes B-1, C-1, C-2, C-3, C-4, C-5)

1. Replace `options: [String]` in `OnboardingStep` with an option type holding three things: a stable `id`, the `canonicalValue` (today's English string, frozen), and a localized display label.
2. `OnboardingFlow.swift`: define every option once in that form. Remove the `displayLabels` typo map in `OnboardingStep.swift:72-78`; the misspelling lives only in `canonicalValue`.
3. `QuestionScreen` tracks selection by option `id`.
4. `OnboardingView.handleNext`: build the stored and analytics value by joining `canonicalValue`s with ", " exactly as today. UserDefaults, PostHog `onboarding_<key>` and Supabase `age`/`goals` therefore receive byte-identical values.
5. Resume (`OnboardingView.swift:873`): split the stored string, map each piece back to an option by `canonicalValue`.
6. `PaywallCopy`, `MarketingNotifications`, `StatisticContent`: resolve the stored value to an option `id` through one shared lookup, then `switch` on the `id`. Unknown or legacy values (for example "45+") keep falling to the existing default.
7. Unit tests: every option round-trips; every pre-existing stored value, including "45+" and the misspelling, still selects the same paywall tick, reminder line and statistic as build 37.

**Done when:** an English run produces the same six `onboarding_*` values as P4, and switching the simulator to a pseudo-language changes labels but not one stored or sent value.

### WP2. Analytics values pinned to English (fixes B-2 to B-6, B-9; guards B-10)

1. Add `canonicalTitle` (English, never localized) next to the display title on `Lesson`, `Course`, `CourseCategory`, scenario data, approach levels and `CommitmentPactCopy`.
2. Point the existing properties at the canonical field. Property names and values are unchanged: `lesson_name`, `category`, `lesson_title`, `course_title`, `previous_course_title`, `scenario_name`, `headline`, `level_name`.
3. Add IDs where one is missing, as new properties only: `course_id` on lesson and quiz events, `previous_course_id` on `course_locked_encountered`.
4. Register three new super properties beside `environment` in `Analytics.registerEnvironment()`: `app_language` (the language the app is actually running in), `device_language` (first preferred language), and `storefront` once StoreKit reports it. Re-register after every `reset()`, as `environment` already is.
5. Add `price_amount` and `currency` (numeric, ISO code) to the paywall purchase and view events. Additive.
6. Add `error_domain` and `error_code` to the four events that send `error_message`. Leave `error_message` in place; it is free-text diagnostics and no saved insight uses it.
7. Leave all `.trackScreenView("…")` names as plain `String` constants and add a comment and a lint check that they are never wrapped in a localized type.

**Not changed:** every event name, Meta event names and parameters (`.startTrial`, `.subscribe`, `.completedRegistration`), RevenueCat product, entitlement, offering and package IDs.

**Done when:** the parity test in section 9 passes in English and in a pseudo-language.

### WP3. Logic off localized text (fixes C-6)

1. `AuthManager.isNetworkError` / `isAuthenticationError` / the `"Timeout"` check (`AuthManager.swift:1307-1351`): classify by error type, `NSError` domain and code, and HTTP status. Remove the keyword matching on `localizedDescription`.
2. First, log which error types actually reach this code in production for a few days (audit Open Question 17) so the typed checks cover the real cases.

**Done when:** a unit test feeds the known error types and gets the same sign-out decisions as today, with the device language set to German.

### WP4. Paywall prices and disclosure from StoreKit (fixes E-1 to E-4, H-4, H-5; D3, D4)

1. **Weekly price** (`PaywallView.swift:997-1015`): format with `storeProduct.priceFormatter` (the same source `zeroPriceString` already uses) instead of `Locale.current`. Remove the `"$0.00"` literal fallbacks; when no formatter exists, omit the line. Per D3 the arithmetic stays.
2. **"only X per week", "per year", "per month"**: one full catalog sentence each with a single price placeholder.
3. **Trial badge**: read the trial length from the product's introductory offer and render it through a plural-aware catalog entry. English must render "3-day Free Trial" exactly as now. If the product has no free-trial offer, show no badge.
4. **One-time offer disclosure** (`OneTimeOfferView.swift:203`): replace the fragment helper `durationPhrase` with complete sentences chosen by case: one for the real configuration (first year, then yearly) and plural-aware generic ones for other period combinations. Same for "off your first year" and "%lld-month Plan".
5. **Main paywall renewal sentence** (D4): add the two variants as full sentences fed by StoreKit price and period.
6. **Derived per-month price** (`OneTimeOfferViewModel.swift:93-103`): already uses the product formatter; keep, and omit rather than guess on failure.
7. Write a one-page disclosure checklist (plan name, length, price, renewal, trial terms, cancel instruction, Privacy, Terms, Restore) and tick it per language during QA.

**Done when:** English paywall and offer screenshots match P3 (apart from the D4 sentence), and a simulator with a German storefront but US device region shows euros throughout.

### WP5. String Catalog and string extraction (fixes A-1 to A-4, D-1 to D-6, E-6 to E-8, G-6)

1. Add `Localizable.xcstrings` (UI strings) and a second table `Content.xcstrings` (data-like strings: course catalog, quotes, onboarding options, statistics, testimonials, approach levels). English is the source language; keys are the English text (rule R3).
2. **Direct SwiftUI literals (~146):** extracted by the build; review each for placeholders.
3. **Indirect `String` values (~693):** convert at the point of definition to a localized lookup. For data-like strings, one helper looks the English canonical string up in the `Content` table with the canonical string itself as the fallback. That single literal is then both the analytics value (R1) and the display key.
4. **Plurals and counts (audit D-1, D-4):** replace every manual plural and count interpolation with a catalog plural entry. List: `PracticeDetailView:25-27`, `PracticeCardView:25-27`, `CompletionScreen:394,405`, `XPStore:63`, `ApproachesLoggedListView:292-296`, `ProfileView:274`, `ProfileStatsHeader:51-53`, `NotificationManager:81`, `PracticeDetailView:155`, `CourseDetailSheet:279`, `SettingsSheet:184`, `DailyReadingGoalSheet:78`.
5. **Fragments (audit D-3, D-5, D-6):** one sentence per case. `LogApproachViewModel:208` becomes two sentences (save / update). Error wrappers become "Purchase failed. Please try again." style full sentences, with the technical detail going to analytics and logs, not the alert.
6. **Dates and numbers:** `ApproachesLoggedListView:299-307` uses a date style, not a fixed pattern; "n days ago" uses the system relative formatter. Percent values use the percent format style. Machine date keys in `StreakStore` and `DailyPracticeServiceProtocol` get the fixed POSIX locale and Gregorian calendar that `XPSource` already uses.
7. **Notifications:** build content with the notification-specific localized string API so text resolves at delivery time. Reminder lines are chosen by option `id` (WP1).
8. **Server-sourced messages:** the app maps Edge Function failures to its own localized sentences by HTTP status or error code and stops displaying the function's English `error` string.
9. **Glossary (Req 14):** mark Wingman, XP and the five category names as do-not-translate in the catalog and in the translator brief.
10. Delete dead code that would otherwise be translated for nothing: `Resources/AppStrings.swift`, the Poppins `Font.App` styles, and, if P1 confirms it never ships to users, the mock scenario text.

**Done when:** an Xcode run with the double-length pseudo-language shows no English-length string anywhere in the app, and an English run is visually identical to P3.

### WP6. Legal links and layout hardening (fixes H-2, H-3, F-1 to F-11)

1. **Sign-in legal line** (`AuthView.swift:343-372`): one localized sentence containing two inline links, allowed to wrap to two lines. Links route through the same Safari sheet and the same two URL constants.
2. **Paywall and offer footers:** let the three links scale down slightly, then wrap to two rows if they still do not fit. Tap targets stay 44pt.
3. **Paywall ticks:** replace the 36-character convention with a layout that tolerates a two-line tick without pushing the plan cards off screen on an SE; add a per-language maximum length to the translation validator as a second guard.
4. **Plan rows:** give the title/price and price/period columns a priority and a minimum scale so the price never truncates.
5. **Answer buttons:** remove the 2-line cap on onboarding options and scenario options; let the button grow, and make the scenario option list scroll if needed.
6. **Fixed-height buttons (about 20 sites):** change fixed height to minimum height with a mild scale-down.
7. **Tab bar, course titles, level line, scenario cards:** allow scale-down before truncation.
8. Check the 25 course thumbnails and remote scenario images for embedded words (not done in the audit).

**Done when:** every screen passes in the double-length pseudo-language on iPhone SE with no clipped, truncated or overlapping text, and Privacy, Terms and Restore work from all four entry points.

### WP7. Content translation plumbing (fixes G-1 to G-5)

**Language source.** One accessor returns the language the app bundle is actually running in. UI strings, lesson overlays and database overlays all use it, so the interface and the content can never disagree.

**Lessons (bundled).**
- The 25 English JSON files stay exactly where they are and remain the structural source: order, IDs, durations, lock state.
- A translation is a flat per-language file per course mapping each existing text ID (`lesson_…`, `content_…`) to translated text.
- `LessonDataService` loads English as today; only when the app language is not English does it load that course's overlay and substitute text by ID. Any ID missing from the overlay keeps its English text.
- `Lesson.canonicalTitle` is taken before the overlay is applied (WP2).

**Supabase (additive, rule R6).**
- Four new tables, each keyed by the existing primary key plus `locale` (names confirmed against the live schema, see `supabase/snapshots/live-schema-2026-11-10.md`):
  - `question_translations` (question_id → `questions.id`): `question_text`, `options`, `explanation`
  - `scenario_translations` (scenario_id → `scenarios.id`): `title`, `summary`
  - `scenario_screen_translations` (screen_id → `scenario_screens.id`): `text`
  - `screen_option_translations` (option_id → `screen_options.id`): `text`
- `practices`, `practice_details` and `practice_steps` are empty in production, so they get no translation tables.
- Read policies mirror the base tables: question translations readable by authenticated users only; scenario, screen and option translations readable by everyone. Constraint on question translations: the options array must be the same length as the English one, because correctness is index-based.
- Confirmed by P1/P2: the daily question set stores question IDs (`daily_question_sets.question_ids uuid[]`), `get_or_create_daily_questions` returns `question_id`, and `get_scenario_screens` returns `screen_id` plus each option's `id`. Overlay by ID works for all of them and **no RPC needs to change**.
- No change to any existing table, RPC, ID or foreign key. Branching and scoring keep reading the English rows.
- Client: fetch English rows with today's unchanged queries. When the app language is not English, run one extra query for translation rows matching the returned IDs and that locale, in parallel, and overlay by ID with per-field English fallback.
- `scenario_name` for analytics is read from the English row before overlay.

**Question cache (G-3).**
- English keeps today's cache file and fingerprint untouched.
- Other languages get their own overlay cache file and a fingerprint that includes the locale and the translation table's latest change. Only the active language is ever downloaded.

**Course catalog.** Stays in Swift for now, with titles looked up through the `Content` table (WP5). Consolidating the four copies of course titles is noted as follow-up, not part of this work.

**User profile.** Write `locale` to `user_metadata` alongside the existing `country` and `currency`. Additive.

**Auth emails.** Add German templates in the Supabase dashboard once P1 shows which templates are active; selection by the `locale` metadata field.

**Done when:** with no translation rows present, a German-language device shows complete English content with no blank fields and makes at most one extra request per content fetch; an English device makes exactly the requests build 37 makes.

### WP8. Tooling and tests

| Tool | Checks |
|---|---|
| Analytics parity test | Section 9. |
| Translation validator (script, runs before every build that adds or changes translations) | Same placeholders in the same count as English; plural categories complete; no empty values; do-not-translate terms intact; question option counts equal English; per-string length limits (paywall ticks, tab labels, buttons); every overlay ID exists in English. |
| Fallback tests | Delete random entries from a test language; assert the English text appears and nothing renders blank or as a key. |
| Performance check | Launch and paywall timings against P3 for English; again for German with full content. |
| Screenshot sweep | Scripted walk through onboarding, paywall, offer, home, courses, lesson, quiz, scenario, profile, settings in English, German and double-length, on SE and 17 Pro. |

---

## 6. Release A exit and soak

Ship Release A with `knownRegions` unchanged.

**Exit gate before submitting**
- Parity test green in English and pseudo-language.
- English screenshots match P3 except for agreed changes (D4).
- English launch and paywall timings within normal run-to-run noise of P3.
- A sandbox purchase on each product fires `paywall_purchase_succeeded`, Meta Start Trial or Subscribe, and grants the RevenueCat entitlement.

**Soak (7 days live)**
- Distinct values of every property in the audit's impact table are a subset of the P4 baseline.
- The 18 `onboarding_*` insights and the 7 screen-name insights show no break at the release date.
- Onboarding completion, paywall view → purchase start, and trial start rates are within their normal range.
- `app_language` reads "en" for 100% of users.

Do not start Release B until the soak passes.

---

## 7. Release B — German

| # | Task | Notes |
|---|---|---|
| G1 | Translator brief | Glossary with do-not-translate terms (D2), tone guide, character limits from the validator, and the instruction to adapt the dating-advice content for a German audience, not translate word for word. |
| G2 | Translate UI and `Content` catalogs (~840 strings) | Export from Xcode, translate, import. Native-speaker review of onboarding, paywall and notifications in particular. |
| G3 | Translate lesson overlays (~36,800 words) | 25 overlay files. Largest single cost. |
| G4 | Translate database content (~42,300 words) | 765 questions (~32,000 words including answer options), 15 scenarios with 891 screens and 276 options (~10,300 words). Insert as translation rows only. Together with G3 the content total is about 79,000 words. |
| G5 | Run the validator; fix every failure | Blocks the build otherwise. |
| G6 | Add `de` to the project's known regions | The only project-setting change in Release B. |
| G7 | German layout pass | Screenshot sweep; fix anything WP6 did not anticipate. |
| G8 | Paywall compliance pass in German | Tick the WP4 disclosure checklist on the real German storefront in sandbox. |
| G9 | App Store Connect | German name, subtitle, keywords, description, screenshots (re-render from `marketing/app-store-assets`), and German display names for the three subscriptions. |
| G10 | German auth email templates | From WP7. |

**Exit gate**
- All Release A gates still green.
- Fallback test: remove a sample of German strings and rows, confirm English appears.
- Full German run-through by a native speaker: onboarding → paywall → trial start → lesson → quiz → scenario → approach log → settings → restore → delete account.
- Parity test in German: every analytics value identical to the English run.

**After launch, watch by `app_language`:** onboarding completion, paywall conversion, trial-to-paid, and lesson completion for German versus English users in the same storefronts.

---

## 8. Requirement traceability

| Req | How it is met | Verified by |
|---|---|---|
| 1. No performance change for English users | R4: English path is the existing path; overlays only load for other languages; strings compile into per-language tables and only the active one is read | P3 baselines vs Release A timings; request count check in WP7 |
| 2. No UI breakage from longer text | WP6 | Double-length and German screenshot sweeps on SE |
| 3. Grammatical translations, no fragments | R5; WP4 items 2–5; WP5 items 4–5 | Validator (placeholder parity); native review |
| 4. More languages do not slow the app | One overlay per active language; per-locale queries and caches; no "all languages" download | Performance check with two test languages loaded |
| 5. PostHog names and values identical | R1, R2; WP1, WP2 | Parity test; soak comparison against P4 |
| 6. Supabase English canonical; IDs, keys, branching unchanged | R6; WP7 translation tables only | Schema diff shows additions only; scenario and quiz tests in German |
| 7. No logic depends on displayed text | WP1 item 6; WP3 | Unit tests under a pseudo-language |
| 8. RevenueCat IDs and Meta events unchanged | Not touched; called out as out of scope in WP2 | Sandbox purchase check in both releases |
| 9. Missing translations fall back to English | R3; per-field overlay fallback; empty counts as missing | Fallback tests |
| 10. Locale-safe plurals and interpolation | Catalog plural variants; positional placeholders | Validator; German and pseudo-language runs |
| 11. Prices, dates, numbers by locale; prices from StoreKit | WP4; WP5 item 6 | Mismatched storefront/region simulator test |
| 12. Privacy and Terms keep working | Same two constants and Safari sheet; WP6 items 1–2 | Tap test from all four entry points in each language |
| 13. Paywall disclosure complete and accurate | WP4 checklist; StoreKit-sourced trial length, prices and periods | Checklist ticked per language on the real storefront |
| 14. Brand and module names not translated | Glossary and do-not-translate flags (D2) | Validator term check |

---

## 9. Analytics parity test

The single most important check, because the failures it catches are invisible.

1. A scripted run drives the app through onboarding (fixed answers), paywall view, plan selection, a sandbox purchase, a lesson with quiz, a scenario, an approach log, and a pact commit.
2. Analytics capture is redirected to an in-memory recorder in the test build.
3. The run executes three times: English on build 37 (reference), English on the new build, pseudo-language or German on the new build.
4. **Pass condition:** the set of event names and, for every property that existed on build 37, the values are identical across all three runs. New properties (`app_language`, `course_id`, `price_amount`, and so on) are allowed; changed or missing ones are not.

---

## 10. Sequencing and effort

Estimates are rough, for one developer, and exclude translation turnaround.

| Order | Package | Effort | Depends on |
|---|---|---|---|
| 0 | Prerequisites P1–P6 | 2–3 days | Your access to the Wingman Supabase project |
| 1 | WP1 Onboarding IDs | 2–3 days | P5 |
| 2 | WP2 Analytics pinning | 2 days | WP1 |
| 3 | WP3 Error classification | 1 day + a few days of logging | — |
| 4 | WP4 Paywall | 2–3 days | D3, D4 |
| 5 | WP5 String Catalog | 6–8 days | WP1, WP2 (so canonical fields exist first) |
| 6 | WP6 Layout and legal links | 3–4 days | WP5 |
| 7 | WP7 Content plumbing | 4–5 days | P1, P2 |
| 8 | WP8 Tooling and tests | 3–4 days, built alongside | P5 |
| — | **Release A + 7-day soak** | | |
| 9 | Release B, G1–G10 | 1–2 weeks of dev time plus translation and review | Soak passed |

WP1 → WP2 → WP5 is the critical path. WP3, WP4 and WP7 can run in parallel with it.

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| A string is localized at a point where it is also used as data, reintroducing a blocker | R1 enforced structurally: canonical and display are different fields. Parity test in pseudo-language on every build. |
| WP5 touches ~120 files and introduces a visible English regression | English screenshot diff against P3; ship Release A alone and soak. |
| Translated options or questions reorder answers and break index-based scoring | Database constraint on option count; validator; translators told order is fixed. |
| Live schema differs from what the app code implies | P1 before WP7; WP7's table list is provisional until then. |
| German copy is correct but reads as translated American advice | G1 brief asks for adaptation; native reviewer signs off onboarding, paywall and the first lessons. |
| Mixed-language experience during rollout (German UI, English content) | Release B ships UI, lessons and database rows together; G4 completes before G6. |
| PostHog's automatic `$locale` starts varying after Release B | Expected. Use the explicit `app_language` property for analysis and say so in the dashboard notes. |
| D4 sentence changes paywall conversion | Ship it in Release A where its effect can be read on English traffic alone; revert is one string. |

---

## 12. Out of scope

- Privacy policy and terms content, consent for session replay and Meta events, and other GDPR items raised in the earlier Europe diagnosis. They are independent of translation and should run in parallel.
- Consolidating the four copies of course titles into one source.
- Right-to-left or non-Latin languages.
- Moving lessons to Supabase.
- Pricing changes per territory.
