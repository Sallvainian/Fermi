// The reference component test: render, then query by data-testid.
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import App from '../../src/App.tsx';

describe('App', () => {
  it('shows the build id baked in at build time', () => {
    render(<App />);
    expect(screen.getByTestId('build-commit-id')).toHaveTextContent(__BUILD_ID__);
  });
});
