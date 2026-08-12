-- XP award breakdown — returns the components, not just the sum
--
-- The completion screen itemises what an award was made of:
--
--     +20   Completed
--     +15   3 correct
--     +5    All correct
--     +40 XP
--
-- The client cannot derive that. It sends `correct_count` / `question_count`
-- and receives a single `amount_awarded`; the base / per-correct / perfect-bonus
-- values live only in `xp_rules`. An earlier revision kept a local Swift mirror
-- of them and it was deleted on purpose — an unexercised duplicate of the
-- economy drifts silently and is wrong the day someone wires it up. So the
-- server returns the parts it already computed.
--
-- WHY DROP AND RECREATE RATHER THAN REPLACE
--
-- `create or replace function` cannot change a function's return type. The
-- argument list is unchanged, so this is not a new overload — it is the same
-- function with three more output columns, and Postgres requires the drop.
--
-- The components are 0 whenever `awarded` is false (a replay, or the approach
-- daily cap refusing), so a client rendering a breakdown from them cannot show
-- line items for an award that did not happen.

drop function if exists public.award_xp(text, text, date, integer, integer);

create or replace function public.award_xp(
  p_source_type    text,
  p_source_id      text,
  p_local_date     date    default current_date,
  p_correct_count  integer default 0,
  p_question_count integer default 0
)
returns table (
  awarded          boolean,
  amount_awarded   integer,
  total_xp         integer,
  capped           boolean,
  base_awarded     integer,
  correct_awarded  integer,
  bonus_awarded    integer
)
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
  v_base      integer;
  v_correct_x integer;
  v_bonus     integer;
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
      false, 0, 0, 0;
    return;
  end if;

  -- Clamp rather than reject. A malformed payload must not become a poison pill
  -- that the client's outbox retries forever against the same error.
  v_questions := greatest(coalesce(p_question_count, 0), 0);
  v_correct   := least(greatest(coalesce(p_correct_count, 0), 0), v_questions);

  v_base      := v_rule.base_amount;
  v_correct_x := v_rule.per_correct * v_correct;
  v_bonus     := case when v_questions > 0 and v_correct = v_questions
                      then v_rule.perfect_bonus else 0 end;
  v_amount    := v_base + v_correct_x + v_bonus;

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
        true, 0, 0, 0;
      return;
    end if;
  end if;

  insert into public.user_xp_events (user_id, source_type, source_id, amount, local_date)
  values (v_uid, p_source_type, p_source_id, v_amount, v_date)
  on conflict on constraint user_xp_events_once do nothing
  returning id into v_new_id;

  return query
    select v_new_id is not null,
           case when v_new_id is not null then v_amount    else 0 end,
           coalesce((select sum(e.amount)::integer
                       from public.user_xp_events e
                      where e.user_id = v_uid), 0),
           false,
           case when v_new_id is not null then v_base      else 0 end,
           case when v_new_id is not null then v_correct_x else 0 end,
           case when v_new_id is not null then v_bonus     else 0 end;
end;
$function$;

revoke execute on function public.award_xp(text, text, date, integer, integer) from public, anon;
grant  execute on function public.award_xp(text, text, date, integer, integer) to authenticated, service_role;

do $xp_breakdown_invariants$
declare
  v_count integer;
begin
  select count(*) into v_count
    from pg_policies
   where schemaname = 'public' and tablename = 'user_xp_events' and cmd <> 'SELECT';
  if v_count > 0 then
    raise exception 'user_xp_events has % non-SELECT policy(ies); award_xp must be the only write path', v_count;
  end if;

  if has_function_privilege('anon', 'public.award_xp(text, text, date, integer, integer)', 'execute') then
    raise exception 'anon must not be able to execute award_xp';
  end if;

  select count(*) into v_count
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'award_xp';
  if v_count <> 1 then
    raise exception 'expected exactly 1 award_xp overload, found %', v_count;
  end if;

  -- The components must reconstruct the total, or the itemised screen would
  -- show line items that do not add up to the figure beneath them.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'award_xp'
       and pg_get_function_result(p.oid) like '%base_awarded%'
       and pg_get_function_result(p.oid) like '%correct_awarded%'
       and pg_get_function_result(p.oid) like '%bonus_awarded%'
  ) then
    raise exception 'award_xp must return the three award components';
  end if;

  raise notice 'XP breakdown invariants verified.';
end
$xp_breakdown_invariants$;
