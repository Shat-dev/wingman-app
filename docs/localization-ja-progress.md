# Japanese (Release D): progress log

Branch `localization-release-d-ja` (from `Shat` at `38cad8d`, which contains "Merge Release C (Spanish + French) into Shat; bump to 1.16 (40)"). Prompt: [localization-release-d/japanese-prompt.md](localization-release-d/japanese-prompt.md). Rules and glossary: [localization-ja-brief.md](localization-ja-brief.md). Models: German [localization-de-progress.md](localization-de-progress.md), Spanish [localization-es-progress.md](localization-es-progress.md), French [localization-fr-progress.md](localization-fr-progress.md), shared setup [localization-release-c-progress.md](localization-release-c-progress.md). Everything translated here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database, and Arthur has no Japanese proofreader yet.

## Where it stands

**Phases 0 (groundwork) and 1 (brief) are done (2026-11-16).** The project, the tests, the scripts and the sweep know about `ja`, and the rules and glossary are written; no Japanese app text exists yet, so the app is unchanged and no build offers Japanese. Next: Phase 2, the interface catalogs.

Nothing is pushed, merged, applied to Supabase or entered in App Store Connect. No UI sweep and no Release build has been run.

## Summary

| Phase | Part | State |
|---|---|---|
| 0 | Branch, prompt, groundwork | **Done** (2026-11-16) |
| 1 | Brief ([localization-ja-brief.md](localization-ja-brief.md)) | **Done** (2026-11-16) |
| 2 | Interface catalogs (586 strings: 407 + 179) | Not started |
| 3 | Lesson overlays (25 courses, 1,531 items, 34,475 English words) | 0 of 25 |
| 4 | Database content (15 scenarios, 765 quiz questions) | Not started |
| 5 | Checks and review pack | Not started |
| 6 | App Store listing draft | Not started |

Lesson order, as German: 1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, then 3, 8, 14, 19, 24, then 4, 9, 15, 20, 25, then 5, 10, 16, 21, 11.

To do once Phase 2 is in (carried over from how Release C did it): move `ja` from `incomingLanguages` into `shippedLanguages` in `StringCatalogTests`, and make `AppLanguageSettingsTests.testThisBuildOffers…` require exactly en, de, es, fr, ja.

## Log

- **2026-11-16. Branch and prompt.** The app created this worktree on `claude/localization-release-d-ja-16d560`, at `Shat` (`38cad8d`). It was renamed to `localization-release-d-ja` (same commit, so the same result as `git switch -c localization-release-d-ja Shat`). `Shat` contains the Release C merge (`9f26fab`). The prompt was untracked in the main checkout, so it was copied here unchanged and committed as "Release D: prompt" (`f1f78a4`). The main checkout was only read (that one file).
- **2026-11-16. Phase 0: groundwork.** No Japanese text yet; German, Spanish and French output is unchanged.
  - **Project.** `ja` added to `knownRegions` in `project.pbxproj`. The bundle only gains `ja.lproj` once the catalogs hold Japanese (Phase 2), so until then the Settings language menu and `Bundle.main.localizations` are exactly as on `Shat`.
  - **App code.** Nothing to change: the Settings picker lists the bundle's localizations and names each with `Locale` (Japanese shows as 日本語), `L10n.contentLanguage` follows the running localization, and overlays, the quiz seed and DB rows are looked up by language tag.
  - **Tests** (no German, Spanish or French assertion weakened):
    - `StringCatalogTests`: en, de, es, fr are still required; `ja` is allowed to appear (`incomingLanguages`), as Release C did for es/fr.
    - `AppLanguageSettingsTests`: the "this build offers" test requires en, de, es, fr first and allows `ja` after them; new tests that the menu lists 日本語 last, that `ja`, `ja-JP` and `ja-US` all land on `ja`, and that adding Japanese moves no one else (`fr-CA` stays French, `zh-Hans` stays English).
    - `LessonOverlayTests`: the overlay allow-list is now de, es, fr, ja.
    - `ReleaseLanguageChecksTests`: `ja` added to the shipped languages. German stays the only required one, so each Japanese part (catalogs, all 25 overlays, all 765 quiz rows, all 15 scenario files) is skipped with a `note: ReleaseLanguageChecks skipped 'ja' …` line until it is complete.
  - **Sweeps.** `OnboardingSweepTests` has `testOnboardingInJapanese` and `testOnboardingAndContentInJapanese` (`-AppleLanguages (ja) -AppleLocale ja_JP`). They reuse the es/fr path (text read from `localization/ja/catalogs.ja.json`, the lesson overlay and the scenario file). Compiled with the unit-test build, **not run**.
  - **Width-aware length check.** `scripts/check_string_catalogs.py` now measures the paywall ticks as width on screen: East Asian wide and full-width characters count as 2 (`unicodedata.east_asian_width` W or F), everything else as 1. So the limit of 36 means about 18 Japanese characters. For Latin-script text the width is the character count: the output for `--languages de,es,fr` (with and without `--strict-lengths`) is byte-identical before and after, and no existing limited string has a width different from its length.
  - **Brand-term check (found while testing, also fixed).** The validator looked for `Wingman` and `XP` with a word-boundary pattern. Japanese has no spaces and its letters count as word characters, so `Wingmanで` and `100XPを` would have been reported as "brand term missing". The check now tests the edges against Latin letters only. Checked against all 1,781 existing de/es/fr strings: the old and new rule agree on every one.
  - **Other scripts.** `db_translations_sql.py` knows the name "Japanese" (messages only); usage lines in it and `review_pack.py` mention `ja`. `lesson_overlays.py`, `import_catalog_translations.py` and `question_translations_seed.py` needed nothing.
  - **Yen.** Checked on this Mac with the same `NumberFormatter` set-up StoreKit and RevenueCat use (currency JPY; device locale ja_JP, en_JP, en_US). Results for example prices ¥5,800 a year, ¥1,300 a month, ¥2,900 offer: full price `¥5,800`, weekly line `¥112` (yearly) and `¥300` (monthly), zero price `¥0`. No decimals, a half-width `¥` in front, thousands comma. All price sentences take the price as one finished `%@` (*only %@ per week*, *Try for %@*, the nine *%@ billed today…* disclosures), so nothing in the wording depends on decimals. **Nothing breaks; no pricing code was changed.** Two notes, neither new with Japanese:
    - The weekly figure is rounded to a whole yen (¥5,800 ÷ 52 = 111.5 → `¥112`), where other currencies round to a cent. It is an "only … per week" illustration, as today.
    - On a phone whose region uses another currency format, iOS writes `JPY 5,800` instead of `¥5,800` (seen with en_AU). That is iOS's own formatting, the same as for every other currency.
    - `OneTimeOfferViewModel.introPricePerMonthString` builds its own formatter from the device locale without the product's currency, so on a phone set to another region it would print the yen amount with that region's symbol and decimals (`$241.67`). It is not shown anywhere in the app today (no caller), so nothing is wrong on screen; noted in case the line is ever put back.
  - **Counts.** The catalogs now hold 586 translatable strings (407 Localizable + 179 Content), one more than the 585 in the prompt (Localizable has 416 entries, 9 marked do-not-translate). The English lessons are 34,475 words in 1,531 items (34,442 when Spanish and French were done; the English was edited since).
  - **Unit tests** on "Wingman L10n 17 Pro": **349 run, 344 passed, 5 skipped, 0 failed** (80 s; `xcodebuild test -scheme Wingman -only-testing:WingmanTests`, own derived-data folder; the UI-test target, with the new Japanese sweeps, compiled as part of the same build). The 5 skips are the double-length pseudo-language probes, off by design. The log has the expected `note: ReleaseLanguageChecks skipped 'ja' …` lines for all four Japanese parts and none for de, es or fr, whose fallback and analytics-parity checks ran in full.
- **2026-11-16. Phase 1: Japanese brief** ([localization-ja-brief.md](localization-ja-brief.md)). Sections as the French brief: who reads this, adapt-don't-translate examples, fixed choices, validator notes, hard limits, glossary, "look at these first", open points. The prompt's decisions are marked "(decided)". My own choices, for the reviewer to check:
  - **Approach:** verb 声をかける; noun アプローチ (「アプローチを記録」). The native noun 声かけ is kept out of the interface because police bulletins use it (「声かけ事案」); it can still be a search keyword. ナンパ only where the English itself talks about pickup culture (ナンパ師, ナンパの決まり文句), each use logged.
  - **Subscription wording:** サブスクリプション; 月額プラン / 年額プラン / %lldか月プラン; 「サブスクリプションを管理」; cancel is 解約; 「購入を復元」; 無料トライアル. Terms / Privacy: 利用規約 / プライバシーポリシー (same for the footer and the full names). iOS Settings: 設定. These follow Apple's Japanese usage as I know it; not checked on a Japanese iPhone from here.
  - **Level:** レベル%lld. **Dates:** iOS formats them (2026年11月16日); in text 11月16日; 「%lld日前」, 「昨日」. **Months:** か月.
  - **Numbers and punctuation:** half-width digits, `%` and Latin letters with no space to the Japanese (45%の男性); full-width 、。「」！？（）：; ranges 18〜24歳; one … in the interface; large numbers the Japanese way (6万).
  - **Voice:** です・ます in running text; buttons and titles in short forms; no pronoun for the reader; the reader's own first person is 僕 (俺 only in casual scenario dialogue).
  - **Glossary:** opener 最初のひと言; closing 次につなげる (not クロージング, sales jargon); calibration 相手の反応を見て合わせる; outcome independence 結果に左右されない; social proof 社会的証明; reps / volume 場数 / 数をこなす; banter 軽い掛け合い; teasing 軽くからかう; escalation 距離を縮める; rejection 断られること; flirting 恋の駆け引き (open point: 駆け引き can also mean "playing games"); 17_3 consent line written out, as strict as the English.
  - **Names:** ソフィー, ローレン, ナオミ, ケイティ, アンバー, メル, サラ, エミリー, クレア, ゾーイ, ナタリー, オレリー; scenarios 12–14 have no name. He says 〜さん until the scene turns casual.
  - **Category names (draft):** マインドセットと土台, アプローチの実践, 会話の流れ, 恋の駆け引きと相性, 日常への定着と熟達.
  - **Validator:** `%` before Japanese is safe (the es/fr `% d` problem does not arise as long as no space or Latin word follows the sign); checked the brief's example strings against the script. The paywall tick limit is 18 full-width characters.
  - No app text, Swift or script changed in this unit, so no tests were run.

## Cultural flags for Arthur

(Advice translated faithfully that may not suit Japan, and every statistic. Lesson id and one sentence each. Arthur decides; nothing is rewritten.)

None yet: no content translated. One thing to know before the first flags arrive: the women's names stay as in English, in katakana, while the examples move to Tokyo, Osaka or Fukuoka, so ソフィー in a Tokyo bar reads as a foreign woman. That follows the decision in the prompt; it is listed in the brief's open points.

## Questions for Arthur

1. **Fonts in Japanese (look at this in the sweep).** The app's text is set in Manrope (bundled in `Wingman/Fonts`) and Poppins (named in code; no Poppins file is in `Wingman/Fonts`). Neither has Japanese glyphs, so iOS draws Japanese in its own font (Hiragino Sans) while digits, `%`, "Wingman" and "XP" stay in Manrope. No font was added, as decided. When the Japanese sweep is run, headings and bold text need a look: the fallback's weight may not match (Manrope Bold/SemiBold next to Hiragino W6), Japanese lines sit taller, and tops can clip where a fixed line height or tight frame was tuned for Latin letters.
2. **Japanese sweep.** `testOnboardingInJapanese` and `testOnboardingAndContentInJapanese` exist but have not been run. Each run creates a guest user in production, so they wait for your say-so.
