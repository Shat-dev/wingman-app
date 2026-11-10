# Release A: where it stands against the exit gate

Written 2026-11-10 at the end of the working loop. Branch `localization-release-a`, 41 commits ahead of `Shat`, last commit `6fb6739`. Nothing is pushed, no pull request is open, and the version is still 1.14 (37).

Release A is the English-only release: it reshapes the app so that languages can be added later, and is meant to change nothing an English user sees except one approved sentence on the paywall. Plan: [localization-implementation-plan.md](localization-implementation-plan.md). Working log, slice by slice: [localization-progress.md](localization-progress.md).

## The short version

**The code for Release A is written and tested as far as it can be without real products, a real purchase or the live database.** It is not ready to submit: three of the four exit-gate conditions need something only you can do.

- 296 unit tests (291 pass; 5 are pseudo-language probes that skip in a normal run).
- English is unchanged on the 17 baseline screens (16 pixel-identical, 1 an animation frame) and on every English output that has a test, most of them compared against a copy of the old code.
- No language is added: `knownRegions` is `en`, both String Catalogs are English only, and the validator fails if another language appears.
- Supabase was only read. One migration file is written and not applied.

## The exit gate (plan section 6)

| # | Condition | State | How it was checked, or what is missing |
|---|---|---|---|
| 1 | Parity test green in English and pseudo-language | **Partly** | A scripted run of 19 analytics calls records identically in English and as a translated app with German content laid over (slice 37). 40-odd further tests pin stored values and analytics properties. **Missing:** the plan's full run through the real screens with a sandbox purchase, and the comparison with build 37. Needs UI automation through a purchase |
| 2 | English screenshots match P3 except for agreed changes | **Met for what can be rendered** | WP6 sweep: 16 of 17 pixel-identical below the status bar, the 17th differs only in an animation frame (slice 21). Before/after renders are identical for the statistic screens, growth projection, plan rows, buttons, footers and tab bar. **Missing:** the priced paywall and the one-time offer have never been rendered (Debug builds load no products). D4 was declined, so there is no agreed change |
| 3 | English launch and paywall timings within noise of P3 | **Launch met; paywall timing not measured** | Cold launch 0.752 s and 0.739 s against 0.858 s (slice 38). Time-to-paywall cannot be read from the sweep, whose duration is test waits |
| 4 | A sandbox purchase on each product fires `paywall_purchase_succeeded`, Meta Start Trial or Subscribe, and grants the entitlement | **Not done** | Needs a Release build, a sandbox Apple ID and your RevenueCat and Meta dashboards |

## The 14 requirements

| # | Requirement | State |
|---|---|---|
| 1 | No performance change for English users | Launch time unchanged. English makes no new request and reads no new file: tested for every content fetch |
| 2 | No UI breakage from longer text | Doubled-text run on an iPhone SE done; its overflow findings fixed. Line caps, fixed-height buttons, footers, the legal line and long plan names all have a translated-app layout. Confirmed in the running app by a second doubled-text run after the fixes |
| 3 | Grammatical translations, no fragments | Every sentence that was assembled from pieces is now a whole catalog entry: legal line, weekly price, trial badge, one-time offer, notifications |
| 4 | More languages do not slow the app | Only the running language is ever fetched or cached; one file and one fingerprint per language. **Not measured with two languages**, since none exists |
| 5 | PostHog names and values identical | Stored answers and analytics values are pinned and read from English fields; display text is separate. Recorder parity test green. **Not observed in PostHog** |
| 6 | Supabase English canonical; IDs, keys, branching unchanged | Translation tables are additive and keyed by the English IDs; the overlay only ever replaces text. **Migration not applied** |
| 7 | No logic depends on displayed text | Onboarding branching goes by option ID; the sign-out decision goes by error type. The old word search survives only as an English fallback until production logs exist |
| 8 | RevenueCat and Meta IDs and events unchanged | Not touched. **Not exercised:** no purchase was made |
| 9 | Missing translations fall back to English | By construction (English text is the key) and tested for the catalogs, database content, lesson quizzes and lessons. Blank counts as missing |
| 10 | Plurals and placeholders locale-safe | Catalog plurals in use; the validator checks placeholders and plural forms of every translation |
| 11 | Prices, dates, numbers by locale; prices from StoreKit | Weekly price formatted by the product; trial length read from the product. Dates stay US-format for English users (open question below) |
| 12 | Privacy and Terms keep working | Same two URLs and the same in-app browser from all four places. A translation that breaks a link falls back to English. **Links not tapped in the running app on the sign-in screens** |
| 13 | Paywall disclosure complete and accurate | Checklist written: 17 of 18 rows present. The 18th (a renewal sentence) is left out by your decision |
| 14 | Brand names not translated | Marked do-not-translate; the validator checks brand terms survive |

## Answers received 2026-11-10

- **D4 (renewal sentence): leave the paywall as it is.** Nothing built; WP4 has no open item left. Requirement 13's one open row stays as it is by decision.
- **One more sweep run: approved and done.** The doubled-text run on the iPhone SE simulator, clean install (one more guest user in production). All 26 screens captured. The slice 23 fixes hold in the running app: the four statistic screens keep their top bar and "Tap to continue" and still advance on a tap, the growth projection keeps its Continue button, and the commitment line wraps to two lines. One residual, already known: on the growth chart, a label that wraps to four lines is clipped at the top.

## What I still need from you

1. **How to see the paywall with real prices.** A Debug build cannot load products, so the paywall only ever shows "Can't load pricing" here. Seeing real prices needs a Release build, and a Release build tags its analytics as production. Two ways:
   - **One Release run (my recommendation for now).** No code change. Cost: one fake user in your production PostHog numbers for that day, and one guest user in Supabase.
   - **A launch flag** that makes an automated Release run tag itself as dev. Keeps production numbers clean, at the price of a small change to the code that decides the analytics environment. Worth it if this will be done repeatedly, which Release B's per-language paywall checks would be.

   Either way it lifts the "no Release-build runs" rule for that run, so it needs your yes. Everything in WP4 is tested with stand-in values and has never been seen with a real product.
2. **A sandbox purchase on each product** (gate condition 4).
3. **The migration dry run, when you want it.** Not needed to ship Release A: English never touches the translation tables. It is needed before a language is added. One command, which leaves nothing behind:

   ```bash
   supabase link --project-ref bnckmgnysfliiypvxxii
   ```

   ```bash
   supabase db query --linked -f supabase/scripts/content_translations_dry_run.sql
   ```

   It runs the migration and its checks against the live database inside one transaction and rolls back. A pass ends with a row reading `OK: …` and `translation_tables_left_behind = 0`. If the CLI will not take a multi-statement file, paste the file into the dashboard's SQL editor instead.
4. **Production logging of session-refresh errors**, if you want the last English word-matching removed from the sign-out decision.
5. **An English sweep, if you want one more.** The English screenshots were last compared at slice 21. The screens changed after that (statistic, growth projection, pact) are identical in before/after test renders, but have not been re-photographed in the running app in English.
6. **The 7-day soak** after shipping.

**Smaller questions, none blocking**

- Dates for English users outside the US ("Nov 3, 2026" for Australians and Britons): keep, or make them follow the region?
- May I delete the apparently unused `ErrorViewScreen.swift`, `AppStrings.swift` and the Poppins styles?
- Should the app sign out when the server says the session or the account no longer exists? Today it keeps the cached session.
- "Hi" in the thumbnail for "The Opener": keep for other languages, or redraw? (Release B)

## Not verified, in one place

- The priced paywall, the trial badge, plan rows and the one-time offer on screen.
- The sign-in legal line and its links inside the running app.
- Any analytics event arriving in PostHog, including the 17 call sites that now pass through a recording seam.
- The profile-language write, and whether a sign-in provider sets its own `locale` (the reason the field is `app_language`).
- Database translations against real tables; a real lesson overlay file in the app.
- Lessons, quizzes, scenarios in play, the approach sheet and settings with doubled text.
- Anything on a real device or in a Release build.

## Deliberate departures from the plan

- **`app_language`, not `locale`,** for the language on the user's profile, to avoid a clash with sign-in providers' own claim.
- **The English word search in the sign-out decision is kept as a fallback** instead of removed, because the production logging that was to come first has not happened.
- **Dates and a few error messages stay exactly as they were in English** and become locale-aware only in a translated app, to keep Release A from changing what English users see.
- **Plan rows were not changed.** Drawn with long text they already keep the price intact; a test now guards that.
- **Paywall ticks got a length limit in the validator instead of a new layout.** They are not cut; a wrapped tick pushes the last one out of sight, which is what the existing 36-character rule prevents.
