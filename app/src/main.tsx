import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter } from 'react-router';
import { RouterProvider } from 'react-router/dom';
import { startAuth } from './api/auth.ts';
import App from './App.tsx';
import './index.css';

// One route for now; every path renders the shell.
const router = createBrowserRouter([{ path: '*', element: <App /> }]);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <RouterProvider router={router} />
  </StrictMode>,
);

// Start the session listener at app start, so a sign-out in any tab wipes
// this tab's drafts even when no form is mounted.
startAuth();
