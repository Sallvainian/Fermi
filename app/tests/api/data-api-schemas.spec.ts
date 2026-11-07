/**
 * The Data API serves neither the app nor the internal schema, to anyone
 * (migration 20261106190000; R7, AD-3). These schemas hold the rules, so a
 * client must never reach them over REST, signed in or not. Adding either
 * schema to [api] schemas in supabase/config.toml fails these tests, and so
 * the Playwright (api) job in test.yml (DW-3).
 *
 * The reference API spec: test from the merged fixtures, apiRequest for
 * every HTTP call, the signed-in token from the auth fixture rather than an
 * inline sign-in, and log.step for milestones. Runs against the local stack
 * only (the api project's baseURL is the local SUPABASE_URL).
 *
 * No response schema exists for PostgREST errors yet, so the assertions
 * cover the fields under test only: the status and PostgREST's error code.
 */
import { test, expect, log } from '../support/merged-fixtures.ts';
import { signInWithPassword } from '../support/test-users.ts';

const publishableKey = (): string => process.env.SUPABASE_PUBLISHABLE_KEY ?? '';

type PostgrestError = { code?: string };

// PostgREST's answer for a schema missing from [api] schemas in
// supabase/config.toml: 406 Not Acceptable, error code PGRST106.
const SCHEMA_NOT_EXPOSED = { status: 406, code: 'PGRST106' } as const;

for (const schema of ['app', 'internal']) {
  test.describe(`schema ${schema}`, () => {
    test(`[P0] @Security a signed-out request to ${schema} is refused`, async ({ apiRequest }) => {
      await log.step(`Request a table in ${schema} with only the publishable key`);
      const { status, body } = await apiRequest<PostgrestError>({
        method: 'GET',
        path: '/rest/v1/anything',
        headers: { apikey: publishableKey(), 'Accept-Profile': schema },
      });

      expect(status).toBe(SCHEMA_NOT_EXPOSED.status);
      expect(body.code).toBe(SCHEMA_NOT_EXPOSED.code);
    });

    test(`[P0] @Security a signed-in request to ${schema} is refused`, async ({ apiRequest, authToken }) => {
      await log.step(`Request a table in ${schema} as the default persona`);
      const { status, body } = await apiRequest<PostgrestError>({
        method: 'GET',
        path: '/rest/v1/anything',
        headers: {
          apikey: publishableKey(),
          Authorization: `Bearer ${authToken}`,
          'Accept-Profile': schema,
        },
      });

      expect(status).toBe(SCHEMA_NOT_EXPOSED.status);
      expect(body.code).toBe(SCHEMA_NOT_EXPOSED.code);
    });
  });
}

test.describe('a user the test owns', () => {
  test('[P1] @Security a new signed-in user cannot reach app either', async ({ apiRequest, testUsers }) => {
    await log.step('Given a new user, deleted after the test');
    const user = await testUsers.create();
    // Signed in inline rather than through authToken: the auth fixture signs
    // in named personas, and this user exists only for this test.
    const session = await signInWithPassword(user);

    await log.step('When it requests a table in app');
    const { status, body } = await apiRequest<PostgrestError>({
      method: 'GET',
      path: '/rest/v1/anything',
      headers: {
        apikey: publishableKey(),
        Authorization: `Bearer ${session.access_token}`,
        'Accept-Profile': 'app',
      },
    });

    await log.step('Then the Data API refuses the schema');
    expect(status).toBe(SCHEMA_NOT_EXPOSED.status);
    expect(body.code).toBe(SCHEMA_NOT_EXPOSED.code);
  });
});
