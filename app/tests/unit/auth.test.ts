import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  resetAuthForTests,
  sessionState,
  startAuth,
  subscribeSession,
} from '../../src/api/auth.ts';
import { draftKey, draftStorageKey } from '../../src/drafts/draftKey.ts';
import { fakeAuthClient } from './fake-auth-client.ts';

afterEach(() => {
  resetAuthForTests();
  sessionStorage.clear();
});

describe('session store', () => {
  it('is loading until the first event', () => {
    const { client } = fakeAuthClient();
    startAuth(client);
    expect(sessionState()).toEqual({ status: 'loading' });
  });

  it('turns signed in or out from any event session', () => {
    const { client, emit } = fakeAuthClient();
    startAuth(client);
    emit('INITIAL_SESSION', 'u1');
    expect(sessionState()).toEqual({ status: 'signed-in', userId: 'u1' });
    emit('SIGNED_IN', 'u2');
    expect(sessionState()).toEqual({ status: 'signed-in', userId: 'u2' });
    emit('SIGNED_OUT', null);
    expect(sessionState()).toEqual({ status: 'signed-out' });
  });

  it('resolves to signed out when there is no session at startup', () => {
    const { client, emit } = fakeAuthClient();
    startAuth(client);
    emit('INITIAL_SESSION', null);
    expect(sessionState()).toEqual({ status: 'signed-out' });
  });

  it('keeps the same snapshot and stays quiet when nothing changed', () => {
    const { client, emit } = fakeAuthClient();
    startAuth(client);
    emit('INITIAL_SESSION', 'u1');
    const snapshot = sessionState();
    const listener = vi.fn();
    const stop = subscribeSession(listener);
    emit('TOKEN_REFRESHED', 'u1');
    expect(sessionState()).toBe(snapshot);
    expect(listener).not.toHaveBeenCalled();
    emit('SIGNED_OUT', null);
    expect(listener).toHaveBeenCalledTimes(1);
    stop();
    emit('SIGNED_IN', 'u1');
    expect(listener).toHaveBeenCalledTimes(1);
  });

  it('registers one listener however often it starts', () => {
    const { client, onAuthStateChange } = fakeAuthClient();
    startAuth(client);
    startAuth(client);
    expect(onAuthStateChange).toHaveBeenCalledTimes(1);
  });

  it('builds the shared client when none is passed', async () => {
    const onAuthStateChange = vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } }));
    vi.resetModules();
    vi.doMock('../../src/api/client.ts', () => ({ supabase: () => ({ auth: { onAuthStateChange } }) }));
    const auth = await import('../../src/api/auth.ts');
    auth.startAuth();
    expect(onAuthStateChange).toHaveBeenCalledTimes(1);
    vi.doUnmock('../../src/api/client.ts');
    vi.resetModules();
  });

  it('stops listening on reset', () => {
    const { client, unsubscribe } = fakeAuthClient();
    startAuth(client);
    resetAuthForTests();
    expect(unsubscribe).toHaveBeenCalledTimes(1);
    resetAuthForTests();
    expect(unsubscribe).toHaveBeenCalledTimes(1);
  });
});

describe('wipe on SIGNED_OUT', () => {
  it('removes every draft key and keeps other keys', () => {
    const { client, emit } = fakeAuthClient();
    startAuth(client);
    emit('INITIAL_SESSION', 'u1');
    sessionStorage.setItem(draftStorageKey('u1', draftKey('fixture', 'c1', 'body')), '"hi"');
    sessionStorage.setItem(draftStorageKey('u2', draftKey('fixture', 'c2', 'body')), '"yo"');
    sessionStorage.setItem('unrelated', 'keep');
    emit('SIGNED_OUT', null);
    expect(sessionStorage.length).toBe(1);
    expect(sessionStorage.getItem('unrelated')).toBe('keep');
  });

  it('does not wipe on other events', () => {
    const { client, emit } = fakeAuthClient();
    startAuth(client);
    sessionStorage.setItem(draftStorageKey('u1', draftKey('fixture', 'c1', 'body')), '"hi"');
    emit('INITIAL_SESSION', 'u1');
    emit('TOKEN_REFRESHED', 'u1');
    emit('USER_UPDATED', 'u1');
    expect(sessionStorage.length).toBe(1);
  });
});
