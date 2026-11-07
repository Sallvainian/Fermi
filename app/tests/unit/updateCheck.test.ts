import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fromPostgrestError } from '../../src/api/errors.ts';
import { holdBusy } from '../../src/busy/busy.ts';
import {
  checkForUpdate,
  isDynamicImportError,
  refresh,
  resetUpdateCheckForTests,
  startUpdateChecks,
  subscribeUpdate,
  updateState,
} from '../../src/update/updateCheck.ts';
import { stubSessionStorage } from './stub-storage.ts';

const MARKER_KEY = 'fermi:update:refreshed-from';
const OTHER_APP = `${__APP_ID__}-other`;
const MINUTE = 60_000;

let fetchSpy: ReturnType<typeof vi.fn>;

// A fetch that answers every call with the given JSON body (a fresh Response
// each time, since a body reads once).
function answerWith(body: unknown, init: ResponseInit = { status: 200 }) {
  fetchSpy.mockImplementation(async () => new Response(JSON.stringify(body), init));
}

function setVisibility(value: 'visible' | 'hidden') {
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => value });
}

// Lets the fetch and the check's promise chain settle.
async function settle() {
  await vi.advanceTimersByTimeAsync(0);
}

async function start() {
  startUpdateChecks();
  await settle();
}

beforeEach(() => {
  vi.useFakeTimers();
  resetUpdateCheckForTests();
  stubSessionStorage();
  fetchSpy = vi.fn();
  vi.stubGlobal('fetch', fetchSpy);
  answerWith({ version: 'v2', app: __APP_ID__ });
  setVisibility('visible');
});

afterEach(() => {
  resetUpdateCheckForTests();
  delete (document as { visibilityState?: unknown }).visibilityState;
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe('what a check reads', () => {
  it('fetches latest.json without the cache, once, at start', async () => {
    await start();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy).toHaveBeenCalledWith('/updates/latest.json', { cache: 'no-store' });
  });

  it('shows nothing when the live app is this app', async () => {
    await start();
    expect(updateState()).toBe('current');
  });

  it('shows nothing for a new version of the same app', async () => {
    answerWith({ version: 'v2', app: __APP_ID__ });
    await start();
    expect(updateState()).toBe('current');
  });

  it('shows the refresh page for a different app when idle', async () => {
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    expect(updateState()).toBe('refresh');
  });

  it('tells subscribers when the state changes, but not ones that unsubscribed', async () => {
    const kept = vi.fn();
    const dropped = vi.fn();
    subscribeUpdate(kept);
    const off = subscribeUpdate(dropped);
    off();
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    expect(updateState()).toBe('refresh');
    expect(kept).toHaveBeenCalledTimes(1);
    expect(dropped).not.toHaveBeenCalled();
  });

  describe.each([
    ['a rejected fetch', () => fetchSpy.mockRejectedValue(new TypeError('Failed to fetch'))],
    ['a 500', () => answerWith({ version: 'v2', app: OTHER_APP }, { status: 500 })],
    [
      'an HTML body (the SPA fallback)',
      () => fetchSpy.mockImplementation(async () => new Response('<!doctype html><title>Fermi</title>')),
    ],
    ['an array', () => answerWith([])],
    ['null', () => answerWith(null)],
    ['a string', () => answerWith('another-app')],
    ['no app', () => answerWith({ version: 'v2' })],
    ['an empty app', () => answerWith({ version: 'v2', app: '' })],
    ['a non-string app', () => answerWith({ version: 'v2', app: 7 })],
  ])('%s', (_name, arrange) => {
    it('shows nothing and does not throw', async () => {
      arrange();
      await start();
      expect(fetchSpy).toHaveBeenCalledTimes(1);
      expect(updateState()).toBe('current');
      await expect(checkForUpdate()).resolves.toBeUndefined();
      expect(updateState()).toBe('current');
    });
  });
});

describe('triggers', () => {
  async function fireOne(fire: () => void) {
    await start();
    fetchSpy.mockClear();
    fire();
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  }

  it('checks when the tab becomes visible', async () => {
    await fireOne(() => document.dispatchEvent(new Event('visibilitychange')));
  });

  it('checks on pageshow', async () => {
    await fireOne(() => window.dispatchEvent(new Event('pageshow')));
  });

  it('checks when the browser comes back online', async () => {
    await fireOne(() => window.dispatchEvent(new Event('online')));
  });

  it('checks on vite:preloadError', async () => {
    await fireOne(() => window.dispatchEvent(new Event('vite:preloadError')));
  });

  it.each([
    'Failed to fetch dynamically imported module: https://fermi/assets/a.js',
    'Importing a module script failed.',
    'error loading dynamically imported module',
  ])('checks on an unhandled rejection saying "%s"', async (message) => {
    await fireOne(() =>
      window.dispatchEvent(Object.assign(new Event('unhandledrejection'), { reason: new TypeError(message) })),
    );
  });

  it('ignores an unhandled rejection that is not a dynamic import failure', async () => {
    await start();
    fetchSpy.mockClear();
    window.dispatchEvent(Object.assign(new Event('unhandledrejection'), { reason: new Error('boom') }));
    window.dispatchEvent(Object.assign(new Event('unhandledrejection'), { reason: undefined }));
    await settle();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('starts only once', async () => {
    await start();
    startUpdateChecks();
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    fetchSpy.mockClear();
    window.dispatchEvent(new Event('online'));
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('joins a check already in flight', async () => {
    let finish!: (response: Response) => void;
    fetchSpy.mockImplementation(() => new Promise<Response>((resolve) => (finish = resolve)));
    startUpdateChecks();
    window.dispatchEvent(new Event('online'));
    window.dispatchEvent(new Event('pageshow'));
    const joined = checkForUpdate();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    finish(new Response(JSON.stringify({ version: 'v2', app: OTHER_APP })));
    await joined;
    expect(updateState()).toBe('refresh');
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('checks again once the earlier check has finished', async () => {
    await start();
    await checkForUpdate();
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });
});

describe('the 15-minute timer', () => {
  it('checks once every 15 minutes while visible', async () => {
    await start();
    fetchSpy.mockClear();
    await vi.advanceTimersByTimeAsync(15 * MINUTE - 1);
    expect(fetchSpy).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(15 * MINUTE);
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it('does not run while the tab is hidden, and restarts when it is visible', async () => {
    await start();
    setVisibility('hidden');
    document.dispatchEvent(new Event('visibilitychange'));
    fetchSpy.mockClear();
    await vi.advanceTimersByTimeAsync(60 * MINUTE);
    expect(fetchSpy).not.toHaveBeenCalled();

    setVisibility('visible');
    document.dispatchEvent(new Event('visibilitychange'));
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(15 * MINUTE);
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it('never starts when the app starts in a hidden tab', async () => {
    setVisibility('hidden');
    await start();
    fetchSpy.mockClear();
    await vi.advanceTimersByTimeAsync(60 * MINUTE);
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});

describe('after a different app is found', () => {
  it('stops every trigger, timer and listener', async () => {
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    expect(updateState()).toBe('refresh');
    fetchSpy.mockClear();
    document.dispatchEvent(new Event('visibilitychange'));
    for (const name of ['pageshow', 'online', 'vite:preloadError']) {
      window.dispatchEvent(new Event(name));
    }
    window.dispatchEvent(
      Object.assign(new Event('unhandledrejection'), { reason: new Error('Failed to fetch dynamically imported module') }),
    );
    await vi.advanceTimersByTimeAsync(60 * MINUTE);
    await checkForUpdate();
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(updateState()).toBe('refresh');
  });
});

describe('stale client codes', () => {
  it.each(['PGRST202', 'PGRST204', '42883', '42703'])('%s runs a check at once and still maps the error', async (code) => {
    expect(fetchSpy).not.toHaveBeenCalled();
    answerWith({ version: 'v2', app: OTHER_APP });
    const err = fromPostgrestError({ code, message: 'something' });
    expect(err.code).toBe('unknown_error');
    expect(err.sqlstate).toBe(code);
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(updateState()).toBe('refresh');
  });

  it('does not check for any other code', async () => {
    fromPostgrestError({ code: '42501', message: 'forbidden' });
    fromPostgrestError({ code: '', message: 'boom' });
    await settle();
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});

describe('busy work', () => {
  it('keeps the app while busy and shows the page on release', async () => {
    const release = holdBusy();
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    expect(updateState()).toBe('waiting');
    await vi.advanceTimersByTimeAsync(2 * MINUTE - 1);
    expect(updateState()).toBe('waiting');
    release();
    expect(updateState()).toBe('refresh');
    await vi.advanceTimersByTimeAsync(5 * MINUTE);
    expect(updateState()).toBe('refresh');
  });

  it('waits for the last of several holds', async () => {
    const a = holdBusy();
    const b = holdBusy();
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    a();
    expect(updateState()).toBe('waiting');
    b();
    expect(updateState()).toBe('refresh');
  });

  it('shows the page after 2 minutes if the work still holds', async () => {
    const release = holdBusy();
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    await vi.advanceTimersByTimeAsync(2 * MINUTE);
    expect(updateState()).toBe('refresh');
    release();
    expect(updateState()).toBe('refresh');
  });

  it('does not check again while waiting', async () => {
    const release = holdBusy();
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    fetchSpy.mockClear();
    window.dispatchEvent(new Event('online'));
    await vi.advanceTimersByTimeAsync(15 * MINUTE);
    expect(fetchSpy).not.toHaveBeenCalled();
    release();
  });
});

describe('Refresh and the marker', () => {
  it('stores the marker and reloads', () => {
    const storage = stubSessionStorage();
    const reload = vi.fn();
    vi.stubGlobal('location', { ...window.location, reload });
    refresh();
    expect(storage.setItem).toHaveBeenCalledWith(MARKER_KEY, __APP_ID__);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('reloads even when storage throws', () => {
    stubSessionStorage({
      setItem: vi.fn(() => {
        throw new Error('quota');
      }),
    });
    const reload = vi.fn();
    vi.stubGlobal('location', { ...window.location, reload });
    expect(() => refresh()).not.toThrow();
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('removes the marker at start, and checks at once when it names another app', async () => {
    const storage = stubSessionStorage();
    storage.setItem(MARKER_KEY, OTHER_APP);
    await start();
    expect(storage.removeItem).toHaveBeenCalledWith(MARKER_KEY);
    expect(storage.getItem(MARKER_KEY)).toBeNull();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('defers every check to one at start + 30 s when the same build came back', async () => {
    const storage = stubSessionStorage();
    storage.setItem(MARKER_KEY, __APP_ID__);
    answerWith({ version: 'v2', app: OTHER_APP });
    await start();
    expect(storage.getItem(MARKER_KEY)).toBeNull();
    window.dispatchEvent(new Event('online'));
    window.dispatchEvent(new Event('pageshow'));
    void checkForUpdate();
    await vi.advanceTimersByTimeAsync(30_000 - 1);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(updateState()).toBe('current');
    await vi.advanceTimersByTimeAsync(1);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(updateState()).toBe('refresh');
  });

  it('checks normally after the 30 s have passed', async () => {
    const storage = stubSessionStorage();
    storage.setItem(MARKER_KEY, __APP_ID__);
    await start();
    await vi.advanceTimersByTimeAsync(30_000);
    fetchSpy.mockClear();
    window.dispatchEvent(new Event('online'));
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('checks at once when storage throws', async () => {
    stubSessionStorage({
      getItem: vi.fn(() => {
        throw new Error('blocked');
      }),
      removeItem: vi.fn(() => {
        throw new Error('blocked');
      }),
    });
    await start();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });
});

describe('a reset while a check is in flight', () => {
  it('ignores the late answer', async () => {
    let finish!: (response: Response) => void;
    fetchSpy.mockImplementation(() => new Promise<Response>((resolve) => (finish = resolve)));
    startUpdateChecks();
    resetUpdateCheckForTests();
    finish(new Response(JSON.stringify({ version: 'v2', app: OTHER_APP })));
    await settle();
    expect(updateState()).toBe('current');
  });
});

describe('isDynamicImportError', () => {
  it.each([
    [new TypeError('Failed to fetch dynamically imported module: /a.js'), true],
    [new TypeError('Importing a module script failed.'), true],
    [new TypeError('error loading dynamically imported module: /a.js'), true],
    ['Failed to fetch dynamically imported module', true],
    [{ message: 'Importing a module script failed' }, true],
    [new Error('Failed to fetch'), false],
    [new Error('boom'), false],
    [{ message: 7 }, false],
    [null, false],
    [undefined, false],
  ])('%j -> %s', (reason, expected) => {
    expect(isDynamicImportError(reason)).toBe(expected);
  });
});
