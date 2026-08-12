-- XP ledger — Phase 1 of docs/xp-system-plan.md
--
-- APPLIED to project bnckmgnysfliiypvxxii on 2026-08-11 as ledger version
-- 20260811161839. Verified after apply: streak functions, policies and data all
-- hashed identical to before; object counts moved by exactly +2 tables,
-- +2 functions, +2 policies and nothing else.
--
-- Additive only. Creates no dependency on, and makes no change to, the streak
-- schema baselined in 20260811160658_baseline_daily_practice_streaks.sql. The
-- only pre-existing objects referenced are auth.users and the standard Supabase
-- roles.
--
-- THREE CORRECTIONS TO THE PLAN THIS IMPLEMENTS
--
-- docs/xp-system-plan.md §3 as originally written was wrong in three ways. The
-- plan has been amended, but the reasoning belongs next to the code:
--
--   1. It specified `security invoker` for award_xp, and resolved the resulting
--      RLS problem with "add an INSERT policy". That is a hole: Supabase's
--      default privileges GRANT ALL on new public tables to `authenticated`, so
--      an INSERT policy of `with check (auth.uid() = user_id)` lets any client
--      POST straight to /rest/v1/user_xp_events with an `amount` of its
--      choosing, bypassing xp_rules and award_xp entirely. Resolved below with
--      SECURITY DEFINER + no write policies, so the RPC is the only way in.
--   2. It omitted `search_path` on the new functions — the very hardening it
--      criticises the streak functions for lacking.
--   3. It omitted the EXECUTE revoke. CREATE FUNCTION grants EXECUTE to PUBLIC
--      by default, so without it these would be anon-callable and would trip
--      the same linter rule the streak RPCs trip today.
--
-- The plan also named the RPC's output column `amount`. RETURNS TABLE names
-- become plpgsql variables and `amount` is a real column on both tables here,
-- so it is `amount_awarded` below.
--
-- SHAPE, AND WHY
--
-- An append-only ledger rather than a mutable counter, because lessons and
-- scenarios are both re-completable in the app (CourseDetailSheet.swift:143,
-- PracticeView.swift:156-196 gate on isLocked and the paywall, never on
-- isCompleted). Once-only therefore has to be a database constraint —
-- `user_xp_events_once` — not client logic. `user_scenario_completions` is the
-- cautionary example: no unique constraint, so every replay inserts another row.
--
-- The running total is derived with sum(), not stored. At tens of rows per user
-- that is free, and it removes a whole class of drift bug. Revisit only if a
-- leaderboard needs it.
--
-- THREE DELIBERATE DEPARTURES FROM THE STREAK RPCs
--
--   1. No p_user_id parameter. Identity comes from auth.uid() inside the
--      function. update_daily_practice_streak takes a user id and never checks
--      it against auth.uid(), so any authenticated caller can advance any other
--      user's streak (see docs/diagnostics/xp-gamification-audit.md §A.5.2).
--      That flaw is not reproduced here.
--   2. search_path is pinned. The streak functions leave it mutable, which the
--      Supabase linter flags on every one of them.
--   3. EXECUTE is revoked from PUBLIC and anon, so the RPC is not reachable
--      without a session. The streak RPCs are callable by anon today.
--
-- WHY SECURITY DEFINER HERE IS NOT THE SAME MISTAKE
--
-- award_xp must bypass RLS to write, because there is deliberately no INSERT
-- policy on user_xp_events: if there were one, Supabase's default table grants
-- would let a client POST straight to /rest/v1/user_xp_events and choose its own
-- `amount`, bypassing the rules table entirely. SECURITY DEFINER plus an
-- auth.uid()-derived user is what makes the RPC the only way in. The caller
-- controls neither who is credited nor how much.

-- ---------------------------------------------------------------------------
-- 1. Award amounts (server-owned)
-- ---------------------------------------------------------------------------
--
-- A table rather than a CASE in the function, so amounts are tunable with a SQL
-- update instead of an App Store release. The client ships a mirror of these
-- values for optimistic display only; the server's number is authoritative.

create table if not exists public.xp_rules (
  source_type text primary key,
  amount      integer not null check (amount > 0),
  updated_at  timestamptz not null default now()
);

-- PLACEHOLDER AMOUNTS — open decision 1 in docs/xp-system-plan.md §11.
-- Ordered by the effort measured in the audit (§D.3): scenario (49-65 authored
-- screens, 5-7 decision points) > lesson (median 14 paragraphs, ~350 words, 3
-- questions, no time gate) > daily practice (exactly 5 questions). Note the
-- audit's finding that a lesson is roughly TWICE a daily practice in taps, not
-- five times — do not inflate `lesson` on intuition.
--
-- `approach` is seeded but nothing awards it until Phase 2 decides to; it is the
-- one self-reported source, so it is deliberately not the largest.
insert into public.xp_rules (source_type, amount) values
  ('daily_practice', 20),
  ('lesson',         30),
  ('scenario',       50),
  ('approach',       40)
on conflict (source_type) do nothing;

-- ---------------------------------------------------------------------------
-- 2. The ledger
-- ---------------------------------------------------------------------------
--
-- source_id is the identity of the thing that was done, and is what makes an
-- award once-only:
--   daily_practice  the local date, '2026-08-12'  -> one award per day
--   lesson          lesson.id, 'lesson_7_3'       -> replaying pays nothing
--   scenario        scenario uuid as text         -> replaying pays nothing
--   approach        approach_logs.id as text      -> delete+relog pays nothing

create table if not exists public.user_xp_events (
  id          uuid    primary key default gen_random_uuid(),
  user_id     uuid    not null references auth.users(id) on delete cascade,
  source_type text    not null references public.xp_rules(source_type),
  source_id   text    not null check (btrim(source_id) <> ''),
  amount      integer not null check (amount > 0),
  local_date  date    not null,
  awarded_at  timestamptz not null default now(),
  constraint user_xp_events_once unique (user_id, source_type, source_id)
);

-- Only one index is added. `user_xp_events_once` already indexes user_id as its
-- leading column, which serves the sum-by-user read, so a separate index on
-- user_id would be dead weight — the streak tables carry exactly that kind of
-- redundant index today.
create index if not exists idx_user_xp_events_user_recent
  on public.user_xp_events (user_id, awarded_at desc);

-- ---------------------------------------------------------------------------
-- 3. Row Level Security
-- ---------------------------------------------------------------------------
--
-- Read-only to clients. There is intentionally NO insert, update or delete
-- policy on user_xp_events: with RLS enabled and no permissive policy for a
-- command, that command is denied outright. award_xp is the only write path.
--
-- Guests hold the `authenticated` role (a Supabase anonymous user is a real
-- auth.users row), so these policies cover the 23 guest accounts on this
-- project with no special case.

alter table public.xp_rules       enable row level security;
alter table public.user_xp_events enable row level security;

drop policy if exists "XP rules are readable" on public.xp_rules;
create policy "XP rules are readable"
  on public.xp_rules for select to authenticated
  using (true);

drop policy if exists "Users read own xp events" on public.user_xp_events;
create policy "Users read own xp events"
  on public.user_xp_events for select to authenticated
  using (auth.uid() = user_id);

-- Defence in depth. RLS already denies these, but Supabase's default privileges
-- hand ALL on new public tables to anon and authenticated, and a future policy
-- added without this context would silently open a write path that bypasses the
-- rules table. Revoking makes the intent explicit at the grant layer too.
revoke insert, update, delete, truncate on table public.user_xp_events from anon, authenticated;
revoke insert, update, delete, truncate on table public.xp_rules       from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. The award function
-- ---------------------------------------------------------------------------
--
-- Returns (awarded, amount_awarded, total_xp).
--
--   awarded        false on a replay — the caller must not claim XP it did not
--                  get. The completion screen keys its animation off this.
--   amount_awarded 0 on a replay.
--   total_xp       always the recomputed authoritative total, so the client can
--                  set its cached value without a second round trip.
--
-- ON CONFLICT DO NOTHING ... RETURNING leaves v_new_id null on a replay, which
-- is what makes the whole thing idempotent — and therefore what makes the
-- client-side outbox in Phase 2 safe to flush at-least-once.
--
-- Output column names avoid `amount`: RETURNS TABLE names become plpgsql
-- variables, and `amount` is a real column on both tables in this file.

create or replace function public.award_xp(
  p_source_type text,
  p_source_id   text,
  p_local_date  date default current_date
)
returns table (awarded boolean, amount_awarded integer, total_xp integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid    uuid := auth.uid();
  v_amount integer;
  v_new_id uuid;
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

  select r.amount into v_amount
    from public.xp_rules r
   where r.source_type = p_source_type;

  if v_amount is null then
    raise exception 'award_xp: unknown source_type %', p_source_type
      using errcode = '22023',
            hint = 'Add a row to public.xp_rules before awarding this source type.';
  end if;

  insert into public.user_xp_events (user_id, source_type, source_id, amount, local_date)
  values (v_uid, p_source_type, p_source_id, v_amount, coalesce(p_local_date, current_date))
  on conflict on constraint user_xp_events_once do nothing
  returning id into v_new_id;

  return query
    select v_new_id is not null,
           case when v_new_id is not null then v_amount else 0 end,
           coalesce((select sum(e.amount)::integer
                       from public.user_xp_events e
                      where e.user_id = v_uid), 0);
end;
$function$;

-- Hydration read. SECURITY INVOKER: the SELECT policy already scopes it, and
-- there is no reason to run this with elevated rights.
create or replace function public.get_xp_summary()
returns table (total_xp integer, event_count integer, last_awarded_at timestamptz)
language sql
stable
security invoker
set search_path = public, pg_temp
as $function$
  select coalesce(sum(e.amount), 0)::integer,
         count(*)::integer,
         max(e.awarded_at)
    from public.user_xp_events e
   where e.user_id = auth.uid();
$function$;

-- CREATE FUNCTION grants EXECUTE to PUBLIC by default, which would make these
-- callable without a session and trip the same linter rule the streak RPCs trip.
revoke execute on function public.award_xp(text, text, date)  from public, anon;
revoke execute on function public.get_xp_summary()            from public, anon;
grant  execute on function public.award_xp(text, text, date)  to authenticated, service_role;
grant  execute on function public.get_xp_summary()            to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Assert the security properties this file exists to establish
-- ---------------------------------------------------------------------------
--
-- These are the invariants that make the RPC the only write path. Asserting
-- them here means a later migration that quietly adds an INSERT policy, or
-- re-grants EXECUTE to anon, fails loudly the next time this is replayed
-- rather than opening a hole nobody notices.

do $xp_invariants$
declare
  v_count integer;
begin
  select count(*) into v_count
    from pg_policies
   where schemaname = 'public' and tablename = 'user_xp_events'
     and cmd <> 'SELECT';
  if v_count > 0 then
    raise exception 'user_xp_events has % non-SELECT policy(ies); award_xp must be the only write path', v_count;
  end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'award_xp'
       and p.prosecdef
       and p.proconfig is not null
       and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')
  ) then
    raise exception 'award_xp must be SECURITY DEFINER with a pinned search_path';
  end if;

  if has_function_privilege('anon', 'public.award_xp(text, text, date)', 'execute') then
    raise exception 'anon must not be able to execute award_xp';
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'award_xp'
       and pg_get_function_identity_arguments(p.oid) like '%p_user_id%'
  ) then
    raise exception 'award_xp must not accept a user id argument; identity comes from auth.uid()';
  end if;

  raise notice 'XP ledger invariants verified.';
end
$xp_invariants$;
