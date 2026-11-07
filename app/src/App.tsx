export default function App() {
  return (
    <main className="mx-auto max-w-xl p-8 pt-[max(2rem,env(safe-area-inset-top))] pl-[max(2rem,env(safe-area-inset-left))] pr-[max(2rem,env(safe-area-inset-right))]">
      <h1 className="text-3xl font-semibold">Fermi+</h1>
      <p className="mt-2 text-sm text-gray-600">
        Build <span data-testid="build-commit-id">{__BUILD_ID__}</span>
      </p>
    </main>
  );
}
