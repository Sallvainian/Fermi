-- No table, column, function or view in public, app or internal has a grant
-- the privilege fixture does not list (AD-3 "locked by default", P0-006). A
-- migration can add a function that Postgres grants EXECUTE to PUBLIC, or a
-- table Supabase's default privileges open to anon and authenticated, and no
-- other test would notice. The fixture is privilege_fixture.psql; read it for
-- the line format and how to fix a failure. Effective ACLs are compared, so a
-- function's implicit PUBLIC EXECUTE counts. Grants to an object's owner and
-- extension-owned objects are left out. Sequences and types are out of scope.

begin;
select plan(6);

create temp table privilege_fixture (
  kind text not null,
  object text not null,
  grants text,
  primary key (kind, object)
);
\ir privilege_fixture.psql

-- One canonical form for a grants string, used on both sides so the order a
-- fixture author writes does not matter: tokens sorted by grantee, privileges
-- sorted, ALL expanded and then collapsed again when a table or view grantee
-- holds every privilege, PRIV* for grantable.
create function pg_temp.privilege_canon(grants text, kind text)
returns text
language sql
stable
as $fn$
  with all_privs as (
    select privilege_type as priv from aclexplode(acldefault('r', 10::oid))
  ), tok as (
    select split_part(t, ':', 1) as grantee, split_part(t, ':', 2) as privs
    from regexp_split_to_table(btrim(coalesce(grants, '')), '\s+') as t
    where t <> ''
  ), raw as (
    select tok.grantee, upper(btrim(x)) as spec
    from tok, regexp_split_to_table(tok.privs, ',') as x
    where btrim(x) <> ''
  ), parsed as (
    select grantee, rtrim(spec, '*') as priv, right(spec, 1) = '*' as grantable
    from raw
  ), expanded as (
    select distinct p.grantee, coalesce(a.priv, p.priv) as priv, p.grantable
    from parsed p
    left join all_privs a
      on p.priv = 'ALL'
     and kind in ('table', 'view', 'materialized view', 'foreign table')
  ), per_grantee as (
    select e.grantee,
      case
        when kind in ('table', 'view', 'materialized view', 'foreign table')
         and count(distinct e.grantable) = 1
         and count(distinct e.priv) = (select count(*) from all_privs)
         and count(*) filter (where e.priv in (select priv from all_privs)) = count(*)
        then 'ALL' || case when bool_or(e.grantable) then '*' else '' end
        else string_agg(e.priv || case when e.grantable then '*' else '' end,
                        ',' order by e.priv collate "C", e.grantable)
      end as rendered
    from expanded e
    group by e.grantee
  )
  select coalesce(
    string_agg(grantee || ':' || rendered, ' ' order by grantee collate "C"),
    '')
  from per_grantee
$fn$;

-- The live catalog: objects, then one row per non-owner ACL entry.
create temp table catalog_obj (
  kind text not null,
  object text not null,
  schema_name text not null,
  obj_oid oid,
  owner_oid oid,
  primary key (kind, object)
);
create temp table catalog_acl (
  kind text not null,
  object text not null,
  grantee text not null,
  priv text not null,
  grantable boolean not null
);

insert into catalog_obj
select case c.relkind
         when 'v' then 'view'
         when 'm' then 'materialized view'
         when 'f' then 'foreign table'
         else 'table'
       end,
       format('%I.%I', n.nspname, c.relname), n.nspname, c.oid, c.relowner
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('public', 'app', 'internal')
  and c.relkind in ('r', 'p', 'v', 'm', 'f')
  and not exists (
    select 1 from pg_depend d
    where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e');

insert into catalog_obj
select case p.prokind when 'p' then 'procedure' else 'function' end,
       format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)),
       n.nspname, p.oid, p.proowner
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'app', 'internal')
  and not exists (
    select 1 from pg_depend d
    where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e');

-- Tables, views and the other relations: the effective ACL.
insert into catalog_acl
select o.kind, o.object,
       case a.grantee when 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
       a.privilege_type, a.is_grantable
from catalog_obj o
join pg_class c on c.oid = o.obj_oid
cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
where o.kind in ('table', 'view', 'materialized view', 'foreign table')
  and a.grantee <> c.relowner;

-- Functions and procedures: the effective ACL (a null one is PUBLIC EXECUTE).
insert into catalog_acl
select o.kind, o.object,
       case a.grantee when 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
       a.privilege_type, a.is_grantable
from catalog_obj o
join pg_proc p on p.oid = o.obj_oid
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
where o.kind in ('function', 'procedure')
  and a.grantee <> p.proowner;

-- Columns: every column of every relation above gets an object row, with or
-- without grants. Its grants are its column-level ACL (attacl) only; table-level
-- grants stay on the table line.
insert into catalog_obj (kind, object, schema_name, obj_oid, owner_oid)
select 'column', format('%s.%I', o.object, att.attname), o.schema_name,
       o.obj_oid, o.owner_oid
from catalog_obj o
join pg_attribute att on att.attrelid = o.obj_oid
where o.kind in ('table', 'view', 'materialized view', 'foreign table')
  and att.attnum > 0
  and not att.attisdropped;

insert into catalog_acl
select 'column', format('%s.%I', o.object, att.attname),
       case a.grantee when 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
       a.privilege_type, a.is_grantable
from catalog_obj o
join pg_attribute att on att.attrelid = o.obj_oid
cross join lateral aclexplode(att.attacl) a
where o.kind in ('table', 'view', 'materialized view', 'foreign table')
  and att.attnum > 0
  and not att.attisdropped
  and att.attacl is not null
  and a.grantee <> o.owner_oid;

create temp table catalog_grants as
select o.kind, o.object,
       pg_temp.privilege_canon(
         coalesce((select string_agg(a.grantee || ':' || a.priv || case when a.grantable then '*' else '' end, ' ')
                   from catalog_acl a
                   where a.kind = o.kind and a.object = o.object), ''),
         o.kind) as grants
from catalog_obj o;

create temp table fixture_grants as
select kind, object, pg_temp.privilege_canon(grants, kind) as grants
from privilege_fixture;

select is_empty(
  $$select format('%s|%s|%s', c.kind, c.object, c.grants) as unlisted_fixture_line
    from catalog_grants c
    left join fixture_grants f on f.kind = c.kind and f.object = c.object
    where f.kind is null
    order by 1$$,
  'every table, column, function and view is listed in the privilege fixture');

select is_empty(
  $$select format('%s|%s|%s', f.kind, f.object, f.grants) as stale_fixture_line
    from fixture_grants f
    left join catalog_grants c on c.kind = f.kind and c.object = f.object
    where c.kind is null
    order by 1$$,
  'the privilege fixture has no entry for an object that does not exist');

select is_empty(
  $$select format('%s|%s expected [%s] actual [%s]', f.kind, f.object, f.grants, c.grants) as differing_grants
    from fixture_grants f
    join catalog_grants c on c.kind = f.kind and c.object = f.object
    where f.grants is distinct from c.grants
    order by 1$$,
  'the grants of every object match the privilege fixture');

select is_empty(
  $$select format('%s|%s|%s:%s', kind, object, grantee, priv) as grant_to_anon_or_public
    from catalog_acl
    where grantee in ('anon', 'PUBLIC')
    order by 1$$,
  'no object in public, app or internal grants anything to anon or PUBLIC');

select is_empty(
  $$select o.object as internal_function_open_to_authenticated
    from catalog_obj o
    where o.schema_name = 'internal'
      and o.kind in ('function', 'procedure')
      and has_function_privilege('authenticated', o.obj_oid, 'execute')
    order by 1$$,
  'no internal function is executable by authenticated');

select is_empty(
  $$select o.object as view_without_security_invoker
    from catalog_obj o
    join pg_class c on c.oid = o.obj_oid
    where o.schema_name = 'public'
      and o.kind = 'view'
      and not exists (
        select 1 from pg_options_to_table(c.reloptions) opt
        where opt.option_name = 'security_invoker'
          and opt.option_value::boolean)
    order by 1$$,
  'every view in public has security_invoker set');

select * from finish();
rollback;
