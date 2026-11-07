import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { stubSessionStorage } from './stub-storage.ts';
import {
  DRAFT_FEATURES,
  draftKey,
  draftStorageKey,
  draftWipeEpoch,
  newRowScope,
  subscribeDraftWipe,
  wipeDrafts,
  type DraftFeature,
} from '../../src/drafts/draftKey.ts';

const SRC = join(import.meta.dirname, '../../src');

function filesUnder(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? filesUnder(path) : [path];
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  sessionStorage.clear();
});

describe('draftKey', () => {
  it('builds the storage key from the user, feature, scope ids and field', () => {
    expect(draftStorageKey('u1', draftKey('fixture', 'c1', 'body'))).toBe('fermi:draft:u1:fixture:c1:body');
  });

  it('marks a row that does not exist yet', () => {
    const key = draftKey('fixture', newRowScope('c1'), 'title');
    expect(draftStorageKey('u1', key)).toBe('fermi:draft:u1:fixture:new:c1:title');
  });

  it('accepts a field with no scope ids', () => {
    expect(draftStorageKey('u1', draftKey('fixture', 'note'))).toBe('fermi:draft:u1:fixture:note');
  });

  it.each([
    ['an unknown feature', () => draftKey('nope' as DraftFeature, 'c1', 'body'), /feature "nope"/],
    ['no field', () => (draftKey as (...args: string[]) => unknown)('fixture'), /needs a field/],
    ['an empty segment', () => draftKey('fixture', '', 'body'), /empty/],
    ['a segment with a colon', () => draftKey('fixture', 'a:b', 'body'), /contains ":"/],
    ['an empty new-row parent', () => draftKey('fixture', newRowScope(''), 'body'), /empty/],
    ['a new-row parent with a colon', () => draftKey('fixture', newRowScope('a:b'), 'body'), /contains ":"/],
    ['a password field', () => draftKey('fixture', 'c1', 'newPassword'), /password/],
    ['a field that is a new-row scope', () => draftKey('fixture', 'c1', newRowScope('x') as never), /field/],
  ])('throws for %s', (_name, build, message) => {
    expect(build).toThrow(message);
  });

  it('rejects an empty or colon-bearing user id', () => {
    const key = draftKey('fixture', 'c1', 'body');
    expect(() => draftStorageKey('', key)).toThrow(/user id/);
    expect(() => draftStorageKey('a:b', key)).toThrow(/user id/);
  });
});

describe('wipeDrafts', () => {
  it('removes every draft key and keeps the others', () => {
    sessionStorage.setItem(draftStorageKey('u1', draftKey('fixture', 'a', 'x')), '"1"');
    sessionStorage.setItem(draftStorageKey('u2', draftKey('fixture', 'b', 'y')), '"2"');
    sessionStorage.setItem('other', 'keep');
    wipeDrafts();
    expect(sessionStorage.length).toBe(1);
    expect(sessionStorage.getItem('other')).toBe('keep');
  });

  it('notifies subscribers and moves the epoch, until they unsubscribe', () => {
    const listener = vi.fn();
    const stop = subscribeDraftWipe(listener);
    const before = draftWipeEpoch();
    wipeDrafts();
    expect(listener).toHaveBeenCalledTimes(1);
    expect(draftWipeEpoch()).toBe(before + 1);
    stop();
    wipeDrafts();
    expect(listener).toHaveBeenCalledTimes(1);
  });

  it('warns and carries on when storage throws', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    stubSessionStorage({
      key: () => {
        throw new Error('denied');
      },
    });
    sessionStorage.setItem('x', '1');
    const listener = vi.fn();
    const stop = subscribeDraftWipe(listener);
    expect(() => wipeDrafts()).not.toThrow();
    stop();
    expect(warn).toHaveBeenCalled();
    expect(listener).toHaveBeenCalled();
  });
});

describe('source rules', () => {
  it('has a folder under src/features for every feature but the test one', () => {
    for (const feature of DRAFT_FEATURES.filter((f) => f !== 'fixture')) {
      expect(statSync(join(SRC, 'features', feature)).isDirectory()).toBe(true);
    }
  });

  it('spells the draft key prefix only in drafts/draftKey.ts', () => {
    const offenders = filesUnder(SRC)
      .filter((file) => readFileSync(file, 'utf8').includes('fermi:draft:'))
      .map((file) => relative(SRC, file));
    expect(offenders).toEqual(['drafts/draftKey.ts']);
  });

  it('never touches localStorage', () => {
    const offenders = filesUnder(SRC)
      .filter((file) => readFileSync(file, 'utf8').includes('localStorage'))
      .map((file) => relative(SRC, file));
    expect(offenders).toEqual([]);
  });
});
