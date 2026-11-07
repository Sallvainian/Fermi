import { afterEach, describe, expect, it, vi } from 'vitest';
import { LOCAL_SUPABASE_ENV, parseSupabaseEnv, supabaseEnv } from './env.ts';

describe('parseSupabaseEnv', () => {
  it('falls back to the local stack when both variables are unset', () => {
    expect(parseSupabaseEnv({})).toEqual({
      url: 'http://127.0.0.1:56321',
      publishableKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
    });
  });

  it('treats empty strings as unset', () => {
    expect(
      parseSupabaseEnv({ VITE_SUPABASE_URL: '', VITE_SUPABASE_PUBLISHABLE_KEY: ' ' }),
    ).toEqual(LOCAL_SUPABASE_ENV);
  });

  it('returns a copy of the local default, not the shared object', () => {
    expect(parseSupabaseEnv({})).not.toBe(LOCAL_SUPABASE_ENV);
  });

  it('uses both variables when both are set', () => {
    expect(
      parseSupabaseEnv({
        VITE_SUPABASE_URL: 'https://abc.supabase.co',
        VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_x',
      }),
    ).toEqual({ url: 'https://abc.supabase.co', publishableKey: 'sb_publishable_x' });
  });

  it('throws naming the missing key when only the URL is set', () => {
    expect(() => parseSupabaseEnv({ VITE_SUPABASE_URL: 'https://abc.supabase.co' })).toThrow(
      /VITE_SUPABASE_PUBLISHABLE_KEY is not set/,
    );
  });

  it('throws naming the missing URL when only the key is set', () => {
    expect(() => parseSupabaseEnv({ VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_x' })).toThrow(
      /VITE_SUPABASE_URL is not set/,
    );
  });

  it('throws naming the URL when it is not a URL', () => {
    expect(() =>
      parseSupabaseEnv({ VITE_SUPABASE_URL: 'not a url', VITE_SUPABASE_PUBLISHABLE_KEY: 'k' }),
    ).toThrow(/VITE_SUPABASE_URL is not a valid URL/);
  });

  it('throws naming the URL when it is not http(s)', () => {
    expect(() =>
      parseSupabaseEnv({ VITE_SUPABASE_URL: 'ftp://abc.supabase.co', VITE_SUPABASE_PUBLISHABLE_KEY: 'k' }),
    ).toThrow(/VITE_SUPABASE_URL must start with http/);
  });
});

describe('supabaseEnv', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it('reads import.meta.env', () => {
    vi.stubEnv('VITE_SUPABASE_URL', 'https://abc.supabase.co');
    vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', 'sb_publishable_x');
    expect(supabaseEnv()).toEqual({ url: 'https://abc.supabase.co', publishableKey: 'sb_publishable_x' });
  });
});
