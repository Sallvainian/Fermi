import { vi } from 'vitest';

// happy-dom's Storage ignores prototype spies, so swap the global for a plain
// in-memory Storage whose methods the test can override.
export function stubSessionStorage(overrides: Partial<Storage> = {}) {
  const data = new Map<string, string>();
  const storage = {
    get length() {
      return data.size;
    },
    key: (i: number) => [...data.keys()][i] ?? null,
    getItem: vi.fn((k: string) => data.get(k) ?? null),
    setItem: vi.fn((k: string, v: string) => void data.set(k, v)),
    removeItem: vi.fn((k: string) => void data.delete(k)),
    clear: () => data.clear(),
    ...overrides,
  };
  vi.stubGlobal('sessionStorage', storage);
  return storage;
}
