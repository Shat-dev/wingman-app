# Apple Retention Messaging: angles for Wingman trials

_Written 2026-11-05. Data from Wingman PostHog (project 393936), RevenueCat webhook events from 2026-08-29 to 2026-11-04. These are one-off counts, not saved metrics._

## What Apple released

When someone taps **Cancel Subscription** in Apple's subscription settings, Apple now shows a confirmation sheet that can carry **your** message before they confirm. They can cancel, tap "Don't Cancel", accept an offer, or switch plans.

There are two ways to run it:

| | App Store Connect (available now) | Retention Messaging API (needs approval) |
|---|---|---|
| What it shows | One message per subscription: text, text + image, or text + retention offer | A different message per person, chosen when they tap Cancel |
| Targeting | Offer eligibility only (minimum paid time, wait between offers) | Is in free trial, is in intro offer, product, storefront, last redeemed offer, spend, custom attributes (through RevenueCat) |
| Switch-plan message | No | Yes ("move to monthly instead") |
| Setup | Monetization → Subscriptions → Retention Messaging | Account Holder fills Apple's request form with RevenueCat's endpoint URL (RevenueCat → App Store app settings) |

**Limits that shape the copy**
- Title is at most 66 characters and the subtitle at most 144. Bullet lists aren't supported, so a list has to be baked into the image.
- The text is static and App Review approves it per language. Nothing is personalised at runtime, so it can't say "your 4-day streak".
- The text **cannot mention prices, discounts or offers** ("50% off", "1 month free"). An offer appears as Apple's own card under the text.
- Factual statements about what the person loses are allowed. Coercive or unverifiable claims get rejected, and Apple "strongly discourages" unsupported statistics, so "77% of women…" is out.
- An app can have 10 messages. Each subscription has one active ASC message. Each message needs a localization for every storefront you sell in, including en-GB and en-AU.
- Images are 3840×2160 PNG with no transparency and require alt text.
- It works on iOS 15.1 and later. Sandbox testing needs TestFlight or a sandbox account, plus a way to open Apple's manage-subscriptions screen.

## Why this matters for Wingman specifically

100 trials started since Aug 29:

| | Trials | Cancelled | Cancelled ≤1 h | 1–24 h | >24 h | Converted |
|---|---|---|---|---|---|---|
| Yearly | 52 | 40 (77%) | **25** | 9 | 6 | 13 (25%) |
| Monthly | 48 | 25 (52%) | **7** | 6 | 12 | 23 (48%) |

(A few cancels are `BILLING_ERROR` rather than `UNSUBSCRIBE`.)

**Half of all trial cancels happen within an hour of starting.** These people haven't judged the product yet. They're cancelling as insurance against being charged. Every one of them walks through Apple's cancel sheet, which is exactly where this feature appears. Right now that sheet is empty.

Yearly trialists are the leak: 77% cancel and 25% pay, against 52% and 48% on monthly.

## The marketing lens (Leon Abboud's article)

The article's argument, applied to a man about to cancel Wingman:

- **There are three desires: health, wealth and relationships.** Wingman sells relationships. Nobody wants "courses". They want to stop freezing up and actually talk to her.
- **The brain filters on survive/thrive.** At the cancel sheet, "survive" means *don't get charged for something I won't use*. If we don't answer that fear first, he won't read anything else.
- **The grunt test.** You get one line and about two seconds. Plain words, an obvious benefit, no jargon.
- **Pain, desire, and perceived distance.** Make the gap visible ("what if" moments versus being the guy who goes for it), then make the path feel short and believable (the mechanism: small daily reps).
- **Mechanism beats promise.** "Get confident" is a promise. "A lesson, a practice and a logged approach a day" is a mechanism a sceptic can evaluate.
- **The vehicle comes last.** The cancel sheet is a new vehicle. The message has to be right before the placement helps.

## The angles

All copy below fits Apple's 66/144 limits and avoids prices and stats.

### 1. "You don't have to cancel to be safe" (answers the survival fear)
**For:** everyone in a free trial, especially the 32 one-hour cancellers.
**Why:** this answers the real reason he's cancelling. He isn't rejecting Wingman, he's protecting his wallet. Take the fear away and there's nothing left to cancel for.

> **You don't have to cancel to stay safe** (37)
> Keep your trial running and we'll remind you the day before it ends. If Wingman isn't helping by then, cancel in one tap. (121)

⚠️ **This only works if it's true.** Wingman has no trial-end reminder today: `NotificationManager` schedules only the daily reading reminder. Build a local notification for 24 hours before `expiration_at` first. That reminder is worth having on its own, because "we'll remind you" is also a strong paywall line.

Fallback if the reminder isn't built:
> **Your trial has more to give you** (31)
> Cancelling now doesn't end your free days, it just ends your plan. Keep it, finish this week's lessons, then decide. (116)

### 2. Switch yearly to monthly (the biggest data-backed lever)
**For:** people in a yearly trial (real-time API, switch-plan message).
**Why:** yearly trialists cancel because a year feels like a big commitment, and the earlier funnel analysis showed people who deliberated chose monthly and didn't instant-cancel. Monthly converts at almost double the rate. Give the cautious buyer a smaller yes instead of a no.

> **Prefer to go month by month?** (28)
> Switch to the monthly plan and keep every course and your progress, without committing to a full year. (102)

⚠️ **Verify in sandbox** what happens to the free trial when someone switches mid-trial. Yearly→monthly is a downgrade in the same group, and Apple normally applies it at the next renewal. Confirm he still gets his remaining free days and is billed monthly, not yearly, when the trial ends.

### 3. Identity and desire (sells the gap, not the product)
**For:** monthly trialists, and as the default ASC text message.
**Why:** this is the article's core move. It names the life he wants and the cost of staying where he is, using the paywall's own headline so the voice stays consistent.

> **Day 1 of becoming the guy who goes for it** (41)
> Nerves don't disappear by waiting. Wingman builds confidence one small rep a day: a lesson, a practice, a logged approach. (122)

Alternative, pain-led:
> **Stop wondering what she would have said** (39)
> Wingman turns talking to women into small daily steps, from eye contact to opener to asking for her number. (107)

### 4. Factual loss (Apple explicitly allows this)
**For:** paying subscribers who cancel at renewal, and trialists after the first 24 hours (once they've built something).
**Why:** after a few days there is something concrete to lose. Pair it with an image of the course map and approach log, which can carry the list Apple won't render as bullets.

> **You'll lose your courses and approach log** (41)
> When your plan ends, you lose access to every course, daily practice, and the approaches you've logged so far. (110)

### 5. Retention offer (paying subscribers only, not trials)
**For:** paid monthly subscribers cancelling before a renewal. Use any of the texts above, with a promotional-offer card (for example one discounted month) attached in App Store Connect.
**Why not trials:** a trialist who sees a discount on the cancel sheet learns that cancelling gets a discount, which trains the 1-hour cancellers to do it every time. ASC's "Paid Subscription Duration" gate also keeps trialists out. This is a separate offer from `wingman_yearly_discount`. Leave that product alone (see memory notes).

### Don't do this
- "Most guys who stick with it log their first approach in a week." This is an unverified stat, so it will be rejected or should be.
- Anything with a price, "free month" or "50% off" in the text.
- "Last chance", all-caps, or "!!" These count as coercive or against the style rules.

## Suggested setup

| Audience (RevenueCat filter) | Message |
|---|---|
| In free trial + `wingman_yearly` | **#2 Switch to monthly** |
| In free trial + `wingman_monthly` | **#1 Reminder** (or #3 until the reminder ships) |
| Paid `wingman_monthly`, not in trial | **#4 Loss** + promotional offer |
| Paid `wingman_yearly`, not in trial | **#4 Loss** (offer optional) |
| Default / fallback (required per product) | **#3 Identity** |

## Rollout order

1. **Today, with no approval needed:** in App Store Connect, add #3 as a text-only message on both subscriptions and localize it for every English storefront. Any cancel sheet with something on it beats an empty one.
2. **Account Holder requests API access** using RevenueCat's endpoint URL. Approval takes time, so start it now.
3. **Build the trial-end reminder** (a local notification 24 h before trial expiry) so that angle #1 is honest. Mention it on the paywall too.
4. **Optional:** make Settings → Manage Subscriptions open Apple's in-app sheet (`.manageSubscriptionsSheet`) instead of the `apps.apple.com` URL. It's smoother and makes sandbox testing easier.
5. Once approved, run RevenueCat's performance test (up to 1 hour, needs an active sandbox or TestFlight subscription). Then create the real-time messages in the table above, both sandbox and production.
6. **Measure:** RevenueCat's save rate, plus a new PostHog check for `rc_uncancellation_event` (none have fired so far, so any appearing is the feature working). Watch the ≤1 h cancel share fall from about 50%.

**Volume caveat:** about 1 trial cancel a day means an A/B test between messages would take months to read. Pick the strongest message per segment, run it for 4–6 weeks, and compare the cancel rate and trial→paid against the table above.

## Sources
- [Apple: Configure retention messages](https://developer.apple.com/help/app-store-connect/manage-subscriptions/configure-retention-messages)
- [RevenueCat: Apple Retention Messaging API](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-retention-messaging-api)
- [Apple: Retention Messaging API reference](https://developer.apple.com/documentation/retentionmessaging), and WWDC26 session 309
- [9to5Mac launch coverage, 2026-11-04](https://9to5mac.com/2026/11/04/apple-now-lets-developers-offer-discounts-when-users-move-to-cancel-subscriptions/)
- [Leon Abboud: How to become so good at marketing your competition thinks you're cheating](https://x.com/leonabboud/status/2094443253495894440)
