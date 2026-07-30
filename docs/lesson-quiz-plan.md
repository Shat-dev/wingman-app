# End-of-Lesson Knowledge Check — Analysis & Implementation Plan

Status: **Planning only — no code changed.** Analysis is based on the committed
state of the repo (branch `Shat`, HEAD `496e672`) plus a live inspection of the
Supabase project `bnckmgnysfliiypvxxii`. The four uncommitted files
(`AuthManager`, `LandingView`, `SettingsSheet`, `WingmanApp`) do not touch
Lesson or DailyPractice, so nothing here plans against stale code.

**Rev 2** — data source changed from bundled JSON to a **new Supabase table
synced into a local cache**, per the decision to keep questions server-editable.
See §2.1. Everything downstream of that (UI reuse, completion gating, progress
storage, rollout) is unchanged from Rev 1.

**Rev 3** — added a `lessons` reference table so `lesson_questions.lesson_id`
carries a real foreign key and the authoring UI can show lesson titles instead of
opaque ids. This removes what §3.4 called the design's structural weak point.

> **Stage 0 is applied.** Migration `create_lesson_questions` ran against
> `bnckmgnysfliiypvxxii` on 2026-07-30: `lessons` (94 rows), `lesson_questions`
> (empty), and the `lesson_question_status` authoring view. Source of truth is
> [`supabase/migrations/20260730000000_create_lesson_questions.sql`](../supabase/migrations/20260730000000_create_lesson_questions.sql).
> Content authoring can begin; all remaining stages are client-side.

---

## 1. Analysis of the Current Implementation

### 1.1 How lessons are structured

Three nested `Codable` structs in [`Wingman/Lesson/Lesson.swift`](../Wingman/Lesson/Lesson.swift):

```
Lesson   id, courseId, courseSummary?, courseTitle, lessonNumber,
         title, duration, summary, isCompleted, isLocked, screens[]
  └ LessonScreen   id, order, content[]
      └ LessonContent   id, text, order
```

Lesson **prose** is 100% local and offline. [`LessonDataService`](../Wingman/Lesson/LessonDataService.swift)
loads from 25 bundled JSON files via a hardcoded `courseJsonMapping`
(`courseId` → filename, `LessonDataService.swift:34-69`). All 25 files live under
`Wingman/Courses/Wingman Lessons/Approach Mechanics/` — the folder name is
misleading, it holds every category, not just Approach Mechanics.

Scale: **94 lessons, 602 screens, 476 KB of JSON.** Results are cached per
course in `lessonsCache`.

The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (project.pbxproj:40-49),
so **new files on disk are picked up automatically** — no `.pbxproj` surgery.

Lesson ids are stable strings of the form `lesson_<course>_<n>` (`lesson_1_1`,
`lesson_1_2`, …). **These are the join key to the new questions table** (§2.2).

> **Dead code:** [`LessonViewModel.swift`](../Wingman/Lesson/LessonViewModel.swift)
> is never instantiated anywhere. `LessonView` reimplements the same
> screen/content navigation in `@State`. Do not "add the quiz to the view model"
> assuming it's live — it isn't. Delete it as part of this work (§5.2).

### 1.2 How lesson completion is currently handled

The whole flow lives in [`LessonView.swift`](../Wingman/Lesson/LessonView.swift),
not in a view model:

1. `goForward()` walks `currentContentIndex` within a screen, then
   `currentScreenIndex` across screens (`LessonView.swift:245-289`).
2. On the last content of the last screen it fires `HapticManager.shared.success()`,
   captures the `lesson_completed` PostHog event with `duration_seconds`, and sets
   `showLessonComplete = true`.
3. That drives a **`.fullScreenCover`** presenting
   [`LessonCompleteView`](../Wingman/Courses/LessonCompleteView.swift) (`LessonView.swift:177-190`).
4. Only when the user taps **Continue** does
   `LessonDataService.markLessonCompleted(lessonId:courseId:)` run, followed by
   `tabBarVisibility.showTabBar()` and `dismiss()`.

`markLessonCompleted` (`LessonDataService.swift:149-182`) then:
- mutates `lessonsCache`, setting `isCompleted` and unlocking `index + 1`;
- persists to `UserDefaults` under **per-user namespaced keys**
  (`completed_lessons_<userId|anonymous>_<courseId>`);
- fire-and-forget syncs the **full** progress dict to Supabase
  `user_metadata.lesson_progress` (last-write-wins, union-merged on hydrate);
- posts `.lessonCompleted` so `CoursesViewModel.progressVersion` bumps and
  course-lock state re-derives.

> **Pre-existing defect worth fixing while we're here:** `lesson_completed`
> analytics fires at step 2, but persistence happens at step 4. Force-quit on
> the completion screen ⇒ PostHog says completed, progress says not. Inserting a
> quiz between those two points widens that window from ~2 seconds to ~60. See §7.4.

### 1.3 How Daily Practice is implemented

Four files under [`Wingman/DailyPractice/`](../Wingman/DailyPractice/):

| File | Lines | Role |
|---|---|---|
| `DailyPracticeView.swift` | 692 | All UI, all styling, all colour logic |
| `DailyPracticeViewModel.swift` | 445 | Question state machine + daily/streak side effects |
| `DailyPracticeServiceProtocol.swift` | 448 | Supabase RPCs, models, error enum |
| `QuestionsCompleteView.swift` | 105 | Streak celebration screen |

**Flow:** `HomeView` sets `navigateToPractice = true` → `navigationDestination`
pushes `DailyPracticeView` → `loadTodayQuestions()` calls the
`get_or_create_daily_questions` RPC (5 questions/day) → per question the user
selects, taps **Check Answer**, sees a green/red explanation panel with a
**Next** button → each check POSTs a row to `user_question_completions` →
after the last question `update_daily_practice_streak` runs, `showCompletionView`
flips, and `QuestionsCompleteView` is pushed → **Continue** posts
`NavigateToHomeView` and calls the `onCompletionDismiss` closure that unwinds the
whole stack (needed because `@Environment(\.dismiss)` is a no-op once a child is
pushed on top).

Notable existing quality in the view model worth preserving: `questionStates`
keyed by question id preserves answers across back-nav, and `countedQuestionIds`
gives first-answer-wins dedup so back-nav can't inflate the streak counts.

### 1.4 Can Daily Practice components be reused?

**The interaction model, yes — that's the whole point. The code as written, no.
Roughly 350 of `DailyPracticeView`'s 692 lines are `private` methods inside the
view struct:**

- `singleSelectOptionButton(...)`, `multipleSelectOptionButton(...)`, `checkboxView(...)`
- Six colour resolvers: `buttonTextColor`, `buttonBackgroundColor`, `buttonBorderColor`,
  `multipleSelectTextColor/BackgroundColor/BorderColor`, plus two checkbox variants
- `explanationViewWithButton()`, `actionButton()`, `progressBar(progress:)`
- `questionContentView()` — the scroll + question + options composition

Every one of these reads `viewModel` directly, so they're bound to
`DailyPracticeViewModel` by type, not just by data.

The view model is likewise fused to daily semantics: `loadTodayQuestions()`,
`updateDailyPracticeStreak()`, `showCompletionView`, the `.dailyPracticeCompleted`
notification, and `submitCompletion` writing to `user_question_completions`.

**But the state machine underneath is genuinely generic** — `selectOption`,
`checkAnswer`, `nextQuestion`/`previousQuestion`, `questionStates`,
`isOptionSelected/Correct/Incorrect`, `shouldShowCorrectButNotSelected`,
`progress`, `isCheckAnswerEnabled`, `isLastQuestion`. About 200 lines that have
nothing to do with "daily".

**Conclusion: extract, don't fork.** Forking gives two 350-line copies of
option-button styling that will drift within a release.

### 1.5 Backend: what exists today

Supabase project `bnckmgnysfliiypvxxii`, `public` schema:

| Table | Rows | Relevance |
|---|---|---|
| `questions` | 757 | Daily Practice pool. Tagged by `module` enum only |
| `user_question_completions` | 245 | One row per answered DP question. FK → `questions.id` |
| `daily_question_sets` | 54 | Which 5 questions a user got on a date |
| `user_daily_practice_sessions` | 49 | One row per completed day |
| `user_daily_practice_streaks` | 11 | current/longest/total, `last_completed_date` |

The `questions` table has **no lesson or course column**. Its `module` enum
(`mindset_foundations`, `approach_mechanics`, `conversational_skills`,
`flirting_chemistry`, `mastery_integration`) maps to the five *course
categories*, not to individual lessons. So the existing 757 questions are
category-level, and can't satisfy "related to this lesson's content" as-is —
though they are useful as **seed drafts** (§2.5).

Sizing, measured: `questions` averages **379 bytes/row**, 280 kB for 757 rows.

RLS is uniform: `questions` is readable by `authenticated`; every `user_*` table
is `auth.uid() = user_id` scoped. Guest/anonymous sessions carry the
`authenticated` role, so they pass.

`questions` uses the `update_updated_at_column()` trigger function (two exist in
this project — `set_updated_at()` is used by the scenario tables; match
`questions` for consistency).

### 1.6 Why lesson questions need their own table

Three concrete failure modes if lesson quizzes ride on the **existing** rows.
All three are silent. **All three are avoided by the separate-table design in
§2.1 — this section exists so nobody "simplifies" back into them later.**

**(a) It would burn the Daily Practice question pool.**
`generate_daily_question_set` calls `get_excluded_question_ids(p_user_id)`, which
returns *every* `question_id` in `user_question_completions` from the last 90
days, and excludes them from the daily draw. 94 lessons × 3 questions = **282 of
757 questions (37%) permanently removed from Daily Practice** for anyone working
through the courses.

**(b) It would falsely mark Daily Practice complete.**
`DailyPracticeService.getDailyPracticeStatus()` does **not** trust the RPC's
`is_completed_today`. It overrides it with a client-side
`checkTodayCompletionFromQuestions()` that counts `user_question_completions`
rows for today and returns `count >= 5` (`DailyPracticeServiceProtocol.swift:294-310`,
`:319-347`). Two lesson quizzes in a day = 6 rows ⇒ **Home shows Daily Practice
as "Completed", the Start button is disabled, `canResume` is false.** The user
silently loses that day's practice and their streak.

**(c) It isn't possible anyway.**
`user_question_completions.question_id` carries an FK to `questions.id`.

> **Standing constraint:** lesson questions live in their own table, and lesson
> quiz answers are **never** written to `user_question_completions`. Nothing on
> the lesson path may call `update_daily_practice_streak` or write
> `user_daily_practice_sessions`.

### 1.7 Existing progression systems and what depends on lesson completion

There is **no XP system and no achievements system** in the codebase. The
surfaces that read lesson completion are:

1. **Next-lesson unlock** — `markLessonCompleted` unlocks `index + 1` in the same course.
2. **Next-course unlock** — `CoursesViewModel.isCourseProgressionUnlocked` requires
   `LessonDataService.isCourseCompleted(previousCourse)`, i.e. *all* its lessons done.
3. **Practice Scenario unlock** — `PracticeService.fetchPractices` (`PracticeServiceProtocol.swift:111,140`)
   compares `LessonDataService.totalLessonsCompleted()` against each scenario's
   `required_lessons_completed`. Live thresholds: 0, 1, 2, 3, 5, 7, 10, 13, 16,
   20, 24, 28, 32, 36, **40**.
4. **Home "Continue" card** — progress ring = completed / total lessons.
5. **Analytics** — `lesson_started` / `lesson_completed` in PostHog.

Streaks are driven **only** by `update_daily_practice_streak`, called **only**
from `DailyPracticeViewModel.nextQuestion()`. Untouched by lessons today; must
stay that way.

---

## 2. Design Decisions

### 2.1 Where do the questions live? → **New Supabase table, synced to a local cache**

The requirement is: curate questions per lesson, edit them without shipping an
App Store release, and don't break the fact that lessons work offline today.

Those pull in opposite directions, and the resolution is **not** "fetch when
needed" — it's **"fetch everything once, then never need the network again."**

| Option | Verdict |
|---|---|
| **A. New `lesson_questions` table, full set cached on device** | ✅ **Chosen** |
| B. New table, fetch per lesson at lesson start | ⚠️ Works, strictly worse than A |
| C. Bundled JSON inside the lesson files | Offline-perfect, but needs a release per edit |
| D. Reuse the existing `questions` table | ❌ §1.6 |

**Why A over B.** Fetching at lesson start is a reasonable instinct — the user
reads for 3–5 minutes, which is ample time for a 3-row query. But it means **94
network round trips** over a user's lifetime, each one an independent chance to
fail, and each failure lands *precisely at the completion gate* — the single
worst place to put an error state.

Fetching the whole table once costs, on measured row size, **282 × 379 B ≈ 107 kB**
(~40 kB gzipped, which Supabase serves by default). One request. After it lands:

- every quiz is served from disk, so **offline works permanently**, not just for
  the lesson you happened to open with signal;
- the network call happens at launch, nowhere near the completion gate;
- content is still edited in Supabase and reaches users with no App Store release.

Even at 10× the question count this is a ~1 MB payload. There is no scale at
which per-lesson fetching wins.

**Why A over C.** C was Rev 1's recommendation and is still the most robust
option on pure offline grounds — but it makes every typo a release. Server-side
editing is worth the sync layer, and A gets offline back after first launch. The
one thing C has that A doesn't is **day-one offline on a fresh install** (§2.4).

### 2.2 Schema

**Two tables.** `lesson_questions` mirrors `questions` so the decoding path, the
option/answer semantics, and the shared UI are identical. `lessons` is reference
data mirrored from the bundled JSON — it exists for two reasons, both of which
turned out to matter more than expected:

1. **It gives `lesson_id` a real foreign key.** Rev 2 had `lesson_id` as bare
   text, because lessons live in JSON rather than the database — which meant a
   typo like `lesson_11` produced orphan rows and one silently quiz-less lesson,
   caught only by a validation query somebody had to remember to run. With a
   `lessons` table, Postgres rejects it outright.
2. **It makes the table legible for authoring.** `lesson_id = 'lesson_1_1'` says
   nothing. Joined against `lessons` you get "Beliefs & Reframes › 1 › You are
   not your thoughts", which is what the `lesson_question_status` view surfaces.

```sql
create table public.lessons (
  lesson_id      text primary key,   -- 'lesson_1_1' — matches the bundled JSON ids
  course_id      text    not null,   -- 'course_1'
  category_id    text    not null,   -- 'cat_1'
  category_name  text    not null,   -- 'Mindset & Foundations'
  course_title   text    not null,   -- 'Beliefs & Reframes'
  lesson_number  integer not null,
  lesson_title   text    not null,
  constraint lessons_unique_number unique (course_id, lesson_number)
);

create table public.lesson_questions (
  id                      uuid primary key default gen_random_uuid(),
  lesson_id               text        not null
                            references public.lessons(lesson_id)
                            on update cascade on delete restrict,
  question_number         integer     not null,   -- 1..3, ordering within the lesson
  question_type           public.question_type not null,  -- reuses the EXISTING enum
  question_text           text        not null,
  options                 jsonb       not null,
  correct_answer_index    integer,                -- single_select
  correct_answer_indices  integer[],              -- multiple_select
  explanation             text        not null,
  is_published            boolean     not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
```

Deliberate choices:

- **`question_type` is the existing `public.question_type` enum**, not a new one.
  Same two values, same wire format, so `LessonQuestionRow` and `SupabaseQuestion`
  decode identically and one Swift struct serves both (§2.3).
- **`course_id` lives on `lessons`, not on `lesson_questions`.** Rev 2
  denormalised it onto every question row; with the join available it's redundant
  and would drift.
- **`on delete restrict`** — you cannot remove a lesson from `lessons` while
  questions still point at it. Deliberate: it forces the questions to be dealt
  with rather than silently orphaned.
- **`lessons` is seeded from the JSON, not hand-typed**, and the seed is
  `on conflict do update`, so re-running it after a lesson is renamed refreshes
  the titles without touching questions.
- **No completions table.** Per §2.6, quiz results aren't persisted. If quiz
  analytics are wanted later, that's a *new* `user_lesson_quiz_attempts` table —
  never `user_question_completions`.

Full DDL including constraints, indexes, RLS, trigger and the authoring view is
in §5.4, and applied.

### 2.3 One concrete model, not a protocol

Rev 1 proposed a `QuizQuestion` protocol because the two sources had different
shapes. With `lesson_questions` mirroring `questions`, they don't. So:

- **One concrete struct**, `QuizQuestion` (id, number, question, options,
  questionType, correctAnswerIndex?, correctAnswerIndices?, explanation).
- `DailyPracticeService` maps `SupabaseQuestion` → `QuizQuestion`.
- `LessonQuestionStore` maps `LessonQuestionRow` → `QuizQuestion`.
- `QuizEngine` and `QuizQuestionView` know only `QuizQuestion`.

`id` becomes `String` rather than `UUID`, since both sources have real UUIDs but
the engine has no reason to care. `DailyPracticeViewModel.submitCompletion` still
needs a `UUID` for its FK write — it reconstructs one from the string at the
service boundary, which is the only place that FK is relevant.

This is simpler than Rev 1: one type, no existentials, no generics in the engine.

### 2.4 Sync and cache design

Model it on [`StreakStore`](../Wingman/DailyPractice/StreakStore.swift), which is
already the house pattern for "remote state with a local cache that must never
regress on failure."

**`LessonQuestionStore`** (singleton, `@MainActor`, `ObservableObject`):

- **Cache location:** a JSON file in Application Support. ~107 kB is above what
  belongs in `UserDefaults`. There is currently **no file-caching helper anywhere
  in the codebase** — everything uses `UserDefaults` — so this is ~15 new lines
  and the first of its kind. Keep it boring: `Data` → `FileManager` → atomic write.
- **Not user-namespaced.** These are global content rows, not user data. Do not
  copy the `completed_lessons_<userId>_<courseId>` namespacing from
  `LessonDataService`, and do not clear the cache on logout — that would force a
  re-download for no reason.
- **Refresh check:** `select updated_at order by updated_at desc limit 1`. One
  row. If it's newer than the cached watermark, pull the full published set;
  otherwise do nothing. Most launches cost one tiny query.
- **Failure policy:** keep last-known-good, never wipe — exactly StreakStore's
  rule. A failed refresh must never empty the cache and silently disable quizzes.
- **Where to call it:** alongside `LessonDataService.hydrateLessonProgressFromCloud()`
  in the auth state handler (`AuthManager.swift:528` for `.signedIn`, and the
  `.initialSession` path at `:687`). That placement inherits the guarantee that a
  session exists, which RLS requires. Calling it earlier — e.g. from `RootView`'s
  `.task` at `WingmanApp.swift:343` — would race auth bootstrap and 401 on cold
  start.

**Cold-start behaviour:** fresh install with no network ⇒ empty cache ⇒ no
questions ⇒ lessons complete exactly as they do today (§2.7). This is the one
capability bundled JSON would have had and this design doesn't. Judged
acceptable; the mitigation, if it ever matters, is shipping a seed snapshot in
the bundle and treating the table as an override — deferred, not designed out.

### 2.5 Curating the content

282 questions (94 lessons × 3) is the real cost of this project, not the code.
Two ways to fill the table, and they combine:

1. **Author fresh per lesson.** Highest quality — questions written against the
   specific prose. Slowest.
2. **Seed from the existing 757, then edit.** `INSERT … SELECT` from `questions`
   filtered by the module matching the lesson's category gives a plausible draft
   per lesson. Editing beats a blank page.

If seeding: **copy the rows, do not reference `questions.id`.** A reference
would re-couple the two systems the moment anyone adds completions tracking, and
walks straight back into §1.6.

Treat seeded rows as raw material — they were written to test a broad category,
not a specific lesson — and gate them behind `is_published = false` until
reviewed.

Authoring surface is the Supabase dashboard table editor. Workable for 282 rows,
tedious. A CSV import per course is faster if the questions get drafted in a
spreadsheet first.

### 2.6 How is progress stored? → **It already is. Add nothing.**

"Lesson completed" already means "reached the end". After this change it means
"reached the end *and* passed the check". Same flag, stronger meaning:

- **No new tables**, beyond `lesson_questions` itself.
- **No new UserDefaults keys**, no additions to the `lesson_progress`
  `user_metadata` blob, so `hydrateLessonProgressFromCloud`'s merge is untouched.
- **No mid-quiz persistence.** Attempt state stays in memory, exactly like Daily
  Practice, which also doesn't persist partial sessions. Abandon the quiz, the
  lesson stays incomplete, re-read and retry.

A separate `quiz_passed` flag would be strictly redundant with `isCompleted`,
because passing is the only way to become completed. Quiz *performance* is an
analytics question → PostHog events (§4.5).

### 2.7 Pass criteria → **Completion-gated, not score-gated (v1)**

A genuine product decision the brief leaves open, and it changes scope.

- **Recommended for v1: answer all questions to pass.** Wrong answers show the
  same red explanation panel Daily Practice already shows, then **Next**.
  Reaching the end passes. Mirrors Daily Practice (which has no pass mark), needs
  no retry loop, no fail screen, no dead ends. It still delivers the actual
  benefit — active recall plus immediate corrective feedback.
- **Alternative: score threshold** (e.g. 2 of 3) with retry. A small delta *if*
  the engine carries a `passThreshold` from day one, a painful retrofit if not.
  So: **build the threshold into the engine's API, ship v1 with it set to "all
  answered".** Turning it on later is one line plus a fail screen.

**Zero-question fallthrough is mandatory, not a nicety.** A lesson with no rows
in `lesson_questions` — un-authored content, or a cold cache — must complete
exactly as it does today. This is what makes both per-course content rollout and
offline-first-launch survivable (§7.1).

### 2.8 Presentation → **One `.fullScreenCover`, quiz then completion**

`LessonCompleteView` is presented today via `.fullScreenCover` from `LessonView`.
Keep that mechanism, change what the cover contains:

```
LessonView.goForward() on last content
   └─ .fullScreenCover(isPresented: $showEndOfLesson)
        └─ LessonQuizFlowView                    ← new, owns an internal state machine
             ├─ .intro   "Knowledge Check"       (skipped when there are no questions)
             ├─ .question(0…n)                   ← shared QuizQuestionView
             └─ .complete → LessonCompleteView   ← existing view, unchanged
```

Why a cover rather than a navigation push like Daily Practice:

- `LessonView` sits inside **two different** `NavigationStack`s depending on
  entry point (Courses → CourseDetail → lesson, or Home Continue → CourseDetail →
  lesson). A cover behaves identically in both; a push does not.
- It sidesteps the problem Daily Practice worked around with `onCompletionDismiss`
  — `@Environment(\.dismiss)` going dead once a child is pushed on top
  (`DailyPracticeView.swift:17-22`).
- `fullScreenCover` has no swipe-to-dismiss, so the quiz can't be escaped mid-answer.
- `LessonCompleteView` and its `onContinue` contract stay **byte-identical**.

**Header:** the brief asks for the lesson/course name up top so it's obvious the
user is still inside the lesson. `LessonView` currently shows `lesson.title` at
the *bottom*; in the quiz there's no reading content competing for space, so put
`lesson.courseTitle` as a small label above `lesson.title`, beneath the progress row.

**Progress bar:** carry the lesson's bar into the quiz — reading fills 0→80%, the
quiz fills 80→100%. Cheap, and it reinforces "still inside the lesson".

---

## 3. Feasibility

### 3.1 Complexity: medium; mostly refactor plus one small sync layer

Nothing architecturally novel. The two non-trivial pieces are extracting reusable
components out of a 692-line view, and a cache-backed store that the codebase has
no precedent for (but which is ~15 lines of `FileManager` around an existing
Supabase fetch pattern).

### 3.2 Effort

| Phase | Work | Estimate |
|---|---|---|
| 1 | Extract `QuizQuestionView` + colour logic from `DailyPracticeView`, no behaviour change | 0.5–1 d |
| 2 | Extract `QuizEngine` + `QuizQuestion`; DP delegates to it | 0.75–1 d |
| 3a | Migration, RLS, indexes, validation + seed queries | 0.5 d |
| 3b | `LessonQuestionStore` — fetch, cache to disk, watermark refresh, failure policy | 0.5–1 d |
| 3c | `LessonQuizFlowView`, `LessonView` wiring, feature flag | 1.5–2 d |
| 4 | Analytics, debug skip toggle | 0.25 d |
| 5 | QA: DP regression, lesson flow, cache/offline matrix | 1–1.25 d |
| | **Engineering total** | **~5–7 days** |

Roughly half a day more than the bundled-JSON version, bought in exchange for
server-side editing.

**Content is still the critical path.** 282 questions; ~10–20 hours with seeding
(§2.5), 15–25 without. Pilot one course before funding the rest (§5.5, Stage 0).

### 3.3 Performance

- **One HTTP request at launch**, conditional on a one-row watermark check. Most
  launches: one tiny query, no payload.
- **~107 kB** cached on disk, ~40 kB gzipped over the wire, parsed once per
  refresh rather than per lesson.
- **Zero network at quiz time.** Opening a quiz is a dictionary lookup by
  `lesson_id` against an in-memory map hydrated from the cache file.
- **No new DB round trips per lesson**, no new writes, no new RPCs.
- Adjacent inefficiency this doesn't cause but sits next to:
  `CourseDetailSheet.loadLessons()` calls `LessonDataService.shared.clearCache()`
  on **every** `.onAppear` (`CourseDetailSheet.swift:180`), so every course visit
  re-parses that course's whole JSON, defeating the cache entirely. Cheap fix,
  separate change.

### 3.4 Architectural concerns

1. **`DailyPracticeView` is already past a maintainable size** at 692 lines with
   ~350 in private view builders. Extraction is overdue independent of this
   feature; this feature makes it pay off twice.
2. **`lessons` duplicates the bundled JSON.** Rev 3 traded a missing foreign key
   for a copy that can go stale — a strictly better trade (the schema now
   enforces referential integrity, and a stale copy fails loudly at insert time
   rather than silently at read time), but the copy still has to be re-seeded
   when lesson ids change. The seed is idempotent and generated from the JSON, so
   this is a checklist item, not a design flaw. §7.8.
3. **Two content systems for one screen** — prose from the bundle, questions from
   the network. A lesson edited in JSON and a question edited in Supabase can
   drift out of sync with no diff showing both. §7.7.
4. **`LessonViewModel` is dead code** sitting next to the file we're editing.
   Delete it, or someone will put quiz logic in it.

### 3.5 Should this be built now?

**Yes — behind a feature flag, piloted on one course.**

Engineering risk is low. The **product risk is real and worth naming**: this adds
mandatory friction to the single path that drives next-lesson unlock, next-course
unlock, all 15 scenario unlocks (up to 40 lessons), and the Home progress card.
If lesson completion rate drops 15%, everything downstream slows by 15%, in a
paid app where that ladder *is* the retention loop.

That's not an argument against the feature — active recall genuinely improves
retention and the engagement case is sound. It's an argument for measuring
instead of assuming:

- **Ship behind `lesson_quiz_enabled` in PostHog.**
  [`FeatureFlags`](../Wingman/Util/FeatureFlags.swift) already exists for exactly
  this and has the kill-switch-vs-enable-switch idiom worked out. Watch
  `lesson_completed` per `lesson_started`, before vs after.
- **Keep v1 completion-gated** (§2.7) so first-read friction is minimal.
- **Author one course (5 lessons, 15 questions) first**, ship to the flagged
  cohort, then decide whether to fund the remaining ~267.

The server-side table makes the pilot materially cheaper than the JSON version
would have: adding a course's questions is an insert, not a release. That's the
main practical dividend of this decision.

---

## 4. Impact on Existing Systems

| System | Impact |
|---|---|
| **Streaks** | **None** — nothing on the lesson path calls `update_daily_practice_streak` or writes `user_daily_practice_sessions`. |
| **XP / achievements** | None exist. No impact. |
| **Daily Practice** | **None functionally** — separate table, separate rows, no writes to `user_question_completions`, daily pool untouched. But refactor phases 1–2 edit DP code, so it needs a full regression pass regardless. |
| **Next-lesson unlock** | Mechanism unchanged. Reached less often. |
| **Next-course unlock** | Mechanism unchanged (`isCourseCompleted`). Reached less often. |
| **Scenario unlock** | Same. Thresholds 0→40 all shift later in wall-clock terms. Consider re-tuning after measuring. |
| **Home Continue card** | Progress ring advances more slowly. Cosmetic. |
| **Lesson progress cloud sync** | Untouched — no new keys in the `lesson_progress` blob. |
| **App launch** | One extra one-row query, non-blocking, on the existing auth-state path. |
| **Analytics** | `lesson_completed`'s meaning changes. §4.5. |
| **Free-demo flow** | `markFreeDemoCompleted()` is currently **called from nowhere** outside `AuthManager` — the "1 scenario + 1 lesson spent" demo is only half-wired. When it is wired, the lesson-spend hook must fire at the same point as `markLessonCompleted`, i.e. **after** the quiz, or the demo gets spent by someone who never finished a lesson. |

### 4.5 Analytics

Keep `lesson_completed` firing at the moment completion is actually **persisted**
(§7.4), not when the reading ends. Its meaning legitimately becomes "read and
passed"; annotate the release in PostHog so the funnel step-change is explained
rather than investigated.

Add to `Analytics.Event` in [`Analytics.swift`](../Wingman/Util/Analytics.swift):

```
lesson_quiz_started    { lesson_id, lesson_name, category, question_count }
lesson_quiz_completed  { …, correct_count, question_count, duration_seconds }
lesson_quiz_abandoned  { …, questions_answered }     ← the friction signal
lesson_quiz_unavailable{ lesson_id, reason: "no_questions" | "cache_empty" }
```

`lesson_quiz_abandoned` is the number that decides whether the flag stays on.
`lesson_quiz_unavailable` is how you find un-authored lessons and cold-cache
users in the wild — without it, the fallthrough in §2.7 is invisible.

---

## 5. Implementation Plan

### 5.1 New files

| File | Purpose |
|---|---|
| `Wingman/Quiz/QuizQuestion.swift` | One concrete struct used by both features (§2.3). |
| `Wingman/Quiz/QuizEngine.swift` | `ObservableObject`. Generic state machine lifted from `DailyPracticeViewModel`: index, selection, check, next/previous, `questionStates`, `countedQuestionIds`, `progress`, `isCheckAnswerEnabled`, `isLastQuestion`, `correctCount`, `passThreshold`. **No** networking, **no** streaks, **no** notifications. |
| `Wingman/Quiz/QuizQuestionView.swift` | The extracted UI: question header, "Select all that apply" hint, single/multi option buttons, checkbox, all colour resolvers, explanation panel, Check/Next button. Driven by a `QuizEngine`. Pixel-identical to today's Daily Practice. |
| `Wingman/Quiz/QuizProgressBar.swift` | The chevron + capsule row, currently duplicated three times (`DailyPracticeView:48-74`, `DailyPracticeView.progressBar`, `LessonView:88-118`). Same geometry: 44×44 chevron, 10 pt capsule, `.leading 8 / .trailing 59`. |
| `Wingman/Lesson/LessonQuestionStore.swift` | Fetch + disk cache + watermark refresh + `questions(forLessonId:)` lookup (§2.4). Modelled on `StreakStore`. |
| `Wingman/Lesson/LessonQuestionService.swift` | Thin Supabase layer: `fetchAllPublished() -> [LessonQuestionRow]`, `latestUpdatedAt() -> Date?`. Mirrors `DailyPracticeService`'s shape, including the protocol-for-testability split. |
| `Wingman/Lesson/LessonQuizFlowView.swift` | The `.fullScreenCover` content: `intro → question(0…n) → complete`, owns a `QuizEngine`, ends by rendering the existing `LessonCompleteView`. |

### 5.2 Modified files

| File | Change |
|---|---|
| [`LessonView.swift`](../Wingman/Lesson/LessonView.swift) | Rename `showLessonComplete` → `showEndOfLesson`; cover presents `LessonQuizFlowView`; move the `lesson_completed` capture into the `onContinue` closure (§7.4); optionally adopt `QuizProgressBar`. |
| [`DailyPracticeView.swift`](../Wingman/DailyPractice/DailyPracticeView.swift) | Delete ~350 lines of private view builders; render `QuizQuestionView` + `QuizProgressBar`. Loading/error/empty states, analytics and nav handlers stay. **692 → ~250 lines.** |
| [`DailyPracticeViewModel.swift`](../Wingman/DailyPractice/DailyPracticeViewModel.swift) | Hold a `QuizEngine`; keep only daily concerns (`loadTodayQuestions`, `submitCompletion`, `updateDailyPracticeStreak`, `showCompletionView`, the notification post). Forward `currentQuestion` / `isOptionSelected` / etc. so the view's remaining call sites don't all churn. **445 → ~250 lines.** |
| [`DailyPracticeServiceProtocol.swift`](../Wingman/DailyPractice/DailyPracticeServiceProtocol.swift) | Map `SupabaseQuestion` → `QuizQuestion` instead of `DailyPracticeQuestion`; reconstruct the `UUID` at the `submitCompletion` boundary. |
| [`DailyPracticeQuestion.swift`](../Wingman/DailyPractice/DailyPracticeQuestion.swift) | `DailyPracticeQuestion` collapses into `QuizQuestion`; keep `SelectedAnswers` and `CompletionResponse` where they are. |
| [`AuthManager.swift`](../Wingman/Auth/AuthManager.swift) | Call `LessonQuestionStore.shared.refresh()` next to the two existing `hydrateLessonProgressFromCloud()` calls (`:528`, `:687`) — §2.4. |
| [`Analytics.swift`](../Wingman/Util/Analytics.swift) | Four new event-name constants (§4.5). |
| [`FeatureFlags.swift`](../Wingman/Util/FeatureFlags.swift) | `@Published private(set) var lessonQuizEnabled: Bool = false`, key `lesson_quiz_enabled`, `#if DEBUG` launch-arg override — copy the `postDemoWallIsHard` shape exactly. Ships **false**; absent flag ⇒ current behaviour. |
| [`LessonViewModel.swift`](../Wingman/Lesson/LessonViewModel.swift) | **Delete.** Dead code (§1.1). |

### 5.3 Reused as-is (no changes)

- [`LessonCompleteView`](../Wingman/Courses/LessonCompleteView.swift) — final step, unchanged including its `onContinue` contract.
- [`LessonDataService.markLessonCompleted`](../Wingman/Lesson/LessonDataService.swift) — the completion write, unchanged. Same call, later.
- Every existing table, RPC and RLS policy. Lesson prose JSON is **untouched**.
- `ScalePressStyle`, `HapticManager`, `Color.custom*`, `Font.manrope*`,
  `appDynamicTypeCeiling()`, `TabBarVisibilityManager`, `NetworkMonitor`.

### 5.4 Backend / database changes

**One migration, already applied.** No RPC changes, no changes to any existing
table, no edge functions. The only outstanding backend task is creating
`lesson_quiz_enabled` in the PostHog dashboard.

Full DDL:
[`supabase/migrations/20260730000000_create_lesson_questions.sql`](../supabase/migrations/20260730000000_create_lesson_questions.sql).
It is idempotent (`if not exists` / `on conflict` / `drop … if exists`
throughout), so re-running it is safe — useful when lessons are added or renamed.
This is also the first file in `supabase/migrations/`; prior schema was managed
through the dashboard with no migration history.

It creates:

1. **`lessons`** — 94 rows generated from the bundled JSON.
2. **`lesson_questions`** — with the FK, four constraints, two indexes, RLS
   select policy for `authenticated`, and the `update_updated_at_column()`
   trigger (matching `questions`).
3. **`lesson_question_status`** — the authoring view:

```sql
select category_name, course_title, lesson_number,
       lesson_id, lesson_title, published, drafts, status
from public.lesson_question_status;
```

`status` is `ready` (3 published), `incomplete` (1–2, or drafts only), or
`empty`. Ordered by course then lesson number, so it reads as a worklist.

**Constraints, verified by probing the live table:**

| Case | Result |
|---|---|
| Valid `single_select` | accepted |
| Valid `multiple_select` | accepted |
| `lesson_id` typo (`lesson_11`) | rejected — `lesson_questions_lesson_id_fkey` |
| `correct_answer_index` past end of `options` | rejected — `lesson_questions_index_in_range` |
| `single_select` carrying `correct_answer_indices` | rejected — `lesson_questions_answer_shape` |
| Duplicate `question_number` within a lesson | rejected — `lesson_questions_unique_number` |

Two known gaps:

- `lesson_questions_index_in_range` covers `single_select` only. Postgres
  disallows subqueries in `CHECK`, so bounds-checking the `correct_answer_indices`
  **array** would need an `IMMUTABLE` helper function. Left out deliberately —
  it's a content check, not an integrity invariant, and the query below covers it.
- RLS does not filter `is_published`; drafts are excluded client-side by the
  service query. If drafts must never leave the server, change the policy's
  `using (true)` to `using (is_published)`.

**Residual validation query** — the only content check the schema can't enforce:

```sql
-- multi-select rows whose indices point outside their options array
select lesson_id, question_number, options, correct_answer_indices
from public.lesson_questions
where correct_answer_indices is not null
  and exists (
    select 1 from unnest(correct_answer_indices) as i
    where i < 0 or i >= jsonb_array_length(options)
  );
```

**Seed template** (§2.5) — drafts only, left unpublished for review:

```sql
insert into public.lesson_questions
  (lesson_id, question_number, question_type, question_text,
   options, correct_answer_index, correct_answer_indices, explanation, is_published)
select
  'lesson_1_1',
  row_number() over (order by q.id),
  q.question_type, q.question_text, q.options,
  q.correct_answer_index, q.correct_answer_indices, q.explanation,
  false                                    -- review before publishing
from public.questions q
where q.module = 'mindset_foundations'     -- category of course_1
order by random()
limit 3;
```

### 5.5 Rollout order

**Stage 0 — migration ✅ applied, content pilot in progress.**
Schema is live (see the header note). Remaining: author 15 questions for
`course_1`, working from `lesson_question_status`. This is the long pole; it runs
in parallel with Stages 1–2, which touch no lesson code.

**Stage 1 — extract the UI (ships alone, no user-visible change).**
`QuizQuestionView` + `QuizProgressBar`; `DailyPracticeView` renders them. Verify
Daily Practice is pixel-identical: single-select, multi-select, correct,
incorrect, partially-correct-multi, back-nav restore.

**Stage 2 — extract the engine (ships alone, no user-visible change).**
`QuizQuestion` + `QuizEngine`; `DailyPracticeViewModel` delegates. Same regression
pass. Stages 1–2 can share a PR if reviewed together, but **must** be separate
from Stage 3 so a Daily Practice regression is never ambiguous about its cause.

**Stage 3 — lesson quiz, flag off.**
`LessonQuestionService` + `LessonQuestionStore`, `LessonQuizFlowView`, `LessonView`
wiring, `lesson_quiz_enabled` (default false), analytics, debug skip toggle.
Merged and shipped dark. The store can ship enabled even with the flag off —
warming the cache before anyone sees a quiz is free and de-risks Stage 4.

**Stage 4 — enable for a cohort.**
Flag on for a small % on the piloted course. Watch
`lesson_completed / lesson_started`, `lesson_quiz_abandoned`,
`lesson_quiz_unavailable`, and time-to-first-scenario-unlock.

**Stage 5 — author the remaining ~267 questions, roll to 100%.**
Gated on Stage 4's numbers. Because content is server-side, publishing a course's
questions is an `update … set is_published = true`, not a release.

### 5.6 Migrations

**Database:** the single `create_lesson_questions` migration above. Purely
additive — no existing table, column, RPC or policy is altered, so it is safe to
apply well ahead of the client work and trivially reversible (`drop table`).

**Content:** additive. An empty or partially-filled table degrades to today's
behaviour per §2.7, which is what makes per-course rollout possible.

**No user-data migration.** Already-completed lessons stay completed; nobody is
retroactively asked to pass a quiz.

---

## 6. Testing Strategy

**There is no test target in this project** (only `Wingman.xcscheme`; no `XCTest`,
no `TEST_HOST`). The plan is honest about that rather than pretending otherwise.

**Add a minimal unit-test target for `QuizEngine`.** Pure logic, no UIKit, no
network, no singletons — the cheapest possible place to start testing this
codebase, and the piece where a silent bug (marking a correct answer wrong) is
worst. Cover: single-select correct/incorrect; multi-select exact-set match;
partial multi-select; back-nav restores saved state; `countedQuestionIds` dedup;
`progress` at boundaries; `passThreshold` at 0 and at n.

`LessonQuestionService` gets the same protocol treatment as
`DailyPracticeServiceProtocol`, so `LessonQuestionStore` can be tested against a
stub: successful sync, failed sync preserves cache, watermark unchanged skips the
fetch, malformed row is skipped rather than failing the whole decode.

**SQL-level:** the validation query in §5.4, run after every content edit. This
catches the realistic content bug — an off-by-one `correct_answer_index`, or three
questions attached to a `lesson_id` that doesn't exist — which no amount of manual
QA will find across 282 rows.

**Manual regression — Daily Practice (after Stage 1 and again after Stage 2):**
single-select and multi-select rendering; correct / incorrect / correct-but-not-
selected colour states; Check → explanation → Next; back to a prior question shows
the saved answer and can't be re-answered; last question → streak → completion →
Continue unwinds to Home; offline error state; retry.

**Manual — cache and sync matrix:**

| Scenario | Expected |
|---|---|
| Fresh install, online | Sync at auth, quizzes work |
| Fresh install, offline | Empty cache → lessons complete as today, `lesson_quiz_unavailable` fires |
| Warm cache, offline | Quizzes work fully offline |
| Warm cache, sync fails | Cache preserved, quizzes keep working |
| Question edited in Supabase | Next launch picks it up via watermark |
| Nothing changed server-side | Watermark check only, no full fetch |
| Logout / login as another user | Cache **not** cleared, no re-download |

**Manual — lesson quiz:**
- Lesson **with** questions → quiz appears, completion only after passing.
- Lesson **without** questions → straight to `LessonCompleteView`, exactly as today.
- Both entry points: Courses → Course → Lesson, and Home Continue → Course → Lesson.
- Chevron on question 1 returns to the lesson; chevron on question 2+ goes back one question.
- Abandon mid-quiz → lesson **not** completed, next lesson **not** unlocked.
- Pass → completed, next lesson unlocked, `.lessonCompleted` fires, Courses grid re-derives.
- Complete a course's last lesson → next course unlocks.
- Anonymous/guest user: sync succeeds (guest is `authenticated`), quiz works.
- Re-open an already-completed lesson → quiz shows again, passing is idempotent.
- Dynamic Type at accessibility sizes with the longest options — `appDynamicTypeCeiling()` applied.
- Tab bar hidden throughout, restored on every exit path.

**Explicit anti-regression check (§1.6):** complete two lesson quizzes in one day,
then open Home. Daily Practice must still read **Start**, not **Completed**, the
streak must be unchanged, and no rows may appear in `user_question_completions`.
This is the single most important test in this plan.

---

## 7. Pitfalls

**7.1 No graceful fallthrough.** A lesson whose questions haven't been authored,
or a user whose cache is cold, must complete exactly as today. If the quiz gate
hard-fails on an empty question list, the first offline fresh install becomes a
lesson nobody can finish. Non-negotiable, and it's what makes staged content
rollout possible.

**7.2 Writing to `user_question_completions`.** §1.6. It is the obvious "reuse"
and it is wrong three ways. The separate table avoids it structurally — keep it
that way, and don't add a lesson-answers table that FKs into `questions`.

**7.3 Reusing `DailyPracticeViewModel` directly for lessons.** It posts
`.dailyPracticeCompleted`, which `HomeViewModel` listens for and reacts to by
re-fetching daily status (`HomeViewModel.swift:67-76`). Silent state corruption.
The `QuizEngine` split exists precisely to prevent this.

**7.4 The analytics/persistence gap widens.** Today `lesson_completed` fires ~2 s
before `markLessonCompleted` runs. With a quiz in between it's ~60 s, and
abandonment in that window is *expected*, not exceptional. **Move the
`lesson_completed` capture into the same closure that calls `markLessonCompleted`**
so the event and the write are atomic, and let `lesson_quiz_abandoned` carry the
drop-off signal.

**7.5 Syncing before a session exists.** RLS on `lesson_questions` requires the
`authenticated` role. Calling `refresh()` from `RootView`'s `.task`
(`WingmanApp.swift:343`) races auth bootstrap and 401s on cold start. Hook it to
the auth state handler next to `hydrateLessonProgressFromCloud()` (§2.4).

**7.6 A failed sync wiping the cache.** `StreakStore` gets this right — "never
overwrites existing values on refresh failure". Copy that rule exactly. A store
that empties itself on a flaky network silently disables the feature for a user
who had it working yesterday.

**7.7 Content drift across two systems.** Lesson prose lives in bundled JSON,
questions live in Postgres. Edit the prose, ship it, and the questions still test
the old text — with no diff showing both. Make "re-check the questions" part of
lesson-content review, and use `lesson_quiz_unavailable` plus the validation query
to catch the structural half.

**7.8 `lesson_id` typos — resolved by the `lessons` FK (Rev 3).** Previously the
sharpest risk here: `lesson_11` instead of `lesson_1_1` produced orphan rows and
one silently quiz-less lesson, catchable only by a validation query somebody had
to remember to run. Postgres now rejects it at insert. The residual risk is
narrower and structural: **`lessons` is a copy of bundled JSON, and nothing
enforces that the copy stays current.** Add a lesson to the JSON without
re-running the seed and it simply has no row, so its questions can't be written
at all. Re-run the seed block whenever lesson ids change — it's idempotent.

**7.9 Tap-mode whiplash.** The reading UI is tap-anywhere-to-advance
(`ScrollableContentView`'s `UITapGestureRecognizer`: left half back, right half
forward). The quiz is tap-a-specific-option. The `.intro` step ("Knowledge Check
— 3 quick questions") is not decoration; it's the beat that stops a fast-tapping
user from landing their lesson-ending tap on an answer.

**7.10 Partial question sets.** `unique (lesson_id, question_number)` prevents
duplicates but not a lesson published with one question. The validation query
flags `<> 3`; treat a one-question quiz as worse than no quiz.

**7.11 No QA escape hatch.** 94 lessons behind a mandatory quiz is punishing to
test. Add a DEBUG-only skip in the shape of the existing
`PracticeService.forceUnlockForTesting` (`PracticeServiceProtocol.swift:91`).

**7.12 The `clearCache()`-on-appear in `CourseDetailSheet`.** Not caused by this
work, but worth a separate one-line fix — every course visit currently re-parses
the whole course JSON.

---

## 8. Summary

- **Data:** new `lesson_questions` table mirroring `questions`' layout (same
  `question_type` enum), keyed by `lesson_id`. Curated server-side, editable
  without an App Store release.
- **Offline:** solved by caching the **whole set** (~107 kB, one request) rather
  than fetching per lesson. After first sync the quiz never touches the network.
  Cold-cache and un-authored lessons degrade to today's completion behaviour.
- **Progress:** nothing new. `isCompleted` already carries the meaning; it just
  becomes harder to earn.
- **Reuse:** extract `QuizEngine` + `QuizQuestionView` out of Daily Practice and
  have both features render the same components off one `QuizQuestion` struct.
  Net effect is **~750 lines deleted from Daily Practice** and one shared quiz
  surface instead of two.
- **Hard constraint:** lesson answers never touch `user_question_completions`,
  `questions`, or the streak RPC — §1.6 explains all three failure modes.
- **Backend:** one additive migration. No existing table, RPC or policy changes.
- **Effort:** ~5–7 engineering days; **282 questions of content curation is the
  critical path**, reducible by seeding drafts from the existing 757.
- **Recommendation:** build it, ship behind `lesson_quiz_enabled`, pilot one
  course, and let `lesson_completed / lesson_started` decide whether it goes to
  100%. Server-side content makes that pilot an insert rather than a release.
