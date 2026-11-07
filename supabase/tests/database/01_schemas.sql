-- The app and internal schemas exist and are closed to the API roles
-- (migration 20261106190000; R7, AD-3). Every access rule lives in these two
-- schemas, so anon and authenticated must not be able to reach them directly.
-- With the Playwright api specs, which fail if the Data API serves either
-- schema, this closes DW-3.

begin;
select plan(6);

select has_schema('app', 'schema app exists');
select has_schema('internal', 'schema internal exists');

select ok(not has_schema_privilege('anon', 'app', 'usage'), 'anon has no usage on app');
select ok(not has_schema_privilege('anon', 'internal', 'usage'), 'anon has no usage on internal');
select ok(not has_schema_privilege('authenticated', 'app', 'usage'), 'authenticated has no usage on app');
select ok(not has_schema_privilege('authenticated', 'internal', 'usage'), 'authenticated has no usage on internal');

select * from finish();
rollback;
