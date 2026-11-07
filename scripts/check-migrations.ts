/**
 * CI entry point for the expand-only check (scripts/migration-lint.ts).
 *
 * Lints every file in supabase/migrations in apply order, not only the ones a
 * pull request changed: an earlier contract migration carries its contract
 * line, so the whole history passes, and no git diff is needed to decide what
 * to check. Exits 1 on any finding.
 *
 * Usage, from the repo root: node scripts/check-migrations.ts [migrations-dir]
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { lintMigrations } from './migration-lint.ts';

const dir = process.argv[2] ?? 'supabase/migrations';
const files = readdirSync(dir)
  .filter((name) => name.endsWith('.sql'))
  .map((name) => ({ name, sql: readFileSync(join(dir, name), 'utf-8') }));

const { findings, contracts } = lintMigrations(files);

for (const { file, reason } of contracts) {
  console.log(`contract migration ${file}: ${reason}`);
}
for (const { file, line, message } of findings) {
  // GitHub annotation, shown on the pull request's file view.
  console.log(`::error file=${join(dir, file)},line=${line}::${file} ${message}`);
}

if (findings.length > 0) {
  console.log(
    `\n${findings.length} breaking change(s). A migration may only add (AD-20). If this is a planned contract ` +
      'step, make its first line `-- contract: <why it is safe now>`.',
  );
  process.exit(1);
}
console.log(`${files.length} migration(s) checked: expand-only.`);
