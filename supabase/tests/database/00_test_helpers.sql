-- The pgTAP side of the shared persona cast (story 3, decision 2; test design
-- TC-3). The TypeScript side is app/tests/support/test-users.ts; persona names
-- and emails match between the two.
--
-- Runs first (file name order) and, unlike every other file here, COMMITS, so
-- the helpers exist for the files after it. They live in schema `tests`,
-- which no migration creates, so they exist only on a local or CI stack and
-- never on the hosted project.
--
-- In a test file, inside begin ... rollback:
--   select tests.create_persona('teacher_a');   -- an auth user, rolled back with the test
--   select tests.authenticate_as('teacher_a');  -- role authenticated, auth.uid() = teacher_a
--   select tests.persona_id('teacher_a');       -- that user's id
--   select tests.authenticate_as_anon();        -- role anon, no JWT claims
--   select tests.clear_authentication();        -- back to postgres
--
-- Epics extend the cast here: epic-invite-sign-in gives the admin and the
-- teachers their roles, epic-classes-rosters adds the students and classes
-- (only in A, in A and B, removed, archived).
--
-- Scheduled jobs take the run time as a parameter (story 3, decision 4;
-- TC-2): a test passes the time it needs, e.g.
--   select internal.run_due_reminders(now := '2026-12-01 09:00+00');
-- and never waits on the clock.

select plan(1);

create schema if not exists tests;
grant usage on schema tests to anon, authenticated;

create table if not exists tests.personas (
  name text primary key,
  user_id uuid not null
);

-- persona-teacher-a@test.example.com, as personaEmail() in test-users.ts.
create or replace function tests.persona_email(persona text)
returns text
language sql
immutable
as $$ select 'persona-' || replace(persona, '_', '-') || '@test.example.com' $$;

create or replace function tests.create_persona(persona text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  persona_user_id uuid;
begin
  if persona !~ '^[a-z][a-z0-9_]*$' then
    raise exception 'Persona names are snake_case, like teacher_a; got %', persona;
  end if;

  -- A Playwright run may already have created this persona's auth user on
  -- the local stack; reuse it rather than collide on the email.
  select id into persona_user_id from auth.users where email = tests.persona_email(persona);

  if persona_user_id is null then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
      tests.persona_email(persona), '', now(),
      '{"provider": "email", "providers": ["email"]}', '{}', now(), now()
    )
    returning id into persona_user_id;
  end if;

  insert into tests.personas (name, user_id) values (persona, persona_user_id)
  on conflict (name) do update set user_id = excluded.user_id;

  return persona_user_id;
end
$$;

create or replace function tests.persona_id(persona text)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  persona_user_id uuid;
begin
  select user_id into persona_user_id from tests.personas where name = persona;
  if persona_user_id is null then
    raise exception 'No persona %; call tests.create_persona(%) first', persona, quote_literal(persona);
  end if;
  return persona_user_id;
end
$$;

-- Security invoker on purpose: Postgres refuses SET ROLE inside a security
-- definer function.
create or replace function tests.authenticate_as(persona text)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', tests.persona_id(persona),
      'role', 'authenticated',
      'email', tests.persona_email(persona)
    )::text,
    true
  );
  perform set_config('role', 'authenticated', true);
end
$$;

create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end
$$;

create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'none', true);
end
$$;

grant execute on all functions in schema tests to anon, authenticated;

select ok(to_regproc('tests.authenticate_as') is not null, 'the persona helpers are installed');

select * from finish();
