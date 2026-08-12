-- XP computed amounts — Phase 1b of docs/xp-system-plan.md
--
-- Reshapes the award mechanism from "one flat integer per source type" into the
-- locked economy in that plan's §0, and adds the approach daily cap.
--
-- WHY THIS IS SAFE TO DO AS A RESHAPE RATHER THAN AN ADDITIVE CHANGE
--
-- `user_xp_events` holds 0 rows and the Phase 2 client is unshipped, so there is
-- nothing to backfill, no user total moves, and no released binary depends on
-- the old RPC signature. That stops being true the moment Phase 3 ships, which
-- is why this lands now.
--
-- THE ECONOMY (plan §0, locked 2026-08-12)
--
--   daily_practice  10 + 3×correct + 5 if all correct      -> 10..30
--   lesson          20 + 5×correct + 5 if all correct      -> 20..35 (2q) / 20..40 (3q)
--   scenario        50 flat                                 -> 50
--   approach        50 flat, capped at 250 per local day    -> 0 or 50
--
-- WHO COMPUTES THE AMOUNT
--
-- The client sends facts (`correct_count`, `question_count`); this function
-- computes the amount. The client still never names a number, so amounts stay
-- tunable by UPDATE rather than by App Store release. The trust assumption is
-- identical to the one `update_daily_practice_streak` already makes — it accepts
-- client-supplied `p_questions_answered` / `p_correct_answers` today — and
-- `QuizEngine.correctCount` is first-answer-wins (QuizEngine.swift:55-63), so
-- re-answering cannot inflate it.
--
-- Note the approach cap makes even a "flat" source conditional: the award is 50
-- or 0 depending on how much that user has already earned from approaches on
-- that local date. That is a second, independent reason the amount could not
-- remain a constant in `xp_rules`.

-- ---------------------------------------------------------------------------
-- 1. Retire the flat-amount function
-- ---------------------------------------------------------------------------
--
-- Dropped, not replaced. The new function has a different arity, so
-- `create or replace` would leave BOTH overloads live — and the old one reads
-- `xp_rules.amount`, which section 2 removes, so it would start failing at
-- runtime while still being exposed at /rest/v1/rpc/award_xp.

drop function if exists public.award_xp(text, text, date);

-- ---------------------------------------------------------------------------
-- 2. Rules table: flat amount -> formula components
-- ---------------------------------------------------------------------------

alter table public.xp_rules
  add column if not exists base_amount   integer,
  add column if not exists per_correct   integer not null default 0,
  add column if not exists perfect_bonus integer not null default 0,
  add column if not exists daily_cap     integer;

comment on column public.xp_rules.base_amount   is 'Paid for completing the activity at all.';
comment on column public.xp_rules.per_correct   is 'Multiplied by the clamped correct answer count. 0 for sources with no quiz.';
comment on column public.xp_rules.perfect_bonus is 'Added when question_count > 0 and every answer was correct.';
comment on column public.xp_rules.daily_cap     is 'Max XP from this source per user per local_date. NULL = uncapped.';

update public.xp_rules set base_amount = 10, per_correct = 3, perfect_bonus = 5, daily_cap = null   where source_type = 'daily_practice';
update public.xp_rules set base_amount = 20, per_correct = 5, perfect_bonus = 5, daily_cap = null   where source_type = 'lesson';
update public.xp_rules set base_amount = 50, per_correct = 0, perfect_bonus = 0, daily_cap = null   where source_type = 'scenario';
update public.xp_rules set base_amount = 50, per_correct = 0, perfect_bonus = 0, daily_cap = 250    where source_type = 'approach';

alter table public.xp_rules alter column base_amount set not null;

-- Dropping the column takes its check constraint with it.
alter table public.xp_rules drop column if exists amount;

alter table public.xp_rules drop constraint if exists xp_rules_base_positive;
alter table public.xp_rules add  constraint xp_rules_base_positive      check (base_amount > 0);
alter table public.xp_rules drop constraint if exists xp_rules_per_correct_nonneg;
alter table public.xp_rules add  constraint xp_rules_per_correct_nonneg check (per_correct >= 0);
alter table public.xp_rules drop constraint if exists xp_rules_perfect_nonneg;
alter table public.xp_rules add  constraint xp_rules_perfect_nonneg     check (perfect_bonus >= 0);
alter table public.xp_rules drop constraint if exists xp_rules_cap_positive;
alter table public.xp_rules add  constraint xp_rules_cap_positive       check (daily_cap is null or daily_cap > 0);

-- ---------------------------------------------------------------------------
-- 3. The award function
-- ---------------------------------------------------------------------------
--
-- Returns (awarded, amount_awarded, total_xp, capped).
--
--   awarded  false for a replay AND for a capped attempt. `capped`
--            distinguishes them, which the completion screen needs: a replay
--            should show nothing, a capped award should be able to say why.
--   capped   true only when a genuinely new award was refused by the daily cap.
--
-- The duplicate check runs BEFORE the cap check so the two states can never be
-- confused. `ON CONFLICT DO NOTHING` stays as the race guard behind it.

create or replace function public.award_xp(
  p_source_type    text,
  p_source_id      text,
  p_local_date     date    default current_date,
  p_correct_count  integer default 0,
  p_question_count integer default 0
)
returns table (awarded boolean, amount_awarded integer, total_xp integer, capped boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid       uuid := auth.uid();
  v_rule      public.xp_rules%rowtype;
  v_date      date := coalesce(p_local_date, current_date);
  v_questions integer;
  v_correct   integer;
  v_amount    integer;
  v_today     integer;
  v_new_id    uuid;
begin
  if v_uid is null then
    raise exception 'award_xp: no authenticated user'
      using errcode = '28000',
            hint = 'award_xp derives the user from auth.uid(); call it with a user JWT.';
  end if;

  if p_source_id is null or btrim(p_source_id) = '' then
    raise exception 'award_xp: source_id must be a non-empty string'
      using errcode = '22023';
  end if;

  select * into v_rule from public.xp_rules r where r.source_type = p_source_type;
  if not found then
    raise exception 'award_xp: unknown source_type %', p_source_type
      using errcode = '22023',
            hint = 'Add a row to public.xp_rules before awarding this source type.';
  end if;

  -- Already paid for this exact thing. Answered before the cap is consulted so
  -- a retry of an already-awarded item never reports itself as capped.
  if exists (
    select 1 from public.user_xp_events e
     where e.user_id = v_uid
       and e.source_type = p_source_type
       and e.source_id = p_source_id
  ) then
    return query select false, 0,
      coalesce((select sum(e.amount)::integer from public.user_xp_events e where e.user_id = v_uid), 0),
      false;
    return;
  end if;

  -- Clamp rather than reject. A malformed payload must not become a poison pill
  -- that the client's outbox retries forever against the same error.
  v_questions := greatest(coalesce(p_question_count, 0), 0);
  v_correct   := least(greatest(coalesce(p_correct_count, 0), 0), v_questions);

  v_amount := v_rule.base_amount
            + (v_rule.per_correct * v_correct)
            + case when v_questions > 0 and v_correct = v_questions
                   then v_rule.perfect_bonus else 0 end;

  -- Daily cap. XP beyond the cap is forfeited, not deferred — the client drops
  -- the queued award on any successful response, capped included.
  if v_rule.daily_cap is not null then
    select coalesce(sum(e.amount), 0) into v_today
      from public.user_xp_events e
     where e.user_id = v_uid
       and e.source_type = p_source_type
       and e.local_date = v_date;

    if v_today + v_amount > v_rule.daily_cap then
      return query select false, 0,
        coalesce((select sum(e.amount)::integer from public.user_xp_events e where e.user_id = v_uid), 0),
        true;
      return;
    end if;
  end if;

  insert into public.user_xp_events (user_id, source_type, source_id, amount, local_date)
  values (v_uid, p_source_type, p_source_id, v_amount, v_date)
  on conflict on constraint user_xp_events_once do nothing
  returning id into v_new_id;

  return query
    select v_new_id is not null,
           case when v_new_id is not null then v_amount else 0 end,
           coalesce((select sum(e.amount)::integer
                       from public.user_xp_events e
                      where e.user_id = v_uid), 0),
           false;
end;
$function$;

revoke execute on function public.award_xp(text, text, date, integer, integer) from public, anon;
grant  execute on function public.award_xp(text, text, date, integer, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Assertions
-- ---------------------------------------------------------------------------
--
-- The security invariants from the Phase 1 migration, plus arithmetic checks
-- that the seeded rules actually produce the locked economy. The arithmetic
-- ones are pure reads of xp_rules — they award nothing.

do $xp_1b_invariants$
declare
  v_count integer;
  v_calc  integer;
begin
  -- Security: the RPC must remain the only write path.
  select count(*) into v_count
    from pg_policies
   where schemaname = 'public' and tablename = 'user_xp_events' and cmd <> 'SELECT';
  if v_count > 0 then
    raise exception 'user_xp_events has % non-SELECT policy(ies); award_xp must be the only write path', v_count;
  end if;

  if has_function_privilege('anon', 'public.award_xp(text, text, date, integer, integer)', 'execute') then
    raise exception 'anon must not be able to execute award_xp';
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'award_xp'
       and pg_get_function_identity_arguments(p.oid) like '%p_user_id%'
  ) then
    raise exception 'award_xp must not accept a user id argument; identity comes from auth.uid()';
  end if;

  -- Exactly one award_xp overload must exist, or PostgREST has an ambiguous
  -- endpoint and the retired flat-amount version may still be reachable.
  select count(*) into v_count
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'award_xp';
  if v_count <> 1 then
    raise exception 'expected exactly 1 award_xp overload, found %', v_count;
  end if;

  -- Economy: the seeded rules must produce the locked numbers.
  select base_amount + per_correct * 5 + perfect_bonus into v_calc
    from public.xp_rules where source_type = 'daily_practice';
  if v_calc <> 30 then raise exception 'daily_practice 5/5 should be 30, got %', v_calc; end if;

  select base_amount into v_calc from public.xp_rules where source_type = 'daily_practice';
  if v_calc <> 10 then raise exception 'daily_practice floor should be 10, got %', v_calc; end if;

  select base_amount + per_correct * 3 + perfect_bonus into v_calc
    from public.xp_rules where source_type = 'lesson';
  if v_calc <> 40 then raise exception 'lesson 3/3 should be 40, got %', v_calc; end if;

  select base_amount + per_correct * 2 + perfect_bonus into v_calc
    from public.xp_rules where source_type = 'lesson';
  if v_calc <> 35 then raise exception 'lesson 2/2 should be 35, got %', v_calc; end if;

  select base_amount into v_calc from public.xp_rules where source_type = 'scenario';
  if v_calc <> 50 then raise exception 'scenario should be 50, got %', v_calc; end if;

  select base_amount into v_calc from public.xp_rules where source_type = 'approach';
  if v_calc <> 50 then raise exception 'approach should be 50, got %', v_calc; end if;

  select daily_cap into v_calc from public.xp_rules where source_type = 'approach';
  if v_calc <> 250 then raise exception 'approach daily cap should be 250, got %', v_calc; end if;

  raise notice 'XP 1b invariants verified: security intact, economy matches plan §0.';
end
$xp_1b_invariants$;
