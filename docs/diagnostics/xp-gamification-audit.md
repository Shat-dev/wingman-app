# XP & Gamification — Diagnosis of What Exists Today

Diagnosis only. No code was changed. Verified against branch `Shat` at
`f252c46`, plus live introspection of the Supabase project
`bnckmgnysfliiypvxxii` (the URL hardcoded at
[SupabaseManager.swift:17](../../Wingman/Supabase/SupabaseManager.swift#L17)).

**Read this first:** the streak's database objects are *not in this
repository*. `supabase/migrations/` contains exactly two files, both about
lesson questions (`20260730000000_create_lesson_questions.sql`,
`20260730010000_lesson_questions_by_column.sql`). Every table and function
behind the streak — `user_daily_practice_streaks`,
`user_daily_practice_sessions`, `update_daily_practice_streak`,
`get_daily_practice_status` — exists only in the live database. Claims about
them below are cited as `[live DB]` and were read via `pg_get_functiondef` /
`information_schema`. There is no file in this repo to point at.

---

## Part A — The existing streak system

### A.1 Where streak state is stored

**Both.** Server is authoritative for the value; the client keeps a
last-known-good mirror.

**Server** `[live DB]` — two tables, both `user_id UUID → auth.users(id)`,
both RLS-enabled with `auth.uid() = user_id` policies:

`public.user_daily_practice_streaks` (11 rows) — one row per user,
`UNIQUE (user_id)`:

| column | type | default |
|---|---|---|
| `id` | uuid | `gen_random_uuid()` |
| `user_id` | uuid | — (unique, FK `auth.users`) |
| `current_streak` | integer | 0 |
| `longest_streak` | integer | 0 |
| `last_completed_date` | **date** (nullable) | — |
| `total_days_completed` | integer | 0 |
| `created_at` / `updated_at` | timestamptz | `now()` |

`public.user_daily_practice_sessions` (53 rows) — one row per user per day,
`UNIQUE (user_id, date)`:

| column | type | default |
|---|---|---|
| `id` | uuid | `gen_random_uuid()` |
| `user_id` | uuid | — (FK `auth.users`) |
| `date` | **date** | — |
| `completed_at` | timestamptz | `now()` |
| `questions_answered` | integer | 0 |
| `correct_answers` | integer | 0 |

`longest_streak` is written but **never read by the app** — no Swift file
references it (grep for `longest`/`best_streak` finds only the dead
UserDefaults key cleared at
[SupabaseManager.swift:72](../../Wingman/Supabase/SupabaseManager.swift#L72)).

There is also a `public.daily_practice_completions` table `[live DB]`, 0 rows,
referenced by **no** Swift file and no function. Dead.

**Client** — [`StreakStore`](../../Wingman/DailyPractice/StreakStore.swift), a
`@MainActor final class ... ObservableObject` singleton
([StreakStore.swift:17-19](../../Wingman/DailyPractice/StreakStore.swift#L17-L19)).
Exact Swift types
([StreakStore.swift:23-26](../../Wingman/DailyPractice/StreakStore.swift#L23-L26)):

```swift
@Published private(set) var currentStreak: Int?      // nil = never loaded
@Published private(set) var totalCompleted: Int?
@Published private(set) var completedDates: Set<String>   // "yyyy-MM-dd"
@Published private(set) var isRefreshing: Bool
```

Persisted to `UserDefaults` under three keys
([StreakStore.swift:34-37](../../Wingman/DailyPractice/StreakStore.swift#L34-L37)):
`streak_cache_current`, `streak_cache_total_completed`,
`streak_cache_completed_dates`.

Wire types are separate structs, both with all-optional fields and
`?? 0`-defaulting computed accessors —
`DailyPracticeStatus`
([DailyPracticeServiceProtocol.swift:79-97](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L79-L97))
and `StreakUpdateResult`
([DailyPracticeServiceProtocol.swift:99-111](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L99-L111)).

### A.2 What increments the streak, and where it fires

One call site. `DailyPracticeViewModel.nextQuestion()`, `.finished` branch
([DailyPracticeViewModel.swift:144-163](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L144-L163))
→ `updateDailyPracticeStreak(questionsAnswered:correctAnswers:)`
([DailyPracticeViewModel.swift:175-236](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L175-L236))
→ `DailyPracticeService.updateDailyPracticeStreak`
([DailyPracticeServiceProtocol.swift:349-404](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L349-L404))
→ RPC `update_daily_practice_streak(p_user_id, p_date, p_questions_answered,
p_correct_answers)` `[live DB]`.

The trigger is **advancing past the last question**, not answering it
correctly — `engine.advance()` returning `.finished`. `correctAnswers` is
recorded on the session row but is not used in any streak arithmetic
`[live DB]`.

Nothing else in the codebase calls the RPC. `HomeViewModel.incrementStreak()`
([HomeViewModel.swift:370-378](../../Wingman/Home/HomeViewModel.swift#L370-L378))
is labelled legacy and only re-reads status.

### A.3 How "a day" is defined

**Device timezone, and the date is supplied by the client.**

```swift
private func getCurrentLocalDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}
```
[DailyPracticeServiceProtocol.swift:408-413](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L408-L413)

That string is passed as `p_date` to both `update_daily_practice_streak`
([:361-370](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L361-L370))
and `get_daily_practice_status`
([:273-280](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L273-L280)).
Both functions do all their date arithmetic against `p_date`, never against
`now()` or `current_date` `[live DB]`. The server never independently
establishes what day it is.

Consequence: changing the device clock or timezone changes what "today" means
for the streak. The same locale assumption is repeated client-side in
`StreakStore` (`fmt.timeZone = .current` at
[StreakStore.swift:108-111](../../Wingman/DailyPractice/StreakStore.swift#L108-L111)
and [:143-147](../../Wingman/DailyPractice/StreakStore.swift#L143-L147)) and in
`WeekStreakCard` ([ProfileView.swift:360-385](../../Wingman/Profile/ProfileView.swift#L360-L385)),
which also hardcodes Sunday as the week start.

`isTodaysPracticeCompleted` / `checkTodayCompletionFromQuestions` use a third
representation — `Calendar.current.startOfDay` + ISO8601 timestamps against
`user_question_completions.completed_at`
([:225-247](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L225-L247),
[:326-346](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L326-L346)) —
so "today" is expressed three different ways across the streak path.

### A.4 Missed day: reset, grace period, freeze

**Hard reset. No grace period. No freeze. No repair.** `[live DB]`

Write side (`update_daily_practice_streak`):

```
last_completed_date = p_date - 1  → current_streak += 1
last_completed_date < p_date - 1  → current_streak := 1
otherwise (same day)              → unchanged
```

Read side (`get_daily_practice_status`) re-validates so a stale row cannot
display a dead streak:

```
last_completed_date IS NULL        → 0
last_completed_date >= p_date - 1  → stored current_streak
otherwise                          → 0
```

So a single missed calendar day drops the displayed streak to 0 immediately,
and the next completion starts at 1. `longest_streak` is the only memory of
what was lost, and nothing displays it.

**Two edge cases in the write path** `[live DB]`: if a streak row exists with
`last_completed_date IS NULL`, all three `IF` branches evaluate NULL/false and
control falls through to the "same day" else-branch — the streak stays at its
stored value (0) instead of being set to 1, and `IF v_last_completed_date !=
p_date` is also NULL so `total_days_completed` is not incremented either. That
state is reachable only if a row is created outside the RPC, which nothing in
the app does today.

### A.5 Client- or server-authoritative?

**Nominally server-side, effectively client-controlled.**

Server-side: the arithmetic, the reset rule and the re-validation all live in
Postgres `[live DB]`. The client cannot post an arbitrary streak number — the
only inputs are a date and two counts.

Client-side, and these matter:

1. **The date is the client's** (§A.3).
2. **Both functions are `SECURITY DEFINER` and take `p_user_id` as a
   parameter, and neither compares it to `auth.uid()`** `[live DB]`. RLS on
   the underlying tables is therefore bypassed on this path. Any authenticated
   user can advance any other user's streak by passing a different UUID. The
   Swift client always passes `SupabaseManager.shared.currentUserId`
   ([:352](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L352)),
   so this is not exploited by the app — but it is the shape of the pattern,
   and copying it for XP would copy the hole.
3. **The number shown after a completion is not always the number stored.**
   All three failure branches of
   `DailyPracticeViewModel.updateDailyPracticeStreak` set
   `currentStreak = 1` and show the completion screen anyway
   ([:187](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L187),
   [:221](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L221),
   [:232](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L232)).
   A user on day 40 whose write fails is told "1", and the write is never
   retried.

### A.6 Offline behaviour

**Daily Practice cannot be done offline at all**, so the streak cannot advance
offline. `getTodayQuestions()` and `getDailyPracticeStatus()` both open with
`guard NetworkMonitor.shared.isConnected else { throw ... .networkError }`
([:122-124](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L122-L124),
[:259-262](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L259-L262)),
so the questions never load and `DailyPracticeView` shows the error state
([DailyPracticeView.swift:79-80](../../Wingman/DailyPractice/DailyPracticeView.swift#L79-L80)).

Reads degrade gracefully: `StreakStore.refresh()` keeps the last-known values
on failure and never writes 0
([StreakStore.swift:70-90](../../Wingman/DailyPractice/StreakStore.swift#L70-L90)),
`HomeViewModel` falls back to `StreakStore.shared.currentStreak ?? 0`
([HomeViewModel.swift:334-345](../../Wingman/Home/HomeViewModel.swift#L334-L345)),
and Profile renders straight from the cache-seeded store
([ProfileView.swift:149-153](../../Wingman/Profile/ProfileView.swift#L149-L153)).

There is **no write queue and no retry anywhere.** `updateDailyPracticeStreak`
notably has *no* `NetworkMonitor` guard
([:349-404](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L349-L404)),
so a connection dropping mid-run produces the "streak = 1" screen described in
§A.5.3 and the day is lost permanently.

### A.7 Reinstall and re-login

**Reinstall:** the streak survives, because it lives on `user_id` server-side
and the Supabase session is stored in the iOS Keychain, which outlives app
deletion — this project relies on that explicitly
([AuthManager.swift:2284](../../Wingman/Auth/AuthManager.swift#L2284): "The
Supabase session persists in iOS Keychain across app deletes", and the
fresh-install fallback at
[AuthManager.swift:1051-1052](../../Wingman/Auth/AuthManager.swift#L1051-L1052)).
`SupabaseManager` does not override the SDK's session storage
([SupabaseManager.swift:29-37](../../Wingman/Supabase/SupabaseManager.swift#L29-L37)).
The `UserDefaults` cache is gone, so `currentStreak` is `nil` until the first
`refresh()` — Home shows a spinner
([HomeView.swift:103-108](../../Wingman/Home/HomeView.swift#L103-L108)) and
Profile shows `0` via `?? 0`
([ProfileView.swift:150](../../Wingman/Profile/ProfileView.swift#L150)) until
the RPC lands.

**Re-login:** `clearCurrentUser()` wipes the three cache keys and calls
`StreakStore.shared.clearCache()`
([SupabaseManager.swift:63-94](../../Wingman/Supabase/SupabaseManager.swift#L63-L94),
[StreakStore.swift:119-125](../../Wingman/DailyPractice/StreakStore.swift#L119-L125)),
so no cross-user leakage; the server value is re-fetched on next Home entry.

### A.8 Guest → authenticated transition (checked explicitly)

**Streak state survives — because the user id does not change.**

When a guest session is present, `authenticate(with:)` calls
`client.auth.linkIdentityWithIdToken` instead of `signInWithIdToken`
([AuthManager.swift:2579-2602](../../Wingman/Auth/AuthManager.swift#L2579-L2602)),
which attaches the provider to the existing `auth.users` row. Both
streak tables are keyed on that id, so every row stays addressable.
`promoteGuestToPermanent`
([AuthManager.swift:2657-2691](../../Wingman/Auth/AuthManager.swift#L2657-L2691))
flips the flags in place and never calls `clearCurrentUser()`, so the
`UserDefaults` streak cache is not wiped either.

**This area is fragile for lesson progress, not for the streak** — and that
asymmetry is the thing to notice before widening streak eligibility:

- Streak/session/scenario rows are server-side and keyed on `user_id`; the
  link preserves them with no migration step.
- **Lesson progress is not.** It is `UserDefaults` namespaced by
  `SupabaseManager.shared.currentUserId ?? "anonymous"`
  ([LessonDataService.swift:212-222](../../Wingman/Lesson/LessonDataService.swift#L212-L222)),
  mirrored into `auth.users.raw_user_meta_data.lesson_progress`
  ([LessonDataService.swift:280-300](../../Wingman/Lesson/LessonDataService.swift#L280-L300)).
  It survives the link only because the id is preserved and
  `promoteGuestToPermanent` explicitly calls
  `hydrateLessonProgressFromCloud()`
  ([AuthManager.swift:2679](../../Wingman/Auth/AuthManager.swift#L2679)).

Two paths still lose everything, streak included:

1. `AccountLinkError.identityAlreadyExists`
   ([AuthManager.swift:2548-2555](../../Wingman/Auth/AuthManager.swift#L2548-L2555),
   thrown at [:2598-2601](../../Wingman/Auth/AuthManager.swift#L2598-L2601)) —
   the chosen Apple/Google identity already belongs to another Wingman row.
   The error string says so out loud: progress from this session will not
   carry over. There is no merge flow.
2. Any sign-in that is *not* from a guest session takes the
   `signInWithIdToken` branch
   ([AuthManager.swift:2580-2582](../../Wingman/Auth/AuthManager.swift#L2580-L2582))
   and lands on whatever row that identity owns.

**UNDETERMINED — whether a *legacy* anonymous user (the pre-guest-session
`isAnonymousUser` UserDefaults concept,
[AuthManager.swift:240-262](../../Wingman/Auth/AuthManager.swift#L240-L262))
can hold streak data at all.** Those users had no `auth.users` row, so every
streak call would have hit the `notAuthenticated` guard
([:352](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L352))
and written nothing. I read the guard and the flag; I did not find a migration
path that would need to move streak data for them, and I did not verify how
many such installs exist in the wild.

---

## Part B — Completion surfaces

Three screens. **All three are one-offs.** They share nothing but the
`"checklist"` image asset and a black `Continue` button — no shared component,
no shared view model, no shared "completion" type.

### B.1 Daily Practice → `QuestionsCompleteView`

File: [Wingman/DailyPractice/QuestionsCompleteView.swift](../../Wingman/DailyPractice/QuestionsCompleteView.swift)
(105 lines).

Presented as a `navigationDestination` bound to
`viewModel.showCompletionView`
([DailyPracticeView.swift:93-99](../../Wingman/DailyPractice/DailyPracticeView.swift#L93-L99)),
which is set only after the streak RPC resolves (or fails)
([DailyPracticeViewModel.swift:205-212](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L205-L212)).

Receives ([:14-15](../../Wingman/DailyPractice/QuestionsCompleteView.swift#L14-L15)):
`currentStreak: Int`, `dismissDailyPractice: () -> Void`, plus
`TabBarVisibilityManager` from the environment.

Renders: checklist image, `"Daily Practice Complete!"`, a flame + streak
number ([:43-53](../../Wingman/DailyPractice/QuestionsCompleteView.swift#L43-L53)),
Continue. Continue posts `NavigateToHomeView` and dismisses
([:58-83](../../Wingman/DailyPractice/QuestionsCompleteView.swift#L58-L83)).

**This is the only one of the three that shows any persistent number.**

### B.2 Lesson → `LessonQuizFlowView` → `LessonCompleteView`

Files: [Wingman/Lesson/LessonQuizFlowView.swift](../../Wingman/Lesson/LessonQuizFlowView.swift)
(228 lines) and [Wingman/Courses/LessonCompleteView.swift](../../Wingman/Courses/LessonCompleteView.swift)
(105 lines).

The lesson's last paragraph sets `showEndOfLesson`
([LessonView.swift:343](../../Wingman/Lesson/LessonView.swift#L343)), which
presents `LessonQuizFlowView` as a `fullScreenCover`
([LessonView.swift:192-229](../../Wingman/Lesson/LessonView.swift#L192-L229)).
That view is a two-step state machine — `.questions` then `.complete`
([LessonQuizFlowView.swift:44-47](../../Wingman/Lesson/LessonQuizFlowView.swift#L44-L47))
— and renders `LessonCompleteView` in the `.complete` case
([:102-105](../../Wingman/Lesson/LessonQuizFlowView.swift#L102-L105)). A lesson
with no authored questions starts at `.complete`
([:62](../../Wingman/Lesson/LessonQuizFlowView.swift#L62)).

`LessonQuizFlowView` receives: `lesson`, `questions: [QuizQuestion]`,
`readingStepCount: Int`, `nextLessonInfo: NextLessonInfo?`,
`onComplete: () -> Void`
([:25-36](../../Wingman/Lesson/LessonQuizFlowView.swift#L25-L36)).

`LessonCompleteView` receives only
`nextLessonInfo: NextLessonInfo?` and `onContinue: () -> Void`
([LessonCompleteView.swift:10-11](../../Wingman/Courses/LessonCompleteView.swift#L10-L11)).
`NextLessonInfo` is `{ title, subtitle }`
([Lesson.swift:64-67](../../Wingman/Lesson/Lesson.swift#L64-L67)).

Renders: checklist image, `"Lesson Complete!"`, then either "Up Next" + next
lesson title, or "Course Complete!"
([:40-64](../../Wingman/Courses/LessonCompleteView.swift#L40-L64)), and
Continue. **No count of anything.** It does not even know the quiz score —
`engine.correctCount` is read for analytics
([LessonQuizFlowView.swift:180](../../Wingman/Lesson/LessonQuizFlowView.swift#L180))
and then dropped.

Continue runs `onComplete`, which fires `lesson_completed` and calls
`markLessonCompleted`
([LessonView.swift:198-226](../../Wingman/Lesson/LessonView.swift#L198-L226)).
**The lesson is not marked complete until this button is tapped** — that is
the natural XP hook point, and it is a single site.

### B.3 Scenario → `GameCompleteView`

File: [Wingman/PracticeGame/PracticeGame.swift:753-787](../../Wingman/PracticeGame/PracticeGame.swift#L753-L787)
(defined inline in the 1145-line game file, not its own file).

Presented as a `fullScreenCover` on `showGameComplete`
([PracticeGame.swift:449-455](../../Wingman/PracticeGame/PracticeGame.swift#L449-L455)),
set by the `onChange(of: viewModel.gameCompleted)` handler
([:430-448](../../Wingman/PracticeGame/PracticeGame.swift#L430-L448)).

Receives exactly one thing: `onContinue: () -> Void`
([:754](../../Wingman/PracticeGame/PracticeGame.swift#L754)).

Renders: checklist image, `"Game Complete!"`, Continue. Nothing else. It has
no reference to the scenario, the user, or any counter.

### B.4 Shared vs. one-off — the practical answer

| | Daily Practice | Lesson | Scenario |
|---|---|---|---|
| View | `QuestionsCompleteView` | `LessonCompleteView` | `GameCompleteView` |
| Own file | yes | yes | no (inline) |
| Presented as | `navigationDestination` | `fullScreenCover` (nested inside another cover) | `fullScreenCover` |
| Data in | streak Int + closure | `NextLessonInfo?` + closure | closure only |
| Persistent number shown | streak | none | none |
| Continue does | notify + dismiss | **mark complete** + dismiss | dismiss |

An XP display cannot be added in one place. It is **three separate edits**,
and each one needs a different plumbing job to get the number there:
`QuestionsCompleteView` already receives a number and can take a second;
`LessonCompleteView` receives its data from `LessonQuizFlowView`, which would
have to acquire it; `GameCompleteView` receives nothing and would need a
parameter added plus a source in `PracticeGame`.

Extracting a shared `CompletionScreen` component first is viable — the three
layouts are near-identical (same asset, same 24–28pt Manrope semibold title,
same 52pt black button) and differ only in title, an optional middle slot, and
the Continue action.

---

## Part C — XP integration points

### C.1 Where XP should be persisted

**Follow the streak's *shape* — server-side table plus a cache-first
`ObservableObject` store — and deliberately diverge on three specifics.**

Follow, because it already works and the alternatives in this codebase are
worse:

- A Postgres table keyed on `user_id`, with an RPC as the write path. This is
  the only persistence approach in the app that survives reinstall without
  relying on a JSON blob merge. The alternative in-repo pattern is lesson
  progress —`UserDefaults` + `auth.users.raw_user_meta_data` with a union
  merge and a full-state last-write-wins push
  ([LessonDataService.swift:238-361](../../Wingman/Lesson/LessonDataService.swift#L238-L361)).
  Do not use that for XP: it has no timestamps, no server-side arithmetic, and
  "union of sets" is meaningless for a running total.
- A client store modelled on `StreakStore` — optional-typed published state so
  "not loaded" is distinguishable from zero, `UserDefaults` seeding in `init`,
  never overwrite on refresh failure, an `apply(...)` entry point so a
  completion write can push its authoritative result in without a second RPC,
  and registration of its cache keys in `SupabaseManager.clearCurrentUser()`
  ([StreakStore.swift:22-26](../../Wingman/DailyPractice/StreakStore.swift#L22-L26),
  [:70-90](../../Wingman/DailyPractice/StreakStore.swift#L70-L90),
  [:96-113](../../Wingman/DailyPractice/StreakStore.swift#L96-L113),
  [SupabaseManager.swift:81](../../Wingman/Supabase/SupabaseManager.swift#L81)).
  `UserProfileStore` is the proof this generalises — it is an explicit copy of
  the same pattern
  ([UserProfileStore.swift:5-12](../../Wingman/Profile/UserProfileStore.swift#L5-L12)).

Diverge on:

1. **Ledger, not a mutable counter.** `user_daily_practice_streaks` is one
   mutable row per user with no audit trail `[live DB]`; a bad write is
   unrecoverable and undetectable. XP needs append-only award rows
   (`user_id`, source type, source id, amount, awarded_at) with the total
   derived or maintained alongside. The reason is not tidiness — see §C.4:
   lessons and scenarios are both re-completable, so once-only awards must be
   enforced by a `UNIQUE (user_id, source_type, source_id)` constraint. Client
   logic cannot enforce it; `PracticeService.completeScenario` already proves
   that, inserting an unconstrained duplicate row on every replay
   ([PracticeServiceProtocol.swift:294-314](../../Wingman/PracticeGame/PracticeServiceProtocol.swift#L294-L314);
   `user_scenario_completions` has only a PK on `id` `[live DB]`).
2. **Server-side `auth.uid()`, not a `p_user_id` parameter.** Both streak
   functions are `SECURITY DEFINER` and trust the caller-supplied UUID (§A.5).
3. **Server-side time.** The streak's day boundary is the device's (§A.3).
   XP awards should stamp `now()` server-side even if a client-local day is
   also recorded for display.

Also: put the migration **in `supabase/migrations/`**. The streak objects are
not in this repo at all, which is why this report needed live introspection to
describe them.

### C.2 Completion events that already exist (no new instrumentation)

Every one of these is a single, guarded, genuine-completion site:

| Event | Fires at | Already writes to server |
|---|---|---|
| Daily Practice finished | `DailyPracticeViewModel.nextQuestion()` `.finished` — [DailyPracticeViewModel.swift:144-163](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L144-L163) | yes — the streak RPC |
| Lesson finished | `onComplete` closure — [LessonView.swift:198-226](../../Wingman/Lesson/LessonView.swift#L198-L226), invoked from [LessonCompleteView.swift:71](../../Wingman/Courses/LessonCompleteView.swift#L71) | no — local + `user_metadata` only |
| Lesson marked complete | `LessonDataService.markLessonCompleted` — [LessonDataService.swift:149-182](../../Wingman/Lesson/LessonDataService.swift#L149-L182), posts `.lessonCompleted` | no |
| Lesson quiz finished | `LessonQuizFlowView.handleNext()` `.finished` — [LessonQuizFlowView.swift:175-187](../../Wingman/Lesson/LessonQuizFlowView.swift#L175-L187) | per-answer only, `user_lesson_quiz_answers` ([LessonQuestionService.swift:163-175](../../Wingman/Lesson/LessonQuestionService.swift#L163-L175)) |
| Scenario finished | `PracticeGameViewModel.triggerCompletion()` → `markComplete()` — [PracticeGame.swift:250-254](../../Wingman/PracticeGame/PracticeGame.swift#L250-L254), [:270-277](../../Wingman/PracticeGame/PracticeGame.swift#L270-L277) | yes — `user_scenario_progress` + `user_scenario_completions` |
| Approach logged | [LogApproachViewModel.swift:160](../../Wingman/LogApproch/LogApproachViewModel.swift#L160) | yes — `approach_logs` |

Two existing `NotificationCenter` broadcasts are already the app's
completion fan-out and could carry an XP refresh with no new plumbing:
`.dailyPracticeCompleted`
([HomeViewModel.swift:12](../../Wingman/Home/HomeViewModel.swift#L12), posted
at [DailyPracticeViewModel.swift:162](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L162),
observed at [HomeViewModel.swift:68](../../Wingman/Home/HomeViewModel.swift#L68))
and `.lessonCompleted`
([LessonDataService.swift:14](../../Wingman/Lesson/LessonDataService.swift#L14),
posted at [:175](../../Wingman/Lesson/LessonDataService.swift#L175) and
[:359](../../Wingman/Lesson/LessonDataService.swift#L359), observed by
`CoursesViewModel` and `PracticeViewModel`).

**Caution on `.lessonCompleted`:** it is also posted by
`hydrateLessonProgressFromCloud()`
([LessonDataService.swift:353-360](../../Wingman/Lesson/LessonDataService.swift#L353-L360))
on every sign-in, where nothing was completed. It is a "recompute derived
state" signal, not an award signal. Awarding XP from it would grant XP at
login.

### C.3 What is missing

Everything on the storage side, and one thing on the event side:

- **Tables.** No XP table of any kind exists `[live DB]`; no Swift file
  mentions XP, points or levels (grepped across `Wingman/`).
- **A per-day, server-side record that a lesson was completed.** The
  `lesson_progress` blob is arrays of lesson ids with **no timestamps**
  ([LessonDataService.swift:251-263](../../Wingman/Lesson/LessonDataService.swift#L251-L263)).
  The only timestamped server trace of lesson activity is
  `user_lesson_quiz_answers.answered_at` `[live DB]`, which exists only when
  the quiz feature flag is on and the lesson has authored questions
  ([LessonView.swift:355-364](../../Wingman/Lesson/LessonView.swift#L355-L364)).
  **This is the single biggest gap for Part D**: without it, a lesson cannot
  mark a streak day server-side.
- **Idempotency for scenario completion.** No unique constraint on
  `user_scenario_completions` `[live DB]`; replays insert duplicates
  ([PracticeServiceProtocol.swift:294-314](../../Wingman/PracticeGame/PracticeServiceProtocol.swift#L294-L314)).
- **A generic "activity happened today" day-marker.** Today the only such
  marker is `user_daily_practice_sessions`, whose name and readers make it
  specifically the daily-practice flag (§D.1).
- **Any retry/queue for a failed award write.** None exists for the streak
  either (§A.6).
- **A shared completion-screen component** to render an XP delta (§B.4).
- **A store + display surfaces.** `HomeView`'s badge
  ([HomeView.swift:95-124](../../Wingman/Home/HomeView.swift#L95-L124)) and
  `WeekStreakCard` ([ProfileView.swift:354-450](../../Wingman/Profile/ProfileView.swift#L354))
  are streak-only.

### C.4 Repeatability — the constraint an XP economy runs into first

- **Lessons are re-openable after completion.** The only tap guard is
  `guard !lesson.isLocked` plus the paywall
  ([CourseDetailSheet.swift:143-145](../../Wingman/Courses/CourseDetailSheet.swift#L143-L145));
  `isCompleted` only changes the checkmark tint
  ([:319](../../Wingman/Courses/CourseDetailSheet.swift#L319)). Re-finishing
  re-runs `markLessonCompleted` and re-fires `lesson_completed`.
- **Scenarios are re-playable.** `loadAndNavigate` checks `isLocked` and the
  paywall, never `isCompleted`
  ([PracticeView.swift:156-196](../../Wingman/PracticeGame/PracticeView.swift#L156-L196)).
- **Daily Practice is the only naturally once-per-day activity**, enforced by
  `UNIQUE (user_id, date)` on the session table `[live DB]` and by
  `get_daily_practice_status` returning `can_resume = false`
  ([HomeViewModel.swift:317-319](../../Wingman/Home/HomeViewModel.swift#L317-L319)).

An XP hook placed naively on the completion sites in §C.2 is farmable by
re-finishing the same lesson or replaying the same scenario. Hence the unique
constraint in §C.1.1.

### C.5 PostHog events that already fire on these completions

All three completions are already instrumented, with duration, and the event
names are constants in one file
([Analytics.swift:24-224](../../Wingman/Util/Analytics.swift#L24-L224)):

| Constant | Name | Fire site | Properties |
|---|---|---|---|
| `dailyChallengeCompleted` | `daily_challenge_completed` | [DailyPracticeView.swift:106-117](../../Wingman/DailyPractice/DailyPracticeView.swift#L106-L117) | `question_count`, `duration_seconds` |
| `lessonCompleted` | `lesson_completed` | [LessonView.swift:207-218](../../Wingman/Lesson/LessonView.swift#L207-L218) | `lesson_id`, `lesson_name`, `category`, `duration_seconds`, `is_free_lesson` |
| `lessonQuizCompleted` | `lesson_quiz_completed` | [LessonQuizFlowView.swift:178-184](../../Wingman/Lesson/LessonQuizFlowView.swift#L178-L184) | `question_count`, `correct_count`, `duration_seconds` |
| `practiceScenarioCompleted` | `practice_scenario_completed` | [PracticeGame.swift:436-440](../../Wingman/PracticeGame/PracticeGame.swift#L436-L440) | `scenario_id`, `scenario_name`, `during_walkthrough`, `duration_seconds` |
| `approachLogged` | `approach_logged` | [LogApproachViewModel.swift:160](../../Wingman/LogApproch/LogApproachViewModel.swift#L160) | — |

**Reuse these; do not add `xp_awarded_for_lesson` and friends.** Add an
`xp_awarded` property (and, if useful, `xp_total_after`) to the existing
completion events. The file's own stated convention supports this — see the
`is_free_lesson` rationale at
[Analytics.swift:81-85](../../Wingman/Util/Analytics.swift#L81-L85) and
[LessonView.swift:211-217](../../Wingman/Lesson/LessonView.swift#L211-L217):
a property on the canonical event rather than a parallel event, so the two can
never disagree about what counts as finishing.

One genuinely new event *is* warranted: **there is no streak event today**
(grep of `Analytics.Event` finds none). Nothing in PostHog records a streak
being extended or broken, so the retention question this whole project is
about — does the streak hold people? — is currently unanswerable from
analytics. That gap exists whether or not XP ships.

**One caveat on all analytics-derived reasoning:** events captured before
`PostHogSDK.setup()` completes were being dropped, ~4 in 5 for Landing, until
the buffering gate was added
([Analytics.swift:226-282](../../Wingman/Util/Analytics.swift#L226-L282)).
Completion events fire deep in a session so they were never the victims, but
historical counts on early-session events are not trustworthy baselines.

---

## Part D — Should Lessons and Scenarios grant streaks?

### Recommendation

**Yes — widen streak eligibility to lessons and scenarios. Decouple streak
from XP. And do not implement it by writing to
`user_daily_practice_sessions`.**

Streak = "you showed up today", satisfied by *any one* qualifying activity,
capped at one per day. XP = "how much you did", awarded per completion with
once-only sources enforced in the database.

### D.1 What breaks if streak eligibility widens

The obvious implementation — have a lesson or scenario call
`update_daily_practice_streak` — **breaks the Home screen**, because that RPC's
first act is to insert into `user_daily_practice_sessions` `[live DB]`, and
that table is the app's "daily practice is done today" flag, not a generic day
marker. Concretely:

1. **`get_daily_practice_status` reads it as completion** `[live DB]`:
   `SELECT EXISTS(... FROM user_daily_practice_sessions WHERE user_id AND date)
   INTO v_completed_today; v_can_resume := NOT v_completed_today;` The
   function's own comment calls this table "the authoritative signal" for
   daily-practice completion.
2. **Home's button state comes straight from that**
   ([HomeViewModel.swift:317-319](../../Wingman/Home/HomeViewModel.swift#L317-L319)):
   `dailyPracticeButtonText = status.completedToday ? "Completed" : "Start"`
   and `isDailyPracticeButtonEnabled = status.canContinue`. A user who
   finished a lesson would be told Daily Practice was already done and the
   button would be disabled. They would lose access to the day's questions.
3. **The Profile week card would lie.**
   `StreakStore.fetchCompletedDatesForCurrentWeek()` selects `date` from the
   same table
   ([StreakStore.swift:149-158](../../Wingman/DailyPractice/StreakStore.swift#L149-L158))
   and `WeekStreakCard` lights a flame per matching day
   ([ProfileView.swift:391-405](../../Wingman/Profile/ProfileView.swift#L391-L405)).
   Arguably desirable under the new rule — but it silently redefines what the
   flame means, and `apply(updateResult:)` also inserts today's date locally
   ([StreakStore.swift:104-113](../../Wingman/DailyPractice/StreakStore.swift#L104-L113)).
4. **`total_days_completed` changes meaning.** It is displayed as "total" in
   the same card
   ([ProfileView.swift:151](../../Wingman/Profile/ProfileView.swift#L151),
   [:432-…](../../Wingman/Profile/ProfileView.swift#L432)) and returned by
   `get_total_daily_practices` `[live DB]`. It would stop counting daily
   practices.
5. **`questions_answered` / `correct_answers` become meaningless** on rows
   written by a lesson or scenario — they are `NOT NULL DEFAULT 0` `[live DB]`,
   so a lesson would write a zero-question "session".
6. **A second-order problem:** the client-side "did they already do today's
   practice" check counts rows in `user_question_completions`, not sessions
   ([DailyPracticeServiceProtocol.swift:236-250](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L236-L250),
   [:326-346](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L326-L346)),
   and `getDailyPracticeStatus` *overrides* the RPC's answer with it
   ([:294-310](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L294-L310)).
   So the two sources of "completed today" would disagree with each other in
   opposite directions.

The fix is a new day-marker keyed on `(user_id, local_date)` recording *which*
activity satisfied the day, with the streak computed from it, and
`user_daily_practice_sessions` left alone as the daily-practice flag it
already is.

Two further blockers, both already named above:

- **A lesson has no server-side completion timestamp** (§C.3). Making a lesson
  count toward a streak requires a new server write at
  [LessonView.swift:220-223](../../Wingman/Lesson/LessonView.swift#L220-L223) /
  [LessonDataService.swift:149-182](../../Wingman/Lesson/LessonDataService.swift#L149-L182).
  This is not optional and is the main cost of the change.
- **Lessons and scenarios are re-completable** (§C.4). Harmless for a streak
  (a day is a day) — fatal for XP without a constraint.

### D.2 Coupled or decoupled?

**Decoupled. Same completion events, two different rules.**

- The streak's unit is *the day*. It is idempotent by construction — the
  second lesson of the day must add nothing, or the number stops meaning
  consecutive days.
- XP's unit is *the piece of work*. It must be additive, or it stops meaning
  volume.

Coupling them forces one of two bad outcomes: XP inherits a once-a-day cap and
stops rewarding the fifth lesson (which is exactly the "no sense of
accumulation" problem you are trying to fix), or the streak inherits
additivity and stops being a streak.

The codebase pushes the same way. The streak's write path is a single RPC
returning `(current_streak, total_completed)` with day arithmetic baked in
`[live DB]`; XP's natural shape is an append-only ledger with a unique
constraint (§C.1). Those are different tables with different keys and
different failure modes — a failed XP write should be retryable and
idempotent, whereas a failed streak write is already a lost day with no retry
(§A.6). Forcing both through one call means one failure loses both.

Practical arrangement: each of the six completion sites in §C.2 calls one
"record activity" entry point; that call awards XP (idempotent per source) and
separately upserts the day-marker (idempotent per day). Two writes, one
trigger, independent semantics.

### D.3 Does widening devalue the streak?

**No — and the premise the code contradicts is worth stating plainly.**

Your brief says lessons and scenarios are "higher-effort" than Daily Practice.
Measured from the content:

- **Daily Practice: exactly 5 questions.** `generate_daily_question_set` caps
  the returned array at 5 (`selected_questions[1:LEAST(..., 5)]`) `[live DB]`,
  and the client's completion check is `count >= 5`
  ([DailyPracticeServiceProtocol.swift:246-247](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L246-L247)).
  Each question is Check Answer → Next
  ([DailyPracticeViewModel.swift:54-56](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L54-L56)).
  ≈ 10 taps.
- **Lesson: median 14 paragraphs across 6 screens, ~350 words** (measured
  across all 94 lessons in the 25 bundled JSON files under
  `Wingman/Courses/Wingman Lessons/`; range 7–20 paragraphs, 220–488 words).
  Advance is one tap per paragraph
  ([LessonView.swift:284-346](../../Wingman/Lesson/LessonView.swift#L284-L346)),
  with **no minimum time and no comprehension gate on the reading** — the tap
  target is a plain half-screen region
  ([LessonView.swift:378-438](../../Wingman/Lesson/LessonView.swift#L378-L438)).
  Then a median of 3 questions (275 questions across 94 lessons, min 2, max 3)
  `[live DB]`. ≈ 20 taps, and the JSON's own `duration` field says 2–5 minutes
  (median 3) ([Lesson.swift:16](../../Wingman/Lesson/Lesson.swift#L16)).
  **A lesson is roughly two Daily Practices' worth of taps, not an order of
  magnitude more** — and the quiz can be switched off entirely by the
  `lessonQuizEnabled` flag or `-skipLessonQuiz`
  ([LessonView.swift:355-364](../../Wingman/Lesson/LessonView.swift#L355-L364)),
  which reduces a lesson to pure tap-through.
- **Scenario: genuinely the heaviest.** 49–65 authored screens each with 5–7
  decision points across the 15 published scenarios `[live DB]`; the canonical
  success path is shorter than the raw screen count because failure branches
  are included, and a wrong answer routes through a fail branch and a feedback
  beat back to the same decision
  ([PracticeGame.swift:218-229](../../Wingman/PracticeGame/PracticeGame.swift#L218-L229)),
  with a forced feedback hold before navigation
  ([:185-191](../../Wingman/PracticeGame/PracticeGame.swift#L185-L191)).

So the ordering by effort is **scenario > lesson > daily practice**, and the
*least* effortful of the three is the only one that currently earns the
streak. That is backwards, and it is the strongest argument for widening.

Two real devaluation risks, both bounded:

1. **Any-of-three is strictly easier than one-of-one**, so streaks will get
   longer on average. This is the intended effect: the streak measures
   showing up, and there is no principled reason a user who read a lesson and
   played a scenario but skipped 5 multiple-choice questions should lose it.
2. **Lessons and scenarios are finite; Daily Practice is infinite.** There are
   94 lessons and 15 scenarios, gated by progression
   (`scenarios.required_lessons_completed` runs 0→40 `[live DB]`, enforced at
   [PracticeServiceProtocol.swift:150](../../Wingman/PracticeGame/PracticeServiceProtocol.swift#L150))
   and by course-completion unlocks
   ([LessonDataService.swift:188-192](../../Wingman/Lesson/LessonDataService.swift#L188-L192)),
   plus a paywall. Daily Practice regenerates forever, excluding recently-seen
   questions `[live DB]`. A committed user exhausts the finite content and is
   back to Daily Practice as the only daily-renewable source — so widening
   does not create an infinite easy path; it creates a temporary one.

Because lessons and scenarios are re-completable (§C.4), a widened streak is
in principle satisfiable forever by replaying scenario 1. Cheap mitigation, if
you want one: only *first* completions qualify. But that shares the once-only
source-id constraint XP needs anyway (§C.1.1), which is another argument for
building the ledger first.

---

## Assumptions in the brief that the code contradicts

1. **"Lessons and Scenarios are higher-effort" — half true.** Scenarios yes;
   lessons are ~2× the taps of Daily Practice with no time gate and an
   optional quiz (§D.3). If XP amounts are set by assumed effort, lessons will
   be over-valued.
2. **"Streaks are only earned via Daily Practice" — confirmed correct**, and
   `update_daily_practice_streak` has exactly one call site
   ([DailyPracticeViewModel.swift:195](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L195)).
3. **"The post-completion screen is flat" — flatter than the screenshots
   suggest.** Two of the three show *no* number at all; only Daily Practice
   shows the streak (§B). And there is no single screen to fix — three
   unrelated views (§B.4).
4. **Implied: XP could follow the streak pattern.** There *is* no single
   pattern. The streak is a server table + `SECURITY DEFINER` RPC that is not
   in version control; lesson progress is `UserDefaults` + a `user_metadata`
   JSON blob; scenario progress is plain RLS-protected tables. Which one you
   "follow" changes the answer materially (§C.1).
5. **Implied: streak state is safely server-authoritative.** The day boundary
   comes from the device and the user id from the caller (§A.3, §A.5).
6. **Implied: guest → account is the fragile part for streaks.** It is not —
   identity linking preserves the user id, so server-side streak rows survive.
   The fragile parts are the `identityAlreadyExists` dead-end and the
   `UserDefaults`/`user_metadata`-based *lesson* progress (§A.8).
7. **Unstated but load-bearing: a lesson's completion is recorded on the
   server with a time.** It is not (§C.3). This is the one hard prerequisite
   for letting lessons satisfy a daily streak.

---

## Undetermined

- **UNDETERMINED — the DDL history of the streak objects.** Checked
  `supabase/migrations/` (2 files, lesson questions only) and the live
  `pg_proc`/`information_schema`. The tables and functions exist in the
  database with no migration in this repo; I cannot say when or by whom they
  were changed, only what they currently are.
- **UNDETERMINED — whether any legacy anonymous (pre-guest-session) install
  holds streak data needing migration.** See §A.8.
- **UNDETERMINED — the true median completion *time* for a lesson or
  scenario.** `duration_seconds` is captured on `lesson_completed` and
  `practice_scenario_completed`
  ([LessonView.swift:208-210](../../Wingman/Lesson/LessonView.swift#L208-L210),
  [PracticeGame.swift:437-439](../../Wingman/PracticeGame/PracticeGame.swift#L437-L439))
  but I did not query PostHog. The effort figures in §D.3 are derived from
  content structure (paragraph, question and screen counts), not observed
  behaviour. Pulling those two distributions would settle the XP-weighting
  question empirically.
