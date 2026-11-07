/**
 * Builds the data for a test user. Pure: creates nothing.
 *
 * Every email is unique (a faker word plus a random id), so parallel workers
 * and repeated runs never collide on the local stack's auth.users. The domain
 * is test.example.com, which RFC 2606 reserves, so no mail can leave.
 */
import { faker } from '@faker-js/faker';

export interface TestUserData {
  email: string;
  password: string;
}

export function buildTestUser(overrides: Partial<TestUserData> = {}): TestUserData {
  const local = `${faker.internet.username()}-${faker.string.alphanumeric(8)}`
    .toLowerCase()
    .replace(/[^a-z0-9.-]/g, '');
  return {
    email: `${local}@test.example.com`,
    password: faker.internet.password({ length: 24 }),
    ...overrides,
  };
}
