/**
 * The one shared module for test users (story 3, decision 2; test design TC-3).
 *
 * Every test that needs a user gets it from here, so the persona cast is
 * defined once and later epics extend it instead of inventing their own:
 * epic-invite-sign-in adds the admin and the teachers, epic-classes-rosters
 * the students and the classes (enrolled, removed and archived cases). The
 * pgTAP side of the same cast is supabase/tests/database/00_test_helpers.sql
 * (tests.create_persona, tests.authenticate_as); keep the names in step.
 *
 * Everything here runs only against the local stack (localStack() refuses
 * any other URL) and uses that stack's secret key, which acts as service_role.
 * Users created through the admin API skip the before_user_created hook, so
 * these users never test admission; the hook's own pgTAP tests do (P0-003).
 */
import { createClient, type Session, type SupabaseClient } from '@supabase/supabase-js';
import { buildTestUser, type TestUserData } from './fixtures/factories/user-factory.ts';
import { localStack } from './helpers/local-stack.ts';

export interface TestUser extends TestUserData {
  id: string;
}

/**
 * What a named persona needs beyond its auth user: a profile role, a
 * staff_invites row, enrollments. Empty until the epics that own those
 * tables add their personas, e.g. `admin`, `teacher_a`, `teacher_b`,
 * `student_only_in_a`, `student_in_a_and_b`, `removed_student` (TC-3).
 * A persona name not listed here is a plain signed-in user with no role.
 */
export type PersonaSetup = (admin: SupabaseClient, user: TestUser) => Promise<void>;

export const personaSetups: Record<string, PersonaSetup> = {};

const clientOptions = { auth: { persistSession: false, autoRefreshToken: false } } as const;

/** A service-role client for the local stack. Never import it into app code. */
export function adminClient(): SupabaseClient {
  const { url, serviceRoleKey } = localStack();
  return createClient(url, serviceRoleKey, clientOptions);
}

/** Creates a confirmed auth user with a unique email. Delete it with deleteTestUser. */
export async function createTestUser(overrides: Partial<TestUserData> = {}): Promise<TestUser> {
  const data = buildTestUser(overrides);
  const { data: created, error } = await adminClient().auth.admin.createUser({
    email: data.email,
    password: data.password,
    email_confirm: true,
  });
  if (error || !created.user) {
    throw new Error(`Could not create test user ${data.email}: ${error?.message ?? 'no user returned'}`);
  }
  return { ...data, id: created.user.id };
}

export async function deleteTestUser(id: string): Promise<void> {
  const { error } = await adminClient().auth.admin.deleteUser(id);
  if (error && error.status !== 404) {
    throw new Error(`Could not delete test user ${id}: ${error.message}`);
  }
}

export function personaEmail(persona: string): string {
  if (!/^[a-z][a-z0-9_]*$/.test(persona)) {
    throw new Error(`Persona names are snake_case, like teacher_a; got "${persona}".`);
  }
  return `persona-${persona.replace(/_/g, '-')}@test.example.com`;
}

async function findUserIdByEmail(admin: SupabaseClient, email: string): Promise<string | null> {
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw new Error(`Could not list users looking for ${email}: ${error.message}`);
    const match = data.users.find((user) => user.email?.toLowerCase() === email);
    if (match) return match.id;
    if (data.users.length < 1000) return null;
  }
  return null;
}

/**
 * A persona's password: fixed per persona, so parallel workers that set it at
 * the same moment all set the same value and none signs another out. Not a
 * secret: persona users exist only on the local stack.
 */
function personaPassword(persona: string): string {
  return `local-stack-only-${persona}-0`;
}

/**
 * The named persona's user, created on first use and reused after that, its
 * password reset to the persona's fixed one so a session can always be signed
 * in. Persona users stay on the local stack between runs; `supabase db reset`
 * clears them.
 */
export async function ensurePersona(persona: string): Promise<TestUser> {
  const admin = adminClient();
  const data = { email: personaEmail(persona), password: personaPassword(persona) };

  const { data: created, error } = await admin.auth.admin.createUser({
    email: data.email,
    password: data.password,
    email_confirm: true,
  });
  let user: TestUser;
  if (!error && created.user) {
    user = { ...data, id: created.user.id };
  } else {
    // The persona exists: from an earlier run (email_exists), or created by a
    // parallel worker in the same instant, which GoTrue reports only as
    // "Database error creating new user". Either way, look it up.
    const id = await findUserIdByEmail(admin, data.email);
    if (!id) throw new Error(`Could not create persona ${persona}: ${error?.message ?? 'no user returned'}`);
    const { error: updateError } = await admin.auth.admin.updateUserById(id, { password: data.password });
    if (updateError) throw new Error(`Could not reset persona ${persona}'s password: ${updateError.message}`);
    user = { ...data, id };
  }

  await personaSetups[persona]?.(admin, user);
  return user;
}

/** Signs the user in with email and password on the local stack. */
export async function signInWithPassword(user: TestUserData): Promise<Session> {
  const { url, publishableKey } = localStack();
  const client = createClient(url, publishableKey, clientOptions);
  const { data, error } = await client.auth.signInWithPassword({ email: user.email, password: user.password });
  if (error || !data.session) {
    throw new Error(`Sign-in failed for ${user.email}: ${error?.message ?? 'no session returned'}`);
  }
  return data.session;
}
