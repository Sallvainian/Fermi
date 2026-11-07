import { describe, expect, it, vi } from 'vitest';
import { holdBusy, isBusy, runBusy, subscribeBusy } from '../../src/busy/busy.ts';

describe('busy registry', () => {
  it('is busy while a hold is open and idle after release', () => {
    expect(isBusy()).toBe(false);
    const release = holdBusy();
    expect(isBusy()).toBe(true);
    release();
    expect(isBusy()).toBe(false);
  });

  it('stays busy until every hold ends', () => {
    const a = holdBusy();
    const b = holdBusy();
    a();
    expect(isBusy()).toBe(true);
    b();
    expect(isBusy()).toBe(false);
  });

  it('ignores a second release of the same hold', () => {
    const a = holdBusy();
    const b = holdBusy();
    a();
    a();
    expect(isBusy()).toBe(true);
    b();
    expect(isBusy()).toBe(false);
  });

  it('holds while runBusy runs and returns its result', async () => {
    let seen = false;
    const result = await runBusy(async () => {
      seen = isBusy();
      return 42;
    });
    expect(result).toBe(42);
    expect(seen).toBe(true);
    expect(isBusy()).toBe(false);
  });

  it('releases and rethrows when the work rejects or throws', async () => {
    await expect(
      runBusy(async () => {
        throw new Error('upload failed');
      }),
    ).rejects.toThrow('upload failed');
    expect(isBusy()).toBe(false);
    await expect(
      runBusy(() => {
        throw new Error('sync failure');
      }),
    ).rejects.toThrow('sync failure');
    expect(isBusy()).toBe(false);
  });

  it('counts two runBusy calls at once', async () => {
    let finishFirst!: () => void;
    const first = runBusy(() => new Promise<void>((resolve) => (finishFirst = resolve)));
    const second = runBusy(async () => {});
    await second;
    expect(isBusy()).toBe(true);
    finishFirst();
    await first;
    expect(isBusy()).toBe(false);
  });

  it('notifies subscribers on each change until they unsubscribe', () => {
    const listener = vi.fn();
    const stop = subscribeBusy(listener);
    const a = holdBusy();
    const b = holdBusy();
    a();
    b();
    expect(listener).toHaveBeenCalledTimes(4);
    stop();
    holdBusy()();
    expect(listener).toHaveBeenCalledTimes(4);
  });
});
