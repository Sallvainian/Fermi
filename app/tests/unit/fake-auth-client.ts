import { vi } from 'vitest';
import type { Supabase } from '../../src/api/client.ts';

type Callback = (event: string, session: { user: { id: string } } | null) => void;

// A client with only auth.onAuthStateChange, which captures the callback so a
// test can fire events. Never touches the network.
export function fakeAuthClient() {
  let callback: Callback | undefined;
  const unsubscribe = vi.fn();
  const onAuthStateChange = vi.fn((cb: Callback) => {
    callback = cb;
    return { data: { subscription: { unsubscribe } } };
  });
  const client = { auth: { onAuthStateChange } } as unknown as Supabase;
  return {
    client,
    onAuthStateChange,
    unsubscribe,
    emit(event: string, userId: string | null) {
      callback?.(event, userId === null ? null : { user: { id: userId } });
    },
  };
}
