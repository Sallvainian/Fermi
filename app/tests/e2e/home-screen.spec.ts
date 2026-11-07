/**
 * Fermi saved to the Home Screen opens standalone as Fermi+ with Fermi's own
 * icon (R14, story 1.15). Safari's Add to Home Screen reads what this spec
 * reads: the manifest and touch icon index.html links, the manifest's fields,
 * and the PNGs they name. Runs on Desktop Chrome and iPhone WebKit; the
 * install itself is checked by hand on the owner's iPhone.
 *
 * Cloudflare answers any missing path with index.html and a 200
 * (wrangler.jsonc's single-page-application fallback), so a 200 proves
 * nothing: each icon must start with the PNG signature and carry its stated
 * size in its IHDR header.
 */
import { test, expect, log } from '../support/merged-fixtures.ts';

type ManifestIcon = { src: string; sizes: string; type: string };
type Manifest = {
  name: string;
  short_name: string;
  display: string;
  start_url: string;
  scope: string;
  background_color: string;
  theme_color: string;
  icons: ManifestIcon[];
};

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

// The IHDR chunk always comes first: width and height are big-endian at 16 and 20.
function pngSize(bytes: Buffer) {
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

test.describe('Home Screen install', () => {
  // The install happens before anyone signs in.
  test.use({ authSessionEnabled: false });

  test('[P1] index.html links a standalone Fermi+ manifest and Fermi icons of their stated sizes', async ({
    page,
    request,
  }) => {
    await log.step('Given the built site is served, when its page opens');
    await page.goto('/');

    await log.step('Then index.html links the manifest and the 180px touch icon, titled Fermi+');
    const manifestHref = await page.locator('link[rel="manifest"]').getAttribute('href');
    const touchIcon = page.locator('link[rel="apple-touch-icon"]');
    await expect(touchIcon).toHaveAttribute('sizes', '180x180');
    const touchIconHref = await touchIcon.getAttribute('href');
    await expect(page.locator('meta[name="apple-mobile-web-app-title"]')).toHaveAttribute('content', 'Fermi+');
    expect(manifestHref).toBeTruthy();
    expect(touchIconHref).toBeTruthy();

    await log.step('And the manifest is served as JSON with the standalone Fermi+ fields');
    // playwright-utils deviation: apiRequest parses only application/json and
    // text/* bodies and returns no headers, so it can read neither
    // application/manifest+json nor a PNG's bytes; Playwright's request fixture can.
    const manifestResponse = await request.get(manifestHref!);
    expect(manifestResponse.status()).toBe(200);
    expect(manifestResponse.headers()['content-type']).toMatch(/json/);
    const manifest = (await manifestResponse.json()) as Manifest;
    expect(manifest).toMatchObject({
      name: 'Fermi+',
      short_name: 'Fermi+',
      display: 'standalone',
      start_url: '/',
      scope: '/',
      background_color: '#000000',
      theme_color: '#8B5CF6',
    });
    expect(manifest.icons.map((icon) => icon.sizes).sort()).toEqual(['192x192', '512x512']);

    await log.step('And every icon it names, and the touch icon, is a PNG of its stated size');
    const icons = [
      ...manifest.icons.map(({ src, type, sizes }) => {
        const [width, height] = sizes.split('x').map(Number);
        return { src, type, width, height };
      }),
      { src: touchIconHref!, type: 'image/png', width: 180, height: 180 },
    ];
    for (const { src, type, width, height } of icons) {
      expect(type, `${src} declared type`).toBe('image/png');
      const response = await request.get(src);
      expect(response.status(), `${src} status`).toBe(200);
      expect(response.headers()['content-type'], `${src} content type`).toBe('image/png');
      const bytes = await response.body();
      expect([...bytes.subarray(0, 8)], `${src} PNG signature`).toEqual(PNG_SIGNATURE);
      expect(pngSize(bytes), `${src} size`).toEqual({ width, height });
    }
  });
});
