# Live schema snapshot: Wingman-App

Captured 2026-11-10 from project `bnckmgnysfliiypvxxii` (region `us-east-1`, Postgres 17.6), `public` schema.
Method: read-only catalog queries through the Supabase connector (`list_tables`, `pg_proc`, `pg_policies`, `information_schema`). This is **not** a `pg_dump`; it records structure needed for the localization work (prerequisites P1 and P2 in `docs/localization-implementation-plan.md`). No data was changed.

## Tables

RLS is enabled on every table. Row counts are as of capture.

### Content (candidates for translation)

**`questions`** — 765 rows (275 linked to a lesson, 490 daily-pool only)

| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| module | enum `question_module` | |
| question_type | enum `question_type` | |
| question_text | text | translatable |
| options | jsonb | array of 3–4 strings; translatable; order is significant |
| correct_answer_index | int4, nullable | index into `options` |
| correct_answer_indices | int4[], nullable | indexes into `options` |
| explanation | text | translatable |
| lesson_id | text, nullable → `lessons.lesson_id` | |
| lesson_quiz_order | int4, nullable, ≥ 1 | |
| created_at, updated_at | timestamptz | `updated_at` maintained by trigger |

**`scenarios`** — 15 rows, all published

| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| title | text | translatable |
| summary | text, nullable | translatable |
| woman_name | text, nullable | 15 distinct names |
| cover_image_url | text, nullable | |
| order_index | int4 | |
| is_published | bool | |
| required_lessons_completed | int4 | |
| created_at, updated_at | timestamptz | |

**`scenario_screens`** — 891 rows (796 have an `image_url`)

| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| scenario_id | uuid → `scenarios.id` | |
| screen_type | enum `screen_type` | |
| order_index | int4 | |
| text | text, nullable | translatable |
| image_url | text, nullable | |
| default_next_screen_id | uuid, nullable → `scenario_screens.id` | branching |
| retry_target_screen_id | uuid, nullable → `scenario_screens.id` | branching |
| created_at, updated_at | timestamptz | |

**`screen_options`** — 276 rows

| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| screen_id | uuid → `scenario_screens.id` | |
| text | text | translatable |
| next_screen_id | uuid, nullable → `scenario_screens.id` | branching |
| is_correct | bool | scoring |
| order_index | int4 | |
| created_at | timestamptz | |

**`lessons`** — 94 rows. Reference mirror of the bundled lesson JSON; the app does not query it.
Columns: `lesson_id` text PK, `course_id`, `category_id`, `category_name`, `course_title`, `lesson_number`, `lesson_title`.

**Empty content tables (0 rows):** `practices` (title, summary, image_url…), `practice_details` (content, video_url, audio_url, duration), `practice_steps` (title, description, order). The app has queries for these, but there is nothing in them to translate.

**Not present:** there is no `courses` or `course_categories` table. The course catalog exists only in the app (`CourseCategory.swift`).

### Word counts (English)

| Source | Words |
|---|---|
| `questions.question_text` + `explanation` | 15,629 |
| `questions.options` | 16,329 |
| `scenario_screens.text` | 8,122 |
| `screen_options.text` | 2,005 |
| `scenarios.title` + `summary` | 222 |
| **Total in database** | **≈ 42,300** |

### User and progress tables (not translated)

| Table | Rows | Key columns |
|---|---|---|
| `daily_question_sets` | 165 | `user_id`, `date`, **`question_ids uuid[]`** |
| `user_question_completions` | 718 | `user_id`, `question_id` → questions, `selected_answers` jsonb, `is_correct` |
| `user_lesson_quiz_answers` | 2,028 | `user_id`, `question_id` → questions, `lesson_id` → lessons, `is_correct` |
| `user_daily_practice_sessions` | 136 | `user_id`, `date`, `questions_answered`, `correct_answers` |
| `user_daily_practice_streaks` | 246 | `user_id` (unique), `current_streak`, `longest_streak`, `last_completed_date`, `total_days_completed` |
| `user_scenario_progress` | 273 | `user_id`, `scenario_id`, `current_screen_id`, `is_completed` |
| `user_scenario_completions` | 226 | `user_id`, `scenario_id` |
| `user_xp_events` | 985 | `user_id`, `source_type` → xp_rules, `source_id`, `amount`, `local_date` |
| `xp_rules` | 4 | `source_type` PK, `base_amount`, `per_correct`, `perfect_bonus`, `daily_cap` |
| `approach_logs` | 11 | `user_id`, `title`, `approach_level` 1–4, `anxiety_level` 1–10, `notes` |
| `user_practice_progress` | 0 | |
| `daily_practice_completions` | 0 | |
| `likes` | 0 | |

All user tables reference `auth.users(id)`.

## Enums

| Enum | Values |
|---|---|
| `question_module` | mindset_foundations, approach_mechanics, conversational_skills, flirting_chemistry, mastery_integration |
| `question_type` | single_select, multiple_select |
| `screen_type` | context, user_dialogue, woman_dialogue, options, feedback |

## Views

`lesson_question_status`, `user_directory`.

## Functions

| Function | Arguments | Returns | Security |
|---|---|---|---|
| `get_or_create_daily_questions` | p_user_id uuid, p_date date | table(question_id, question_number, module, question_type, question_text, options, correct_answer_index, correct_answer_indices, explanation) | definer |
| `generate_daily_question_set` | p_user_id uuid, p_date date | uuid[] | definer |
| `get_excluded_question_ids` | p_user_id uuid | uuid[] | definer |
| `get_scenario_screens` | p_scenario_id uuid | table(screen_id, screen_type, order_index, text, image_url, default_next_screen_id, retry_target_screen_id, options jsonb) | invoker |
| `get_unlocked_scenarios` | p_user_id uuid | table(scenario_id, title, summary, cover_image_url, required_daily_practices, woman_name, order_index, is_completed, current_screen_id, total_daily_completions) | invoker |
| `get_daily_practice_status` | p_user_id uuid, p_date date | table(current_streak, total_completed, is_completed_today, can_resume) | definer |
| `update_daily_practice_streak` | p_user_id uuid, p_date date, p_questions_answered int, p_correct_answers int | table(current_streak, total_completed) | definer |
| `get_total_daily_practices` | p_user_id uuid | integer | definer |
| `award_xp` | p_source_type text, p_source_id text, p_local_date date, p_correct_count int, p_question_count int | table(awarded, amount_awarded, total_xp, capped, base_awarded, correct_awarded, bonus_awarded) | definer |
| `get_xp_summary` | — | table(total_xp, event_count, last_awarded_at) | invoker |
| `mark_streak_activity` | p_local_date date | table(current_streak, longest_streak, did_extend) | invoker |
| `set_updated_at`, `update_updated_at_column` | — | trigger | invoker |

### Definitions relevant to translation

```sql
-- Daily questions: the stored set is an array of question IDs; text is read
-- from `questions` at call time.
CREATE OR REPLACE FUNCTION public.get_or_create_daily_questions(p_user_id uuid, p_date date)
 RETURNS TABLE(question_id uuid, question_number integer, module question_module, question_type question_type, question_text text, options jsonb, correct_answer_index integer, correct_answer_indices integer[], explanation text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
   existing_set_id UUID;
   question_ids UUID[];
BEGIN
   SELECT dqs.question_ids INTO question_ids
   FROM daily_question_sets dqs
   WHERE dqs.user_id = p_user_id AND dqs.date = p_date;

   IF question_ids IS NULL THEN
       question_ids := generate_daily_question_set(p_user_id, p_date);

       IF question_ids IS NOT NULL AND array_length(question_ids, 1) > 0 THEN
           INSERT INTO daily_question_sets (user_id, date, question_ids)
           VALUES (p_user_id, p_date, question_ids);
       ELSE
           RETURN;
       END IF;
   END IF;

   RETURN QUERY
   SELECT
       q.id as question_id,
       (array_position(question_ids, q.id))::INTEGER as question_number,
       q.module,
       q.question_type,
       q.question_text,
       q.options,
       q.correct_answer_index,
       q.correct_answer_indices,
       q.explanation -- SINGLE EXPLANATION
   FROM questions q
   WHERE q.id = ANY(question_ids)
   ORDER BY array_position(question_ids, q.id);
END;
$function$
```

```sql
-- Scenario screens: returns screen IDs and option IDs alongside the text.
CREATE OR REPLACE FUNCTION public.get_scenario_screens(p_scenario_id uuid)
 RETURNS TABLE(screen_id uuid, screen_type screen_type, order_index integer, text text, image_url text, default_next_screen_id uuid, retry_target_screen_id uuid, options jsonb)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT
        ss.id                       AS screen_id,
        ss.screen_type,
        ss.order_index,
        ss.text,
        ss.image_url,
        ss.default_next_screen_id,
        ss.retry_target_screen_id,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id',              so.id,
                        'text',            so.text,
                        'next_screen_id',  so.next_screen_id,
                        'is_correct',      so.is_correct,
                        'order_index',     so.order_index
                    ) ORDER BY so.order_index
                )
                FROM screen_options so
                WHERE so.screen_id = ss.id
            ),
            '[]'::JSONB
        )                           AS options
    FROM scenario_screens ss
    WHERE ss.scenario_id = p_scenario_id
    ORDER BY ss.order_index ASC;
$function$
```

`generate_daily_question_set` picks 5 question IDs at random (3–5 from the three core modules, the rest from the two foundation modules), excluding IDs from `get_excluded_question_ids`. It selects by `module` and `id` only; no text is involved.

## Row-level security policies

| Table | Policy | Command / role | Condition |
|---|---|---|---|
| questions | Questions are readable by authenticated users | SELECT / authenticated | true |
| lessons | Lessons are readable by authenticated users | SELECT / authenticated | true |
| scenarios | Anyone reads published scenarios | SELECT / public | is_published = true |
| scenario_screens | Anyone reads screens | SELECT / public | true |
| screen_options | Anyone reads options | SELECT / public | true |
| practices, practice_details, practice_steps | "…viewable by everyone" | SELECT / public | true |
| xp_rules | XP rules are readable | SELECT / authenticated | true |
| user_xp_events | Users read own xp events | SELECT / authenticated | auth.uid() = user_id |
| daily_question_sets | view / insert own | SELECT, INSERT / authenticated | auth.uid() = user_id |
| user_question_completions | view / insert own | SELECT, INSERT / authenticated | auth.uid() = user_id |
| user_lesson_quiz_answers | view / insert own | SELECT, INSERT / authenticated | auth.uid() = user_id |
| user_daily_practice_sessions | view / insert own | SELECT, INSERT / authenticated | auth.uid() = user_id |
| user_daily_practice_streaks | view / insert / update own | SELECT, INSERT, UPDATE / authenticated | auth.uid() = user_id |
| user_scenario_progress | read / insert / update own | SELECT, INSERT, UPDATE / public | auth.uid() = user_id |
| user_scenario_completions | read / insert own | SELECT, INSERT / public | auth.uid() = user_id |
| user_practice_progress | view / insert / update own | SELECT, INSERT, UPDATE / public | auth.uid() = user_id |
| approach_logs | view / insert / update / delete own | all four / public | auth.uid() = user_id |
| daily_practice_completions | read / insert own | SELECT, INSERT / public | auth.uid() = user_id |

No table has a write policy for content (questions, scenarios, screens, options, lessons); content is written with the service role.

## Triggers

| Table | Trigger | Action |
|---|---|---|
| questions | update_questions_updated_at | BEFORE UPDATE → `update_updated_at_column()` |
| scenarios | trg_scenarios_updated_at | BEFORE UPDATE → `set_updated_at()` |
| scenario_screens | trg_screens_updated_at | BEFORE UPDATE → `set_updated_at()` |
| practices, practice_details, user_practice_progress | update_*_updated_at | BEFORE UPDATE → `update_updated_at_column()` |

## Extensions and scheduling

Extensions: `plpgsql`, `pgcrypto`, `uuid-ossp`, `pg_stat_statements`, `supabase_vault`.
`pg_cron` is not installed (no `cron` schema), so there are no scheduled database jobs.

## What this settles for the localization plan

| Question | Answer |
|---|---|
| P2: do stored daily question sets hold IDs or text? | **IDs** (`question_ids uuid[]`). Question text is read live from `questions`, so a client-side overlay by question ID works for daily practice. |
| Do the RPCs return IDs the client can overlay on? | **Yes.** `get_or_create_daily_questions` returns `question_id`; `get_scenario_screens` returns `screen_id` and each option's `id`. No RPC needs changing. |
| Real names of the scenario tables | `scenario_screens`, `screen_options`. |
| Which translation tables are needed | `question_translations`, `scenario_translations`, `scenario_screen_translations`, `screen_option_translations`. The three practice tables are empty and need none. |
| Read policies to mirror | Questions: authenticated only. Scenarios, screens, options: public. |
| Server-side scheduled text | None (`pg_cron` absent). |
| Course tables | Do not exist; the app's Swift catalog is the only source. |
| Database region | `us-east-1`. |
