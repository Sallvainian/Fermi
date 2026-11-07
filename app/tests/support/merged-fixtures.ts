/**
 * The one entry point every Playwright spec imports from, browser and API
 * specs alike: apiRequest, recurse, interceptNetworkCall, the network error
 * monitor (fails a test on any 4xx or 5xx response the page receives), the
 * auth fixtures and testUsers.
 *
 * apiRequest opens a page for its UI display mode, so even an API spec starts
 * a browser; the api project's CI job installs Chromium for that.
 *
 * Specs never import `test` from @playwright/test (Playwright Utils mandate).
 */
import { mergeTests } from '@playwright/test';
import { log } from '@seontechnologies/playwright-utils';
import { test as apiRequestFixture } from '@seontechnologies/playwright-utils/api-request/fixtures';
import { test as recurseFixture } from '@seontechnologies/playwright-utils/recurse/fixtures';
import { test as interceptFixture } from '@seontechnologies/playwright-utils/intercept-network-call/fixtures';
import { test as networkErrorFixture } from '@seontechnologies/playwright-utils/network-error-monitor/fixtures';
import { test as authFixture } from './auth-fixture.ts';
import { test as testUsersFixture } from './fixtures/test-users-fixture.ts';

export const test = mergeTests(
  apiRequestFixture,
  recurseFixture,
  interceptFixture,
  networkErrorFixture,
  authFixture,
  testUsersFixture,
);

export { expect } from '@playwright/test';
export { log };
