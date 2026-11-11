# Launching Wingman in German: step by step

Written 2026-11-11 for Arthur. Branch `localization-release-b`. Nothing here is pushed or submitted yet.

**Where things stand.** The German app is built and works end to end. That covers the whole interface, all 25 courses, 765 quiz questions and 15 scenarios. It was checked on screen on the iPhone SE and iPhone 17 Pro simulators. The German database rows are already live on production. Only a build from this branch reads them, so nobody sees them today. **All of the German is a machine draft (written by Claude) and has not been read by a German speaker.** Release B also contains all of Release A, which has not shipped either.

Who does each step:
- **You** (Arthur)
- **Proofreader**: a German native speaker you hire
- **Adviser**: a lawyer or privacy adviser
- **Claude**: a future Claude Code session; just ask for the step by name

Costs are rough market rates, so get real quotes.

---

## Do these first

Start these three this week. They take the longest, and they don't depend on each other.

1. **Get the German proofread** (step 1). The longest lead time, and it blocks the launch.
2. **Book a privacy and legal check for Germany** (step 2). Your data goes to the US, and your privacy policy has nothing for EU users. That's true today, whatever the app's language.
3. **Do a sandbox purchase on each product** (step 3). Release A can't ship without it, and Release B contains Release A.

Everything else can wait until those three are moving.

---

## The order at a glance

| Step | What | Who | Time / cost | Blocks |
|---|---|---|---|---|
| 1 | German proofread | Claude, then proofreader, then Claude | 1–2 weeks; priority set ≈ €150–300 | Testing, submission |
| 2 | Privacy and legal check | You and adviser | Quote; 1–3 weeks | Marketing to Germany |
| 3 | Release A open items | You | 1–2 hours, then a 7-day soak | Submission |
| 4 | Small decisions | You | 15 minutes | Nothing big |
| 5 | Auth emails (G10) | You, or Claude to draft | 15 minutes to 1 hour | Submission |
| 6 | German App Store listing (G9) | Claude drafts, you paste | 1 day | Submission |
| 7 | Testing before submission | You, Claude | 1 day | Submission |
| 8 | Build, version, submit | You, with Claude | 1–2 hours plus Apple review | Launch |
| 9 | After launch: watch | You, Claude | 4–6 weeks of watching | Nothing |

Steps 1, 2 and 3 run in parallel. Steps 4 to 6 fit in while the proofreader works. Step 7 needs step 1 finished, and step 8 needs everything before it.

---

## Step 1. German proofread (native speaker)

**Why:** Claude wrote all the German. The grammar is mostly right. What a writer can't catch in their own work is tone: what sounds natural to a German man and what sounds stiff, translated or cringe in a dating app. The same goes for wording around money and the law. The brief for the reviewer is [`localization-de-brief.md`](localization-de-brief.md).

### 1a. Build a review pack (Claude) ✅ done 2026-11-12

**The pack:** [`localization/de/review/wingman-german-review-pack.xlsx`](../localization/de/review/wingman-german-review-pack.xlsx). Rebuild it after any German change with `python3 scripts/german_review_pack.py`.

It's one Excel workbook with six sheets:
- **Read me:** what the app is, the house rules, and how to fill the sheets in.
- **Choices to check:** 12 decisions for the proofreader to confirm or change.
- **Interface:** 456 strings, sorted by screen. The 215 "Must read" rows (paywall, sign-in, onboarding, notifications) are highlighted in pink.
- **Lesson 1_1** and **Lesson 6_1:** the two sample lessons, page by page.
- **Daily quotes:** 120 quotes, lower priority.

The proofreader writes only in the yellow columns: Your version, Status and Comment.

Priority set, about 4,700 words:

| Part | Size | Where it lives |
|---|---|---|
| Whole interface: paywall, one-time offer, sign-in legal line, onboarding, notifications, buttons, course titles | 576 strings, about 3,800 English words | [`localization/de/catalogs.de.json`](../localization/de/catalogs.de.json) (English → German) |
| Two sample lessons: 1_1 "Du bist nicht deine Gedanken" and 6_1 (the first of another course) | about 900 words | `Wingman/Courses/Lesson Overlays/lesson_overlay_course_1_de.json`, `…course_6_de.json` |

The brief's section "Look at these first" lists which interface lines carry money or legal weight. The proofreader should read every one of them.

Later, optional:

| Part | Size | Where it lives |
|---|---|---|
| All lessons | about 34,500 words | `Wingman/Courses/Lesson Overlays/*_de.json`; `python3 scripts/lesson_overlays.py export de <folder>` makes English copies to compare |
| Quiz questions and scenarios | about 42,300 words | `localization/de/db/*.json`, already English and German side by side |

Reviewing everything costs roughly €2,000–5,000. A middle way: review the priority set, then fix whatever German users report.

### 1b. Hire the proofreader (you; 1–2 weeks)

- **Where:** a freelance site such as Fiverr, Upwork or ProZ. Search for "German proofreading, native, app / marketing". Prefer a man in your target age range (25–55): the copy speaks to him.
- **Ask for:** a proofread and edit of a machine draft, not a fresh translation. That's cheaper, about €0.03–0.06 per word.
- **Send:** the review pack, plus [`localization-de-brief.md`](localization-de-brief.md). The brief covers tone ("calm older brother"), the fixed word choices, the 36-character limit on paywall ticks, and placeholders like `%@` that must not change.
- **Ask them to check these choices** (from [`localization-de-progress.md`](localization-de-progress.md), "For the reviewer"):
  - "Scheiß drauf" for "screw it" (course 2). The coarsest phrase in the app; soften to "Egal"?
  - "flirty" and "flirtend" are both used; pick one.
  - "Social Proof" left in English, with *sozialer Beweis* in brackets.
  - The course titles that were guesses: *Die Annäherung*, *Das Pflichtprogramm*, *Der Abschluss*, *Bereit zum Ansprechen*.
  - *der Held deines Lebens* for Nora Ephron's "heroine".
  - "Guten Tag," for the afternoon greeting.
- **Tell them what's deliberate:** the German quotation marks „…“ (opening mark low, closing mark high) are correct German, not a bug. *Wingman*, *XP* and the five category names stay in English.
- **Optional but valuable:** give them a TestFlight build and an iPhone set to German, and ask for the full run-through from the plan's exit gate. That's onboarding → paywall → lesson → quiz → scenario → logging an approach → settings → restore purchases → delete account. A single session catches what a spreadsheet can't.

**Done when:** you have the corrected pack back.

### 1c. Put the corrections in (Claude; about an hour)

Ask Claude to **"apply the German review corrections"** and hand over the corrected files. Claude will:

1. **Interface:** update `localization/de/catalogs.de.json`, then run
   `python3 scripts/import_catalog_translations.py de localization/de/catalogs.de.json --reviewed`. That marks the reviewed strings "translated" instead of "needs review". Then run `python3 scripts/check_string_catalogs.py --languages de --strict-lengths`.
2. **Lessons:** edit the files in `Wingman/Courses/Lesson Overlays/`, then run `python3 scripts/lesson_overlays.py check de` until it passes.
3. **Quiz and scenarios:** edit `localization/de/db/*.json`, then run `python3 scripts/db_translations_sql.py de` to regenerate `supabase/seed/content_translations_de/*.sql`. Re-run only the changed files on production. Each file is a safe, repeatable upsert. Writing to production needs your go-ahead each time.
4. Run the unit tests. If the wording changed a lot, re-run the German screenshot sweep (step 7).

**Done when:** the checks pass, the strings show as reviewed, and the changes are committed on this branch.

---

## Step 2. Privacy and legal check (you and an adviser)

**This is not legal advice.** These are the facts about how Wingman handles data today, checked in the code and the Supabase project on 2026-11-11. Take them to someone qualified in EU and German privacy law.

### The facts

- **Data goes to the US.**
  - The database and accounts (Supabase) are in `us-east-1`, Virginia.
  - Analytics and session replay (PostHog) go to `us.i.posthog.com` (`Wingman/Resources/Constants.swift`).
  - Purchases (RevenueCat) and ads attribution (Meta SDK) are US companies.
- **Privacy policy** ([getwingman.app/privacy](https://www.getwingman.app/privacy), last updated 2026-04-19): no mention of GDPR, legal bases, named processors, US transfers or how long data is kept. It doesn't mention session replay.
- **Session replay** is on for every user. It records screenshots of the app, and typed text is not masked (`maskAllTextInputs = false` in `WingmanApp.swift`). The sign-in screen and the settings sheet are masked.
- **Meta SDK** starts and logs events at app launch, before any consent question. There is no consent or opt-out screen anywhere in the app.
- **Terms of use** are governed by New South Wales law, with exclusive jurisdiction there.
- The privacy and terms pages are in English only (plan decision D6).
- The App Store page already shows your trader details for the EU (done under the Digital Services Act).

### Questions to ask the adviser

1. What does my privacy policy need for EU and German users: legal bases, the list of processors, US transfers, how long data is kept, users' rights, a contact?
2. Are my US providers covered for EU data (for example under the EU–US Data Privacy Framework)? Do I need to sign data processing agreements with Supabase, PostHog, RevenueCat and Meta?
3. Does session replay need consent first? Do I need to mask on-screen text, or switch replay off for EU users?
4. Does the Meta SDK, and analytics generally, need an opt-in before it runs? Germany has its own rules for this (the TDDDG).
5. Do I need an EU representative, given I have no business established in the EU?
6. Do I need an Impressum (the German legal notice) in the app or on the website?
7. Do the privacy policy and terms need German versions?
8. Can German consumers be held to NSW law and courts?
9. Is my App Store privacy label accurate?

### Technical options, for once you have answers

Claude can do any of these in a future session; none is decided.

- **Move analytics to the EU:** create a PostHog project on the EU cloud and change `POSTHOG_HOST`. History stays in the old project. About an hour of code, plus re-creating the dashboards.
- **Mask session replay text,** or turn replay off for EU users. A small code change.
- **A consent screen** before PostHog and the Meta SDK start: set `FacebookAutoLogAppEventsEnabled` to false in `Info.plist` and start each one only after the user says yes. This affects your ad attribution and analytics numbers, so weigh it.
- **Move the database to the EU:** this means a new Supabase project and a full migration. Large and risky; only if the adviser says it's needed.

**Done when:** you have written answers, and any changes they need are either made or scheduled.

---

## Step 3. Release A's open items (you)

Release B contains all of Release A (the English-only groundwork), which has not shipped. From [`localization-release-a-exit-gate.md`](localization-release-a-exit-gate.md):

1. **A sandbox purchase on each product.** This is gate condition 4.
   - Make a Release build on a real iPhone; Debug builds can't load prices.
   - Sign in with a sandbox Apple ID: App Store Connect → Users and Access → Sandbox. On the iPhone: Settings → App Store → Sandbox Account.
   - Buy the monthly, the yearly and the one-time offer.
   - **Check:** `paywall_purchase_succeeded` arrives in PostHog, Meta shows Subscribe, and RevenueCat grants the entitlement.
   - **Do the German sandbox purchase at the same time:** add a sandbox tester whose country is Germany, so you see euro prices and the German paywall (also step 7).
   - Never delete or detach `wingman_yearly_discount` in RevenueCat; three users hold it.
2. **The trial badge:** nothing to check. You removed the free trial, so the badge shows nothing.
3. **The 7-day soak after shipping:** watch crashes, onboarding and paywall numbers for a week before the next big change.

**A decision for you: ship Release A first, or both together?**
- **The plan's order:** ship Release A on its own (English only, from `localization-release-a`), soak for 7 days, then ship Release B. If something breaks, you know which release did it.
- **Together:** one submission with about 120 changes. Faster, but a problem is harder to trace.

**Done when:** each product has been bought in sandbox with the events seen, and you've chosen the shipping order.

---

## Step 4. Small decisions (you; 15 minutes)

- **Duplicate quiz question.** `4533a8d2…` and `58d8c403…` are the same Japan-trip question, word for word. Deleting one is a permanent database change, and answer history may point at it. Tell Claude which to keep, or to leave both.
- **English lesson fixes** (lessons 11_5, 12_3, 13_1, 15_4, 20_4, 21_1, 21_2, 25_3, plus typos) live only on this branch. English users get them when Release B ships. If you want them sooner, Claude can copy them into the next English release.
- **The reviewer's open choices from step 1b,** if the proofreader leaves them to you.

---

## Step 5. German sign-in emails (G10)

**First, check whether any emails are sent.** The app signs users in with Apple and Google. The email-and-password code in `Wingman/Auth/AuthService.swift` isn't used by any screen, so Supabase may send few or no emails.

1. **Supabase dashboard** → project Wingman-App → Authentication → Emails (templates) and Logs. Note which templates are switched on and whether any were sent recently.
2. **If none are used:** done. Note it in the progress log.
3. **If some are used** (for example account deletion confirmation): Supabase has one template per email type, not one per language. A template can show German or English by checking the user's profile field `app_language` (written by `Wingman/Auth/ProfileLanguage.swift`). Ask Claude to draft the German text and the template code, then paste it into the dashboard yourself.

**Done when:** every email that is actually sent has German text, or you've confirmed none are sent.

---

## Step 6. German App Store page (G9)

**Why it matters:** the App Store indexes keywords separately for each country. With an English-only page, German searches don't find Wingman. That's the main point of the X article you shared: the store page usually brings more downloads than translating the app itself. Prices need no change: 17,99 € a month and 79,99 € a year are already set for Germany, and Germans buy at that level.

**What to prepare** (Claude drafts all of it; you paste it in):

| Field | Where in App Store Connect | Notes |
|---|---|---|
| Name (30 characters), subtitle (30) | App → App Information → localization menu (top right) → add **German** | The name can stay "Wingman" plus a German subtitle |
| Description, keywords (100 characters), promotional text | App → the new version → localization menu → German | Keywords are what Germans actually type ("Frauen ansprechen", "Selbstbewusstsein", "Flirten lernen"…); Claude should research these |
| Screenshots (the first three matter most) | Same page, German section | Use the German app on screen, with German captions |
| Subscription names and descriptions | App → Subscriptions → the group → each of the 3 subscriptions → Localization → German | Today they read "Monthly", "Yearly" and "Wingman Premium Yearly Discount". Use *Monatsabo* and *Jahresabo*, matching the in-app wording |

**Screenshots:** `marketing/app-store-assets/` builds images from HTML (`./render.sh` → `png/`), using app captures in `src/`. Claude can make German copies of the HTML with German captions and fresh German app captures from a simulator. The sweep pictures in `docs/localization-baseline/` are shrunk, so they're too small to use.

**Timing: ship the page with the German app, not before.** Name, subtitle, description, keywords and screenshots only go live with a version submission. A German page for an English app tends to draw one-star reviews ("App ist nur auf Englisch"). Prepare everything now and add it to the Release B submission in step 8. Promotional text can be changed at any time.

**Done when:** every field and screenshot is ready in a document and a folder, and checked by the proofreader with the step 1 pack if possible.

---

## Step 7. Testing before you submit (you and Claude; about a day)

Each automated screenshot sweep creates a real guest user in production, and a Release build sends real analytics. Claude runs one only when you say so.

1. **Release build in German with real prices.** Use a sandbox tester in the German storefront (step 3). Check:
   - the paywall shows euro prices and the German price sentences;
   - the one-time offer;
   - a purchase goes through and premium unlocks.

   The disclosure checklist [`localization-disclosure-checklist.md`](localization-disclosure-checklist.md) is the list to tick (plan item G8).
2. **A real iPhone set to German:** Settings → General → Language & Region → iPhone Language → Deutsch. Or set only Wingman: Settings → Wingman → Language. Check that the iOS permission pop-ups, such as notifications, appear in German. The simulator showed them in English only because its own language was English.
3. **German notifications:** allow them, then trigger or wait for a reminder. Non-subscribers get one a day after onboarding; there's also the daily lesson reminder.
4. **More lessons on screen:** so far only lesson 1_1 was checked on screen. Open the first lesson of a few other courses (6, 12, 17, 22) and one long lesson on the smallest iPhone you can get.
5. **Fallback check** (Claude): hide a few German strings and rows, and confirm English appears instead of a blank. The plan's exit gate asks for this.
6. **Analytics parity in German** (Claude): analytics event names and values must be identical to English, so your dashboards keep working.
7. **If the review changed a lot of wording,** re-run the German sweep on the SE and the 17 Pro (Claude, with your go-ahead).

**Done when:** all of the above pass, or the problems are fixed.

---

## Step 8. Build, version, submit (you, with Claude)

1. **Check what's live first.** The branch says 1.14 (37), but the version in the repo is often already shipped. Check the App Store version (the iTunes lookup), the newest `$app_build` in PostHog and your Xcode archives. Then bump: Xcode and App Store Connect use the same number.
2. **Which branch.** If you chose "Release A first" in step 3, ship `localization-release-a`, soak 7 days, then come back here. Otherwise merge `localization-release-b` into `Shat` (Claude can open the pull request) and archive from there.
3. **Archive a Release build** in Xcode → Product → Archive → Distribute → App Store Connect.
4. **In App Store Connect,** on the new version:
   - attach the build;
   - add the German page from step 6;
   - write "What's New" in both languages;
   - submit for review.
5. **Optional:** a TestFlight round with your German proofreader before you submit.

**Done when:** Apple approves and the version is live in the German store.

---

## Step 9. After launch: what to watch (4–6 weeks)

Your baseline (90 days to 2026-11-10): **Germany had 17 onboardings and 5 purchases.** EU users who don't speak English already convert about as well as English speakers. The question is whether German grows that.

- **In PostHog, split by `app_language` and `device_language`.** These are new properties sent by this release; see `Wingman/Util/Analytics.swift`. Watch:
  - onboarding completion;
  - paywall conversion;
  - first payment (there's no trial any more);
  - lesson completion for German users against English users in the same storefronts (DE, AT, CH).
- **App Store Connect → Analytics:** impressions, product page views and downloads for Germany, before and after the German page.
- **RevenueCat:** revenue by country.
- **Reviews in the German store:** these are the best source of translation complaints. Fix them with the step 1c flow; a database wording fix doesn't need an app update.
- **During the 7-day soak:** crashes and the onboarding-to-paywall rate overall, not just German.

**Done when:** you have 4–6 weeks of numbers and can decide whether the next language is worth it.
