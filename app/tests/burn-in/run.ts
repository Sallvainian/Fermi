/**
 * Runs burn-in on the Playwright specs a change affects (see burn-in.config.ts).
 *
 *   npm run test:burn-in -- --base-branch=origin/main
 *
 * Exits 1 when any repeated run fails; exits 0 with a message when the change
 * affects no spec. Run from app/ (npm sets the working directory).
 */
import { runBurnIn } from '@seontechnologies/playwright-utils/burn-in';

const flag = process.argv.find((arg) => arg.startsWith('--base-branch='));
const baseBranch = flag ? flag.slice('--base-branch='.length) : 'main';

await runBurnIn({
  configPath: 'tests/burn-in/burn-in.config.ts',
  baseBranch,
});
