import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createSupabase } from './client.ts';

// A developer's shell may export VITE_SUPABASE_*; start each test from unset.
beforeEach(() => {
  vi.stubEnv('VITE_SUPABASE_URL', '');
  vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', '');
});

afterEach(() => {
  vi.unstubAllEnvs();
  vi.resetModules();
});

describe('createSupabase', () => {
  it('builds a client from the given settings', () => {
    const client = createSupabase({ url: 'https://abc.supabase.co', publishableKey: 'sb_publishable_x' });
    expect(typeof client.from).toBe('function');
    expect(typeof client.functions.invoke).toBe('function');
  });
});

describe('supabase()', () => {
  it('returns one client, created on the first call', async () => {
    const { supabase } = await import('./client.ts');
    const first = supabase();
    expect(supabase()).toBe(first);
  });

  it('reads the environment only when first called', async () => {
    vi.stubEnv('VITE_SUPABASE_URL', 'https://abc.supabase.co');
    const { supabase } = await import('./client.ts');
    expect(() => supabase()).toThrow(/VITE_SUPABASE_PUBLISHABLE_KEY/);
  });
});
