/// <reference types="vite/client" />

// The commit id this build came from, or `local`. Set in vite.config.ts.
declare const __BUILD_ID__: string;

// Both unset means the local stack; see src/api/env.ts.
interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY?: string;
}
