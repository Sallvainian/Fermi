// The expand-only migration check (AD-20; story 3, decision 3; TC-4).
import { describe, expect, it } from 'vitest';
import { lintMigrations, stripSql } from '../../../scripts/migration-lint.ts';

const lint = (...sqls: string[]) =>
  lintMigrations(sqls.map((sql, i) => ({ name: `2026110700000${i}_m.sql`, sql })));
const messages = (...sqls: string[]) => lint(...sqls).findings.map((f) => f.message);

describe('migrations that only add', () => {
  it.each([
    'create table app.classes (id uuid primary key);',
    'alter table app.classes add column name text;',
    'alter table app.classes drop constraint classes_name_key;',
    'alter table app.classes alter column name drop default;',
    'alter table app.classes alter column name drop not null;',
    'alter table app.classes rename constraint a to b;',
    'drop policy "read own" on app.classes;',
    'drop trigger t on app.classes;',
    'drop index app.classes_name_idx;',
    'revoke all on schema app from anon;',
    'create extension if not exists pgtap with schema extensions;',
  ])('pass: %s', (sql) => {
    expect(messages(sql)).toEqual([]);
  });

  it('ignores a DROP inside a comment, a string or a function body', () => {
    const sql = [
      '-- drop table app.old;',
      '/* alter table app.x drop column y; */',
      "comment on schema app is 'drop table app.y';",
      'create function app.f() returns void language plpgsql as $$ begin drop table tmp; end $$;',
    ].join('\n');
    expect(messages(sql)).toEqual([]);
  });
});

describe('migrations that break a client', () => {
  it.each([
    ['drop table app.classes;', 'drops a table'],
    ['drop table if exists app.classes;', 'drops a table'],
    ['drop view public.v;', 'drops a view'],
    ['drop function public.get_classes(uuid);', 'drops a function'],
    ['drop schema app cascade;', 'drops a schema'],
    ['alter table app.classes drop column name;', 'drops a column'],
    ['alter table app.classes drop name;', 'drops a column'],
    ['alter table if exists app.classes drop column if exists name;', 'drops a column'],
    ['alter table app.classes rename column name to title;', 'renames a table or one of its columns'],
    ['alter table app.classes rename to courses;', 'renames a table or one of its columns'],
    ['alter function public.f(uuid) rename to g;', 'renames a function or one of its columns'],
    ['alter table app.classes set schema internal;', 'moves a table to another schema'],
  ])('fail: %s', (sql, message) => {
    expect(messages(sql)).toEqual([message]);
  });

  it('reports the line the statement starts on', () => {
    const { findings } = lint('create table app.a (id int);\n\n  drop table app.a;');
    expect(findings).toEqual([{ file: '20261107000000_m.sql', line: 3, message: 'drops a table' }]);
  });

  it("fails a function redefined with different arguments in a later migration", () => {
    expect(
      messages(
        'create function public.get_roster(p_class uuid) returns setof uuid language sql as $$ select 1 $$;',
        'create or replace function public.get_roster(p_class uuid, p_archived boolean) returns setof uuid language sql as $$ select 1 $$;',
      ),
    ).toEqual(['changes the arguments of public.get_roster from (uuid) in 20261107000000_m.sql to (uuid, boolean)']);
  });

  it('passes a function replaced with the same argument types', () => {
    expect(
      messages(
        'create function get_roster(p_class uuid) returns int language sql as $$ select 1 $$;',
        'create or replace function public.get_roster(p_class uuid) returns int language sql as $$ select 2 $$;',
      ),
    ).toEqual([]);
  });
});

describe('contract migrations', () => {
  it('exempts a migration whose first line states a contract reason', () => {
    const result = lint('\n-- contract: the app stopped reading name in the deploy of 2026-12-01\nalter table app.classes drop column name;');
    expect(result.findings).toEqual([]);
    expect(result.contracts).toEqual([
      { file: '20261107000000_m.sql', reason: 'the app stopped reading name in the deploy of 2026-12-01' },
    ]);
  });

  it('does not exempt a contract line with no reason', () => {
    expect(messages('-- contract:\nalter table app.classes drop column name;')).toEqual([
      'has a contract line with no reason; write why the change is safe now',
      'drops a column',
    ]);
  });

  it('does not exempt a contract line that is not the first line', () => {
    expect(messages('alter table app.classes drop column name;\n-- contract: too late')).toEqual(['drops a column']);
  });
});

describe('stripSql', () => {
  it('keeps line numbers', () => {
    const sql = "select 1; -- a\n/* b\nc */ select 'x\ny';";
    expect(stripSql(sql).split('\n')).toHaveLength(sql.split('\n').length);
  });
});
