/loop Continue Wingman's German translation (Release B) on branch `localization-release-b` in /Users/arthur/Desktop/wingman-app. Do one unit of work per iteration, commit it, log it, and pace yourself.

Read first, every iteration: `docs/localization-de-brief.md` (glossary, tone, rules), `docs/localization-de-progress.md` (what is done; create it on the first iteration), and section 7 of `docs/localization-implementation-plan.md`.

First iteration only: `git switch localization-release-b`. Commit the uncommitted German catalog work, the German sweep and its screenshots with the message "Release B: German UI catalogs (draft), German sweep". Only then start the work below.

Work, in this order:

1. **Lesson overlays (G3).** Run `python3 scripts/lesson_overlays.py export de` into a scratch folder. Translate ONE course per iteration into German, following the brief: informal "du", adapted rather than word-for-word, Wingman/XP and the five category names untranslated. Put the finished file under `Wingman/Courses/Lesson Overlays/`. Run `python3 scripts/lesson_overlays.py check de` until it passes, then commit ("Release B: German lessons, course N"). Start with the courses a new user meets first.
2. **Database content (G4), after all 25 courses are done.** Read `supabase/migrations/20261110000000_content_translations.sql` for the table shapes. Read the English quiz questions and scenarios READ-ONLY from the live database through the Supabase MCP. First check with list_projects that it reaches Wingman-App (bnckmgnysfliiypvxxii); stop and log it if it does not. Write the German as insert statements into `supabase/seed/content_translations_de/` (one file per scenario, questions in batches of about 100), keyed by the English IDs exactly as the migration requires. Never execute them.
3. When both are done, list in the progress log what still needs Arthur: native-speaker review, applying the migration, the App Store listing (G9), auth emails (G10), and a German sweep that also shows lessons.

After each unit: run `python3 scripts/check_string_catalogs.py --languages de --strict-lengths`. If you changed any Swift, run the unit tests on the "Wingman L10n 17 Pro" simulator (`-only-testing:WingmanTests`). Add a dated line to `docs/localization-de-progress.md`: what was done, word count, anything uncertain for the reviewer. Commit.

Never:
- push, open a PR, merge, or touch the `localization-release-a` or `Shat` branches;
- apply a migration or write anything to Supabase, PostHog, RevenueCat, App Store Connect or Meta;
- run a UI sweep or anything that launches the app against production (each one creates a real guest user);
- change app logic. Translation files only, plus a test fix if one is truly needed, explained in the log;
- mark strings reviewed (`--reviewed`). Everything stays "needs review".

If something blocks you (a validator rule you can't satisfy, an ambiguous source text, the MCP reaching the wrong project), write it under "Questions for Arthur" in the progress log and move on to the next unit. Do not guess on anything that touches money, the law or data.

Stop the loop when G3 and G4 are both written and checked, or if three iterations in a row make no progress. Finish with a short summary at the top of the progress log.
