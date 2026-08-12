# XP System — Implementation Plan

Companion to [`docs/diagnostics/xp-gamification-audit.md`](diagnostics/xp-gamification-audit.md),
which is the diagnosis this plan is built on. Read that first; this document
does not repeat its findings, it acts on them.

Verified against branch `Shat` at `f252c46`. **Plan only — nothing here has
been implemented.**

## The two hard constraints

Everything below is subordinate to these. A phase that cannot satisfy them
does not ship.

1. **No regression to any existing user's streak.** Not the stored value, not
   the displayed value, not the daily-practice button state, not the week
   card. The streak's write path is untouched by Phases 0–4 and its read path
   is untouched by Phases 0–4; Phase 5 changes the read path only behind a
   flag, in shadow mode first, with a numeric equality check against the
   current value for every existing user before the flag flips.
2. **Works for guests, and survives guest → real account.** This falls out of
   one fact established in the audit §A.8: `linkIdentityWithIdToken`
   ([AuthManager.swift:2579-2602](../Wingman/Auth/AuthManager.swift#L2579-L2602))
   preserves the `auth.users` id. Anything keyed on `user_id` survives the
   upgrade with **zero migration code**. So the entire design rule is: *XP is
   keyed on `auth.uid()` and nothing else.* No `anonymous_user_id`, no
   device id, no local-only ledger that has to be transferred at signup.
   §6 states the guest invariants explicitly and §7 the exception the plan
   cannot fix.

---

## 0. The economy — LOCKED 2026-08-12

Settled after [`xp-spec-feasibility.md`](diagnostics/xp-spec-feasibility.md) and
[`xp-spec-v2-diagnosis.md`](diagnostics/xp-spec-v2-diagnosis.md). **This
supersedes the placeholder amounts in §3.1 and closes every open decision in
§11.** Nothing below is implemented yet.

### Awards

| Source | Award | Range |
|---|---|---|
| Daily practice | 10 + 3×correct + 5 if 5/5 | 10–30 |
| Lesson | 20 + 5×correct + 5 if all correct | 20–35 (2q) / 20–40 (3q) |
| Scenario | 50 flat | 50 |
| Approach log | 50 flat, **capped at 250 per local day** | 0 or 50 |

The 20–40 lesson range is only reachable by the 87 three-question lessons; the
7 two-question lessons cap at 35. Accepted — see the v2 diagnosis §"Item 2".

**Every source is once-only per `source_id`**, which the shipped
`user_xp_events_once` constraint already enforces. Re-reading a completed lesson
or replaying a finished scenario earns nothing. Confirmed as intended.

### Who computes the amount

**The client sends facts; the server computes the amount.** The client passes
`correct_count` and `question_count`; the rules table holds the formula
components and Postgres does the arithmetic.

Rationale: amounts stay server-owned and tunable without an App Store release,
the client never names a number, and the trust assumption is *identical* to the
one `update_daily_practice_streak` already makes — it accepts client-supplied
`p_questions_answered` and `p_correct_answers` today. `QuizEngine.correctCount`
is first-answer-wins ([QuizEngine.swift:55-63](../Wingman/Quiz/QuizEngine.swift#L55-L63)),
so re-answering cannot inflate it.

Note the approach cap makes even the "flat" sources conditional: the award is 50
or 0 depending on how many approach rows already exist for that user and
`local_date`. That is a server-side count, not a constant, which is a second
reason the amount cannot stay a single integer in `xp_rules`.

### Levels

Cumulative thresholds: **0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200,
4000.**

**Derived, never stored.** A pure function of the total `get_xp_summary()`
already returns. A stored level column would be a denormalisation that can
silently disagree with the ledger. Displayed on Profile alongside
`WeekStreakCard` ([ProfileView.swift:149-155](../Wingman/Profile/ProfileView.swift#L149-L155)).

### Streak

Advances on any **completed** daily practice, lesson, or scenario. Completion,
never "viewed" — `lesson_started` fires from `onAppear`
([LessonView.swift:184-187](../Wingman/Lesson/LessonView.swift#L184-L187)), so
counting views would let one tap sustain a streak.

The day marker is **derived from `user_xp_events.local_date`** — no new table.
Phase 2 produced the activity-day record that plan §9.1 proposed to build.
Consequence, accepted: replaying finished content marks no day, so once a user
exhausts all 94 lessons and 15 scenarios only daily practice sustains the
streak.

### Deliberately NOT built

- **No daily goal.** The 30 XP goal was the Duolingo pattern where the goal *is*
  the streak condition. Here the streak is a completion test, so the goal has no
  mechanical job — and it would contradict the streak (a lesson answered
  entirely wrong is 20 XP: streak extends, goal missed). The app also already
  has an unrelated `DailyReadingGoalSheet`, which is purely notification copy —
  nothing measures reading time against it
  ([NotificationManager.swift:68-101](../Wingman/Util/NotificationManager.swift#L68-L101)).
- **No reflection bonus.** Dropped. The only real reflection field is `notes`,
  which is optional; `title` is required but is a short label.
- **No streak milestone bonuses.** Dropped. **The streak therefore awards no XP
  at all** — it is purely a habit counter. This is the decoupling the audit
  recommended (§D.2: streak = daily habit, XP = volume), and it removes the
  failure mode where the streak RPC's `currentStreak = 1` fallback
  ([DailyPracticeViewModel.swift:187](../Wingman/DailyPractice/DailyPracticeViewModel.swift#L187))
  would have silently skipped a milestone payout.

### Known consequence to revisit after launch

The economy is **approach-dominated**. A capped approach day is 250 XP against
120 for a perfect day of everything else combined, and the full 0→4000 ladder is
~16 days of capped approach logging. Levels will therefore mostly measure
approaches logged — the one self-reported, ungated action. Defensible, since the
audit found approach logging is the app's core value action, but it is a
decision rather than an accident. The lever is the cap, not the 50.

### Revised sequencing

The locked economy does not fit the original phase plan: three of the four
sources award a computed amount, and the shipped `award_xp` takes no amount and
no inputs. That is a change to the award mechanism — Phase 1 — not to the UI.

| | Work | Notes |
|---|---|---|
| 0 | Baseline the streak schema | **done**, `20260811160658` |
| 1 | XP ledger | **done**, `20260811161839` |
| 2 | Client write path + outbox | **done**, unshipped |
| **1b** | Reshape the award mechanism for computed amounts; wire the approach hook and its daily cap | **done**, `20260812053050` |
| **2b** | Plumb `correctCount` + `questionCount` to the lesson award site | **done** — 2 files, `LessonCompleteView` untouched |
| 3 | UI: completion screens, Home, Profile, levels | **done** — badge extracted, not a whole screen; see §5 |
| 5 | Streak widening | much cheaper — no new table |

**Do 1b now, before Phase 3.** `user_xp_events` holds **0 rows** and Phase 2 is
unshipped, so no released binary depends on the current RPC signature and no
user's total moves. Reshaping is free today. Once Phase 3 ships and users
accumulate XP it costs a data migration over live, user-visible totals plus an
App Store release.

Phase 4 (ship and observe) now sits after 3 rather than being a numbered stage
of its own.

---

## 1. Design decisions (and why)

| Decision | Choice | Why |
|---|---|---|
| Storage | Postgres table, RPC write path | Only approach in the app that survives reinstall without a JSON-blob merge (audit §C.1) |
| Shape | **Append-only ledger**, not a counter | Lessons and scenarios are both re-completable (audit §C.4); once-only must be a DB constraint |
| Total | **Derived** (`SUM(amount)`), no totals table | ~tens of rows per user; a second source of truth is a drift bug waiting to happen. Revisit only if a leaderboard ships |
| Identity | `auth.uid()` inside the function | The streak's RPCs take `p_user_id` and never check it (audit §A.5.2). Do not copy that |
| Amounts | **Server-owned**, in a rules table | Client cannot inflate; amounts become tunable without an App Store release |
| Time | `now()` server-side, plus a client-supplied `local_date` for display | The streak's day boundary is the device's (audit §A.3). XP records both and trusts the server for ordering |
| Streak coupling | **Decoupled** | Audit §D.2. Two writes, one trigger, independent semantics and independent failure |
| Offline | Local outbox + idempotent replay | The streak has no retry and loses the day (audit §A.6). XP must not inherit that |

---

## 2. Phase 0 — Baseline the existing schema (prerequisite, no behaviour change)

> **STATUS: DONE — applied 2026-08-11 as ledger version `20260811160658`.**
> File: `supabase/migrations/20260811160658_baseline_daily_practice_streaks.sql`.
> Verified a byte-for-byte no-op: function definitions, policies, constraints,
> indexes, column defaults, ACLs, RLS flags and row data all hashed identical
> before and after, and `get_daily_practice_status` returns values matching
> stored state for all 11 existing users.
>
> **New blocker surfaced for Phase 1**, see the KNOWN LEDGER MISMATCH note in
> that file: two local migration filenames carry versions the remote ledger has
> never seen, and one remote migration has no local file. Until that is
> reconciled, `supabase db push` would re-run `20260730010000` and drop the live
> `lesson_question_status` view. **Reconcile before shipping any XP migration.**

**Problem:** `supabase/migrations/` contains two files, both about lesson
questions. `user_daily_practice_streaks`, `user_daily_practice_sessions`,
`update_daily_practice_streak` and `get_daily_practice_status` exist only in
the live database (audit, preamble). Shipping a migration into a project with
no baseline means there is nothing to roll back to and nothing to reproduce a
staging environment from.

**Do:** add `supabase/migrations/<ts>_baseline_streak_and_practice.sql`
containing the *current* live definitions, written idempotently
(`create table if not exists`, `create or replace function`), so applying it to
production is a verified no-op.

**Acceptance:**

- `pg_get_functiondef` for both functions is byte-identical before and after
  applying the migration to production.
- `information_schema.columns` diff for both tables is empty.
- The migration applies cleanly to an empty database and to production.

**Risk to constraint 1:** this is the single highest-risk phase for the streak,
because it is the only one that writes DDL touching streak objects. Mitigate
by capturing `pg_get_functiondef`/`\d` output to a file *before* writing the
migration and diffing after. If the diff is not empty, stop.

---

## 3. Phase 1 — XP backend (additive only)

> **STATUS: DONE — applied 2026-08-11 as ledger version `20260811161839`.**
> File: `supabase/migrations/20260811161839_xp_ledger.sql`.
>
> **The SQL below has been corrected in three places since it was first
> written; the applied migration is the corrected version.** The original
> §3.3 specified `security invoker` and resolved the resulting RLS problem by
> adding an INSERT policy — that was a security hole, because Supabase's
> default privileges `GRANT ALL` on new public tables to `authenticated`, so a
> client could `POST /rest/v1/user_xp_events` with an `amount` of its choosing
> and bypass `xp_rules` entirely. It also omitted `search_path` on the new
> functions and the `EXECUTE` revoke from `PUBLIC`/`anon`. All three are fixed
> below and in the applied migration.
>
> Verified after apply: 15/15 behavioural assertions passed (once-only on
> replay, per-user scoping, guest and permanent accounts identical, all three
> error paths rejected), run inside an atomic block that rolled every test row
> back — the ledger holds 0 event rows and the 4 seeded rules. Streak
> functions, policies and data hashed identical to before; object counts moved
> by exactly +2 tables, +2 functions, +2 policies.

### 3.1 Tables

```sql
-- Server-owned award amounts. A table, not a CASE, so tuning is a SQL
-- update rather than an App Store release.
create table if not exists public.xp_rules (
  source_type text primary key,
  amount      integer not null check (amount > 0),
  updated_at  timestamptz not null default now()
);

insert into public.xp_rules (source_type, amount) values
  ('daily_practice', 20),
  ('lesson',         30),
  ('scenario',       50),
  ('approach',       40)
on conflict (source_type) do nothing;

-- Append-only ledger. The unique constraint IS the once-only rule.
create table if not exists public.user_xp_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  source_type text not null references public.xp_rules(source_type),
  source_id   text not null,
  amount      integer not null check (amount > 0),
  local_date  date not null,
  awarded_at  timestamptz not null default now(),
  constraint user_xp_events_once unique (user_id, source_type, source_id)
);

create index if not exists idx_user_xp_events_user   on public.user_xp_events(user_id);
create index if not exists idx_user_xp_events_recent on public.user_xp_events(user_id, awarded_at desc);
```

`source_id` values — the identity of the thing that was done:

| source_type | source_id | Once-only means |
|---|---|---|
| `daily_practice` | the local date, `"2026-08-12"` | one award per day (matches `UNIQUE (user_id, date)` on the session table) |
| `lesson` | `lesson.id`, e.g. `"lesson_7_3"` | replaying a lesson pays nothing |
| `scenario` | scenario UUID string | replaying a scenario pays nothing |
| `approach` | `approach_logs.id` | deleting and re-logging pays nothing |

Amounts above are placeholders. Set them from the effort data in audit §D.3
(scenario > lesson > daily practice), not from intuition — the audit found
lessons are ~2× the taps of daily practice, not 5×.

### 3.2 RLS

```sql
alter table public.user_xp_events enable row level security;
alter table public.xp_rules       enable row level security;

create policy "Users read own xp events" on public.user_xp_events
  for select to authenticated using (auth.uid() = user_id);

-- No INSERT policy. All writes go through the RPC below, which is the only
-- place the once-only and amount rules can be enforced together.

create policy "Rules readable" on public.xp_rules
  for select to authenticated using (true);
```

Guests hold the `authenticated` role (audit §A.8), so these policies cover
them with no special case — same reasoning as the `questions` RLS note at
[AuthManager.swift:2680-2683](../Wingman/Auth/AuthManager.swift#L2680-L2683).

### 3.3 The award function

```sql
create or replace function public.award_xp(
  p_source_type text,
  p_source_id   text,
  p_local_date  date
)
returns table (awarded boolean, amount integer, total_xp integer)
language plpgsql
security invoker           -- deliberately NOT definer; see below
as $$
declare
  v_uid    uuid := auth.uid();
  v_amount integer;
  v_new_id uuid;
begin
  if v_uid is null then
    raise exception 'award_xp: no authenticated user';
  end if;

  select r.amount into v_amount from public.xp_rules r
   where r.source_type = p_source_type;
  if v_amount is null then
    raise exception 'award_xp: unknown source_type %', p_source_type;
  end if;

  insert into public.user_xp_events (user_id, source_type, source_id, amount, local_date)
  values (v_uid, p_source_type, p_source_id, v_amount, p_local_date)
  on conflict (user_id, source_type, source_id) do nothing
  returning id into v_new_id;

  return query
    select v_new_id is not null,
           case when v_new_id is not null then v_amount else 0 end,
           coalesce((select sum(e.amount)::integer
                       from public.user_xp_events e
                      where e.user_id = v_uid), 0);
end;
$$;

grant execute on function public.award_xp(text, text, date) to authenticated;
```

Three things to notice, each a deliberate departure from the streak RPCs:

- **`security definer`, but with no `p_user_id`** — identity comes from
  `auth.uid()`, and `search_path` is pinned. A caller controls neither who is
  credited nor how much. The function must bypass RLS to write, because there
  is deliberately **no INSERT policy** on `user_xp_events`: adding one would
  combine with Supabase's default `GRANT ALL` to `authenticated` to let a
  client `POST /rest/v1/user_xp_events` with its own `amount` and skip the
  rules table. `EXECUTE` is revoked from `PUBLIC` and `anon` so the RPC needs a
  session. This is *not* the streak RPCs' mistake — theirs is trusting a
  caller-supplied user id, which this does not do.
- **`on conflict do nothing … returning`** makes replay free and tells the
  client whether it was a real award. This is what makes the outbox (§4.3)
  safe to flush at-least-once.
- **Total is recomputed, not incremented.** No drift is possible.

Also add a read function or plain select for hydration:

```sql
create or replace function public.get_xp_summary()
returns table (total_xp integer, event_count integer, last_awarded_at timestamptz)
language sql security invoker as $$
  select coalesce(sum(amount),0)::integer, count(*)::integer, max(awarded_at)
    from public.user_xp_events where user_id = auth.uid();
$$;
```

### 3.4 Acceptance (SQL only, before any app change)

- Award twice with the same `(source_type, source_id)` → second returns
  `awarded = false, amount = 0`, and `total_xp` unchanged. One row in the table.
- Award with a forged `user_id` → impossible; there is no parameter.
- Award as an anonymous (guest) JWT → succeeds, row carries the guest uuid.
- Unknown `source_type` → raises, no row.
- `select * from user_daily_practice_streaks` and `..._sessions` unchanged;
  `pg_get_functiondef` for both streak functions unchanged.

---

## 4. Phase 2 — Client write path (no UI)

> **STATUS: DONE — 2026-08-12.** Four new files under `Wingman/XP/`
> (`XPSource`, `XPService`, `XPOutbox`, `XPStore`) plus additive hooks in four
> existing files. `BUILD SUCCEEDED`, no errors, no new warnings; app launches
> and `XPStore` seeds correctly. 82 insertions, 1 deletion (the `cacheKeys`
> line being extended) — no existing logic modified.
>
> **Deviations from the spec below, all deliberate:**
> - **`approach` is not wired.** The rule row is seeded but no code awards it;
>   it stays open decision 2 in §11. The other three sources are live.
> - **No optimistic display.** `lastAward` is set only from a server result
>   with `awarded == true`, so it can never claim XP a replay did not grant.
>   Optimistic pre-server display is a §5.2 concern and lands with the
>   completion screens in Phase 3.
> - **`XPLocalDate` does not reuse `DailyPracticeService.getCurrentLocalDate()`**
>   — partly because §4.5 forbids touching that file, partly because that
>   formatter sets no locale and so inherits the device calendar. On a
>   non-Gregorian device the streak has been writing e.g. `2569-08-12` into
>   `user_daily_practice_sessions.date`. It stays self-consistent so the streak
>   still works, but it is wrong, and it is worth its own fix later.
>   `XPLocalDate` pins `en_US_POSIX` + Gregorian.
> - **`xp_award_failed` / `xp_outbox_flushed` shipped now**, not in Phase 3 —
>   the outbox is invisible without them and it ships here.

### 4.1 New files

```
Wingman/XP/XPService.swift        // protocol + Supabase impl, mirrors DailyPracticeService
Wingman/XP/XPStore.swift          // @MainActor ObservableObject, mirrors StreakStore
Wingman/XP/XPOutbox.swift         // UserDefaults-backed pending-award queue
Wingman/XP/XPSource.swift         // enum + local mirror of xp_rules for optimistic display
```

### 4.2 `XPStore` — follow `StreakStore`, with one addition

Copy the properties that make `StreakStore` behave well
([StreakStore.swift:22-26](../Wingman/DailyPractice/StreakStore.swift#L22-L26),
[:70-90](../Wingman/DailyPractice/StreakStore.swift#L70-L90),
[:96-113](../Wingman/DailyPractice/StreakStore.swift#L96-L113)):

```swift
@MainActor final class XPStore: ObservableObject {
    static let shared = XPStore()

    @Published private(set) var totalXP: Int?          // nil = never loaded
    @Published private(set) var lastAward: XPAward?    // for the completion screens
    @Published private(set) var isRefreshing = false

    static let totalKey    = "xp_cache_total"
    static let ownerKey    = "xp_cache_owner_user_id"   // ← the addition
    static let outboxKey   = "xp_outbox"
    static let cacheKeys   = [totalKey, ownerKey, outboxKey]
}
```

- `refresh()` never overwrites on failure (the `StreakStore` rule).
- `apply(result:)` pushes the RPC's authoritative `total_xp` in, so no second
  round-trip after a completion.
- **`ownerKey` is new and is not in `StreakStore`.** The cache records which
  `user_id` it belongs to; `loadFromCache()` drops it on mismatch. This closes
  a hole `StreakStore` has today: `clearCurrentUser()` only runs on sign-out
  ([SupabaseManager.swift:63-94](../Wingman/Supabase/SupabaseManager.swift#L63-L94)),
  so a `.signedIn` for a different user without an intervening `.signedOut`
  leaves the previous user's cached number on screen until refresh lands.
  **Do not backport this to `StreakStore` in this workstream** — it is a
  behaviour change to the streak, and constraint 1 forbids bundling it here.
  File it separately.

Register the keys for logout wipe — the single line this plan adds to an
existing file:

```swift
// SupabaseManager.swift:81
] + StreakStore.cacheKeys + UserProfileStore.cacheKeys + XPStore.cacheKeys
```

and the matching `XPStore.shared.clearCache()` alongside the two existing
calls at [SupabaseManager.swift:87-93](../Wingman/Supabase/SupabaseManager.swift#L87-L93).

### 4.3 The outbox

Why it exists: a failed streak write today shows the user "1" and is never
retried (audit §A.5.3, §A.6). XP must not repeat that.

Entry: `{ id, userId, sourceType, sourceId, localDate, createdAt }`.
Persisted as JSON in `UserDefaults` under `xp_outbox`.

Rules, in order of importance:

1. **Every entry carries the `userId` it was earned under.** On flush, entries
   whose `userId != SupabaseManager.shared.currentUserId` are **skipped, never
   sent**. This is the guard that prevents crediting user B for user A's work
   after an account switch. Skipped entries are pruned after 30 days.
2. Flush is at-least-once and safe, because `award_xp` is idempotent (§3.3).
3. Flush triggers: app foreground, `NetworkMonitor.$isConnected` → true
   (same pattern as
   [AuthManager.swift:1794-1807](../Wingman/Auth/AuthManager.swift#L1794-L1807)),
   and after each successful award.
4. The enqueue happens **before** the network call, not after it fails — so a
   process kill mid-flight cannot lose the award.
5. Cap the queue (e.g. 200 entries) and drop oldest; log a PostHog error if it
   ever fills, because that means flushing is broken.

### 4.4 Hook sites — one line each, all existing

None of these needs new instrumentation (audit §C.2):

| Source | Call from | Notes |
|---|---|---|
| `daily_practice` | [DailyPracticeViewModel.swift:144-163](../Wingman/DailyPractice/DailyPracticeViewModel.swift#L144-L163), `.finished` branch | **Alongside** the streak RPC, not inside it. `source_id` = the same local date string the streak RPC is given ([DailyPracticeServiceProtocol.swift:408-413](../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L408-L413)) |
| `lesson` | the `onComplete` closure, [LessonView.swift:198-226](../Wingman/Lesson/LessonView.swift#L198-L226) | Next to the existing `lesson_completed` capture and `markLessonCompleted` call — the point at which the lesson genuinely becomes complete |
| `scenario` | `PracticeGameViewModel.markComplete()`, [PracticeGame.swift:270-277](../Wingman/PracticeGame/PracticeGame.swift#L270-L277) | Already guarded to genuine completion by `triggerCompletion()` ([:250-254](../Wingman/PracticeGame/PracticeGame.swift#L250-L254)) |
| `approach` | [LogApproachViewModel.swift:160](../Wingman/LogApproch/LogApproachViewModel.swift#L160) | Optional for v1. If included, `source_id` = the approach row id so a delete-and-relog does not pay twice |

**Do not hook `.lessonCompleted` (NotificationCenter).** It is also posted by
`hydrateLessonProgressFromCloud()`
([LessonDataService.swift:353-360](../Wingman/Lesson/LessonDataService.swift#L353-L360)),
which runs on every sign-in and every guest promotion. Hooking it awards XP at
login. Same for `.dailyPracticeCompleted` — use the view-model site, which
fires once per genuine run.

### 4.5 Streak isolation checklist for this phase

These files must appear in the diff **only** in the ways listed:

- `SupabaseManager.swift` — two additive lines (§4.2). Nothing else.
- `DailyPracticeViewModel.swift` — one added call in the `.finished` branch,
  placed **after** the existing `Task { await updateDailyPracticeStreak(...) }`
  so it cannot reorder or delay the streak write, and in its own `Task` so an
  XP failure cannot throw into the streak path.
- `StreakStore.swift`, `DailyPracticeServiceProtocol.swift`,
  `HomeViewModel.swift`, `QuestionsCompleteView.swift` — **zero changes in
  this phase.**

### 4.6 Acceptance

- Complete a daily practice twice in one day (delete the session row between
  runs to force it): streak behaves exactly as today; XP awards once.
- Complete a lesson, force-quit before the network call resolves, relaunch:
  the award lands from the outbox, exactly once.
- Airplane mode → complete a lesson → re-enable: award lands once.
- Sign out, sign in as a different account: no XP from account A appears, and
  A's outbox entries are never sent.

---

## 5. Phase 3 — Completion screens and displays

> **STATUS: DONE — 2026-08-12.** Three new files (`XPLevel`, `XPAwardBadge`,
> `XPLevelCard`), badge added to all three completion screens, XP pill on Home,
> level card on Profile, hydration at all five auth sites.
>
> **Two deliberate deviations from the plan below:**
>
> 1. **No shared `CompletionScreen`.** §5.1 called for unifying the three
>    completion screens. Reading them showed they differ in image size (290 vs
>    291pt), title size (24 vs 28pt), button font (system 17 vs Manrope 16) and
>    four paddings. Unifying them would visibly redesign two screens under cover
>    of a refactor — a change nobody asked for, on the app's reward moments.
>    `XPAwardBadge` is extracted instead: one component, three call sites, the
>    same anti-drift benefit, zero visual regression. The full unification is
>    still available as a deliberate design task.
> 2. **No optimistic display.** §5.2 called for showing a locally-predicted
>    amount immediately and withdrawing it on a replay. That is a number
>    appearing and then vanishing; and for approaches the local mirror cannot
>    know the daily cap, so it would be wrong exactly when it mattered. The
>    badge renders only on a confirmed `awarded == true`, animating in when the
>    result lands. Cost: nothing shows offline, and a fast Continue tap misses
>    it — the total on Home and Profile is still correct in both cases.
>
> Also, per §0: a **level indicator on Profile**, and **no daily-goal ring**.
>
> `xp_awarded` ships as its own event rather than as properties on the
> completion events (§5.5). Those fire when the user finishes; the award
> resolves afterwards and may sit queued for hours, so carrying the amount on
> them would mean delaying a completion event on the network and dropping it
> entirely offline.

### 5.1 Extract a shared completion screen first

Audit §B.4: the three screens are one-offs sharing only the `"checklist"`
asset and a black 52pt button. Adding XP to three unrelated views triples the
work and guarantees drift.

New `Wingman/CommonComponents/CompletionScreen.swift`:

```swift
struct CompletionScreen<Detail: View>: View {
    let title: String
    let award: XPAward?          // nil → render nothing, no layout shift
    @ViewBuilder var detail: Detail
    let continueTitle: String
    let onContinue: () -> Void
}
```

Then:

- [QuestionsCompleteView.swift](../Wingman/DailyPractice/QuestionsCompleteView.swift)
  → `detail` = the existing flame + streak row
  ([:43-53](../Wingman/DailyPractice/QuestionsCompleteView.swift#L43-L53)).
  **Its `Continue` action must be preserved verbatim** — it posts
  `NavigateToHomeView`, shows the tab bar and calls `dismissDailyPractice`
  ([:58-83](../Wingman/DailyPractice/QuestionsCompleteView.swift#L58-L83)), and
  its `onAppear`/`onDisappear` drive `TabBarVisibilityManager`
  ([:88-95](../Wingman/DailyPractice/QuestionsCompleteView.swift#L88-L95)).
  Losing any of that is a navigation regression.
- [LessonCompleteView.swift](../Wingman/Courses/LessonCompleteView.swift)
  → `detail` = the existing "Up Next" / "Course Complete!" block
  ([:40-64](../Wingman/Courses/LessonCompleteView.swift#L40-L64)). `onContinue`
  still runs the `onComplete` closure that marks the lesson complete
  ([LessonView.swift:198-226](../Wingman/Lesson/LessonView.swift#L198-L226)) —
  **do not move the completion write into the component.**
- `GameCompleteView` ([PracticeGame.swift:753-787](../Wingman/PracticeGame/PracticeGame.swift#L753-L787))
  → `detail` = empty. Needs a new `award` parameter plumbed from `PracticeGame`
  ([:449-455](../Wingman/PracticeGame/PracticeGame.swift#L449-L455)).

### 5.2 Optimistic display, honest reconciliation

The reward screen must show a number immediately; the award RPC may be
in flight or queued. Rule:

1. Show the **locally mirrored** amount from `XPSource` (a Swift enum seeded
   with the same values as `xp_rules`) the moment the screen appears.
2. When the RPC returns, animate `totalXP` to the server's `total_xp`.
3. If the RPC returned `awarded = false` (a replay), show **no** award — the
   detail slot renders the streak/up-next only. The screen must never claim XP
   that was not granted.
4. If the RPC never returns (queued), keep the optimistic amount, do not
   animate a total, and let the next `refresh()` correct it.
5. If the local mirror and `xp_rules` diverge, the server wins on next refresh.
   Log a PostHog property when they differ so the drift is visible.

### 5.3 Persistent displays

- **Home:** an XP pill beside the existing flame badge
  ([HomeView.swift:95-124](../Wingman/Home/HomeView.swift#L95-L124)). Mirror
  the badge's own loading treatment — spinner while `totalXP == nil`, not `0`.
- **Profile:** an XP card near `WeekStreakCard`
  ([ProfileView.swift:149-155](../Wingman/Profile/ProfileView.swift#L149-L155)).
  Add `Task { await xpStore.refresh() }` next to the existing streak refresh at
  [ProfileView.swift:268](../Wingman/Profile/ProfileView.swift#L268).

### 5.4 Hydration hooks

`XPStore.refresh()` should be called where the other per-user loads already
happen, so a returning user's total is warm:

- guest branch of `.signedIn` — [AuthManager.swift:664-680](../Wingman/Auth/AuthManager.swift#L664-L680)
- guest branch of `.initialSession` — [AuthManager.swift:860-873](../Wingman/Auth/AuthManager.swift#L860-L873)
- permanent branches — [:714-723](../Wingman/Auth/AuthManager.swift#L714-L723), [:896-905](../Wingman/Auth/AuthManager.swift#L896-L905)
- `promoteGuestToPermanent` — [AuthManager.swift:2679-2685](../Wingman/Auth/AuthManager.swift#L2679-L2685)

The promotion hook is not strictly required (the id is unchanged, so the cache
is already correct) but it is free and keeps the promotion path symmetric with
`hydrateLessonProgressFromCloud()`.

### 5.5 Analytics

Reuse the existing completion events; do **not** add `xp_awarded_for_lesson`
and friends. Add `xp_awarded` and `xp_total_after` as properties to
`daily_challenge_completed`
([DailyPracticeView.swift:106-117](../Wingman/DailyPractice/DailyPracticeView.swift#L106-L117)),
`lesson_completed` ([LessonView.swift:207-218](../Wingman/Lesson/LessonView.swift#L207-L218))
and `practice_scenario_completed`
([PracticeGame.swift:436-440](../Wingman/PracticeGame/PracticeGame.swift#L436-L440)).
This follows the file's own stated convention — see the `is_free_lesson`
rationale at [Analytics.swift:81-85](../Wingman/Util/Analytics.swift#L81-L85).

Two new events are justified because they have no host: `xp_award_failed`
(with `source_type`, `queued: Bool`) and `xp_outbox_flushed` (with `count`).
Without them the outbox is invisible.

---

## 6. Guest and account-linking correctness

The invariants this plan relies on, each already true in the code:

1. **A guest is a real `auth.users` row**, so `auth.uid()` is non-null and
   every FK and RLS policy works unchanged (audit §A.8;
   [docs/anonymous-auth-plan.md](anonymous-auth-plan.md) §0).
2. **A sessionless user cannot reach content.** `RootView` walls them at
   account creation before `MainTabView`
   ([WingmanApp.swift:330-365](../Wingman/WingmanApp.swift#L330-L365)), so
   there is no "earned XP with no identity" case to design for at onboarding
   time. The outbox exists for network failures and for the narrow
   mid-session case in §7.1, not for identity-less awards.
3. **Linking preserves the id**
   ([AuthManager.swift:2586-2587](../Wingman/Auth/AuthManager.swift#L2586-L2587)),
   so XP rows survive guest → permanent with no transfer step, no merge, and
   no code. This is the single reason the plan can meet constraint 2 cheaply.
4. **`promoteGuestToPermanent` does not call `clearCurrentUser()`**
   ([AuthManager.swift:2657-2691](../Wingman/Auth/AuthManager.swift#L2657-L2691)),
   so the local XP cache is not wiped at promotion either.

**Test matrix for constraint 2** (all must pass before Phase 3 ships):

| Scenario | Expected |
|---|---|
| Guest earns XP, then links Apple → same XP total, same rows, no refetch gap | ✅ |
| Guest earns XP offline, links Apple while still offline, comes online | outbox flushes under the same (preserved) id, awards land once |
| Guest earns XP, links Google, force-quits, relaunches | total restored from cache, then confirmed by refresh |
| Guest earns XP, signs out deliberately, signs back into the same account | cache wiped by `clearCurrentUser()`, server total re-fetched intact |
| Guest earns XP, hits `identityAlreadyExists`, logs into the other account | XP does **not** carry — see §7.2. Must be *documented*, not silently wrong |

---

## 7. The fragility, expanded

This is the section the plan cannot engineer away, and the reason the ledger
shape matters.

### 7.1 Lesson progress: `UserDefaults` + a `user_metadata` JSON blob

Lesson completion is the only major progress signal in the app with **no
row in Postgres**. It lives in two places, neither of which is a database:

**(a) Namespaced `UserDefaults`.** Keys are
`completed_lessons_<namespace>_<courseId>` and
`unlocked_lessons_<namespace>_<courseId>`, where the namespace is
`SupabaseManager.shared.currentUserId ?? "anonymous"`
([LessonDataService.swift:212-222](../Wingman/Lesson/LessonDataService.swift#L212-L222)).

Failure modes:

- **The `"anonymous"` bucket is a black hole.** Nothing migrates it.
  `hydrateLessonProgressFromCloud()` iterates course ids and reads keys for the
  *current* namespace only
  ([:332-346](../Wingman/Lesson/LessonDataService.swift#L332-L346)); there is no
  code path anywhere that reads `completed_lessons_anonymous_*` and re-keys it.
  The window is narrow today — a sessionless user is walled before
  `MainTabView` ([WingmanApp.swift:330-365](../Wingman/WingmanApp.swift#L330-L365))
  — but not closed: a server-side session invalidation
  ([AuthManager.swift:762-851](../Wingman/Auth/AuthManager.swift#L762-L851))
  makes `currentUserId` nil while the user is still standing in a lesson. Their
  next completion writes to `"anonymous"` and is never seen again.
  `PracticeViewModel` has the same `"anonymous"` fallback for its scenario
  cache, flagged as a soft site in
  [docs/anonymous-auth-plan.md](anonymous-auth-plan.md) §0.
- **`markLessonCompleted` silently no-ops** if the course is not in
  `lessonsCache`: `guard var lessons = lessonsCache[courseId] else { return }`
  ([:150](../Wingman/Lesson/LessonDataService.swift#L150)). It depends on the
  course JSON having been loaded in this process.
- **Unlock state is inferred, not recorded.** `saveLessonProgress` derives the
  unlocked list from `!isLocked` on the in-memory array
  ([:224-230](../Wingman/Lesson/LessonDataService.swift#L224-L230)), so an
  in-memory mistake becomes persisted truth.

**(b) A JSON blob on `auth.users.raw_user_meta_data.lesson_progress`**
([:238-300](../Wingman/Lesson/LessonDataService.swift#L238-L300)).

Failure modes:

- **Last-write-wins on the whole blob.** The code writes full state, not
  deltas, and says so ([:246-248](../Wingman/Lesson/LessonDataService.swift#L246-L248)).
  Two devices → the later writer overwrites, and the loser's only protection is
  that the merge is a union.
- **Union merge means progress can only grow**
  ([:339-340](../Wingman/Lesson/LessonDataService.swift#L339-L340)). There is no
  un-complete. A wrong entry — from a bug, a bad merge, a shared device — is
  permanent, and the next sync pushes it back to the cloud.
- **No timestamps anywhere in the blob**
  ([:251-263](../Wingman/Lesson/LessonDataService.swift#L251-L263)). The server
  knows *that* `lesson_7_3` is done, never *when*. This is precisely what
  blocks lessons from marking a streak day (audit §C.3, §D.1) and it is why
  Phase 5 needs a new write.
- **Fire-and-forget sync, no retry.** `syncLessonProgressToCloud()` swallows
  the error and relies on "the next completion"
  ([:288-299](../Wingman/Lesson/LessonDataService.swift#L288-L299)). A user
  whose last lesson fails to sync and who then reinstalls loses it.
- **It gates scenario unlocks.** `totalLessonsCompleted()` sums the same
  `UserDefaults` keys ([:198-202](../Wingman/Lesson/LessonDataService.swift#L198-L202))
  and `PracticeService.fetchPractices` locks scenarios on it
  ([PracticeServiceProtocol.swift:150](../Wingman/PracticeGame/PracticeServiceProtocol.swift#L150)).
  A namespace mishap does not just hide progress — it silently re-locks content
  the user already earned.

**Consequence for XP:** do not persist XP this way, and do not derive XP from
lesson progress. The ledger in §3.1 is the fix — a row per award, with a
timestamp, in a table with a constraint. It also means XP for lessons is
*more* durable than the lesson completion that produced it, which is an
acceptable asymmetry and arguably an argument for giving lessons a real
Postgres row later (a prerequisite for Phase 5 anyway).

### 7.2 The `identityAlreadyExists` dead-end

**The path.** A guest taps Sign in with Apple/Google. `authenticate(with:)`
calls `linkIdentityWithIdToken`
([AuthManager.swift:2579-2597](../Wingman/Auth/AuthManager.swift#L2579-L2597)).
If that Apple/Google identity is already attached to a *different*
`auth.users` row, Supabase throws `.identityAlreadyExists`, which is mapped to
`AccountLinkError` and surfaced
([:2548-2555](../Wingman/Auth/AuthManager.swift#L2548-L2555),
[:2598-2601](../Wingman/Auth/AuthManager.swift#L2598-L2601)). The error copy
says it out loud: progress from this session won't carry over. **Phase A.4
explicitly decided against building a merge flow**
([:2546-2547](../Wingman/Auth/AuthManager.swift#L2546-L2547)); the only
requirement was that the screen not dead-end.

**Who hits it.** Not an exotic user — the *normal returning user on a new
device*. Someone who used Wingman, got a new phone or erased the old one, and
so lost the Keychain-persisted session that would otherwise have restored
their account ([AuthManager.swift:2284](../Wingman/Auth/AuthManager.swift#L2284)).
They reinstall, get a fresh guest session, use the app for a while, then sign
in with the same Apple ID they used originally. The `hasEverHadSession` guard
([:1723-1728](../Wingman/Auth/AuthManager.swift#L1723-L1728)) stops *that
device* minting a second guest, but it knows nothing about a different device.

**What is lost** when they proceed into the other account — everything keyed on
the abandoned guest uuid:

| Data | Where |
|---|---|
| Streak + all session days | `user_daily_practice_streaks`, `user_daily_practice_sessions` |
| Approach logs | `approach_logs` |
| Scenario progress and completions | `user_scenario_progress`, `user_scenario_completions` |
| Daily-practice answers | `user_question_completions` |
| Lesson quiz answers | `user_lesson_quiz_answers` |
| Lesson progress | the guest's own `raw_user_meta_data.lesson_progress` |
| **XP, once this plan ships** | `user_xp_events` |

The local mirrors go too: signing out to switch accounts runs
`clearCurrentUser()`, which wipes the streak and profile caches
([SupabaseManager.swift:63-94](../Wingman/Supabase/SupabaseManager.swift#L63-L94)).
The guest `auth.users` row is orphaned but never deleted, so the data still
exists server-side — it is simply unreachable, which is the important detail
below.

**What this plan does about it: nothing, deliberately — but it keeps the door
open.** Building account merge is out of scope and was already decided against.
What the plan *does* is choose a shape that can be merged later:

- Merging two XP ledgers is a single statement —
  `update user_xp_events set user_id = :keep where user_id = :abandon`
  followed by a conflict-tolerant retry, because
  `UNIQUE (user_id, source_type, source_id)` makes overlapping awards collapse
  instead of double-counting. That is the *easiest* merge in the entire app.
- The streak's `user_daily_practice_streaks` cannot be merged this way at all:
  one mutable counter row per user, with no per-day record beyond
  `user_daily_practice_sessions` and no way to reconstruct which days belonged
  to which identity beyond re-deriving it. (Re-deriving it is possible — that
  is a point in favour of the `user_activity_days` table in Phase 5.)
- Lesson progress cannot be merged reliably at all, for every reason in §7.1.

So: accept the dead-end, document it in the plan and in the error copy (which
already says it), and note that **if account merge is ever built, XP and the
Phase 5 activity-day table are the two things that will merge cleanly** —
which is an argument for the ledger, not an afterthought.

**Cheap mitigation worth considering separately** (not part of this plan):
detect the collision *before* the user commits, and offer "keep this session's
progress, use a different login" as the first option rather than showing an
error after the fact.

---

## 8. Phase 4 — Ship XP, hold the streak

Ship Phases 0–3. Do not touch the streak. Run for at least two weeks and
confirm from PostHog that `xp_award_failed` is near zero and outbox flushes are
rare before considering Phase 5. The audit's core complaint — "no sense of
accumulation" — is fully addressed by Phase 3 alone.

---

## 9. Phase 5 — Widen the streak (separate, flagged, shadow-first)

Only after Phase 4 is stable. This is the phase that can regress existing
users, so it gets the strictest process.

### 9.1 New table — never write to `user_daily_practice_sessions`

Audit §D.1 is the whole argument: that table is read by
`get_daily_practice_status` as the daily-practice completion flag, which drives
Home's button state ([HomeViewModel.swift:317-319](../Wingman/Home/HomeViewModel.swift#L317-L319))
and the Profile week card
([StreakStore.swift:149-158](../Wingman/DailyPractice/StreakStore.swift#L149-L158)).
Writing a lesson into it tells the user Daily Practice is done and disables the
button. Instead:

```sql
create table if not exists public.user_activity_days (
  user_id     uuid not null references auth.users(id) on delete cascade,
  local_date  date not null,
  first_source text not null,
  first_at    timestamptz not null default now(),
  primary key (user_id, local_date)
);
```

Written by the same "record activity" entry point that awards XP — two writes,
one trigger, independent failure (audit §D.2).

### 9.2 Backfill, then prove equality

```sql
insert into public.user_activity_days (user_id, local_date, first_source, first_at)
select user_id, date, 'daily_practice', coalesce(completed_at, now())
  from public.user_daily_practice_sessions
on conflict do nothing;
```

Then, **before any new source is allowed to write to the table**, verify for
every existing user that the streak computed from `user_activity_days` equals
`user_daily_practice_streaks.current_streak` as re-validated by
`get_daily_practice_status`. Not "close to" — equal, for all rows. If any user
differs, stop and find out why. (There are 11 streak rows and 53 session rows
today, so this is exhaustively checkable, not a sample.)

### 9.3 Shadow mode

Compute both values client-side for one release, display the **old** one, and
emit a PostHog event when they differ. Only flip the display after the
divergence rate is zero across a full release cycle. Gate the flip on a
PostHog boolean flag with a safe default of `false`, exactly like
`postDemoWallIsHard` ([FeatureFlags.swift:32-42](../Wingman/Util/FeatureFlags.swift#L32-L42)).

### 9.4 The prerequisite this phase cannot skip

A lesson has no server-side completion timestamp (§7.1, audit §C.3). Making a
lesson mark an activity day therefore requires a **new server write** at the
completion site ([LessonView.swift:220-223](../Wingman/Lesson/LessonView.swift#L220-L223)).
The `user_activity_days` upsert *is* that write — which means Phase 5 also
incidentally gives lessons their first real Postgres row, and the first
reliable answer to "when did this user last do a lesson?".

### 9.5 What must not change

- `update_daily_practice_streak` keeps writing exactly as today, so the legacy
  value stays available as fallback and rollback is a flag flip, not a
  migration.
- `user_daily_practice_sessions` keeps its meaning; nothing new writes to it.
- `total_days_completed` keeps counting daily practices only. If a "total
  active days" number is wanted, derive it from `user_activity_days` and label
  it separately — do not redefine the existing one, which is rendered as
  "total" in the week card ([ProfileView.swift:151](../Wingman/Profile/ProfileView.swift#L151)).

---

## 10. Rollback

| Phase | Rollback |
|---|---|
| 0 | None needed — verified no-op |
| 1 | `drop table user_xp_events, xp_rules; drop function award_xp, get_xp_summary;` Nothing else references them |
| 2 | App release without the hook calls. Ledger rows are inert |
| 3 | App release reverting the completion-screen changes. Server untouched |
| 5 | Flip the PostHog flag → the client reads the legacy streak again. `user_activity_days` keeps filling harmlessly |

No phase requires a data migration to reverse, and no phase before 5 can alter
a streak value.

---

## 11. Decisions — all resolved 2026-08-12

Kept as a record of what was decided and why. The answers live in §0.

| Question | Resolution |
|---|---|
| Amounts | §0. Formula-based, not flat |
| Who computes the amount | Client sends facts, server computes |
| Approaches as an XP source | **In** — 50 flat, capped 250/day |
| Replays | **Pay nothing.** `user_xp_events_once` already enforces it |
| Levels/tiers | **In** — derived from the total, shown on Profile, never stored |
| Scenario grade scaling | **Cut.** No grade exists and completion is 100%-correct by construction |
| Reflection bonus | **Cut** |
| Streak milestone bonuses | **Cut.** Streak awards no XP |
| Daily goal | **Cut** |
| 5-minute minimum between approach logs | **Cut** |
| Anti-farming on approach delete/relog | **Cut** — not a concern for this app |
| Streak sources | Completed daily practice, lesson, or scenario |
| Streak day marker | Derived from `user_xp_events.local_date`, no new table |

### The one thing still outstanding

**The ledger reconciliation** (see the KNOWN LEDGER MISMATCH note in
`supabase/migrations/20260811160658_baseline_daily_practice_streaks.sql`). Two
local migration filenames carry versions the remote has never seen, and one
remote migration has no local file. Targeted applies work fine, so it does not
block Phase 1b — but `supabase db push` stays unsafe until it is fixed, and
Phase 5 wants a preview branch to shadow-test on, which replays migrations.
