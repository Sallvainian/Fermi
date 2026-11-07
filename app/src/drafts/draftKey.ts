// The only builder of draft storage keys (AD-26). A key reads
// `<prefix><user id>:<feature>:<scope ids...>:<field>`; nothing else in
// app/src spells the prefix, and a test enforces that.
const PREFIX = 'fermi:draft:';

// The features that may keep drafts. 'fixture' is the unit tests' feature; each
// epic adds the name of its app/src/features/<area> folder here, and a test
// checks every other entry is such a folder.
export const DRAFT_FEATURES = ['fixture'] as const;
export type DraftFeature = (typeof DRAFT_FEATURES)[number];

// A key without its user id, so a form can build it during render before the
// session resolves. Only draftKey() makes one.
export type DraftKey = string & { readonly __brand: 'DraftKey' };

// The scope of a row that does not exist yet (a new item under its parent).
export type NewRowScope = { readonly newRowOf: string };

export function newRowScope(parentId: string): NewRowScope {
  return { newRowOf: parentId };
}

function checkSegment(segment: string, what: string): void {
  if (segment === '') throw new Error(`Draft key ${what} is empty`);
  if (segment.includes(':')) throw new Error(`Draft key ${what} "${segment}" contains ":"`);
}

export function draftKey(
  feature: DraftFeature,
  ...scopeIdsAndField: [...scopeIds: (string | NewRowScope)[], field: string]
): DraftKey {
  if (!(DRAFT_FEATURES as readonly string[]).includes(feature)) {
    throw new Error(`Draft key feature "${String(feature)}" is not in DRAFT_FEATURES`);
  }
  if (scopeIdsAndField.length === 0) throw new Error('Draft key needs a field');

  const segments: string[] = [feature];
  for (const part of scopeIdsAndField) {
    if (typeof part === 'string') {
      checkSegment(part, 'segment');
      segments.push(part);
    } else {
      checkSegment(part.newRowOf, 'new-row parent id');
      segments.push('new', part.newRowOf);
    }
  }

  const field = scopeIdsAndField[scopeIdsAndField.length - 1];
  if (typeof field !== 'string') throw new Error('Draft key field must be a string');
  if (/password/i.test(field)) throw new Error(`Draft key field "${field}" looks like a password`);

  return segments.join(':') as DraftKey;
}

export function draftStorageKey(userId: string, key: DraftKey): string {
  checkSegment(userId, 'user id');
  return `${PREFIX}${userId}:${key}`;
}

// A counter that changes on every wipe: a mounted hook compares it to the one
// it last saw and resets to its initial value.
let wipeEpoch = 0;
const wipeListeners = new Set<() => void>();

export function draftWipeEpoch(): number {
  return wipeEpoch;
}

export function subscribeDraftWipe(listener: () => void): () => void {
  wipeListeners.add(listener);
  return () => {
    wipeListeners.delete(listener);
  };
}

// Removes every draft key from sessionStorage and leaves other keys alone.
export function wipeDrafts(): void {
  try {
    const doomed: string[] = [];
    for (let i = 0; i < sessionStorage.length; i++) {
      const name = sessionStorage.key(i);
      if (name !== null && name.startsWith(PREFIX)) doomed.push(name);
    }
    for (const name of doomed) sessionStorage.removeItem(name);
  } catch (error) {
    console.warn('Could not wipe drafts from sessionStorage', error);
  }
  wipeEpoch += 1;
  for (const listener of [...wipeListeners]) listener();
}
