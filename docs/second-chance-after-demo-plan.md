# Second-Chance Offer on the Feature-Gate Paywall — Diagnosis + Plan

Status: **Planning only — no code changed.**

Extends `second-chance-paywall-plan.md` and closes open item §5 of
`demo-then-wall-plan.md`.

**Intent (confirmed 2026-08-03):** the target is the paywall the user hits when
they finish the free lesson and try the second one, tap scenario 2, or tap daily
practice — i.e. `PaywallSource.featureGate`, presented by
`SubscriptionGateModifier`. When *that* is dismissed, show a discounted offer with
copy and graphics that make the discount legible.

Verified against branch `Shat`.

---

## 1. Headline: the trigger already exists and is live

`SubscriptionGateModifier.swift:54` chains `SecondChanceOfferView` off a
no-purchase dismissal of the feature-gate paywall, via SwiftUI's sheet-level
`onDismiss:`. All three gate call sites get it:

| Call site | Gate |
|---|---|
| `Home/HomeView.swift:315` | daily practice |
| `PracticeGame/PracticeView.swift:71` | scenarios |
| `Courses/CourseDetailSheet.swift:184` | lessons |

The product, RC offering, offer screen, purchase logic, once-ever persistence and
eligibility checks are all built and correct. The RevenueCat dashboard identifiers
match `RevenueCatConfig.swift:56-59` exactly.

**So the question is not "how do we wire this" — it is "is what's already wired
safe to ship, and does the offer itself make sense."** §3 and §4 answer those.

---

## 2. The flow, as actually shipped

There are **three** paywall surfaces, not two. The middle one is easy to forget:

```
onboarding questions → RatingPromptView
  → PAYWALL #1        PaywallView(source: .onboarding)         WingmanApp.swift:233
  → MainTabView, demo mode — mascot walkthrough, free scenario 1
  → markFreeDemoCompleted()                                    MainTabView.swift:131,149
  → POST-DEMO ASK     PaywallView(source: .postDemo)           WingmanApp.swift:288
        ↳ route, not a sheet; soft unless post_demo_wall_hard
  → dismiss → MainTabView, and the FREE LESSON CREDIT unlocks  AuthManager.swift:551-555
  → user completes the free lesson
  → taps lesson 2 / scenario 2 / daily practice
  → PAYWALL #2 (your naming)  PaywallView(source: .featureGate)  SubscriptionGateModifier
  → dismiss → SECOND-CHANCE OFFER          ← already implemented
```

Note the free lesson credit is released by `markFreeDemoCompleted()` and collected
**on the far side of the post-demo ask** (`AuthManager.swift:2173-2176`). So the
user meets a paywall immediately before the free lesson *and* immediately after
it. That is three paywalls in a short span. Whether that is intended is a product
call worth making deliberately — it is the highest-leverage open question here,
and it is independent of everything else in this document.

---

## 3. Edge cases — ranked by whether they can bite

### 3.1 🔴 The offer can be spent during the walkthrough

The walkthrough scrim passes taps through on two beats —
`.scenarioPrompt` and `.lessonsTour` (`WalkthroughOverlayView.swift:58-67`) —
because the script asks the user to tap a card and scroll the course list. Demo-mode
locking was **cancelled**, not implemented (`demo-then-wall-plan.md` §4), so the
gates are live during those beats. A user who wanders into a locked course during
`.lessonsTour` gets the feature-gate paywall, and dismissing it fires the
second-chance offer **mid-walkthrough** — before they have completed the free
lesson, i.e. before the intended moment.

`hasSeenSecondChanceOffer` is once-ever, so that stray tap permanently consumes
the offer. At the moment you actually want it, `alreadyShown` is `true`.

**Fix — and note the trap in the obvious version:**

```swift
// NOT `guard hasCompletedFreeDemo` on its own.
guard authManager.hasCompletedFreeDemo || authManager.hasSuppressedWalkthrough
else { return }
```

`suppressWalkthrough(reason: "existingProgress")` fires for every pre-update user
with existing progress (`AuthManager.swift:1040-1042`), and nothing ever flips
`hasCompletedFreeDemo` for them. Guarding on `hasCompletedFreeDemo` alone would
**permanently disable the second-chance offer for the entire existing install
base.** Express it as one named property on `AuthManager` (e.g.
`hasResolvedDemoPath`) rather than repeating the disjunction at the call site.

### 3.2 🔴 The offer as configured is a downgrade, not a discount

Unchanged by the surface correction — it applies at the feature gate exactly as it
did anywhere else, because it is a property of the user, not the screen.

Hard constraint (`second-chance-paywall-plan.md` §2): **intro-offer eligibility is
one per subscription group, per Apple ID, ever.** The 3-day free trial on
`wingman_yearly` and the 50%-off intro offer on `wingman_yearly_discount` draw
from the *same* allowance.

- A user at the feature gate has never subscribed, so they are almost always
  **still trial-eligible**.
- `isSecondChanceEligible()` gates presentation on that same eligibility — so
  **the only people who can be shown the discount are exactly the people who
  still hold their free trial.**
- The offer is Pay-Up-Front, no trial: ~$22.49 today.

So it replaces a **$0 door** with a **$22.49 door** and permanently burns the
trial. To someone who just declined at $0-today, that is a worse offer wearing a
discount badge. The offer is not additive — it is a **substitution**. §4 is about
which side of that trade to spend the one allowance on.

### 3.3 🟠 Double-fire on purchase — wrong analytics, double dismiss

`SecondChanceOfferView` marks the offer from two places that both run on a
successful purchase:

- `.onChange(of: authManager.hasActiveSubscription)` → `outcome: "restored"` (line 118)
- the purchase closure → `outcome: "purchased"` (line 183)

The chain is synchronous: `viewModel.purchase()` calls
`SubscriptionManager.handleCustomerInfoUpdate` (line 95) →
`updateSubscriptionStatus` → `NotificationCenter.post`
(`SubscriptionManager.swift:258`, synchronous) → `AuthManager.syncSubscriptionStatus`
→ `hasActiveSubscription = true` — all **before** `purchase()` returns, and there
is an `await` suspension right after (line 96) for SwiftUI to deliver `onChange`.

Result: `markSecondChanceOfferShown` runs twice with different outcomes, firing two
racing `client.auth.update` writes, so `second_chance_offer_outcome` in
`user_metadata` lands nondeterministically. `onDismiss()` is also called twice.
Not user-visible (the boolean is correct either way), but purchase attribution is
wrong. **Fix:** a `@State private var didFinish = false` guard around both paths.

### 3.4 🟡 Once ever, across all three gates

First dismissal at *any* gate consumes it. Dismiss at daily practice on day 1 and
there is no offer at lesson 2 on day 3. This is by design, but it means the offer
does not reliably land on the specific moment described in the intent — the
lesson-2 moment is simply whichever gate happens to come first. If the lesson-2
moment specifically is what matters, the alternative is to scope the trigger to
the lessons gate only. Recommendation: leave it as-is; first-gate is a reasonable
proxy for first real intent, and narrowing it costs volume.

### 3.5 🟡 Trial-ineligible users see nothing

Correct and required — claiming a discount Apple will not honor is a 3.1.2
violation. But it means a slice of dismissers get no offer at all, and under §4
Option A that slice grows (anyone who took a trial and lapsed). Tracked by
`recovery_offer_not_eligible`.

### 3.6 🟢 Presentation stacking — checked, fine

`CourseDetailSheet` is a `navigationDestination` push at both call sites
(`HomeView.swift:293-299`, `CoursesView.swift:346`), not a sheet. So the deepest
stack is sheet (paywall) → sheet (offer), never three. The offer sheet is
presented from a `Task` with two awaits in it, so there is natural delay past the
paywall's dismissal animation — no same-frame double-presentation.

### 3.7 🟢 Guests

`hasSession` is the gate, not `isAuthenticated`, so guests correctly get the offer
(`SubscriptionGateModifier.swift:97` has the comment explaining why the earlier
flag was wrong). Supabase anonymous→permanent linking keeps the same user id, so
the `user_metadata` mirror survives. Worth confirming once in test rather than
assuming.

### 3.8 🟢 Purchase-triggered auto-dismiss does not fire the offer

`SubscriptionGateModifier`'s `onDismiss` hook runs on the purchase path too, but
`hasActiveSubscription` is already true by then so the guard no-ops. Already
handled and commented (lines 44-53).

### 3.9 🔴 Local StoreKit config — the reason the offer never appeared

**Downgraded to 🟢 in error, then confirmed as the actual blocker 2026-08-03**
when the offer failed to appear on a real device test.

The original note said this "only matters if `useStoreKitTestingMode` is flipped
to `true`; it is `false`, so sandbox testing works today." That reasoning was
wrong. `useStoreKitTestingMode` is an app-level constant controlling whether the
app bypasses RevenueCat; it has nothing to do with **the Xcode scheme's**
`StoreKitConfigurationFileReference`, which is set
(`Wingman.xcscheme:59-61` → `Wingman/storekitconfig.storekit`) and which governs
StoreKit product resolution for every run launched from Xcode.

That file contained exactly two products — `wingman_monthly` and
`wingman_yearly`. So RevenueCat returned the `second_chance` offering from its
servers, tried to hydrate `yearly_discount` against a local StoreKit that had
never heard of `wingman_yearly_discount`, and dropped the package. The gate then
failed at the package lookup and skipped silently:

```
🎁 SubscriptionGate: package 'yearly_discount' not found in offering
   'second_chance' — available packages:
```

Nothing was broken in RevenueCat, App Store Connect, or the app logic. The
product simply did not exist in the store the simulator was talking to.

**Fixed:** `wingman_yearly_discount` added to `storekitconfig.storekit` — base
`44.99` (matching `wingman_yearly`, so the rendered renewal price is right),
`groupNumber 1` (level parity with ASC), and a `payUpFront` introductory offer of
`22.49` over `P1Y`. Verified: `savingsPercent` computes to exactly `50` from
those two numbers.

**General lesson worth keeping:** a product that exists in RevenueCat and in App
Store Connect still does not exist for a Debug run unless it is also in the local
StoreKit config file. Any future product needs adding in three places, not two.

### 3.10 🔴 Nothing checks that the product actually carries an intro offer

Found 2026-08-03. Independent of §4's choice, and the most dangerous item left.

`discountedPriceString` is `introductoryDiscount?.localizedPriceString ?? ""`
(`SecondChanceOfferViewModel.swift:27`) and **nothing anywhere guards
`introductoryDiscount != nil`** — `resolveSecondChancePackage()` checks only that
the offering and package exist, and the view's `onAppear` guards only
`viewModel.package != nil`.

The eligibility check looks like it covers this, but does not:
`isSecondChanceEligible()` treats `.unknown` as "show it", and `.unknown` is
precisely what a fresh install with no App Store receipt returns
(`PaywallViewModel.swift:158-162` documents this) — i.e. most of the target
population. So if the Pay-Up-Front offer is missing, misconfigured, or still
pending review in App Store Connect, the offer is presented anyway and renders:

- plan row: `" for your first year"` — leading blank where the price should be
- disclosure: `"Billed  today for your first year."`
- CTA: **"Get 50% Off"**
- and StoreKit charges the **full $44.99**, because the product has no discount
  to apply

A button that says 50% off, a blank price, and a full-price charge. That is a
3.1.2 violation and a chargeback, from a dashboard state the app cannot see.

**Fix:** require the intro offer in `resolveSecondChancePackage()`, so the
failure is "no offer shown" rather than "wrong offer shown":

```swift
guard package.storeProduct.introductoryDiscount != nil else {
    log("🎁 SubscriptionGate: '\(package.storeProduct.productIdentifier)' has no introductory offer — skipping")
    Analytics.capture(Analytics.Event.recoveryOfferNotEligible, ["reason": "no_intro_offer_on_product"])
    return nil
}
```

Keep the view's `onAppear` guard as a second layer, extended to the same
condition.

### 3.11 ✅ Verify the discount product grants the entitlement — CONFIRMED 2026-08-03

`wingman_yearly_discount` is attached to the `Wingman Pro` entitlement alongside
`wingman_yearly` and `wingman_monthly`. The ASC introductory offer is Approved,
and the product sits in the `Wingman Premium` group at level 1, lateral to
`wingman_yearly`. Original risk write-up retained below.



Cannot be checked from code — a RevenueCat dashboard question, and the screenshot
in hand shows the package→product mapping but not entitlements.

If `wingman_yearly_discount` is **not attached to the `Wingman Pro` entitlement**,
then `SecondChanceOfferViewModel.purchase()` takes the `else` branch at line 100:
the user is charged, `entitlements[ENTITLEMENT_ID]?.isActive` is false, and they
get *"Purchase completed but entitlement not found. Please contact support."*
Money taken, no access, support ticket. Two-click check, worst-case outcome —
do it before the flag is ever enabled.

### 3.12 🔴 The discount percentage was asserted, not computed

Found 2026-08-03, prompted by the right question: *does the discount follow the
user's region and currency?*

Prices always did — everything renders `localizedPriceString`, which is
per-storefront. **The percentage did not.** "50%" was hardcoded in four
user-facing strings: the headline, the subhead ("at half price"), the plan-row
badge, and the CTA.

50% off is a choice of *price point*, not a percentage. Apple's price tiers do
not land on exactly half the base price in every territory, so the real saving
drifts — and any storefront where it does got a screen claiming a discount it
was not giving. A false pricing claim under Guideline 3.1.2, unfixable from the
dashboard, and live.

**Fixed:** `SecondChanceOfferViewModel.savingsPercent` computes it from
`introductoryDiscount.price` against `storeProduct.price`, **truncated rather
than rounded** so the number can only ever understate the discount. All four
strings now interpolate it, and the nil path makes no numeric claim at all
rather than falling back to "50%" — a wrong percentage beside a correct price is
worse than a vague one. `recovery_offer_viewed` now carries `savings_percent`,
so territory drift is visible in PostHog instead of invisible.

Worth remembering when the copy is rewritten in §5: **any new percentage claim
must come from `savingsPercent`.** This is the failure mode that looks completely
fine in the base territory and only breaks abroad.

### 3.13 App Review (5.6 / 3.1.2)

Exit-intent discount offers draw scrutiny; new app, no approval history
(`demo-then-wall-plan.md` §5.2). Mitigations are in §5 (no fake timer, unchanged
X affordance) and §6 (ship behind a flag, dark, and enable after review clears).

---

## 4. The offer itself — mechanics and percentage

> **DECIDED 2026-08-03 — Option B.** Keep Pay-Up-Front, 50% off year 1, as
> currently configured. A/B against Option A later. This means **no VM or
> disclosure changes are needed** — both are already written for pay-up-front —
> and Phase 3 drops out of §7 entirely. Option A is retained below as the
> documented alternative for that future test.
>
> Consequence to hold onto: the two doors are mutually exclusive and the choice
> is final. Taking the 3-day trial makes the user a subscriber, so they never
> meet a gate again and never see the offer; if that trial later lapses
> unconverted they are intro-ineligible and the offer is gated out for good.
> Taking the discount consumes the same allowance from the other side. The user
> genuinely gets to pick either door — once.

The user has one intro-offer allowance. Spend it on the trial, or on the discount.

### Option A — Keep the trial, cut the standing price (deferred to a later A/B)

Reconfigure `wingman_yearly_discount` in App Store Connect:

| | Now | Proposed |
|---|---|---|
| Base price | $44.99/yr | **$29.99/yr** |
| Intro offer | Pay-Up-Front, ~$22.49 for yr 1 | **3-day Free Trial** |
| Charged today | ~$22.49 | **$0.00** |
| Reads as | 50% off year 1 | **33% off, for as long as they stay** |

Strictly better than what they just declined on price, identical on risk. That is
what makes an exit offer read as generosity rather than a bait-and-switch, and it
is the cleanest answer to a 5.6 reviewer. No change to the eligibility plumbing.
Cost: the discount is permanent for those users, not year-1 only.

Aggressive variant: **$26.99 (40% off)**. Below that, cannibalising paywall #1 and
the post-demo ask becomes the bigger risk than the incremental conversion.

**Code implications — these are not optional:**
- `discountedPriceString` reads `introductoryDiscount.localizedPriceString`, which
  for a free trial is **"$0.00"**. The VM needs trial-shaped presentation: "3 days
  free", then `storeProduct.localizedPriceString` ($29.99) as the recurring price.
- `renewalPriceString` currently means "the full price it reverts to". Under
  Option A it means "the discounted price they keep". Rename and re-comment.
- The disclosure at `SecondChanceOfferView.swift:169` **must** be rewritten:
  "3 days free, then $29.99/year. Cancel anytime in App Store settings." Shipping
  Option A with the current pay-up-front copy is a false pricing claim under 3.1.2.
- The strikethrough anchor ($44.99) comes from
  `RevenueCatManager.shared.offerings?.current?.package(identifier: "yearly")?.storeProduct.localizedPriceString`
  — never hardcode it, storefronts differ.

### Option B — Keep Pay-Up-Front 50% off year 1

Correct only if you believe the dismissal is a **price** objection rather than a
commitment one. Maximises year-1 revenue per taker, no trial-cancel churn, at the
cost of withdrawing the $0 door and burning the trial. Take rate will be
materially lower. Ships as-is — no dashboard or VM work.

### Not available

**Promotional Offers** and **Win-Back Offers** both require prior subscriber
history this user does not have, and **trial-then-discount cannot be chained** on
one product. Established in `second-chance-paywall-plan.md` §2-3. There is no
configuration that gives this user both a free trial and a discount.

---

## 5. Wording and graphics — the actual build work

Current screen (`SecondChanceOfferView.swift`): SF Symbol tag, headline, subhead,
one `PlanRow`, CTA, disclosure, footer links. Compliant, but it makes no argument.
Six changes, in priority order:

1. **Anchor the saving visually.** Under Option B: `$44.99` struck through beside
   a bold `$22.49`, plus a filled "SAVE 50%" pill, scoped to year 1. Nothing on
   the screen currently shows the price they are being saved *from*, so the
   discount is a claim rather than a comparison. Highest impact, smallest change.
   The anchor must be read from
   `RevenueCatManager.shared.offerings?.current?.package(identifier: "yearly")?.storeProduct.localizedPriceString`
   — never hardcoded, storefronts differ — and the whole block must be suppressed
   if that lookup fails, rather than rendering a strikethrough against nothing.
2. **Name what they just tried to do.** The gate knows whether they were blocked
   on a lesson, a scenario, or daily practice. "Lesson 2 is waiting" converts
   better than "Wait — here's 50% off". Requires threading the gate's context into
   `SecondChanceOfferView`; `subscriptionGate(isPresented:)` would take a
   `context:` parameter defaulting to a generic string.
3. **Honest scarcity, no timer.** "One-time offer — you won't see this screen
   again" is *literally true* (the once-ever flag enforces it). A countdown timer
   is the most common 5.6 rejection trigger and would be a lie here.
4. **Three value bullets, maximum.** They saw the full feature list on the paywall
   seconds ago; repeating it reads as not listening.
5. **Keep the X exactly as it is** — 44×44, top-trailing, no delay, no fade-in.
   Making the exit harder than on the paywall it follows is the other reliable 5.6
   rejection, and it is not worth the conversion.
6. **Stay inside the existing design language.** Manrope, `.wingmanBlack`,
   `Color(hex: "6B7280")`, 5pt radius, `ScalePressStyle`, `PlanRow`. A screen that
   looks like a different app reads as a dark pattern; this one should read as the
   same app being generous.

---

## 6. Feature flag

Add to `FeatureFlags.swift`:

```swift
@Published private(set) var secondChanceOfferEnabled: Bool = false
private static let secondChanceOfferKey = "second_chance_offer_enabled"
```

- **Ships `false`** — enable-switch phrasing. Off is the safe default given §3.10:
  an absent flag or a failed `/decide` means no exit offer, which is the
  review-safe state.
- Launch-arg override **not** behind `#if DEBUG`, following
  `readLessonQuizEnabled()`'s reasoning verbatim: purchases only work in Release,
  so a Debug-only override is unusable for exactly the flow that needs testing.
- Rollout: submit with the flag off → clear review → enable for a cohort →
  compare against the paywall-#2 purchase rate it may cannibalise.

Also add `"source"` to the six `recovery_offer_*` events (`Analytics.swift:82-87`).
Low priority while there is one trigger, but it costs nothing now and it is the
thing you will wish you had if a second trigger is ever added.

---

## 7. Phasing

| Phase | Work | Blocked by | Status |
|---|---|---|---|
| **0** | Decide §4 | — | ✅ Option B |
| **1** | §3.1 walkthrough guard — incl. the `hasSuppressedWalkthrough` trap | — | ✅ done |
| **2** | §3.3 `didFinish` guard against the double-fire | — | ✅ done |
| **3** | ~~VM + disclosure changes for the new mechanic~~ | — | ❌ dropped — Option B ships the existing copy |
| **3a** | §3.10 intro-offer guard in `resolveSecondChancePackage()` | — | ✅ done |
| **3b** | §3.11 dashboard: confirm entitlement attachment + offer approved | — | ✅ confirmed |
| **3c** | §3.12 compute the discount % per storefront instead of hardcoding | — | ✅ done |
| **4** | Wording + graphics (§5 items 1, 3, 4, 6) | 3a, 3b | ✅ done |
| **5** | Gate context threading (§5 item 2) | 4 | |
| **6** | `FeatureFlags.secondChanceOfferEnabled` + `source` on events | — | |
| **7** | Add `wingman_yearly_discount` to `storekitconfig.storekit` | — | ✅ done — §3.9, this was the blocker |

Phases 1 and 2 are live bug fixes and were worth doing regardless of how §4 lands.

### Notes from implementing 1-2

- **Phase 1** added `AuthManager.hasResolvedDemoPath`
  (`hasCompletedFreeDemo || hasSuppressedWalkthrough`) rather than repeating the
  disjunction at the call site. Note it is the *inverse pairing* of
  `canOpenLesson`'s `hasCompletedFreeDemo && !hasSuppressedWalkthrough` — a
  suppressed user was never promised a free lesson, but the walkthrough is still
  behind them. Both are correct; the difference is worth reading twice.
- **Phase 2 needed two mechanisms, not one.** `didFinish` alone would have left
  the *wrong* outcome winning: the `onChange` safety net fires during
  `purchase()`'s `await`, i.e. before the purchase closure runs, so it would have
  claimed the resolution and labelled a purchase as `"restored"`. `isResolving`
  fixes the ordering; `didFinish` drops the loser. Restore now also resolves at
  its own call site instead of leaning on the safety net, which leaves that
  handler with a single honest job: entitlement arriving from *outside* this
  screen (5-minute poll, foreground refresh, RC delegate push), recorded as
  `"subscribed_externally"`.

---

## 8. Testing

`-forcePremium` is opt-in (`AuthManager.swift:462-483`), so Debug builds exercise
non-subscriber paths correctly.

- Complete the walkthrough → free lesson → tap lesson 2 → dismiss → **offer appears**
- Tap a locked course during `.lessonsTour` → dismiss → **offer must NOT appear** (§3.1)
- Existing account with prior progress (`hasSuppressedWalkthrough == true`) → hit a
  gate → dismiss → **offer must appear** (the §3.1 trap)
- Purchase from the offer → confirm `markSecondChanceOfferShown` runs **once**, with
  `outcome: "purchased"` (§3.3)
- Dismiss a gate, then hit a different gate → **no second offer**
- Sandbox account that has consumed its intro offer → `recovery_offer_not_eligible`,
  no offer shown
- Guest session → offer appears; then link an account → confirm the flag survives
- Airplane mode at the gate → offer silently skipped, flag **not** burned
