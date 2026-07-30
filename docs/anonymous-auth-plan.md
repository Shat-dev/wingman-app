# Anonymous Auth — Implementation Plan

Companion to `demo-then-wall-plan.md`. **Supersedes** that document's §1 anonymous
branch, the "Approach logging — free, no change" claim in §4, and parts of §0.
Phases 1-3 of that plan survive intact — see "Effect on phases 1-3" below.

Verified against branch `Shat`. Line numbers from state at time of writing.

## The change in one line

Stop treating "anonymous" as a local UserDefaults concept with no backend
identity, and make it a real Supabase `auth.users` row (`is_anonymous = true`).
The account stops being a wall and becomes an upgrade.

```
Landing
  → "Create Account" → unchanged, real account from the start
  → "Skip for now"   → signInAnonymously()   ← real user_id from here on
      → onboarding quiz → RatingPromptView → Paywall #1
          → purchased  → post-purchase account ask (SKIPPABLE) → MainTabView
          → dismissed  → MainTabView, demo mode, still anonymous
              → walkthrough → post-demo ask
                  → purchased → post-purchase account ask (SKIPPABLE)
                  → dismissed → into the app, anonymous indefinitely
                      → Profile prompt, triggered at ~5 logged approaches
```

The forced post-paywall `AuthView` disappears entirely.

---

## 0. Why this works at all

`SupabaseManager.currentUserId` is `client.auth.currentUser?.id`
(`SupabaseManager.swift:48`). Every user-scoped table is keyed on it, with
`user_id UUID NOT NULL REFERENCES auth.users(id)` and RLS policies of the form
`auth.uid() = user_id` (schema reference, `SupabaseManager.swift:88-132`).

A Supabase anonymous user is a **real row in `auth.users`**. It therefore
satisfies the foreign key, satisfies every RLS policy unchanged, and produces a
non-nil `currentUserId`. All 14 hard blockers below start working with **no
change to any of them**:

| File | Lines | Blocks |
|---|---|---|
| `PracticeGame/PracticeServiceProtocol.swift` | 107 | `fetchPractices()` throws `.notAuthenticated` — scenario list never loads |
| `PracticeGame/PracticeGame.swift` | 163, 176 | scenario progress + completion writes |
| `Lesson/LessonDataService.swift` | 281 | lesson completion writes |
| `Profile/ApproachService.swift` | 64, 102, 123 | fetch / insert / update approach logs |
| `DailyPractice/DailyPracticeServiceProtocol.swift` | 128, 172, 215, 266, 320, 352 | all daily-practice reads/writes |
| `DailyPractice/StreakStore.swift` | 130 | streak sync |

Two soft sites fall back to the literal string `"anonymous"` as a cache key and
should be revisited but do not block:
`PracticeGame/PracticeViewModel.swift:121`, `Lesson/LessonDataService.swift:213`.

**Correction to `demo-then-wall-plan.md` §4.** That document states "Approach
logging — free, no change. Already shipped." True only because every user who
reaches `MainTabView` today is authenticated. Without a session all three
`ApproachService` guards bail and the §3 profile-handoff beat hands the user a
feature that silently does nothing. Anonymous auth is a **prerequisite** for the
demo, not an optimisation alongside it.

---

## Phase A — Preconditions (do these before writing code)

None of these are code. All of them can invalidate the plan.

1. ~~**Enable anonymous sign-ins** in the Supabase dashboard.~~ **DONE and
   verified live, 2026-07-30.** `POST /auth/v1/signup` against
   `bnckmgnysfliiypvxxii` returns a session with `is_anonymous: true` and
   `role: authenticated` (both in the user object and in the JWT claims).

   The RLS consequences below were then **probed empirically**, not inferred:

   | Probe | Result |
   |---|---|
   | Guest session reads `questions` | `200`, rows returned |
   | Publishable key only (anon role) reads `questions` | `200` but **empty** — correctly blocked |
   | Publishable key only reads `scenarios`, `scenario_screens` | **rows returned — no account of any kind needed** |
   | Guest inserts `approach_logs` with own `user_id` | `201` |
   | Guest inserts with a **forged** `user_id` | **`403`, RLS violation** |
   | Guest selects `approach_logs` | sees **1 of 9** rows — only its own |

   Conclusions, now facts rather than assumptions:

   - **The write model is safe.** A guest can create its own rows and cannot
     forge or read another user's. Every `with_check = (auth.uid() = user_id)`
     holds under the `authenticated` role.
   - **Content exposure is pre-existing and unchanged by this work.**
     `scenarios` / `scenario_screens` are readable with just the publishable key
     hardcoded at `SupabaseManager.swift:22`. That was true before anonymous
     sign-ins and is unaffected by them.
   - **`questions` (757 rows) is the only real delta.** Blocked for `anon`,
     readable for a guest session. Accepted knowingly. **Do not "fix" it with an
     `is_anonymous` exclusion** — under this plan a user can purchase while still
     a guest, and guest subscribers legitimately need daily practice.
   - **User-scoped tables are unaffected.** All use `auth.uid() = user_id`, and
     every INSERT policy carries `with_check = (auth.uid() = user_id)`. A guest
     cannot read or forge another user's rows.
   - **Content tables were already open.** `scenarios`, `scenario_screens`,
     `screen_options`, `practices`, `practice_details`, `practice_steps` all have
     `{public}` policies with `qual = true`. A Postgres policy granted to
     `public` applies to *every* role including `anon`, so these are readable
     with the publishable key hardcoded at `SupabaseManager.swift:22`. Anonymous
     sign-in changed nothing here.
   - **One real delta: `questions`** (757 rows, the daily-practice bank) is
     `{authenticated}` only, so it becomes reachable by anyone who calls
     `signInAnonymously()`. Accepted knowingly. **Do not "fix" this with an
     `is_anonymous` exclusion** — under this plan a user can purchase while still
     a guest, and guest subscribers legitimately need daily practice.
2. ~~**Confirm `signInAnonymously()` emits `.signedIn`.**~~ **VERIFIED — it does.**
   Read from the pinned SDK source (supabase-swift 2.x,
   `Sources/Auth/AuthClient.swift`): `signInAnonymously()` delegates to
   `_signIn(request:)`, which at **:452-453** calls `sessionManager.update(session)`
   and then `eventEmitter.emit(.signedIn, session: session)`.

   So the handler at `AuthManager.swift:317` runs for guest sessions, and
   `checkUserFreeDemoStatus` / `checkUserPostDemoWallStatus` (`:343-344`) fire
   normally. **Phase 1-3 flags load correctly — the plan's shape is safe.**

   **Second-order consequence, and it upgrades Phase C from tidy-up to
   prerequisite:** the same handler reaches
   `if self.isAnonymousUser { await self.syncAnonymousDataToBackend() }` at
   `:333-336`. That will now fire on *every guest session creation*. For a fresh
   guest it is close to a no-op (nothing to transfer, no RevenueCat purchase to
   link), but it does call `anonymousManager.clearAllData()` (`:933`). Gate it
   before Phase B ships, not after.
3. **Test keychain survival across delete-and-reinstall.** **PARTIALLY ANSWERED
   from SDK source; the rest cannot be tested on a simulator.**

   The SDK stores the session via `KeychainLocalStorage`, service
   `"supabase.gotrue.swift"`, no access group
   (`Sources/Auth/Storage/KeychainLocalStorage.swift:8-9`), with
   `kSecAttrAccessibleAfterFirstUnlock` and **no `kSecAttrSynchronizable`**
   (`Sources/Auth/Internal/Keychain.swift:85`).

   - Not iCloud-Keychain synced → a guest session does **not** appear on a
     second device in real time.
   - But `AfterFirstUnlock` *without* `ThisDeviceOnly` means the item **is**
     included in encrypted backups and device-to-device transfers. A user doing a
     normal iPhone→iPhone migration or encrypted restore **keeps** their guest
     session and progress.
   - So the loss case is narrower than first stated in this plan: fresh setups,
     Android→iOS, and unencrypted/no-backup users — not every phone upgrade.

   The delete-and-reinstall question still needs a **physical device**. Simulator
   keychain is a shared per-simulator database with different uninstall
   semantics, so a simulator result would be misleading either way. It also
   needs item 1 done first.
4. ~~**Decide the merge policy**~~ **DECIDED (2026-07-30): not building one.**
   The collision (guest with progress links an Apple ID that already has an
   account) was judged too rare to design for. Accepted.

   Residual requirement, which is not the same thing: `linkIdentity` will still
   throw `identity_already_exists` when it does happen, and the screen must not
   dead-end. Catch it, show "This Apple ID already has an account — sign in
   instead? Your current progress won't carry over," and offer sign-in or
   cancel. That is error handling, not a merge flow.
5. **Decide abuse controls.** Anonymous sign-in lets anyone mint unlimited rows.
   Rate limiting / captcha, plus a cleanup job for stale anonymous users. Also:
   every user-count query and dashboard now needs an `is_anonymous` filter.

---

## Phase B — Session bootstrap and the migration guard

**IMPLEMENTED and verified on simulator, 2026-07-30.** See "Verification" at the
end of this section for the three tests and the defect they caught.

**This is the highest-risk phase in the plan. Everything else is mechanical.**

### The failure to design against

`restoreSessionGracefully()` (`AuthManager.swift:637`) reads `client.auth.session`
and on failure sets `isAuthenticated = false`. Today that routes an existing user
to `AuthView(mode: .login)` — recoverable, data intact.

If "no session → create anonymous session" is implemented naively, that same
transient failure mints a **new anonymous user for an existing paying customer**:

- new `user_id` → approach logs, progress and streak all invisible
- `logIn(newAnonymousId)` is an identified→identified switch, so the entitlement
  stays stranded on the old id (`RevenueCatManager.swift:76-84` documents exactly
  this stranding mechanic) → the paying user is also locked out of what they paid for

`SupabaseManager.swift:34` sets `autoRefreshToken: false`, so expired-token
handling is manual and transient nil sessions are *more* likely than the happy
path suggests.

### The rule

> Create an anonymous session **only** on a definitive "no session has ever
> existed on this device". **Never** on a session-read error.

Implementation shape:

- A persisted marker (`has_ever_had_session`, global — not per-user) written the
  first time any session is established, anonymous or real. Never cleared except
  on explicit sign-out + account deletion.
- Anonymous bootstrap runs only when that marker is absent **and** the session
  read returned a clean "no session" rather than throwing.
- On a session-read *error* with the marker present: keep today's behaviour —
  show the login screen. A returning user seeing a login screen is a recoverable
  annoyance; a returning user silently handed a fresh identity is data loss.
- Offline at first launch with no marker: do **not** create a local placeholder
  identity. Anonymous sign-in requires network. Defer bootstrap and let the app
  show its existing offline treatment, or the placeholder will diverge from the
  real row later.

### Where bootstrap is called

`LandingView.swift:130` already calls `authManager.startAnonymousOnboarding()`
on "Skip for now". That is the natural hook — it keeps the Landing choice
intact and means users who tap "Create Account" never get an anonymous row.

### Existing users

Safe by construction: everyone with data today has a real account (the anonymous
branch never reached `MainTabView`), so their session restores normally and the
marker is present. Confirmed against the live database — **119 users, 0 with
`is_anonymous = true`**. The guard above is the entire safety story: get it wrong
and this phase is a data-loss incident, get it right and existing users see
nothing.

### Verification (simulator, iPhone 17 Pro Max, 2026-07-30)

Three DEBUG launch arguments were added to make this testable without driving
the funnel by hand, following the `-forceFreeDemoCompleted` pattern from
phases 1-3: `-guestSessionsEnabled`, `-forceGuestBootstrap`,
`-forceHasEverHadSession`.

| Test | Setup | Expected | Result |
|---|---|---|---|
| **1 — the guard** | marker pre-set, flag on, bootstrap forced | REFUSE | ✅ `Guest bootstrap REFUSED — this device has had a session before` |
| **2 — happy path** | clean install, flag on, bootstrap forced | one guest session, routing unchanged | ✅ session created, `isGuestSession false → true`, RootView stayed on Landing throughout |
| **3 — relaunch** | existing guest session, bootstrap forced again | no second user | ✅ `Guest bootstrap skipped — a session already exists`, same user id |

Database after all three: **exactly one** `is_anonymous` row, matching the id in
the logs. No duplicates from any retry path.

#### Defect found by test 2, now fixed

The first run of test 2 logged `Guest bootstrap skipped — flag disabled` on a
device that should have bootstrapped. Cause: `FeatureFlags` is populated from a
**detached** task (PostHog SDK setup, `WingmanApp.swift`), so a bootstrap running
early reads `guestSessionsEnabled == false` — indistinguishable from the flag
genuinely being off. In production this is a real race: a user who taps "Skip for
now" before `/decide` answers would silently never get a session, with nothing to
retry it.

Two changes:

1. **Guard order.** The three correctness guards (in-flight, session exists,
   `hasEverHadSession`) now run *before* the flag check and never arm a retry —
   no later change of circumstances can make bootstrap correct for those. Only
   the two "not right now" guards (flag, offline) arm `guestBootstrapPending`.
2. **`observeFeatureFlagsForGuestBootstrap()`** retries a deferred bootstrap when
   `guestSessionsEnabled` flips true, mirroring the existing network-restored
   observer. Also covers flipping the flag on mid-session operationally.

Test 2's passing run shows the full corrected sequence: deferred → flags load →
`Guest sessions enabled — retrying deferred bootstrap` → session created.

---

## Phase C — Naming collision

**IMPLEMENTED 2026-07-30.**

`AuthManager.isAnonymousUser` meant "local UserDefaults anonymous, no Supabase
session". Phase B introduced a second, different notion: a Supabase session that
is itself anonymous (`is_anonymous = true`). Two things sharing one name is how
`.signedIn` for a guest session came to trigger the whole anonymous→permanent
transfer.

The split, now in code:

| Symbol | Meaning |
|---|---|
| `isLegacyAnonymousUser` | onboarding with **no** Supabase session; local-only (UserDefaults + `AnonymousUserManager`) |
| `isGuestSession` | a real `auth.users` row with `is_anonymous = true`, holding a live session |

Renamed across 6 files: `AuthManager`, `WingmanApp`, `SubscriptionGateModifier`,
`PaywallViewModel`, `LoadingScreen`, `OnboardingView`.

**The backing UserDefaults key is deliberately still the string
`"isAnonymousUser"`.** Renaming the key would strand every user currently
mid-onboarding: they would read `false` on next launch and be routed as if they
had never started. The Swift symbol and the storage key are intentionally
different, and that is called out at the property.

The "legacy" prefix is load-bearing — this flag and the `AnonymousUserManager`
mirror are retired in Phase E. It marks them as not-for-new-work.

### Also fixed here — stale `isGuestSession`

Review of Phase B found `isGuestSession` was never cleared when a guest signed
into a real account. Supabase emits `.signedIn` for the new session, not
`.signedOut`, so the flag stayed `true` for the rest of the process. Latent in
Phase B (nothing routes on it) but a live bug the moment Phase E does. Now
cleared in all three non-guest paths: `.signedIn`, `.initialSession`, and
`restoreSessionGracefully`.

### Regression after the rename

Phase B's tests 1 and 2 re-run against the renamed code: guard still REFUSES,
happy path still defers → retries on flag load → creates exactly one session,
RootView still shows Landing throughout.

**Incidental finding:** on the **simulator**, the Supabase session survived
`simctl uninstall` — the first re-run hit `skipped — a session already exists`
instead of the intended guard. `xcrun simctl keychain <udid> reset` is required
between clean-state tests. This is a simulator observation and says nothing
reliable about device behaviour (see Phase A.3) — do not treat it as the answer
to the delete-and-reinstall question.

---

## Phase D — Identity linking + RevenueCat identity

**IMPLEMENTED 2026-07-30, with a correction to this plan's scope.**

### Correction: linking was an unstated prerequisite, not a later phase

This section originally claimed that "`linkIdentity` keeps the same Supabase row
and the same `user_id`", so RevenueCat needs exactly one `logIn`. That premise
was **not true of the code as written**. Both sign-in paths called
`client.auth.signInWithIdToken` (`AuthManager.swift`, Google and Apple), which
creates a *different* `auth.users` row and abandons the guest.

Implementing the RevenueCat change alone would therefore have **introduced** the
exact bug this phase claims to delete:

1. guest session → `logIn(guestId)` → RevenueCat becomes *identified*
2. purchase lands on `guestId`
3. user signs up → `signInWithIdToken` → **new** `realId`
4. `logIn(realId)` → identified→identified → RevenueCat does not transfer →
   **purchase stranded**, which is precisely the failure documented at
   `RevenueCatManager.swift:76-84`

So linking moved into Phase D as its first half. `Purchases.configure()` still
runs without an appUserID — that warning is about `configure`, not `logIn`.

### Linking

`supabase-swift` provides **`linkIdentityWithIdToken(credentials:)`**
(`AuthClient.swift:1213`), which attaches a provider to the *current* session's
user via `POST /token?grant_type=id_token` with `link_identity` set. Native — no
web redirect. The id is preserved, so every FK, RLS row and RevenueCat
entitlement keyed on it survives.

`AuthManager.authenticate(with:)` is now the single entry point for both
providers: link when `isGuestSession`, plain `signInWithIdToken` otherwise.

**Critical detail: linking emits `.userUpdated`, NOT `.signedIn`**
(`AuthClient.swift:1230-1231`). The existing `.userUpdated` handler only
refreshed `currentUser`, so without work a linked user would keep
`isGuestSession == true` and `isAuthenticated == false` — a real account the app
still treated as a guest. `.userUpdated` now performs the guest→permanent
promotion: clears `isGuestSession`, sets `isAuthenticated`, and runs the six
per-user state loads the guest branches skip. RevenueCat and PostHog need no
second call, because the id did not change.

`identity_already_exists` surfaces as `AuthManager.AccountLinkError` and is
caught in both sign-in flows, so the screen shows a clear message instead of
dead-ending (Phase A.4 decision: no merge flow, but no trap either).

### RevenueCat

`adoptGuestIdentity(_:)` runs on every guest-session path (`.signedIn`,
`.initialSession`, cached restore) and is idempotent via an `appUserID` check.

Verified on simulator: RevenueCat starts at
`$RCAnonymousID:4fa5acf7…`, then on guest session creation logs
`🆔 Adopting guest identity…` followed by
`🔑 RevenueCat: User logged in with ID: 486EE20A-…`. That is the
anonymous→identified transition — the one RevenueCat transfers correctly — and
it is now the only `logIn` in a user's lifetime. `isAuthenticated` never flipped,
so Phase B's "routing unchanged" property still holds.

### Consequences (unchanged from the original plan)

The comment at `RevenueCatManager.swift:68-88` warns against assigning an
appUserID pre-signup, because RC only auto-transfers purchases when logging in
*from* an anonymous `$RCAnonymousID`, and identified→identified strands the
purchase.

**That risk disappears here**, because `linkIdentity` keeps the same Supabase row
and the same `user_id`:

- anonymous session created → `logIn(supabaseUserId)` **once**
- purchase lands on that id
- account creation links an identity → **id does not change** → nothing to transfer

There is never a second `logIn`, so the identified→identified case cannot arise.

Consequences:

- `Purchases.configure()` stays **without** an appUserID — the warning in point 1
  of that comment is about `configure`, not `logIn`. Do not change it.
- `linkAnonymousPurchase` (`RevenueCatManager.swift:140-170`) becomes dead code.
- The `🚨 RevenueCat purchase linking FAILED — paying user may be gated` branch
  (`AuthManager.swift:1005`) becomes unreachable. This is the scariest revenue
  failure path in the app today.
- The analytics gap that comment knowingly accepts closes: RC and PostHog can
  share the Supabase user id from first launch, so a pre-signup purchase finally
  stitches to the onboarding and paywall events that produced it. Update the
  identify call at `WingmanApp.swift:442`.

Do not delete the dead code in the same commit as the behaviour change. Land the
behaviour, verify entitlements on real purchases, then remove.

---

## Phase E — Remove the wall, collapse the routing

**IMPLEMENTED and verified on the production path (no launch flags), 2026-07-30.**

### What landed

- **`AuthManager.hasSession`** (`isAuthenticated || isGuestSession`) is what
  RootView now asks. `isAuthenticated` stays narrower — "has a **permanent**
  account" — because that is the input Phase F's account ask needs.
- **RootView's main branch keys off `hasSession`**, so guests route through the
  ordinary flow: questions → rating → paywall → demo → gated app.
- **Guests now run the per-user state loads** (`loadGuestUserState`). Phase B
  skipped these because guests could not reach the app; now the flags decide
  where they land, and skipping would restart onboarding every launch.
- **`completeAnonymousOnboarding()` persists against the guest's own id.**
  `checkUserQuestionStatus` reads `hasCompletedQuestions_<userId>`, so without
  this the in-memory flag is lost on relaunch and the guest loops onboarding
  forever. Mirrored to `user_metadata` for the same reason `completePaywallFlow`
  does.
- **The legacy no-session branch survives, narrowed.** It is now reachable only
  when a guest session could not be created (kill switch on, or bootstrap failed
  and has not retried). Such a user has no `user_id`, so the scenario fetch
  itself throws `.notAuthenticated` — the wall at the end of that branch is what
  stops them reaching an app that cannot function for them. It disappears with
  the legacy flag in Phase H.
- **Flag default flipped to `true`** (fail open), as this plan required.

### The kill-switch inversion, which the flag flip forced

`postDemoWallIsHard` can read `isFeatureEnabled("post_demo_wall_hard")` directly
because `false` is its safe default. `guestSessionsEnabled` cannot: PostHog
returns `false` both for a flag that does not exist **and** for every launch
before `/decide` answers. An `enabled`-style key would therefore have read as
"off" on a fresh project and silently defeated the fail-open default, walling
every user at account creation.

The key is `guest_sessions_disabled` and the read is inverted. Absent or
not-yet-loaded → "not disabled" → open. Only an explicitly created-and-enabled
PostHog flag turns guest sessions off. It still gates *creation*, not use —
users holding a guest session keep it.

### Regression caught during verification

The first Phase E build bootstrapped a guest session at launch for a **brand-new
install**, so the app went straight to OnboardingView and LandingView never
appeared — silently removing the Create Account / Log In / Skip choice, which is
explicitly meant to be kept.

Cause: the launch-time retry (step 4b in `WingmanApp`, added so users who ended a
previous launch without a session get repaired) has no reason to run for someone
who has not chosen the skip path yet. It is now gated on `isLegacyAnonymousUser`,
which `startAnonymousOnboarding()` sets — i.e. the session is created by the skip
button, and the launch retry only ever repairs a session that should already
exist.

### Verification (simulator, **no launch arguments**)

| Step | Result |
|---|---|
| Fresh install, first launch | ✅ `RootView: User NOT authenticated, showing Landing` — no guest row minted |
| Tap "Skip for now" | ✅ `🔘 Skip for now button tapped` → `🎭 Creating guest session…` |
| Session established | ✅ `has_ever_had_session set`, `Adopting guest identity`, `Guest session signed in: 608D27CD-…` |
| Routing | ✅ `RootView: User HAS a session (guest: true)` → `Showing OnboardingView (questions NOT completed)` |

Note this ran with the flag at its shipped default and **no** PostHog
`guest_sessions_disabled` flag present — i.e. the fail-open path is what was
exercised.

### Still unverified

Identity linking (Phase D) has no runtime coverage: it needs a real Apple/Google
sign-in on a device holding a live guest session, which cannot be driven from
here. Verified by construction only. **Test this manually before shipping** —
sign in on a guest session and confirm
`⬆️ Guest promoted to permanent account — id preserved` with an unchanged id.

### Consequences for the legacy code

- Delete the forced `AuthView(mode: .signup, context: .requiredAfterPaywall)`
  branch (`WingmanApp.swift:267`).
- `AuthContext.requiredAfterPaywall` and its copy become unused. Keep the enum —
  Phase F reuses it for the post-purchase ask with different copy.
- RootView's entire anonymous branch (`WingmanApp.swift:228-269`) collapses into
  the authenticated path, because there is now always a `userId`.
- `AnonymousUserManager`'s mirrored flags (`hasCompletedPaywallFlow`,
  `hasCompletedOnboarding`, name/age/goals) become redundant — the anonymous
  Supabase user can write `user_metadata` directly.
- `syncAnonymousDataToBackend()` (`AuthManager.swift:826`) becomes a no-op:
  linking preserves the row, so there is nothing to transfer. Its most delicate
  logic — the flag transfer at `:876-898` — exists solely to survive a user_id
  change that no longer happens.
- `effectivePaywallFlowCompleted` loses its reason to exist once the anonymous
  and authenticated paths are one path. Verify before removing; it also
  self-heals reinstall cases.

Net: this phase deletes more than it adds, including the race-prone code whose
own doc comment (`AnonymousUserManager.swift:59-71`) records prior breakage.

---

## Phase F — Post-purchase account ask

**IMPLEMENTED and verified on simulator, 2026-07-30.**

`AuthContext.afterPurchase` with its own copy, a "Not now" decline, and a
persisted per-user flag (`hasSeenPostPurchaseAccountAsk_<userId>`) so declining
is remembered rather than re-asked every launch.

Routing sits **before** branch 4a in RootView, which is what lets one condition
(`isGuestSession && shouldShowPostPurchaseAccountAsk`) catch a purchase made on
*either* paywall instead of needing two branches. Declining sets the flag and
falls through to 4a; linking clears `isGuestSession` and does the same.

Copy does three jobs, same discipline as the required-step screen:

| Line | Job |
|---|---|
| "Secure your subscription" | why this is worth 10 seconds |
| "Right now it's tied to this device…" | what is actually at risk |
| "Your subscription is already active either way." | removes the fear that declining costs them what they paid for |

### Verification

| Test | Result |
|---|---|
| Guest + subscription → ask presented | ✅ `Showing post-purchase account ask (guest subscriber)`, `context: afterPurchase` |
| "Not now" | ✅ `declined` → `marked seen for: C2295FE8-…` → `Showing MainTabView` — **the payer is never trapped** |
| Relaunch after declining | ✅ ask does **not** reappear; straight to MainTabView |

Layout was reviewed on device and corrected: two free `Spacer`s centred the
content block and left a void above the title larger than the one this screen's
whole redesign was meant to remove. The top spacer is now capped at 90pt so
content sits high-centre with the decline and legal footer anchoring the bottom.

DEBUG hook `-forcePostPurchaseAsk YES` shows the screen without a real purchase.

### Still unverified

The **link** half — tapping Continue with Apple/Google here — has no runtime
coverage, for the same reason as Phase D: it needs a real provider sign-in on a
device holding a guest session. The decline path is fully verified; the accept
path is verified by construction only.

Fires after a successful purchase on **either** paywall, when the current session
is a guest session. One rule, not four branches.

**It must be skippable.** A "Not now" that lands the user in `MainTabView`.

The reason is already established in this codebase: `bypassWallThisSession`
(`WingmanApp.swift:114-124`) exists because a hard wall with no exit bricks the
app when a network-dependent call fails. The same applies here with higher
stakes — if Apple/Google OAuth fails, a user who has *already paid* cannot reach
what they bought. That is a refund, a one-star review, and a Guideline 3.1.2 /
5.1.1(v) surface. Blocking buys a few points of link rate and takes on a tail
risk carried entirely by paying customers.

Acceptance will be high anyway: "secure the subscription you just bought"
justifies itself, and this is the cohort you most need identified (refunds,
chargebacks, support, device changes).

---

## Phase G — Profile prompt for the permanently-free user

**IMPLEMENTED and verified on simulator, 2026-07-30.**

`AuthContext.saveProgress` presented as a **sheet** from a `SaveProgressBanner`
in ProfileView, above the streak card. A sheet rather than a route because this
is an offer the user can walk away from.

Thresholds are `[5, 25]`, escalating and then silent —
`AuthManager.guestAccountPromptThresholds`. Dismissal records the highest
threshold *reached* (`guestAccountPromptDismissedAt_<userId>`, mirrored to a
`@Published` so the view re-renders), so the prompt re-arms at the next tier
rather than the next render. A user who has declined twice has answered.

Copy names the specific thing at risk — "Save your N approaches", with N live
from `approachService.totalCount`. Everything else in the app is content that can
be re-served; the approach log is not.

### Verification

| Test | Result |
|---|---|
| Guest, 6 approaches | ✅ banner shows "Save your 6 approaches" |
| Tap ✕ | ✅ `Guest account prompt dismissed at threshold 5`, banner disappears |
| Relaunch, still 6 | ✅ `promptDismissedAt: 5` loaded, banner stays hidden |
| Seed to 26, relaunch | ✅ banner returns as "Save your 26 approaches" — escalation works |

Note on method: `xcrun simctl terminate` kills before UserDefaults flushes, so
reading the key with `defaults read` straight after a dismissal shows it missing.
That is a test artifact, not a bug — the relaunch above proves the value
persisted. Verify persistence by relaunching the app, never by reading the plist
after a `terminate`.

### Consequences and known limitation

The modal user — dismisses both paywalls — stays anonymous indefinitely. That is
a deliberate choice, not an oversight, and it means the guest session is the
primary persistence identity for most of the user base.

What that user actually accumulates: **approach logs** (ungated — verified, no
`subscriptionGate` on `LogApproachBottomSheet` or `ProfileView`), the two demo
completions, `user_metadata` profile fields, and a reading goal. Daily practice
is gated (`HomeView.swift:309`), so streaks do not meaningfully accumulate.

Everything on that list except the approach log is content that can be re-served.
The approach log is a record of things that happened in the user's life and
cannot be regenerated. That, and only that, is what the prompt protects.

Therefore:

- **Trigger on accumulated value, not on arrival** — first shown at ~5 logged
  approaches. A day-one user with zero logs has nothing to protect and the prompt
  is pure nag.
- **Profile, not Settings.** Settings has no traffic; Profile is where the logs
  are visibly sitting, which is the argument.
- Dismissible, re-armable at a higher threshold.

### Known limitation, worth stating rather than discovering

A guest session lives on one device. If that user later signs in with Apple on a
*new* phone they get a different row and the old progress is orphaned — linking
only works from the device holding the guest session. Worse, after a purchase:
Restore pulls the entitlement onto the new id via the App Store receipt, but the
progress stays behind, so they get the subscription back **without** the logs.
This is the strongest argument for Phase G actually being visible.

---

## Effect on phases 1-3 of `demo-then-wall-plan.md`

Largely intact.

- `hasCompletedFreeDemo` / `hasDismissedPostDemoWall` are per-user keyed and ride
  through `linkIdentity` unchanged, because the row and id survive linking.
- The three load paths (`:343`, `:429`, `:658`) still apply — but see Phase A.2,
  they must be confirmed to fire for anonymous sign-in.
- The `user_metadata` mirrors keep working; anonymous users have metadata.
- `PaywallSource.postDemo` and the `post_demo_wall_hard` flag are unaffected.
- The DEBUG launch-argument overrides remain useful and should be extended with
  one that forces a guest session, for testing Phase B without a clean device.

What does change: the plan's §1 statement that "the anonymous branch needs no
change" is now wrong — that branch is deleted.

---

## Phasing

| Phase | Work | Blocked by | Risk |
|---|---|---|---|
| **A** | Dashboard + four verifications + two decisions | — | ✅ done |
| **B** | Session bootstrap + migration guard | A | ✅ done — verified on simulator |
| **C** | `isAnonymousUser` rename | B | ✅ done |
| **D** | Identity linking + RevenueCat single-logIn; dead code left in place | B, C | ✅ done |
| **E** | Remove wall; collapse RootView; flag fail-open | C, D | ✅ done |
| **F** | Post-purchase account ask (skippable) — linking itself landed in D | E | ✅ done |
| **G** | Triggered Profile prompt | E | ✅ done |
| **H** | Delete Phase D/E dead code once verified in production | D, E | ⛔ blocked — see below |

Phase B ships behind a kill switch. If the guard misfires in the wild the only
safe rollback is "stop creating guest sessions", and that needs to be a remote
flag — `FeatureFlags` already has the PostHog plumbing from phase 3.

---

## Analytics

The funnel this is meant to move:

```
install → landing_skip → guest_session_created
       → onboarding_complete → paywall#1_viewed → {purchased | dismissed}
       → walkthrough_started → … → paywall_viewed(source=postDemo)
       → purchased → account_ask_shown → {linked | skipped}
```

Add: `guest_session_created`, `guest_session_bootstrap_failed`,
`account_ask_shown` / `account_linked` / `account_ask_skipped` (with a `trigger`
property: `postPurchase` | `profilePrompt`), `identity_link_conflict` (Phase A.4).

The number that judges this change: **paywall#1 dismissal → demo start**. Today
that transition passes through a forced account wall; the whole point is that it
stops doing so. `AuthRequired` (the screen-name split already shipped) gives the
before-baseline — capture it before Phase E deletes the screen.

---

## Phase H — BLOCKED, and why

**Not implemented, deliberately.** Attempted 2026-07-30; the reachability
analysis says it is not safe yet.

### Nothing on the deletion list is actually dead

Checked rather than assumed:

- `linkAnonymousPurchase` is called **only** from `syncAnonymousDataToBackend`.
- `syncAnonymousDataToBackend` is called **only** from the `.signedIn` handler,
  guarded by `isLegacyAnonymousUser`.
- A guest who links emits `.userUpdated`, not `.signedIn`, so guests never reach
  it. The **only** callers are legacy no-session users.
- `AuthContext.requiredAfterPaywall` is rendered only by the legacy RootView
  branch.

So every item reduces to one change: **delete the legacy no-session flow.**

### Which is exactly the thing that must not be deleted yet

The legacy branch is the fallback when a guest session cannot be created —
offline at first launch, `guest_sessions_disabled` flipped on, or a Supabase
outage. Today such a user still onboards and is walled at account creation.

Delete it and that user has nowhere to go: `startAnonymousOnboarding()` sets
`hasCompletedOnboarding = false`, `hasSession` is false, so RootView falls
through to LandingView — they tap "Skip for now", nothing visibly happens, and
they loop. Removing the fallback needs a real "couldn't create a session" state
built first; that is new work, not deletion.

### The gate, restated

This phase's own precondition is "once verified in production". Guest sessions
have not shipped, and **identity linking has never executed once at runtime** —
it is verified by construction only across D, E, F and G. Deleting the fallback
for a feature whose accept path has never run is the wrong order.

### Do this instead, in order

1. Ship A–G with the kill switch available.
2. Run the manual link test (below) — this is the release blocker.
3. Watch `guest_session_created`, `account_linked`, `account_ask_skipped` and
   purchase rate at `source=postDemo` for a release.
4. Then execute the checklist below as one mechanical commit.

### Removal checklist for when it unblocks

| Item | File |
|---|---|
| `linkAnonymousPurchase` | `Payment/RevenueCatManager.swift` |
| `🚨 RevenueCat purchase linking FAILED` branch | `Auth/AuthManager.swift` |
| `syncAnonymousDataToBackend()` + its `.signedIn` call | `Auth/AuthManager.swift` |
| `isLegacyAnonymousUser` + the `"isAnonymousUser"` key | `Auth/AuthManager.swift` |
| `AnonymousUserManager` (whole type) | `Util/AnonymousUserManager.swift` |
| Legacy RootView branch | `WingmanApp.swift` |
| `AuthContext.requiredAfterPaywall` + its copy/footnote | `Auth/AuthMode.swift`, `Auth/AuthView.swift` |
| No-session storage branch | `Payment/PaywallViewModel.swift` |
| `effectivePaywallFlowCompleted` (verify first — also self-heals reinstalls) | `Auth/AuthManager.swift` |

### Landed early from this phase

One item was safe now and is done: the purchase-storage branch in
`PaywallViewModel` keyed on `isAnon` ("no permanent account"), which meant a
**guest** purchase was still stashed in `AnonymousUserManager`. That armed
`needsRevenueCatLinking`, and had that guest ever reached the legacy sync path it
would have triggered an identified→identified `logIn` and stranded the
entitlement — the exact failure Phase D removed. Now keyed on `hasSession`.

---

## Manual test plan

Run on a **physical device** unless noted. The simulator cannot do Apple/Google
sign-in, and its keychain does not behave like a device's across uninstall.

Watch the console (Xcode, or Console.app filtered to subsystem
`com.lazul.wingman` for Release builds). The emoji prefixes are the fastest
filter: `🎭` guest session, `🔐` marker, `🆔` identity, `⬆️` promotion,
`🎯` routing.

### 0. THE BLOCKER — identity linking preserves the user id

Nothing else matters if this fails. Run it first.

1. Delete the app. Reinstall. Tap **Skip for now**.
2. Console: note the id in `🎭 Guest session signed in: <ID-A>`.
3. Complete onboarding, dismiss the paywall, log 5+ approaches.
4. Profile → **Save your N approaches** → **Create a free account** → Continue
   with Apple.
5. **PASS:** `⬆️ Guest promoted to permanent account — id preserved: <ID-A>` —
   the *same* id as step 2, and the approaches are still listed.
6. **FAIL:** a different id, or `✅ User signed in` with an empty approach list.
   That means linking silently created a new user. **Do not ship.**

Verify server-side too:

```sql
select id, email, is_anonymous from auth.users where id = '<ID-A>';
-- expect: is_anonymous = false, email populated, SAME row
```

### 1. New user keeps the Landing choice

1. Fresh install → **LandingView appears** (not onboarding).
2. Console shows **no** `🎭 Creating guest session…` yet — the choice is intact.
3. Tap **Create Account** → normal signup, no guest row is ever made.
4. Reinstall, tap **Skip for now** → `🎭 Creating guest session…` now fires.

### 2. Guest reaches the app with no account wall

1. Skip for now → onboarding → rating → paywall → **dismiss**.
2. **PASS:** lands in the app. The old "Create Account" wall must **not** appear.
3. Log an approach, complete a scenario, quit and relaunch — progress persists
   and `🎭 Guest session restored from cache` shows the same id.

### 3. Existing paying user is untouched (migration safety)

Use a device that already has a real account and an active subscription.

1. Install the new build over the old one. **Do not** delete the app.
2. **PASS:** signs straight in, subscription active, progress intact.
3. Console must show `🎭 Guest bootstrap REFUSED` or no bootstrap at all —
   **never** `Creating guest session`.
4. Repeat in airplane mode: expect the login screen, **never** a new guest
   session. This is the failure that would strand a paying customer.

### 4. Post-purchase ask is an ask, not a wall

1. As a guest, buy a subscription (sandbox account).
2. **PASS:** "Secure your subscription" appears with **Not now**.
3. Tap **Not now** → lands in the app, subscription active.
4. Relaunch → the ask does **not** return.
5. Repeat, this time tapping Continue with Apple → run the step-0 id check.

### 5. Profile prompt thresholds

1. Guest with fewer than 5 approaches → **no banner** (it protects nothing yet).
2. At 5+ → "Save your N approaches" appears.
3. Dismiss ✕ → gone. Relaunch → still gone.
4. Reach 25 → returns. Dismiss → never returns.

Persistence must be checked by **relaunching the app**. Reading the plist after
`simctl terminate` shows stale values — the kill skips the UserDefaults flush.

### 6. Kill switch and offline

1. In PostHog create `guest_sessions_disabled` and enable it.
2. Fresh install → Skip → `🎭 Guest bootstrap skipped` and the legacy flow runs
   (onboarding → paywall → account wall). Nothing crashes.
3. Disable the flag again; new installs get guest sessions.
4. Airplane mode → Skip → `🎭 Guest bootstrap deferred — offline`. Restore
   network → `🎭 Network restored — retrying deferred guest bootstrap`.

### 7. Analytics sanity

After a day of real traffic, confirm these arrive:
`guest_session_created`, `account_linked`, `account_ask_skipped`
(with `trigger` = `postPurchase` / `profilePrompt`), and screen views
`Auth` / `AuthAfterPurchase` / `AuthSaveProgress`.

The funnel that judges the whole change:
**paywall #1 dismissed → demo started.** That transition used to pass through a
forced account wall. `AuthRequired` gives the before-baseline.

### 8. Housekeeping while testing

Test runs leave anonymous rows behind. Clear them between passes:

```sql
delete from auth.users where is_anonymous = true;
```

---

## Open items

1. ~~Merge policy for `identity_already_exists`~~ — decided, error handling only.
2. Keychain survival across reinstall (Phase A.3). Determines how loudly Phase G
   needs to advertise itself. Needs a physical device; simulator is misleading.
3. Anonymous-row cleanup cadence and abuse controls (Phase A.5).
4. Whether `is_anonymous` should be readable in RLS for any policy — currently
   no policy distinguishes, and none obviously needs to. Confirm against the live
   schema, which is not inspectable from this repo.
5. Account deletion for a guest user: `AccountDeletionModels` assumes a real
   account. Decide whether "delete my data" is offered pre-link, and whether it
   is even reachable in the UI for a guest.
6. Swipe-to-dismiss on the Profile sheet records nothing, so the banner stays.
   Defensible — the user closed the sheet, they did not decline — but if it
   reads as nagging, route the sheet's dismissal through
   `markGuestAccountPromptDismissed` too.
7. **Phase H is blocked** — see its section. The gate is the manual link test
   plus one release of production data.
