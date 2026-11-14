/loop Set up Wingman's Spanish and French release (Release C) in /Users/arthur/Desktop/wingman-app, then hand the translation to two parallel sessions. Copy exactly how German (Release B) was done. One unit of work per iteration; commit it, log it, pace yourself.

This is prompt 1 of 3. The other two, `docs/localization-release-c/1-spanish-prompt.md` and `docs/localization-release-c/2-french-prompt.md`, are what you start the two language sessions with at the end. Read both on the first iteration so the groundwork fits what they expect.

## Goal of this session

Everything both languages share, done once, so the two language sessions only ever touch their own files:
- language-generic scripts and tests (Phase 0);
- the Spanish and French briefs (Phase 1);
- both interface catalogs translated (Phase 2), because `Localizable.xcstrings` and `Content.xcstrings` hold every language in one file and two sessions editing them would conflict;
- then start the Spanish and French sessions (Phase 3).

## Read first, every iteration

1. `docs/localization-release-c-progress.md` (create it on the first iteration, modelled on `docs/localization-de-progress.md`). This is the shared log; the language sessions keep their own.
2. For reference: `docs/localization-de-brief.md`, `docs/localization-de-progress.md`, `docs/german-launch-checklist.md`, section 7 of `docs/localization-implementation-plan.md`, and `docs/localization-de-overnight-prompt.md` (the loop that did German).

## Decisions already made (do not reopen)

- **One Spanish, not two.** Ship a single `es` localization in neutral Latin American Spanish that Spaniards also read naturally. Reason: `L10n.contentLanguage` (`Wingman/Util/L10n.swift`) uses the running localization tag for lesson overlay files, database translation rows and the bundled question seed. If the app shipped `es` and `es-419`, a Mexican phone would run `es-419`, find no `es-419` rows and fall back to English. With only `es`, every Spanish phone (es-ES, es-MX, es-419, es-US) runs `es`. Do **not** add `es-419`, `es-MX` or `fr-CA`.
- **French is `fr`** (France as the reference; Canada and Belgium fall back to it).
- **Informal address everywhere,** as German uses *du*: Spanish **tú** (plural **ustedes**, never *vosotros*, never *vos*); French **tu**.
- **Never translate:** Wingman, XP. Category names are translated, as German does; analytics keeps the English names.
- **Analytics, product IDs, entitlement checks, onboarding answer IDs and `title` fields stay English.** Screens read `displayTitle`.
- **Adapt, don't translate word for word,** as the German brief says.
- Privacy and terms pages stay English for now (decision D6).

## Phase 0. Branch and groundwork

1. Check `git status` and `git log Shat..localization-release-b`. If `localization-release-b` has commits not in `Shat`, or there are uncommitted changes other than `Wingman.xcodeproj/xcshareddata/xcschemes/Wingman.xcscheme` and the untracked `docs/localization-release-c/` folder (these three prompts), **stop and ask Arthur** what to do with them. Otherwise `git switch Shat`, create `localization-release-c` from it, and commit `docs/localization-release-c/` as its first commit ("Release C: prompts"). Leave the scheme change uncommitted.
2. **Make every German-only assumption language-generic.** Search `Wingman/`, `WingmanTests/`, `WingmanUITests/` and `scripts/` for `"de"`, `_de`, `German` and `Deutsch`. Known places:
   - `Wingman.xcodeproj/project.pbxproj` `knownRegions`: add `es` and `fr`.
   - `scripts/db_translations_sql.py`: the JSON key is hard-coded `"de"` and the output folder is `content_translations_de`. Make it take the locale, read the matching key, and write `supabase/seed/content_translations_<locale>/` and `Wingman/Content/question_translations_seed.<locale>.json`. German output must stay byte-identical: regenerate German and `git diff` to prove it.
   - `scripts/lesson_overlays.py`, `scripts/question_translations_seed.py`, `scripts/import_catalog_translations.py`, `scripts/check_string_catalogs.py`: confirm each works for `es` and `fr`; fix German-only wording in messages.
   - `scripts/german_review_pack.py` → `scripts/review_pack.py <locale>`, with per-language "Choices to check" rows read from a small per-language file (e.g. `localization/<locale>/review/choices.json`) so each language session can fill its own without editing the script. German output stays the same.
   - The unit test that guards which overlay languages may ship (it allows German and rejects others; look in `LessonOverlayTests` and nearby): allow `de`, `es`, `fr`.
   - `WingmanTests/GermanReleaseChecksTests.swift`: make the fallback and analytics-parity checks run for every shipped language (`de`, `es`, `fr`), and have them **skip a language whose content isn't bundled yet** (log a note rather than fail), so the language sessions can work while the other language is unfinished. Do not weaken any German assertion.
   - `WingmanUITests/OnboardingSweepTests.swift`: add Spanish (`-AppleLanguages (es) -AppleLocale es_MX`) and French (`(fr)`, `fr_FR`) variants of the German sweep. Do not run them.
   - `Wingman/Util/AppLanguageSettings.swift` and the language row in `Wingman/Profile/SettingsSheet.swift`: confirm the picker lists Español and Français and `name(of:)` returns them; extend `AppLanguageSettingsTests`.
   - Confirm the app loads `question_translations_seed.<locale>.json` for the running language.
3. Run the unit tests on the "Wingman L10n 17 Pro" simulator (`-only-testing:WingmanTests`). Commit ("Release C: language-generic tooling and tests").

## Phase 1. Briefs (one iteration each)

Write `docs/localization-es-brief.md` and `docs/localization-fr-brief.md` with the German brief's sections: who reads this, adapt-don't-translate examples, fixed choices, hard limits, "look at these first", open points. Fixed choices to settle:

| Topic | Spanish (`es`) | French (`fr`) |
|---|---|---|
| Address | tú / ustedes; short imperatives (*elige*, *prueba*) | tu (*choisis*, *essaie*) |
| Regional words | Neutral LatAm: *celular* not *móvil*; avoid *coger*, *vosotros*, *vale*, *guay*, *chévere*, *padre*; *ligar* is fine | Metropolitan French; no Québec-only terms |
| Subscription | *suscripción* (*mensual*, *anual*, *Gestionar suscripción*) | *abonnement* (*mensuel*, *annuel*, *Gérer l'abonnement*) |
| Terms / Privacy | *Términos* / *Privacidad*; full: *Términos de uso* / *Política de privacidad* | *CGU* / *Confidentialité*; full: *Conditions d'utilisation* / *Politique de confidentialité* |
| Approach (noun) | pick one and keep it | pick one and keep it |
| Level | *Nivel %lld* | *Niveau %lld* |
| Numbers | choose `45 %` or `45%` and state it | `45 %` with a narrow no-break space (U+202F) |
| Punctuation | opening ¿ and ¡ always; choose «…» or "…" | narrow no-break space before `; : ! ?`; « … » with narrow no-break spaces inside |
| Plurals | fill *one* and *other*; *many* only if Xcode or the validator requires it | **0 and 1 are both singular** (*0 leçon*, *1 leçon*); fill *one*, *other*, *many* if required |

Check the validator's format-specifier rule (in German, `% d` read as a placeholder) against French `% d…` and Spanish `% de`, and write the workaround into each brief.

Also add a glossary section to each brief for lesson terms the language session must keep consistent (closing, calibration, outcome independence, social proof, approach, rep/volume, banter, teasing). Use the German log's choices as a guide to what's tricky.

## Phase 2. Interface catalogs (both languages here)

Spanish first, then French: translate both String Catalogs (574 strings for German) into `localization/<locale>/catalogs.<locale>.json` (English key → translation), import with `python3 scripts/import_catalog_translations.py <locale> localization/<locale>/catalogs.<locale>.json`, validate with `python3 scripts/check_string_catalogs.py --languages de,es,fr --strict-lengths`.

- **Paywall ticks: 36 characters at most** (wraps on the iPhone SE). Rewrite rather than truncate.
- Placeholders (`%@`, `%lld`, `%1$@`) survive exactly; link targets like `(terms)` never change.
- Course titles: translate them now, mark the uncertain ones in the brief's open points; the language session may suggest better titles once it has read the lessons, and logs them for Arthur rather than editing the catalog.
- Paywall and one-time-offer price sentences must read correctly with StoreKit prices in MXN, COP, ARS, CLP, EUR, CAD and CHF. Note any that break.
- Commit per language ("Release C: Spanish UI catalogs (draft)").

## Phase 3. Hand off to the two language sessions

When Phases 0–2 are committed and the checks pass:

1. Make sure everything is committed on `localization-release-c` and the working tree is clean.
2. Start two sessions, one per language, each in **its own worktree** (`use_worktree: true`), on Opus, with `context: "fresh"`. The session's prompt is the full text of `docs/localization-release-c/1-spanish-prompt.md` and `docs/localization-release-c/2-french-prompt.md` respectively. Titles: "Wingman Spanish (Release C)" and "Wingman French (Release C)". Arthur asked for this in the prompt that started this session, so these are user-asked.
3. If the app refuses to start them (for example because this iteration was started by the loop's timer, not by Arthur), propose them as cards instead and tell Arthur in one line to click both.
4. Log both session links in the progress log, then **stop the loop**.

## Final step (only when Arthur asks, after both language sessions finish)

Merge `localization-release-c-es` and `localization-release-c-fr` into `localization-release-c` (they touch separate files, so there should be no conflicts; stop and ask if there are), run every check for `de`, `es` and `fr` plus the unit tests, then write `docs/release-c-launch-checklist.md` modelled on `docs/german-launch-checklist.md`:
1. Native proofread for each language (review packs, priority set first). For Spanish, ideally a Mexican reviewer plus a Spaniard's pass on the paywall and onboarding.
2. **Regional pricing** (Arthur does this in App Store Connect): Mexico, Colombia, Argentina, Peru, Chile at roughly 40–60% of the US price, Argentina watched for currency swings; Spain, France, Belgium, Switzerland, Canada near today's prices; the one-time offer product too. India pricing was discussed separately (₹499 / ₹2,499 / win-back ₹1,299).
3. Privacy and legal: the open German questions apply to France and Spain too; add France's rules on French-language consumer terms and Mexico's LFPDPPP.
4. Auth emails, only if any are sent.
5. Sandbox purchase in a Mexican and a French storefront with the disclosure checklist (`docs/localization-disclosure-checklist.md`).
6. Testing, the version check (what's live before bumping), build and submit.
7. After launch: watch by `app_language` and country.

## After each unit

Run the checks for what you touched; if you changed Swift, run the unit tests. Add a dated line to the progress log. Commit.

## Never

- push, open a PR, or change `Shat`, `localization-release-a` or `localization-release-b`;
- write anything to Supabase, PostHog, RevenueCat, App Store Connect or Meta;
- run a UI sweep, a Release build or anything against production without Arthur's say-so in chat;
- change app behaviour beyond the Phase 0 generalisation; German output must stay identical;
- mark strings reviewed (`--reviewed`);
- delete or detach `wingman_yearly_discount` or touch the duplicate Japan quiz question.

If something blocks you, write it under "Questions for Arthur" in the progress log and move to the next unit. Do not guess on anything that touches money, the law or data. Stop if three iterations in a row make no progress.
