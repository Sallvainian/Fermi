// Vitest setup, run before every unit and component test file.
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// Testing Library unmounts after each test on its own only when the runner
// exposes a global afterEach; vitest.config.ts keeps globals off, so do it here.
afterEach(() => {
  cleanup();
});
