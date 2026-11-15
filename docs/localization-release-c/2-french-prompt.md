/loop Translate Wingman's lessons, quizzes and scenarios into French (Release C, `fr`) in /Users/arthur/Desktop/wingman-app, copying exactly how German (Release B) was done. One unit of work per iteration; commit it, log it, pace yourself.

This is one of two parallel language sessions. A setup session already made the scripts and tests language-generic, wrote the brief and translated the interface catalogs on branch `localization-release-c`. A Spanish twin is doing the other language at the same time in its own worktree. You only ever touch French files.

## First iteration only

1. Check where you are: `git branch --show-current` and `git log --oneline -5`. You must be on a branch that contains the setup commits ("Release C: language-generic tooling and tests" and "Release C: French UI catalogs (draft)"). If you are in a fresh worktree, create `localization-release-c-fr` from `localization-release-c` (`git switch -c localization-release-c-fr localization-release-c`). If the setup commits are missing, stop and write that in the progress log.
2. Create `docs/localization-fr-progress.md`, modelled on `docs/localization-de-progress.md`.

## Read first, every iteration

1. `docs/localization-fr-progress.md` (your log).
2. `docs/localization-fr-brief.md` (your glossary, tone and rules). Follow it exactly.
3. For reference: `docs/localization-de-progress.md` (how German handled the hard terms) and `docs/localization-de-brief.md`.

## Your files, and only these

- `Wingman/Courses/Lesson Overlays/lesson_overlay_course_<n>_fr.json`
- `localization/fr/db/*.json`
- `supabase/seed/content_translations_fr/*.sql` and `Wingman/Content/question_translations_seed.fr.json` (both generated, never hand-edited)
- `localization/fr/review/` (review pack and its `choices.json`)
- `docs/localization-fr-progress.md`, `docs/french-app-store-listing.md`
- French screenshot HTML copies in `marketing/app-store-assets/` (new files only)

**Do not edit** `Localizable.xcstrings`, `Content.xcstrings`, anything in `scripts/`, any Swift file, any test, `project.pbxproj`, or the shared `docs/localization-release-c-progress.md`. If you find a catalog mistake, a better course title, or a script bug, write it under "For the setup session" in your log and carry on.

## Work, in this order

1. **Lesson overlays.** `python3 scripts/lesson_overlays.py export fr <scratch folder>`. Translate **one course per iteration** into `Wingman/Courses/Lesson Overlays/`, following the brief. Run `python3 scripts/lesson_overlays.py check fr` until it passes. Commit ("Release C: French lessons, course N"). Order, as German: 1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, then 3, 8, 14, 19, 24, then 4, 9, 15, 20, 25, then 5, 10, 16, 21, 11. Keep the consent wording in 17_3 as strict as the English. Use metric units and local settings (Paris, Lyon or Bordeaux; football or rugby instead of baseball) where the English names a US place.
2. **Database content, after all 25 courses.** The translation tables already exist on production and accept any locale; no migration is needed.
   - Use the German source files as your English side: `localization/de/db/*.json` already hold every English id and text. Write `localization/fr/db/<same file name>.json` with `en` and `fr` side by side, in the same shape.
   - Check with the Supabase MCP `list_projects` that it reaches **Wingman-App (bnckmgnysfliiypvxxii)**, and re-check a sample of ids against the live DB with **SELECT only**. If it reaches another project, skip the check, log it, and continue.
   - One scenario per iteration; quiz questions in the same nine batch files German used. Run `python3 scripts/db_translations_sql.py fr` (generates the SQL and the bundled seed) and `python3 scripts/question_translations_seed.py fr --check`. **Never execute the SQL.**
   - Names of the women in scenarios stay unchanged.
3. **Checks, once everything is translated.**
   - `python3 scripts/check_string_catalogs.py --languages de,es,fr --strict-lengths`, the overlay check and the DB generator all pass.
   - Unit tests on the "Wingman L10n 17 Pro" simulator (`-only-testing:WingmanTests`), including the per-language fallback and analytics-parity tests. If the other language's content is missing in your worktree, those tests should skip it; if they fail because of it instead, log it for the setup session.
   - Search the French for formal *vous* where *tu* is meant, for missing narrow no-break spaces before `; : ! ?` and inside « », and for anglicisms where a normal French word exists. Fix and log.
   - Fill `localization/fr/review/choices.json` with the choices a reviewer should check, then build the review pack with `python3 scripts/review_pack.py fr`.
4. **App Store listing draft.** Write `docs/french-app-store-listing.md` modelled on `docs/german-app-store-listing.md`: **French (France)**, plus notes on what to change for **French (Canada)**. Name, subtitle, 100-character keywords researched for what people actually search (*draguer*, *aborder une femme*, *confiance en soi*, *séduction*…), description, promotional text, What's New, subscription display names, screenshot captions. Make translated copies of the screenshot HTML in `marketing/app-store-assets/` (do not render or upload).

## After each unit

Run the checks for what you touched. Add a dated line to your progress log: what was done, the English word count, choices the reviewer should check. Commit.

## Never

- push, open a PR, merge, or change any branch other than `localization-release-c-fr`;
- write anything to Supabase, PostHog, RevenueCat, App Store Connect or Meta;
- run a UI sweep, a Release build or anything against production;
- edit shared files (see "Your files, and only these");
- mark strings reviewed (`--reviewed`); everything stays "needs review".

If something blocks you, write it under "Questions for Arthur" in your log and move to the next unit. Do not guess on anything that touches money, the law or data.

Stop the loop when all four steps are done, or if three iterations in a row make no progress. Finish with a summary at the top of your log: what's done, word counts, a numbered "What needs Arthur" list, and anything under "For the setup session".
