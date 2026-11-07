// The vite config scripts/test-check-site.sh serves the built shell with
// (`vite preview --config <this file> --outDir <build>`). It has no imports
// beyond node:fs and node:path, so it needs neither the app's plugins nor its
// build variables.
//
// Why it exists: vite preview serves files with sirv, which sends
// `Cache-Control: no-cache` and overrides any header set earlier in the chain.
// check-site.sh asserts `max-age=0` on `/` and `/updates/latest.json`, so the
// test needs a server whose Cache-Control it controls. This plugin answers those
// two paths itself, ahead of sirv, with the header the case asks for:
//   CHECK_SITE_ROOT_CACHE    Cache-Control for `/` and `/index.html`
//   CHECK_SITE_LATEST_CACHE  Cache-Control for `/updates/latest.json`
// Unset means `public, max-age=0, must-revalidate`, what Cloudflare serves;
// set but empty means no Cache-Control header at all.
//
// `/updates/latest.json` is answered only when the build has that file; without
// it the request falls through to the SPA fallback, which answers index.html as
// Cloudflare does.
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const DEFAULT_CACHE = 'public, max-age=0, must-revalidate';

function cacheFrom(name) {
  const value = process.env[name];
  return value === undefined ? DEFAULT_CACHE : value;
}

function send(res, type, cache, body) {
  res.statusCode = 200;
  res.setHeader('Content-Type', type);
  if (cache !== '') res.setHeader('Cache-Control', cache);
  res.end(body);
}

const cacheHeaders = {
  name: 'check-site-cache-headers',
  configurePreviewServer(server) {
    const outDir = resolve(server.config.root, server.config.build.outDir);
    server.middlewares.use((req, res, next) => {
      if (req.method !== 'GET' && req.method !== 'HEAD') return next();
      const path = (req.url ?? '').split('?')[0];
      if (path === '/' || path === '/index.html') {
        return send(res, 'text/html; charset=utf-8', cacheFrom('CHECK_SITE_ROOT_CACHE'), readFileSync(resolve(outDir, 'index.html')));
      }
      if (path === '/updates/latest.json') {
        const file = resolve(outDir, 'updates', 'latest.json');
        if (!existsSync(file)) return next();
        return send(res, 'application/json', cacheFrom('CHECK_SITE_LATEST_CACHE'), readFileSync(file));
      }
      return next();
    });
  },
};

export default {
  plugins: [cacheHeaders],
};
