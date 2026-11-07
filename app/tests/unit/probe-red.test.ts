import { describe, it, expect } from 'vitest';

describe('CI red probe', () => {
  it('fails on purpose', () => {
    debugger;
    expect(1).toBe(2);
  });
});
