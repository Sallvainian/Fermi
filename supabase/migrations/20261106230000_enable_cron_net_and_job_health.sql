-- Enables pg_cron and pg_net, and adds the failure record and the health check
-- that make a failed scheduled job visible (R7, R8, AD-21 "silent failures",
-- P1-002, P1-015).
--
--   internal.job_failures      one row per failed scheduled job, written by the
--                              job itself (later epics insert here); reported_at
--                              is set when a check returns the row
--   internal.job_health_checks one row per check; the latest is the start of
--                              the next check's window
--   public.job_health(run_at)  returns every failure since the previous check
--                              from three sources (job_failures, failed pg_cron
--                              runs, non-2xx or failed pg_net calls) and
--                              records this check. Only service_role may call
--                              it; .github/workflows/keep-alive.yml does,
--                              twice a day, through the Data API.
--
-- Why two rules. A failure row becomes visible when its writer commits, but its
-- time is set when the writer's transaction starts (now()), so a window on time
-- alone loses a row whose transaction started before a check and committed
-- after it. job_failures rows, written from inside long job transactions
-- (AD-15), are therefore picked by reported_at is null and then marked, which
-- is exact whatever the commit timing. cron.job_run_details and
-- net._http_response belong to the extensions and cannot be marked; their
-- writers commit within seconds of the row's time, so they use the time window
-- shifted back by a settle lag of 10 minutes. Consecutive shifted windows still
-- tile with no gap or overlap, and a row committed within 10 minutes of its
-- time is always seen. Known limit: pg_net deletes net._http_response rows
-- after pg_net.ttl (6 hours, a sighup setting), so a twice-daily check sees
-- only the HTTP failures of the last 6 hours.
--
-- Checked by: `supabase test db` (supabase/tests/database/04_job_health.sql)
-- and scripts/test-check-job-health.sh, which calls the function over the
-- local Data API with the secret key.

-- The docs' pg_cron grants: the postgres role reads cron.job and
-- cron.job_run_details inside the definer function below.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

create extension if not exists pg_net with schema extensions;

-- A uuid key, not an identity column, so no sequence lies outside the privilege
-- catalog test.
create table internal.job_failures (
  id uuid primary key default gen_random_uuid(),
  job text not null,
  error_code text not null,
  detail jsonb not null default '{}',
  failed_at timestamptz not null default now(),
  reported_at timestamptz
);

create index job_failures_failed_at_idx on internal.job_failures (failed_at)
  where reported_at is null;

create table internal.job_health_checks (
  checked_at timestamptz primary key
);

-- No API role holds a grant on either table (AD-3).
revoke all on table internal.job_failures, internal.job_health_checks
  from public, anon, authenticated, service_role;

create function public.job_health(run_at timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_since timestamptz;
  v_failures jsonb;
  -- cron and http rows are read this far behind the check; see the header.
  v_settle constant interval := interval '10 minutes';
begin
  -- Serialise checks. A second concurrent call waits here, then either records
  -- a later window or, when its run_at is not after the first call's, raises
  -- run_at_before_last_check, so no failure is returned twice.
  lock table internal.job_health_checks in exclusive mode;

  select max(c.checked_at) into v_since from internal.job_health_checks c;

  if v_since is not null and run_at <= v_since then
    raise exception using errcode = '22023', message = 'run_at_before_last_check';
  end if;

  with marked as (
    update internal.job_failures m
       set reported_at = run_at
     where m.reported_at is null
       and m.failed_at < run_at
    returning m.job, m.error_code, m.failed_at, m.detail
  )
  select coalesce(jsonb_agg(
           jsonb_build_object(
             'source', f.source,
             'job', f.job,
             'error', left(f.error, 500),
             'at', f.at
           ) || case when f.detail is null then '{}'::jsonb
                     else jsonb_build_object('detail', f.detail) end
           order by f.at, f.source, f.job),
         '[]'::jsonb)
    into v_failures
  from (
    select 'job_failures' as source,
           jf.job as job,
           jf.error_code as error,
           jf.failed_at as at,
           jf.detail as detail
      from marked jf
    union all
    select 'cron',
           coalesce(j.jobname, 'job ' || d.jobid::text),
           coalesce(d.return_message, ''),
           coalesce(d.end_time, d.start_time),
           null::jsonb
      from cron.job_run_details d
      left join cron.job j on j.jobid = d.jobid
     where d.status = 'failed'
       and coalesce(d.end_time, d.start_time) < run_at - v_settle
       and (v_since is null or coalesce(d.end_time, d.start_time) >= v_since - v_settle)
    union all
    select 'http',
           'request ' || r.id::text,
           coalesce(r.error_msg,
                    case when r.timed_out then 'timed out'
                         else 'HTTP ' || coalesce(r.status_code::text, 'no status') end),
           r.created,
           null::jsonb
      from net._http_response r
     where (r.status_code is null or r.status_code not between 200 and 299)
       and r.created < run_at - v_settle
       and (v_since is null or r.created >= v_since - v_settle)
  ) f;

  insert into internal.job_health_checks (checked_at) values (run_at);

  return jsonb_build_object('since', v_since, 'until', run_at, 'failures', v_failures);
end;
$fn$;

alter function public.job_health(timestamptz) owner to postgres;

-- Postgres grants EXECUTE on a new function to PUBLIC, and Supabase's default
-- privileges to anon and authenticated too (AD-3).
revoke all on function public.job_health(timestamptz) from public, anon, authenticated;
grant execute on function public.job_health(timestamptz) to service_role;
