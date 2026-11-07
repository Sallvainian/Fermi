/**
 * Playwright global setup: prepares Playwright Utils' auth-session storage
 * (app/.auth/, gitignored) and registers the Fermi auth provider. Tokens are
 * fetched lazily, per persona, the first time a test asks for one; nothing
 * signs in here, so a run that needs no user does not need Supabase up.
 */
import { authStorageInit, configureAuthSession, setAuthProvider } from '@seontechnologies/playwright-utils/auth-session';
import { supabaseAuthProvider } from './auth/supabase-auth-provider.ts';

export default function globalSetup(): void {
  authStorageInit();
  configureAuthSession({ debug: false });
  setAuthProvider(supabaseAuthProvider);
}
