**Digest for Q13: how client auth, `firestore.rules`, `storage.rules` and Cloud Functions are tested @ 7808a91**

**Short answer:** At this commit the auth code, the rules files and the Cloud Functions have no tests. There is one tracked test file, and it covers only a callback-scheduling utility. `firebase.json` is not tracked, so the commit has no emulator configuration. No CI workflow runs a test step, a rules check or a functions build.

**1. Tracked test files (load-bearing)**
- `git ls-tree -r --name-only 7808a91 | grep -iE '(_test|\.test|\.spec)\.(dart|ts|js)$|^test/|integration_test/|test_driver/'` returns exactly one path: `test/unit/firestore_thread_safe_test.dart`.
- `test/unit/firestore_thread_safe_test.dart:1-4 @ 7808a91` imports only `flutter_test`, `flutter/material`, `fermi_plus/shared/utils/firestore_thread_safe.dart` and `fake_async`. It does not import Firebase, a fake Firestore or anything from auth.
- `test/unit/firestore_thread_safe_test.dart:7-307 (main, group 'FirestoreThreadSafe') @ 7808a91` holds 11 cases. They cover:
  - microtask ordering after build (`:13`)
  - priority order: critical, high, normal, low (`:42`)
  - deduplication within a 20ms window (`:83`)
  - metrics counters (`:132`)
  - `safeNotify` on a `ChangeNotifier` (`:159`)
  - high priority on error callbacks (`:185`)
  - dedup-entry cleanup (`:213`)
  - dedup rate (`:233`)
  - max queue depth (`:264`)
  - `resetMetrics` (`:285`)
  - The helper class `TestNotifier` is at `:311`.
- No `test/widgets/` or `integration_test/` directory exists, although `pubspec.yaml:193-194 @ 7808a91` has scripts that point at them.

**2. Rules tests (load-bearing: none)**
- `firestore.rules`, `storage.rules` and `firestore.indexes.json` are tracked at the repo root (`git ls-tree`).
- A `git grep` for `rules-unit-testing` across the tree (excluded paths left out) returns no matches. The rules files have no test harness.
- The only check on the rules is a review prompt. `.github/workflows/claude-code-review.yml:125-128 @ 7808a91` asks the AI reviewer to flag `firestore.rules`/`storage.rules` changes that "expose another user's data or reject a write the app makes". The reviewer reads the diff; nothing runs the rules.

**3. Cloud Functions tests (load-bearing: none)**
- `functions/` contains `src/*.ts` (16 files), `.eslintrc.js`, the tsconfigs, `package.json`, `package-lock.json` and `.gitignore`. It has no test files and no `test/` directory.
- `functions/package.json:3-13 (scripts) @ 7808a91` defines lint, build, build:watch, serve (`:7`, `firebase emulators:start --only functions`), shell, start, deploy, logs and migrate:roles. It has no `test` script.
- `functions/package.json:28 (devDependencies) @ 7808a91` declares `firebase-functions-test ^3.3.0`, which resolves to 3.4.1 at `functions/package-lock.json:4374-4376`. Nothing imports it: its only grep hits are those manifest lines.

**4. Emulator configuration (load-bearing: `firebase.json` is untracked)**
- `git ls-tree -r --name-only 7808a91 | grep -i firebase` lists `.firebaserc`, `.firebase/hosting.YnVpbGQvd2Vi.cache`, `lib/firebase_options.dart` and others, but no `firebase.json`.
- `.gitignore:114 @ 7808a91` ignores `**/firebase.json`. `:115`, `:118` and `:119` ignore `firebase-debug.log`, `emulator-debug.log` and `firebase-export-*`.
- So no emulator ports, rules paths or functions source settings are tracked. The `serve` script at `functions/package.json:7` depends on a `firebase.json` that does not exist at the commit.

**5. Emulator connections in client code**
- A `git grep` for `useFirestoreEmulator`, `useAuthEmulator`, `useFunctionsEmulator`, `useStorageEmulator`, `connect*Emulator` and `useEmulator` over the tree (excluded paths left out) returns no matches.
- `lib/shared/core/app_initializer.dart:138-139 @ 7808a91` has only a comment: "Skip emulator configuration for now / The Android emulator has issues with Google Play Services". The next lines (`:142-146`) turn on Firestore offline persistence for non-web builds.
- `lib/features/auth/data/services/desktop_oauth_handler_secure.dart:25-37 (SecureDesktopOAuthHandler._baseUrl) @ 7808a91`: when `kDebugMode` is set, it returns `FIREBASE_FUNCTIONS_EMULATOR_URL` (default `http://localhost:5001`) followed by `/$_projectId/$_region`. Release builds use `FIREBASE_FUNCTIONS_URL` or `https://$_region-$_projectId.cloudfunctions.net`.
  - Grepping `lib` for `SecureDesktopOAuthHandler` and `desktop_oauth_handler_secure` finds only the class's own declaration at `:12`, so nothing in `lib` references it.
  - `lib/features/auth/data/services/auth_service.dart:19-20 (AuthService) @ 7808a91` uses `DirectDesktopOAuthHandler` instead, whose comment says it "works without Firebase Functions".

**6. Testability seams in client code (none used by a test)**
- `lib/features/auth/data/services/auth_service.dart:27-29 (AuthService constructor) @ 7808a91` hard-wires `FirebaseAuth.instance` and `FirebaseFirestore.instance`, so nothing can be injected.
- These constructors accept an optional `FirebaseFirestore?` (and in some cases `FirebaseAuth?`):
  - `lib/features/student/data/services/student_service.dart:34 (StudentService) @ 7808a91`; its doc comment at `:20-21, :33` says this "supports … unit testing"
  - `lib/features/assignments/data/services/assignment_service.dart:20`
  - `lib/features/assignments/data/services/submission_service.dart:33`
  - `lib/features/classes/data/services/class_service.dart:20`
  - `lib/features/grades/data/services/grade_service.dart:17`
  - `lib/features/chat/data/services/scheduled_messages_service.dart:41` (Firestore and Auth)
  - `lib/features/behavior_points/presentation/providers/behavior_point_provider.dart:141` (Auth)
  - `lib/shared/services/firestore_service.dart:43`
- No test constructs any of these.

**7. Test tooling declared vs used**
- `pubspec.yaml:121-135 (dev_dependencies) @ 7808a91` declares `flutter_test`, `integration_test`, `flutter_lints`, `fake_cloud_firestore ^4.0.0`, `test ^1.25.15`, `fake_async ^1.3.3` and build tools. Only `flutter_test` and `fake_async` are imported anywhere: grepping `lib`, `test` and `functions/src` for `fake_cloud_firestore`, `FakeFirebaseFirestore`, `mockito`, `package:faker` and `MockFirebaseAuth` finds nothing.
- `pubspec.yaml:153-161 @ 7808a91`: `freezed`, `freezed_annotation`, `import_sorter`, `mockito ^5.5.0` and `faker ^2.2.0` are indented two spaces under the `flutter_launcher_icons:` block that starts at `:138`. YAML parses them as keys of that block, not as dev dependencies.
- Similarly, `flutter_gen_runner` (`:169`) sits under `dependency_overrides:`.
- `pubspec.yaml:182-222 (scripts) @ 7808a91` defines test, test:unit, test:widget (`:193`, `test/widgets/`), test:integration (`:194`, `integration_test`), test:coverage, pre-commit (`:217`, which ends in `flutter test`) and ci:test (`:221`).
- Root `package.json:9-13 @ 7808a91` declares `@seontechnologies/playwright-utils ^4.6.1` as a devDependency, with its install script disabled at `:22`. No Playwright spec or config file is tracked.

**8. CI**
- `.github/workflows/01_ci.yml:13-55 (job validate) @ 7808a91` runs `flutter pub get` (`:29`), `flutter analyze --no-fatal-infos` (`:32`), `dart format --set-exit-if-changed .` (`:35`) and the dead-code analyzer with `|| true` and `continue-on-error` (`:41-46`).
  - It has no `flutter test` step.
  - It checks out `ref: main`, not the PR head (`:19-20`).
  - It has no `functions/` lint or build and no rules step.
- A `git grep` of `.github/workflows` for `flutter test`, `npm test`, `emulators` and `integration_test` finds no `run:` step that runs tests.
  - The other workflows only run `flutter pub get` and builds: `02_deploy_web.yml:28,31`, `03_windows_release.yml`, `04_macos_release.yml` and `05_Ignore_desktop-release.yml`.
- `flutter test` appears only in AI-agent prompts and tool allow-lists:
  - `claude-code-review.yml:40` (comment), `:137` (prompt) and `:203` (`Bash(flutter test:*)` allowed)
  - `claude.yml:80` (prompt)
- `claude.yml:86-90 @ 7808a91` tells the agent: "This job has no device or emulator" and "`functions/` dependencies are not installed here, so a change there is unverified".

**What I looked for and did not find @ 7808a91**
- No `firebase.json` and no `rules-unit-testing` anywhere.
- No client emulator calls (`use*Emulator`, `connect*Emulator`).
- No test file under `functions/` and no `test` script there.
- No `integration_test/`, `test/widgets/` or `test_driver/`.
- No use of `fake_cloud_firestore`, `mockito`, `faker` or `firebase-functions-test`.
- No CI step that runs tests, lints or builds `functions/`, or checks the rules.

Budget: I read 13 of the 15 repository files. I did not read `02_deploy_web.yml` in full; its `run:` steps come from grep only. I also did not read the rules files themselves or `functions/src`, because the question is about tests and those files are not tests.