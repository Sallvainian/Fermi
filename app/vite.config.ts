import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// The commit this build came from: deploy.yml's GITHUB_SHA, or `local` on a
// developer machine. App.tsx shows it, and scripts/check-site.sh reads it back
// from the served HTML to prove the push that just ran is the one that is live.
const buildId = process.env.GITHUB_SHA || 'local';

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
  },
  plugins: [react(), tailwindcss(), buildIdMeta],
});
