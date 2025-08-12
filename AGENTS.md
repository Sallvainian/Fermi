# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: Flutter app code.
  - `features/`: Feature-first modules (e.g., `auth/`, `assignments/`, `teacher/`).
  - `shared/`: Cross-cutting code (`models/`, `providers/`, `repositories/`, `routing/`, `screens/`, `services/`, `theme/`, `utils/`, `widgets/`).
  - `config/`, `main.dart`, `firebase_options.dart`.
- `test/`: Dart unit/widget tests mirroring `lib/` structure.
- `assets/`: Images and static assets.
- `functions/`: Firebase Cloud Functions (TypeScript in `src/`, compiled to `lib/`).
- Platform targets: `web/`, `android/`, `ios/`, `windows/`.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`
- Run web/PWA: `flutter run -d chrome`
- Run on device/emulator: `flutter run`
- Analyze/lint: `flutter analyze`
- Format: `dart format .`
- Run tests: `flutter test` (optionally `--coverage`)
- Build web: `flutter build web`
- Cloud Functions (Node 22):
  - Install: `npm --prefix functions install`
  - Lint: `npm --prefix functions run lint`
  - Build: `npm --prefix functions run build`
  - Emulate: `npm --prefix functions run serve`
  - Deploy: `npm --prefix functions run deploy`

## Coding Style & Naming Conventions
- Dart: 2-space indentation; prefer trailing commas for stable formatting.
- Files: `snake_case.dart`; classes/types: `UpperCamelCase`; methods/vars: `lowerCamelCase`.
- Tests/widgets/screens mirror `lib/` paths; example: `lib/features/auth/...` → `test/features/auth/...`.
- Follow `analysis_options.yaml`; keep imports ordered and avoid unused code (`flutter analyze`).

## Testing Guidelines
- Frameworks: `flutter_test` and `test`.
- Naming: `*_test.dart`; group tests by feature.
- Run: `flutter test`; generate coverage with `flutter test --coverage` (outputs `coverage/lcov.info`).
- Prefer fast unit tests; add widget tests for navigation and auth flows (see `test/app_router_redirect_test.dart`).

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:` with optional scope (e.g., `feat(auth): ...`).
- Keep messages imperative and focused; reference issues (`#123`) when relevant.
- PRs: include a clear description, linked issues, screenshots/GIFs for UI changes, and test steps. Ensure `flutter analyze` and `flutter test` pass and CI is green.

## Security & Configuration Tips
- Do not hardcode secrets; use `.env`/`.envs/` and platform configs. Avoid committing private keys.
- `firebase_options.dart` is generated; re-run FlutterFire config when Firebase settings change.
- Validate `firestore.rules` and `storage.rules` with emulators before deploying.

