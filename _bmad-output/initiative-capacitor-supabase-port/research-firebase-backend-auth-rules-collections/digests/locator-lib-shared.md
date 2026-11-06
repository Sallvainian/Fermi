I searched `lib/shared/` at 7808a91 using `git grep` and `git ls-tree` with the excluded paths left out. There are 65 files in the area. Questions 3, 4 (rules side), 9, 10 and 13 are mostly outside it. A few call sites outside the area are cited only where they resolve a variable collection name or show who uses a shared helper.

## Q1: Firebase startup and sign-in
- `lib/shared/core/app_initializer.dart:29 (AppInitializer.initialize) @ 7808a91` runs in this order: Firebase first, then the service locator, then the deferred services in a post-frame callback (line 40). It is called from `lib/main.dart:341 (_InitializationWrapperState) @ 7808a91`.
- `lib/shared/core/app_initializer.dart:101-105 (_initializeFirebase) @ 7808a91` calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` only when `Firebase.apps.isEmpty`. It ignores `duplicate-app` errors (line 119). `isFirebaseInitialized` (line 18) also checks `Firebase.apps`, to survive hot restart.
- Line 136 has a comment saying auth persistence is handled in the AuthService constructor. Line 138 says emulator configuration is skipped ("Skip emulator configuration for now").
- `lib/shared/core/app_initializer.dart:142-147 @ 7808a91` turns on Firestore offline persistence with `CACHE_SIZE_UNLIMITED`, on non-web platforms only.
- `lib/shared/core/app_initializer.dart:150-165 @ 7808a91` covers Realtime Database: it only gets `FirebaseDatabase.instance` and calls `setPersistenceEnabled(true)` on non-web. It sets no refs or listeners.
- `lib/shared/core/app_initializer.dart:54-74 (_initializeDeferredServices) @ 7808a91`:
  - `NotificationService().initialize()` always runs. `requestPermissions()` runs only on non-web (lines 195-202).
  - `FirebaseMessagingService().initialize()` runs only on Android and iOS (lines 77-89 and 217-246). Line 228 returns early on web ("Foreground-only on web").
- `lib/shared/core/service_locator.dart:55 (setupServiceLocator) @ 7808a91` registers lazy singletons with GetIt:
  - `FirebaseAuth`, `FirebaseFirestore` and `FirebaseStorage` (lines 84-90).
  - `AuthService` (line 101).
  - Factories for `AssignmentService` and `SubmissionService` (lines 108-114).
  - It skips everything if Firebase is not initialized (line 68) or if it already ran (line 59). The getters are in the extension at line 138.
- Auth state for the rest of the app:
  - `lib/shared/core/app_providers.dart:28 (AppProviders) @ 7808a91` creates `ChangeNotifierProvider(AuthProvider())`.
  - `lib/shared/routing/app_router.dart:67-135 (AppRouter.createRouter) @ 7808a91` uses `refreshListenable: authProvider` and redirects on `AuthStatus`:
    - uninitialized or authenticating: no redirect.
    - error: `/auth/login`.
    - not signed in: `/auth/role-selection`.
    - `needsPasswordReset`: `/auth/teacher-setup/password`.
    - signed in but on an auth route: `/dashboard`.
    - a non-student on `/student*` (lines 126-131): `/dashboard`.
  - The dashboard route picks a dashboard from `userModel.role` (lines 197-252). Line 242 means a user with no role is treated as a student.
  - `lib/shared/routing/auth_redirect.dart:21 (computeAuthRedirect) @ 7808a91` holds similar `/teacher` and `/student` guard logic. Nothing calls it: the only hit for `computeAuthRedirect` in `lib` and `test` is its definition.
- Reading the user's role on the client:
  - Firestore path: `lib/shared/models/user_model.dart:146 (UserModel.fromFirestore) @ 7808a91` parses `data['role']` with `_roleFromString` (line 251), which maps teacher, student and admin and returns null for anything else.
  - Custom-claims path: `lib/shared/utils/set_user_role_claims.dart:41 (UserRoleClaims.hasRole) @ 7808a91` and line 58 (`getCurrentUserRole`) read `getIdTokenResult().claims['role']`.
  - Two different `UserRole` enums exist: `lib/shared/models/user_model.dart:7 @ 7808a91` and `lib/shared/models/user_role.dart:2 @ 7808a91`. The second has a `fromString` that falls back to student (line 44).
- I found no sign-in flow code in `lib/shared`. Those flows live in `lib/features/auth`, which is outside my area.

## Q2: Client side of role claims
- `lib/shared/utils/set_user_role_claims.dart:14-37 (UserRoleClaims.setRoleClaim) @ 7808a91` calls `httpsCallable('setRoleClaim')` with `{'uid', 'role'}` on the default `FirebaseFunctions.instance` (no region set, line 7). If the uid is the current user, it then forces `getIdToken(true)`.
- `lib/shared/utils/run_migration.dart:13 (runUserRoleMigration) @ 7808a91` calls `FirebaseFunctions.instanceFor(region: 'us-east4').httpsCallable('migrateAllUserRoles')` with no arguments (lines 47-50). It shows `success`, `message`, `totalUsers`, `successCount`, `errorCount` and `errors` from the result.
- Neither one is called anywhere. The only references to `UserRoleClaims` or `runUserRoleMigration` in `lib` and `test` are their own definitions and example comments.

## Q4: Storage paths in this area
- `lib/shared/screens/settings_screen.dart:1029-1041 (_SettingsScreenState) @ 7808a91` uploads with `putFile` to `users/{uid}/profile/avatar.jpg`, then calls `getDownloadURL` and `authProvider.updateProfilePicture(url)`.
- `lib/shared/screens/settings_screen.dart:1078-1086 @ 7808a91` deletes the same path. The comment at line 1092 notes that photoURL is not cleared afterwards.
- `lib/shared/core/service_locator.dart:88 @ 7808a91` registers `FirebaseStorage`.

## Q5: users, public_usernames, presence, fcm_tokens, notifications, scheduled_messages, bug_reports
- **users**
  - Model: `lib/shared/models/user_model.dart:100 (UserModel.fromFirestore) @ 7808a91` and line 155 (`toFirestore`). Fields: uid, email, displayName, firstName, lastName, photoURL (it also reads photoUrl), username, parentEmail, teacherId, studentId, gradeLevel, enrolledClassIds, createdAt, lastActive, role, needsPasswordReset, realEmail. `createdAt` and `lastActive` are parsed only when they are already `DateTime` (lines 140-145).
  - Reads: `lib/shared/utils/check_auth_info.dart:16-17 and 29-30 (CheckAuthInfo.analyzeAuthSituation) @ 7808a91` reads `users/{currentUid}` and `users/zxD9cZale9OHvFERivxx7WAixOB3` (a hardcoded old uid). Nothing calls it.
  - `lib/shared/utils/firestore_thread_safe.dart:57 @ 7808a91` mentions `users` only inside a doc comment.
  - `UserModel.fromFirestore` is used outside the area at `lib/features/auth/providers/auth_provider.dart:408`, `lib/features/admin/data/services/user_management_service.dart:62`, `lib/features/chat/presentation/screens/group_creation_screen.dart:55`, `lib/features/discussions/presentation/providers/discussion_provider.dart:252` and `lib/features/teacher/presentation/screens/manage_student_accounts_screen.dart:403` (all @ 7808a91).
- **bug_reports**
  - `lib/shared/screens/contact_support_screen.dart:331-333 (_ContactSupportScreenState) @ 7808a91` does `.add(reportData)`.
  - The shape is built inline at lines 308-328: category, priority, subject, description, userId, userEmail, userName, userRole, createdAt (server timestamp), status `'new'`, platform, appVersion `'1.0.0'`, and deviceInfo {platform, screenSize, pixelRatio}. There is no model class for it.
- **Variable collection names**
  - `lib/shared/services/firestore_service.dart:52 (FirestoreService.collection) @ 7808a91` calls `_firestore.collection(collectionPath)`. The generic CRUD methods use `collection.doc(id)` at lines 83, 101, 139, 155, 242 and 261, and take caller-supplied `fromFirestore`/`toFirestore` (lines 31, 34).
  - `lib/shared/services/firestore_repository.dart:145 (FirestoreRepository.getCollectionReference) @ 7808a91` calls `_firestore.collection(path)`. Batch `collection.doc` calls are at lines 76 and 91.
  - What callers pass for `collectionPath`:
    - `'assignments'`: `lib/features/assignments/data/services/assignment_service.dart:23 @ 7808a91`
    - `'classes'`: `lib/features/classes/data/services/class_service.dart:22 @ 7808a91`
    - `'grades'`: `lib/features/grades/data/services/grade_service.dart:19 @ 7808a91`
  - What callers pass for `path`:
    - `'grades'`: `lib/features/assignments/data/services/assignment_service.dart:83 @ 7808a91`
    - `'archived_grades'`: `lib/features/grades/data/services/grade_service.dart:279-280 @ 7808a91`
  - I found no `collectionName` or `collection(this.collectionName)` in `lib/shared`.
- No hits in `lib/shared` for `public_usernames`, `presence`, `fcm_tokens`, `notifications` or `scheduled_messages`.

## Q6: classes, students, assignments, submissions, grades, calendar_events
- **classes**: `lib/shared/utils/fix_teacher_id.dart:24-40 (FixTeacherId.updateClassesTeacherId) @ 7808a91` queries `classes` where `teacherId ==` the hardcoded old uid. It batch-updates `teacherId` to the current uid and sets `updatedAt` to a server timestamp. Nothing calls it.
- **assignments, classes, grades**: reached only through the generic `FirestoreService` and `FirestoreRepository` (see Q5).
- `lib/shared/utils/firestore_batch_query.dart:16 (FirestoreBatchQuery.batchWhereIn) @ 7808a91` and line 52 (the FieldPath variant) split `whereIn` queries into chunks of 30 (line 6). Callers: `lib/features/grades/presentation/providers/grade_provider.dart:72,183` and `lib/features/student/presentation/providers/student_provider.dart:104,164` (@ 7808a91).
- No `collectionGroup` hits in `lib/shared`.

## Q7 and Q8
- No collection or doc hits in `lib/shared` for any of the Q7 or Q8 collections.
- `lib/shared/utils/firestore_thread_safe.dart:16 (FirestoreThreadSafe) @ 7808a91` is a listener and notify wrapper with no collection names. It is used by the behavior_points, chat, classes and discussions providers (for example `lib/features/chat/data/controllers/firestore_chat_controller.dart:127 @ 7808a91`) and is tested in `test/unit/firestore_thread_safe_test.dart:7 @ 7808a91`.

## Q11: notifications in this area
- `lib/shared/core/app_initializer.dart:195-246 @ 7808a91`: see Q1.
- `lib/shared/widgets/web_notification_handler.dart:6 (WebNotificationHandler) @ 7808a91` is web only. It sets `WebInAppNotificationService.onNotificationReceived` and shows each notification as a SnackBar (lines 27-60). It wraps the app at `lib/main.dart:249 @ 7808a91`.
- The notification toggles in `lib/shared/screens/settings_screen.dart:29-39 and 1182 (AdvancedNotificationSettingsSheet) @ 7808a91` are widget state. A grep for `SharedPreferences` in that file found nothing.
- No `FirebaseMessaging` or `FlutterLocalNotifications` symbols appear directly in `lib/shared`.

## Q12: Callables in this area
- `lib/shared/utils/set_user_role_claims.dart:20 @ 7808a91`: `setRoleClaim` with `{uid, role}`, default region.
- `lib/shared/utils/run_migration.dart:48 @ 7808a91`: `migrateAllUserRoles` with no arguments, region `us-east4`.

## Q13
- The only test I found for this area is `test/unit/firestore_thread_safe_test.dart @ 7808a91`.
- `lib/shared/core/app_initializer.dart:138 @ 7808a91` contains no `useEmulator` calls; the comment there says emulator configuration is skipped.

## Searched, nothing found (`lib/shared` @ 7808a91)
- `collectionGroup(`
- `FirebaseDatabase.` beyond `app_initializer.dart:151` (no `.ref` on the database)
- `FirebaseMessaging` used directly
- `FlutterLocalNotifications`
- `authStateChanges`, `idTokenChanges`, `userChanges`
- `useEmulator`
- `collectionName`
- `fromMap`, `toMap`
- The Q5 names other than `users` and `bug_reports`, and every Q7 and Q8 collection name

Other model classes with `toJson`/`fromJson`: `NavItem` (`lib/shared/models/nav_item.dart:53,63 @ 7808a91`), plus `CacheStatistics` and `CacheSizeInfo` (`lib/shared/services/cache_service.dart:452,479 @ 7808a91`). None of them is tied to a Firestore collection.