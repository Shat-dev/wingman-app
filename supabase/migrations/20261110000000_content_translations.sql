-- Content translation tables — WP7 of docs/localization-implementation-plan.md
--
-- NOT APPLIED. Written 2026-11-10 against the live schema as captured in
-- supabase/snapshots/live-schema-2026-11-10.md. Nothing in this file has been
-- run on project bnckmgnysfliiypvxxii. It ships no data: with these tables
-- empty, every user sees exactly the English content they see today.
--
-- Checked without a database: parsed with the PostgreSQL 17 grammar (pglast),
-- including the plpgsql bodies, and every statement confirmed to create or
-- alter only the new objects below. It has NOT been executed anywhere. Run it
-- on a branch or a local stack first, then the checks at the bottom.
--
-- ADDITIVE ONLY (rule R6 of the plan)
--
-- Creates four tables, two functions, five triggers, four policies and four
-- indexes. Changes no existing table, column, function, policy, ID or foreign
-- key. The only existing objects referenced are the four content tables, as
-- foreign-key targets, and the standard Supabase roles.
--
-- English stays where it is. `questions`, `scenarios`, `scenario_screens` and
-- `screen_options` remain the source of structure, order, branching and
-- scoring. A translation row holds display text for one English row in one
-- language, and nothing else: no answer indexes, no next-screen pointers, no
-- flags. A translation can therefore never change what is correct or where a
-- scenario goes; the worst a bad row can do is show the wrong words.
--
-- No RPC changes. `get_or_create_daily_questions` returns `question_id` and
-- `get_scenario_screens` returns `screen_id` and each option's `id`, so the
-- app fetches English exactly as it does now and, only when its language is
-- not English, makes one extra query for the translation rows of the IDs it
-- just received.
--
-- SHAPE, AND WHY
--
--   * Primary key (english_row_id, locale): one translation per row per
--     language, and the lookup the app makes (these IDs, this locale) is the
--     primary key itself.
--   * Every text column is NULLABLE and may not be blank. NULL means "not
--     translated, show the English"; the app falls back field by field. A
--     blank string is rejected so a field can never render empty
--     (requirement 9).
--   * ON DELETE CASCADE: deleting an English row removes its translations.
--     Nothing else could be done with them.
--   * `question_translations.options` must have the same number of entries as
--     the English `options`, each a non-blank string. Correctness is an INDEX
--     into that array (`correct_answer_index`, `correct_answer_indices`), so
--     a translated array of a different length would silently move the right
--     answer. A CHECK cannot look at another table, so a trigger enforces it.
--     The app also refuses a translated array whose length differs, because
--     the English row can be edited after the translation was written.
--   * `locale` is a lowercase BCP 47 language tag: "de", "sv", "pt-br". The
--     app sends the language its interface is actually running in.
--
-- SECURITY
--
-- Read access mirrors the base tables exactly:
--
--   questions          SELECT  authenticated          -> question_translations: same
--   scenarios          SELECT  public, published only -> scenario_translations: same,
--                                                         via the parent row
--   scenario_screens   SELECT  public                 -> same
--   screen_options     SELECT  public                 -> same
--
-- No write policy exists on any of them, so with RLS on, only the service
-- role can write. Supabase's default privileges also GRANT ALL on new public
-- tables to `anon` and `authenticated`; RLS stops ordinary writes, but
-- TRUNCATE is not subject to RLS, so the grants are cut back to SELECT
-- explicitly (the lesson recorded in 20260811161839_xp_ledger.sql).
--
-- Both functions pin `search_path` and are SECURITY INVOKER.

begin;

-- ---------------------------------------------------------------------------
-- Shared trigger: keep updated_at current
-- ---------------------------------------------------------------------------
--
-- A new function rather than the existing `set_updated_at()` /
-- `update_updated_at_column()`: those have a mutable search_path, and this
-- migration does not alter existing objects to fix that.

create function public.set_translation_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

revoke all on function public.set_translation_updated_at() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- question_translations
-- ---------------------------------------------------------------------------

create table public.question_translations (
    question_id    uuid        not null references public.questions (id) on delete cascade,
    locale         text        not null,
    question_text  text,
    options        jsonb,
    explanation    text,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),

    constraint question_translations_pkey
        primary key (question_id, locale),
    constraint question_translations_locale_format
        check (locale ~ '^[a-z]{2,3}(-[a-z0-9]{2,8})*$'),
    constraint question_translations_question_text_not_blank
        check (question_text is null or btrim(question_text) <> ''),
    constraint question_translations_explanation_not_blank
        check (explanation is null or btrim(explanation) <> ''),
    constraint question_translations_options_is_array
        check (options is null or jsonb_typeof(options) = 'array'),
    constraint question_translations_has_content
        check (question_text is not null or options is not null or explanation is not null)
);

comment on table public.question_translations is
    'Display text for one question in one language. English stays in public.questions; answer indexes are never stored here.';
comment on column public.question_translations.options is
    'Translated answer options, same order and same count as questions.options (enforced by trigger). NULL = show the English options.';

-- For the app''s cache fingerprint: "has anything changed for this language?"
create index question_translations_locale_updated_at_idx
    on public.question_translations (locale, updated_at desc);

-- The options array must line up with the English one. See SHAPE above.
create function public.check_question_translation_options()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    english_options jsonb;
    english_count   integer;
    option_value    jsonb;
begin
    if new.options is null then
        return new;
    end if;

    select q.options
      into english_options
      from public.questions q
     where q.id = new.question_id;

    if english_options is null or jsonb_typeof(english_options) <> 'array' then
        raise exception
            'question_translations: question % has no English options array to translate', new.question_id
            using errcode = 'check_violation';
    end if;

    english_count := jsonb_array_length(english_options);

    if jsonb_array_length(new.options) <> english_count then
        raise exception
            'question_translations: % options for question % in locale %, but the English question has %',
            jsonb_array_length(new.options), new.question_id, new.locale, english_count
            using errcode = 'check_violation';
    end if;

    for option_value in select value from jsonb_array_elements(new.options)
    loop
        if jsonb_typeof(option_value) <> 'string' or btrim(option_value #>> '{}') = '' then
            raise exception
                'question_translations: every option for question % in locale % must be a non-blank string',
                new.question_id, new.locale
                using errcode = 'check_violation';
        end if;
    end loop;

    return new;
end;
$$;

revoke all on function public.check_question_translation_options() from public, anon, authenticated;

create trigger question_translations_check_options
    before insert or update of options, question_id
    on public.question_translations
    for each row
    execute function public.check_question_translation_options();

create trigger question_translations_set_updated_at
    before update
    on public.question_translations
    for each row
    execute function public.set_translation_updated_at();

alter table public.question_translations enable row level security;

create policy "Question translations are readable by authenticated users"
    on public.question_translations
    for select
    to authenticated
    using (true);

revoke all on table public.question_translations from anon, authenticated;
grant select on table public.question_translations to authenticated;

-- ---------------------------------------------------------------------------
-- scenario_translations
-- ---------------------------------------------------------------------------

create table public.scenario_translations (
    scenario_id  uuid        not null references public.scenarios (id) on delete cascade,
    locale       text        not null,
    title        text,
    summary      text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),

    constraint scenario_translations_pkey
        primary key (scenario_id, locale),
    constraint scenario_translations_locale_format
        check (locale ~ '^[a-z]{2,3}(-[a-z0-9]{2,8})*$'),
    constraint scenario_translations_title_not_blank
        check (title is null or btrim(title) <> ''),
    constraint scenario_translations_summary_not_blank
        check (summary is null or btrim(summary) <> ''),
    constraint scenario_translations_has_content
        check (title is not null or summary is not null)
);

comment on table public.scenario_translations is
    'Display title and summary for one scenario in one language. Analytics keeps using the English title from public.scenarios.';

create index scenario_translations_locale_updated_at_idx
    on public.scenario_translations (locale, updated_at desc);

create trigger scenario_translations_set_updated_at
    before update
    on public.scenario_translations
    for each row
    execute function public.set_translation_updated_at();

alter table public.scenario_translations enable row level security;

-- Mirrors "Anyone reads published scenarios": a translation is readable
-- exactly when its scenario is.
create policy "Anyone reads translations of published scenarios"
    on public.scenario_translations
    for select
    to public
    using (
        exists (
            select 1
              from public.scenarios s
             where s.id = scenario_translations.scenario_id
               and s.is_published = true
        )
    );

revoke all on table public.scenario_translations from anon, authenticated;
grant select on table public.scenario_translations to anon, authenticated;

-- ---------------------------------------------------------------------------
-- scenario_screen_translations
-- ---------------------------------------------------------------------------

create table public.scenario_screen_translations (
    screen_id   uuid        not null references public.scenario_screens (id) on delete cascade,
    locale      text        not null,
    text        text        not null,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),

    constraint scenario_screen_translations_pkey
        primary key (screen_id, locale),
    constraint scenario_screen_translations_locale_format
        check (locale ~ '^[a-z]{2,3}(-[a-z0-9]{2,8})*$'),
    constraint scenario_screen_translations_text_not_blank
        check (btrim(text) <> '')
);

comment on table public.scenario_screen_translations is
    'Display text for one scenario screen in one language. Branching (next and retry screens) stays in public.scenario_screens.';

create index scenario_screen_translations_locale_updated_at_idx
    on public.scenario_screen_translations (locale, updated_at desc);

create trigger scenario_screen_translations_set_updated_at
    before update
    on public.scenario_screen_translations
    for each row
    execute function public.set_translation_updated_at();

alter table public.scenario_screen_translations enable row level security;

create policy "Anyone reads screen translations"
    on public.scenario_screen_translations
    for select
    to public
    using (true);

revoke all on table public.scenario_screen_translations from anon, authenticated;
grant select on table public.scenario_screen_translations to anon, authenticated;

-- ---------------------------------------------------------------------------
-- screen_option_translations
-- ---------------------------------------------------------------------------

create table public.screen_option_translations (
    option_id   uuid        not null references public.screen_options (id) on delete cascade,
    locale      text        not null,
    text        text        not null,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),

    constraint screen_option_translations_pkey
        primary key (option_id, locale),
    constraint screen_option_translations_locale_format
        check (locale ~ '^[a-z]{2,3}(-[a-z0-9]{2,8})*$'),
    constraint screen_option_translations_text_not_blank
        check (btrim(text) <> '')
);

comment on table public.screen_option_translations is
    'Display text for one scenario answer option in one language. is_correct and next_screen_id stay in public.screen_options.';

create index screen_option_translations_locale_updated_at_idx
    on public.screen_option_translations (locale, updated_at desc);

create trigger screen_option_translations_set_updated_at
    before update
    on public.screen_option_translations
    for each row
    execute function public.set_translation_updated_at();

alter table public.screen_option_translations enable row level security;

create policy "Anyone reads option translations"
    on public.screen_option_translations
    for select
    to public
    using (true);

revoke all on table public.screen_option_translations from anon, authenticated;
grant select on table public.screen_option_translations to anon, authenticated;

commit;

-- ---------------------------------------------------------------------------
-- CHECKS TO RUN AFTER APPLYING (on a branch or local stack first)
-- ---------------------------------------------------------------------------
--
-- 1. Additive only. Before and after, the counts of pre-existing objects must
--    be identical, and the new ones must be exactly:
--        +4 tables, +2 functions, +5 triggers, +4 policies,
--        +8 indexes (4 primary keys, 4 locale/updated_at)
--
--      select count(*) from information_schema.tables where table_schema = 'public';
--      select count(*) from pg_policies where schemaname = 'public';
--
-- 2. Empty tables change nothing. As an authenticated user:
--      select count(*) from public.question_translations;            -- 0
--    and the app in English makes no request to any of the four tables.
--
-- 3. The options guard. With a real question id whose English options has N
--    entries, as the service role:
--      insert into public.question_translations (question_id, locale, options)
--      values ('<id>', 'de', '["a"]'::jsonb);                 -- must FAIL when N <> 1
--      insert ... values ('<id>', 'de', '["a", "", "c"]');    -- must FAIL (blank option)
--      insert ... values ('<id>', 'de', '[1, 2, 3]');         -- must FAIL (not strings)
--      insert ... N non-blank strings;                        -- must succeed
--
-- 4. Blank text is rejected:
--      insert into public.scenario_translations (scenario_id, locale, title)
--      values ('<id>', 'de', '   ');                          -- must FAIL
--
-- 5. Access. As anon:
--      select * from public.question_translations;            -- permission denied
--      select * from public.scenario_translations;            -- only published scenarios
--      insert / update / delete / truncate on any of the four -- permission denied
--    As authenticated: select allowed on all four, writes denied on all four.
--
-- 6. Run the Supabase advisors (security and performance) and confirm no new
--    finding names any of these objects.
--
-- ROLLBACK (drops only what this file created)
--
--   begin;
--   drop table if exists public.screen_option_translations;
--   drop table if exists public.scenario_screen_translations;
--   drop table if exists public.scenario_translations;
--   drop table if exists public.question_translations;
--   drop function if exists public.check_question_translation_options();
--   drop function if exists public.set_translation_updated_at();
--   commit;
