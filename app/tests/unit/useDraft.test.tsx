import { act, render, renderHook } from '@testing-library/react';
import { StrictMode } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { resetAuthForTests, startAuth } from '../../src/api/auth.ts';
import { draftKey, draftStorageKey, wipeDrafts } from '../../src/drafts/draftKey.ts';
import { draftFileNames, useDraft } from '../../src/drafts/useDraft.ts';
import { fakeAuthClient } from './fake-auth-client.ts';
import { stubSessionStorage } from './stub-storage.ts';

const KEY = draftKey('fixture', 'c1', 'body');
const stored = (userId = 'u1') => sessionStorage.getItem(draftStorageKey(userId, KEY));

function setup() {
  const fake = fakeAuthClient();
  startAuth(fake.client);
  return fake;
}

afterEach(() => {
  resetAuthForTests();
  vi.unstubAllGlobals();
  sessionStorage.clear();
  localStorage.clear();
});

describe('useDraft', () => {
  it('writes synchronously to sessionStorage only', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const { result } = renderHook(() => useDraft(KEY, ''));
    act(() => result.current.setValue('hi'));
    expect(stored()).toBe('"hi"');
    expect(result.current.value).toBe('hi');
    expect(result.current.restored).toBe(false);
    expect(localStorage.length).toBe(0);
  });

  it('restores after a remount for the same user and key', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const first = renderHook(() => useDraft(KEY, ''));
    act(() => first.result.current.setValue('hi'));
    first.unmount();
    const second = renderHook(() => useDraft(KEY, ''));
    expect(second.result.current.value).toBe('hi');
    expect(second.result.current.restored).toBe(true);
  });

  it('works under StrictMode and with structured values', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const wrapper = StrictMode;
    const first = renderHook(() => useDraft(KEY, { names: [] as string[], n: 1, ok: true as boolean, none: null }), { wrapper });
    act(() => first.result.current.setValue({ names: ['a.pdf'], n: 2, ok: false, none: null }));
    first.unmount();
    const second = renderHook(() => useDraft(KEY, { names: [] as string[], n: 1, ok: true as boolean, none: null }), { wrapper });
    expect(second.result.current.value).toEqual({ names: ['a.pdf'], n: 2, ok: false, none: null });
  });

  it('starts fresh with the initial value', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const { result } = renderHook(() => useDraft(KEY, 'start'));
    expect(result.current.value).toBe('start');
    expect(result.current.restored).toBe(false);
  });

  it('ignores corrupt JSON', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    sessionStorage.setItem(draftStorageKey('u1', KEY), '{not json');
    const { result } = renderHook(() => useDraft(KEY, 'start'));
    expect(result.current.value).toBe('start');
    expect(result.current.restored).toBe(false);
    expect(warn).toHaveBeenCalled();
  });

  it('keeps users apart', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const one = renderHook(() => useDraft(KEY, ''));
    act(() => one.result.current.setValue('mine'));
    one.unmount();
    act(() => fake.emit('SIGNED_IN', 'u2'));
    const two = renderHook(() => useDraft(KEY, ''));
    expect(two.result.current.value).toBe('');
    expect(two.result.current.restored).toBe(false);
  });

  it('follows a user switch while mounted', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    sessionStorage.setItem(draftStorageKey('u2', KEY), '"theirs"');
    const { result } = renderHook(() => useDraft(KEY, ''));
    act(() => result.current.setValue('mine'));
    act(() => fake.emit('SIGNED_IN', 'u2'));
    expect(result.current.value).toBe('theirs');
    expect(result.current.restored).toBe(true);
  });

  it('reads and writes nothing while the session is loading', () => {
    const { getItem, setItem } = stubSessionStorage();
    setup();
    const { result } = renderHook(() => useDraft(KEY, ''));
    act(() => result.current.setValue('typed'));
    expect(result.current.value).toBe('typed');
    expect(getItem).not.toHaveBeenCalled();
    expect(setItem).not.toHaveBeenCalled();
    expect(sessionStorage.length).toBe(0);
  });

  it('keeps text typed while loading when the session resolves, without storing it', () => {
    const fake = setup();
    const { result } = renderHook(() => useDraft(KEY, ''));
    act(() => result.current.setValue('typed'));
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    expect(result.current.value).toBe('typed');
    expect(sessionStorage.length).toBe(0);
    act(() => result.current.setValue('typed more'));
    expect(stored()).toBe('"typed more"');
  });

  it('does not carry loading text to a different key', () => {
    const fake = setup();
    const { result, rerender } = renderHook(({ k }) => useDraft(k, ''), { initialProps: { k: KEY } });
    act(() => result.current.setValue('typed'));
    rerender({ k: draftKey('fixture', 'c2', 'body') });
    expect(result.current.value).toBe('');
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    expect(result.current.value).toBe('');
  });

  it('writes nothing from a setValue held across a sign-out, user switch or wipe', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const { result } = renderHook(() => useDraft(KEY, ''));
    const held = result.current.setValue;
    act(() => fake.emit('SIGNED_OUT', null));
    act(() => held('late'));
    expect(sessionStorage.length).toBe(0);

    act(() => fake.emit('SIGNED_IN', 'u1'));
    const heldU1 = result.current.setValue;
    act(() => fake.emit('SIGNED_IN', 'u2'));
    act(() => heldU1('late'));
    expect(sessionStorage.length).toBe(0);

    const heldU2 = result.current.setValue;
    act(() => wipeDrafts());
    act(() => heldU2('late'));
    expect(sessionStorage.length).toBe(0);
  });

  it('restores a stored draft when the session resolves', () => {
    const fake = setup();
    sessionStorage.setItem(draftStorageKey('u1', KEY), '"saved"');
    const { result } = renderHook(() => useDraft(KEY, ''));
    expect(result.current.restored).toBe(false);
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    expect(result.current.value).toBe('saved');
    expect(result.current.restored).toBe(true);
  });

  it('stores nothing while signed out', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', null));
    const { result } = renderHook(() => useDraft(KEY, ''));
    act(() => result.current.setValue('typed'));
    expect(result.current.value).toBe('typed');
    act(() => result.current.clear());
    expect(result.current.value).toBe('');
    expect(sessionStorage.length).toBe(0);
  });

  it('clear removes the key, returns to initial, and the next change writes again', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    sessionStorage.setItem(draftStorageKey('u1', KEY), '"old"');
    const { result } = renderHook(() => useDraft(KEY, ''));
    expect(result.current.restored).toBe(true);
    act(() => result.current.clear());
    expect(stored()).toBeNull();
    expect(result.current.value).toBe('');
    expect(result.current.restored).toBe(false);
    act(() => result.current.setValue('new'));
    expect(stored()).toBe('"new"');
  });

  it('keeps the value in memory and warns when storage throws', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    stubSessionStorage({
      setItem: () => {
        throw new DOMException('full', 'QuotaExceededError');
      },
      removeItem: () => {
        throw new Error('denied');
      },
    });
    const { result } = renderHook(() => useDraft(KEY, ''));
    act(() => result.current.setValue('hi'));
    expect(result.current.value).toBe('hi');
    act(() => result.current.clear());
    expect(result.current.value).toBe('');
    expect(warn).toHaveBeenCalledTimes(2);
  });

  it('throws a TypeError for a File or Blob, bare or nested, and stores nothing', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const { result } = renderHook(() => useDraft<never>(KEY, null as never));
    const file = new File(['x'], 'a.pdf');
    const set = result.current.setValue as (v: unknown) => void;
    expect(() => set(file)).toThrow(TypeError);
    expect(() => set({ a: [new Blob(['x'])] })).toThrow(TypeError);
    expect(sessionStorage.length).toBe(0);
  });

  it('stores file names instead of files', () => {
    const files = [new File(['x'], 'a.pdf'), new File(['y'], 'b.png')];
    expect(draftFileNames(files)).toEqual(['a.pdf', 'b.png']);
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const { result } = renderHook(() => useDraft(KEY, [] as string[]));
    act(() => result.current.setValue(draftFileNames(files)));
    expect(stored()).toBe('["a.pdf","b.png"]');
  });

  it('resets mounted hooks to initial values on SIGNED_OUT, and wipes the keys', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const a = renderHook(() => useDraft(KEY, ''));
    const b = renderHook(() => useDraft(draftKey('fixture', 'c2', 'title'), 't'));
    act(() => a.result.current.setValue('hi'));
    act(() => b.result.current.setValue('there'));
    sessionStorage.setItem('unrelated', 'keep');
    act(() => fake.emit('SIGNED_OUT', null));
    expect(a.result.current.value).toBe('');
    expect(b.result.current.value).toBe('t');
    expect(a.result.current.restored).toBe(false);
    expect(sessionStorage.length).toBe(1);
  });

  it('resets on a wipe while the session stays signed in', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    const { result } = renderHook(() => useDraft(KEY, ''));
    act(() => result.current.setValue('hi'));
    act(() => wipeDrafts());
    expect(result.current.value).toBe('');
    act(() => result.current.setValue('again'));
    expect(stored()).toBe('"again"');
  });

  it('drives a textarea like the design note', () => {
    const fake = setup();
    act(() => fake.emit('INITIAL_SESSION', 'u1'));
    function Form() {
      const body = useDraft(KEY, '');
      return (
        <>
          <textarea data-testid="body" value={body.value} onChange={(e) => body.setValue(e.target.value)} />
          {body.restored && <button onClick={body.clear}>Discard</button>}
        </>
      );
    }
    sessionStorage.setItem(draftStorageKey('u1', KEY), '"saved"');
    const { getByTestId, getByText, queryByText } = render(<Form />);
    expect((getByTestId('body') as HTMLTextAreaElement).value).toBe('saved');
    act(() => getByText('Discard').click());
    expect((getByTestId('body') as HTMLTextAreaElement).value).toBe('');
    expect(queryByText('Discard')).toBeNull();
  });
});
