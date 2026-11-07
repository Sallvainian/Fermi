/// <reference types="vite/client" />

// The commit id this build came from, or `local`. Set in vite.config.ts.
declare const __BUILD_ID__: string;

// The git tree hash of app/ this build came from, or `local`. Set in
// vite.config.ts from deploy.yml's APP_ID; the update check compares it with
// latest.json's `app`.
declare const __APP_ID__: string;

// Both unset means the local stack; see src/api/env.ts.
interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY?: string;
}
