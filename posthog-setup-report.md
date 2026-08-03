# PostHog post-wizard report

Wingman already had a deep PostHog integration — 56 call sites, session replay, feature flags, an `environment` super-property, and an `Analytics` façade in [Analytics.swift](Wingman/Util/Analytics.swift). This pass was therefore **supplemental**: nothing existing was rewritten, no event was renamed, and no dashboard that depends on the current events was disturbed. 15 new events were added in the four areas that had no instrumentation at all.

## What was already covered (left untouched)

Onboarding (`onboarding_started` / `_step_viewed` / `_completed`), auth (`user_signed_up`, `user_logged_in`, `user_logged_out`, `account_linked`, `account_ask_skipped`, `session_invalidated`), the paywall (`paywall_viewed`, `paywall_purchase_started` / `_succeeded` / `_failed`, `paywall_offerings_failed`), the second-chance recovery offer, the first-run walkthrough, lessons and lesson quizzes, practice scenarios, and daily challenges.

## The four gaps this pass closed

**1. The core value action was invisible.** Every existing event measured content *consumption* — lessons read, scenarios played, questions answered. Logging an approach is the thing the app is actually for, and it emitted nothing. `approach_logged` is now the event to build activation and retention cohorts on.

**2. Churn was invisible in both forms.** Purchases were captured on the way in and nothing on the way out, so no insight could separate a retained subscriber from a lapsed one. `subscription_expired` now fires on the entitlement's true→false edge and carries `churn_type`, which splits *voluntary* cancellation from *billing failure* — RevenueCat already distinguishes these via `unsubscribeDetectedAt` / `billingIssueDetectedAt`, and they need opposite responses. Account deletion is now captured at both ends.

**3. The paywall had no visible upstream.** `paywall_viewed` fires but carries no trigger, so a lesson tap that hits the subscription gate was indistinguishable from every other entry point. `lesson_gate_blocked` makes the lesson→purchase funnel measurable. `course_locked_encountered` separately captures the *progression* gate, which is a content-sequencing problem that no pricing change fixes.

**4. Two screens sat in a blind spot.** The rating prompt and referral screens sit between `onboarding_completed` and `paywall_viewed`. Anyone dropping there never reaches pricing, but the loss landed in the gap between those two events and read as paywall drop-off — pointing optimisation at the wrong screen.

## Events added

| Event | Description | File |
|---|---|---|
| `approach_logged` | A new approach log is saved — the app's core value action. Fires on new entries only; an edit is a correction to one already counted. Properties: `approach_level`, `level_name`, `anxiety_level`, `has_notes`, `notes_length`, `total_approaches`, `is_first_approach`. | [LogApproachViewModel.swift](Wingman/LogApproch/LogApproachViewModel.swift) |
| `approach_log_failed` | The Supabase write threw. The user only ever sees "Failed to save. Please try again.", so an outage and an expired session were indistinguishable from a user who never logged anything. Properties: `is_edit`, `approach_level`, `error_message`. | [LogApproachViewModel.swift](Wingman/LogApproch/LogApproachViewModel.swift) |
| `approach_deleted` | The negative counterpart to `approach_logged`. A rising delete rate is either a trust problem with the log or regret about what was written. Properties: `approach_level`, `days_since_logged`, `remaining_total`. | [ApproachService.swift](Wingman/Profile/ApproachService.swift) |
| `course_locked_encountered` | A user lands in a progression-locked course's preview mode. One-shot per presentation. Properties: `course_id`, `course_title`, `category_id`, `previous_course_title`. | [CourseDetailSheet.swift](Wingman/Courses/CourseDetailSheet.swift) |
| `lesson_gate_blocked` | The exact tap where a free user hits the subscription gate instead of the lesson. Properties: `lesson_id`, `lesson_title`, `course_id`, `course_title`, `free_lesson_already_claimed`. | [CourseDetailSheet.swift](Wingman/Courses/CourseDetailSheet.swift) |
| `subscription_expired` | Entitlement active→inactive. Properties: `churn_type` (`voluntary` / `billing_issue` / `lapsed`), `was_trial`, `product_identifier`, `days_subscribed`, `expiry_date`, `is_sandbox`. | [SubscriptionManager.swift](Wingman/Payment/SubscriptionManager.swift) |
| `account_deletion_started` | Fired client-side the moment Delete is confirmed, before the request leaves. Properties: `is_guest_session`, `total_approaches`, `is_subscribed`. | [SettingsSheet.swift](Wingman/Profile/SettingsSheet.swift) |
| `account_deletion_completed` | **Server-side.** The definitive churn event. Properties: `deleted_user_id`, `tables_with_errors`, `had_partial_errors`, `used_fallback_distinct_id`. | [delete-user-account/index.ts](supabase/functions/delete-user-account/index.ts) |
| `account_deletion_failed` | **Server-side.** Properties: `failed_step`, `tables_with_errors`, `error_message`, `deleted_user_id`. | [delete-user-account/index.ts](supabase/functions/delete-user-account/index.ts) |
| `purchases_restored` | Restore found an active entitlement — separates a returning subscriber from a new purchase. Properties: `source`, `entitlement_expiry_date`. | [SettingsSheet.swift](Wingman/Profile/SettingsSheet.swift) |
| `purchases_restore_failed` | Restore found nothing, or threw. A paying user who lands here reads as churn while actually being a support ticket. Properties: `reason` (`no_active_entitlement` / `error`), `source`, `error_message`. | [SettingsSheet.swift](Wingman/Profile/SettingsSheet.swift) |
| `notification_permission_result` | Outcome of the authorization prompt. `was_prompted` distinguishes a genuine first prompt from a re-read of a standing answer. Properties: `granted`, `was_prompted`, `prior_status`, `source`, `had_error`. | [NotificationManager.swift](Wingman/Util/NotificationManager.swift) |
| `daily_reading_goal_set` | A commitment signal, and the only read on whether the 10-minute default is right. Properties: `goal_minutes`, `previous_goal_minutes`, `changed`, `notifications_enabled`. | [DailyReadingGoalSheet.swift](Wingman/Profile/DailyReadingGoalSheet.swift) |
| `rating_prompt_continued` | Continue tapped on the pre-paywall rating screen. Properties: `time_on_screen_seconds`. | [RatingPromptView.swift](Wingman/Rating/RatingPromptView.swift) |
| `referral_step_completed` | Submit or skip on the referral screen. The code itself is user-entered free text and is deliberately not sent. Properties: `action` (`submitted` / `skipped`), `code_length`. | [ReferralView.swift](Wingman/Referral/ReferralView.swift) |

## Error tracking

A new `Analytics.captureError(_:context:_:)` helper routes to the SDK's `captureException`, so these land in PostHog's **Errors** view and group with each other rather than becoming custom events nobody builds an insight on. Added at six API boundaries: `approach_save`, `approach_delete`, `approach_fetch`, `purchases_restore`, `account_deletion`, and `notification_permission`.

Note that `$exception` **autocapture** for unhandled crashes is gated on remote config, not a local flag — enable it under *Error tracking* in your PostHog project settings if you want it. The explicit calls above work regardless.

## Client↔server identity correlation

The edge function's events would have landed on the wrong person without a fix. It only knows the Supabase user id, which Postgres returns as a **lowercase** UUID, while the iOS client calls `identify()` with Swift's `uuidString`, which is **uppercase**. Letting the server derive its own `distinct_id` would have forked a second PostHog person on every single deletion, and the churn event would never have joined to the user who caused it.

[AuthManager.swift](Wingman/Auth/AuthManager.swift) now sends `X-POSTHOG-DISTINCT-ID` and `X-POSTHOG-SESSION-ID` on the deletion request, and the function uses them (falling back to the raw user id only if absent, flagged as `used_fallback_distinct_id`). The session header also stitches the server event into the client's session replay.

## Two decisions worth knowing about

**The iOS token stayed in `Constants.swift`, deliberately.** The standard guidance is to read PostHog keys from Xcode scheme environment variables. That is correct for a sample app and **wrong for a shipping one**: scheme env vars only exist when launching from Xcode, so a TestFlight or App Store build would find nothing and the `fatalError` in that pattern would be a crash-on-launch for every real user. A PostHog project token is a publishable client key that ships inside the binary regardless, so there is nothing to protect by moving it. The existing arrangement is right and was left alone.

**The server-side keys are genuinely secret-managed**, because there the env-var approach works properly:

```bash
supabase secrets set POSTHOG_PROJECT_TOKEN=phc_nHqVpjSQBTE4UBm2poiehcb4de92uJirKRMed8nhdurH POSTHOG_HOST=https://us.i.posthog.com
```

**Until you run that, the two server-side events silently no-op** — `capturePostHog` logs a warning and returns. That is intentional: an analytics outage or a missing secret must never turn a successful account deletion into a 500 the user sees, or leave someone believing their data survived when it did not.

Redeploy the function afterwards:

```bash
supabase functions deploy delete-user-account
```

## Verification

`xcodebuild -scheme Wingman` succeeds with no new warnings in any edited file. `deno check` on the edge function reports 3 errors — all three are **pre-existing** (`.message` read off an `unknown`-typed caught value in the original response-building code) and confirmed present on the unmodified file; the added code narrows its errors correctly and introduces none.

## Next steps

**No dashboard or insights were created.** The PostHog MCP server is not connected to this session, so I had no way to create them — and I'd rather tell you that than hand you links that don't resolve. Connect the PostHog MCP and ask me to build the "Analytics basics" dashboard, or create these five by hand:

1. **Lesson → purchase funnel** — `lesson_gate_blocked` → `paywall_viewed` → `paywall_purchase_succeeded`. The conversion path that was unmeasurable before this pass.
2. **Churn breakdown** — `subscription_expired` as a trend, broken down by `churn_type`. Voluntary cancellation and billing failure need opposite responses; this is the only chart that separates them.
3. **Activation** — `approach_logged` where `is_first_approach = true`, as a trend, plus retention of users who fire it vs. users who never do.
4. **Onboarding → pricing drop-off** — `onboarding_completed` → `rating_prompt_continued` → `referral_step_completed` → `paywall_viewed`. Locates which of the two interstitial screens is actually costing you.
5. **Account deletion funnel** — `account_deletion_started` → `account_deletion_completed`. The gap is deletions that failed or died in flight; watch for `failed_step = auth_user`, which means the user's content was destroyed but their login survived.

Filter every insight on `environment = "prod"` — the app registers that super-property at launch and simulator traffic carries `dev`.

### Agent skill

There is an agent skill folder at `.claude/skills/integration-swift/`. You can use that context for further agent development with Claude Code; it helps ensure the model uses up-to-date approaches for integrating PostHog.
