-- pg_cron, pg_net and the job health check (migration 20261106230000; R7, R8,
-- AD-21 "silent failures", AD-17, P1-002, P1-015). public.job_health(run_at)
-- returns every failure since the previous check, from internal.job_failures,
-- failed pg_cron runs and non-2xx or failed pg_net calls, and records the
-- check. Every call here passes an explicit run_at (TC-2), and the test clears
-- the four sources first, inside the transaction, so rows on a shared local
-- stack cannot change the result.

begin;
select plan(48);

-- Installed where the migration says.
select is(
  (select n.nspname::text from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'pg_cron'),
  'pg_catalog', 'pg_cron is installed in pg_catalog');
select is(
  (select n.nspname::text from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'pg_net'),
  'extensions', 'pg_net is installed in extensions');

-- Tables and columns.
select has_table('internal', 'job_failures', 'internal.job_failures exists');
select has_table('internal', 'job_health_checks', 'internal.job_health_checks exists');
select columns_are('internal', 'job_failures',
  array['id', 'job', 'error_code', 'detail', 'failed_at', 'reported_at'],
  'internal.job_failures has exactly its six columns');
select columns_are('internal', 'job_health_checks', array['checked_at'],
  'internal.job_health_checks has exactly checked_at');
select has_index('internal', 'job_failures', 'job_failures_failed_at_idx', 'failed_at',
  'job_failures is indexed on failed_at');
select ok(
  (select pg_get_indexdef(i.indexrelid) like '% WHERE (reported_at IS NULL)'
     from pg_index i where i.indexrelid = 'internal.job_failures_failed_at_idx'::regclass),
  'the failed_at index covers only rows not yet reported');

-- The function.
select is_definer('public', 'job_health', array['timestamp with time zone'],
  'public.job_health is security definer');
select function_owner_is('public', 'job_health', array['timestamp with time zone'], 'postgres',
  'public.job_health is owned by postgres');
select ok(
  (select p.proconfig @> array['search_path=""'] from pg_proc p
    where p.oid = 'public.job_health(timestamp with time zone)'::regprocedure),
  'public.job_health sets search_path to the empty path');

-- Who may call it, and who may reach the tables and schemas (AD-3).
select ok(not has_function_privilege('anon', 'public.job_health(timestamp with time zone)', 'execute'),
  'anon cannot execute job_health');
select ok(not has_function_privilege('authenticated', 'public.job_health(timestamp with time zone)', 'execute'),
  'authenticated cannot execute job_health');
select ok(has_function_privilege('service_role', 'public.job_health(timestamp with time zone)', 'execute'),
  'service_role can execute job_health');
select ok(not exists (
  select 1
  from unnest(array['anon', 'authenticated', 'service_role']) as r(role_name),
       unnest(array['internal.job_failures', 'internal.job_health_checks']) as t(table_name)
  where has_table_privilege(r.role_name, t.table_name,
    'select,insert,update,delete,truncate,references,trigger')
), 'no API role holds a privilege on the two internal tables');
select ok(not exists (
  select 1
  from unnest(array['anon', 'authenticated', 'service_role']) as r(role_name),
       unnest(array['internal', 'cron']) as s(schema_name)
  where has_schema_privilege(r.role_name, s.schema_name, 'usage')
), 'no API role has usage on internal or cron');

-- Start from empty sources and no earlier check.
delete from internal.job_health_checks;
delete from internal.job_failures;
delete from cron.job_run_details;
delete from net._http_response;

create temp table res (n int primary key, r jsonb not null);

-- Failures the first check must report. Window times are in January 2030.
insert into internal.job_failures (job, error_code, detail, failed_at) values
  ('j1', 'boom', '{"k": 1}', '2030-01-01 01:00+00'),
  ('j-long', repeat('x', 600), '{}', '2030-01-01 01:05+00'),
  -- exactly at the first check's run_at: belongs to the second check's window
  ('j-edge-next', 'edge', '{}', '2030-01-02 00:00+00');

-- cron.schedule, not an insert: postgres cannot write cron.job directly. The
-- job is rolled back with the transaction, before pg_cron could run it.
select cron.schedule('test-job-health', '* * * * *', 'select 1');

insert into cron.job_run_details (jobid, runid, status, return_message, start_time, end_time)
select j.jobid, v.runid, v.status, v.return_message, v.start_time, v.end_time
from cron.job j,
  (values
    (900000001::bigint, 'failed',    'ERROR: cron boom', '2030-01-01 01:29+00'::timestamptz, '2030-01-01 01:30+00'::timestamptz),
    (900000002::bigint, 'succeeded', 'SELECT 1',         '2030-01-01 01:30+00'::timestamptz, '2030-01-01 01:31+00'::timestamptz),
    (900000003::bigint, 'failed',    'no end time',      '2030-01-01 01:45+00'::timestamptz, null::timestamptz)
  ) as v(runid, status, return_message, start_time, end_time)
where j.jobname = 'test-job-health';
-- A run of a job that has since been unscheduled.
insert into cron.job_run_details (jobid, runid, status, return_message, start_time, end_time)
values (999999999, 900000004, 'failed', 'gone', '2030-01-01 01:50+00', '2030-01-01 01:51+00');

insert into net._http_response (id, status_code, timed_out, error_msg, created) values
  (900000001, 500,  false, null,                    '2030-01-01 02:00+00'),
  (900000002, 200,  false, null,                    '2030-01-01 02:01+00'),
  (900000003, 204,  false, null,                    '2030-01-01 02:02+00'),
  (900000004, null, true,  'Timeout was reached',   '2030-01-01 02:03+00'),
  (900000005, 301,  false, null,                    '2030-01-01 02:04+00');

-- First check ever: no lower bound.
insert into res select 1, public.job_health('2030-01-02 00:00+00');

select is((select r->'since' from res where n = 1), 'null'::jsonb, 'first check: since is null');
select is(
  (select array_agg(reported_at order by job) from internal.job_failures where job in ('j1', 'j-long')),
  array['2030-01-02 00:00+00', '2030-01-02 00:00+00']::timestamptz[],
  'the first check marks the job_failures rows it returned as reported at run_at');
select is((select (r->>'until')::timestamptz from res where n = 1), '2030-01-02 00:00+00'::timestamptz,
  'first check: until is run_at');
select is((select jsonb_array_length(r->'failures') from res where n = 1), 8,
  'first check reports 8 failures');
select is(
  (select array_agg(f->>'source' order by f->>'source') from res, jsonb_array_elements(r->'failures') f where n = 1),
  array['cron', 'cron', 'cron', 'http', 'http', 'http', 'job_failures', 'job_failures'],
  'first check: three cron, three http and two job_failures items');
select is(
  (select f->>'error' from res, jsonb_array_elements(r->'failures') f where n = 1 and f->>'job' = 'j1'),
  'boom', 'a job_failures item carries error_code as error');
select is(
  (select f->'detail' from res, jsonb_array_elements(r->'failures') f where n = 1 and f->>'job' = 'j1'),
  '{"k": 1}'::jsonb, 'a job_failures item carries detail');
select is(
  (select length(f->>'error') from res, jsonb_array_elements(r->'failures') f where n = 1 and f->>'job' = 'j-long'),
  500, 'an error is cut to 500 characters');
select is(
  (select f->>'error' from res, jsonb_array_elements(r->'failures') f
    where n = 1 and f->>'source' = 'cron' and f->>'job' = 'test-job-health' and f->>'error' like 'ERROR%'),
  'ERROR: cron boom', 'a failed cron run names its job from cron.job and carries return_message');
select is(
  (select (f->>'at')::timestamptz from res, jsonb_array_elements(r->'failures') f
    where n = 1 and f->>'error' = 'ERROR: cron boom'),
  '2030-01-01 01:30+00'::timestamptz, 'a failed cron run is dated by its end time');
select is(
  (select (f->>'at')::timestamptz from res, jsonb_array_elements(r->'failures') f
    where n = 1 and f->>'error' = 'no end time'),
  '2030-01-01 01:45+00'::timestamptz, 'a failed cron run with no end time is dated by its start time');
select is(
  (select f->>'job' from res, jsonb_array_elements(r->'failures') f where n = 1 and f->>'error' = 'gone'),
  'job 999999999', 'a failed cron run of an unscheduled job is named by its id');
select is(
  (select f->>'error' from res, jsonb_array_elements(r->'failures') f
    where n = 1 and f->>'source' = 'http' and f->>'job' = 'request 900000001'),
  'HTTP 500', 'a 500 pg_net response is reported');
select is(
  (select f->>'error' from res, jsonb_array_elements(r->'failures') f
    where n = 1 and f->>'source' = 'http' and f->>'job' = 'request 900000004'),
  'Timeout was reached', 'a pg_net call with no status is reported with its error_msg');
select is(
  (select f->>'error' from res, jsonb_array_elements(r->'failures') f
    where n = 1 and f->>'source' = 'http' and f->>'job' = 'request 900000005'),
  'HTTP 301', 'a 3xx pg_net response is reported');
select ok(not exists (
  select 1 from res, jsonb_array_elements(r->'failures') f
  where n = 1 and (f->>'job' = 'request 900000002' or f->>'job' = 'request 900000003' or f->>'error' = 'SELECT 1')
), 'succeeded cron runs and 200 or 204 responses are not reported');
select is(
  (select array_agg((f->>'at')::timestamptz order by ord) = array_agg((f->>'at')::timestamptz order by (f->>'at')::timestamptz)
     from res, jsonb_array_elements(r->'failures') with ordinality as x(f, ord) where n = 1),
  true, 'failures are ordered by time');

-- The window is [since, run_at): a failure at the earlier run_at belongs to
-- the next check.
insert into res select 2, public.job_health('2030-01-03 00:00+00');
select is((select (r->>'since')::timestamptz from res where n = 2), '2030-01-02 00:00+00'::timestamptz,
  'second check: since is the first check''s run_at');
select is((select jsonb_agg(f->>'job') from res, jsonb_array_elements(r->'failures') f where n = 2),
  '["j-edge-next"]'::jsonb, 'second check: only the failure at the first run_at, none reported again');

-- Reported once.
insert into res select 3, public.job_health('2030-01-04 00:00+00');
select is((select r->'failures' from res where n = 3), '[]'::jsonb,
  'third check: nothing is reported again');

insert into internal.job_failures (job, error_code, failed_at) values
  ('j-edge-since', 'at since', '2030-01-04 00:00+00'),
  ('j-edge-until', 'at until', '2030-01-05 00:00+00');
insert into res select 4, public.job_health('2030-01-05 00:00+00');
select is((select jsonb_agg(f->>'job') from res, jsonb_array_elements(r->'failures') f where n = 4),
  '["j-edge-since"]'::jsonb, 'a failure at since is in the window and one at run_at is not');
insert into res select 5, public.job_health('2030-01-06 00:00+00');
select is((select jsonb_agg(f->>'job') from res, jsonb_array_elements(r->'failures') f where n = 5),
  '["j-edge-until"]'::jsonb, 'the failure at the earlier run_at is in the next window');

-- A run time before the last check records nothing.
select throws_ok(
  $$select public.job_health('2030-01-05 12:00+00')$$,
  '22023', 'run_at_before_last_check',
  'a run_at before the last check raises 22023 run_at_before_last_check');
select is((select count(*)::int from internal.job_health_checks), 5,
  'the refused call recorded nothing');

-- A job_failures row dated before the previous check but not yet reported (its
-- writer committed after that check) is picked by the next check, and cron and
-- http rows are bounded by the window shifted back by the 10 minute settle lag.
insert into internal.job_failures (job, error_code, failed_at) values
  ('j-late', 'committed late', '2030-01-03 00:00+00');
insert into net._http_response (id, status_code, created) values
  -- 5 minutes before the previous check (2030-01-06): inside its lag, so this check
  (900000010, 500, '2030-01-05 23:55+00'),
  -- 5 minutes before this check's run_at: inside this check's lag, so the next
  (900000011, 502, '2030-01-06 23:55+00');
insert into cron.job_run_details (jobid, runid, status, return_message, start_time, end_time)
select j.jobid, 900000010, 'failed', 'cron late', '2030-01-06 23:54+00', '2030-01-06 23:55+00'
from cron.job j where j.jobname = 'test-job-health';

select is((select reported_at from internal.job_failures where job = 'j-late'), null::timestamptz,
  'a late-committed job_failures row starts unreported');
insert into res select 6, public.job_health('2030-01-07 00:00+00');
select is(
  (select array_agg(f->>'job' order by f->>'job') from res, jsonb_array_elements(r->'failures') f where n = 6),
  array['j-late', 'request 900000010'],
  'the next check reports the late job_failures row and the http row from the previous check''s lag, not the rows in its own lag');
select is((select reported_at from internal.job_failures where job = 'j-late'), '2030-01-07 00:00+00'::timestamptz,
  'the late job_failures row is marked reported at that check''s run_at');
insert into res select 7, public.job_health('2030-01-08 00:00+00');
select is(
  (select array_agg(f->>'job' order by f->>'job') from res, jsonb_array_elements(r->'failures') f where n = 7),
  array['request 900000011', 'test-job-health'],
  'the rows 5 minutes before the earlier run_at are reported by the next check');

-- A run_at equal to the last check is refused too, with the same key.
select throws_ok(
  $$select public.job_health('2030-01-08 00:00+00')$$,
  '22023', 'run_at_before_last_check',
  'a run_at equal to the last check raises 22023 run_at_before_last_check');
select is((select count(*)::int from internal.job_health_checks), 7,
  'the refused calls recorded nothing');

-- Wrong callers (P1-015).
set local role authenticated;
select throws_ok($$select public.job_health('2030-02-01 00:00+00')$$, '42501', null,
  'authenticated calling job_health is refused with 42501');
reset role;
set local role anon;
select throws_ok($$select public.job_health('2030-02-01 00:00+00')$$, '42501', null,
  'anon calling job_health is refused with 42501');
reset role;

select * from finish();
rollback;
