import { refresh } from './updateCheck.ts';

// What an open Fermi shows once a newer app is live (AD-24, R1). Full screen,
// no close control, and nothing but the sentence and one button. It needs no
// session, so it works signed out too.
export default function RefreshPage() {
  return (
    <main
      data-testid="refresh-page"
      className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-6 bg-white p-8 pt-[max(2rem,env(safe-area-inset-top))] pb-[max(2rem,env(safe-area-inset-bottom))] pl-[max(2rem,env(safe-area-inset-left))] pr-[max(2rem,env(safe-area-inset-right))] text-center"
    >
      <p className="max-w-xl text-lg">
        A new version of Fermi+ is ready. Refresh to keep using Fermi+.
      </p>
      <button
        type="button"
        data-testid="refresh-button"
        onClick={refresh}
        className="rounded-md bg-gray-900 px-6 py-3 text-base font-medium text-white"
      >
        Refresh
      </button>
    </main>
  );
}
