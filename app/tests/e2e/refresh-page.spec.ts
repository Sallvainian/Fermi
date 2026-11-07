/**
 * A Fermi on an old build is replaced by the refresh page (R1, AD-24, story 16).
 *
 * The built site is served by vite preview, which has no /updates/latest.json
 * of its own, so the spec fulfills it with a different app id: the open page is
 * "an old build". The refresh page needs no session, so the spec starts signed
 * out. Runs on Desktop Chrome and iPhone WebKit.
 */
import { test, expect, log } from '../support/merged-fixtures.ts';

const SENTENCE = 'A new version of Fermi+ is ready. Refresh to keep using Fermi+.';
const DRAFT_KEY = 'fermi:draft:e2e:fixture:x:body';
const DRAFT_VALUE = 'a half-written note';

test.describe('refresh page', () => {
  test.use({ authSessionEnabled: false });

  test('[P0] an old build shows only the refresh page, and Refresh brings the shell back with the draft intact', async ({
    page,
    interceptNetworkCall,
  }) => {
    await log.step('Given latest.json names another app than this build');
    // The fulfillment stays in place for every later request, reloads included.
    const latest = interceptNetworkCall({
      url: '**/updates/latest.json',
      fulfillResponse: { status: 200, body: { version: 'another-commit', app: 'another-app-id' } },
    });

    await log.step('When a deep path opens');
    await page.goto('/refresh-check/deep');
    await latest;

    await log.step('Then only the refresh page shows: its sentence and one Refresh button');
    await expect(page.getByTestId('refresh-page')).toBeVisible();
    await expect(page.getByTestId('refresh-page')).toHaveText(`${SENTENCE}Refresh`);
    await expect(page.getByRole('button')).toHaveCount(1);
    await expect(page.getByRole('button', { name: 'Refresh' })).toBeVisible();
    await expect(page.getByTestId('build-commit-id')).toHaveCount(0);

    await log.step('And a draft value is in sessionStorage');
    await page.evaluate(([key, value]) => sessionStorage.setItem(key, value), [DRAFT_KEY, DRAFT_VALUE]);

    await log.step('When Refresh is clicked');
    const reloaded = interceptNetworkCall({ url: '**/refresh-check/deep' });
    await page.getByRole('button', { name: 'Refresh' }).click();
    const { status, response } = await reloaded;

    await log.step('Then the deep path answers 200 HTML again (index.html)');
    expect(status).toBe(200);
    expect(response?.headers()['content-type']).toContain('text/html');

    await log.step('And the shell shows, because the same build came back and the check waits 30 s');
    await expect(page.getByTestId('build-commit-id')).toBeVisible();
    await expect(page.getByTestId('refresh-page')).toHaveCount(0);

    await log.step('And the draft value survived the reload, the marker having been consumed');
    expect(await page.evaluate((key) => sessionStorage.getItem(key), DRAFT_KEY)).toBe(DRAFT_VALUE);
    expect(await page.evaluate(() => sessionStorage.getItem('fermi:update:refreshed-from'))).toBeNull();
  });

  test('[P1] a latest.json naming this app leaves the shell alone', async ({ page, interceptNetworkCall }) => {
    await log.step('Given latest.json names the app id this build was made with');
    const appId = process.env.APP_ID || 'local';
    const latest = interceptNetworkCall({
      url: '**/updates/latest.json',
      fulfillResponse: { status: 200, body: { version: 'another-commit', app: appId } },
    });

    await log.step('When the shell opens');
    await page.goto('/');
    await latest;

    await log.step('Then the shell shows and the refresh page does not');
    await expect(page.getByTestId('build-commit-id')).toBeVisible();
    await expect(page.getByTestId('refresh-page')).toHaveCount(0);
  });
});
