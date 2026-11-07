-- Enables pgTAP, the database test framework `supabase test db` runs
-- supabase/tests/database/ with (R7, AD-21: only epic-platform-baseline
-- enables extensions).
--
-- Checked by: `supabase test db` passes on a fresh local stack, and
-- `select extversion from pg_extension where extname = 'pgtap'` returns a row.

create extension if not exists pgtap with schema extensions;
