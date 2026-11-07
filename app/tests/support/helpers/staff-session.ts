/**
 * Signs in a teacher or the admin on the local stack (story 3, decision 1;
 * test design TC-1).
 *
 * Staff sign in only with Google or Apple, which no automated test can drive.
 * This helper is the test-only way round it, and it exists only here, in test
 * code: nothing in app/, supabase/functions/ or the hosted config adds a test
 * sign-in, and the hosted project keeps Google and Apple as the only staff
 * sign-in. It creates the persona through the local stack's admin API with
 * that stack's own service-role key and signs in with a password, and it
 * refuses to run when the Supabase URL is not 127.0.0.1 or localhost.
 *
 * Staff signed in this way skip the teacher-list check (before_user_created),
 * so admission is tested only by the database tests of the sign-in gate
 * (P0-003) and by hand in the Simulator.
 */
import type { Session } from '@supabase/supabase-js';
import { ensurePersona, signInWithPassword, type TestUser } from '../test-users.ts';
import { localStack } from './local-stack.ts';

export interface StaffSession {
  user: TestUser;
  session: Session;
}

export async function signInAsStaff(persona: string): Promise<StaffSession> {
  // Checked before anything else, so a hosted URL fails before any request.
  localStack();
  const user = await ensurePersona(persona);
  const session = await signInWithPassword(user);
  return { user, session };
}
