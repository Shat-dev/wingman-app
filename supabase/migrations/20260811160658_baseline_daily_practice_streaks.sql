-- Baseline — Daily Practice streak schema
-- See docs/xp-system-plan.md §2 (Phase 0)
--
-- WHY THIS EXISTS
--
-- The streak feature's database objects were created directly against the
-- live project and were never captured in this repository. Before this file,
-- `supabase/migrations/` contained only the two lesson-question migrations,
-- so there was:
--
--   * no rollback target for any future change to these objects,
--   * no way to stand up a staging/branch database that can run Daily
--     Practice at all, and
--   * no reviewable record of the streak rules, which live entirely in
--     PL/pgSQL.
--
-- This migration is a **transcription of the current production definitions**,
-- not a change to them. It is written idempotently (`if not exists`,
-- `or replace`, `drop policy if exists`) so applying it to production is a
-- verified no-op, and applying it to an empty database reproduces the feature.
--
-- APPLIED to project bnckmgnysfliiypvxxii on 2026-08-11 as ledger version
-- 20260811160658 (this file's name matches that version deliberately — the CLI
-- matches on the version prefix, and two of the older migrations in this
-- directory carry versions the remote has never seen; see the note at the
-- bottom of this header). The apply was verified as a byte-for-byte no-op:
-- every function definition, policy, constraint, index, column default, ACL
-- and data hash was identical before and after.
--
-- The two function bodies below are byte-identical to `pg_proc.prosrc`:
--
--   get_daily_practice_status     md5(prosrc) = ff5b4746caed4de84177e91108679429  (2118 bytes)
--   update_daily_practice_streak  md5(prosrc) = b10739d2b5ee14294389e22edea3b7cd  (2709 bytes)
--
-- If you edit a function body here, that md5 no longer matches and this file
-- stops being a baseline. Record the new hash in the same place, or better,
-- put the change in its own migration and leave this one alone.
--
-- DELIBERATELY NOT FIXED HERE
--
-- Two known issues are reproduced faithfully rather than corrected, because a
-- baseline that also changes behaviour cannot be verified as a no-op:
--
--   1. Both functions are SECURITY DEFINER and take `p_user_id` as an
--      argument without comparing it to `auth.uid()`, so they bypass the RLS
--      policies below. See docs/diagnostics/xp-gamification-audit.md §A.5.
--   2. Neither function sets `search_path`, which is the usual companion
--      hardening for SECURITY DEFINER.
--
-- Both belong in a separate, deliberate migration with its own testing.
--
-- OUT OF SCOPE
--
-- The rest of the Daily Practice cluster is still un-baselined and should get
-- the same treatment before anything changes it:
--   tables    questions, daily_question_sets, user_question_completions
--   functions get_or_create_daily_questions, generate_daily_question_set,
--             get_excluded_question_ids, get_total_daily_practices
-- Also un-baselined: the scenario tables, approach_logs, and the practices
-- cluster. This file covers only what the XP work sits next to.
--
-- KNOWN LEDGER MISMATCH — READ BEFORE RUNNING `supabase db push`
--
-- As of this migration the remote ledger holds:
--   20260730073852  create_lesson_questions
--   20260730103720  lesson_questions_by_column
--   20260731072912  lesson_question_status_variable_count   <- no local file
--   20260811160658  baseline_daily_practice_streaks         <- this file
--
-- The first two do NOT match the local filenames (20260730000000 /
-- 20260730010000), and the CLI matches on version, not name. So a plain
-- `supabase db push` treats both as unapplied and re-runs them — and
-- 20260730010000 opens with `drop view if exists public.lesson_question_status`,
-- a view that exists in production and whose current definition comes from
-- 20260731072912, for which there is no local file to recreate it.
--
-- Reconcile before pushing anything, including the XP migrations:
--   supabase migration repair --status applied 20260730000000 20260730010000
--   supabase db pull            # to recover 20260731072912 into the repo
--
-- This file was applied via a targeted migration, not a push, for that reason.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

-- One row per user. `current_streak` is only truthful as of
-- `last_completed_date`; the read function re-validates it against today.
create table if not exists public.user_daily_practice_streaks (
  id                   uuid    primary key default gen_random_uuid(),
  user_id              uuid    not null unique references auth.users(id) on delete cascade,
  current_streak       integer not null default 0,
  longest_streak       integer not null default 0,
  last_completed_date  date,
  total_days_completed integer not null default 0,
  created_at           timestamptz default now(),
  updated_at           timestamptz default now()
);

-- One row per user per completed day. Written only by
-- update_daily_practice_streak. This table is the app's "Daily Practice is
-- done today" flag — see get_daily_practice_status below and
-- HomeViewModel.swift:317-319. Do not write rows here from any other feature.
create table if not exists public.user_daily_practice_sessions (
  id                 uuid    primary key default gen_random_uuid(),
  user_id            uuid    not null references auth.users(id) on delete cascade,
  date               date    not null,
  completed_at       timestamptz default now(),
  questions_answered integer not null default 0,
  correct_answers    integer not null default 0,
  constraint user_daily_practice_sessions_user_id_date_key unique (user_id, date)
);

-- Redundant against the unique constraints' backing indexes on both tables,
-- but present in production, so reproduced for fidelity.
create index if not exists idx_streaks_user_id     on public.user_daily_practice_streaks (user_id);
create index if not exists idx_sessions_user_date  on public.user_daily_practice_sessions (user_id, date);

-- ---------------------------------------------------------------------------
-- 2. Row Level Security
-- ---------------------------------------------------------------------------
--
-- Guests (Supabase anonymous users) hold the `authenticated` role, so these
-- policies cover them with no special case.
--
-- Note there is no DELETE policy on either table and no UPDATE policy on
-- sessions. That matches production. The RPCs are SECURITY DEFINER and so are
-- unaffected by any of this.

alter table public.user_daily_practice_streaks  enable row level security;
alter table public.user_daily_practice_sessions enable row level security;

drop policy if exists "Users can view their own streaks"   on public.user_daily_practice_streaks;
create policy "Users can view their own streaks"
  on public.user_daily_practice_streaks for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own streaks" on public.user_daily_practice_streaks;
create policy "Users can insert their own streaks"
  on public.user_daily_practice_streaks for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own streaks" on public.user_daily_practice_streaks;
create policy "Users can update their own streaks"
  on public.user_daily_practice_streaks for update to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can view their own sessions"   on public.user_daily_practice_sessions;
create policy "Users can view their own sessions"
  on public.user_daily_practice_sessions for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own sessions" on public.user_daily_practice_sessions;
create policy "Users can insert their own sessions"
  on public.user_daily_practice_sessions for insert to authenticated
  with check (auth.uid() = user_id);

-- Table-level grants. These are what Supabase's default privileges already
-- give to tables created by `postgres` in `public`, restated so this file also
-- works on a project whose defaults have been altered. RLS above is what
-- actually restricts access.
grant all on table public.user_daily_practice_streaks  to anon, authenticated, service_role;
grant all on table public.user_daily_practice_sessions to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Functions
-- ---------------------------------------------------------------------------
--
-- Bodies below are transcribed verbatim from production, comments, spacing and
-- all. Resist tidying them.
--
-- They are bracketed by two assertions. This file claims to be a no-op; the
-- assertions make it prove that instead of asking you to trust it.

-- PRE-FLIGHT. If either function already exists but does not match the body
-- this file was transcribed from, production has moved on and this file is
-- stale. Abort rather than overwrite someone else's change. Skipped on an
-- empty database, where the functions do not exist yet.
do $baseline_preflight$
declare
  v_actual text;
begin
  select md5(p.prosrc) into v_actual
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_daily_practice_status';
  if v_actual is not null and v_actual <> 'ff5b4746caed4de84177e91108679429' then
    raise exception using
      message = 'Baseline is stale: public.get_daily_practice_status has drifted.',
      detail  = format('live md5(prosrc)=%s, this file expects ff5b4746caed4de84177e91108679429', v_actual),
      hint    = 'Re-transcribe from production before applying. Do not overwrite.';
  end if;

  select md5(p.prosrc) into v_actual
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'update_daily_practice_streak';
  if v_actual is not null and v_actual <> 'b10739d2b5ee14294389e22edea3b7cd' then
    raise exception using
      message = 'Baseline is stale: public.update_daily_practice_streak has drifted.',
      detail  = format('live md5(prosrc)=%s, this file expects b10739d2b5ee14294389e22edea3b7cd', v_actual),
      hint    = 'Re-transcribe from production before applying. Do not overwrite.';
  end if;
end
$baseline_preflight$;

CREATE OR REPLACE FUNCTION public.get_daily_practice_status(p_user_id uuid, p_date date)
 RETURNS TABLE(current_streak integer, total_completed integer, is_completed_today boolean, can_resume boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_stored_streak       INTEGER := 0;
    v_total_completed     INTEGER := 0;
    v_last_completed_date DATE;
    v_current_streak      INTEGER := 0;
    v_completed_today     BOOLEAN := FALSE;
    v_can_resume          BOOLEAN := TRUE;
BEGIN
    -- Read the stored streak row, including last_completed_date
    -- (the previous version ignored this column, which was the bug).
    SELECT
        COALESCE(s.current_streak, 0),
        COALESCE(s.total_days_completed, 0),
        s.last_completed_date
    INTO v_stored_streak, v_total_completed, v_last_completed_date
    FROM user_daily_practice_streaks s
    WHERE s.user_id = p_user_id;

    -- Validate the streak against today. The stored value is only truthful at
    -- the moment of the last completion; if a day has been missed since then
    -- with no completion, the streak is broken and must read as 0. This
    -- mirrors the write-side rule in update_daily_practice_streak, where a
    -- streak continues only when last_completed_date = yesterday.
    --
    --   last_completed = today            -> alive, return stored
    --   last_completed = yesterday        -> alive (today still open), return stored
    --   last_completed < yesterday (or NULL) -> broken, return 0
    v_current_streak := CASE
        WHEN v_last_completed_date IS NULL           THEN 0
        WHEN v_last_completed_date >= p_date - 1     THEN v_stored_streak
        ELSE 0
    END;

    -- is_completed_today: query the actual completion signal. Previously this
    -- checked daily_question_sets, which is populated when the day's questions
    -- are *generated* (at session start) rather than when the user finishes.
    -- user_daily_practice_sessions is written by update_daily_practice_streak
    -- on completion, so it is the authoritative signal.
    SELECT EXISTS(
        SELECT 1
        FROM user_daily_practice_sessions
        WHERE user_id = p_user_id AND date = p_date
    ) INTO v_completed_today;

    v_can_resume := NOT v_completed_today;

    RETURN QUERY SELECT v_current_streak, v_total_completed, v_completed_today, v_can_resume;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_daily_practice_streak(p_user_id uuid, p_date date, p_questions_answered integer, p_correct_answers integer)
 RETURNS TABLE(current_streak integer, total_completed integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_current_streak INTEGER := 0;
    v_longest_streak INTEGER := 0;
    v_total_completed INTEGER := 0;
    v_last_completed_date DATE;
    v_yesterday DATE := p_date - INTERVAL '1 day';
BEGIN
    -- Insert or update the daily session
    INSERT INTO user_daily_practice_sessions (user_id, date, questions_answered, correct_answers)
    VALUES (p_user_id, p_date, p_questions_answered, p_correct_answers)
    ON CONFLICT (user_id, date) 
    DO UPDATE SET 
        questions_answered = EXCLUDED.questions_answered,
        correct_answers = EXCLUDED.correct_answers,
        completed_at = NOW();
    
    -- Get or create streak record (use table alias to avoid ambiguity)
    SELECT 
        COALESCE(s.current_streak, 0),
        COALESCE(s.longest_streak, 0), 
        COALESCE(s.total_days_completed, 0),
        s.last_completed_date
    INTO v_current_streak, v_longest_streak, v_total_completed, v_last_completed_date
    FROM user_daily_practice_streaks s
    WHERE s.user_id = p_user_id;
    
    -- If no streak record exists, create one
    IF NOT FOUND THEN
        v_current_streak := 1;
        v_longest_streak := 1;
        v_total_completed := 1;
        
        INSERT INTO user_daily_practice_streaks (
            user_id, current_streak, longest_streak, total_days_completed, last_completed_date
        ) VALUES (
            p_user_id, v_current_streak, v_longest_streak, v_total_completed, p_date
        );
    ELSE
        -- Check if continuing streak or starting new one
        IF v_last_completed_date = v_yesterday THEN
            -- Continuing streak
            v_current_streak := v_current_streak + 1;
        ELSIF v_last_completed_date < v_yesterday THEN
            -- Streak broken, start new one
            v_current_streak := 1;
        ELSE
            -- Same day completion, don't change streak
            -- v_current_streak stays the same
        END IF;
        
        -- Update longest streak if current is higher
        v_longest_streak := GREATEST(v_longest_streak, v_current_streak);
        
        -- Update total completed (only increment if new day)
        IF v_last_completed_date != p_date THEN
            v_total_completed := v_total_completed + 1;
        END IF;
        
        -- Update the streak record
        UPDATE user_daily_practice_streaks SET
            current_streak = v_current_streak,
            longest_streak = v_longest_streak,
            total_days_completed = v_total_completed,
            last_completed_date = p_date,
            updated_at = NOW()
        WHERE user_id = p_user_id;
    END IF;
    
    -- Return the current values
    RETURN QUERY SELECT v_current_streak, v_total_completed;
END;
$function$;

-- Matches production, where PUBLIC holds EXECUTE on both (the PostgreSQL
-- default for newly created functions).
grant execute on function public.get_daily_practice_status(uuid, date) to anon, authenticated, service_role;
grant execute on function public.update_daily_practice_streak(uuid, date, integer, integer) to anon, authenticated, service_role;

-- POST-FLIGHT. The bodies above must land byte-for-byte identical to what was
-- transcribed. If a whitespace-stripping editor, a copy-paste, or a migration
-- runner mangled them, this raises and the surrounding transaction rolls the
-- whole file back — so a mangled apply leaves production untouched rather than
-- quietly reformatted.
do $baseline_postflight$
declare
  v_actual text;
begin
  select md5(p.prosrc) into v_actual
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_daily_practice_status';
  if v_actual is distinct from 'ff5b4746caed4de84177e91108679429' then
    raise exception using
      message = 'Baseline apply corrupted public.get_daily_practice_status.',
      detail  = format('post-apply md5(prosrc)=%s, expected ff5b4746caed4de84177e91108679429', v_actual),
      hint    = 'Function bodies must be applied verbatim, trailing whitespace included.';
  end if;

  select md5(p.prosrc) into v_actual
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'update_daily_practice_streak';
  if v_actual is distinct from 'b10739d2b5ee14294389e22edea3b7cd' then
    raise exception using
      message = 'Baseline apply corrupted public.update_daily_practice_streak.',
      detail  = format('post-apply md5(prosrc)=%s, expected b10739d2b5ee14294389e22edea3b7cd', v_actual),
      hint    = 'Function bodies must be applied verbatim, trailing whitespace included.';
  end if;

  raise notice 'Baseline verified: both function bodies match production byte-for-byte.';
end
$baseline_postflight$;
