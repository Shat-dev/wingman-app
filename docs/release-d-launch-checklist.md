# Launching Wingman in Japanese: step by step

Written 2026-11-16 for Arthur. This follows the Spanish and French checklist ([release-c-launch-checklist.md](release-c-launch-checklist.md)); where a step works the same way, this one points there instead of repeating it.

**Where things stand.**
- **Japanese (`ja`) is fully drafted:**
  - the whole interface (586 strings);
  - all 25 courses (1,531 lesson items);
  - 765 quiz questions;
  - 15 scenarios.
- **Merged into `Shat` on 2026-11-16** (merge commit `75d7b4d`). Not pushed. No version bump: the project still says 1.16 (40).
- **Checks:** every check passes for German, Spanish, French and Japanese on the merge. Unit tests on the merge commit, on "Wingman L10n 17 Pro" (Debug build, unit tests only): 349 run, 344 passed, 0 failed, 5 skipped. The five skips are the pseudo-language probes, which skip themselves by design; nothing is skipped for Japanese.
- **The German fixes from the native speaker's review** (the commit already on `Shat`) came through the merge unchanged. German, Spanish and French strings are identical to what `Shat` had.
- **Not seen on screen yet:** no simulator sweep has run in Japanese, and no Release build. Each sweep creates a guest user in production, so it waits for your OK.
- **Database rows: not applied.** The 15 scenarios read their text from the database, so they show in English until step 5 is done. The interface, lessons and quiz questions ship inside the app and are already Japanese in a build.
- **Draft status:** all of it is a machine draft (written by Claude). **No Japanese speaker has read any of it**, and you have no Japanese reader in the team, so step 1 matters more here than it did for the other languages.
- **The advice was translated, not adapted.** 63 places where it may land differently in Japan are listed for you (step 2).

Log, with the summary at the top: [localization-ja-progress.md](localization-ja-progress.md). Brief for the reviewer: [localization-ja-brief.md](localization-ja-brief.md). Listing draft: [japanese-app-store-listing.md](japanese-app-store-listing.md).

Who does each step:
- **You** (Arthur)
- **Proofreader**: a native Japanese speaker you hire
- **Adviser**: a lawyer or privacy adviser
- **Claude**: a future Claude Code session; just ask for the step by name

No costs are given here. The rates in the Release C checklist were for European languages and I have no figure for Japanese, so get quotes.

---

## Do these first

Start these three this week. They take the longest, and they don't depend on each other.

1. **Get the proofread going** (step 1). The longest lead time, and it blocks everything on screen.
2. **Ask the adviser the Japan questions** (step 4). Add them to the conversation you already owe the other languages.
3. **Read the cultural flags** (step 2). Your decisions may change lesson text, and it is cheaper to change it before the proofreader reads it than after.

---

## The order at a glance

| Step | What | Who | Blocks |
|---|---|---|---|
| 1 | Native proofread, priority set first | Proofreader, then Claude | Testing, submission |
| 2 | Cultural flags: a decision on each | You | The proofread of those lessons |
| 3 | Pricing in yen, the one-time offer too | You (App Store Connect) | Launch in Japan |
| 4 | Privacy and legal questions | You and adviser | Marketing in Japan |
| 5 | Database: id check, then apply the Japanese rows | Claude, with your go-ahead | Scenarios in Japanese, testing, submission |
| 6 | Japanese sweeps on both simulators | Claude, with your say-so | Submission |
| 7 | Sandbox purchase in the Japanese storefront | You | Submission |
| 8 | Keywords, listing pages, screenshots, subscription names | You, Claude drafted | Submission |
| 9 | Version check, build, submit | You, with Claude | Launch |
| 10 | After launch: watch | You, Claude | Nothing |

Steps 1, 2, 3 and 4 run in parallel. Steps 5 and 8 fit in while the proofreader works. Step 6 needs step 5. Step 7 needs step 3. Step 9 needs everything before it.

---

## Step 1. Native proofread (priority set first)

**Why:** Claude wrote all of it and nobody has read it. For the other languages a proofread was polish; here it is the only check there has been. Grammar is probably mostly right. What can't be judged from here is tone (does the polite coach voice sound like a trusted older friend or like a manual), the wording around money and the law, and whether the terms chosen for dating talk sound respectable or sleazy.

### 1a. The review pack (Claude) ✅ done 2026-11-16

[`localization/ja/review/wingman-japanese-review-pack.xlsx`](../localization/ja/review/wingman-japanese-review-pack.xlsx), seven sheets:
- **Read me**
- **Choices to check:** 28 translation decisions. The first row gives the reading order.
- **Interface:** 466 rows; the 216 "Must read" rows are highlighted and come first: paywall and one-time offer, then sign-in, onboarding, notifications.
- **Lesson 17_3** (respect and consent), then **Lesson 1_1** and **Lesson 6_1**
- **Daily quotes**

Rebuild the pack after any change with `python3 scripts/review_pack.py ja`. The choices and house rules live in `localization/ja/review/choices.json`.

**Priority set,** about 4,900 English words: the whole interface plus the three lessons. If the budget covers less than that, the order is the "Must read" interface rows, then lesson 17_3, then the 28 choices. Everything else is another 76,000 English words or so (the other lessons, all quizzes, all scenarios), and none of the quizzes or scenarios are in the workbook; a reviewer who takes those on works from `localization/ja/db/*.json` and the lesson overlay files.

### 1b. Hire the proofreader (you)

- **Who:** a native Japanese speaker who lives in Japan or left recently, ideally a man of 25 to 45 or someone who writes for that reader. Dating vocabulary dates quickly.
- **Say up front:**
  - It is a proofread and edit of a machine draft, not a fresh translation.
  - The voice is polite です・ます on purpose, with no 君 or お前 and almost no あなた.
  - The app avoids ナンパ and the pickup tone on purpose. If a word sounds like a seduction manual, that is a bug.
  - The advice itself must not be rewritten. Advice that does not fit Japan gets a comment, and you decide (step 2).
- **Ask them to answer the 28 choices first.** The ones that could change many screens at once are 駆け引き for "flirting", こちら for the man's side of a conversation, and whether lists in dictionary form are acceptable inside polite text.
- **Send:** the pack, the brief, and the listing draft (step 8).
- **Hard limits:** paywall ticks may be at most 18 Japanese characters, and placeholders like `%@` must not change. The pack's Read me lists them.
- **Optional but valuable:** a TestFlight build on an iPhone set to Japanese. A spreadsheet cannot show where a line breaks, and Japanese lines can break in the middle of a word.

**Done when:** you have the corrected pack back.

### 1c. Put the corrections in (Claude; about an hour)

Ask Claude to **"apply the Japanese review corrections"**. It is the same flow as German step 1c, with `ja`:
1. `import_catalog_translations.py ja … --reviewed`, then `check_string_catalogs.py --languages ja --strict-lengths`.
2. Lesson overlays, then `lesson_overlays.py check ja`.
3. `localization/ja/db/*.json`, then `db_translations_sql.py ja` and `question_translations_seed.py ja --check`.
4. Unit tests.

Until this step, every Japanese string stays marked "needs review". That is deliberate.

**Done when:** the checks pass, the reviewed strings show as reviewed, and the changes are committed.

---

## Step 2. Cultural flags: your decision on each

**Why:** the decision for this release was to translate the advice faithfully and flag what may not fit, not to rewrite it. So the Japanese app currently tells a man in Tokyo exactly what the English app tells a man in Sydney.

The list is in [localization-ja-progress.md](localization-ja-progress.md) under "Cultural flags for Arthur": 63 numbered points, each with the lesson, scenario or question it comes from and one sentence on why it may land differently.

They fall into a few groups, so you can decide by group:
- **Where he approaches:** on trains, in a library, at the gym, in the street, a group of women on a night out.
- **How direct he is:** direct openers that state attraction, asking for her contact to test a polite answer, "assume she is interested".
- **Eye contact and looking away:** holding eye contact with a stranger; treating a quick look-away as no signal.
- **Touch and closeness:** touch within the first minutes, standing closer, guiding her by the arm.
- **Teasing:** teasing a woman he has just met, cheeky pushback, guessing ages, not being impressed.
- **Research claims and statistics:** numbers and "psychologists call this…" lines kept as strong as the English.
- **Grooming details:** facial hair, cologne.

For each, the choices are:
1. **Keep it as written.**
2. **Soften or adapt it for Japan** (Claude can draft the change; the proofreader should read it).
3. **Change it in every language**, where the flag is really about the English.

One flag is a question for whoever advises you on Japan and is not something to decide by taste: approaching strangers in public and local nuisance-prevention rules. It is stated in the list as an open question.

**Done when:** each flag has a decision, and any changes are drafted before the proofreader reaches those lessons.

---

## Step 3. Pricing in yen (you, in App Store Connect)

Where: App Store Connect → your app → Subscriptions → the group → each subscription → Subscription Prices → Japan.

- **Check all three products:** monthly, yearly, and the one-time offer product. No price is suggested here; that is your call.
- **Yen has no decimals.** Check that each price is a round figure a Japanese buyer would expect to see.
- **Your notes say the yearly price and the offer were cut by 20% in every storefront on 2026-11-16.** That will have changed what Japan shows; look at the current yen figures before deciding anything.
- **The one-time offer shows "50%" only if the numbers add up.** The app computes the percentage from the two prices in that storefront; if they don't give a clean figure, it shows no percentage. Check that Japan still says 50% after your changes.
- **Never delete or detach `wingman_yearly_discount`** in RevenueCat; users hold it.
- No code change is needed. All prices on screen come from the App Store.

**Done when:** Japan has the price you want on all three products, and the offer shows the percentage you expect.

---

## Step 4. Privacy and legal questions (you and an adviser)

**This is not legal advice, and nothing here is answered.** These are questions to put to an adviser.

**Still open from the other languages** (German checklist step 2 and Release C step 3; they apply to Japan too):
- where user data goes, the session replay, and analytics starting before any consent;
- a privacy policy without the content the EU rules ask for;
- terms under New South Wales law;
- English-only terms and privacy pages for a paid subscription sold to consumers in another language.

**New for Japan:**
1. **The Act on Specified Commercial Transactions (特定商取引法).** Japanese consumers expect a seller disclosure page for a paid service. Does Wingman need one? If so, what must it say, in which language, and where must it be linked from?
2. **The Act on the Protection of Personal Information (個人情報保護法).** Does the current privacy policy cover what it requires, including sending personal data out of Japan? Does it need a Japanese version?
3. **English-only terms and privacy pages.** Are they acceptable for a subscription sold to Japanese consumers, or is a Japanese version, or a note that the pages are in English, needed?
4. **Subscription wording.** Does the paywall's billing sentence meet what Japanese consumer rules expect to be shown before a purchase? The Japanese text is in the review pack, Interface sheet, area "Paywall & one-time offer".
5. **Approaching strangers in public.** Do local nuisance-prevention rules make any of the app's advice a risk for the user or for you as the publisher? This is the cultural flag that was written as a question.

**Done when:** you have written answers, and any changes they need are made or scheduled.

---

## Step 5. Database: check, then apply (Claude, with your go-ahead)

**Why it matters:** scenarios read their text from the database. Until the Japanese rows are live, all 15 scenarios show in English in a Japanese app, and the What's New line in the listing draft ("all lessons, quizzes and scenarios") is not true.

1. **Read-only id check first. Not done yet.** It was skipped during the translation because the Supabase connector reached only Clera-App, not Wingman-App.
   - Point the connector at Wingman-App, or use the Supabase CLI from a scratch folder as Release C did.
   - SELECT only: confirm that every id in the Japanese files exists in production, and that production has no Japanese rows yet.
   - What is already known without the database: the Japanese files use the same ids as the French ones, file for file, and every generated SQL file has the same number of upserts as its French twin (765 questions, 15 scenarios, 796 screens, 276 options).
   - Also check the date of the last English edit in production. The Japanese was translated from the English in the repo's German files; if the English changed in production after 2026-11-15, those rows need a second look.
2. **Then apply, with your go-ahead.** 24 files in `supabase/seed/content_translations_ja/`. Each is a safe, repeatable upsert, applied the way the other languages were. **None has ever been run.** Only a build that offers Japanese reads these rows, so applying them early shows nothing to current users.
3. **The duplicate quiz question** (`4533a8d2…` / `58d8c403…`) is still duplicated and carries the same Japanese in both rows. Leave both unless you decide otherwise; deleting one is a permanent change.
4. **After the proofread:** re-run only the files whose wording changed. A database wording fix needs no app update.

**Done when:** the check matches and the Japanese rows are live.

---

## Step 6. Japanese sweeps on both simulators (Claude, when you say so)

**Why:** nothing Japanese has been seen on a screen except one onboarding screen rendered in a unit test. Each sweep creates a guest user in production, so Claude runs them only when you say so.

- **The tests exist and have never been run:** `testOnboardingInJapanese` and `testOnboardingAndContentInJapanese` in `WingmanUITests/OnboardingSweepTests.swift`.
- **The simulators:** "Wingman L10n 17 Pro" and "Wingman L10n SE". Both are safe to reset.
- **Run step 5 first,** or the scenario in the content sweep plays in English.

**What to look at, in this order:**
1. **The font.** The app's fonts have no Japanese glyphs, so iOS draws Japanese in its own font while digits, %, "Wingman" and "XP" stay in the app's font. Check that headings and body text don't look mismatched in weight or size, especially where a number sits inside a Japanese sentence.
2. **Line breaks.** Japanese has no spaces, so a line can break in the middle of a word. One onboarding headline was already shortened for this. Look at every headline, button and card title.
3. **The small phone.** On the SE: the growth screen's third bullet, the paywall headline against the close ✕, and long quiz answers under "Check answer". These were the trouble spots in the other languages.
4. **The three sentences built from pieces:** the Home greeting with the name on the next line, "3倍" followed by its explanation, and "50%" over 「最初の1年間オフ」. Say whether you want the code changed so Japanese can use its own order.
5. **Scenario cards.** The card shows three lines of summary; check that the Japanese summaries fit.
6. **Anything still in English** apart from the iOS permission pop-up, which follows the phone's language.

Expected, not a bug: "can't load prices" on the paywall in a Debug build.

**Done when:** both simulators have been swept, every screen read, and any layout problem is fixed and re-checked.

---

## Step 7. Sandbox purchase in the Japanese storefront (you)

1. Add a sandbox tester whose country is Japan.
2. Use a Release build on a real iPhone set to Japanese. A Release build sends real analytics, so this is your call to start.
3. Buy the monthly, the yearly and the one-time offer.
4. Tick [`localization-disclosure-checklist.md`](localization-disclosure-checklist.md): copy its per-language sign-off row for Japanese (Japan).

**Check:** the yen prices from step 3; the Japanese billing sentences, with the amount and the period in the right places; the offer's percentage; and that premium unlocks.

Also on the real iPhone: the iOS permission pop-ups, a notification, the first lesson of a few courses (6, 12, 17, 22), one scenario, and Settings → Language switching between English, Deutsch, Español, Français and 日本語.

**Done when:** all three purchases work and the disclosure checklist is ticked for Japanese.

---

## Step 8. Keywords, listing pages, screenshots, subscription names

**Draft ready (2026-11-16):** [japanese-app-store-listing.md](japanese-app-store-listing.md). It has the name, subtitle, keywords, description, promotional text, What's New, subscription names, the text for all five screenshots, and two retention messages. Send it to the proofreader with the pack.

Before anything is entered:
1. **Keyword popularity for Japan.** The keyword field is a first guess and has not been checked. Run the per-country popularity lookup you used for the other markets, then fill the 13 free characters from what it finds.
2. **A store search in Japan** for each name candidate and for "Wingman". The French draft did this for France; nobody has done it for Japan, so it is not known what the name would compete with.
3. **How App Store Connect counts Japanese characters.** The draft counts one per character. If the field counts two, the keyword list is too long. The live counter in App Store Connect is the authority.
4. **Choose the name.** The draft recommends 「Wingman: 恋愛の自信と会話力」 and gives 「Wingman: 女性に声をかける自信」 as the plainer alternative.
5. **The retention message.** Say which English message is live on the cancel sheet. The repo does not record it, so the draft has Japanese for both likely ones. It needs its own App Review approval, and Apple limits how many submissions can wait at once.
6. **Subscription names:** 月額プラン and 年額プラン, matching the paywall. Keep the group name "Wingman Premium". Give `wingman_yearly_discount` a Japanese name too and change nothing else about it.

Screenshots and banners:
- **Figma screenshots:** use the caption tables in the draft. Two frames need their two text layers swapped, because Japanese puts the object first. The hand-lettered line has to be set in type or dropped.
- **Header and search banners:** four `-ja` files are in `marketing/app-store-assets/`. **They have never been rendered.** Choose a Japanese font, add `-ja` to the loop in `render.sh`, run it, and check every line break by eye before uploading.
- **Phone captures in Japanese** need a simulator run (step 6). Without them, the page launches with Japanese captions over English phone screens.

**Timing:** add the Japanese page with the build that ships Japanese, not before. A Japanese page for an app that is not yet in Japanese draws bad reviews.

**Done when:** every field and image is ready and proofread.

---

## Step 9. Version, build, submit (you, with Claude)

1. **Check what is live before bumping.** The project says **1.16 (40)**. Your notes say 1.16 (40) was submitted with Spanish and French on 2026-11-16 and was waiting for review, so that number is taken.
   - Check the App Store version (the iTunes lookup), the newest `$app_build` in PostHog and your Xcode archives.
   - Then bump. Xcode and App Store Connect use the same number. **Nothing in this merge bumped it.**
2. **Don't archive from `Shat` for another release until you have decided about Japanese.** `Shat` now offers 日本語 in Settings. Any build archived from it ships the unreviewed Japanese draft to anyone who picks that language or whose phone is set to Japanese. If another release has to go out first, either accept that or ask Claude to hide Japanese behind a switch.
3. **Bundled quiz questions:** Claude runs `python3 scripts/question_translations_seed.py <lang> --check` for de, es, fr and ja.
4. **Archive** from `Shat`: Xcode → Product → Archive → Distribute → App Store Connect, or the command-line route in your notes.
5. **In App Store Connect,** on the new version: attach the build, add the Japanese page from step 8, write "What's New" in each language, submit.

**Done when:** Apple approves and the version is live.

---

## Step 10. After launch: what to watch (4–6 weeks)

- **Get a baseline first.** Before launch, ask Claude to pull the last 90 days of onboardings, paywall views and first payments for Japan. It is a thin market today, so judge it on trends, not single weeks.
- **In PostHog,** split by `app_language` and by country (and `device_language`). Watch, for `ja` against English users in the Japanese storefront:
  - onboarding completion, step by step. A step where Japanese users drop and others don't points at wording or layout on that screen;
  - paywall conversion and first payment;
  - lesson completion and scenario completion.
- **App Store Connect → Analytics:** impressions, product page views and downloads for Japan, before and after the Japanese page.
- **RevenueCat:** revenue for Japan, in yen and in dollars.
- **Reviews in the Japanese store.** With no Japanese reader in the team, these are the first native feedback you get. Ask Claude to translate them, and fix wording with the step 1c flow.
- **Support messages in Japanese:** decide beforehand who answers them and in which language.

**Done when:** you have 4–6 weeks of numbers and can decide whether Japan repays more work.
