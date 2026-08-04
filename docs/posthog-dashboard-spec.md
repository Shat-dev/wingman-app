# PostHog dashboard spec — "Wingman core metrics"

Executable build sheet for the five insights described in
[posthog-setup-report.md](../posthog-setup-report.md). Every event and property
below was verified against the source on 2026-08-03 — names here are what the
code actually emits, not what the report's prose says.

## Global

- **Dashboard name:** Wingman core metrics
- **Filter on every insight:** `environment = "prod"`.
  Registered at [WingmanApp.swift:477](../Wingman/WingmanApp.swift:477) as
  `dev` in DEBUG and `prod` otherwise. Without this filter every number is
  polluted by simulator traffic.
- **Default date range:** last 30 days.

---

## 1. Lesson → purchase funnel

**Type:** Funnel · **Steps:**

1. `lesson_gate_blocked`
2. `paywall_viewed` — **filter `source = "featureGate"`**
3. `paywall_purchase_succeeded`

**Correction vs. the report.** The report says `paywall_viewed` "carries no
trigger". That is stale — it carries `source`
([PaywallView.swift:543](../Wingman/Payment/PaywallView.swift:543)) with values
from `PaywallSource`: `onboarding`, `featureGate`, `postDemo`. Without the step-2
filter, an onboarding paywall view that merely happens to follow a lesson gate
counts as a conversion this funnel did not cause.

`paywall_viewed` fires from exactly one site and is guarded against SwiftUI
re-mounts by `didLogPaywallView`, so no dedup handling is needed.

---

## 2. Churn breakdown

**Type:** Trend · **Event:** `subscription_expired` · **Breakdown:** `churn_type`

Values, from [SubscriptionManager.swift:245-251](../Wingman/Payment/SubscriptionManager.swift:245):

| Value | Meaning |
|---|---|
| `voluntary` | User cancelled (`unsubscribeDetectedAt`) |
| `billing_issue` | Payment failed (`billingIssueDetectedAt`) |
| `lapsed` | Neither flag — expired without a signal |

`billing_issue` is recoverable with a dunning email; `voluntary` is not. That
split is the entire point of this chart.

Consider a second series filtered `is_sandbox = false` — sandbox renewals expire
on an accelerated clock and will otherwise dominate the count.

---

## 3. Activation

**Two insights.**

**3a. First approaches** — Trend · `approach_logged` filtered
`is_first_approach = true`
([LogApproachViewModel.swift:167](../Wingman/LogApproch/LogApproachViewModel.swift:167)).

**3b. Activation retention** — Retention · cohortising event `approach_logged`,
returning event `approach_logged`. This is the chart that answers whether
logging an approach is the habit that retains, which is the premise the whole
instrumentation pass rests on.

---

## 4. Onboarding → pricing drop-off

**Type:** Funnel · **Steps:**

1. `onboarding_completed`
2. `rating_prompt_continued`
3. `referral_step_completed`
4. `paywall_viewed` — **filter `source = "onboarding"`**

**Correction vs. the report.** Same `source` issue as funnel 1 — step 4 must be
scoped to `onboarding` or a later feature-gate paywall view backfills the step
and hides the interstitial drop-off this funnel exists to find.

**Note on step 1.** `onboarding_completed` fires once, property-less, at
[OnboardingView.swift:360](../Wingman/Onboarding/OnboardingView.swift:360). Five
other repo hits for that string are Supabase `user_metadata` writes in
`AuthManager` / `LoadingScreen` and are not analytics events — do not build a
step on those.

**Note on step 3.** `referral_step_completed` fires on *both* submit and skip,
carrying `action` = `submitted` | `skipped`
([ReferralView.swift:36,60](../Wingman/Referral/ReferralView.swift:36)). Leave it
unfiltered here — the funnel measures traversal, not referral success. Break
down by `action` only if you want the sub-question.

---

## 5. Account deletion funnel

**Type:** Funnel · **Steps:**

1. `account_deletion_started`
2. `account_deletion_completed`

The gap is deletions that failed or died in flight. Pair with a Trend on
`account_deletion_failed` broken down by `failed_step`, and watch for
`failed_step = "auth_user"` — that state means the user's content was destroyed
but their login survived.

**Prerequisite.** Steps 2 and 3 are server-side
([index.ts:345](../supabase/functions/delete-user-account/index.ts:345)) and
**silently no-op until the edge function secrets are set**:

```bash
supabase secrets set POSTHOG_PROJECT_TOKEN=<phc_token> POSTHOG_HOST=https://us.i.posthog.com
supabase functions deploy delete-user-account
```

Until then this funnel shows 100% drop-off at step 1 — an artifact, not churn.
