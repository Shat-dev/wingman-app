-- Lesson Knowledge Check — Rev 4 schema
-- See docs/lesson-quiz-plan.md
--
-- Supersedes 20260730000000_create_lesson_questions.sql.
--
-- WHY THIS REPLACES THE PREVIOUS DESIGN
-- The earlier `lesson_questions` table held its own copy of each question's
-- text. That made sense while we believed the existing 757 questions were
-- category-level and mostly unusable for lesson quizzes. They aren't — they
-- were generated FROM the lesson prose, so every lesson question already
-- exists in `public.questions`. Copying them would fork 282 rows and let the
-- two copies drift.
--
-- Instead, `questions` gains two columns:
--   lesson_id          which lesson this question was generated from (all 757)
--   lesson_quiz_order  1..n if chosen for that lesson's end-of-lesson quiz,
--                      NULL if it stays a Daily Practice-only question
--
-- Tagging all 757 (not just the ~282 chosen) is deliberate: you cannot pick
-- the best 3 questions for a lesson without being able to see all 8 that came
-- from it, and the unchosen ones are what the review loop serves as an
-- alternative to repeating a question verbatim.
--
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. Tear down the copy-based design (empty, nothing to preserve)
-- ---------------------------------------------------------------------------

drop view  if exists public.lesson_question_status;
drop table if exists public.lesson_questions;

-- ---------------------------------------------------------------------------
-- 2. Lesson linkage on the existing question bank
-- ---------------------------------------------------------------------------

alter table public.questions
  add column if not exists lesson_id text
    references public.lessons(lesson_id)
    on update cascade on delete restrict,
  add column if not exists lesson_quiz_order integer;

-- A question cannot occupy a quiz slot without belonging to a lesson.
alter table public.questions
  drop constraint if exists questions_quiz_order_needs_lesson;
alter table public.questions
  add  constraint questions_quiz_order_needs_lesson check (
    lesson_quiz_order is null or lesson_id is not null
  );

-- Slots are 1-based.
alter table public.questions
  drop constraint if exists questions_quiz_order_positive;
alter table public.questions
  add  constraint questions_quiz_order_positive check (
    lesson_quiz_order is null or lesson_quiz_order >= 1
  );

-- One question per slot per lesson. Partial, so the ~475 Daily-Practice-only
-- questions (all NULL) don't collide with each other.
create unique index if not exists questions_lesson_quiz_slot_uniq
  on public.questions (lesson_id, lesson_quiz_order)
  where lesson_quiz_order is not null;

-- Lookup path for "give me this lesson's quiz".
create index if not exists questions_lesson_id_idx
  on public.questions (lesson_id)
  where lesson_id is not null;

-- ---------------------------------------------------------------------------
-- 3. Lesson quiz answers — the review loop's own log
-- ---------------------------------------------------------------------------
--
-- Deliberately NOT user_question_completions. That table feeds
-- get_excluded_question_ids(), which removes anything answered in the last 90
-- days from the Daily Practice draw — so writing a wrong lesson answer there
-- would ban the question for 90 days, the exact opposite of resurfacing it.
-- It would also trip the client-side `count >= 5` check that decides whether
-- today's Daily Practice is already complete.
--
-- lesson_id is stored alongside question_id on purpose. It is a historical
-- fact ("this was answered as part of that lesson's quiz"), not a duplicate of
-- current state — if a question is later re-tagged to a different lesson, past
-- answers must still read correctly.

create table if not exists public.user_lesson_quiz_answers (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id)        on delete cascade,
  question_id uuid        not null references public.questions(id)  on delete cascade,
  lesson_id   text        not null references public.lessons(lesson_id) on update cascade,
  is_correct  boolean     not null,
  answered_at timestamptz not null default now()
);

-- "Which questions has this user got wrong?" — the review-loop query.
create index if not exists user_lesson_quiz_answers_review_idx
  on public.user_lesson_quiz_answers (user_id, is_correct, answered_at desc);

create index if not exists user_lesson_quiz_answers_question_idx
  on public.user_lesson_quiz_answers (user_id, question_id);

alter table public.user_lesson_quiz_answers enable row level security;

drop policy if exists "Users can view their own lesson quiz answers"
  on public.user_lesson_quiz_answers;
create policy "Users can view their own lesson quiz answers"
  on public.user_lesson_quiz_answers
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own lesson quiz answers"
  on public.user_lesson_quiz_answers;
create policy "Users can insert their own lesson quiz answers"
  on public.user_lesson_quiz_answers
  for insert to authenticated
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 4. Authoring view — rebuilt against questions
-- ---------------------------------------------------------------------------
--
--   in_quiz       questions chosen for this lesson's quiz (target: 3)
--   tagged_total  questions known to have come from this lesson
--   status        ready | incomplete | tagged, none chosen | empty

create or replace view public.lesson_question_status as
select
  l.category_name,
  l.course_id,
  l.course_title,
  l.lesson_number,
  l.lesson_id,
  l.lesson_title,
  count(q.id) filter (where q.lesson_quiz_order is not null) as in_quiz,
  count(q.id)                                                as tagged_total,
  case
    when count(q.id) filter (where q.lesson_quiz_order is not null) = 3 then 'ready'
    when count(q.id) filter (where q.lesson_quiz_order is not null) > 0 then 'incomplete'
    when count(q.id) > 0                                               then 'tagged, none chosen'
    else 'empty'
  end as status
from public.lessons l
left join public.questions q on q.lesson_id = l.lesson_id
group by l.category_name, l.course_id, l.course_title,
         l.lesson_number, l.lesson_id, l.lesson_title
order by
  substring(l.course_id from 8)::int,
  l.lesson_number;
