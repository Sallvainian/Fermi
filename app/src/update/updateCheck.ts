import { isBusy, subscribeBusy } from '../busy/busy.ts';

// The update check (AD-24, R1): a tab or Home Screen web app left open across a
// deploy learns that the build changed and shows the refresh page. Framework
// free, so Vitest drives every trigger and timer without React; UpdateGate only
// reads the state.
//
// The deploy writes /updates/latest.json as { version, app } (scripts/
// write-latest-json.sh). `version` is the commit; `app` is the git tree hash of
// app/, baked into this build as __APP_ID__. A different `app` means app/
// changed, so a docs-only push never shows the page.
//
// The state goes 'current' -> ('waiting' while busy work runs) -> 'refresh' and
// never back: the refresh page cannot be dismissed, so it is final for the
// page's life.
export type UpdateState = 'current' | 'waiting' | 'refresh';

const LATEST_URL = '/updates/latest.json';
// While the tab is visible, how often the check repeats.
const CHECK_INTERVAL_MS = 15 * 60_000;
// The longest a found update waits for busy work (uploads, imports) to end.
const BUSY_WAIT_MS = 2 * 60_000;
// After a Refresh that came back to the same app, how long checks stay quiet.
const SAME_BUILD_QUIET_MS = 30_000;

// sessionStorage key for Refresh's marker. Not a draft key, so signing out and
// the draft store never touch it.
const REFRESHED_FROM_KEY = 'fermi:update:refreshed-from';

// What a failed dynamic import says, by browser (Chrome, Safari, Firefox).
const DYNAMIC_IMPORT_ERRORS = [
  'Failed to fetch dynamically imported module',
  'Importing a module script failed',
  'error loading dynamically imported module',
];

let state: UpdateState = 'current';
const listeners = new Set<() => void>();

let started = false;
let generation = 0;
let inFlight: Promise<void> | null = null;
// True from start until the quiet period after a same-build Refresh ends.
let quiet = false;
let quietTimer: ReturnType<typeof setTimeout> | undefined;
let intervalTimer: ReturnType<typeof setInterval> | undefined;
let busyOff: (() => void) | undefined;
let busyTimer: ReturnType<typeof setTimeout> | undefined;
let removeTriggers: (() => void) | undefined;

export function updateState(): UpdateState {
  return state;
}

export function subscribeUpdate(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

function set(next: UpdateState): void {
  if (state === next) return;
  state = next;
  for (const listener of [...listeners]) listener();
}

export function isDynamicImportError(reason: unknown): boolean {
  let message = '';
  if (typeof reason === 'string') {
    message = reason;
  } else if (typeof reason === 'object' && reason !== null) {
    const m = (reason as { message?: unknown }).message;
    if (typeof m === 'string') message = m;
  }
  const lower = message.toLowerCase();
  return DYNAMIC_IMPORT_ERRORS.some((text) => lower.includes(text.toLowerCase()));
}

// True when latest.json says a different app is live. Anything else -- a
// rejected fetch, a non-2xx status, a body that is not JSON (the SPA fallback
// answers a missing file with HTML), not an object, or no non-empty string
// `app` -- says nothing, so nothing is shown.
async function liveAppDiffers(): Promise<boolean> {
  try {
    const response = await fetch(LATEST_URL, { cache: 'no-store' });
    if (!response.ok) return false;
    const body: unknown = await response.json();
    if (typeof body !== 'object' || body === null || Array.isArray(body)) return false;
    const app = (body as { app?: unknown }).app;
    return typeof app === 'string' && app !== '' && app !== __APP_ID__;
  } catch {
    return false;
  }
}

// Stops every trigger, timer and listener the check owns. Does not touch the
// busy wait, which is how a found update ends.
function stopChecks(): void {
  removeTriggers?.();
  removeTriggers = undefined;
  clearInterval(intervalTimer);
  intervalTimer = undefined;
  clearTimeout(quietTimer);
  quietTimer = undefined;
  quiet = false;
}

function updateFound(): void {
  stopChecks();
  if (!isBusy()) {
    set('refresh');
    return;
  }
  // Work that must not be cut off holds the busy registry: show the page when
  // it ends, or after two minutes if it has not.
  set('waiting');
  busyOff = subscribeBusy(() => {
    if (!isBusy()) showRefreshPage();
  });
  busyTimer = setTimeout(showRefreshPage, BUSY_WAIT_MS);
}

function showRefreshPage(): void {
  busyOff?.();
  busyOff = undefined;
  clearTimeout(busyTimer);
  busyTimer = undefined;
  set('refresh');
}

// Fetches latest.json once and acts on it. Never rejects. A check that starts
// while one is in flight joins it. Once a different app is found, or while the
// quiet period after a same-build Refresh runs, it does nothing (the quiet
// period ends in one check of its own).
export function checkForUpdate(): Promise<void> {
  if (state !== 'current' || quiet) return Promise.resolve();
  if (inFlight) return inFlight;
  const mine = generation;
  const run = liveAppDiffers().then((differs) => {
    if (inFlight === run) inFlight = null;
    if (differs && mine === generation && state === 'current') updateFound();
  });
  inFlight = run;
  return run;
}

function startInterval(): void {
  clearInterval(intervalTimer);
  intervalTimer = setInterval(() => void checkForUpdate(), CHECK_INTERVAL_MS);
}

function isVisible(): boolean {
  return document.visibilityState === 'visible';
}

// Reads the Refresh marker and removes it. True when it names this build: the
// reload came back to the same app, so the new build is not live for this
// client yet.
function cameBackToSameApp(): boolean {
  try {
    const marker = sessionStorage.getItem(REFRESHED_FROM_KEY);
    sessionStorage.removeItem(REFRESHED_FROM_KEY);
    return marker === __APP_ID__;
  } catch {
    return false;
  }
}

// Starts the checks: reads the Refresh marker, registers the triggers (visible
// again, every pageshow (which includes a back/forward cache restore), back
// online, a failed dynamic import) and the 15-minute timer, and runs the first check. Does nothing when called
// again. main.tsx calls it beside startAuth().
export function startUpdateChecks(): void {
  if (started) return;
  started = true;

  const onVisibility = () => {
    if (isVisible()) {
      void checkForUpdate();
      startInterval();
    } else {
      clearInterval(intervalTimer);
      intervalTimer = undefined;
    }
  };
  const onTrigger = () => void checkForUpdate();
  const onRejection = (event: PromiseRejectionEvent) => {
    if (isDynamicImportError(event.reason)) void checkForUpdate();
  };
  document.addEventListener('visibilitychange', onVisibility);
  window.addEventListener('pageshow', onTrigger);
  window.addEventListener('online', onTrigger);
  window.addEventListener('vite:preloadError', onTrigger);
  window.addEventListener('unhandledrejection', onRejection);
  removeTriggers = () => {
    document.removeEventListener('visibilitychange', onVisibility);
    window.removeEventListener('pageshow', onTrigger);
    window.removeEventListener('online', onTrigger);
    window.removeEventListener('vite:preloadError', onTrigger);
    window.removeEventListener('unhandledrejection', onRejection);
  };

  if (isVisible()) startInterval();

  if (cameBackToSameApp()) {
    // Every check before start + 30 s becomes one check at that time.
    quiet = true;
    quietTimer = setTimeout(() => {
      quiet = false;
      quietTimer = undefined;
      void checkForUpdate();
    }, SAME_BUILD_QUIET_MS);
  } else {
    void checkForUpdate();
  }
}

// The refresh page's button: remembers which build the page was on, then
// reloads. If the reload brings back the same build (a cached page), the marker
// keeps the check quiet for 30 s instead of showing the page again at once.
export function refresh(): void {
  try {
    sessionStorage.setItem(REFRESHED_FROM_KEY, __APP_ID__);
  } catch {
    // The reload still happens; the page may show again at once.
  }
  location.reload();
}

// Puts the module back to its initial state. Tests only.
export function resetUpdateCheckForTests(): void {
  stopChecks();
  busyOff?.();
  busyOff = undefined;
  clearTimeout(busyTimer);
  busyTimer = undefined;
  generation += 1;
  inFlight = null;
  started = false;
  state = 'current';
  listeners.clear();
}
