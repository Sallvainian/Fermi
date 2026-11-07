// The staff sign-in helper's guard (story 3, decision 1; test design TC-1):
// every test helper that holds the service-role key refuses a Supabase URL
// that is not on this machine.
import { afterEach, describe, expect, it } from 'vitest';
import { signInAsStaff } from '../support/helpers/staff-session.ts';
import { NonLocalSupabaseError, assertLocalSupabaseUrl } from '../support/helpers/local-stack.ts';

describe('assertLocalSupabaseUrl', () => {
  it.each(['http://127.0.0.1:56321', 'http://localhost:56321', 'http://localhost'])('accepts %s', (url) => {
    expect(assertLocalSupabaseUrl(url)).toBe(url);
  });

  it.each([
    'https://mzbblbgmrvcgvzxwhptm.supabase.co',
    'https://fermi-plus.sallvain.workers.dev',
    'http://127.0.0.1.example.com',
    'http://localhost.example.com',
    'http://10.0.0.5:56321',
    'not a url',
  ])('refuses %s', (url) => {
    expect(() => assertLocalSupabaseUrl(url)).toThrow(NonLocalSupabaseError);
  });

  it('refuses a missing URL', () => {
    expect(() => assertLocalSupabaseUrl(undefined)).toThrow(/SUPABASE_URL is not set/);
  });
});

describe('signInAsStaff', () => {
  const saved = { ...process.env };
  afterEach(() => {
    process.env = { ...saved };
  });

  it('refuses the hosted project before making any request', async () => {
    process.env.SUPABASE_URL = 'https://mzbblbgmrvcgvzxwhptm.supabase.co';
    process.env.SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_unused';
    process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-role-unused';

    await expect(signInAsStaff('teacher_a')).rejects.toThrow(NonLocalSupabaseError);
  });
});
