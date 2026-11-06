Digest for my area (top-level files, `lib/main.dart`, `lib/firebase_options.dart`, `test/`, and platform Firebase config) at 7808a91. Everything was searched through git at the commit, with the excluded paths left out.

Two findings shape several answers:
- **`firebase.json` is not in the commit.** `git ls-tree` at 7808a91 has no `firebase.json`, and `.gitignore:114 @ 7808a91` contains `**/firebase.json`. There is no emulator configuration at the commit (bears on Q13 and on hosting/functions config).
- **`firestore.rules` never reads custom claims.** A grep for `token.role`, `token.admin`, `token.teacher`, `token.student` and `claims` in `firestore.rules @ 7808a91` finds nothing. Roles come from the `role` field of the Firestore document `users/{uid}`, combined with a check on the email domain in the token (bears on Q1, Q2, Q3).

**Q1 (Firebase start and sign-in)**
- `lib/main.dart:30 (main) @ 7808a91` — runs inside `runZonedGuarded`, loads `.env` on non-web builds only (four fallback paths, lines 99–161; a missing file logs "Google Sign-In will not work"), then calls `runApp(InitializationWrapper)`.
- `lib/main.dart:341 (_InitializationWrapperState._initializeApp) @ 7808a91` — calls `AppInitializer.initialize()`. There is a fast path if `AppInitializer.isFirebaseInitialized` (line 308), and a `duplicate-app` error is tolerated (line 361).
- `lib/main.dart:27 (isFirebaseInitialized) @ 7808a91` — a public getter that forwards to `AppInitializer.isFirebaseInitialized`.
- `lib/main.dart:202-244 (_TeacherDashboardAppState.build) @ 7808a91` — watches `AuthProvider` and shows a loading app while `AuthStatus.uninitialized` or `authenticating`. It then builds the router once with `AppRouter.createRouter(authProvider)`, inside `MultiProvider(AppProviders.getProviders())` and wrapped in `WebNotificationHandler`.
- `lib/firebase_options.dart:18 (DefaultFirebaseOptions.currentPlatform) @ 7808a91` — returns options for web, android, ios, macos, windows and linux. All use project `teacher-dashboard-flutterfire`, with a `databaseURL` for Realtime Database and a `storageBucket`.
  - The `ios` options (line 62) set `iosClientId 218352465432-g06upomj…` and `iosBundleId com.academic-tools.fermi`.
  - The `macos` options (line 90) reuse the iOS appId `…ios:33fe51…`.
  - The `windows` options (line 77) and `linux` options (line 104) use the web appId `…web:05826e…`.
- **Platform config mismatches with `firebase_options.dart`:**
  - `ios/Runner/GoogleService-Info.plist:5 (CLIENT_ID) @ 7808a91` has `…-5lt4mte28…`, not the `g06upomj` id in `firebase_options.dart`. The URL scheme matches the plist: `ios/Runner/Info.plist:110-115 (CFBundleURLTypes) @ 7808a91` is the reversed client id `com.googleusercontent.apps.218352465432-5lt4mte28…`.
  - `macos/Runner/GoogleService-Info.plist:17,34 (BUNDLE_ID, GOOGLE_APP_ID) @ 7808a91` has `com.academic-tools.teacherDashboardFlutter` and `…ios:89f7eb…`, not the values in `firebase_options.dart`.
  - `macos/Runner/Info.plist @ 7808a91` has no `CFBundleURLTypes` (grep found nothing).
  - `android/app/google-services.json:13 (package_name) @ 7808a91` is `com.teacherdashboard.teacher_dashboard_flutter_firebase`, matching `android/app/build.gradle.kts:27 (applicationId) @ 7808a91`. Lines 6–7 apply the google-services and crashlytics plugins.
- `ios/Runner/Runner.entitlements:7 (com.apple.developer.applesignin) @ 7808a91` — Apple sign-in entitlement. Line 13 has the placeholder associated domain `applinks:yourdomain.com`.
- `macos/Runner/DebugProfile.entitlements:15` and `macos/Runner/Release.entitlements:23 (keychain-access-groups) @ 7808a91` — keychain groups for both the `teacher-dashboard-flutter` and `fermi` bundle ids. Both files have `network.server` set (bears on a loopback OAuth server).
- `pubspec.yaml:35-53 (dependencies) @ 7808a91` — `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_database`, `firebase_messaging`, `cloud_functions`, `google_sign_in ^7.0.5`, plus `oauth2`, `crypto` and `url_launcher` for Windows desktop OAuth. Line 236 bundles `.env` as an asset.
- **Windows plugins:** `windows/flutter/generated_plugins.cmake:5 (FLUTTER_PLUGIN_LIST) @ 7808a91` registers only `cloud_firestore`, `firebase_auth`, `firebase_core` and `firebase_storage`. There is no `firebase_database`, `firebase_messaging` or `cloud_functions` on Windows.
- The `lib/shared/core/*` and `lib/features/auth` files are outside my area.

**Q2 (role claims on the server)**
- `firestore.rules:43 (getUserRole) @ 7808a91` — reads `users/{uid}.role` with `get()`. Rules depend on that document field, not on custom claims (see the no-claims finding above).
- `firestore.rules:92-95 (match /users/{userId}, allow create) @ 7808a91` — a user may create their own doc only with `uid == userId` and `hasValidSchoolDomain()`. Field-level checks on `role` at create: none.
- `firestore.rules:97 @ 7808a91` — `update` is allowed for the owner, admin or teacher, with no check on which fields change. A user can therefore update the `role` field on their own doc.
- The server and client files named in the question are outside my area.

**Q3 (`firestore.rules`)**
- **Helpers:**
  - `isAuthenticated` (line 7) and `isOwner` (line 12).
  - Domain checks on `request.auth.token.email`: `hasTeacherDomain` (line 22, `@roselleschools.org`), `hasStudentDomain` (line 29, `@rosellestudent.org`), `hasAdminDomain` (line 36, `@fermi-plus.com`) and `hasValidSchoolDomain` (line 17).
  - Role checks: `isTheTeacher` (line 49) requires role `teacher` and (teacher domain or `isAdmin`). `isStudent` (line 58) requires role `student` and (student domain or `isAdmin`). `isAdmin` (line 67) requires role `admin` and the admin domain.
  - `isEnrolledInClass` (line 76) checks `uid in classes/{id}.studentIds`.
  - All of these are in `firestore.rules @ 7808a91`.
- **Per-path rules (`firestore.rules @ 7808a91`):**
  - `users` (line 82): read by self, teacher or admin, or by a student with a school domain. Create, update and delete as covered in Q2.
  - `public_usernames` (line 104): `read: if true`. Create requires `data.uid == auth.uid` and `users/{uid}.username == username`.
  - `classes` (line 117): read by any authenticated user (line 127). A student may self-enroll only if `affectedKeys().hasOnly(['studentIds','updatedAt'])` and they are not already in `studentIds` (lines 140–143). Create, update and delete are for the teacher.
  - `classes/studentPoints` (line 150), its `history` (line 163) and `behaviors` (line 181): writes are teacher-only. A student may read their own points and history; `behaviors` is readable when enrolled. The catch-all `classes/{document=**}` (line 195) gives read to teacher or enrolled, write to teacher.
  - `conversations` (line 203): participant checks. `messages` (line 220): create needs `authorId` or `senderId == uid` and membership; update and delete are `false`. `typing/{userId}` (line 236): only the owner may write.
  - `chatRooms` (line 250): any authenticated user may read the room. Create, update and delete require `uid in participantIds`. `messages` (line 264): create requires `senderId` and membership. Delete is allowed for any authenticated user (line 273).
  - `chat_rooms` (legacy, line 278): `participantIds.hasAll(...)` prevents removing other participants (line 293).
  - `assignments` (line 310), `grades` (line 328) and `submissions` (line 361): ownership via `teacherId`, `studentId` and `classId`. A student may update a submission only while `submittedAt == null` and `studentId` is unchanged (lines 373–377).
  - Collection-group rules: `{path=**}/grades` (line 344) is teacher-only. `{path=**}/history` (line 349) is teacher, admin, or the owner of the class named in `resource.data.classId`.
  - `discussion_boards` is matched twice (lines 391 and 506; Firestore ORs the two). Line 393 lets any authenticated user create a board, while line 508 requires a teacher.
  - `threads` (lines 400 and 514), `comments` (lines 418 and 533) and `replies` (lines 429 and 545): authors may edit. Anyone may update a thread's counters only if `affectedKeys().hasOnly(['likeCount'])` or `['replyCount']` with a change of ±1 (lines 407–413).
  - The `replies` likeCount condition at lines 436–438 and 553–555 has `&&`/`||` precedence such that `likeCount == old - 1` alone passes.
  - `likes` (lines 443, 458, 560, 575): document id must equal uid and `data.userId == uid`; update is `false`.
  - `games/scores` (line 474).
  - `scheduled_messages` (line 492): checks `message.senderId`.
  - `calendar_events` (line 591): `createdBy` and `participantIds`.
  - `students` (line 604): checks `studentId` or `userId`.
  - `teachers` (line 621).
  - `calls` (line 627): status transition list at line 648, plus a `candidates` subcollection.
  - `activities` (line 663).
  - `notifications` (line 685): checks `userId`.
  - `fcm_tokens/{userId}` (line 706): owner only.
  - `bug_reports` (line 711): create requires `userId == uid`; update and delete are `false`.
  - `jeopardy_games` (line 725): `isPublic` or `teacherId`; `teacherId` cannot be changed (line 744).
  - `jeopardy_sessions` (line 752): `teacherId` and `participantIds`.
  - `presence/{userId}` (line 775): owner writes.
  - Default deny (line 793).
- **Placeholders:** several conditions are `&& true` where comments mention email verification (for example lines 256, 370, 497, 641, 718). The header comment at line 800 claims "Email verification required".
- **No rule for** `jeopardy_questions`, `oauth_pkce_challenges` or `_rate_limits` (grep in `firestore.rules @ 7808a91` found nothing). They fall to the default deny at line 793.

**Q4 (`storage.rules`)**
- `storage.rules:5 (isAuthenticated) @ 7808a91` is the only helper.
- `/chat_images/{chatRoomId}/{fileName}` (line 10) and `/chat_videos/...` (line 16): any authenticated user may read and write. There is no membership, size or content-type check.
- `/users/{userId}/profile/{fileName}` (line 22) and `/users/{userId}/{allPaths=**}` (line 28): any authenticated user may read; only the owner may write.
- `/public/**` (line 34): public read, no write.
- Default deny at line 40.
- The client paths in `lib/` are outside my area.

**Q5–Q8 (indexes in `firestore.indexes.json @ 7808a91`)**
- **Q5:**
  - `notifications`: collection group at lines 874 (`userId`, `createdAt`) and 892 (`+isRead`). Collection scope at lines 914 (`read`, `userId`, `createdAt`), 936 and 954.
  - `presence`: lines 976 (`online`, `lastSeen`) and 994 (`online`, `updatedAt`).
  - No index for `users`, `public_usernames`, `fcm_tokens`, `scheduled_messages` or `bug_reports`.
- **Q6:**
  - `classes`: lines 308–406 (six indexes on `enrollmentCode`/`isActive`, `studentIds` CONTAINS, `teacherId`).
  - `students`: collection group at line 1012 (`classIds` CONTAINS, `name`); collection scope at lines 1030, 1048 (`gradeLevel`) and 1066 (`isActive`).
  - `assignments`: collection group at lines 40 and 58; collection scope at lines 76–174, including `isPublished`/`publishAt` and `status`.
  - `grades`: collection group at lines 548 (`classId`, `gradedAt`) and 566 (`studentId`, `classId`, `assignmentId`); collection scope at lines 588–722.
  - `calendar_events`: lines 192 (`createdBy`, `isActive`, `startTime`), 214 and 236 (`participantIds` CONTAINS).
  - No index for `submissions`.
- **Q7:**
  - `chatRooms`: line 290 (`participantIds` CONTAINS, `lastMessageTime`).
  - `chat_rooms`: lines 254 and 272.
  - `messages`: collection group at lines 802 and 820, collection scope at 838 and 856 (`conversationId` or `senderId`, then `timestamp`).
  - `discussion_boards`: lines 424 and 442 (`isPinned`).
  - `threads`: collection group at line 1084; collection scope at 1102 and 1120.
  - No index for `conversations`, `typing`, `replies` or `likes`.
- **Q8:**
  - `history` (all collection group): lines 1138 (`classId`, `isUndone`, `awardedAt`), 1160 (`+studentId`), 1186 (`+gender`) and 1212 (`+type`).
  - `behaviors`: line 1238 (`name`).
  - `activities`: lines 4 (`classId`, `timestamp`) and 22 (`teacherId`, `timestamp`).
  - `jeopardy_games`: lines 744, 762 and 784.
  - No index for `studentPoints`, `jeopardy_sessions`, `jeopardy_questions`, `oauth_pkce_challenges` or `_rate_limits`.
- **Indexes for collections outside the list:** `files` (lines 460 and 482) and `games` (lines 504 and 526). `fieldOverrides` at line 1252 sets a TTL on `calls.expireAt`.
- Model and serializer files in `lib/` and `functions/` are outside my area.

**Q9–Q10 (Cloud Functions)**
- Nothing in my area. `package.json:1 @ 7808a91` (root) is a Cloudflare/wrangler manifest with no functions scripts. `.firebaserc @ 7808a91` sets the default project `teacher-dashboard-flutterfire` and a hosting target only.

**Q11 (push notifications)**
- **iOS:** `ios/Runner/Info.plist:39-41 (UIBackgroundModes) @ 7808a91` includes `remote-notification`, `processing` and `fetch`. `ios/Runner/Runner.entitlements:5 (aps-environment) @ 7808a91` is `development`, and line 27 enables time-sensitive notifications.
- **Web:** `web/index.html:67 (serviceWorker cleanup script) @ 7808a91` unregisters every service worker and clears caches. The commit has no `firebase-messaging-sw.js` (`git ls-tree` grep found nothing), and `web/manifest.json` has no `gcm_sender_id`.
- **Android:** `android/app/src/main/AndroidManifest.xml @ 7808a91` has no `POST_NOTIFICATIONS` permission, no FCM default-channel meta-data and no messaging service (grep found nothing).
- **macOS:** both `macos/Runner/*.entitlements` lack `aps-environment`.
- `pubspec.yaml:42` (`firebase_messaging ^16.0.0`), `:99` (`flutter_local_notifications ^19.4.1`) and `:165` (timezone override) `@ 7808a91`.
- **Windows:** `windows/flutter/generated_plugins.cmake:16 (FLUTTER_FFI_PLUGIN_LIST) @ 7808a91` includes `flutter_local_notifications_windows` and no `firebase_messaging`.
- The Dart services are outside my area.

**Q12 (client callables)**
- Only the dependency is in my area: `pubspec.yaml:43 (cloud_functions) @ 7808a91`. Windows does not register `cloud_functions` (`generated_plugins.cmake:5`).

**Q13 (testing)**
- `test/unit/firestore_thread_safe_test.dart:7 (group FirestoreThreadSafe) @ 7808a91` is the only tracked test file. It tests `lib/shared/utils/firestore_thread_safe.dart` (priority, dedup and metrics; tests at lines 13–285) with `fake_async`.
- No tests cover auth, `firestore.rules`, `storage.rules` or functions.
- `git ls-tree` at 7808a91 shows no `integration_test/` directory, even though the script at `pubspec.yaml:194` points to it. There are no `test/widgets/` (script at line 193) and no `*test*`/`*spec*` files under `functions/`.
- `git log --diff-filter=D` found no deleted test files.
- `pubspec.yaml:121-135 (dev_dependencies) @ 7808a91` — `flutter_test`, `integration_test`, `fake_cloud_firestore ^4.0.0`, `test`, `fake_async`. There is no `firebase_auth_mocks` and no rules-unit-testing package.
- `pubspec.yaml:153-161 @ 7808a91` — `freezed`, `mockito` and `faker` sit indented under the `flutter_launcher_icons:` map (line 138), not under `dev_dependencies`.
- `pubspec.yaml:191-221 (scripts) @ 7808a91` — test scripts, including `ci:test` with coverage.
- `.github/workflows/01_ci.yml:32 @ 7808a91` runs `flutter analyze --no-fatal-infos`. A grep of `01_ci.yml` and `02_deploy_web.yml` for `flutter test`, `firebase` and `emulator` found no test run, emulator or rules test.
- `.github/workflows/claude-code-review.yml:40 @ 7808a91` mentions `flutter test` in a comment.
- There is no emulator config, because `firebase.json` is not in the commit.

**Searched, nothing found (all at 7808a91):**
- `firebase.json` and `firebase-messaging-sw.js` in `git ls-tree -r`
- `token.role` and `claims` in `firestore.rules`
- `jeopardy_questions`, `oauth_pkce_challenges`, `_rate_limits` in `firestore.rules` and `firestore.indexes.json`
- `POST_NOTIFICATIONS` and the messaging service in `AndroidManifest.xml`
- `CFBundleURLTypes` in `macos/Runner/Info.plist`
- OAuth, loopback and redirect strings in `windows/`
- `flutter test` and emulator steps in the CI workflows