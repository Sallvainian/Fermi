# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: Flutter app source (widgets, services, routing).
- `assets/`: Images, icons, and static resources.
- `android/`, `ios/`, `macos/`, `windows/`, `web/`: Platform targets.
- `functions/`: Firebase Cloud Functions (TypeScript → `lib/` compiled JS, `src/` sources).
- `src/`: Cloudflare Worker (`index.js`) serving `build/web` assets.
- `docs/`, `scripts/`: Developer docs and build/release helpers.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`
- Run app: `flutter run -d chrome` (web) or `flutter run -d <device>`
- Analyze/lint: `flutter analyze`
- Format: `dart format .` (check only: `dart format . --set-exit-if-changed`)
- Unit/widget tests: `flutter test` (coverage: `flutter test --coverage`)
- Integration tests: `flutter test integration_test`
- Web build: `flutter build web --release` (output in `build/web`)
- Cloudflare dev: `npx wrangler dev` (uses `wrangler.toml` and `src/index.js`)
- Firebase Functions: `cd functions && npm i && npm run build && npm run serve`

## Coding Style & Naming Conventions
- Indentation: 2 spaces (see `.editorconfig`).
- Dart: follow `flutter_lints` (see `analysis_options.yaml`). Files `snake_case.dart`; classes/enums `PascalCase`; members `lowerCamelCase`.
- JS/TS (functions): ESLint (Google style); prefer TypeScript in `functions/src`.

## Testing Guidelines
- Frameworks: `flutter_test`, `integration_test` for app; `firebase-functions-test` available for Functions.
- Locations: place unit/widget tests under `test/` with `_test.dart` suffix; integration tests under `integration_test/`.
- Run: `flutter test`, `flutter test integration_test`. Generate coverage with `flutter test --coverage`.

## Commit & Pull Request Guidelines
- Commits: follow Conventional Commits used in this repo (e.g., `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`).
- PRs: include clear description, linked issues, test evidence (or steps), and UI screenshots when applicable. Ensure `flutter analyze` passes and tests run.

## Security & Configuration Tips
- Do not commit secrets. Use `.env` (see `.env.example`).
- Functions require Node 22 (see `functions/package.json`).
- For web deploys, Cloudflare serves `build/web` via the Worker (`src/index.js`); run the web build before publishing.

## Agent Tools
- See `CLAUDE.md` and `.mcp.json` for Task Master AI setup. Common commands: `task-master next`, `task-master show <id>`, `task-master set-status --id=<id> --status=done`.
