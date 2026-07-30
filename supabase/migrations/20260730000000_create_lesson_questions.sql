-- Lesson Knowledge Check — Stage 0 schema
-- See docs/lesson-quiz-plan.md §5.4
--
-- Two tables:
--   lessons          reference data mirrored from the bundled lesson JSON.
--                    Exists so lesson_questions.lesson_id can carry a real
--                    foreign key, and so the authoring view can show titles
--                    instead of opaque ids.
--   lesson_questions the curated questions, one row per question.
--
-- Safe to re-run: everything is IF NOT EXISTS / ON CONFLICT.

-- ---------------------------------------------------------------------------
-- 1. Lesson reference table (94 rows, generated from the app bundle)
-- ---------------------------------------------------------------------------

create table if not exists public.lessons (
  lesson_id      text primary key,
  course_id      text    not null,
  category_id    text    not null,
  category_name  text    not null,
  course_title   text    not null,
  lesson_number  integer not null,
  lesson_title   text    not null,
  constraint lessons_unique_number unique (course_id, lesson_number)
);

alter table public.lessons enable row level security;

drop policy if exists "Lessons are readable by authenticated users" on public.lessons;
create policy "Lessons are readable by authenticated users"
  on public.lessons for select to authenticated using (true);

insert into public.lessons
  (lesson_id, course_id, category_id, category_name, course_title, lesson_number, lesson_title)
values
  ('lesson_1_1', 'course_1', 'cat_1', 'Mindset & Foundations', 'Beliefs & Reframes', 1, 'You are not your thoughts'),
  ('lesson_1_2', 'course_1', 'cat_1', 'Mindset & Foundations', 'Beliefs & Reframes', 2, 'Rejection isn''t personal'),
  ('lesson_1_3', 'course_1', 'cat_1', 'Mindset & Foundations', 'Beliefs & Reframes', 3, 'Rewrite the Story'),
  ('lesson_1_4', 'course_1', 'cat_1', 'Mindset & Foundations', 'Beliefs & Reframes', 4, 'Confidence Comes from Evidence'),
  ('lesson_1_5', 'course_1', 'cat_1', 'Mindset & Foundations', 'Beliefs & Reframes', 5, 'Growth mindset vs Fixed mindset'),
  ('lesson_2_1', 'course_2', 'cat_1', 'Mindset & Foundations', 'Fear & Exposure', 1, 'Fear Shrinks When You Chase it'),
  ('lesson_2_2', 'course_2', 'cat_1', 'Mindset & Foundations', 'Fear & Exposure', 2, 'Own Your Presence in Public'),
  ('lesson_2_3', 'course_2', 'cat_1', 'Mindset & Foundations', 'Fear & Exposure', 3, 'Using Breath to Reduce Fear'),
  ('lesson_2_4', 'course_2', 'cat_1', 'Mindset & Foundations', 'Fear & Exposure', 4, 'Anchor Points: Staying Grounded'),
  ('lesson_3_1', 'course_3', 'cat_1', 'Mindset & Foundations', 'Presence & Expressions', 1, 'Your body speaks first'),
  ('lesson_3_2', 'course_3', 'cat_1', 'Mindset & Foundations', 'Presence & Expressions', 2, 'The Power of a Calm Voice'),
  ('lesson_3_3', 'course_3', 'cat_1', 'Mindset & Foundations', 'Presence & Expressions', 3, 'Energy Is Contagious'),
  ('lesson_3_4', 'course_3', 'cat_1', 'Mindset & Foundations', 'Presence & Expressions', 4, 'Smile First, Speak Second'),
  ('lesson_4_1', 'course_4', 'cat_1', 'Mindset & Foundations', 'Inner Stability', 1, 'Nothing to Prove'),
  ('lesson_4_2', 'course_4', 'cat_1', 'Mindset & Foundations', 'Inner Stability', 2, 'Own Your Pace'),
  ('lesson_4_3', 'course_4', 'cat_1', 'Mindset & Foundations', 'Inner Stability', 3, 'Outcome Independence'),
  ('lesson_4_4', 'course_4', 'cat_1', 'Mindset & Foundations', 'Inner Stability', 4, 'Handling Positive Responses'),
  ('lesson_5_1', 'course_5', 'cat_1', 'Mindset & Foundations', 'Non-negotiables', 1, 'Build the Body, Build the Belief'),
  ('lesson_5_2', 'course_5', 'cat_1', 'Mindset & Foundations', 'Non-negotiables', 2, 'Grooming Is Essential'),
  ('lesson_5_3', 'course_5', 'cat_1', 'Mindset & Foundations', 'Non-negotiables', 3, 'Hygiene Goes a Long Way'),
  ('lesson_5_4', 'course_5', 'cat_1', 'Mindset & Foundations', 'Non-negotiables', 4, 'Fashion and Style'),
  ('lesson_6_1', 'course_6', 'cat_2', 'Approach Mechanics', 'Approach Readiness', 1, 'Hesitation Guarantees the Loss'),
  ('lesson_6_2', 'course_6', 'cat_2', 'Approach Mechanics', 'Approach Readiness', 2, 'Life''s Fun If You Open Your Mouth'),
  ('lesson_6_3', 'course_6', 'cat_2', 'Approach Mechanics', 'Approach Readiness', 3, 'Curiosity Beats Agenda'),
  ('lesson_6_4', 'course_6', 'cat_2', 'Approach Mechanics', 'Approach Readiness', 4, 'You''re Always in the Field'),
  ('lesson_7_1', 'course_7', 'cat_2', 'Approach Mechanics', 'The Physical Approach', 1, 'The 3-Second Rule'),
  ('lesson_7_2', 'course_7', 'cat_2', 'Approach Mechanics', 'The Physical Approach', 2, 'Approach Angle & Distance'),
  ('lesson_7_3', 'course_7', 'cat_2', 'Approach Mechanics', 'The Physical Approach', 3, 'Your Body in Motion'),
  ('lesson_7_4', 'course_7', 'cat_2', 'Approach Mechanics', 'The Physical Approach', 4, 'Eye Contact & First Impression'),
  ('lesson_8_1', 'course_8', 'cat_2', 'Approach Mechanics', 'The Opener', 1, 'Indirect Openers'),
  ('lesson_8_2', 'course_8', 'cat_2', 'Approach Mechanics', 'The Opener', 2, 'Direct Intent Openers'),
  ('lesson_8_3', 'course_8', 'cat_2', 'Approach Mechanics', 'The Opener', 3, 'Frame Control'),
  ('lesson_8_4', 'course_8', 'cat_2', 'Approach Mechanics', 'The Opener', 4, 'Voice Mechanics'),
  ('lesson_9_1', 'course_9', 'cat_2', 'Approach Mechanics', 'Reading & Responding', 1, 'Reading Her Response'),
  ('lesson_9_2', 'course_9', 'cat_2', 'Approach Mechanics', 'Reading & Responding', 2, 'Responding to Neutral Signals'),
  ('lesson_9_3', 'course_9', 'cat_2', 'Approach Mechanics', 'Reading & Responding', 3, 'Recognizing Signals: A Guide'),
  ('lesson_10_1', 'course_10', 'cat_2', 'Approach Mechanics', 'Situational Specific Approaches', 1, 'Daytime Approaches'),
  ('lesson_10_2', 'course_10', 'cat_2', 'Approach Mechanics', 'Situational Specific Approaches', 2, 'Nighttime Approaches'),
  ('lesson_10_3', 'course_10', 'cat_2', 'Approach Mechanics', 'Situational Specific Approaches', 3, 'Approaching Women in Groups'),
  ('lesson_11_1', 'course_11', 'cat_2', 'Approach Mechanics', 'Advanced Opening Techniques', 1, 'Curiosity Based Openers'),
  ('lesson_11_2', 'course_11', 'cat_2', 'Approach Mechanics', 'Advanced Opening Techniques', 2, 'Assumption Based Openers'),
  ('lesson_11_3', 'course_11', 'cat_2', 'Approach Mechanics', 'Advanced Opening Techniques', 3, 'Opinion Openers'),
  ('lesson_11_4', 'course_11', 'cat_2', 'Approach Mechanics', 'Advanced Opening Techniques', 4, 'Setting Time Constraints'),
  ('lesson_11_5', 'course_11', 'cat_2', 'Approach Mechanics', 'Advanced Opening Techniques', 5, 'Nighttime technique: False Exits'),
  ('lesson_12_1', 'course_12', 'cat_3', 'Conversation Flow', 'Small Talk & Momentum', 1, 'Never Run Out of Things to Say'),
  ('lesson_12_2', 'course_12', 'cat_3', 'Conversation Flow', 'Small Talk & Momentum', 2, 'Use Observations and Statements'),
  ('lesson_12_3', 'course_12', 'cat_3', 'Conversation Flow', 'Small Talk & Momentum', 3, 'Maintain Momentum'),
  ('lesson_12_4', 'course_12', 'cat_3', 'Conversation Flow', 'Small Talk & Momentum', 4, 'When Silence Works'),
  ('lesson_13_1', 'course_13', 'cat_3', 'Conversation Flow', 'Listening & Attunement', 1, 'Listen for Subtext, Not Just Words'),
  ('lesson_13_2', 'course_13', 'cat_3', 'Conversation Flow', 'Listening & Attunement', 2, 'Listen to understand, not to reply'),
  ('lesson_13_3', 'course_13', 'cat_3', 'Conversation Flow', 'Listening & Attunement', 3, 'Validating Her Response First'),
  ('lesson_13_4', 'course_13', 'cat_3', 'Conversation Flow', 'Listening & Attunement', 4, 'Non-Verbal Listening Cues'),
  ('lesson_14_1', 'course_14', 'cat_3', 'Conversation Flow', 'Sharing & Vulnerability', 1, 'Match First, Then Lead'),
  ('lesson_14_2', 'course_14', 'cat_3', 'Conversation Flow', 'Sharing & Vulnerability', 2, 'What to Share, What Not to Share'),
  ('lesson_14_3', 'course_14', 'cat_3', 'Conversation Flow', 'Sharing & Vulnerability', 3, 'Tell Stories That Connect'),
  ('lesson_14_4', 'course_14', 'cat_3', 'Conversation Flow', 'Sharing & Vulnerability', 4, 'Link the Stories Back to Her World'),
  ('lesson_15_1', 'course_15', 'cat_3', 'Conversation Flow', 'Closing', 1, 'Know When the Moment Is Ready'),
  ('lesson_15_2', 'course_15', 'cat_3', 'Conversation Flow', 'Closing', 2, 'End on Connection, Not Luck'),
  ('lesson_15_3', 'course_15', 'cat_3', 'Conversation Flow', 'Closing', 3, 'Make It Easy to Say Yes'),
  ('lesson_15_4', 'course_15', 'cat_3', 'Conversation Flow', 'Closing', 4, 'Assume she is interested'),
  ('lesson_16_1', 'course_16', 'cat_3', 'Conversation Flow', 'Advanced Conversation Skills', 1, 'Resetting After Energy Drops'),
  ('lesson_16_2', 'course_16', 'cat_3', 'Conversation Flow', 'Advanced Conversation Skills', 2, 'Disagree Without Disconnecting'),
  ('lesson_16_3', 'course_16', 'cat_3', 'Conversation Flow', 'Advanced Conversation Skills', 3, 'Make Being With You Fun'),
  ('lesson_17_1', 'course_17', 'cat_4', 'Flirting & Chemistry', 'Flirting Prerequisites', 1, 'The Goal of Flirting'),
  ('lesson_17_2', 'course_17', 'cat_4', 'Flirting & Chemistry', 'Flirting Prerequisites', 2, 'Identifying the Signals'),
  ('lesson_17_3', 'course_17', 'cat_4', 'Flirting & Chemistry', 'Flirting Prerequisites', 3, 'Respect'),
  ('lesson_17_4', 'course_17', 'cat_4', 'Flirting & Chemistry', 'Flirting Prerequisites', 4, 'Energy'),
  ('lesson_18_1', 'course_18', 'cat_4', 'Flirting & Chemistry', 'Playfulness & Spark', 1, 'Humour: Banter and Teasing'),
  ('lesson_18_2', 'course_18', 'cat_4', 'Flirting & Chemistry', 'Playfulness & Spark', 2, 'Light, Playful Challenges'),
  ('lesson_18_3', 'course_18', 'cat_4', 'Flirting & Chemistry', 'Playfulness & Spark', 3, 'Add a Little Bit of Cheek'),
  ('lesson_19_1', 'course_19', 'cat_4', 'Flirting & Chemistry', 'Compliments & Verbal Chemistry', 1, 'Compliments That Actually Land'),
  ('lesson_19_2', 'course_19', 'cat_4', 'Flirting & Chemistry', 'Compliments & Verbal Chemistry', 2, 'Being Nice Is Not Desire'),
  ('lesson_19_3', 'course_19', 'cat_4', 'Flirting & Chemistry', 'Compliments & Verbal Chemistry', 3, 'One Line to Change the Dynamic'),
  ('lesson_20_1', 'course_20', 'cat_4', 'Flirting & Chemistry', 'Physical Presence', 1, 'Eye Contact That Creates Tension'),
  ('lesson_20_2', 'course_20', 'cat_4', 'Flirting & Chemistry', 'Physical Presence', 2, 'Using Proximity to Build Attraction'),
  ('lesson_20_3', 'course_20', 'cat_4', 'Flirting & Chemistry', 'Physical Presence', 3, 'Using Mirroring to Build Rapport'),
  ('lesson_20_4', 'course_20', 'cat_4', 'Flirting & Chemistry', 'Physical Presence', 4, 'When and How to Use Touch'),
  ('lesson_21_1', 'course_21', 'cat_4', 'Flirting & Chemistry', 'Advanced Flirting Skills', 1, 'Disqualification Techniques'),
  ('lesson_21_2', 'course_21', 'cat_4', 'Flirting & Chemistry', 'Advanced Flirting Skills', 2, 'Flirt by Creating Sexual Tension'),
  ('lesson_21_3', 'course_21', 'cat_4', 'Flirting & Chemistry', 'Advanced Flirting Skills', 3, 'Callbacks & Inside Jokes'),
  ('lesson_22_1', 'course_22', 'cat_5', 'Integration & Mastery', 'Upgrading Your Lifestyle', 1, 'The Effect of Social Status'),
  ('lesson_22_2', 'course_22', 'cat_5', 'Integration & Mastery', 'Upgrading Your Lifestyle', 2, 'The Interesting Man Advantage'),
  ('lesson_22_3', 'course_22', 'cat_5', 'Integration & Mastery', 'Upgrading Your Lifestyle', 3, 'The Power of Mystery'),
  ('lesson_22_4', 'course_22', 'cat_5', 'Integration & Mastery', 'Upgrading Your Lifestyle', 4, 'The Average of Your Social Circle'),
  ('lesson_23_1', 'course_23', 'cat_5', 'Integration & Mastery', 'Creating Opportunities', 1, 'Create More Chances to Connect'),
  ('lesson_23_2', 'course_23', 'cat_5', 'Integration & Mastery', 'Creating Opportunities', 2, 'Train Where You Live'),
  ('lesson_23_3', 'course_23', 'cat_5', 'Integration & Mastery', 'Creating Opportunities', 3, 'Home Court Advantage'),
  ('lesson_24_1', 'course_24', 'cat_5', 'Integration & Mastery', 'Mastery & Identity', 1, 'Volume Creates Familiarity'),
  ('lesson_24_2', 'course_24', 'cat_5', 'Integration & Mastery', 'Mastery & Identity', 2, 'Stay Consistent'),
  ('lesson_24_3', 'course_24', 'cat_5', 'Integration & Mastery', 'Mastery & Identity', 3, 'From Technique to Intuition'),
  ('lesson_25_1', 'course_25', 'cat_5', 'Integration & Mastery', 'Learning & Self Discovery', 1, 'The Experimental Mindset'),
  ('lesson_25_2', 'course_25', 'cat_5', 'Integration & Mastery', 'Learning & Self Discovery', 2, 'Your Authentic Style'),
  ('lesson_25_3', 'course_25', 'cat_5', 'Integration & Mastery', 'Learning & Self Discovery', 3, 'Identify Your Sticking Point'),
  ('lesson_25_4', 'course_25', 'cat_5', 'Integration & Mastery', 'Learning & Self Discovery', 4, 'The Growth Plateau')
on conflict (lesson_id) do update set
  course_id     = excluded.course_id,
  category_id   = excluded.category_id,
  category_name = excluded.category_name,
  course_title  = excluded.course_title,
  lesson_number = excluded.lesson_number,
  lesson_title  = excluded.lesson_title;

-- ---------------------------------------------------------------------------
-- 2. Lesson questions
-- ---------------------------------------------------------------------------

create table if not exists public.lesson_questions (
  id                      uuid primary key default gen_random_uuid(),
  lesson_id               text        not null
                            references public.lessons(lesson_id)
                            on update cascade on delete restrict,
  question_number         integer     not null,
  question_type           public.question_type not null,
  question_text           text        not null,
  options                 jsonb       not null,
  correct_answer_index    integer,
  correct_answer_indices  integer[],
  explanation             text        not null,
  is_published            boolean     not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  constraint lesson_questions_unique_number
    unique (lesson_id, question_number),

  -- options must be a real array with at least two choices
  constraint lesson_questions_options_shape check (
    jsonb_typeof(options) = 'array' and jsonb_array_length(options) >= 2
  ),

  -- exactly one answer column populated, matching question_type
  constraint lesson_questions_answer_shape check (
    (question_type = 'single_select'
       and correct_answer_index   is not null
       and correct_answer_indices is null)
    or
    (question_type = 'multiple_select'
       and correct_answer_indices is not null
       and array_length(correct_answer_indices, 1) > 0
       and correct_answer_index   is null)
  ),

  -- catches the off-by-one that makes a single-select question unanswerable
  constraint lesson_questions_index_in_range check (
    correct_answer_index is null
    or (correct_answer_index >= 0
        and correct_answer_index < jsonb_array_length(options))
  )
);

create index if not exists lesson_questions_lesson_id_idx
  on public.lesson_questions (lesson_id);

create index if not exists lesson_questions_updated_at_idx
  on public.lesson_questions (updated_at desc);

alter table public.lesson_questions enable row level security;

drop policy if exists "Lesson questions are readable by authenticated users"
  on public.lesson_questions;
create policy "Lesson questions are readable by authenticated users"
  on public.lesson_questions for select to authenticated using (true);

drop trigger if exists update_lesson_questions_updated_at on public.lesson_questions;
create trigger update_lesson_questions_updated_at
  before update on public.lesson_questions
  for each row execute function public.update_updated_at_column();

-- ---------------------------------------------------------------------------
-- 3. Authoring view — which lessons still need questions
-- ---------------------------------------------------------------------------

create or replace view public.lesson_question_status as
select
  l.category_name,
  l.course_id,
  l.course_title,
  l.lesson_number,
  l.lesson_id,
  l.lesson_title,
  count(q.id) filter (where q.is_published)       as published,
  count(q.id) filter (where not q.is_published)   as drafts,
  case
    when count(q.id) filter (where q.is_published) = 3 then 'ready'
    when count(q.id) = 0                               then 'empty'
    else 'incomplete'
  end                                              as status
from public.lessons l
left join public.lesson_questions q on q.lesson_id = l.lesson_id
group by l.category_name, l.course_id, l.course_title,
         l.lesson_number, l.lesson_id, l.lesson_title
order by
  substring(l.course_id from 8)::int,
  l.lesson_number;
