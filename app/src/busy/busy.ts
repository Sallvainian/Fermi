// The one busy registry (AD-24): work that must not be cut off by a refresh
// (an upload, a CSV import) holds it while it runs. Framework-free.
let holds = 0;
const listeners = new Set<() => void>();

function notify(): void {
  for (const listener of [...listeners]) listener();
}

// Marks work in progress. Call the returned release when it ends; calling it
// again does nothing.
export function holdBusy(): () => void {
  let released = false;
  holds += 1;
  notify();
  return () => {
    if (released) return;
    released = true;
    holds -= 1;
    notify();
  };
}

// Holds the registry while fn runs and releases it however fn ends.
export async function runBusy<T>(fn: () => Promise<T> | T): Promise<T> {
  const release = holdBusy();
  try {
    return await fn();
  } finally {
    release();
  }
}

export function isBusy(): boolean {
  return holds > 0;
}

export function subscribeBusy(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
