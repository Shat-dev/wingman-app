# Spanish and French (Release C): setup log

Branch `localization-release-c`. Prompt: [localization-release-c/0-setup-prompt.md](localization-release-c/0-setup-prompt.md). This is the shared log for the setup session (Phases 0–3). The two language sessions keep their own logs: `docs/localization-es-progress.md` and `docs/localization-fr-progress.md`. Everything translated here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

Model: German (Release B), see [localization-de-progress.md](localization-de-progress.md) and [localization-de-brief.md](localization-de-brief.md).

## Where it stands

Phase 0 is done: the scripts and tests work for `de`, `es` and `fr`, German output is unchanged, and 341 unit tests pass. Next is Phase 1, the Spanish brief.

## Summary

| Phase | Part | State |
|---|---|---|
| 0 | Branch and prompts | Done (2026-11-15) |
| 0 | Language-generic scripts and tests | Done (2026-11-15) |
| 1 | Spanish brief | Not started |
| 1 | French brief | Not started |
| 2 | Spanish UI catalogs | Not started |
| 2 | French UI catalogs | Not started |
| 3 | Spanish and French sessions started | Not started |

## Log

- **2026-11-15. Branch and prompts.** `localization-release-b` had two commits not in `Shat` (`69c708b`, `893fef3`, "Final changes", 13 Nov: Xcode 26.6 upgrade check, one analyzer setting, test-target ID reorder, scheme tweaks). Asked Arthur; he chose to branch from `localization-release-b`, so `localization-release-c` starts at `893fef3` and includes them. `Shat` is unchanged. The uncommitted scheme change (Run language `de` → `en`) stays uncommitted, as the prompt says. First commit: "Release C: prompts".

- **2026-11-15. Phase 0: language-generic tooling and tests.** Everything German-only now takes the locale; German output is unchanged.
  - `project.pbxproj` `knownRegions`: added `es`, `fr`. The app code already worked for any language: the Settings picker lists the bundle's localizations and names them with `Locale` (*Español*, *Français*); `L10n.contentLanguage` uses the running localization; `QuestionTranslationSeed` loads `question_translations_seed.<lang>.json`; new files are bundled automatically (synchronized folders).
  - `scripts/db_translations_sql.py <locale>`: reads the locale's own JSON key (it was hard-coded `"de"`), messages name the language, and it stops cleanly if `localization/<locale>/db/` doesn't exist. Regenerating German gives byte-identical SQL (24 files) and seed (765 rows): `git diff` shows nothing.
  - `scripts/german_review_pack.py` → `scripts/review_pack.py <locale>`. The "Choices to check" rows, the "How to fill it in" rules and the Read me example now live in `localization/<locale>/review/choices.json` (German's written from the old constants). The German workbook is cell-for-cell identical (values, fonts, fills, comments, widths, validations compared). `docs/german-launch-checklist.md` points at the new command.
  - `lesson_overlays.py`, `question_translations_seed.py`, `import_catalog_translations.py`, `check_string_catalogs.py` already took the locale; only German-only wording in two docstrings changed. `check_string_catalogs.py --languages de,es,fr --strict-lengths` passes (es and fr fall back to English everywhere).
  - Tests: `LessonOverlayTests` allows overlays for `de`, `es`, `fr` and rejects others, and checks every bundled file of each loads. `GermanReleaseChecksTests` → `ReleaseLanguageChecksTests`: the same fallback and analytics-parity checks, run for every shipped language. German is required and its assertions are unchanged; a Spanish or French part (catalogs, all 25 overlays, all 765 quiz rows, all 15 scenario files) that isn't complete is skipped with a `note: ReleaseLanguageChecks skipped …` line in the test log. `AppLanguageSettingsTests`: Spanish and French names, and every regional tag (es-MX, es-419, es-ES, fr-CA, fr-BE…) lands on `es` / `fr`. `StringCatalogTests` and the "this build offers" test accept es/fr appearing once their catalogs exist; **tighten both to exactly en, de, es, fr after Phase 2.**
  - `OnboardingSweepTests`: Spanish (`es`, `es_MX`) and French (`fr`, `fr_FR`) variants of both German sweeps. The lesson and scenario titles are now read from the language's overlay and DB file instead of hard-coded German; the starts of long sentences are derived from the catalog for es/fr (German keeps its hand-written list); the Daily Practice "Start" button no longer assumes the Home tab is also called "Start". Compiled, **not run**.
  - Unit tests on "Wingman L10n 17 Pro": 341 run, 336 passed, 5 skipped, 0 failed (2 new).

## Questions for Arthur

None open.
