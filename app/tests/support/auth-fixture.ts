/**
 * Adds Playwright Utils' auth fixtures (authOptions, authToken, and a signed-in
 * context and page) on top of the Fermi auth provider.
 *
 * A test picks its user with `test.use({ authOptions: { userIdentifier: 'teacher_a' } })`
 * inside a describe block; the persona names live in ./test-users.ts. A test
 * that must start signed out sets `test.use({ authSessionEnabled: false })`.
 */
import { test as base } from '@playwright/test';
import {
  createAuthFixtures,
  setAuthProvider,
  type AuthFixtures,
} from '@seontechnologies/playwright-utils/auth-session';
import { supabaseAuthProvider } from './auth/supabase-auth-provider.ts';

// Each worker loads this module, so the provider is set in every worker,
// not only in global setup's process.
setAuthProvider(supabaseAuthProvider);

export const test = base.extend<AuthFixtures>({
  ...createAuthFixtures(),
  // Restated in Playwright's [value, { option: true }] tuple form, which
  // createAuthFixtures' declared types widen to an array; the values are the
  // library's defaults (its README does the same).
  authOptions: [{ environment: process.env.TEST_ENV || 'local', userIdentifier: 'default' }, { option: true }],
  authSessionEnabled: [true, { option: true }],
});
