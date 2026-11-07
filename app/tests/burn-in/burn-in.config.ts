/**
 * Burn-in: on a pull request, every Playwright spec the change touches, or
 * that imports a file the change touches, runs 5 times with no retries. A
 * spec that fails once in 5 fails the pull request, so a flaky test is caught
 * where it is written, not weeks later on main.
 *
 * Read by Playwright Utils' runBurnIn (tests/burn-in/run.ts). Paths are
 * relative to app/, where it runs.
 */
import type { BurnInConfig } from '@seontechnologies/playwright-utils/burn-in';

const config: BurnInConfig = {
  // Playwright specs only; Vitest's *.test.ts files are not burned in.
  testPatterns: ['tests/e2e/**/*.spec.ts', 'tests/api/**/*.spec.ts'],

  // A change to only these never selects a spec. Docs and this folder; the
  // configs and types patterns are Playwright Utils' defaults, kept because
  // setting the list replaces them.
  skipBurnInPatterns: [
    '**/*.md',
    'tests/burn-in/**',
    '**/playwright.config.ts',
    '**/*config*',
    '**/*types*',
    '**/package.json',
    '**/tsconfig*.json',
  ],

  // Every affected spec, not a sample.
  burnInTestPercentage: 1,

  // 5 runs as My-Love does; retries 0, since a retry would hide the flake
  // the run exists to find.
  burnIn: { repeatEach: 5, retries: 0 },
};

export default config;
