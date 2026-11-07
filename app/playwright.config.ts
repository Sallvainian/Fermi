import { defineConfig, devices } from '@playwright/test';
import { loadLocalStackEnv } from './tests/support/helpers/local-stack.ts';

// SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and SUPABASE_SERVICE_ROLE_KEY: set by CI's
// setup-supabase action, or read here from `supabase status`. Local demo keys,
// never secrets (AD-23).
loadLocalStackEnv();

// The built shell, served the way Cloudflare serves it: a production build,
// not the dev server.
const BASE_URL = process.env.BASE_URL || 'http://localhost:4173';

export default defineConfig({
  globalSetup: './tests/support/global-setup.ts',
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  // ubuntu-latest has 4 vCPUs, shared with the local Supabase stack.
  workers: process.env.CI ? 2 : undefined,
  timeout: 60_000,

  use: {
    baseURL: BASE_URL,
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    trace: 'retain-on-failure-and-retries',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  // junit feeds scripts/check-test-counts.sh, which fails a run that quietly
  // ran fewer tests than Playwright lists.
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
  ],
  outputDir: 'test-results/artifacts',

  projects: [
    {
      name: 'chromium',
      testDir: './tests/e2e',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      // WebKit with an iPhone's screen and user agent. Not iOS Safari (test
      // design TC-8); that is checked by hand.
      name: 'webkit',
      testDir: './tests/e2e',
      use: { ...devices['iPhone 15'] },
    },
    {
      // HTTP against the local Supabase stack. apiRequest still opens a
      // Chromium page (Playwright Utils' UI display mode).
      name: 'api',
      testDir: './tests/api',
      use: { baseURL: process.env.SUPABASE_URL },
    },
  ],

  webServer: {
    command: 'npm run build && npx vite preview --port 4173 --strictPort',
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
