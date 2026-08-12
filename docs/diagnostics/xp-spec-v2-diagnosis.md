# XP Spec v2 — Diagnosis

Diagnosis only, no code changed. Follows
[`xp-spec-feasibility.md`](xp-spec-feasibility.md) with your simplifications
applied. Verified against branch `Shat` and project `bnckmgnysfliiypvxxii`,
2026-08-12.

---

## 1. "The quiz can be absent entirely" — you are right, it was patched

My earlier finding was accurate about the *mechanism* and overstated the
*risk*. Both accidental paths are closed:

- **The flag fails open.** `lessonQuizEnabled` defaults to `true`
  ([FeatureFlags.swift:84](../../Wingman/Util/FeatureFlags.swift#L84)) and the
  PostHog key is phrased as a kill switch, `lesson_quiz_disabled`
  ([FeatureFlags.swift:118-119](../../Wingman/Util/FeatureFlags.swift#L118-L119)).
  `isFeatureEnabled` returns false both for a flag that does not exist and for
  every launch before `/decide` answers — with an `enabled`-style key those read
  as "off". Phrased as `disabled` they read as "not disabled". Only a flag
  someone deliberately created *and* enabled can turn the quiz off.
- **The cold cache is covered.** `lesson_questions_seed.json` ships in the app
  bundle (confirmed present in the built `Wingman.app`) and covers **94 lessons
  / 275 questions** — every lesson. A fresh install with no network still has
  the full quiz.

What remains is one path, and it is not reachable by a user: the
`-skipLessonQuiz YES` launch argument
([LessonView.swift:367-371](../../Wingman/Lesson/LessonView.swift#L367-L371)).
It is only ever *read*, never written by app code, so setting it requires
launching from Xcode. It is a QA escape hatch, deliberately available in Release
because the flows worth testing sit behind a paywall.

**Verdict: in production the quiz always shows.** Lesson XP can safely assume a
quiz ran. The one thing the award still has to handle is the *shape* of the
data, not its absence — see §2.

## 2. "Is it safe to persist lesson quiz correct-count at award time?"

**Yes — safer than the equivalent already shipped for the streak.** Three
reasons:

1. **The count cannot be inflated by retrying.** `correctCount` is
   first-answer-wins, deduped by `countedQuestionIds`
   ([QuizEngine.swift:55-63](../../Wingman/Quiz/QuizEngine.swift#L55-L63)).
   Back-navigating and re-answering does not move it. That dedup exists
   precisely because Daily Practice feeds these numbers to the streak RPC.
2. **There is direct precedent.** `update_daily_practice_streak` already accepts
   `p_questions_answered` and `p_correct_answers` **from the client** and writes
   them to `user_daily_practice_sessions`. Trusting the client about its own
   quiz score is not a new trust assumption in this codebase; it is the existing
   one.
3. **The plumbing is small and contained.** The value exists at
   [LessonQuizFlowView.swift:180](../../Wingman/Lesson/LessonQuizFlowView.swift#L180)
   and is currently discarded. `onComplete: () -> Void`
   ([LessonQuizFlowView.swift:36](../../Wingman/Lesson/LessonQuizFlowView.swift#L36))
   has exactly one call site
   ([LessonView.swift:198](../../Wingman/Lesson/LessonView.swift#L198)); the
   view has exactly one presenter. Two files, two edits.

**One condition.** Pass the question *count* alongside the correct count. The
`.complete` step is also entered directly when `questions.isEmpty`
([LessonQuizFlowView.swift:62](../../Wingman/Lesson/LessonQuizFlowView.swift#L62)),
where `correctCount` is 0. Without the denominator, "0 of 0, no quiz ran" and
"0 of 3, got everything wrong" are indistinguishable, and the second should not
pay the same as the first.

## 3. Streak: "any daily practice, any lesson viewed, any scenario completed"

**Two things here — one I'd change, one that got much cheaper.**

### Change "viewed" to "completed"

`lesson_started` fires from `LessonView.onAppear`
([LessonView.swift:184-187](../../Wingman/Lesson/LessonView.swift#L184-L187)).
If viewing counts, opening a lesson and immediately backing out keeps a streak
alive — one tap, no content consumed. That is materially weaker than the other
two sources you named, both of which require finishing. It also undercuts the
number's meaning more than widening ever could.

Lesson *completion* is already an instrumented, single-site event (the Continue
tap at [LessonView.swift:220-233](../../Wingman/Lesson/LessonView.swift#L220-L233))
— it is where the XP hook already sits. Recommend that.

### The activity-day table the plan wanted already exists

Plan §9.1 proposed creating `user_activity_days`. **Phase 2 produced it as a
byproduct.** `public.user_xp_events` has `local_date` and gets a row on every
daily practice, lesson and scenario completion. "Did this user do something
today" is a query against a table that already exists, with no new schema.

**One caveat that is a genuine design question.** XP is once-only per
`source_id` (`user_xp_events_once`). So:

- Daily practice writes a row **every** day (`source_id` is the date).
- A lesson or scenario writes a row **only the first time** it is completed.

A user who re-reads a lesson they finished last month earns no XP and therefore
marks no activity day. Their streak would not advance, and the app would give no
reason why. Daily practice always works, so the streak is always sustainable —
but "I did a lesson today and my streak didn't move" is a support ticket waiting
to happen. Either accept it, or mark the day from the completion events rather
than from the ledger.

## 4. Does this fit alongside Phase 3, or does the plan change?

**The plan changes. The schema work has to come before Phase 3, not alongside
it — and right now it is free.**

### Why it cannot ride along

Three of the four activities still award a computed amount:

| Activity | Award | Variable? |
|---|---|---|
| Daily practice | 10 + 3×correct + 5 if 5/5 | **yes**, 10–30 |
| Lesson | 20 + 5×correct + 5 if all | **yes**, 20–35 / 20–40 |
| Scenario | flat | no |
| Approach | flat 50 | no |

`xp_rules.amount` is a single integer per source type and `award_xp` takes no
amount and no inputs — signature
`award_xp(p_source_type text, p_source_id text, p_local_date date)`. It cannot
express `base + per_correct + bonus` for any value of those constants. That is a
change to the award mechanism itself, which is Phase 1, not Phase 3.

Building Phase 3's UI on top of flat amounts means building screens that display
numbers the economy will not produce, then reworking them.

### Why now is the cheapest moment it will ever be

- **`user_xp_events` holds 0 rows.** Nothing to backfill, no user's total moves.
- **Phase 2 is not shipped.** The XP code exists only in the working tree and my
  local build; no released binary depends on the current RPC signature.

Both of those stop being true the moment Phase 3 ships. Reshaping afterwards
means a data migration over live, user-visible totals plus an App Store release.
This is the concrete version of the point I made loosely earlier.

### The one decision that gates everything: who computes the amount

Three options. I recommend the third.

1. **Client sends the amount.** Simplest. Reopens exactly the hole the ledger was
   built to close — a modified client awards itself anything. You said cheating
   isn't a concern here, and for an app with no leaderboard that is defensible,
   but it makes the ledger only as trustworthy as the binary.
2. **Server derives everything.** Needs `user_lesson_quiz_answers` to be
   reliable. It is not: those writes are fire-and-forget `try?`
   ([LessonQuizFlowView.swift:211-227](../../Wingman/Lesson/LessonQuizFlowView.swift#L211-L227))
   and the table holds 11 rows across 4 users.
3. **Client sends facts, server computes the amount.** The client passes
   `correct_count` and `question_count`; the rules table holds the formula
   components and the server does the arithmetic. Amounts stay server-owned and
   tunable without a release, the client never names a number, and the trust
   assumption is identical to the one `update_daily_practice_streak` already
   makes. It also kills the `XPSource.optimisticAmount` drift problem for the
   flat sources.

### Revised sequencing

| | Work | Status |
|---|---|---|
| **1b** | Reshape the award mechanism for computed amounts; wire the approach hook | **new, do first — free today** |
| **2b** | Plumb `correctCount` + `questionCount` to the lesson award site | small, 2 files |
| **3** | UI: completion screens, Home, Profile, **levels**, daily-goal ring | as planned, plus levels |
| **5** | Streak widening | **much cheaper** — §3, no new table |

Levels need **no storage**. They are a pure derivation from the total that
`get_xp_summary()` already returns. Storing a level column would be a
denormalisation that can silently disagree with the ledger. Display it on
Profile next to `WeekStreakCard`
([ProfileView.swift:149-155](../../Wingman/Profile/ProfileView.swift#L149-L155)).

## 5. The economy problem in your new numbers

Worth settling before anything is built, because it decides what a level means.

With approach at **50 flat** and the original **250/day cap**, that is 5
approaches per day:

- One day of capped approach logging: **250 XP**.
- One day of everything else, played perfectly: 30 (daily practice) + one new
  lesson (40) + one new scenario (50) = **120 XP**.
- The whole level ladder, 0 → 4,000, is **16 days** of capped approach logging.

Total XP available from all finite content: 94 lessons at 20–40 plus 15
scenarios at 50 = **2,630 – 4,475**. So a perfect player just clears level 10
from content alone; an average one does not, and needs daily practice or
approaches.

**The consequence: levels would mostly measure approaches logged**, which is the
one self-reported, ungated action in the app. That may be exactly what you want
— the audit found approach logging is the app's core value action and the thing
every retention cohort should care about. But it should be a decision, not a
side effect of the cap.

The **30 XP daily goal** has the same issue: one approach is 50, so the goal is
met by a single self-reported line of text, while a perfect 5-question Daily
Practice hits exactly 30.

---

## Open decisions

1. **Who computes the amount** (§4). Recommend option 3.
2. **Scenario flat amount.** You said "same XP" but not which. `xp_rules`
   currently seeds `scenario = 50`; the original spec implied 35–60. Pick one.
3. **Approach daily cap.** 50 flat with the old 250 cap = 5/day. Confirm or
   change.
4. **Daily goal vs approach value** (§5) — 30 is met by one approach.
5. **Streak day marker**: derive from the XP ledger (free, but replays of
   finished content mark nothing) or from completion events (needs the small
   table plan §9.1 described).
6. **Lesson streak trigger**: viewed or completed. Recommend completed.
