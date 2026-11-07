import type { Supabase } from './client.ts';
import { supabase } from './client.ts';
import { wipeDrafts } from '../drafts/draftKey.ts';

export type SessionState =
  | { readonly status: 'loading' }
  | { readonly status: 'signed-out' }
  | { readonly status: 'signed-in'; readonly userId: string };

const LOADING: SessionState = { status: 'loading' };
const SIGNED_OUT: SessionState = { status: 'signed-out' };

let state: SessionState = LOADING;
const listeners = new Set<() => void>();

// The snapshot is cached: it changes identity only when the status or the user
// changes, as useSyncExternalStore requires.
export function sessionState(): SessionState {
  return state;
}

export function subscribeSession(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

function setState(next: SessionState): void {
  const same =
    next.status === state.status &&
    (next.status !== 'signed-in' || (state.status === 'signed-in' && next.userId === state.userId));
  if (same) return;
  state = next;
  for (const listener of [...listeners]) listener();
}

let unsubscribe: (() => void) | undefined;

// Starts the one auth listener, from app start: after a refresh a tab may hold
// drafts with no form mounted, and a sign-out in another tab (broadcast here as
// SIGNED_OUT) must still wipe them. The first event, INITIAL_SESSION, is the
// session resolving. Safe to call twice.
export function startAuth(client?: Supabase): void {
  if (unsubscribe) return;
  const { data } = (client ?? supabase()).auth.onAuthStateChange((event, session) => {
    // Synchronous on purpose: awaiting a Supabase call here can deadlock.
    setState(session?.user ? { status: 'signed-in', userId: session.user.id } : SIGNED_OUT);
    if (event === 'SIGNED_OUT') wipeDrafts();
  });
  unsubscribe = () => data.subscription.unsubscribe();
}

// Tests only: stop the listener and forget the session.
export function resetAuthForTests(): void {
  unsubscribe?.();
  unsubscribe = undefined;
  setState(LOADING);
}
