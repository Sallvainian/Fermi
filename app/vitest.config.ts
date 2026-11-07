import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config.ts';

// Extends vite.config.ts, so unit tests compile the app exactly as the build
// does: the same React plugin and the same __BUILD_ID__ define.
export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      environment: 'happy-dom',
      setupFiles: ['./tests/setup.ts'],
      // Puts every vi.spyOn back before each test, so a spy one file forgets
      // to restore cannot leak into the next.
      restoreMocks: true,
      include: ['tests/unit/**/*.test.{ts,tsx}', 'src/**/*.test.{ts,tsx}'],
      // The order a --sequence.shuffle run uses, from SEED (CI passes its run
      // number) or 1, so a shuffled failure replays exactly with SEED=<n>.
      sequence: { seed: Number(process.env.SEED) || 1 },
      reporters: ['default', 'junit'],
      outputFile: { junit: 'test-results/vitest-junit.xml' },
      coverage: {
        provider: 'v8',
        reporter: ['text', 'json-summary', 'html'],
        include: ['src/**/*.{ts,tsx}'],
        exclude: ['src/**/*.test.{ts,tsx}', 'src/main.tsx', 'src/vite-env.d.ts'],
        // The owner's decision of 2026-11-06 (test design Q3): app/src/api/,
        // the only code that calls Supabase (AD-17), keeps 80% of its lines
        // covered. Screens carry no threshold: the client is thin by design
        // (AD-1). Stores join here once their file naming exists.
        thresholds: {
          'src/api/**': { lines: 80 },
        },
      },
    },
  }),
);
