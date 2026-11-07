/**
 * `testUsers`: creates throwaway users for one test and deletes them after it,
 * pass or fail. Use it for a user the test owns; use a persona through
 * authOptions for a signed-in role.
 */
import { test as base } from '@playwright/test';
import { createTestUser, deleteTestUser, type TestUser } from '../test-users.ts';
import type { TestUserData } from './factories/user-factory.ts';

export interface TestUsers {
  create(overrides?: Partial<TestUserData>): Promise<TestUser>;
}

export const test = base.extend<{ testUsers: TestUsers }>({
  testUsers: async ({}, use) => {
    const created: string[] = [];
    await use({
      create: async (overrides) => {
        const user = await createTestUser(overrides);
        created.push(user.id);
        return user;
      },
    });
    // Teardown runs whatever the test's outcome. Every user is attempted
    // before any error is raised, so one failure leaves no others behind.
    const results = await Promise.allSettled(created.map((id) => deleteTestUser(id)));
    const failed = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
    if (failed.length > 0) {
      throw new Error(`Could not delete ${failed.length} test user(s): ${failed.map((f) => String(f.reason)).join('; ')}`);
    }
  },
});
