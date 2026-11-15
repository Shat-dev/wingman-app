/loop Translate Wingman into Japanese (Release D, `ja`) in /Users/arthur/Desktop/wingman-app, copying how German (Release B) and Spanish/French (Release C) were done. One unit of work per iteration; commit it, log it, pace yourself.

This is a single session: groundwork, brief, interface catalogs, lessons, database content, checks and the listing draft, in that order. There is no twin session, so you may edit the shared catalogs, scripts and tests where this prompt says so.

## First iteration only

1. Check where you are: `git branch --show-current`, `git status`, `git log --oneline -5`. You should be in your own worktree. Create `localization-release-d-ja` from `Shat` (`git switch -c localization-release-d-ja Shat`). `Shat` must contain "Merge Release C (Spanish + French) into Shat; bump to 1.16 (40)"; if it does not, stop and say so in the log.
2. Commit `docs/localization-release-d/` as the first commit ("Release D: prompt") if it is not committed yet.
3. Create `docs/localization-ja-progress.md`, modelled on `docs/localization-es-progress.md`.

Why a branch and not `Shat` itself: adding `ja` to the bundle before the content is finished would ship a half-Japanese app from any archive made in the meantime. Arthur keeps one universal branch, so this branch exists only until the Japanese is complete and is then merged into `Shat` (final step).

## Read first, every iteration

1. `docs/localization-ja-progress.md` (your log).
2. `docs/localization-ja-brief.md` once it exists (your glossary, tone and rules). Follow it exactly.
3. For reference: `docs/localization-fr-brief.md` and `docs/localization-es-brief.md` (the brief format), `docs/localization-de-progress.md` (how German handled the hard terms), `docs/localization-release-c-progress.md` (what the shared setup did), `docs/release-c-launch-checklist.md`.

## Decisions already made (do not reopen)

- **Locale is `ja`.** One Japanese; no regional variants.
- **Register: polite です・ます in a warm coach's voice,** never stiff keigo and never rough. Buttons and nudges use short forms (〜しよう, 〜してみよう, or a noun phrase). Drop the pronoun wherever Japanese allows; never 君 or お前, and あなた only where the sentence fails without it. This replaces the *du / tú / tu* rule: Japanese has no equivalent, and casual speech from an app to a paying adult reads as rude.
- **Scenario dialogue is natural spoken Japanese.** The man opens in polite speech with a stranger, as a Japanese man would; where the English scene shows rapport building, moving to casual speech is part of that and should be shown. The woman's lines are written as a Japanese woman would say them, not translated line by line.
- **Never translate:** Wingman, XP (both stay in Latin letters). Category names are translated, as the other languages do; analytics keeps the English names.
- **Analytics, product IDs, entitlement checks, onboarding answer IDs and `title` fields stay English.** Screens read `displayTitle`.
- **Adapt, don't translate word for word.** The principles stay exactly as the English has them. The examples move to Japan: Tokyo, Osaka or Fukuoka instead of a US city; metric units; a local sport; exchanging LINE where the English swaps numbers or Instagram.
- **Do not change the advice itself.** Where the English advice may not suit Japan (direct compliments to a stranger, touch, persistence on the street, the step from dating to a couple, which in Japan usually goes through an explicit confession), translate it faithfully and add a line under "Cultural flags for Arthur" in the log with the lesson id and one sentence on the concern. Arthur decides; you do not rewrite.
- **Consent wording in 17_3 stays as strict as the English.**
- **Women's names in scenarios keep the same name, written in katakana** (log the mapping once in the brief). Latin-letter names inside Japanese sentences read badly.
- **Statistics keep their numbers and are not presented as Japanese findings.** Log each one under "Cultural flags for Arthur".
- **Punctuation and numbers:** 、。「」！？ full-width; digits, `%` and Latin letters half-width (`45%`, no space); no space between Japanese text and digits. State it in the brief.
- **Plurals:** Japanese has only the *other* form. Fill that one; add another only if Xcode or the validator requires it.
- Privacy and terms pages stay English for now (decision D6).

## Phase 0. Groundwork (one or two iterations)

Release C already made the scripts and tests language-generic. What is left:

1. Add `ja` to `knownRegions` in `Wingman.xcodeproj/project.pbxproj`.
2. Search `Wingman/`, `WingmanTests/`, `WingmanUITests/` and `scripts/` for every list of shipped languages (`de`, `es`, `fr` together) and add `ja`: the overlay allow-list test, `ReleaseLanguageChecksTests`, `AppLanguageSettings` and its tests (the picker must list 日本語), the sweep tests, and the default of any `--languages` argument.
3. **Width-aware length check.** `scripts/check_string_catalogs.py` counts characters (`PAYWALL_TICK_LIMIT = 36`). A Japanese character is about twice as wide as a Latin one, so 36 Japanese characters overflow. Count East Asian wide and full-width characters as 2 (use `unicodedata.east_asian_width`), so the limit means the same on screen. Output for `de`, `es` and `fr` must not change: run the check before and after and compare.
4. **Fonts.** The app's fonts are Manrope and Poppins (`Wingman/Fonts`); neither has Japanese glyphs, so iOS falls back to its own Japanese font. Do not add a font. Log under "Questions for Arthur" that headings and bold text need a look in the sweep (fallback weight, line height, clipped tops).
5. Add a Japanese variant of the onboarding and content sweeps to `WingmanUITests/OnboardingSweepTests.swift` (`-AppleLanguages (ja) -AppleLocale ja_JP`). Do not run it.
6. Check the paywall and one-time-offer price sentences against yen: no decimals, `¥` before the number, per-week and per-month figures still reading correctly. Note any that break; do not change pricing code without logging why.
7. Run the unit tests on the "Wingman L10n 17 Pro" simulator (`-only-testing:WingmanTests`). Commit ("Release D: Japanese groundwork").

Do not weaken any existing German, Spanish or French assertion. Incomplete Japanese content should make the per-language checks skip Japanese, as Release C set up, not fail.

## Phase 1. Brief (one iteration)

Write `docs/localization-ja-brief.md` with the French brief's sections: who reads this, adapt-don't-translate examples, fixed choices (the decisions above plus your own), validator workarounds, hard limits, glossary, "look at these first", open points.

Settle and write down: subscription wording (サブスクリプション or プラン; 月額 / 年額; the manage-subscription label Apple uses in Japanese), Terms / Privacy labels (利用規約 / プライバシーポリシー), "Level %lld", date format, how "approach" is said as a noun and a verb, and the glossary terms the lessons repeat (closing, calibration, outcome independence, social proof, rep/volume, banter, teasing, escalation, rejection). For "approach", avoid ナンパ in the interface and the listing: it carries a pushy, street-hustler image; note where it is unavoidable in lesson text.

## Phase 2. Interface catalogs (one or two iterations)

Translate both String Catalogs (585 strings in Spanish and French) into `localization/ja/catalogs.ja.json` (English key → translation), import with `python3 scripts/import_catalog_translations.py ja localization/ja/catalogs.ja.json`, validate with `python3 scripts/check_string_catalogs.py --languages de,es,fr,ja --strict-lengths`.

- Paywall ticks obey the width-aware limit. Rewrite rather than truncate.
- Placeholders (`%@`, `%lld`, `%1$@`) survive exactly, reordered where Japanese word order needs it; link targets like `(terms)` never change.
- Sentences built from pieces (streaks, "days ago", the offer disclosure) must read correctly in Japanese word order. Where they cannot, log it under "Questions for Arthur" with the screen name.
- Commit ("Release D: Japanese UI catalogs (draft)").

## Phase 3. Lesson overlays (one course per iteration)

`python3 scripts/lesson_overlays.py export ja <scratch folder>`. Translate into `Wingman/Courses/Lesson Overlays/lesson_overlay_course_<n>_ja.json`. Run `python3 scripts/lesson_overlays.py check ja` until it passes. Commit ("Release D: Japanese lessons, course N"). Order, as German: 1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, then 3, 8, 14, 19, 24, then 4, 9, 15, 20, 25, then 5, 10, 16, 21, 11.

## Phase 4. Database content (after all 25 courses)

The translation tables already exist on production and accept any locale; no migration is needed.

- Use the German source files as your English side: `localization/de/db/*.json` hold every English id and text. Write `localization/ja/db/<same file name>.json` with `en` and `ja` side by side, in the same shape.
- Check with the Supabase MCP `list_projects` that it reaches **Wingman-App (bnckmgnysfliiypvxxii)**, and re-check a sample of ids against the live DB with **SELECT only**. If it reaches another project, skip the check, log it, and continue.
- One scenario per iteration; quiz questions in the same nine batch files German used. Run `python3 scripts/db_translations_sql.py ja` and `python3 scripts/question_translations_seed.py ja --check`. **Never execute the SQL.**

## Phase 5. Checks and review pack

- The catalog check, the overlay check and the DB generator all pass for `de,es,fr,ja`.
- Unit tests on the "Wingman L10n 17 Pro" simulator, including the per-language fallback and analytics-parity tests, with Japanese no longer skipped.
- Search the Japanese for: mixed です・ます and plain endings inside one screen, 君 / お前 / あなた, half-width punctuation in Japanese sentences, full-width digits, left-over English sentences, and ナンパ outside the places the brief allows. Fix and log.
- Fill `localization/ja/review/choices.json` and build the pack with `python3 scripts/review_pack.py ja`. Put onboarding, paywall, one-time offer and lesson 17_3 first: Arthur has no Japanese reader, so this priority set is what a paid native check would cover.

## Phase 6. App Store listing draft

Write `docs/japanese-app-store-listing.md` modelled on `docs/french-app-store-listing.md`: name, subtitle, 100-character keyword field, description, promotional text, What's New, subscription display names (group, monthly, yearly), screenshot captions, and the retention message in Japanese. Keywords are a first guess from what people search (恋愛, 出会い, モテる, 会話, 自信, 声かけ…); mark them "not yet checked against Apple Ads popularity". Make Japanese copies of the screenshot HTML in `marketing/app-store-assets/` (new files only; do not render or upload).

## Final step (only when Arthur asks)

Merge `localization-release-d-ja` into `Shat`, run every check for `de`, `es`, `fr` and `ja` plus the unit tests, and write `docs/release-d-launch-checklist.md` modelled on `docs/release-c-launch-checklist.md`:
1. Native proofread (priority set first).
2. Cultural flags: Arthur's decision on each.
3. Pricing in yen (Arthur, in App Store Connect), the one-time offer product too.
4. Privacy and legal: the open questions from the other languages, plus Japan's Act on Specified Commercial Transactions (the seller disclosure Japanese consumers expect for paid services) and the Act on the Protection of Personal Information. State the questions; do not answer them.
5. Applying the Japanese rows to production (Arthur's go-ahead, id check first).
6. Japanese sweeps on both L10n simulators, with the font and line-break look called out.
7. Sandbox purchase in the Japanese storefront with `docs/localization-disclosure-checklist.md`.
8. Keyword popularity for Japan, listing pages, screenshots, subscription names.
9. The version check (what is live before bumping), build and submit.
10. After launch: watch by `app_language` and country.

## After each unit

Run the checks for what you touched; if you changed Swift, run the unit tests. Add a dated line to the progress log: what was done, the English word count, choices the reviewer should check. Commit.

## Never

- push, open a PR, merge, or change any branch other than `localization-release-d-ja`;
- write anything to Supabase, PostHog, RevenueCat, App Store Connect or Meta;
- run a UI sweep, a Release build or anything against production without Arthur's say-so in chat;
- change app behaviour beyond the Phase 0 list; German, Spanish and French output must stay identical;
- bump the version or build number;
- mark strings reviewed (`--reviewed`); everything stays "needs review";
- delete or detach `wingman_yearly_discount`, or touch the duplicate quiz question 4533a8d2/58d8c403.

If something blocks you, write it under "Questions for Arthur" in the log and move to the next unit. Do not guess on anything that touches money, the law or data.

Stop the loop when Phase 6 is done, or if three iterations in a row make no progress. Finish with a summary at the top of the log: what is done, word counts, a numbered "What needs Arthur" list, and the "Cultural flags for Arthur" list.
