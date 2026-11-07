/**
 * The local Supabase stack every test talks to, and the guard that keeps
 * tests off any other Supabase.
 *
 * Test helpers here hold the stack's service-role key (SERVICE_ROLE_KEY; the
 * admin API needs it as a Bearer JWT, which supabase-js does not send for the
 * sb_secret_ key) and create users through the admin API. Pointed at
 * the hosted project, that would create real accounts, so every helper calls
 * assertLocalSupabaseUrl first and refuses any URL whose host is not
 * 127.0.0.1 or localhost (story 3, decision 1; test design TC-1).
 *
 * The keys come from `supabase status`, never from a secret: they are the
 * local stack's demo keys, the same on every machine and CI runner (AD-23).
 */
import { execFileSync } from 'node:child_process';

const LOCAL_HOSTNAMES = new Set(['127.0.0.1', 'localhost']);

export class NonLocalSupabaseError extends Error {
  constructor(url: string) {
    super(
      `Refusing to run test helpers against ${url}: they hold the service-role key and create users, ` +
        'so they run only against the local Supabase stack (127.0.0.1 or localhost).',
    );
    this.name = 'NonLocalSupabaseError';
  }
}

/** Returns the URL when its host is 127.0.0.1 or localhost; throws otherwise. */
export function assertLocalSupabaseUrl(url: string | undefined): string {
  if (!url) {
    throw new Error('SUPABASE_URL is not set and `supabase status` did not report one. Run `supabase start`.');
  }
  let hostname: string;
  try {
    hostname = new URL(url).hostname;
  } catch {
    throw new NonLocalSupabaseError(url);
  }
  if (!LOCAL_HOSTNAMES.has(hostname)) {
    throw new NonLocalSupabaseError(url);
  }
  return url;
}

export interface LocalStack {
  url: string;
  publishableKey: string;
  serviceRoleKey: string;
}

type StatusJson = { API_URL?: string; PUBLISHABLE_KEY?: string; SERVICE_ROLE_KEY?: string };

function readStatus(): StatusJson {
  try {
    // The CLI finds supabase/config.toml from app/ by walking up. stderr is
    // dropped because the CLI prints its upgrade notice there.
    const out = execFileSync('supabase', ['status', '-o', 'json'], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return JSON.parse(out) as StatusJson;
  } catch {
    return {};
  }
}

/**
 * Fills SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and SUPABASE_SERVICE_ROLE_KEY from
 * `supabase status` when they are not already set (CI exports them from
 * .github/actions/setup-supabase). It never throws, so a browser-only run
 * works with the stack down; localStack() does the checking when a test
 * actually needs Supabase.
 */
export function loadLocalStackEnv(): void {
  if (process.env.SUPABASE_URL && process.env.SUPABASE_PUBLISHABLE_KEY && process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return;
  }
  const status = readStatus();
  // Assigned only when found: `??= undefined` would store the string "undefined".
  if (status.API_URL) process.env.SUPABASE_URL ??= status.API_URL;
  if (status.PUBLISHABLE_KEY) process.env.SUPABASE_PUBLISHABLE_KEY ??= status.PUBLISHABLE_KEY;
  if (status.SERVICE_ROLE_KEY) process.env.SUPABASE_SERVICE_ROLE_KEY ??= status.SERVICE_ROLE_KEY;
}

/** The loaded stack. Throws when it is missing or not local. */
export function localStack(): LocalStack {
  const url = assertLocalSupabaseUrl(process.env.SUPABASE_URL);
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!publishableKey || !serviceRoleKey) {
    throw new Error(
      'SUPABASE_PUBLISHABLE_KEY or SUPABASE_SERVICE_ROLE_KEY is missing. Run `supabase start` in the repo root.',
    );
  }
  return { url, publishableKey, serviceRoleKey };
}
