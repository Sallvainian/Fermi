// Cloudflare Worker for serving Flutter web app with Static Assets

export default {
  async fetch(request, env) {
    // Serve static assets (Flutter web app)
    return env.ASSETS.fetch(request);
  },
};