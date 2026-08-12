# XP Spec — Feasibility Diagnosis

Audit only. No code was written or changed; no schema is proposed here.
Verified against branch `Shat` and live project `bnckmgnysfliiypvxxii` on
2026-08-12, with the XP ledger from migration `20260811161839_xp_ledger.sql`
in place.

---

## Verdict

**The spec is not implementable against what exists today. Zero of the four
activities can be expressed by the current award mechanism, and one of them
depends on a thing that does not exist at all.**

Two findings block everything else. Neither is a reason to abandon the spec —
both are additive gaps rather than contradictions — except item 3, which
requires inventing a measurement the app has never taken.

---

## Blocker A — The award mechanism has no way to express a variable amount

`public.award_xp` takes exactly three arguments:

```
award_xp(p_source_type text, p_source_id text, p_local_date date)
  RETURNS TABLE(awarded boolean, amount_awarded integer, total_xp integer)
```

There is no amount parameter. The amount is looked up server-side from
`public.xp_rules.amount`, which holds **one flat integer per source type** —
currently `daily_practice=20, lesson=30, scenario=50, approach=40`.

This is deliberate, and it is the property that stops a tampered client from
awarding itself anything: the caller controls neither who is credited nor how
much (`supabase/migrations/20260811161839_xp_ledger.sql`, "WHY SECURITY DEFINER
HERE IS NOT THE SAME MISTAKE").

**Every one of the four activities in this spec awards a computed, variable
amount.** Daily practice ranges 10–30, lesson 20–40, scenario 35–60, approach
25–100 plus bonuses. None of these can be produced by a constant per source
type. The client mirror `XPSource.optimisticAmount`
([XPSource.swift:34-41](../../Wingman/XP/XPSource.swift#L34-L41)) is likewise a
single integer per case.

So the spec's economy and the shipped mechanism are structurally different
shapes. That is the first thing to resolve, and it is a decision about *who
computes the amount* — which is a security decision, not a plumbing one.

## Blocker B — The scenario "existing performance grade" does not exist

Spec item 3 says "0–25 XP scaled to the existing performance grade." **There is
no performance grade, score, or attempt count for scenarios anywhere in the
codebase or the database.**

What I checked:

- `public.user_scenario_progress` columns: `id, user_id, scenario_id,
  current_screen_id, is_completed, started_at, last_played_at, completed_at`.
- `public.user_scenario_completions` columns: `id, user_id, scenario_id,
  completed_at`.
- A query for columns matching `score|grade|attempt|correct|mistake|rating` on
  those two tables returns **0**.
- `PracticeGameViewModel` ([PracticeGame.swift:23-278](../../Wingman/PracticeGame/PracticeGame.swift#L23-L278))
  holds `progress`, `currentSceneId`, `pendingSelection`, `gameCompleted`. There
  is no right/wrong counter. The only occurrences of "grade" in the file are
  comments about the per-tap haptic ([:169](../../Wingman/PracticeGame/PracticeGame.swift#L169),
  [:694](../../Wingman/PracticeGame/PracticeGame.swift#L694),
  [:745](../../Wingman/PracticeGame/PracticeGame.swift#L745)).
- `GameCompleteView` ([PracticeGame.swift:753-787](../../Wingman/PracticeGame/PracticeGame.swift#L753-L787))
  takes exactly one parameter: `onContinue`.

**And it cannot be derived after the fact, because of how scenarios are built.**
A wrong option routes into a fail branch whose `retryTargetScreenId` returns the
user to the same decision
([PracticeGame.swift:218-229](../../Wingman/PracticeGame/PracticeGame.swift#L218-L229)).
Every completed scenario therefore ends with the correct option chosen at every
decision — **completion is 100%-correct by construction**. A grade would have to
measure first-attempt correctness or attempt count, and neither is persisted:
`pendingSelection` is transient in-memory state
([PracticeGame.swift:171-191](../../Wingman/PracticeGame/PracticeGame.swift#L171-L191)).

Complicating any future grading: of 95 decision screens, **88 have exactly one
correct option and 7 have more than one** (`public.screen_options.is_correct`,
103 correct rows of 276 total).

---

## Item 1 — Daily practice: 10 + 3/correct + 5 if 5/5 (range 10–30)

**Arithmetically sound and the inputs all exist. Only Blocker A stands in the
way.**

- **5 questions is real.** `generate_daily_question_set` returns
  `selected_questions[1:LEAST(array_length(...), 5)]`, and all 59 rows in
  `public.daily_question_sets` have `array_length(question_ids,1) = 5`. The
  client treats `count >= 5` as complete
  ([DailyPracticeServiceProtocol.swift:246-247](../../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift#L246-L247)).
- **Correct count is available at the award site.** `engine.correctCount` is
  read in the `.finished` branch
  ([DailyPracticeViewModel.swift:153](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L153)) —
  the same line the XP hook already sits beside. Counting is first-answer-wins
  ([DailyPracticeViewModel.swift:20-21](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L20-L21)).
- **It is also persisted server-side** as
  `public.user_daily_practice_sessions.correct_answers`, so the amount could be
  computed on either side.
- Range checks out: `10 + 3×5 + 5 = 30` max, `10` min.

## Item 2 — Lesson: 20 + 5/correct + 5 if all correct (range 20–40)

**Three defects, one of them a silent halving.**

1. **The score is discarded before the award site.** `engine.correctCount` is
   read for analytics at
   [LessonQuizFlowView.swift:180](../../Wingman/Lesson/LessonQuizFlowView.swift#L180)
   and then dropped. Both completion callbacks are parameterless:
   `onComplete: () -> Void`
   ([LessonQuizFlowView.swift:36](../../Wingman/Lesson/LessonQuizFlowView.swift#L36))
   and `onContinue: () -> Void`
   ([LessonCompleteView.swift:11](../../Wingman/Courses/LessonCompleteView.swift#L11)).
   At the XP hook ([LessonView.swift:220-233](../../Wingman/Lesson/LessonView.swift#L220-L233))
   the number is not in scope.
2. **Range 20–40 is unreachable for 7 of 94 lessons.** 87 lessons have 3 quiz
   questions; **7 have 2** (`public.questions` grouped by `lesson_id` where
   `lesson_quiz_order is not null`). A 2-question lesson caps at
   `20 + 5×2 + 5 = 35`. Two lessons that both read as "complete" pay differently
   by 5 XP for a reason invisible to the user.
3. **The quiz can be absent entirely, and then the lesson pays a flat 20.**
   `quizQuestions` returns `[]` when `-skipLessonQuiz` is set or
   `featureFlags.lessonQuizEnabled` is false
   ([LessonView.swift:355-364](../../Wingman/Lesson/LessonView.swift#L355-L364)),
   and `LessonQuizFlowView` then starts at `.complete`
   ([LessonQuizFlowView.swift:62](../../Wingman/Lesson/LessonQuizFlowView.swift#L62)).
   A server-side kill switch would silently halve every lesson's XP with no
   other visible symptom.

Server-side scoring is not a workaround: `user_lesson_quiz_answers` is written
fire-and-forget with `try?`
([LessonQuizFlowView.swift:211-227](../../Wingman/Lesson/LessonQuizFlowView.swift#L211-L227)),
and today holds **11 rows across 4 users**.

## Item 3 — Scenario: 35 + 0–25 scaled to grade (range 35–60)

See **Blocker B**. The flat 35 is expressible once Blocker A is resolved. The
0–25 component measures something the app has never recorded and, under the
current retry design, something that is identical for every user who finishes.

## Item 4 — Approach log: 100/60/40/25 tiered, cap 250, +25 reflection, 5-min minimum

**"Ungated" is correct. The other four mechanics are each missing or
mismatched.**

- **Ungated: confirmed.** No paywall or subscription gate appears in
  `LogApproachViewModel.swift`, `LogApproachBottomSheet.swift`, or
  `ApproachService.swift`. (The guest account prompts at 1 and 25 approaches,
  [AuthManager.swift:347](../../Wingman/Auth/AuthManager.swift#L347), are
  prompts, not gates.)
- **"Reflection fields" — there is one, not several.** The sheet has exactly two
  free-text inputs: `title`, a `TextField`
  ([LogApproachBottomSheet.swift:182](../../Wingman/LogApproch/LogApproachBottomSheet.swift#L182)),
  and `notes`, a `TextEditor`
  ([LogApproachBottomSheet.swift:218](../../Wingman/LogApproch/LogApproachBottomSheet.swift#L218)).
  `title` is **required** — it is the sole `canSave` condition
  ([LogApproachViewModel.swift:39-41](../../Wingman/LogApproch/LogApproachViewModel.swift#L39-L41))
  — and its placeholder is "E.g. Approached at Cafe", i.e. a label, not a
  reflection. `notes` is optional and stored as NULL when empty
  ([LogApproachViewModel.swift:235](../../Wingman/LogApproch/LogApproachViewModel.swift#L235)).
  If the 80-character threshold counts `title + notes`, it is satisfiable by
  padding the required label.
- **"Minimum 5 minutes between logs" does not exist.** No cooldown, rate limit,
  interval check, throttle or debounce exists in the logging path (searched
  `Wingman/LogApproch/` and `ApproachService.swift`). It is computable —
  `public.approach_logs.logged_at` exists — but nothing computes it.
- **Tiering by position-in-day is computable but not expressible.** Counting the
  day's logs is a query over `approach_logs.logged_at`; the blocker is again the
  flat amount (Blocker A).
- **The tier is farmable, depending on an unstated detail.**
  `ApproachService.deleteApproach` exists
  ([ApproachService.swift:126](../../Wingman/Profile/ApproachService.swift#L126)),
  and `public.user_xp_events` has **no foreign key to `approach_logs`** — its
  only FK is `user_xp_events_user_id_fkey` to `auth.users`. Deleting an approach
  therefore does not remove its XP. If "Nth of day" is computed from
  `approach_logs` rows (which decrease on delete), the sequence log → earn 100 →
  delete → log → earn 100 repeats indefinitely, bounded only by the 250 cap. If
  computed from ledger rows, it does not. **The spec does not say which.**

---

## Levels: 0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000

**No level concept exists anywhere.** A search of every column in the `public`
schema matching `xp|level` returns three, all false positives:
`approach_logs.approach_level`, `approach_logs.anxiety_level` (both the 1–4 /
1–10 self-report scales) and `questions.explanation` (substring match). No
Swift type, property or view references a user level.

This is the one part of the spec that needs **no storage at all** — levels are a
pure derivation from `total_xp`, which `get_xp_summary()` already returns.

Thresholds are strictly increasing with widening gaps (100, 150, 200, 250, 300,
400, 500, 600, 700, 800). Arithmetically sound.

**Reachability against finite content:** 94 lessons at 20–40 gives 1,880–3,760;
15 scenarios at 35–60 gives 525–900. Combined finite ceiling 4,660, floor 2,405.
Level 10 (4,000) is therefore **not reachable from all lessons and all scenarios
alone at average-or-worse performance** — it requires daily practice (renewable
indefinitely) or approach logs. That may be intended; it is worth knowing it is
load-bearing.

## Daily goal = 30 XP

**Internally inconsistent with item 4.** A single approach log awards 100 — 3.3×
the daily goal — and approach logging is ungated, self-reported, and has no
minimum interval (above). A perfect daily practice awards exactly 30, i.e. the
whole goal for the app's most structured activity, while one self-reported line
of text awards more than three times that.

## Streak milestones: 7 (+50), 14 (+100), 30 (+250), 60 (+500), 100 (+1000)

**Expressible, with two hazards.**

- **The streak value is available at the right moment.**
  `public.user_daily_practice_streaks.current_streak`, surfaced client-side as
  `result.streak`
  ([DailyPracticeViewModel.swift:206](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L206)).
- **Once-per-milestone is already enforceable.** The ledger's
  `user_xp_events_once UNIQUE (user_id, source_type, source_id)` gives exactly
  one bonus per milestone per user, permanently — including for a user who
  breaks a 7-day streak and rebuilds it. That is a product decision the existing
  constraint answers with "no second payout"; the spec does not state an intent.
- **Hazard 1 — the failure path would silently skip milestones.** When the
  streak RPC fails, `DailyPracticeViewModel` sets `currentStreak = 1` and shows
  the completion screen anyway
  ([:187](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L187),
  [:221](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L221),
  [:232](../../Wingman/DailyPractice/DailyPracticeViewModel.swift#L232)), with no
  retry. A genuine 7th day whose write failed reads as 1, and the bonus is lost
  with no record that it was owed.
- **Hazard 2 — proportion.** The 100-day bonus (+1000) is 25% of the entire
  level ladder in a single award.

---

## What exists vs. what does not

| Spec needs | Status |
|---|---|
| Daily practice correct-count at award time | **Exists** — `engine.correctCount`, DailyPracticeViewModel.swift:153 |
| Daily practice = 5 questions | **Exists** — all 59 `daily_question_sets` rows are size 5 |
| Daily practice correctness persisted | **Exists** — `user_daily_practice_sessions.correct_answers` |
| Lesson quiz correct-count at award time | **Does not reach the award site** — dropped at LessonQuizFlowView.swift:180 |
| Lesson quiz question count of 3 for all lessons | **False** — 87 lessons have 3, 7 have 2 |
| Scenario performance grade | **Does not exist** — no column, no property, and 100%-correct by construction |
| Approach ungated | **True** |
| Approach reflection fields (plural) | **One optional field** — `notes`; `title` is a required label |
| Approach ≥80-char measurement | Computable from `approach_logs.notes`; nothing measures it |
| 5-minute minimum between logs | **Does not exist** |
| Approach XP tied to the log row | **No FK** — `user_xp_events` references only `auth.users` |
| Variable award amounts | **Does not exist** — `xp_rules.amount` is one integer per source type |
| Streak value at award time | **Exists** — `result.streak`, DailyPracticeViewModel.swift:206 |
| Once-per-milestone idempotency | **Exists** — `user_xp_events_once` |
| User level | **Does not exist**; needs no storage — derivable from `get_xp_summary()` |
| Any streak analytics event | **Does not exist** — no streak event in `Analytics.Event` |

---

## UNVERIFIED

- **Whether approach logging is reachable without a subscription at every entry
  point.** I confirmed no gate exists inside `LogApproachViewModel.swift`,
  `LogApproachBottomSheet.swift` or `ApproachService.swift`. I did not trace
  every call site that presents the sheet. To settle it: check the presentation
  sites in `HomeView.swift` and `MainTabView.swift` for `SubscriptionGateModifier`
  or a `canOpen…`-style guard.
- **Whether the 7 multi-correct decision screens are authoring errors or
  intentional.** `public.screen_options` has 7 screens with more than one
  `is_correct = true`. To settle it: inspect those 7 screens' options against
  the scenario scripts.
- **What "performance grade" was meant to refer to.** If it refers to something
  a user currently sees, I did not find it; `GameCompleteView` renders a
  checkmark, the title "Game Complete!", and a Continue button, and nothing else.

---

## The three decisions this spec forces, before any implementation

1. **Who computes the amount.** Every activity needs a variable award. Having
   the client send it re-opens the hole the ledger was built to close; having
   the server compute it means the server must be able to see correctness,
   grade, and the day's approach count. That is the central design question and
   the spec does not answer it.
2. **What a scenario grade actually measures**, given that finishing requires
   getting every decision right. Attempts and first-try correctness are the only
   candidates, and neither is recorded today.
3. **Whether approach XP is anchored to the log row or to the ledger**, which
   decides whether the tier is farmable via delete-and-relog.
