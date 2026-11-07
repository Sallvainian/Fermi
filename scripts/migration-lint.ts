/**
 * The expand-only check for supabase/migrations (AD-20; story 3, decision 3;
 * test design TC-4).
 *
 * Migrations deploy before the bundle, so a migration may only add. It fails:
 *   - dropping a table, view, materialized view, function, procedure or schema
 *   - dropping a column (ALTER TABLE ... DROP [COLUMN] x)
 *   - renaming a table, column, function or schema, or moving one to another
 *     schema (ALTER ... RENAME, ALTER ... SET SCHEMA)
 *   - changing an RPC's arguments: CREATE FUNCTION under a name an earlier
 *     migration already defined, with a different argument list (an overload
 *     is a new function under an old name, which AD-20 rules out)
 *
 * A planned contract migration, which AD-20 allows once the bundle that stopped
 * using the old shape has been live for one deploy, passes when its first
 * non-empty line is `-- contract: <why it is safe now>` (owner decision,
 * 2026-11-06). The reason is printed in CI and visible in review.
 *
 * Comments, quoted strings and dollar-quoted bodies are ignored, so a DROP in
 * a comment or a function body's text does not count. Dynamic SQL inside a
 * function or DO block is therefore not checked.
 *
 * Runs on Node 24 without a build step (type stripping), and is imported by
 * the Vitest suite in app/tests/unit/migration-lint.test.ts.
 */

export interface MigrationFile {
  name: string;
  sql: string;
}

export interface Finding {
  file: string;
  line: number;
  message: string;
}

export interface LintResult {
  findings: Finding[];
  /** Files exempted by a contract line, with their stated reason. */
  contracts: Array<{ file: string; reason: string }>;
}

const CONTRACT_LINE = /^--\s*contract:(.*)$/i;

/**
 * Replaces comments, string literals and dollar-quoted bodies with spaces,
 * keeping newlines so line numbers still match the file.
 */
export function stripSql(sql: string): string {
  let out = '';
  let i = 0;
  const blank = (s: string) => s.replace(/[^\n]/g, ' ');
  while (i < sql.length) {
    const rest = sql.slice(i);
    if (rest.startsWith('--')) {
      const end = sql.indexOf('\n', i);
      const stop = end === -1 ? sql.length : end;
      out += blank(sql.slice(i, stop));
      i = stop;
    } else if (rest.startsWith('/*')) {
      const end = sql.indexOf('*/', i + 2);
      const stop = end === -1 ? sql.length : end + 2;
      out += blank(sql.slice(i, stop));
      i = stop;
    } else if (sql[i] === "'") {
      let j = i + 1;
      while (j < sql.length) {
        if (sql[j] === "'" && sql[j + 1] === "'") j += 2;
        else if (sql[j] === "'") break;
        else j++;
      }
      out += blank(sql.slice(i, j + 1));
      i = j + 1;
    } else {
      const tag = /^\$[A-Za-z_]*\$/.exec(rest);
      if (tag) {
        const end = sql.indexOf(tag[0], i + tag[0].length);
        const stop = end === -1 ? sql.length : end + tag[0].length;
        out += blank(sql.slice(i, stop));
        i = stop;
      } else {
        out += sql[i];
        i++;
      }
    }
  }
  return out;
}

/** Splits stripped SQL into statements, each with the line it starts on. */
function statements(stripped: string): Array<{ text: string; line: number }> {
  const result: Array<{ text: string; line: number }> = [];
  let start = 0;
  for (let i = 0; i <= stripped.length; i++) {
    if (i === stripped.length || stripped[i] === ';') {
      const raw = stripped.slice(start, i);
      const lead = raw.length - raw.trimStart().length;
      const text = raw.trim().replace(/\s+/g, ' ');
      if (text) {
        const line = stripped.slice(0, start + lead).split('\n').length;
        result.push({ text, line });
      }
      start = i + 1;
    }
  }
  return result;
}

const IDENT = String.raw`(?:"[^"]+"|[A-Za-z_][\w$]*)`;
const QUALIFIED = String.raw`${IDENT}(?:\.${IDENT})?`;

/** Lower-cases unquoted identifiers and drops the quotes from quoted ones. */
function normalizeName(name: string): string {
  return name
    .split('.')
    .map((part) => (part.startsWith('"') ? part.slice(1, -1) : part.toLowerCase()))
    .join('.');
}

/** public.f and f name the same function; a bare name resolves to public. */
function qualifyFunction(name: string): string {
  const normalized = normalizeName(name);
  return normalized.includes('.') ? normalized : `public.${normalized}`;
}

/** The argument list with names and defaults removed, types only. */
function argumentTypes(args: string): string {
  if (!args.trim()) return '';
  const parts: string[] = [];
  let depth = 0;
  let current = '';
  for (const ch of args) {
    if (ch === '(') depth++;
    if (ch === ')') depth--;
    if (ch === ',' && depth === 0) {
      parts.push(current);
      current = '';
    } else current += ch;
  }
  parts.push(current);
  return parts
    .map((part) => {
      const withoutDefault = part.replace(/\s+(default\b|=).*$/is, '').trim();
      const tokens = withoutDefault.split(/\s+/);
      if (/^(in|out|inout|variadic)$/i.test(tokens[0] ?? '')) tokens.shift();
      // `name type` or just `type`; a known type word first means no name.
      const typeStart = tokens.length > 1 && !TYPE_WORDS.test(tokens[0]) ? 1 : 0;
      return tokens.slice(typeStart).join(' ').toLowerCase();
    })
    .join(', ');
}

const TYPE_WORDS =
  /^(uuid|text|int|integer|bigint|smallint|boolean|bool|numeric|real|jsonb?|date|time|timestamp|timestamptz|interval|bytea|character|varchar|double|"?[a-z_]+"?\.[a-z_]+)$/i;

const BREAKING: Array<{ pattern: RegExp; what: string }> = [
  { pattern: /^drop (table|view|materialized view|function|procedure|schema)\b/i, what: 'drops a $1' },
  {
    pattern: new RegExp(
      String.raw`^alter table (?:if exists )?(?:only )?${QUALIFIED} .*\bdrop (?!constraint\b|default\b|not null\b|identity\b|expression\b)(?:column )?(?:if exists )?${IDENT}`,
      'i',
    ),
    what: 'drops a column',
  },
  // A constraint's name is invisible to clients, so renaming one is allowed.
  {
    pattern: /^alter (table|view|materialized view|function|procedure|schema)\b.*\brename\b(?! constraint\b)/i,
    what: 'renames a $1 or one of its columns',
  },
  { pattern: /^alter (table|view|materialized view|function|procedure)\b.*\bset schema\b/i, what: 'moves a $1 to another schema' },
];

const CREATE_FUNCTION = new RegExp(String.raw`^create (?:or replace )?function (${QUALIFIED}) ?\(`, 'i');

function functionArgs(text: string, openParen: number): string {
  let depth = 0;
  for (let i = openParen; i < text.length; i++) {
    if (text[i] === '(') depth++;
    if (text[i] === ')') {
      depth--;
      if (depth === 0) return text.slice(openParen + 1, i);
    }
  }
  return text.slice(openParen + 1);
}

/** Lints the migrations in the order they apply (file name order). */
export function lintMigrations(files: MigrationFile[]): LintResult {
  const findings: Finding[] = [];
  const contracts: LintResult['contracts'] = [];
  const signatures = new Map<string, { args: string; file: string }>();

  for (const file of [...files].sort((a, b) => a.name.localeCompare(b.name))) {
    const firstLine = file.sql.split('\n').find((l) => l.trim() !== '')?.trim() ?? '';
    const contract = CONTRACT_LINE.exec(firstLine);
    let exempt = false;
    if (contract) {
      const reason = contract[1].trim();
      if (reason) {
        exempt = true;
        contracts.push({ file: file.name, reason });
      } else {
        findings.push({ file: file.name, line: 1, message: 'has a contract line with no reason; write why the change is safe now' });
      }
    }

    for (const { text, line } of statements(stripSql(file.sql))) {
      if (!exempt) {
        for (const rule of BREAKING) {
          const match = rule.pattern.exec(text);
          if (match) {
            findings.push({ file: file.name, line, message: rule.what.replace('$1', (match[1] ?? '').toLowerCase()) });
          }
        }
      }

      const created = CREATE_FUNCTION.exec(text);
      if (created) {
        const name = qualifyFunction(created[1]);
        const args = argumentTypes(functionArgs(text, created[0].length - 1));
        const earlier = signatures.get(name);
        if (!exempt && earlier && earlier.args !== args) {
          findings.push({
            file: file.name,
            line,
            message: `changes the arguments of ${name} from (${earlier.args}) in ${earlier.file} to (${args})`,
          });
        }
        signatures.set(name, { args, file: file.name });
      }

      const dropped = new RegExp(String.raw`^drop function (?:if exists )?(${QUALIFIED})`, 'i').exec(text);
      if (dropped) signatures.delete(qualifyFunction(dropped[1]));
    }
  }
  return { findings, contracts };
}
