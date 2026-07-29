# Second-Chance Discounted Paywall — Implementation Plan

Status: **Planning only — no code changed.** This document is the analysis + plan requested before implementation begins.

---

## 1. Analysis of the Current Implementation

### 1.1 Where RevenueCat is initialised
- [`Wingman/Payment/RevenueCatConfig.swift`](../Wingman/Payment/RevenueCatConfig.swift) holds the API keys (DEBUG vs Release), the entitlement id (`"Wingman Pro"`), and the two known product ids (`wingman_yearly`, `wingman_monthly`).
- [`RevenueCatManager.swift`](../Wingman/Payment/RevenueCatManager.swift) is a `@MainActor` singleton (`RevenueCatManager.shared`). `configure()` calls `Purchases.configure(withAPIKey:)` **without** an `appUserID`, deliberately, so the SDK starts anonymous and the later `logIn(supabaseUserId)` can alias/transfer an anonymous purchase (see the long comment at `RevenueCatManager.swift:68-89`). This is called once from `RootView`'s `.task` in [`WingmanApp.swift:229`](../Wingman/WingmanApp.swift).
- `Purchases.shared.delegate = self` — `RevenueCatManager` also owns the `PurchasesDelegate` callback.

### 1.2 How purchases are currently made
- Two purchase call sites, both going through `Purchases.shared.purchase(package:)`:
  - `PaywallViewModel.purchase(_:)` (`Wingman/Payment/PaywallViewModel.swift:381`) — the real UI-driven purchase path used by `PaywallView`. Handles `userCancelled`, checks `customerInfo.entitlements[Constants.ENTITLEMENT_ID]`, fires PostHog + Meta events, updates `SubscriptionManager` synchronously with the authoritative `customerInfo`, and (if the user was anonymous) stores the purchase in `AnonymousUserManager` for later linking.
  - `RevenueCatManager.purchase(_:)` — a thinner duplicate, not currently wired to the paywall UI (kept as a general-purpose helper).
- Restore: `PaywallViewModel.openRestore()` → `Purchases.shared.restorePurchases()`.

### 1.3 How offerings are fetched
- `PaywallViewModel.loadOfferings()` is the real implementation used by the UI. It:
  - Coalesces concurrent triggers via `loadTask`.
  - Retries with linear backoff (`maxLoadAttempts = 3`) only on a cold load (no cached offerings yet).
  - Races each attempt against a 15s timeout (`fetchOfferingsWithTimeout`).
  - On success, auto-selects the yearly package and loads intro-offer eligibility.
  - Reports failure to PostHog (`paywall_offerings_failed`) only once every attempt is exhausted.
  - Retries automatically when `NetworkMonitor` reports connectivity restored.
- `RevenueCatManager.fetchOfferings()` is a simpler one-shot version, used to seed `RevenueCatManager.offerings` at app launch (`configure()` → `Task { await fetchOfferings() }`).

### 1.4 How the paywall decides which package to display
- Both view models resolve packages the same way, with a named-identifier-first fallback:
  ```swift
  offerings?.current?.package(identifier: "yearly") ?? offerings?.current?.annual
  offerings?.current?.package(identifier: "monthly") ?? offerings?.current?.monthly
  ```
- Everything reads from `offerings?.current` — **there is currently only one Offering in play** in the app's logic. Introducing a second, distinct Offering (or a distinct Package inside `current`) is new territory for this codebase, not an existing pattern to reuse verbatim.

### 1.5 How eligibility for free trials is determined
- `PaywallViewModel.loadIntroEligibility()` calls `Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers:)` for both the yearly and monthly product ids and stores the result in `@Published var introEligibility: [String: IntroEligibility]`.
- `isYearlyTrialEligible` / `isMonthlyTrialEligible` / `isTrialEligible(for:)` treat `.eligible` **and** `.unknown` as "show trial UI" (optimistic default — `.unknown` is what a fresh install with no App Store receipt returns, and Apple will honor the trial in that case). Only `.ineligible` / `.noIntroOfferExists` hides the trial badge — this is explicitly to satisfy Apple Guideline 3.1.2 (never claim a trial the user won't actually get).
- Eligibility is re-checked after a **failed** restore (a restore with no entitlement still writes the App Store receipt to disk, so RevenueCat can now give an authoritative answer).

### 1.6 Where paywall dismissal is handled
- `PaywallView` takes `isDismissible: Bool` and an optional `onDismiss: (() -> Void)?`.
  - `isDismissible == false` (not currently used at either real call site, but supported): no X button, non-dismissible.
  - `onDismiss == nil` (onboarding paywall): X calls `authManager.completePaywallFlow()` — this is a **routing-level** completion (advances `RootView`'s state machine to `MainTabView`).
  - `onDismiss` provided (feature-gate paywall, via `SubscriptionGateModifier`): X just closes the sheet (`isPresented = false`); it deliberately does **not** call `completePaywallFlow()` because the user is already past that step.
- PostHog `paywall_dismissed` fires from the X button with `outcome: "dismissed_without_purchase"`, and separately from the Continue button with `outcome: "purchased"` — both tagged with `source` (`onboarding` / `featureGate`).

### 1.7 Where the feature-gated paywall is presented
- `SubscriptionGateModifier.swift` — a single reusable `.subscriptionGate(isPresented:)` view modifier wraps `PaywallView(source: .featureGate, isDismissible: true, onDismiss: { isPresented = false })` in a `.sheet`. It also auto-dismisses the sheet if `authManager.hasActiveSubscription` flips true while presented (i.e., purchase succeeded).
- Current call sites: `HomeView.swift:307` (Daily Practice), `PracticeView.swift:66`, `CourseDetailSheet.swift:156`, `LogApproachBottomSheet.swift:380`. All four are "user tapped a locked feature while not subscribed."

### 1.8 Where the onboarding paywall is presented
- `RootView` in `WingmanApp.swift` (a state machine, not a dedicated file) presents `PaywallView(authManager:, isDismissible: true, source: .onboarding)` directly (no `onDismiss` override) at two points: the authenticated branch (`WingmanApp.swift:159`) and the anonymous-but-onboarded branch (`WingmanApp.swift:188`) — reached only after onboarding questions are answered and the rating prompt has been acknowledged, gated on `!authManager.effectivePaywallFlowCompleted`.

### 1.9 How subscription state is cached
Two independent caches, for different purposes:
- **`SubscriptionManager`** (`Wingman/Payment/SubscriptionManager.swift`) persists `cached_subscription_active` / `cached_subscription_expiry` in `UserDefaults.standard` — **global, not per-user**, deliberately: Apple subscriptions are tied to the Apple ID / device, not the app's account system, so this is correct even across an app-account switch on a shared device. Read synchronously at `initializeMonitoring()` so gated UI never flashes "unpaid" for a paying user during the cold-start network round-trip; a stale "active" past its stored expiry is treated as inactive without waiting for the network.
- **`AuthManager`** persists routing/flow flags **per Supabase user id** (`hasCompletedPaywallFlow_<userId>`, `hasSeenRatingPrompt_<userId>`, etc.) in `UserDefaults`, with a **Supabase `user_metadata` mirror** as the cross-device/reinstall-durable source of truth (`captureStoreContext`, `paywall_flow_completed`, `age`). The read path is: try the per-user UserDefaults key first; if false, fall back to `currentUser.userMetadata["paywall_flow_completed"]`, and if that hits, backfill UserDefaults. This two-tier pattern (fast local cache + durable server mirror, self-healing on read) is the established convention in this codebase — see `checkUserPaywallFlowStatus` / `completePaywallFlow` in `AuthManager.swift`.
- Anonymous (pre-signup) users get a third, temporary tier: `AnonymousUserManager` (global `UserDefaults`), which is transferred into the per-user keys + `user_metadata` at `syncAnonymousDataToBackend()` on signup.

### 1.10 How entitlements are refreshed
- **Delegate push**: `RevenueCatManager: PurchasesDelegate` → `purchases(_:receivedUpdated:)` fires on login/logout, purchase, restore, and any server-side entitlement change, and forwards straight to `SubscriptionManager.handleCustomerInfoUpdate` (idempotent).
- **Periodic poll**: `SubscriptionManager.startPeriodicChecks()` — every 5 minutes via `Timer`.
- **Foreground refresh**: `WingmanApp` observes `willEnterForegroundNotification` → `SubscriptionManager.shared.refreshSubscriptionStatus()` (which also calls `Purchases.shared.invalidateCustomerInfoCache()` first).
- **Synchronous post-purchase/-restore update**: `PaywallViewModel.purchase(_:)` and `.openRestore()` call `SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)` with the *authoritative* `customerInfo` returned directly from the StoreKit call, before the async refresh, so `SubscriptionGateModifier`'s auto-dismiss fires reliably even if the network blips immediately after.
- `AuthManager.hasActiveSubscription` is driven by `NotificationCenter` (`subscriptionStatusChangedNotification`), not a direct dependency on `SubscriptionManager` — this is why it self-heals `hasCompletedPaywallFlow` inside `syncSubscriptionStatus()` (a paying user is by definition past the paywall, even if the flag is stale after a reinstall).

**Note (⚠️ found in passing, not part of this task):** `syncSubscriptionStatus()` in `AuthManager.swift:189-196` hardcodes `self.hasActiveSubscription = true` under `#if DEBUG`. That's outside the scope of this plan, but it means the recovery-offer gating logic below (`!hasActiveSubscription`) **cannot be manually tested in a DEBUG build** without also toggling that — flagged in §7 (Testing).

---

## 2. Apple Constraints — What Is and Isn't Allowed

**Direct answer to "3-day free trial → then 50% off Year 1 → then normal renewal, as one chained offer": No.** Apple's `SubscriptionOffer` on a single product supports exactly one offer *type* — Free Trial, Pay-As-You-Go, or Pay-Up-Front — you cannot stack two introductory offers (a trial *followed by* a discount) on the same product/purchase. This is a hard StoreKit limitation, not a RevenueCat one.

The two governing rules:

1. **One introductory offer per subscription group, per Apple ID, ever.** A customer is eligible for an introductory offer (trial, pay-as-you-go, or pay-up-front, on *any* product in the group) only if they have never redeemed an introductory offer for that group before. The moment they redeem one — on any product in the group — that eligibility is permanently consumed for the group. ([Apple: Offering introductory offers](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app), [Adapty: Apple subscription offers guide](https://adapty.io/blog/apple-subscription-offers-guide/))
2. **Promotional Offers and Win-Back Offers both require the user to already be (or have been) a subscriber.** Promotional offers target "existing and lapsed subscribers who previously held an active subscription" and require presenting a **server-signed** discount (RevenueCat needs your App Store Connect In-App Purchase Key uploaded so it can sign these on your behalf via `getPromotionalOffer(...)`). Win-back offers (iOS 18+) specifically target *churned* subscribers meeting a developer-defined "minimum paid duration" and "time since last subscribed" — i.e., someone who paid at least once, then lapsed. ([RevenueCat: iOS Subscription Offers](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers/ios-subscription-offers))

**Why this matters for this feature specifically:** by construction, the user this feature targets has *never* had an active entitlement — if they had, `authManager.hasActiveSubscription` would be true and the feature gate would never have fired paywall #2 at all (§1.7/§1.9). So this user:
- **Is not eligible for a Promotional Offer or a Win-Back Offer** — both require prior/active subscriber history that doesn't exist yet.
- **Is still eligible for one Introductory Offer**, *provided* they didn't already redeem the 3-day trial at paywall #1. Since reaching paywall #2 requires `!hasActiveSubscription`, and starting the trial *would* set `hasActiveSubscription = true` for its duration, a user who took the trial and is still inside it will never see paywall #2 (or the recovery offer) in the first place — they're gated out upstream. The edge case that *can* still consume eligibility: a user who started the trial, it later **expired without converting** (e.g. billing failure at trial end), and they subsequently reach paywall #2 — see the eligibility-gating requirement in §6.

**The compliant mechanism, therefore, is a second Introductory Offer — on a second product** (App Store Connect ties one intro offer configuration to one product/price point; you cannot add a second, different intro offer to `wingman_yearly` alongside its existing 3-day trial). Concretely:

- Create a new product, e.g. `wingman_yearly_second_chance`, in the **same subscription group** as `wingman_yearly` / `wingman_monthly` (so it competes for the same "one intro offer per group" pool and grants the same entitlement level).
- Configure a **Pay-Up-Front introductory offer** on it: 50% of the normal yearly price, duration = 1 year. Pay-up-front is exactly "reduced price for the intro duration, then reverts to the standard renewal price" — which matches "discount applies only to the first year, automatically renews at normal yearly price after" precisely, with Apple (not app code) enforcing the renewal price transition.
- A user is offered this at true 50% off **only if StoreKit says they're eligible** (`checkTrialOrIntroDiscountEligibility` against the *new* product id) — if they already consumed their one intro offer (e.g. the expired-trial edge case above), StoreKit will silently charge full price regardless of what our UI says, which would violate Guideline 3.1.2's pricing-accuracy requirement. **The client must gate presentation of the recovery offer on this eligibility check, not just on "haven't shown it before."**

**App Store Review Guideline 3.1.2 compliance** (same pattern already used for the trial disclosure in `PaywallView.swift:369-371`): the recovery offer screen must clearly disclose, near the purchase button, (a) the discounted price and that it applies to year 1 only, (b) the exact renewal price and that it recurs annually, and (c) that it auto-renews until cancelled, with a working cancellation path. Apple reviewers check this text explicitly for introductory-price screens.

**Product/pricing note:** App Store Connect prices are set as absolute price-tier points, not literal "50%" — you pick the intro price tier nearest half of the standard tier for each storefront/currency (Apple's price tiers don't guarantee an exact 50.000% across every territory; this is normal and acceptable — RevenueCat/App Store Connect handle per-territory tiering automatically once you pick the intro price relative to the base price in your primary territory).

---

## 3. RevenueCat Best Practice — Mechanism Tradeoffs

| Mechanism | Fits this use case? | Why / why not |
|---|---|---|
| **Introductory Offer (Pay-Up-Front) on a new product** | ✅ **Recommended** | Only mechanism that (a) works for a never-subscribed user, (b) needs no server-side signing, (c) has Apple enforce the "reverts to full price after year 1" behavior automatically, (d) is checkable client-side with the exact same `checkTrialOrIntroDiscountEligibility` API already used in this codebase. |
| **Promotional Offer** | ❌ Not eligible | Requires the user to already have/have had an active subscription in the group (§2). Also requires uploading an App Store Connect In-App Purchase signing key to RevenueCat and calling `getPromotionalOffer(...)` — real infra even where it *is* applicable. Save this mechanism for a future "win back a cancelled subscriber" flow, not this one. |
| **Win-Back Offer** | ❌ Not eligible | Requires "minimum paid duration" — i.e., the user must have paid at least once before. Not applicable to a user who has never converted. |
| **Offer Codes** | ❌ Wrong shape | Designed for out-of-band distribution (marketing emails, influencer codes), redeemed via a code-entry sheet or App Store link — not a fit for an automatic in-flow "you just dismissed the paywall" moment. |
| **Reuse the existing `wingman_yearly` product, just show a "discounted" price label in the UI** | ❌ Not viable | The price StoreKit charges is whatever is configured on the product/offer in App Store Connect — you cannot show one price in-app and charge another. Apple would reject this, and it wouldn't actually charge 50% off. |
| **A second Offering (RevenueCat) pointing at the new product** | ✅ **Recommended**, alongside the new product | RevenueCat Offerings/Packages are a *targeting/presentation* layer over App Store Connect products, not a discounting mechanism themselves — the discount lives in ASC. But a dedicated Offering (e.g. `second_chance`) cleanly isolates "which package(s) does this specific paywall screen show" from the main `current` offering, matches the one-Offering-per-screen mental model already used by `PaywallViewModel`/`RevenueCatManager` (§1.4), and is the natural surface for later A/B testing via RevenueCat's Targeting rules without touching client code. |
| **Entitlements** | No new entitlement needed | Attach the new product to the existing `Wingman Pro` entitlement in the RC dashboard. The recovery offer grants the *same* access as the regular yearly plan — it's a pricing experiment, not a different product tier. |
| **RevenueCat Paywalls (remote-configured UI) / Targeting** | Optional, future | RC's Targeting can serve different Offerings to different customer segments (via Custom Attributes) without an app update — a good fit for *later* iteration (e.g. tuning who gets 50% vs 30% off) but not required for v1, and it doesn't change the underlying Apple constraint in §2. Flagged as a "phase 2+" opportunity in §5. |

---

## 4. Recommended Architecture

### 4.1 App Store Connect / RevenueCat dashboard model
- **New product**: `wingman_yearly_second_chance` (or similar), same subscription group as `wingman_yearly`/`wingman_monthly`, same duration (1 year), same subscription **level/rank** as `wingman_yearly` (so it's a lateral option, not an upgrade/downgrade in Apple's eyes — avoids proration surprises if a subscriber ever switches between the two).
- **Introductory offer** on that product: Pay-Up-Front, 50% of the standard yearly price, 1-year duration, available to new subscribers (Apple's default "new customers" eligibility, which is exactly the population this offer targets).
- **Entitlement**: attach the new product to the existing `Wingman Pro` entitlement.
- **RevenueCat Offering**: a new Offering `second_chance` containing one Package wrapping `wingman_yearly_second_chance`. Leave `current` untouched — no risk to the existing onboarding paywall.
- **RevenueCat Customer Attribute** (optional, recommended for cross-system consistency): set `second_chance_offer_shown` after presenting, mirroring the pattern of tagging state on the RC customer for future dashboard segmentation — but see §"Persistence" below for why this is **not** the gating source of truth.

### 4.2 Client-side flow
1. `SubscriptionGateModifier`'s existing sheet (`PaywallView(source: .featureGate, ...)`) dismisses via its `onDismiss` closure.
2. That closure — today just `isPresented = false` — is extended to also evaluate whether the recovery offer should chain in:
   - not already subscribed (`authManager.hasActiveSubscription == false`)
   - not shown before (`!authManager.hasSeenSecondChanceOffer`, per-user, §"Persistence")
   - StoreKit/RevenueCat confirms intro-offer eligibility for `wingman_yearly_second_chance`
   - the `second_chance` Offering/Package actually resolved (defensive — dashboard misconfig shouldn't crash or dead-end the user)
3. If all true, present a new, dedicated view — `SecondChanceOfferView` — as a second sheet, single-plan, single-CTA, with the required 3.1.2 pricing disclosure.
4. On dismiss **or** purchase (success or failure-after-cancel), mark the offer as shown (`authManager.markSecondChanceOfferShown(outcome:)`) so it truly never appears again, regardless of which path the user took.
5. On purchase success, the sheet auto-dismisses the same way the existing feature-gate paywall does today (via the `hasActiveSubscription` `.onChange`).

### 4.3 Why a new view instead of extending `PaywallView`
`PaywallView` is built around a 2-plan carousel (monthly/yearly) with per-plan trial badges. A recovery offer is conceptually different UX: one plan, urgency framing, a savings badge, and mandatory renewal-price disclosure. Bending `PaywallView` to conditionally render a single-plan "special offer" mode would add a third source-branching dimension (`source` already distinguishes onboarding/featureGate; adding "is this the discount screen" on top multiplies the states `PaywallView`, `PaywallViewModel`, and their tests have to handle) for a screen whose content and layout genuinely differ. A small, dedicated `SecondChanceOfferView` + `SecondChanceOfferViewModel` pair is less code overall and keeps `PaywallView` unchanged (lower regression risk to the existing, working paywalls). It can still reuse `PlanRow`, `HapticManager`, `SafariView`, and the PostHog helper patterns already in `PaywallView.swift`.

### 4.4 Persistence — "shown only once, ever" (comparison)

| Option | Survives reinstall? | Synchronous read at gate time? | Fits existing app conventions? | Verdict |
|---|---|---|---|---|
| **UserDefaults only** | ❌ No — wiped on uninstall | ✅ Yes | Partially (used as the *fast cache* tier everywhere else) | Not sufficient alone — a reinstalling user (deliberate or not) would see the discount again indefinitely, undermining "genuine one-time recovery offer" and Apple's expectation that introductory-style messaging map to a real one-time event. |
| **RevenueCat Customer Attribute (read back client-side)** | ✅ Yes (tied to RC App User ID = Supabase user id, post-login) | ❌ No — the client SDK is write-only for custom attributes; reading them back requires the server-side REST API (secret key), not exposed to the app | No existing pattern in this codebase for reading RC attributes back into the client | Good for **write-once, dashboard-side segmentation/Targeting** (§5, phase 2+), bad as the sole gating source for a client-side `if` check. |
| **Backend database — Supabase `user_metadata`** | ✅ Yes | Local cache read is synchronous; the metadata itself hydrates on session restore, same as today | ✅ Yes — **this is exactly the existing `paywall_flow_completed` / `age` / store-context pattern** already implemented in `AuthManager.swift` | **Recommended primary/durable tier.** Zero new backend infrastructure (no migration, no new table) — reuses `client.auth.update(user:)` against `auth.users.user_metadata`, the same call `completePaywallFlow()` already makes. |
| **Local cache (per-user UserDefaults key, e.g. `hasSeenSecondChanceOffer_<userId>`)** | ❌ No, by itself | ✅ Yes | ✅ Yes — mirrors `hasCompletedPaywallFlow_<userId>` exactly | **Recommended fast tier**, paired with the Supabase mirror below it — never used alone. |
| **New dedicated Postgres table** (e.g. `user_offer_state`) | ✅ Yes | Requires a network round trip unless cached locally anyway | ❌ New infra not currently needed | Overkill for a single boolean-ish flag; would only be justified if the team later wants to run many concurrent, queryable offer experiments server-side. Not recommended for v1 — flagged as a future option in §5 if the team wants server-driven experiment targeting beyond what RC Targeting covers. |

**Recommendation:** replicate the existing two-tier pattern exactly — per-user `UserDefaults` key as the fast/offline-safe read, mirrored best-effort to Supabase `user_metadata.second_chance_offer_shown` (plus `second_chance_offer_shown_at` and `second_chance_offer_outcome` for observability) as the durable, reinstall-surviving source of truth, with the same self-healing read (`UserDefaults` first, fall back to `user_metadata` on miss, backfill on hit) already implemented for `hasCompletedPaywallFlow`. This is the option with the least new code, the least new failure surface, and it's the pattern the next engineer touching this file will already recognize.

Do **not** use Apple/StoreKit intro-offer eligibility itself as the "already shown" gate — it answers "would Apple actually give this user the discount," not "did our app already offer it." Both checks are needed and serve different purposes (§4.2 step 2).

---

## 5. Step-by-Step Implementation Plan

### Phase 0 — App Store Connect & RevenueCat dashboard (no code)
- **App Store Connect**: create `wingman_yearly_second_chance` in the existing subscription group; set price = ~50% of the yearly product's price in the primary territory; add a Pay-Up-Front introductory offer, 1-year duration, at that price; set localized display name/description (this string can surface in the user's Settings ▸ Subscriptions page — make it clear, e.g. "Wingman Pro (Yearly)" matching the parent product's naming, not "50% off" verbatim, since that copy goes stale after year 1); submit for review alongside the next app version (new IAPs need review, and typically ride along with a binary submission).
- **RevenueCat dashboard**: import the new product; attach it to the `Wingman Pro` entitlement; create the `second_chance` Offering with one Package (`identifier: "yearly_discounted"` or similar) wrapping the product.
- **Risk**: Apple in-app-purchase review can take 24–48h+ and is separate from binary review — start this phase well before the target ship date.
- **Testing checklist for this phase**: verify the new product appears in RevenueCat's "Offerings" tab with a resolved price; verify a sandbox account with no purchase history shows the product as intro-offer-eligible in App Store Connect's sandbox testing tools.

### Phase 1 — Config & data layer
- **Files to modify**:
  - [`Wingman/Payment/RevenueCatConfig.swift`](../Wingman/Payment/RevenueCatConfig.swift): add `ProductIds.yearlySecondChance` and a `secondChanceOfferingId` constant, following the existing `ProductIds` struct shape.
  - [`Wingman/Resources/Constants.swift`](../Wingman/Resources/Constants.swift): add `SECOND_CHANCE_YEARLY_PRODUCT_ID`, mirroring the existing `YEARLY_PRODUCT_ID` re-export pattern.
  - [`Wingman/Payment/RevenueCatManager.swift`](../Wingman/Payment/RevenueCatManager.swift): add `getSecondChanceOffering() -> Offering?` and `getSecondChancePackage() -> Package?`, mirroring `getYearlyPackage()`/`getAllPackages()`.
- **New files**: none yet — this phase is data plumbing only.
- **Backend changes**: none.
- **RevenueCat dashboard changes**: none beyond Phase 0.
- **App Store Connect changes**: none beyond Phase 0.
- **State management changes**: none.
- **Analytics events**: none yet.
- **Edge cases**: offerings fetch fails / `second_chance` Offering is missing (dashboard not yet configured, or fetch timing) — every accessor must return `nil` safely, never force-unwrap, matching existing code style.
- **Risks**: low — purely additive, no existing call site touched.
- **Testing checklist**: unit-verify (or manual sandbox check) that `getSecondChancePackage()` resolves once the dashboard Offering exists, and returns `nil` gracefully before that / on a stale local `offerings` cache.

### Phase 2 — Eligibility & persistence in `AuthManager`
- **Files to modify**: [`Wingman/Auth/AuthManager.swift`](../Wingman/Auth/AuthManager.swift)
  - Add `@Published var hasSeenSecondChanceOffer: Bool` (init from global `UserDefaults` at launch, same as `hasCompletedPaywallFlow`).
  - Add `checkUserSecondChanceOfferStatus(userId:)`, called alongside `checkUserQuestionStatus` / `checkUserPaywallFlowStatus` in `observeAuthState()`'s `.signedIn` and `.initialSession` branches (`AuthManager.swift:339-340`) — same UserDefaults-first, `user_metadata`-fallback, backfill-on-hit shape as `checkUserPaywallFlowStatus`.
  - Add `markSecondChanceOfferShown(outcome: String)` mirroring `completePaywallFlow()` (`AuthManager.swift:983-1014`): set the in-memory flag, write the per-user UserDefaults key, best-effort mirror `second_chance_offer_shown: true` + `second_chance_offer_shown_at` (ISO8601 string) + `second_chance_offer_outcome` (`"dismissed"` / `"purchased"`) to `user_metadata` via `client.auth.update(user:)`.
  - Add the new per-user key to `clearAllLocalData()`'s cleanup list (`AuthManager.swift:1448-1458`) and to the `.userDeleted` reset branch (`AuthManager.swift:390-397`).
  - **Anonymous users**: this feature is unreachable for anonymous users by construction (§ Goal — paywall #2 requires account creation first), so no `AnonymousUserManager` changes are needed. Worth a one-line defensive guard in the new gating check regardless (`!authManager.isAnonymousUser`), in case a future refactor changes when `.subscriptionGate` can fire.
- **New files**: none.
- **Backend changes**: none (reuses `auth.users.user_metadata`, no migration).
- **RevenueCat dashboard changes**: none.
- **App Store Connect changes**: none.
- **State management changes**: as above — new published flag + persistence methods on `AuthManager`, following its existing conventions exactly.
- **Analytics events**: none yet.
- **Edge cases**:
  - `user_metadata` write races with a fast app-quit right after dismissal — acceptable per the existing "best-effort mirror" philosophy already documented for `paywall_flow_completed` (local UserDefaults remains source of truth on-device; the mirror only matters for reinstall/new-device).
  - A user who already saw the offer on Device A, then signs in on Device B before the mirror write on Device A has round-tripped — narrow race, same as the existing pattern's known limitation, not a regression.
- **Risks**: low — additive, follows an established, working pattern.
- **Testing checklist**: sign in as a fresh test user → trigger + dismiss the offer → force-quit → relaunch → confirm it does not reappear; delete + reinstall the app with the same test account → sign back in → confirm `user_metadata` fallback correctly suppresses the offer.

### Phase 3 — UI: `SecondChanceOfferView` + `SecondChanceOfferViewModel`
- **New files**:
  - `Wingman/Payment/SecondChanceOfferViewModel.swift` — loads `RevenueCatManager.shared.getSecondChancePackage()`, checks `checkTrialOrIntroDiscountEligibility` for the new product id, exposes the discounted price / renewal price / eligibility as `@Published` state, and a `purchase()` method mirroring `PaywallViewModel.purchase(_:)`'s structure (cancellation handling, entitlement check, `SubscriptionManager.shared.handleCustomerInfoUpdate`, Meta `AppEvents.shared.logEvent(.subscribe, ...)`) but with its own PostHog event names (§ Analytics).
  - `Wingman/Payment/SecondChanceOfferView.swift` — single-plan layout: headline ("Here's 50% off, just this once"), the discounted price, the *exact* renewal-price disclosure (Guideline 3.1.2 — reuse the disclosure-text pattern at `PaywallView.swift:369-371`), a primary CTA, and a dismiss (X) affordance that is always visible (this is explicitly a one-shot, skippable offer — never non-dismissible).
- **Files to modify**: [`Wingman/Payment/SubscriptionGateModifier.swift`](../Wingman/Payment/SubscriptionGateModifier.swift) — extend `SubscriptionGate` with a second `@State`/binding for the recovery-offer sheet, chained off the feature-gate paywall's `onDismiss`, gated on the eligibility checks from §4.2 step 2. [`Wingman/Payment/PaywallView.swift`](../Wingman/Payment/PaywallView.swift) — extend `PaywallSource` (or add a sibling enum used only by the new view, to avoid coupling it to `PaywallView`'s internals — **recommended**, since the two screens' analytics properties differ).
- **Backend changes**: none.
- **RevenueCat dashboard changes**: none beyond Phase 0.
- **App Store Connect changes**: none beyond Phase 0.
- **State management changes**: `SubscriptionGateModifier` now owns two chained sheet-presentation states instead of one — a targeted, contained change to a single small file.
- **Analytics events**: see §"Analytics" below — implemented here.
- **Edge cases**:
  - Eligibility check or Offering fetch is slow/fails right as the feature-gate paywall dismisses — do not block the dismiss animation; resolve the recovery-offer decision asynchronously and only present the sheet if/when it resolves affirmatively, with a short timeout (reuse the `PaywallTimeoutError` pattern from `PaywallViewModel`) so a hung network call can't leave the user in limbo.
  - User dismisses the feature-gate paywall, the recovery sheet is about to present, and in that instant `hasActiveSubscription` flips true from some other in-flight event (e.g. Family Sharing grant, a delayed webhook) — re-check `!hasActiveSubscription` immediately before presenting, not just at the start of the async chain.
  - User backgrounds the app between the two sheets — SwiftUI sheet chaining across a backgrounding event should be verified manually; if flaky, fall back to presenting the recovery sheet from `onDismiss` synchronously with a pre-fetched/cached eligibility result rather than an async chain.
- **Risks**: medium — this is the highest-regression-risk phase, since it touches the shared `SubscriptionGateModifier` used by four existing screens. Mitigate by keeping the new logic additive (wrapped in its own `if` branch) and testing all four existing call sites after the change, not just the new path.
- **Testing checklist**: all four feature-gate call sites (`HomeView`, `PracticeView`, `CourseDetailSheet`, `LogApproachBottomSheet`) still gate/dismiss correctly for a subscribed user (recovery sheet must never appear); dismiss-without-purchase on the feature-gate paywall correctly chains to the recovery offer exactly once per account; purchasing directly from the feature-gate paywall (not dismissing) must **not** trigger the recovery offer at all.

### Phase 4 — Analytics
Add these PostHog events, following the existing naming/property conventions (`source`, `time_on_screen_seconds` via the same `Analytics.elapsedSeconds` helper used in `PaywallView.swift`, `plan`, `product_id`):

| Event | Fired from | Key properties |
|---|---|---|
| `paywall_viewed` *(existing, unchanged)* | `PaywallView.onAppear` | `source: "onboarding" \| "featureGate"` |
| `paywall_dismissed` *(existing, unchanged)* | `PaywallView` X / Continue | `source`, `outcome: "dismissed_without_purchase" \| "purchased"` |
| `recovery_offer_viewed` *(new)* | `SecondChanceOfferView.onAppear`, guarded like `didLogPaywallView` | `discounted_price`, `renewal_price`, `product_id` |
| `recovery_offer_dismissed` *(new)* | X button on `SecondChanceOfferView` | `time_on_screen_seconds` |
| `recovery_offer_purchase_started` *(new)* | before the StoreKit call, mirroring `paywall_purchase_started` | `product_id` |
| `recovery_offer_purchased` *(new)* | on confirmed entitlement, mirroring `paywall_purchase_succeeded` | `product_id`, `discounted_price`, `is_anonymous: false` (always, by construction) |
| `recovery_offer_purchase_failed` *(new)* | non-cancel purchase error | `error_code` |
| `recovery_offer_not_eligible` *(new)* | when the gate in §4.2 step 2 resolves negatively — **important**: distinguishes "user already saw it" from "StoreKit says they're not intro-offer-eligible" from "offering failed to load," so the funnel isn't silently undercounted | `reason: "already_shown" \| "not_intro_eligible" \| "already_subscribed" \| "offering_unavailable"` |

**Derived PostHog Insights (no new events needed beyond the above, built as saved Insights/dashboards):**
- *Initial paywall viewed / dismissed*: filter existing `paywall_viewed`/`paywall_dismissed` by `source = "onboarding"`.
- *Feature paywall viewed / dismissed*: same events filtered by `source = "featureGate"`.
- *Revenue by source paywall*: join `paywall_purchase_succeeded` (existing) + `recovery_offer_purchased` (new) by `source`/event name, using PostHog's revenue tracking or a cross-referenced Stripe/RevenueCat export — RevenueCat's own dashboard (Charts ▸ Revenue by Offering/Product) is actually the more authoritative source for this specific metric since it reconciles against real App Store transactions, not client-side events; recommend using RC for revenue truth and PostHog for behavioral funnels.
- *Conversion rate by paywall*: `paywall_purchase_succeeded` (or `recovery_offer_purchased`) ÷ `paywall_viewed` (or `recovery_offer_viewed`), segmented by `source`.
- *Conversion rate by recovery offer specifically*: `recovery_offer_purchased` ÷ `recovery_offer_viewed`, and separately ÷ `paywall_dismissed{source=featureGate}` to see full-funnel "of everyone who bounced off paywall #2, how many convert on the recovery offer."

### Phase 5 — QA, staged rollout, and cleanup
- Full regression of the four existing feature-gate call sites + both onboarding paywall entry points (authenticated and anonymous-onboarded branches in `RootView`).
- Sandbox-account matrix testing (§7).
- Consider a soft rollout: ship the code paths but keep the `second_chance` Offering unpublished/empty in RevenueCat first (the `getSecondChancePackage() == nil` guard from Phase 1 means the feature silently no-ops), then flip it on for a small percentage once Apple's IAP review clears and telemetry confirms the gating logic is sound in production.

---

## 6. Risks and Edge Cases (consolidated)

- **False discount promise**: presenting "50% off" when StoreKit will actually charge full price (stale/failed eligibility check) is both a bad user experience and a Guideline 3.1.2 compliance risk. Mitigation: always gate presentation on a fresh `checkTrialOrIntroDiscountEligibility` result for the *new* product id, not an assumption based on "never subscribed."
- **Trial-then-lapsed users leaking through**: a user who started the 3-day trial, let it lapse without converting, and later reaches paywall #2 has already consumed their one intro-offer eligibility — StoreKit will correctly report them ineligible, and per the mitigation above they simply won't be shown the recovery offer (falls into `recovery_offer_not_eligible: "not_intro_eligible"`). This is correct behavior, not a bug, but should be called out to product/marketing so the "recovery offer" isn't assumed to reach 100% of paywall-#2 dismissers.
- **Subscription-group product proliferation**: adding a third product to the group is permanent surface area — Apple doesn't let you delete a product once it's had any transactions, and Settings ▸ Subscriptions will show whichever display name was set at purchase time forever for anyone who bought it. Get the display name right before submitting (Phase 0).
- **`SubscriptionGateModifier` blast radius**: it's shared by four screens; any regression here affects Daily Practice, Practice games, Course details, and Log Approach simultaneously. Treat Phase 3 as the highest-scrutiny code review of this project.
- **Reinstall / multi-device race**: the `user_metadata` mirror is best-effort (matches the existing `paywall_flow_completed` pattern's own documented limitation) — a user could theoretically see the offer twice if they dismiss it, force-quit before the mirror write completes, and immediately reinstall. Accepted risk, consistent with existing app behavior for the same class of flag.
- **DEBUG build gating**: `AuthManager.syncSubscriptionStatus()` hardcodes `hasActiveSubscription = true` in DEBUG (§1.10 note) — the recovery-offer gate (which depends on `!hasActiveSubscription`) will need a temporary local override to test in a debug build; document this clearly for QA so it isn't mistaken for a bug.
- **Anonymous-user path**: structurally unreachable today (paywall #2 requires account creation), but add the defensive `!isAnonymousUser` guard (§Phase 2) so a future onboarding-flow change can't silently expose it to anonymous users, who have no durable per-user persistence key to gate on.
- **App Store review timeline for the new IAP**: can desync from the app binary's own review; plan the ship date accordingly (§Phase 0).
- **Analytics undercounting**: without the `recovery_offer_not_eligible` event (§Phase 4), a drop in recovery-offer views could be misread as a UI bug when it's actually StoreKit correctly denying eligibility — instrument this explicitly rather than treating "no event fired" as sufficient signal.

---

## 7. Testing Strategy

**Sandbox account matrix** (App Store Connect sandbox testers, each fresh — Apple sandbox accounts remember redemption history just like production):
1. Fresh sandbox account, dismiss onboarding paywall, create account, dismiss feature-gate paywall → **expect** recovery offer shown, 50% price displayed, purchase succeeds at the discounted price.
2. Same as #1, but dismiss the recovery offer instead of purchasing → relaunch app, trigger another feature gate → **expect** feature-gate paywall shown again, recovery offer **not** shown again.
3. Fresh sandbox account, purchase directly from the feature-gate paywall (skip dismissal) → **expect** no recovery offer ever, entitlement active.
4. Fresh sandbox account, start the 3-day trial at the **onboarding** paywall, let it lapse in sandbox (sandbox trial durations are compressed — minutes, not days) without converting, then reach the feature-gate paywall and dismiss it → **expect** `checkTrialOrIntroDiscountEligibility` reports ineligible for the second-chance product, recovery offer is **not** shown (or shown without a discount claim — per §Phase 3, recommended: not shown at all).
5. Sandbox account that already purchased the discounted product once (in a prior test pass) → **expect** the "already shown" flag prevents re-presentation even before checking StoreKit eligibility.
6. Restore Purchases flow from the main paywall for an account that bought the discounted product → **expect** entitlement correctly restored (same entitlement id, so this should work for free, but verify explicitly since it's a new product id).
7. Reinstall the app mid-flow (after dismissing the recovery offer, before force-quitting) to test the best-effort `user_metadata` mirror timing (§6).
8. Regression: all four existing `.subscriptionGate` call sites, for both a subscribed and an unsubscribed test account, confirm no behavior change for a subscribed user (recovery chain must never fire) and correct existing dismiss/purchase behavior for an unsubscribed one.
9. Both onboarding-paywall entry points in `RootView` (authenticated branch and anonymous-onboarded branch) — confirm zero change in behavior (this paywall is explicitly out of scope for the new flow).
10. Airplane-mode / slow-network pass on the recovery-offer chain specifically — confirm it fails safe (no offer shown, no crash, feature-gate dismiss still completes) per the async-eligibility edge case in §5/Phase 3.
11. PostHog Live Events view: confirm every new event in §Phase 4 fires exactly once per occurrence, with correct properties, across the above scenarios.
12. Verify App Store Connect's required subscription-price/renewal disclosure text renders exactly as configured on the new product (Apple reviewers and Guideline 3.1.2 both check this) — visually diff against `PaywallView`'s existing disclosure text pattern.

---

## 8. Final Recommendation

Implement the recovery offer as a **second App Store Connect product** (`wingman_yearly_second_chance`) carrying its own **Pay-Up-Front introductory offer** (50% off, 1-year duration, reverting to standard price), surfaced through a **dedicated RevenueCat Offering** and a **new, minimal `SecondChanceOfferView`/`SecondChanceOfferViewModel`** pair, chained off the existing `SubscriptionGateModifier`'s dismiss path. Gate presentation on three independent checks — not subscribed, not previously shown (per-user `UserDefaults` + Supabase `user_metadata` mirror, replicating the app's existing `hasCompletedPaywallFlow` pattern exactly), and live StoreKit intro-offer eligibility — and never on any one of those alone.

**Why this over the alternatives:** Promotional Offers and Win-Back Offers are the "right" RevenueCat-native tools for discounting *existing or lapsed* subscribers, but this feature's entire population has never subscribed, which structurally rules both out (§2, §3) — using them here would either not work (StoreKit would reject/ignore the offer) or require infrastructure (server-side signing) this use case doesn't need. A second Introductory Offer on a second product is the only mechanism Apple actually allows for a never-subscribed user, and it happens to be the simplest to implement: no signing server, no new entitlement, and eligibility checking that reuses code already in `PaywallViewModel` today.

**Why this minimizes technical debt:** every new piece of state (the "already shown" flag) and every new analytics event follows a pattern that already exists and is already proven correct in this codebase (`hasCompletedPaywallFlow` / `paywall_*` PostHog events) — a future engineer reading `AuthManager.swift` or `PaywallView.swift`-adjacent code will recognize the shape immediately. The one deliberate divergence — a new view instead of extending `PaywallView` — is chosen specifically to *reduce* debt: it keeps the existing, working, two-plan paywall untouched and isolates all new complexity in new files, rather than adding a third conditional dimension to an already-complex, actively-used view. The architecture also leaves a clean seam for future experimentation (different discount percentages, different Offerings per cohort) via RevenueCat Targeting without any further client changes, should the team want to A/B test this later.
