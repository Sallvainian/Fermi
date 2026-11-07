import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter } from 'react-router';
import { RouterProvider } from 'react-router/dom';
import { startAuth } from './api/auth.ts';
import App from './App.tsx';
import UpdateGate from './update/UpdateGate.tsx';
import { startUpdateChecks } from './update/updateCheck.ts';
import './index.css';

// One route for now; every path renders the shell.
const router = createBrowserRouter([{ path: '*', element: <App /> }]);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <UpdateGate>
      <RouterProvider router={router} />
    </UpdateGate>
  </StrictMode>,
);

// Start the session listener at app start, so a sign-out in any tab wipes
// this tab's drafts even when no form is mounted.
startAuth();

// Start the update check at app start: a tab left open across a deploy learns
// of it and shows the refresh page (AD-24).
startUpdateChecks();
