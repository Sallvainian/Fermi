import { useSyncExternalStore, type ReactNode } from 'react';
import RefreshPage from './RefreshPage.tsx';
import { subscribeUpdate, updateState } from './updateCheck.ts';

// Wraps the router. When the update check finds a newer app, the refresh page
// replaces the children, so the router and everything under it unmount.
export default function UpdateGate({ children }: { children: ReactNode }) {
  const state = useSyncExternalStore(subscribeUpdate, updateState);
  return state === 'refresh' ? <RefreshPage /> : children;
}
