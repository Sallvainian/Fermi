// The Supabase settings the client is built from (AD-17: this folder is the
// only code that talks to Supabase).

export interface SupabaseEnv {
  url: string;
  publishableKey: string;
}

export interface RawSupabaseEnv {
  VITE_SUPABASE_URL?: string;
  VITE_SUPABASE_PUBLISHABLE_KEY?: string;
}

// The local stack (supabase/config.toml `[api] port`) and the fixed demo key
// CLI 2.122.0 prints for it. Used when neither variable is set, because
// test.yml builds the production shell for Playwright against the local stack.
// The deploy build is the only one that must target the hosted project, so its
// guard lives in deploy.yml.
export const LOCAL_SUPABASE_ENV: SupabaseEnv = {
  url: 'http://127.0.0.1:56321',
  publishableKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
};

// An empty string counts as unset: an unset repo variable reaches a build as ''.
function present(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

export function parseSupabaseEnv(raw: RawSupabaseEnv): SupabaseEnv {
  const url = present(raw.VITE_SUPABASE_URL);
  const publishableKey = present(raw.VITE_SUPABASE_PUBLISHABLE_KEY);

  if (url === undefined && publishableKey === undefined) {
    return { ...LOCAL_SUPABASE_ENV };
  }
  if (url === undefined) {
    throw new Error('VITE_SUPABASE_URL is not set, but VITE_SUPABASE_PUBLISHABLE_KEY is.');
  }
  if (publishableKey === undefined) {
    throw new Error('VITE_SUPABASE_PUBLISHABLE_KEY is not set, but VITE_SUPABASE_URL is.');
  }

  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error('VITE_SUPABASE_URL is not a valid URL.');
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error('VITE_SUPABASE_URL must start with http:// or https://.');
  }

  return { url, publishableKey };
}

export function supabaseEnv(): SupabaseEnv {
  return parseSupabaseEnv(import.meta.env);
}
