-- Phase 5: lessons and scenarios advance the streak
--
-- Until now `update_daily_practice_streak` was the only thing that could move a
-- streak, and it has exactly one caller. Finishing a lesson or a scenario left
-- the streak untouched.
--
-- WHAT THIS DELIBERATELY DOES NOT DO
--
-- 1. **It never writes `user_daily_practice_sessions`.** That table is the
--    app's "Daily Practice is done today" flag: `get_daily_practice_status`
--    reads it for `is_completed_today` / `can_resume`, which drive Home's
--    button state. A lesson writing a row there would tell the user they had
--    already practised and disable the button on them. This is the single
--    biggest trap in widening the streak and the reason this is a separate
--    function rather than a second caller of the existing one.
--
-- 2. **It never increments `total_days_completed`.** That column means "daily
--    practices completed" and is what `get_total_daily_practices` reports.
--    Letting lesson activity inflate it would silently redefine it.
--
-- 3. **No backfill.** Per the product decision, history is not reconstructed.
--    The existing `user_daily_practice_streaks` row already carries each user's
--    accumulated streak, so advancing it in place preserves every current
--    streak exactly — there is nothing to migrate.
--
-- WHY SECURITY INVOKER
--
-- `user_daily_practice_streaks` already has SELECT, INSERT and UPDATE policies
-- for `authenticated`, all scoped to `auth.uid() = user_id`. So this needs no
-- elevated rights, and unlike the two existing streak functions it takes no
-- `p_user_id` to be trusted — the caller cannot move anyone else's streak.
--
-- REPLAYS COUNT
--
-- Re-reading a finished lesson still advances the streak. The streak measures
-- "did you show up today", and the alternative produces the worst possible
-- support ticket: "I did a lesson and my streak didn't move." XP stays
-- once-only; the two are deliberately decoupled.

create or replace function public.mark_streak_activity(
  p_local_date date default current_date
)
returns table (current_streak integer, longest_streak integer, did_extend boolean)
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_uid       uuid := auth.uid();
  v_date      date := coalesce(p_local_date, current_date);
  v_current   integer;
  v_longest   integer;
  v_last      date;
  v_new       integer;
  v_extended  boolean := false;
begin
  if v_uid is null then
    raise exception 'mark_streak_activity: no authenticated user'
      using errcode = '28000';
  end if;

  select s.current_streak, s.longest_streak, s.last_completed_date
    into v_current, v_longest, v_last
    from public.user_daily_practice_streaks s
   where s.user_id = v_uid;

  if not found then
    -- First activity of any kind for this user.
    insert into public.user_daily_practice_streaks
      (user_id, current_streak, longest_streak, total_days_completed, last_completed_date)
    values (v_uid, 1, 1, 0, v_date);

    return query select 1, 1, true;
    return;
  end if;

  -- Same rules as update_daily_practice_streak, so the two writers can never
  -- disagree about what a streak is.
  --
  --   already counted today  -> unchanged
  --   last was yesterday     -> extend
  --   anything older or null -> restart at 1
  if v_last = v_date then
    v_new := coalesce(v_current, 0);
  elsif v_last = v_date - 1 then
    v_new := coalesce(v_current, 0) + 1;
    v_extended := true;
  else
    v_new := 1;
    v_extended := true;
  end if;

  v_longest := greatest(coalesce(v_longest, 0), v_new);

  update public.user_daily_practice_streaks s
     set current_streak      = v_new,
         longest_streak      = v_longest,
         -- total_days_completed intentionally untouched: see note 2 above.
         last_completed_date = greatest(coalesce(s.last_completed_date, v_date), v_date),
         updated_at          = now()
   where s.user_id = v_uid;

  return query select v_new, v_longest, v_extended;
end;
$function$;

revoke execute on function public.mark_streak_activity(date) from public, anon;
grant  execute on function public.mark_streak_activity(date) to authenticated, service_role;

do $streak_activity_invariants$
declare
  v_hash text;
begin
  -- The two pre-existing streak functions must be byte-identical. This whole
  -- phase is additive; if either changed, something went wrong.
  select md5(string_agg(p.proname || md5(pg_get_functiondef(p.oid)), ',' order by p.proname))
    into v_hash
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('update_daily_practice_streak', 'get_daily_practice_status');

  if v_hash <> 'd62ae337ab9cd19bceff985990f26146' then
    raise exception 'the existing streak functions changed; this migration must be purely additive (got %)', v_hash;
  end if;

  if has_function_privilege('anon', 'public.mark_streak_activity(date)', 'execute') then
    raise exception 'anon must not be able to move a streak';
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'mark_streak_activity' and p.prosecdef
  ) then
    raise exception 'mark_streak_activity must be SECURITY INVOKER; RLS already scopes it';
  end if;

  raise notice 'Streak activity invariants verified.';
end
$streak_activity_invariants$;
