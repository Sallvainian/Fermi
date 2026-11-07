// The refresh page and the gate that swaps it for the router (AD-24, R1).
import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { holdBusy } from '../../src/busy/busy.ts';
import UpdateGate from '../../src/update/UpdateGate.tsx';
import {
  resetUpdateCheckForTests,
  startUpdateChecks,
  updateState,
} from '../../src/update/updateCheck.ts';
import { stubSessionStorage } from './stub-storage.ts';

const SENTENCE = 'A new version of Fermi+ is ready. Refresh to keep using Fermi+.';
const OTHER_APP = `${__APP_ID__}-other`;

function renderGate() {
  return render(
    <UpdateGate>
      <div data-testid="router-child">the router</div>
    </UpdateGate>,
  );
}

// Starts the checks against a latest.json naming another app.
async function findNewApp() {
  await act(async () => {
    startUpdateChecks();
    await vi.advanceTimersByTimeAsync(0);
  });
}

beforeEach(() => {
  vi.useFakeTimers();
  resetUpdateCheckForTests();
  vi.stubGlobal(
    'fetch',
    vi.fn(async () => new Response(JSON.stringify({ version: 'v2', app: OTHER_APP }))),
  );
});

afterEach(() => {
  resetUpdateCheckForTests();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe('UpdateGate', () => {
  it('renders its children until a newer app is found', async () => {
    stubSessionStorage();
    renderGate();
    expect(screen.getByTestId('router-child')).toBeInTheDocument();
    expect(screen.queryByTestId('refresh-page')).not.toBeInTheDocument();
  });

  describe('when a newer app is found', () => {
    beforeEach(() => {
      stubSessionStorage();
    });

    it('replaces the children with the refresh page', async () => {
      renderGate();
      await findNewApp();
      expect(screen.queryByTestId('router-child')).not.toBeInTheDocument();
      expect(screen.getByTestId('refresh-page')).toBeInTheDocument();
    });

    it('shows exactly the sentence and a Refresh button', async () => {
      const { container } = renderGate();
      await findNewApp();
      expect(container.textContent).toBe(`${SENTENCE}Refresh`);
      expect(screen.getAllByRole('button')).toHaveLength(1);
      expect(screen.getByRole('button')).toHaveTextContent(/^Refresh$/);
      expect(container.querySelectorAll('a, input, select, textarea, [role="dialog"]')).toHaveLength(0);
      expect(container.querySelectorAll('button')).toHaveLength(1);
    });

    it('keeps the page when Escape is pressed', async () => {
      renderGate();
      await findNewApp();
      fireEvent.keyDown(document, { key: 'Escape' });
      fireEvent.keyDown(screen.getByTestId('refresh-page'), { key: 'Escape' });
      fireEvent.keyUp(document, { key: 'Escape' });
      expect(screen.getByTestId('refresh-page')).toBeInTheDocument();
      expect(screen.queryByTestId('router-child')).not.toBeInTheDocument();
    });

    it('stores the marker and reloads when Refresh is clicked', async () => {
      const storage = stubSessionStorage();
      const reload = vi.fn();
      vi.stubGlobal('location', { ...window.location, reload });
      renderGate();
      await findNewApp();
      fireEvent.click(screen.getByRole('button', { name: 'Refresh' }));
      expect(storage.setItem).toHaveBeenCalledWith('fermi:update:refreshed-from', __APP_ID__);
      expect(reload).toHaveBeenCalledTimes(1);
    });
  });

  describe('while busy work holds the registry', () => {
    it('keeps the children until release', async () => {
      stubSessionStorage();
      const release = holdBusy();
      renderGate();
      await findNewApp();
      expect(updateState()).toBe('waiting');
      expect(screen.getByTestId('router-child')).toBeInTheDocument();
      expect(screen.queryByTestId('refresh-page')).not.toBeInTheDocument();
      act(() => release());
      expect(screen.getByTestId('refresh-page')).toBeInTheDocument();
      expect(screen.queryByTestId('router-child')).not.toBeInTheDocument();
    });

    it('shows the page at 2 minutes if the work still holds', async () => {
      stubSessionStorage();
      const release = holdBusy();
      renderGate();
      await findNewApp();
      await act(() => vi.advanceTimersByTimeAsync(2 * 60_000 - 1));
      expect(screen.getByTestId('router-child')).toBeInTheDocument();
      await act(() => vi.advanceTimersByTimeAsync(1));
      expect(screen.getByTestId('refresh-page')).toBeInTheDocument();
      expect(screen.queryByTestId('router-child')).not.toBeInTheDocument();
      release();
    });
  });
});
