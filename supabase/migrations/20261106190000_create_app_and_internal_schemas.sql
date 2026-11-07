-- Creates the two schemas the data model lives in, empty and closed to the API.
--
-- Checked by: after `supabase db reset`, schemas `app` and `internal` exist and
-- hold nothing, `anon` and `authenticated` lack USAGE on both, and a REST
-- request with `Accept-Profile: app` is refused with PGRST106 because neither
-- schema is in [api] schemas in supabase/config.toml.

create schema app;
create schema internal;

-- This closes schema USAGE only: anon and authenticated cannot reach anything
-- in either schema until a later migration grants it. It does not cover
-- functions, because Postgres grants EXECUTE on new functions to PUBLIC, so each
-- function's own migration revokes EXECUTE itself (AD-3).
revoke all on schema app, internal from public, anon, authenticated;
