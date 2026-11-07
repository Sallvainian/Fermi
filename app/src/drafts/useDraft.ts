import { useCallback, useState, useSyncExternalStore } from 'react';
import { sessionState, subscribeSession } from '../api/auth.ts';
import { draftStorageKey, draftWipeEpoch, subscribeDraftWipe, type DraftKey } from './draftKey.ts';

// What a draft may hold: JSON. File and Blob are not JSON; keep file names
// with draftFileNames() instead.
export type DraftValue =
  | string
  | number
  | boolean
  | null
  | DraftValue[]
  | { [key: string]: DraftValue };

// `useDraft(key, '')` infers the literal type ''; widen it so setValue takes any
// string. Only the top level is widened: for an object with a boolean or
// literal field, pass the type yourself, as in useDraft<Form>(key, initial).
type Widen<T> = T extends string ? string : T extends number ? number : T extends boolean ? boolean : T;

export type Draft<T> = {
  value: T;
  setValue: (next: T) => void;
  // True when value came from storage and has not been cleared since.
  restored: boolean;
  // Removes the stored draft and returns to the initial value (send, save, cancel, Discard).
  clear: () => void;
};

export function draftFileNames(files: Iterable<File>): string[] {
  return Array.from(files, (file) => file.name);
}

function assertJson(value: unknown, seen = new Set<object>()): void {
  if (typeof Blob !== 'undefined' && value instanceof Blob) {
    throw new TypeError('A draft cannot hold a File or Blob; store file names with draftFileNames()');
  }
  if (typeof value !== 'object' || value === null || seen.has(value)) return;
  seen.add(value);
  for (const item of Array.isArray(value) ? value : Object.values(value)) assertJson(item, seen);
}

function readStored(storageKey: string): { value: unknown } | undefined {
  try {
    const raw = sessionStorage.getItem(storageKey);
    return raw === null ? undefined : { value: JSON.parse(raw) };
  } catch (error) {
    console.warn(`Could not restore draft ${storageKey}`, error);
    return undefined;
  }
}

type Slot<T> = { key: DraftKey; storageKey: string | null; epoch: number; value: T; restored: boolean };

function settle<T>(
  prev: Slot<T> | undefined,
  key: DraftKey,
  storageKey: string | null,
  epoch: number,
  initial: T,
): Slot<T> {
  // A wipe changed the epoch: storage was emptied, so start over from initial.
  const wiped = prev !== undefined && prev.epoch !== epoch;
  if (!wiped && storageKey !== null) {
    const stored = readStored(storageKey);
    if (stored) return { key, storageKey, epoch, value: stored.value as T, restored: true };
    // Text typed while the session was still loading is kept when it resolves,
    // but only for the same draft key.
    if (prev && prev.storageKey === null && prev.key === key) {
      return { key, storageKey, epoch, value: prev.value, restored: false };
    }
  }
  return { key, storageKey, epoch, value: initial, restored: false };
}

// One form field's draft, kept in sessionStorage under the signed-in user's
// key. Until the session resolves, and when signed out, it is memory only.
export function useDraft<T extends DraftValue>(key: DraftKey, initial: T): Draft<Widen<T>> {
  // Widen<T> is only for callers; inside, a draft is any DraftValue.
  type V = DraftValue;
  const initialValue: V = initial;
  const session = useSyncExternalStore(subscribeSession, sessionState, sessionState);
  const epoch = useSyncExternalStore(subscribeDraftWipe, draftWipeEpoch, draftWipeEpoch);
  const storageKey = session.status === 'signed-in' ? draftStorageKey(session.userId, key) : null;

  const [slot, setSlot] = useState<Slot<V>>(() => settle(undefined, key, storageKey, epoch, initialValue));

  // The user, the key or a wipe changed: settle again during render (no effect, no flash).
  let current = slot;
  if (slot.key !== key || slot.storageKey !== storageKey || slot.epoch !== epoch) {
    current = settle(slot, key, storageKey, epoch, initialValue);
    setSlot(current);
  }

  const setValue = useCallback(
    (next: V) => {
      assertJson(next);
      // A setValue held across an await can outlive its session: write only if
      // the user, the key and the wipe epoch are still the ones it was made for.
      const live = sessionState();
      const stillCurrent =
        live.status === 'signed-in' &&
        draftStorageKey(live.userId, key) === storageKey &&
        draftWipeEpoch() === epoch;
      if (storageKey !== null && stillCurrent) {
        try {
          sessionStorage.setItem(storageKey, JSON.stringify(next));
        } catch (error) {
          console.warn(`Could not store draft ${storageKey}; keeping it in memory`, error);
        }
      }
      setSlot((prev) => ({ ...prev, key, storageKey, epoch, value: next }));
    },
    [key, storageKey, epoch],
  );

  const clear = useCallback(() => {
    if (storageKey !== null) {
      try {
        sessionStorage.removeItem(storageKey);
      } catch (error) {
        console.warn(`Could not clear draft ${storageKey}`, error);
      }
    }
    setSlot({ key, storageKey, epoch, value: initialValue, restored: false });
  }, [key, storageKey, epoch, initialValue]);

  return { value: current.value, setValue, restored: current.restored, clear } as unknown as Draft<Widen<T>>;
}
