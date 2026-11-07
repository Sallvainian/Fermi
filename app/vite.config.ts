import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// The commit this build came from: deploy.yml's GITHUB_SHA, or `local` on a
// developer machine. App.tsx shows it, and scripts/check-site.sh reads it back
// from the served HTML to prove the push that just ran is the one that is live.
const buildId = process.env.GITHUB_SHA || 'local';

// The git tree hash of app/ (deploy.yml's APP_ID, `git rev-parse HEAD:app`), or
// `local`. It changes only when something under app/ does, so the update check
// (src/update/) compares it with latest.json's `app` and shows the refresh page
// only for a real app change, not for a docs-only push.
const appId = process.env.APP_ID || 'local';

// Writes the build id into index.html as a meta tag, so the health check can
// read it without running any JavaScript.
const buildIdMeta: Plugin = {
  name: 'fermi-build-id-meta',
  transformIndexHtml() {
    return [
      {
        tag: 'meta',
        attrs: { name: 'fermi-build', content: buildId },
        injectTo: 'head',
      },
    ];
  },
};

// https://vite.dev/config/
export default defineConfig({
  // Cloudflare serves the app from the root of its own origin (wrangler.jsonc).
  base: '/',
  define: {
    // Declared in src/vite-env.d.ts.
    __BUILD_ID__: JSON.stringify(buildId),
    __APP_ID__: JSON.stringify(appId),
  },
  plugins: [react(), tailwindcss(), buildIdMeta],
});
