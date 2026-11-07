/**
 * The auth provider for @seontechnologies/playwright-utils' auth-session.
 *
 * `authOptions.userIdentifier` is a persona name from tests/support/test-users.ts
 * (`default` when a test sets none). The token is that persona's Supabase
 * access token, signed in on the local stack through signInAsStaff, and the
 * session is stored the way supabase-js keeps it, in localStorage under
 * sb-<host>-auth-token on the app's origin, so a browser test opens the app
 * already signed in once app/src/api/ reads that session.
 */
import fs from 'node:fs';
import type { APIRequestContext } from '@playwright/test';
import {
  getStorageStatePath,
  saveStorageState,
  type AuthOptions,
  type AuthProvider,
} from '@seontechnologies/playwright-utils/auth-session';
import { signInAsStaff } from '../helpers/staff-session.ts';
import { localStack } from '../helpers/local-stack.ts';

type StorageOrigin = { origin: string; localStorage: Array<{ name: string; value: string }> };

/** supabase-js's storage key: sb-<first label of the API host>-auth-token. */
export function supabaseStorageKey(supabaseUrl: string): string {
  return `sb-${new URL(supabaseUrl).hostname.split('.')[0]}-auth-token`;
}

export const supabaseAuthProvider: AuthProvider = {
  getEnvironment: (options?: Partial<AuthOptions>) => options?.environment || process.env.TEST_ENV || 'local',

  getUserIdentifier: (options?: Partial<AuthOptions>) => options?.userIdentifier || 'default',

  getBaseUrl: (options?: Partial<AuthOptions>) =>
    options?.baseUrl || process.env.BASE_URL || 'http://localhost:4173',

  extractToken: (tokenData: Record<string, unknown>) => {
    const origins = (tokenData.origins as StorageOrigin[] | undefined) ?? [];
    for (const origin of origins) {
      for (const item of origin.localStorage) {
        if (/^sb-.+-auth-token$/.test(item.name)) {
          try {
            return (JSON.parse(item.value) as { access_token?: string }).access_token ?? null;
          } catch {
            return null;
          }
        }
      }
    }
    return null;
  },

  // supabase-js keeps the session in localStorage, not a cookie.
  extractCookies: () => [],

  extractStorage: (tokenData: Record<string, unknown>) => (tokenData.origins as StorageOrigin[] | undefined) ?? [],

  isTokenExpired: (rawToken: string) => {
    try {
      const payload = JSON.parse(Buffer.from(rawToken.split('.')[1] ?? '', 'base64url').toString('utf-8')) as {
        exp?: number;
      };
      if (typeof payload.exp !== 'number') return true;
      // Treat a token within a minute of expiry as expired.
      return Math.floor(Date.now() / 1000) >= payload.exp - 60;
    } catch {
      return true;
    }
  },

  manageAuthToken: async (_request: APIRequestContext, options?: Partial<AuthOptions>) => {
    const environment = supabaseAuthProvider.getEnvironment(options);
    const userIdentifier = supabaseAuthProvider.getUserIdentifier(options);
    const { url } = localStack();
    const { session } = await signInAsStaff(userIdentifier);

    const storageState = {
      cookies: [],
      origins: [
        {
          origin: supabaseAuthProvider.getBaseUrl?.(options) ?? 'http://localhost:4173',
          localStorage: [{ name: supabaseStorageKey(url), value: JSON.stringify(session) }],
        },
      ],
    };
    saveStorageState(getStorageStatePath({ environment, userIdentifier }), storageState);
    return storageState;
  },

  clearToken: (options?: Partial<AuthOptions>) => {
    const path = getStorageStatePath({
      environment: supabaseAuthProvider.getEnvironment(options),
      userIdentifier: supabaseAuthProvider.getUserIdentifier(options),
    });
    if (fs.existsSync(path)) fs.unlinkSync(path);
  },
};
