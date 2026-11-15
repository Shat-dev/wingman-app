# Launching Wingman in Spanish and French: step by step

Written 2026-11-15 for Arthur. Branch `localization-release-c`. Nothing here is pushed or submitted yet. This follows the German checklist ([german-launch-checklist.md](german-launch-checklist.md)); where a step works the same way, this one points there instead of repeating it.

**Where things stand.**
- **Spanish (`es`, neutral Latin American) and French (`fr`, France) are fully drafted:**
  - the whole interface (585 strings each);
  - all 25 courses;
  - 765 quiz questions;
  - 15 scenarios.
- **Checks:** every check passes for German, Spanish and French. The unit tests pass on the merged branch with nothing skipped (341 run, 336 passed, 5 skipped by design, 0 failed; 2026-11-15).
- **Not seen on screen yet:** no simulator sweep has run in Spanish or French. Each run creates a guest user in production, so it waits for your OK.
- **Database rows:** the Spanish and French rows are generated as SQL but **have never been run**. Production has no Spanish or French rows.
- **Draft status:** all of it is a machine draft (written by Claude) and has not been read by a native speaker.
- **Earlier releases:** this branch also contains all of Release A and Release B (German), and neither has shipped.

Logs:
- [localization-release-c-progress.md](localization-release-c-progress.md) (setup);
- [localization-es-progress.md](localization-es-progress.md) (Spanish);
- [localization-fr-progress.md](localization-fr-progress.md) (French).

Briefs for reviewers: [localization-es-brief.md](localization-es-brief.md) and [localization-fr-brief.md](localization-fr-brief.md).

Who does each step:
- **You** (Arthur)
- **Proofreaders**: native speakers you hire, one per language
- **Adviser**: a lawyer or privacy adviser
- **Claude**: a future Claude Code session; just ask for the step by name

Costs are rough market rates, so get real quotes.

---

## Do these first

Start these four this week. They take the longest, and they don't depend on each other.

1. **Get both proofreads going** (step 1). The longest lead time, and it blocks the launch.
2. **Ask the adviser about France, Spain and Mexico** (step 3). You can add these to the German questions, so it's one conversation.
3. **Set regional prices** (step 2). Latin American prices at US levels would waste most of the Spanish work.
4. **Decide the shipping order** (step 9): German first, then Spanish and French, or all three together.

---

## The order at a glance

| Step | What | Who | Time / cost | Blocks |
|---|---|---|---|---|
| 1 | Spanish and French proofreads | Proofreaders, then Claude | 1–2 weeks; priority set ≈ €150–300 per language | Testing, submission |
| 2 | Regional pricing | You (App Store Connect) | 1–2 hours | Launch in Latin America |
| 3 | Privacy and legal check | You and adviser | Quote; 1–3 weeks | Marketing in those countries |
| 4 | Small decisions | You | 20 minutes | Nothing big |
| 5 | Auth emails | You, or Claude to draft | 15 minutes to 1 hour | Submission |
| 6 | Database: check, then apply | Claude, with your go-ahead | 1 hour | Testing scenarios, submission |
| 7 | App Store pages | Claude drafted; you finish and paste | 1–2 days | Submission |
| 8 | Testing before submission | You, Claude | 1–2 days | Submission |
| 9 | Version, build, submit | You, with Claude | 1–2 hours plus Apple review | Launch |
| 10 | After launch: watch | You, Claude | 4–6 weeks | Nothing |

Steps 1, 2 and 3 run in parallel. Steps 4 to 7 fit in while the proofreaders work. Step 8 needs steps 1 and 6 finished, and step 9 needs everything before it.

---

## Step 1. Native proofreads (one per language)

**Why:** Claude wrote all of it. Grammar is mostly right. What a writer can't catch in their own work is tone, and the wording around money and the law. In Spanish, the difficulty is also writing one Spanish that works from Mexico City to Madrid.

### 1a. The review packs (Claude) ✅ done 2026-11-15

| Language | Pack | Choices to check |
|---|---|---|
| Spanish | [`localization/es/review/wingman-spanish-review-pack.xlsx`](../localization/es/review/wingman-spanish-review-pack.xlsx) | 25 |
| French | [`localization/fr/review/wingman-french-review-pack.xlsx`](../localization/fr/review/wingman-french-review-pack.xlsx) | 26 |

They have the same six sheets as the German pack:
- **Read me**
- **Choices to check**
- **Interface:** 465 rows; the 215 "Must read" rows are highlighted.
- **Lesson 1_1** and **Lesson 6_1**
- **Daily quotes**

Rebuild a pack after any change with `python3 scripts/review_pack.py es` (or `fr`). The choices and house rules live in `localization/<lang>/review/choices.json`.

**Priority set,** about 4,700 English words per language: the whole interface plus the two sample lessons, the same as German. Reviewing everything (another ~76,000 words) is roughly €2,000–5,000 per language. A middle way: review the priority set, then fix what users report.

### 1b. Hire the proofreaders (you; 1–2 weeks)

- **Spanish:** ideally a **Mexican** reviewer for the whole priority set. Then add a **Spaniard's** pass on just the paywall and onboarding, so nothing reads as wrong or rude in Spain.
  - Say up front that the Spanish is neutral Latin American on purpose: *tú* (never *vos*), and *ustedes* (never *vosotros*).
  - Ask them to start with "Choices to check", consent wording first.
- **French:** a native speaker from France.
  - Say up front that the French uses *tu*. It also uses French typography on purpose: a thin space before `? ! : ;` and inside « ».
  - Point them to the 26 choices. The biggest ones are marked in [localization-fr-progress.md](localization-fr-progress.md), including *cadre* vs *posture* for "frame".
- **For both:**
  - **Ask for:** a proofread and edit of a machine draft, not a fresh translation (about €0.03–0.06 per word).
  - **Send:** the pack, the brief, and the App Store listing draft (step 7).
  - **Hard limits:** the brief lists them, for example the 36-character paywall ticks and placeholders like `%@` that must not change.
  - **Optional but valuable:** a TestFlight build on an iPhone set to their language, with the full run-through from German step 1b.

**Done when:** you have each corrected pack back.

### 1c. Put the corrections in (Claude; about an hour per language)

Ask Claude to **"apply the Spanish (or French) review corrections"**. It's the same flow as German step 1c, with `es` or `fr` in place of `de`:
1. `import_catalog_translations.py <lang> … --reviewed`, then `check_string_catalogs.py --languages <lang> --strict-lengths`.
2. Lesson overlays, then `lesson_overlays.py check <lang>`.
3. `localization/<lang>/db/*.json`, then `db_translations_sql.py <lang>` and `question_translations_seed.py <lang> --check`.
4. Unit tests.

**Done when:** the checks pass, the strings show as reviewed, and the changes are committed.

---

## Step 2. Regional pricing (you, in App Store Connect)

**Why:** Apple's automatic prices follow exchange rates, not what people can pay. A US-level price in Mexico or Argentina is a large share of a monthly wage, so most of the Spanish-speaking market would never convert.

Where: App Store Connect → your app → Subscriptions → the group → each subscription → Subscription Prices → change prices by country or region.

| Storefronts | Suggested level | Notes |
|---|---|---|
| Mexico, Colombia, Argentina, Peru, Chile | Roughly **40–60% of the US price** | Argentina: watch for currency swings and revisit every month or two |
| Spain, France, Belgium, Switzerland, Canada | **Near today's prices** | Already in euros, Swiss francs and Canadian dollars, so check that they look round and sensible |
| India (discussed separately) | ₹499 a month, ₹2,499 a year, win-back ₹1,299 | Only if you decide to do India now |

- **Do the one-time offer too.** The 50%-off-the-first-year offer has its own price in each storefront. The app computes the "50%" it shows from the two prices in that storefront. If the numbers don't add up, it shows no percentage, so check that it still says 50% where you expect.
- **Never delete or detach `wingman_yearly_discount`** in RevenueCat; three users hold it.
- No code change is needed. All prices on screen come from the App Store.

**Done when:** every row above has the price you want, including the offer.

---

## Step 3. Privacy and legal check (you and an adviser)

**This is not legal advice.** Everything in German checklist step 2 applies to Spain and France too: the facts about where data goes, the session replay, the Meta SDK starting before any consent, the privacy policy without GDPR content, and terms under New South Wales law. Spain and France are EU countries, so the EU questions there cover them.

Add these to the same conversation:

1. **France: French-language consumer terms.** Are English-only terms and privacy pages acceptable for a paid subscription sold to French consumers? This touches the French consumer code and the Loi Toubon on French-language consumer documents. Both language sessions raised it and did not guess.
2. **Spain:** the same question for Spanish-language terms and privacy pages.
3. **Mexico: the LFPDPPP** (Mexico's federal law on personal data held by private parties).
   - Does Wingman need a privacy notice (*aviso de privacidad*) that meets it, in Spanish?
   - What does it say about sending data to the US?
4. **Latin America generally:** does selling to consumers in Colombia, Argentina, Peru and Chile need anything beyond what the App Store already shows?

**Done when:** you have written answers, and any changes they need are made or scheduled. German step 2 lists the technical options, for example the EU analytics project, masking replay text and a consent screen. They apply to all three languages at once.

---

## Step 4. Small decisions (you; 20 minutes)

- **French consent addition, lesson 25_4_5_2.** The English says to try "earlier escalation" with no condition. The French adds *quand elle te le rend* ("when she gives it back"), to match the touch rule in course 17.
  - Keep it or drop it?
  - Should English and German say the same?
- **Strong research claims in course 3,** for example "neurologically impossible", dopamine and serotonin. Every language keeps them as strong as the English. Consider softening them in all four.
- **Scenario names are shared by every language.** For example, the French spelling would be *Aurélie*, not Aurelie. Changing a name changes it for everyone.
- **Duplicate Japan quiz question** (`4533a8d2…` / `58d8c403…`). It is still duplicated, now in Spanish and French too. Deleting one is a permanent database change; tell Claude which to keep, or leave both.
- **The listing choices in step 7:**
  - the Spanish name;
  - whether Spain gets its own page;
  - French (Canada).

---

## Step 5. Sign-in emails

The same check as German step 5, done once for all languages:
1. Find out whether Supabase sends any auth emails at all. The app signs in with Apple and Google.
2. If none are sent, you're done for every language.
3. If some are, Claude drafts Spanish and French text and the template code, which picks the text by `app_language`. You paste it into the dashboard.

**Done when:** every email actually sent has Spanish and French text, or you've confirmed none are sent.

---

## Step 6. Database: check, then apply (Claude, with your go-ahead)

**Why it matters:** scenarios read their Spanish and French text from the database, so until these rows are live, scenarios show in English. Quiz questions and lessons are also bundled in the app, so they work without the database.

1. **Read-only check first.** The Supabase connector reached only Clera-App all night, so neither language session could compare its ids with production. The ids are German's, which were checked against the live database on 2026-11-11, and both languages match German id for id.
   - Point the connector at **Wingman-App** (`bnckmgnysfliiypvxxii`).
   - Ask Claude to **"run the Release C database check"**. That is a SELECT-only md5 of the 765 question ids plus the scenario rows.
2. **Apply after the proofreads,** so you write to production once:
   - Spanish: 24 files in `supabase/seed/content_translations_es/`.
   - French: 24 files in `supabase/seed/content_translations_fr/`.

   Each file is a safe, repeatable upsert, applied the way German's were. Writing to production needs your go-ahead each time. Only a build from this branch reads these rows, so applying them early shows nothing to current users.
3. **After any later wording fix:** re-run only the changed files. A database wording fix needs no app update.

**Done when:** the check matches and both sets of rows are live.

---

## Step 7. App Store pages

**Drafts ready (2026-11-15):** [spanish-app-store-listing.md](spanish-app-store-listing.md) and [french-app-store-listing.md](french-app-store-listing.md). Each has:
- the name, subtitle and keywords;
- the description, promotional text and What's New;
- the subscription names;
- the text for all five screenshots.

Send them to the proofreaders with the packs.

Decisions in the drafts:
- **Spanish:**
  - The main page is **Spanish (Mexico)**. It also shows to Spanish speakers in the US store and across Latin America.
  - Recommended name: *Wingman: Hablar con mujeres*, with the subtitle *Aprende a ligar con seguridad*.
  - **Spanish (Spain)** is a separate, optional page. The draft notes say what to change for it, for example *Wingman: Ligar con confianza* and *Ajustes*.
- **French:**
  - **French** (France) covers France, Belgium and Switzerland.
  - Add **French (Canada)** as well. Without it, French-speaking Canadians see the English page. The draft says what to change.

Screenshots and banners:
- **Figma screenshots:** use the caption tables in each draft.
- **Phone captures in Spanish or French:** fresh ones need a simulator run, which creates a guest user in production, so it needs your OK. Without them, use the English captures with translated captions.
- **Header and search banners:** Spanish and French copies of the four HTML mockups are in `marketing/app-store-assets/` (`*-es.html`, `*-fr.html`). `./render.sh` now renders them alongside the English ones (updated 2026-11-15). Run it and look at each one before you upload.

**Timing:** add the pages with the build that ships the language, not before, the same as German. Promotional text can change any time.

**Done when:** every field and image is ready and proofread.

---

## Step 8. Testing before you submit (you and Claude; 1–2 days)

Sweeps and Release builds touch production (a guest user per sweep, real analytics), so Claude runs them only when you say so.

1. **Sandbox purchase in a Mexican and a French storefront.**
   - Add sandbox testers whose countries are Mexico and France.
   - Use a Release build on a real iPhone.
   - Buy the monthly, the yearly and the one-time offer.
   - Tick [`localization-disclosure-checklist.md`](localization-disclosure-checklist.md) for each language: copy its per-language sign-off row for Spanish (Mexico) and French (France).
   - **Check:** peso and euro prices; the Spanish and French price sentences; the offer's percentage after your step 2 prices; and that premium unlocks.
2. **Simulator sweeps (Claude, with your go-ahead).**
   - `WingmanUITests/OnboardingSweepTests` has Spanish and French versions of the German sweeps, for onboarding and for content. They are compiled but have never been run.
   - Run them on the SE and the 17 Pro.
   - Spanish and French are often longer than English, so look for clipped text on the SE.
3. **A real iPhone in each language:**
   - the iOS permission pop-ups;
   - notifications;
   - the first lesson of a few courses (6, 12, 17, 22);
   - one scenario. This needs step 6 done, or it shows in English.
4. **Language picker:** in Settings → Language, switch between English, Deutsch, Español and Français. Check that the app follows each choice.
5. **Fallback and analytics parity** (Claude) ✅ done 2026-11-15. `ReleaseLanguageChecksTests` now runs in full for Spanish and French: missing text falls back to English, and analytics values match English.
6. **If the review changed a lot of wording,** re-run the sweeps.

**Done when:** all of the above pass, or the problems are fixed.

---

## Step 9. Version, build, submit (you, with Claude)

1. **Choose the order.**
   - **German first:** ship German (Release A + B), soak 7 days, then ship Spanish and French. If something breaks, you know which release did it.
   - **All together:** faster, but a problem is harder to trace.

   Either way, this branch already contains A and B. `Shat` has nothing that this branch lacks.
2. **Check what's live before bumping.** The repo says **1.15 (38)**, the number German was planned to ship as.
   - Check the App Store version (the iTunes lookup), the newest `$app_build` in PostHog and your Xcode archives.
   - Then bump. Xcode and App Store Connect use the same number.
3. **Bundled quiz questions:** Claude runs `python3 scripts/question_translations_seed.py <lang> --check` for de, es and fr.
4. **Merge and archive.** Merge `localization-release-c` into `Shat` (Claude can open the pull request), then Xcode → Product → Archive → Distribute → App Store Connect.
5. **In App Store Connect,** on the new version:
   - attach the build;
   - add the pages from step 7;
   - write "What's New" in each language;
   - submit.

**Done when:** Apple approves and the version is live.

---

## Step 10. After launch: what to watch (4–6 weeks)

- **Get a baseline first.** Before launch, ask Claude to pull the 90 days of onboardings, paywall views and first payments for:
  - Mexico, Colombia, Argentina, Peru, Chile, Spain, and Spanish-speaking US users;
  - France, Belgium, Switzerland and Canada.

  These markets are thin today, so judge them on trends, not single weeks.
- **In PostHog,** split by `app_language` and by country (and `device_language`). Watch:
  - onboarding completion;
  - paywall conversion;
  - first payment;
  - lesson completion against English users in the same storefronts.
- **Latin American prices:** compare paywall conversion before and after step 2. A cheaper price should convert clearly better, or it isn't paying for itself.
- **App Store Connect → Analytics:** impressions, product page views and downloads for each country, before and after the new pages.
- **RevenueCat:** revenue by country, and Argentina's in dollars.
- **Reviews in each store:** the best source of translation complaints. Fix them with the step 1c flow.

**Done when:** you have 4–6 weeks of numbers and can decide whether the next language is worth it.
