/**
 * The shell shows the commit it was built from (story 1's verify, in a browser).
 *
 * The reference UI spec: test from the merged fixtures, the network call
 * declared before page.goto and awaited after it, data-testid selectors, and
 * the page already signed in as the `default` persona by the auth fixture
 * (the shell reads no session yet; later screens do).
 */
import { test, expect, log } from '../support/merged-fixtures.ts';

// vite.config.ts bakes in GITHUB_SHA, or `local` off CI.
const expectedBuildId = process.env.GITHUB_SHA || 'local';

test.describe('shell', () => {
  test('[P1] shows the commit id the build came from', async ({ page, interceptNetworkCall }) => {
    await log.step('Given the built shell is served');
    // The shell makes no API call yet, so the call it depends on is its own
    // script: the bundle that renders the id.
    const bundle = interceptNetworkCall({ url: '**/assets/index-*.js' });

    await log.step('When the shell opens');
    await page.goto('/');
    const { status } = await bundle;
    expect(status).toBe(200);

    await log.step('Then it shows the build id, and its fermi-build meta carries the same id');
    await expect(page.getByTestId('build-commit-id')).toHaveText('probe-wrong-id');
    await expect(page.locator('meta[name="fermi-build"]')).toHaveAttribute('content', expectedBuildId);
  });
});
