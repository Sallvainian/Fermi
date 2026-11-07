import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { supabaseEnv, type SupabaseEnv } from './env.ts';

export type Supabase = SupabaseClient;

export function createSupabase(env: SupabaseEnv): Supabase {
  return createClient(env.url, env.publishableKey);
}

let instance: Supabase | undefined;

// The one client. Created on the first call, so code that never calls
// Supabase (the shell today) never builds it or reads the environment.
export function supabase(): Supabase {
  instance ??= createSupabase(supabaseEnv());
  return instance;
}
