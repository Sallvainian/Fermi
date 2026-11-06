---
title: 'Codebase research: Firebase backend auth, rules, collections and functions'
type: codebase
ask: |-
  research this codebase's Firebase backend: how sign-in and user roles work (lib/features/auth, functions authBlocking and customClaims), how firestore.rules and storage.rules decide access, where each Firestore collection is defined and accessed, and what each Cloud Function in functions/src does and what triggers it. Goal: this is the baseline for replacing Firebase with Supabase.
repository: '/Users/sallvain/Projects/Fermi'
commit: '7808a91cfc090824a3501648e54d466f50689675'
branch: 'initiative/capacitor-supabase-port'
status: complete
validation: 'normal'
claims: {verified: 75, disputed: 3}
created: '2026-11-05'
updated: '2026-11-05'
---

# Codebase research: Firebase backend auth, rules, collections and functions

## Questions

1. (how) How does the client start Firebase and sign users in? Cover `lib/firebase_options.dart`, `lib/shared/core/service_locator.dart`, `lib/shared/core/app_initializer.dart` (including what it initializes for Realtime Database and Messaging), each sign-in flow in `lib/features/auth` (email/password, username, Google, the desktop OAuth handlers), how auth state is exposed to the rest of the app, and how the client reads the user's role.
2. (how) How are role claims assigned and changed on the server? Cover `functions/src/authBlocking.ts`, `functions/src/customClaims.ts`, `functions/src/config/domainRoles.ts`, `functions/src/migrate-user-roles.ts`, `functions/src/migrate-user-roles-cloud.ts`, and the client's `lib/shared/utils/set_user_role_claims.dart` and `lib/shared/utils/run_migration.dart`: what triggers each and what each writes.
3. (how) How does `firestore.rules` decide read and write access for each match path: helper functions, claim/role checks, ownership and membership checks, and field-level validation?
4. (how) How does `storage.rules` decide access, and which Storage paths does the client read or write?
5. (where) Where is the document shape of each of these Firestore collections defined (model classes, serializers, `firestore.indexes.json`), and which files read or write each: `users`, `public_usernames`, `presence`, `fcm_tokens`, `notifications`, `scheduled_messages`, `bug_reports`? Also resolve the call sites that pass a collection name as a variable (`collection(this.collectionName)`, `collection(path)`, `collection(collectionPath)`).
6. (where) Same as 5 for: `classes`, `students`, `assignments`, `submissions`, `grades` (including `collectionGroup('grades')`), `calendar_events`.
7. (where) Same as 5 for: `chatRooms`, `conversations`, `messages`, `typing`, `discussion_boards`, `threads`, `replies`, `likes`.
8. (where) Same as 5 for: `studentPoints`, `behaviors`, `history` (including the `collectionGroup('history')` queries), `activities`, `jeopardy_games`, `jeopardy_sessions`, `jeopardy_questions`, `oauth_pkce_challenges`, `_rate_limits`.
9. (how) What does each exported function in `functions/src/adminFunctions.ts`, `functions/src/bulkImport.ts`, `functions/src/oauth.ts` and `functions/src/cleanup.ts` do, what triggers it (callable, HTTP, schedule, Firestore event, auth event), and which collections and Admin SDK APIs does it touch?
10. (how) Same as 9 for `functions/src/chatFunctions.ts`, `functions/src/behaviorPoints.ts`, `functions/src/security.ts`, `functions/src/rate-limiter.ts` and `functions/src/migrate-usernames.ts`, including which of their functions are or are not exported from `functions/src/index.ts`.
11. (how) How does the client register for, receive and display push notifications? Cover `lib/features/notifications/data/services/firebase_messaging_service.dart`, `lib/shared/core/app_initializer.dart`, `lib/features/chat/presentation/screens/flyer_chat_screen.dart`, and `flutter_local_notifications` usage.
12. (where) Which client files call Cloud Functions callables, and which function does each call with what arguments? (Files using `FirebaseFunctions` / `httpsCallable`.)
13. (how) How are the client auth code, `firestore.rules`, `storage.rules` and the Cloud Functions tested: `test/`, any tests under `functions/`, and the emulator configuration in `firebase.json`?

## 1. How does the client start Firebase and sign users in?

The client starts Firebase once, with no emulator configured. Every sign-in goes through `AuthProvider` and `AuthService`. On desktop, only `DirectDesktopOAuthHandler` is live. The client reads the user's role from the Firestore field `users/{uid}.role`. No live path reads an ID-token claim.

### Startup

1. **`main`**
   - Loads `.env` on non-web builds.
   - Calls `runApp(InitializationWrapper)`.

   `lib/main.dart:30 (main) @ 7808a91`
2. **`_InitializationWrapperState._initializeApp`**
   - Calls `AppInitializer.initialize()`.
   - Has a fast path for when Firebase is already up.

   `lib/main.dart:341 (_InitializationWrapperState) @ 7808a91`
3. **`AppInitializer.initialize`**
   - Runs Firebase, then the service locator, then deferred services in a post-frame callback.
   - Errors are logged and execution continues.

   `lib/shared/core/app_initializer.dart:29-51 (AppInitializer) @ 7808a91`
4. **Firebase initialization**
   - Calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` only when `Firebase.apps.isEmpty`, and ignores `duplicate-app`.
   - No emulator is configured.

   `lib/shared/core/app_initializer.dart:101-139 (AppInitializer) @ 7808a91`
5. **Platform options**
   - `DefaultFirebaseOptions.currentPlatform` has web, android, ios, macos, windows and linux entries, all for project `teacher-dashboard-flutterfire`.
   - Any other platform throws `UnsupportedError`.

   `lib/firebase_options.dart:18-38 (DefaultFirebaseOptions) @ 7808a91`
6. **Persistence settings**
   - Firestore: `persistenceEnabled: true` with an unlimited cache, on non-web only. `lib/shared/core/app_initializer.dart:142-147 (AppInitializer) @ 7808a91`
   - **Realtime Database:** the only initialization is `FirebaseDatabase.instance` plus `setPersistenceEnabled(true)` on non-web. No refs or listeners are created. `lib/shared/core/app_initializer.dart:150-165 (AppInitializer) @ 7808a91`
7. **Service locator** registers lazy singletons for `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage` and `AuthService`, plus factories for `AssignmentService` and `SubmissionService`. `lib/shared/core/service_locator.dart:55-119 (setupServiceLocator) @ 7808a91`
   - Nothing resolves the GetIt `AuthService`. `AuthProvider` builds its own with `authService ?? AuthService()`. `lib/features/auth/providers/auth_provider.dart:66 (AuthProvider) @ 7808a91`
8. **Deferred services**
   - `NotificationService().initialize()` runs on all platforms.
   - **Messaging:** `FirebaseMessagingService().initialize()` runs on Android and iOS only. Desktop and web never start FCM.

   `lib/shared/core/app_initializer.dart:54-89 (AppInitializer) @ 7808a91`
9. **Root widget**
   - Shows a loading app while `AuthStatus` is `uninitialized` or `authenticating`.
   - Then builds `AppRouter.createRouter(authProvider)` once.

   `lib/main.dart:198-244 (_TeacherDashboardAppState) @ 7808a91`

### Sign-in methods

#### Email/password sign-in

1. `login_screen._signIn` calls `AuthProvider.signIn`. `lib/features/auth/presentation/screens/login_screen.dart:96-117 (_signIn) @ 7808a91`
2. `AuthProvider.signIn` passes the call to `AuthService.signIn`. `lib/features/auth/providers/auth_provider.dart:193-224 (AuthProvider) @ 7808a91`
3. `AuthService.signIn`:
   - Rejects `invalid-email-domain` unless the email ends with `@roselleschools.org`, `@rosellestudent.org` or `@fermi-plus.com`. `lib/features/auth/data/services/auth_service.dart:46-73 (AuthService) @ 7808a91`
   - Calls `signInWithEmailAndPassword`.
   - Merge-writes `users/{uid}.lastActive`.

   `lib/features/auth/data/services/auth_service.dart:211-251 (AuthService) @ 7808a91`

#### Email/password sign-up

`AuthService.signUp`:
- Applies the same domain check.
- Calls `createUserWithEmailAndPassword`, then `updateDisplayName`.
- Merge-writes `users/{uid}` with `{uid, firstName, lastName, username, lastActive}` and no role. A comment says the blocking function sets the role.

`lib/features/auth/data/services/auth_service.dart:159-208 (AuthService) @ 7808a91`

#### Username sign-in

`UsernameAuthService.signInWithUsername`:
1. Resolves `public_usernames/{username}`. If that misses, it queries `users` where `username ==` and writes the mapping back.
2. Reads `users/{uid}.email`.
3. Calls `signInWithEmailAndPassword`.

`lib/features/auth/data/services/username_auth_service.dart:81-192 (UsernameAuthService) @ 7808a91`

`signInWithUsername` has no caller. The only use of `UsernameAuthService` is for generating and validating usernames. `lib/features/teacher/presentation/screens/manage_student_accounts_screen.dart:26 (_ManageStudentAccountsScreenState) @ 7808a91`

#### Google

`AuthService.signInWithGoogle` never calls the domain check. It branches by platform:

| Platform | Flow |
|---|---|
| Web | `GoogleAuthProvider` with `signInWithPopup`, falling back to `signInWithRedirect` / `getRedirectResult` |
| Desktop (Windows, macOS, Linux) | `_directOAuthHandler.performDirectOAuthFlow()` |
| Android and iOS | `signInWithProvider(GoogleAuthProvider)` |

Afterwards it reads `users/{uid}`:
- If the document is missing, it merge-writes profile fields with no role.
- Otherwise, it merge-writes `lastActive`.

`lib/features/auth/data/services/auth_service.dart:254-414 (AuthService) @ 7808a91`

#### Apple

`AuthService.signInWithApple`:
- Calls `SignInWithApple.getAppleIDCredential`, then `OAuthProvider('apple.com').credential`, then `signInWithCredential`.
- For a new user, writes `users/{uid}` with `role: null` and `authProvider: 'apple'`.

`lib/features/auth/data/services/auth_service.dart:417-498 (AuthService) @ 7808a91`

The login and sign-up screens do not call it. Its only caller is `reauthenticateWithApple`. `lib/features/auth/providers/auth_provider.dart:648-650 (AuthProvider) @ 7808a91`

### Desktop OAuth handlers

- **Live:** `DirectDesktopOAuthHandler`, which is a field of `AuthService`. `lib/features/auth/data/services/auth_service.dart:19-20 (AuthService) @ 7808a91` Its flow:
  - Reads the client ID and secret from `--dart-define`, falling back to `.env`.
  - Opens a loopback server with `HttpServer.bind('localhost', 0)`.
  - Uses PKCE S256 and launches Google's auth URL.
  - Exchanges the code on the client at `oauth2.googleapis.com/token`, sending `client_secret`.
  - Calls `GoogleAuthProvider.credential` and then `signInWithCredential`.

  `lib/features/auth/data/services/desktop_oauth_handler_direct.dart:64-207 (DirectDesktopOAuthHandler) @ 7808a91`
- **Not instantiated:** `SecureDesktopOAuthHandler`. It calls the `getOAuthUrl` and `exchangeOAuthCode` HTTP functions, then `signInWithCustomToken`. `lib/features/auth/data/services/desktop_oauth_handler_secure.dart:12-118 (SecureDesktopOAuthHandler) @ 7808a91`
- **Not instantiated:** `DesktopOAuthHandler`. It returns `oauth2.Credentials` and makes no Firebase Auth call. `lib/features/auth/data/services/desktop_oauth_handler.dart:21-54 (DesktopOAuthHandler) @ 7808a91`
- The log text in `AuthService` says "secure OAuth via Firebase Functions", but the code calls the direct handler. `lib/features/auth/data/services/auth_service.dart:336-341 (AuthService) @ 7808a91`

### How auth state reaches the app

`AuthProvider` is a `ChangeNotifier`. It exposes:
- `status`, one of `uninitialized`, `authenticated`, `authenticating`, `unauthenticated` or `error`
- `userModel`
- `firebaseUser`

`lib/features/auth/providers/auth_provider.dart:14-81 (AuthProvider) @ 7808a91`

**`AuthProvider` does not subscribe to `authStateChanges`.** `_initializeAuthState` runs once:
1. On web, calls `getRedirectResult`.
2. Reads `currentUser`.
3. Calls `user.reload()`, and signs out if it fails.
4. Calls `_processUser`.

`lib/features/auth/providers/auth_provider.dart:86-137 (AuthProvider) @ 7808a91`

The only `authStateChanges()` listener in `lib` is in the presence service. `lib/features/student/data/services/presence_service.dart:408 (PresenceService) @ 7808a91`

**`_processUser`:**
- Loads `users/{uid}`, retrying up to 5 times, and accepts the model only when `role != null`. `lib/features/auth/providers/auth_provider.dart:397-438 (AuthProvider) @ 7808a91`
- If no model loads and the email ends with `@fermi-plus.com`, writes `users/{uid}` with `role: 'admin'` from the client and loads again.
- On success, starts web in-app notifications and sets presence.
- If the model or role is missing, signs out and sets `error`.

`lib/features/auth/providers/auth_provider.dart:140-187 (AuthProvider) @ 7808a91`

**Routing** uses `refreshListenable: authProvider`. `lib/shared/routing/app_router.dart:67-136 (AppRouter) @ 7808a91`

| Condition | Redirect |
|---|---|
| `uninitialized` or `authenticating` | none |
| `error` | `/auth/login` |
| signed out | `/auth/role-selection` |
| `needsPasswordReset` | `/auth/teacher-setup/password` |
| signed in on an auth route | `/dashboard` |
| non-student on a `/student` route | `/dashboard` |

`/dashboard` picks the teacher, student or admin dashboard from `userModel.role`. A null role with a signed-in user falls back to the student dashboard. `lib/shared/routing/app_router.dart:194-254 (GoRoute) @ 7808a91`

`computeAuthRedirect` has no caller. `lib/shared/routing/auth_redirect.dart:21 (computeAuthRedirect) @ 7808a91`

### Where the client reads the role

- **From Firestore.** `UserModel.fromFirestore` maps `users/{uid}.role` through `_roleFromString`. Only `teacher`, `student` and `admin` map to a role; any other value becomes null. `lib/shared/models/user_model.dart:146-262 (UserModel) @ 7808a91`
- **From ID-token claims, unused.** `UserRoleClaims.hasRole` and `getCurrentUserRole` read `getIdTokenResult().claims['role']`, but nothing imports them. `lib/shared/utils/set_user_role_claims.dart:41-69 (UserRoleClaims) @ 7808a91`
- **Client-side role writers, uncalled.**
  - `AuthService.updateUserRole` and `saveUserRole` write `users.role` and have no callers. `lib/features/auth/data/services/auth_service.dart:527-588 (AuthService) @ 7808a91`
  - `AuthProvider.setSelectedRole` is a no-op. `lib/features/auth/providers/auth_provider.dart:632-635 (AuthProvider) @ 7808a91`

### Answered elsewhere

- Presence storage: see question 5, `presence` (it is Firestore).
- Role at sign-up: see question 2, `autoAssignRole`.

## 2. How are role claims assigned and changed on the server?

The email domain decides the role only at sign-up. After that, the claim follows the Firestore `users.role` field through `syncUserRole`, but only for `teacher` and `student`. An `admin` claim is written only by the blocking function at sign-up and by `createAdminAccount`.

### Domain-to-role mapping

- `DOMAIN_ROLE_MAPPINGS` maps three email domains to roles:

  | Domain | Role |
  |---|---|
  | `@roselleschools.org` | teacher |
  | `@rosellestudent.org` | student |
  | `@fermi-plus.com` | admin |

  `functions/src/config/domainRoles.ts:7-23 (DOMAIN_ROLE_MAPPINGS) @ 7808a91`
- `ADMIN_EMAILS` is empty. `functions/src/config/domainRoles.ts:26 (ADMIN_EMAILS) @ 7808a91`
- `getRoleFromEmail` lowercases the email, checks `ADMIN_EMAILS`, then returns the first mapping whose domain the email ends with, or `null`. `functions/src/config/domainRoles.ts:33-49 (getRoleFromEmail) @ 7808a91`

### `autoAssignRole`: blocking function

- **Trigger:** `beforeUserCreated` in `us-east4`. `functions/src/authBlocking.ts:13-14 (autoAssignRole) @ 7808a91`
- **Rejections:**
  - `invalid-argument` when the user data or the email is missing.
  - `permission-denied` when the domain is not a school domain. The message differs for `google.com` sign-ups.

  `functions/src/authBlocking.ts:18-50 (autoAssignRole) @ 7808a91`
- **Writes:**
  - `users/{uid}` with `{email, displayName, role, createdAt, emailVerified: false, isEmailUser: true, profileComplete: false}`
  - an `activities` document of type `user_created`

  `functions/src/authBlocking.ts:73-95 (autoAssignRole) @ 7808a91`
- **Returns:** `{customClaims: {role, emailDomain}, displayName, emailVerified: role === "admin"}`. It handles all three roles. `functions/src/authBlocking.ts:106-110 (autoAssignRole) @ 7808a91`

### `syncUserRole`: Firestore trigger

- **Trigger:** `onDocumentWritten` on `users/{userId}` in `us-east4`. It does nothing when `before.role === after.role`. `functions/src/customClaims.ts:80-92 (syncUserRole) @ 7808a91`
- **On delete:** it calls `setCustomUserClaims(userId, null)`, which clears every claim. `functions/src/customClaims.ts:95-103 (syncUserRole) @ 7808a91`
- **Role filter:** it writes `{role}` only for `teacher` or `student`. A change to `admin`, to any other value, or to no value writes nothing, and the old claim stays. Errors are logged and swallowed. `functions/src/customClaims.ts:106-114 (syncUserRole) @ 7808a91`

### `setRoleClaim`: callable

- **Trigger:** `onCall` in `us-east4`.
- **Rejections:** it rejects unauthenticated callers, a missing `uid` or `role`, and any role other than `teacher` or `student`.

`functions/src/customClaims.ts:10-34 (setRoleClaim) @ 7808a91`

- **Permission check:** it is denied unless the caller's `users.role` is `teacher` or the `uid` is the caller's own. Two consequences:
  - Any authenticated user can set their own role to teacher.
  - The catch turns every error into `internal`, so the client never sees `permission-denied`.

  `functions/src/customClaims.ts:46-72 (setRoleClaim) @ 7808a91`
- **Writes:** `setCustomUserClaims(uid, {role})` first, then `users/{uid}.update({role})`. If the update fails, the claim has changed and the field has not. `functions/src/customClaims.ts:54-60 (setRoleClaim) @ 7808a91`

### Migrations

- **`migrateAllUserRoles`**
  - `https.onCall`. Only a caller whose `users.role` is `teacher` may run it, so admins cannot.
  - For every `users` document it calls `setCustomUserClaims(id, {role})`, for teacher and student only.
  - It writes nothing to Firestore.

  `functions/src/migrate-user-roles-cloud.ts:13-86 (migrateAllUserRoles) @ 7808a91`
- **`migrateUserRoles`**
  - A standalone node script, run with `npm run migrate:roles` and not exported from `index.ts`. It has no caller check.
  - It runs the same loop with the same filter.

  `functions/src/migrate-user-roles.ts:10-68 (migrateUserRoles) @ 7808a91` and `functions/package.json:12 (scripts) @ 7808a91`

### Other places that set claims

- **`createStudentAccount`** sets `{role: "student"}`. It accepts `@rosellestudent.com`, which is not in `DOMAIN_ROLE_MAPPINGS`. `functions/src/adminFunctions.ts:75-135 (createStudentAccount) @ 7808a91`
- **`createTeacherAccount`** sets `{role: "teacher"}`. `functions/src/adminFunctions.ts:248-256 (createTeacherAccount) @ 7808a91`
- **`createAdminAccount`** sets `{role: "admin"}`. `functions/src/adminFunctions.ts:350-358 (createAdminAccount) @ 7808a91`
- **`bulkImportStudents`** sets `customClaims = {role: "student", gradeLevel}` through `auth.importUsers`. `functions/src/bulkImport.ts:228-244 (bulkImportStudents) @ 7808a91`
- **`exchangeOAuthCode`** puts `{provider: "google.com", email}` on a custom token and sets no role. `functions/src/oauth.ts:311-314 (exchangeOAuthCode) @ 7808a91`

UNVERIFIED (platform behavior, not in this code): whether Admin SDK `createUser` and `importUsers` fire `beforeUserCreated`.

### Client utilities

- **`UserRoleClaims.setRoleClaim`**
  - Calls the `setRoleClaim` callable with `{uid, role}`, then forces a token refresh.
  - Uses `FirebaseFunctions.instance` with no region set.

  `lib/shared/utils/set_user_role_claims.dart:7-37 (UserRoleClaims) @ 7808a91`
- **`runUserRoleMigration`** calls `migrateAllUserRoles` in `us-east4`. `lib/shared/utils/run_migration.dart:13-50 (runUserRoleMigration) @ 7808a91`
- Nothing in `lib`, `test` or `integration_test` calls either utility.

### How the claim and `users.role` diverge

- **Owner self-edit.** The owner of a `users` document may update it with no field restriction, so they can change `role` to teacher or student. `syncUserRole` then copies the new value into the claim. `firestore.rules:97 (users) @ 7808a91`
- **Change to admin, or role removed.** The old claim stays. `functions/src/customClaims.ts:106-114 (syncUserRole) @ 7808a91`
- **Sign-up.** The `users` document written at sign-up fires `syncUserRole`. For teacher and student, that replaces `{role, emailDomain}` with `{role}`. It also drops the `gradeLevel` claim set by bulk import.
- **Missing callable.** `UserManagementService.updateUserRole` calls an `updateUserRole` callable that does not exist under `functions/src`, then writes `users.role` directly. `lib/features/admin/data/services/user_management_service.dart:154-163 (UserManagementService) @ 7808a91`
- **Role checks never read the claim.** The Firestore rules (question 3) and every server callable's role check read `users.role`.

## 3. How does `firestore.rules` decide read and write access for each match path?

Roles come from the Firestore field `users/{uid}.role`, combined with the email domain in the token; the rules read no custom claims. An owner can edit their own `users` document, `role` included. 15 conditions are a placeholder `true`. Each point is cited below.

### How roles are determined

- The rules read no custom claims. The only `request.auth.token` field used is `email`. `firestore.rules:22-40 (hasTeacherDomain) @ 7808a91`
- `getUserRole(userId)` does `get(/users/$(userId))` and returns `data.role` (or null), and every role helper calls it with `request.auth.uid`. `firestore.rules:43-46 (getUserRole) @ 7808a91`
- The email-domain helpers match the token email against a case-insensitive regex:
  - teacher: `@roselleschools.org`
  - student: `@rosellestudent.org`
  - admin: `@fermi-plus.com`
  - `hasValidSchoolDomain` is any of the three.

  `firestore.rules:17-40 (hasValidSchoolDomain) @ 7808a91`
- `isTheTeacher()` requires role `'teacher'` and either the teacher domain or `isAdmin()`. Because `isAdmin()` needs role `'admin'`, this reduces to role teacher plus the teacher domain. It checks ownership of no document. `firestore.rules:49-55 (isTheTeacher) @ 7808a91`
- `isStudent()` requires role `'student'` and the student domain (or `isAdmin()`, which cannot be true at the same time). `firestore.rules:58-64 (isStudent) @ 7808a91`
- `isAdmin()` requires role `'admin'` and the admin domain. `firestore.rules:67-73 (isAdmin) @ 7808a91`
- `isEnrolledInClass(classId)` requires `isStudent()` and the caller's uid in `classes/{classId}.studentIds`. `firestore.rules:76-79 (isEnrolledInClass) @ 7808a91`
- `isOwner(userId)` requires a signed-in caller whose uid equals `userId`. `firestore.rules:12-14 (isOwner) @ 7808a91`

### `users/{userId}`

`firestore.rules:82-100 (users) @ 7808a91`

- **Read:** a signed-in caller who is the owner, `isTheTeacher()`, `isAdmin()`, or `isStudent() && hasValidSchoolDomain()`. Any student can therefore read every user document. `firestore.rules:85-90 (users) @ 7808a91`
- **Create:** requires `auth.uid == userId`, `request.resource.data.uid == userId` and `hasValidSchoolDomain()`. No other field is checked, including `role`. `firestore.rules:92-95 (users) @ 7808a91`
- **Update:** `isOwner(userId) || isAdmin() || isTheTeacher()`, with no field checks. A user can therefore change the `role` field on their own document. The domain check inside each role helper is the only thing that ties a role to an email. `firestore.rules:97 (users) @ 7808a91`
- **Delete:** `isAdmin() || isTheTeacher()`. The comment says "Only admins". `firestore.rules:98-99 (users) @ 7808a91`

### `public_usernames/{username}`

- **Read:** `if true`, so unauthenticated callers can read. `firestore.rules:106 (public_usernames) @ 7808a91`
- **Create:** requires `request.resource.data.uid == auth.uid` and `get(users/{auth.uid}).data.username == username`. `firestore.rules:108-110 (public_usernames) @ 7808a91`
- **Update and delete:** admin or teacher. `firestore.rules:112 (public_usernames) @ 7808a91`

### `classes/{classId}` and subcollections

`firestore.rules:117-199 (classes) @ 7808a91`

- **Read:** any signed-in user can read any class. The comment mentions enrollment, but the rule never checks it. `firestore.rules:124-127 (classes) @ 7808a91`
- **Create:** `(isTheTeacher() && request.resource.data.teacherId == auth.uid) || isAdmin() || isTheTeacher()`. The trailing bare `isTheTeacher()` makes the `teacherId` check non-binding. `firestore.rules:130-131 (classes) @ 7808a91`
- **Update** is allowed in either of two cases:
  - `isTheTeacher()`, on any class and any fields.
  - `isStudent()`, where the changed keys are `hasOnly(['studentIds','updatedAt'])` and the caller's uid is not already in `resource.data.studentIds`. Nothing checks that the new `studentIds` contains the caller or keeps the existing entries.

  `firestore.rules:134-143 (classes) @ 7808a91`
- **Delete:** the `teacherId` ownership check is non-binding, for the same reason as create. `firestore.rules:146-147 (classes) @ 7808a91`
- **`studentPoints/{studentId}`:**
  - read: teacher, admin, or the student whose points they are
  - create and update: `isTheTeacher()`
  - delete: admin or teacher

  `firestore.rules:150-161 (studentPoints) @ 7808a91`
- **`studentPoints/{studentId}/history/{historyId}`:**
  - read: teacher, admin, or the owning student
  - create and update: `isTheTeacher()`

  `firestore.rules:163-177 (history) @ 7808a91`
- **`behaviors/{behaviorId}`:**
  - read: teacher, admin, or `isEnrolledInClass(classId)`
  - writes: `isTheTeacher()`

  `firestore.rules:181-192 (behaviors) @ 7808a91`
- **`{document=**}` catch-all under a class:**
  - read: `isTheTeacher() || isEnrolledInClass(classId)`
  - write: `isTheTeacher()`

  Under Firestore's OR semantics for overlapping matches, this also gives any enrolled student read access to every student's points and history. `firestore.rules:195-198 (document) @ 7808a91`

### `conversations`, `chatRooms`, `chat_rooms`

- **`conversations/{conversationId}`** `firestore.rules:203-218 (conversations) @ 7808a91`
  - read: signed in, and either `resource == null` or the caller is in `resource.data.participants`
  - create: the caller is in the new `participants`
  - update: the caller is in the existing `participants`, with no field checks
  - delete: `false`
- **Its `messages`** `firestore.rules:220-233 (messages) @ 7808a91`
  - read: the caller is in the parent's `participants`, checked with `get`
  - create: requires `auth.uid == authorId || auth.uid == senderId` plus parent membership
  - update and delete: `false`
- **Its `typing/{userId}`:** read by any signed-in user; written only when `auth.uid == userId`. `firestore.rules:236-246 (typing) @ 7808a91`
- **`chatRooms/{chatRoomId}`** `firestore.rules:250-262 (chatRooms) @ 7808a91`
  - read: any signed-in user
  - create: the caller is in the new `participantIds`
  - update and delete: the caller is in the existing `participantIds`, with no field checks
- **Its `messages`** `firestore.rules:264-274 (messages) @ 7808a91`
  - read: parent membership
  - create: `senderId == uid` plus membership
  - update: `false`
  - delete: any signed-in user. `firestore.rules:273 (messages) @ 7808a91`
- **The older `chat_rooms/{chatRoomId}`:** an update by a non-teacher must keep `participantIds.hasAll(old participantIds)`, so a non-teacher cannot remove participants. Delete is `false`. `firestore.rules:278-307 (chat_rooms) @ 7808a91`

### `assignments`, `grades`, `submissions`, collection groups

- **`assignments/{assignmentId}`** `firestore.rules:310-325 (assignments) @ 7808a91`
  - read: `isTheTeacher() || resource == null || (isStudent() && isEnrolledInClass(resource.data.classId))`
  - create: `isTheTeacher() && request.resource.data.teacherId == auth.uid`. Nothing checks that `classId` belongs to that teacher.
  - update and delete: require the existing `teacherId == uid`. Update does not stop `teacherId` from being changed.
- **`grades/{gradeId}`** `firestore.rules:328-341 (grades) @ 7808a91`
  - read: teacher, `resource == null`, or the student whose `studentId` it is
  - create: the teacher, with the new `teacherId == uid`
  - update and delete: the teacher, with the existing `teacherId == uid`
- **Collection group `{path=**}/grades`:** read when `isTheTeacher()`. `firestore.rules:344-346 (path) @ 7808a91`
- **Collection group `{path=**}/history`:** read by teacher, admin, or the caller who owns the class named in `resource.data.classId`, checked with `get`. `firestore.rules:349-358 (path) @ 7808a91`
- **`submissions/{submissionId}`** `firestore.rules:361-382 (submissions) @ 7808a91`
  - read: teacher, `resource == null`, or the owning student
  - create: `isStudent()` with `auth.uid == request.resource.data.studentId`. Nothing checks the assignment or enrollment.
  - update by a student: allowed while `resource.data.submittedAt == null` and `studentId` is unchanged, with no `affectedKeys` limit
  - update by `isTheTeacher()`: allowed
  - delete: teacher

### Other collections

- **`announcements`:**
  - read: signed in
  - writes: `isTheTeacher()`

  `firestore.rules:385-388 (announcements) @ 7808a91`
- **`discussion_boards/{boardId}`** is matched twice, at `:391` and `:506`. Firestore combines the two with OR, so the more permissive block wins:
  - any signed-in user can create a board (`:393`), even though `:508` requires a teacher
  - thread, comment and reply creates need no `authorId` check (`:402`, `:420`, `:431`), even though `:517`, `:536` and `:548` require one

  `firestore.rules:391-588 (discussion_boards) @ 7808a91`
- **Thread counter updates:** anyone may update a thread's counters when the changed keys are only `likeCount` or only `replyCount` and the value moves by ±1. `firestore.rules:407-413 (threads) @ 7808a91`
- **Reply `likeCount` update:** the condition lacks inner parentheses. By standard precedence, any update with `likeCount == old-1` passes regardless of which other keys change. `firestore.rules:436-438 (replies) @ 7808a91`
- **`likes`:**
  - create: `auth.uid == likeId == request.resource.data.userId`
  - delete: `auth.uid == likeId`
  - update: `false`

  `firestore.rules:443-469 (likes) @ 7808a91`
- **`games/{gameId}`:**
  - read and create: signed in
  - update and delete: `creatorId == uid`
  - `scores` create: the new `studentId == uid`

  `firestore.rules:474-488 (games) @ 7808a91`
- **`scheduled_messages`:** every operation keys on the nested field `message.senderId == uid`. `firestore.rules:492-503 (scheduled_messages) @ 7808a91`
- **`calendar_events`:**
  - read: `createdBy == uid` or the caller is in `participantIds`
  - writes: `createdBy == uid`

  `firestore.rules:591-601 (calendar_events) @ 7808a91`
- **`students/{studentId}`:**
  - read: teacher, or the student matching `studentId` or `resource.data.userId`
  - update: that student, with no field checks
  - create and delete: teacher

  `firestore.rules:604-618 (students) @ 7808a91`
- **`teachers/{teacherId}`:** read and write when `isTheTeacher() && uid == teacherId`. `firestore.rules:621-624 (teachers) @ 7808a91`
- **`calls/{callId}`:**
  - read: any signed-in user while `status == 'ringing'`
  - update: caller or receiver, limited to a status transition list
  - `candidates` subcollection: caller and receiver, checked with `get`

  `firestore.rules:627-660 (calls) @ 7808a91`
- **`activities`:**
  - read: admin, teacher, or a student enrolled in the class named in `resource.data.classId`
  - create: admin, teacher, or the new `userId == uid`
  - update and delete: admin or teacher

  `firestore.rules:663-682 (activities) @ 7808a91`
- **`notifications`:**
  - read, update and delete: `userId == uid`
  - create: teacher or the new `userId == uid`

  `firestore.rules:685-703 (notifications) @ 7808a91`
- **`fcm_tokens/{userId}`:** owner only. `firestore.rules:706-708 (fcm_tokens) @ 7808a91`
- **`bug_reports`:**
  - create: the new `userId == uid`
  - read: teacher
  - update and delete: `false`

  `firestore.rules:711-722 (bug_reports) @ 7808a91`
- **`jeopardy_games`:**
  - read: `isPublic == true` or `teacherId == uid`
  - create: teacher, with `teacherId == uid`
  - update: `teacherId` must stay unchanged

  `firestore.rules:725-749 (jeopardy_games) @ 7808a91`
- **`jeopardy_sessions`:**
  - update: `teacherId == uid` or the caller is in `participantIds`, with no field checks

  `firestore.rules:752-772 (jeopardy_sessions) @ 7808a91`
- **`presence/{userId}`:** read by any signed-in user; written by the owner. `firestore.rules:775-790 (presence) @ 7808a91`
- **Default `{document=**}`:** denies read and write. `firestore.rules:793-795 (document) @ 7808a91`
- **Collections with no rule:** `jeopardy_questions`, `oauth_pkce_challenges` and `_rate_limits` have no match block, so they fall to the default deny.

### Placeholders and comments

- **Placeholder conditions:** 15 conditions are the literal `true`, at lines `:136`, `:256`, `:270`, `:289`, `:302`, `:370`, `:394`, `:403`, `:421`, `:432`, `:497`, `:641`, `:718`, `:738` and `:762`. Nearby comments mention email verification. `firestore.rules:367-370 (submissions) @ 7808a91`
- **Footer comment:** it claims "Email verification required for content creation", but the file has no `email_verified` check. `firestore.rules:800 (document) @ 7808a91`
- **Field-level checks:** the only ones in the file are:
  - `affectedKeys().hasOnly` at `:140`, `:407`, `:411`, `:436`, `:522`, `:526`, `:553`
  - `hasAll` at `:293`

Looked for and not found at 7808a91: custom-claim reads (`token.role`, `.claims`, `customClaims`) and `email_verified`. Not settled from the code: how `resource == null` behaves in list queries.

## 4. How does `storage.rules` decide access, and which Storage paths does the client read or write?

`storage.rules` checks two things only: whether the caller is signed in, and whether the uid matches the path's `{userId}`. It has no size, content-type, custom-claim or metadata checks. The only helper is `isAuthenticated()`, which returns `request.auth != null`. `storage.rules:5-7 (isAuthenticated) @ 7808a91`

Every rule is written as `read` or `write`, so `write` covers create, update and delete.

| Block | read | write | Citation |
|---|---|---|---|
| `/chat_images/{chatRoomId}/{fileName}` | signed in | signed in. Nothing ties the caller to `chatRoomId` | `storage.rules:10-13 (chat_images) @ 7808a91` |
| `/chat_videos/{chatRoomId}/{fileName}` | signed in | signed in | `storage.rules:16-19 (chat_videos) @ 7808a91` |
| `/users/{userId}/profile/{fileName}` | signed in | `request.auth.uid == userId` | `storage.rules:22-25 (users) @ 7808a91` |
| `/users/{userId}/{allPaths=**}` | signed in | `request.auth.uid == userId` | `storage.rules:28-31 (users) @ 7808a91` |
| `/public/{allPaths=**}` | `true` (signed-out callers too) | `false` | `storage.rules:34-37 (public) @ 7808a91` |
| `/{document=**}` | `false` | `false` | `storage.rules:40-42 (document) @ 7808a91` |

A comment in `setRoleClaim` says the role claim "is needed for Storage rules to check if a user is a teacher". The rules at this commit never read that claim. `functions/src/customClaims.ts:6-10 (setRoleClaim) @ 7808a91`

### Every Storage path the code touches

**1. Client write.** The client writes `users/{uid}/profile/avatar.jpg` with `putFile`, and that path matches the profile block. `lib/shared/screens/settings_screen.dart:1029-1038 (_uploadProfilePicture) @ 7808a91`

**2. Client read.** The client calls `getDownloadURL()` on the same path. `lib/shared/screens/settings_screen.dart:1041 (_uploadProfilePicture) @ 7808a91` `updateProfilePicture` then stores the URL. `lib/features/auth/providers/auth_provider.dart:704-713 (updateProfilePicture) @ 7808a91`

**3. Client delete.** The client deletes the same path with `storageRef.delete()` and swallows any error. It does not clear `photoURL` afterwards. `lib/shared/screens/settings_screen.dart:1078-1093 (_removeProfilePicture) @ 7808a91`

**4. Server write.** The Admin SDK writes `chat-attachments/{conversationId}/{userId}/{timestamp}_{sanitizedFileName}` in `uploadChatFile`. `functions/src/chatFunctions.ts:339-357 (uploadChatFile) @ 7808a91`

- No allow block covers `chat-attachments/`. The nearest blocks, `chat_images` and `chat_videos`, use underscores. The default-deny block matches the path, so client SDK access is denied, and only the Admin SDK and the signed URL reach these files. `storage.rules:40-42 (document) @ 7808a91` (An earlier draft said no rules block matched the path; the verifier found that the default deny does.)
- The function returns a signed read URL that expires `03-01-2500`. `functions/src/chatFunctions.ts:360-363 (uploadChatFile) @ 7808a91`
- The client sends the file as base64 and uses the `url` that comes back, once for images and once for files. `lib/features/chat/data/controllers/firestore_chat_controller.dart:383-397 (FirestoreChatController) @ 7808a91` and `lib/features/chat/data/controllers/firestore_chat_controller.dart:473-487 (FirestoreChatController) @ 7808a91`
- Images are shown with a plain URL fetch through `Image.network`, not through the Storage SDK. `lib/features/chat/presentation/widgets/web_image_stub.dart:20 (build) @ 7808a91`

**5. Unused paths.** No code uses `chat_images/`, `chat_videos/` or `public/`. A repository-wide grep finds them only in `storage.rules`.

### Checks in `uploadChatFile` that stand in for rules on the chat path

- **Unauthenticated callers** are rejected. `functions/src/chatFunctions.ts:290-295 (uploadChatFile) @ 7808a91`
- **File size** is checked against the client-declared `fileSize` (10 MB limit), not the decoded buffer. The check is skipped when `fileSize` is absent. `functions/src/chatFunctions.ts:309-314 (uploadChatFile) @ 7808a91`
- **MIME type** must be one of 11 allowed types. `functions/src/chatFunctions.ts:317-331 (uploadChatFile) @ 7808a91`
  - The client builds image types as `'image/${extension}'`, so a `.jpg` file becomes `image/jpg`, which is not on the list. `lib/features/chat/data/controllers/firestore_chat_controller.dart:387 (FirestoreChatController) @ 7808a91`
- **Conversation membership** is checked by `ensureConversationMembership`. `functions/src/chatFunctions.ts:334 (uploadChatFile) @ 7808a91`

### Not found at 7808a91

- `FirebaseStorage` is registered in the service locator, but nothing in `lib/` reads it through `getIt`. `lib/shared/core/service_locator.dart:88-90 (setupServiceLocator) @ 7808a91`
- No function reads or deletes Storage objects.
- `firebase.json` is not tracked at this commit, so nothing shows how `storage.rules` is deployed.

## 5. Where are `users`, `public_usernames`, `presence`, `fcm_tokens`, `notifications`, `scheduled_messages` and `bug_reports` defined and accessed?

The field lists for the writes in `auth_service.dart` come from grep, not from a full read.

### Collection names passed as variables

None of these resolve to the seven collections in this question.

- **`rate-limiter.ts`:** `collection(this.collectionName)` is fixed to `"_rate_limits"`. `functions/src/rate-limiter.ts:18-34 (FirestoreRateLimiter) @ 7808a91`
- **`FirestoreService.collection`:** `collection(collectionPath)` receives `'assignments'`, `'classes'` and `'grades'`. `lib/shared/services/firestore_service.dart:52 (FirestoreService) @ 7808a91`
  - `'assignments'`: `lib/features/assignments/data/services/assignment_service.dart:23 (AssignmentService) @ 7808a91`
  - `'classes'`: `lib/features/classes/data/services/class_service.dart:22 (ClassService) @ 7808a91`
  - `'grades'`: `lib/features/grades/data/services/grade_service.dart:19 (GradeService) @ 7808a91`
- **`getCollectionReference`:** `collection(path)` receives `'grades'` and `'archived_grades'`. `lib/shared/services/firestore_repository.dart:142-146 (getCollectionReference) @ 7808a91`
  - `'grades'`: `lib/features/assignments/data/services/assignment_service.dart:83 (AssignmentService) @ 7808a91`
  - `'archived_grades'`: `lib/features/grades/data/services/grade_service.dart:279-281 (archiveOldGrades) @ 7808a91`

### `users`

**Shape.** The read model is `UserModel`. `lib/shared/models/user_model.dart:100-175 (UserModel) @ 7808a91` Its fields are:
- identity: `uid`, `email`, `displayName`, `firstName`, `lastName`, `username`, `realEmail`
- profile: `photoURL` (falls back to `photoUrl`), `parentEmail`, `gradeLevel`
- links: `teacherId`, `studentId`, `enrolledClassIds`
- state: `role` (enum name), `needsPasswordReset`, `createdAt`, `lastActive`

`createdAt` and `lastActive` are accepted only when they are a `DateTime`. Every writer stores a server timestamp or `Timestamp`. `lib/shared/models/user_model.dart:140-145 (UserModel) @ 7808a91`

**Indexes.** There are none for `users`.

**Writes from functions:**

| Function | Operation | Fields | Citation |
|---|---|---|---|
| `autoAssignRole` | set | `email`, `displayName`, `role`, `createdAt`, `emailVerified`, `isEmailUser`, `profileComplete` | `functions/src/authBlocking.ts:73-81 (autoAssignRole) @ 7808a91` |
| `createStudentAccount` | set | `email`, `displayName`, `role`, `gradeLevel`, `parentEmail`, `createdAt`, `createdBy`, `isEmailUser`, `isGoogleAuth` | `functions/src/adminFunctions.ts:132-142 (createStudentAccount) @ 7808a91` |
| `createTeacherAccount` | set | `email`, `displayName`, `role`, `createdAt`, `createdBy`, `isEmailUser` | `functions/src/adminFunctions.ts:253-260 (createTeacherAccount) @ 7808a91` |
| `createAdminAccount` | set | same fields as the teacher write | `functions/src/adminFunctions.ts:355-362 (createAdminAccount) @ 7808a91` |
| `deleteUserAccount` | delete | — | `functions/src/adminFunctions.ts:438 (deleteUserAccount) @ 7808a91` |
| `bulkImportStudents` | set | the student fields, plus `profileComplete`, `studentId`, `classId`, `enrolledClasses` | `functions/src/bulkImport.ts:294-317 (bulkImportStudents) @ 7808a91` |
| `migrateStudentClassEnrollment` | update | sets `classId`, `enrolledClasses`; deletes `className` | `functions/src/bulkImport.ts:619-624 (migrateStudentClassEnrollment) @ 7808a91` |
| `setRoleClaim` | update | `role` | `functions/src/customClaims.ts:58-60 (setRoleClaim) @ 7808a91` |

**Reads from functions:**
- `adminFunctions.ts`:
  - caller role check at `:56`, `:208`, `:308`, `:410`, `:479`, `:544`
  - target user at `:431`, `:503`
  - the whole collection at `:553`

  `functions/src/adminFunctions.ts:56 (createStudentAccount) @ 7808a91`
- `behaviorPoints.ts`: `:54`, `:185`, `:296`, `:388`. `functions/src/behaviorPoints.ts:54 (awardBehaviorPoints) @ 7808a91`
- `bulkImport.ts`: `:45`, `:563`, and a query on `role == student` at `:574`. `functions/src/bulkImport.ts:574 (migrateStudentClassEnrollment) @ 7808a91`
- `chatFunctions.ts`: `:75`; the `.name` field at `:245`; `fcmToken` at `:397-399`. `functions/src/chatFunctions.ts:245 (updateTypingStatus) @ 7808a91`
- `customClaims.ts`: `:39`, and the `syncUserRole` trigger on `users/{userId}`. `functions/src/customClaims.ts:80-81 (syncUserRole) @ 7808a91`
- Migration scripts and functions:
  - `functions/src/migrate-user-roles.ts:20 (migrateUserRoles) @ 7808a91`
  - `functions/src/migrate-user-roles-cloud.ts:27 (migrateAllUserRoles) @ 7808a91`, `:46`
  - `functions/src/migrate-usernames.ts:26 (migrateUsernamesToPublic) @ 7808a91`, `:164`; a query on `username != null` at `:45` and `:194`

**Writes from the client:**
- `auth_service.dart`: `:196`, `:393`, `:407`, `:473`, `:536` (`role`), `:578`. `lib/features/auth/data/services/auth_service.dart:536 (AuthService) @ 7808a91`
  - merge of `lastActive`: `:244-246`
  - update: `:487`
  - delete: `:622`
- `username_auth_service.dart`: `lib/features/auth/data/services/username_auth_service.dart:253 (UsernameAuthService) @ 7808a91`
  - update of `lastActive`: `:184-186`
  - set: `:253`, `:329`
  - batch delete: `:381`
- `auth_provider.dart`: `lib/features/auth/providers/auth_provider.dart:155 (AuthProvider) @ 7808a91`
  - set with `role: 'admin'`: `:155`
  - update of name fields: `:697`
  - update of `photoURL`: `:708`
- `teacher_password_reset_screen.dart`: update of `needsPasswordReset` and `lastPasswordChange`. `lib/features/auth/presentation/screens/teacher_password_reset_screen.dart:49-54 (_TeacherPasswordResetScreenState) @ 7808a91`
- `profile_completion_dialog.dart`: update of the name fields, `profileComplete` and `updatedAt`. `lib/features/auth/presentation/widgets/profile_completion_dialog.dart:56-64 (_ProfileCompletionDialogState) @ 7808a91`
- `user_management_service.dart`: `lib/features/admin/data/services/user_management_service.dart:135-260 (UserManagementService) @ 7808a91`
  - update with caller-supplied fields: `:135-138`
  - update of `role`: `:160`
  - batch update of `enrolledClassIds`: `:222-226`
  - batch update: `:256-260`
- `student_provider.dart`: `lib/features/student/presentation/providers/student_provider.dart:228-273 (createStudent) @ 7808a91`
  - set of the student account fields: `:228-239`
  - update: `:259`
  - delete: `:273`
- `firebase_messaging_service.dart`: `lib/features/notifications/data/services/firebase_messaging_service.dart:241-245 (_saveFCMToken) @ 7808a91`
  - update of `fcmToken`, `fcmTokenUpdatedAt` and `platform`: `:241-245`
  - delete of those fields: `:407-410`

**Reads from the client:**
- admin:
  - `lib/features/admin/data/services/bulk_import_service.dart:303 (_checkEmailExists) @ 7808a91`
  - `lib/features/admin/data/services/user_management_service.dart:21 (getUsersStream) @ 7808a91`, `:45`, `:86`, `:322`
  - `lib/features/admin/presentation/providers/admin_provider.dart:56 (_loadSystemStats) @ 7808a91`, `:189`
- auth:
  - `lib/features/auth/data/services/auth_service.dart:383 (signInWithGoogle) @ 7808a91`, `:452`, `:543`, `:597`
  - `lib/features/auth/data/services/username_auth_service.dart:65 (getUidByUsername) @ 7808a91`, `:117`, `:159`
  - `lib/features/auth/providers/auth_provider.dart:425 (AuthProvider) @ 7808a91`, `:432`
- chat:
  - `lib/features/chat/data/services/scheduled_messages_service.dart:97 (scheduleMessage) @ 7808a91`
  - `lib/features/chat/presentation/screens/class_selection_screen.dart:107 (_createOrJoinClassChat) @ 7808a91`
  - `lib/features/chat/presentation/screens/flyer_chat_screen.dart:243 (_resolveUser) @ 7808a91`
  - `lib/features/chat/presentation/screens/group_creation_screen.dart:48-50 (_searchUsers) @ 7808a91`
  - `lib/features/chat/presentation/screens/user_list.dart:28 (SimpleUserList) @ 7808a91` (snapshots of the whole collection)
  - `lib/features/chat/presentation/screens/user_selection_screen.dart:44-45 (_loadUsers) @ 7808a91`
- other features:
  - `lib/features/calendar/presentation/providers/calendar_provider.dart:164 (createEvent) @ 7808a91`
  - `lib/features/classes/presentation/providers/class_provider.dart:271-273 (batchSize) @ 7808a91`, `:455`
  - `lib/features/discussions/presentation/providers/discussion_provider.dart:184 (_fetchUserRole) @ 7808a91`, `:247`, `:350`, `:514`
  - `lib/features/grades/data/services/grade_analytics_service.dart:40 (generateClassAnalytics) @ 7808a91`
  - `lib/features/student/presentation/providers/student_provider.dart:29-32 (loadAllStudents) @ 7808a91`, `:105`, `:165` (the operation at `:105` and `:165` is UNVERIFIED)
  - `lib/features/teacher/presentation/screens/manage_student_accounts_screen.dart:370 (collection) @ 7808a91`
  - `lib/shared/utils/check_auth_info.dart:16 (analyzeAuthSituation) @ 7808a91`, `:29`


**Field-name disagreements:**
- **`photoURL` and `photoUrl`.** Every writer uses `photoURL`. Three chat readers read `photoUrl` from `users` documents:
  - `lib/features/chat/presentation/screens/class_selection_screen.dart:117 (_createOrJoinClassChat) @ 7808a91`
  - `lib/features/chat/presentation/screens/flyer_chat_screen.dart:257 (_resolveUser) @ 7808a91`
  - `lib/features/chat/presentation/screens/user_selection_screen.dart:157 (build) @ 7808a91`
- **`enrolledClassIds` and `enrolledClasses`.** The model and the admin service use `enrolledClassIds`. The functions write `enrolledClasses` plus a scalar `classId`. `functions/src/bulkImport.ts:315-316 (bulkImportStudents) @ 7808a91`
- **`name` and `displayName`.** One function and one client query use `name`; every writer uses `displayName`.
  - `functions/src/chatFunctions.ts:245 (updateTypingStatus) @ 7808a91` reads `.name`.
  - `lib/features/chat/presentation/screens/group_creation_screen.dart:49-50 (_searchUsers) @ 7808a91` queries `name`.

### `public_usernames`

**Shape.** There is no model class. The document id is `username.toLowerCase()`, with fields `{uid, role}`. The functions writer adds `migratedAt`.

**Call sites in `username_auth_service.dart`:** `lib/features/auth/data/services/username_auth_service.dart:49-384 (UsernameAuthService) @ 7808a91`
- reads: `:49-54` (availability), `:97-104` (login lookup)
- write: `:133` (backfills a missing entry on login)
- sets: `:268` (student), `:343` (teacher)
- batch delete: `:384`

**Call sites in `migrate-usernames.ts`:** `functions/src/migrate-usernames.ts:76-96 (migrateUsernamesToPublic) @ 7808a91`
- reads: `:76-79`, `:211-214`
- batch sets: `:88-92`, `:222`

**Writers that skip it.** Three `users` writers set `username` without creating a `public_usernames` entry:
- `lib/features/auth/data/services/auth_service.dart:200 (AuthService) @ 7808a91`
- `lib/features/auth/data/services/auth_service.dart:584 (AuthService) @ 7808a91`
- `lib/features/student/presentation/providers/student_provider.dart:229 (createStudent) @ 7808a91`

### `presence`

**Shape.** Presence is stored in Firestore. The document id is the uid. Fields are `online`, `lastSeen`, `uid`, `displayName`, `photoURL`, `role`, `isAnonymous` and `metadata{platform, version}`. `lib/features/student/data/services/presence_service.dart:151-173 (_buildPresenceData) @ 7808a91`

**Indexes:**
- `online` + `lastSeen`: `firestore.indexes.json:976-992 (presence) @ 7808a91`
- `online` + `updatedAt`: `firestore.indexes.json:994-1010 (presence) @ 7808a91`. No presence writer writes `updatedAt`.

**Call sites in `presence_service.dart`:** `lib/features/student/data/services/presence_service.dart:92 (PresenceService) @ 7808a91`
- writes:
  - merge set: `:92`, `:101`
  - update: `:109`
  - batch update: `:480`, `:539-540`
  - delete: `:520`
- reads:
  - snapshots: `:219`, `:363`, `:388`, `:558`
  - get: `:259`, `:466`, `:517`

**Other reader.** `admin_provider.dart` reads `online == true`. `lib/features/admin/presentation/providers/admin_provider.dart:101-104 (AdminProvider) @ 7808a91`

### `fcm_tokens`

**Shape.** There is no model class and no index. The document id is the userId, with fields `token`, `userId`, `platform` and `updatedAt`. `lib/features/notifications/data/services/firebase_messaging_service.dart:248-253 (_saveFCMToken) @ 7808a91`

**Call sites.** It is written at `:248` and deleted at `:412`. Nothing in `lib/` or `functions/src/` reads it.

**The server reads a different field.** The only server-side token consumer reads `users.fcmToken`, not this collection. `functions/src/chatFunctions.ts:397-399 (sendPushNotifications) @ 7808a91`

### `notifications`

**Shape: two models.**
- `NotificationModel`: `userId`, `type`, `title`, `message`, `createdAt`, `isRead`, `priority`, `actionData`, `imageUrl`, `category`, `scheduledFor`, `expiresAt`. `lib/features/notifications/domain/models/notification_model.dart:47-93 (NotificationModel) @ 7808a91`
- `Notification`: `userId`, `type`, `title`, `message`, `read`, `relatedId`, `relatedType`, `actionUrl`, `metadata`, `createdAt`, `readAt`. Nothing calls its serializers. `lib/features/notifications/domain/models/notification.dart:124-160 (Notification) @ 7808a91`

**Indexes:**
- collection group, `userId` + `createdAt`: `firestore.indexes.json:874 (notifications) @ 7808a91`
- collection group, `userId` + `isRead` + `createdAt`: `firestore.indexes.json:892 (notifications) @ 7808a91`
- collection scope, `read` + `userId` + `createdAt`: `firestore.indexes.json:914 (notifications) @ 7808a91`
- collection scope, `userId` + `createdAt`: `firestore.indexes.json:936 (notifications) @ 7808a91`
- collection scope, `userId` + `isRead` + `createdAt`: `firestore.indexes.json:954 (notifications) @ 7808a91`

**Call sites in `firebase_notification_service.dart`:** `lib/features/notifications/data/services/firebase_notification_service.dart:10-296 (FirebaseNotificationService) @ 7808a91`
- reads: `:24-31`, `:64-75`, `:95-97`, `:129-132`, `:152-155`
- updates of `isRead`: `:113`, `:118`, and a batch at `:135`
- deletes: `:143`, and a batch at `:158`
- adds: `:192`, and a batch set at `:284`/`:296`

**Call sites in `web_in_app_notification_service.dart`:** `lib/features/notifications/data/services/web_in_app_notification_service.dart:46-149 (WebInAppNotificationService) @ 7808a91`
- read: `:46-52`, filtering on `userId` and `read == false` and reading `title`, `body` and `data`
- update with `delivered`: `:116`
- test add: `:137-149`

**Call site in `notification_service.dart`.** An `add` with no `userId` and no read flag. `lib/features/notifications/data/services/notification_service.dart:303-311 (_storeNotificationRecord) @ 7808a91`

**Disagreements:**
- The read flag is `isRead` in one service and `read` in the other.
- `NotificationModel` writes `message` and `actionData`, while the web listener reads `body` and `data`.
- Records with no `userId` never match the `userId`-filtered queries.

### `scheduled_messages`

**Shape.** Each document holds `chatRoomId`, `createdAt` and an embedded `message`. `lib/features/chat/data/services/scheduled_messages_service.dart:111-117 (ScheduledMessagesService) @ 7808a91` The embedded `message` is the map from `Message.toFirestore`. Its fields are `senderId`, `senderName`, `senderRole`, `content`, `timestamp`, `isRead`, `attachmentUrl`, `attachmentType`, `scheduledFor`, `isScheduled`, `status`, `isEdited` and `editedAt`. `lib/features/chat/domain/models/message.dart:175-192 (Message) @ 7808a91` There is no index.

**Call sites:**
- set: `:111`
- reads: `:145-147`, `:263-264`
- delete: `:185`
- update: `:232-234`

**No server-side delivery.** Nothing in `functions/src` reads this collection.

### `bug_reports`

**Shape.** The document is built inline with no model class and no index. Fields are `category`, `priority`, `subject`, `description`, `userId`, `userEmail`, `userName`, `userRole`, `createdAt`, `status: 'new'`, `platform`, `appVersion` and `deviceInfo`. `lib/shared/screens/contact_support_screen.dart:308-328 (_submitReport) @ 7808a91`

**Call sites.** The only call is an `add` at `:331-333`. Nothing reads the collection.

## 6. Where are `classes`, `students`, `assignments`, `submissions`, `grades` and `calendar_events` defined and accessed?

No `fieldOverrides` entry in `firestore.indexes.json` covers these six collections. Index line numbers below point to the `"collectionGroup"` line of each entry.

### `classes`

**Shape.** `ClassModel` defines:
- `teacherId`, `name`, `subject`, `description`, `gradeLevel`, `room`, `schedule`
- `studentIds[]`, `syllabusUrl`, `isActive`, `academicYear`, `semester`
- `maxStudents`, `enrollmentCode`, `settings`, `createdAt`, `updatedAt`

Timestamps are parsed leniently.

`lib/features/classes/domain/models/class_model.dart:137-236 (ClassModel) @ 7808a91`

**Disagreements with the model:**
- **`students` instead of `studentIds`.** `class_selection_screen.dart` queries and reads `students`. `lib/features/chat/presentation/screens/class_selection_screen.dart:52 (_loadClasses) @ 7808a91` So does `grade_analytics_service.dart`. `lib/features/grades/data/services/grade_analytics_service.dart:35 (GradeAnalyticsService) @ 7808a91` The model and every writer use `studentIds`.
- **`studentCount`.** Incremented by `create_student_dialog.dart` and `student_provider.dart`, but not a model field. `lib/features/classes/presentation/widgets/create_student_dialog.dart:131-137 (_createAndEnrollStudent) @ 7808a91`
- **`chatRoomId`.** Written but not in the model. `lib/features/chat/presentation/screens/class_selection_screen.dart:132-134 (_createOrJoinClassChat) @ 7808a91`
- **`teacherUID`.** The functions read `classData.teacherId || classData.teacherUID`. Nothing in `lib` reads or writes `teacherUID`. `functions/src/behaviorPoints.ts:74 (awardBehaviorPoints) @ 7808a91`
- **A hand-built write.** One write leaves out `semester`, `syllabusUrl`, `maxStudents` and `settings`. `lib/features/classes/presentation/providers/class_provider.dart:426-442 (createClassFromParams) @ 7808a91`

**Indexes** (`firestore.indexes.json:308-406 (classes) @ 7808a91`):

| Line | Fields |
|---|---|
| 308 | `enrollmentCode` + `isActive` |
| 326 | `studentIds` CONTAINS + `isActive` + `name` |
| 348 | `studentIds` CONTAINS + `name` |
| 366 | `teacherId` + `isActive` |
| 384 | `teacherId` + `isActive` + `createdAt` desc |
| 406 | `teacherId` + `name` |

**Call sites:**
- `class_service.dart`, through `FirestoreRepository('classes')` `lib/features/classes/data/services/class_service.dart:22-310 (ClassService) @ 7808a91`
  - Writes: `:46`, `:78`, `:87`, `:93`; transactions at `:162`/`:193` and `:207`/`:231`; `:247`
  - Reads: `:65`, `:70`, `:105`, `:124`, `:140`, `:259`, `:310`
- `class_provider.dart` `lib/features/classes/presentation/providers/class_provider.dart:92-479 (ClassProvider) @ 7808a91`
  - Reads: `:92`, `:124`, `:145`, `:221`, `:248`, `:372`
  - Writes: `:181`, `:195`, `:210`, `:305`, `:319`, `:333`, `:347`, `:442`, `:479`
- `class_selection_screen.dart` (chat): reads at `:46`, `:51`, `:94`; write at `:132-134`
- `create_student_dialog.dart`: write at `:131-137`
- `student_provider.dart`: writes at `:291`, `:306`
- `bulk_import_service.dart`: write at `:202`
- `user_management_service.dart`: write at `:230`; reads at `:303`, `:329`
- `student_assignment_provider.dart`: read at `:34`
- `grade_analytics_service.dart`: read at `:16`
- `fix_teacher_id.dart`: read, then batch write of `teacherId`, for a hard-coded uid at `:24-40`
- `behavior_points_service.dart`: subcollections only (see question 8)
- `functions/src/adminFunctions.ts`: write at `:149`. `functions/src/adminFunctions.ts:149-153 (createStudentAccount) @ 7808a91`
- `functions/src/bulkImport.ts`: reads at `:167`, `:180`, `:588`; writes at `:348`, `:648`. `functions/src/bulkImport.ts:180-184 (bulkImportStudents) @ 7808a91`
- `functions/src/behaviorPoints.ts`: class reads at `:64`, `:195`, `:309`, `:400`

### `students`

**Shape. Two models disagree:**

| | `Student` | `StudentEnhanced` |
|---|---|---|
| Fields | `uid`, `username`, `temporaryPassword`, `accountClaimed`, `passwordChanged`, `backupEmail`, `email`, `firstName`, `lastName`, `displayName`, `gradeLevel`, `parentEmail`, `classIds[]`, `photoURL`, `createdAt`, `updatedAt`, `isActive`, `metadata` | `uid` (falls back to doc id), `email`, `displayName`, `firstName`, `lastName`, `gender`, `avatarUrl`, `gradeLevel`, `classIds`, `createdAt`, `updatedAt`, `totalPoints`, `positivePoints`, `negativePoints`, `lastBehaviorUpdate` |
| `gradeLevel` | int | String |
| Photo field | `photoURL` | `avatarUrl` |
| Citation | `lib/features/student/domain/models/student.dart:120-182 (Student) @ 7808a91` | `lib/features/students/data/models/student_enhanced.dart:79-134 (StudentEnhanced) @ 7808a91` |

Nothing calls `StudentEnhanced.fromFirestore`. Which collection it would read is UNVERIFIED.

**Disagreements:**
- **`userId` vs `uid`.**
  - `auth_service.dart` writes `id`, `userId` and `gradeLevel: 9`. `lib/features/auth/data/services/auth_service.dart:546-558 (AuthService) @ 7808a91`
  - `getStudentByUserId` queries `userId`. `lib/features/student/data/services/student_service.dart:91 (StudentService) @ 7808a91`
  - `createStudentDocumentIfMissing` queries `uid`. `lib/features/student/data/services/student_service.dart:545 (createStudentDocumentIfMissing) @ 7808a91`
- **Indexes on a field no model has.** The indexes at lines 1012 and 1030 are on `classIds` + `name`; neither model has `name`. The query that actually runs, `classIds` + `orderBy displayName`, has no matching index. `lib/features/student/data/services/student_service.dart:154-155 (getStudentsForClass) @ 7808a91`
- **Student lists built from `users`.** Several places build `Student.fromFirestore` from `users` documents, not from `students`. `lib/features/classes/presentation/providers/class_provider.dart:270-277 (ClassProvider) @ 7808a91`

**Indexes:**

| Line | Fields | Scope |
|---|---|---|
| 1012 | `classIds` + `name` | collection group |
| 1030 | `classIds` + `name` | collection |
| 1048 | `gradeLevel` + `displayName` | collection |
| 1066 | `isActive` + `displayName` | collection |

**Call sites:**
- `student_service.dart` `lib/features/student/data/services/student_service.dart:36-603 (StudentService) @ 7808a91`
  - Writes: `:52`, `:227`, `:246`, `:263`, `:282`, `:304`, `:324`; batches at `:350`, `:379`, `:407`, `:433`; `:579-603`
  - Reads: `:71`, `:90`, `:112`, `:130`, `:153`, `:173`, `:199`, `:457`, `:473`, `:493`, `:513`, `:541-547`
- `create_student_dialog.dart`: writes at `:96` and `:125-127`
- `bulk_import_service.dart`: write at `:195`
- `auth_service.dart`: writes at `:546` and `:628`
- `functions/src` has no access to `students`.

### `assignments`

**Shape. Two models:**

| | `Assignment` | `AssignmentModel` |
|---|---|---|
| Fields | `teacherId`, `classId`, `title`, `description`, `instructions`, `dueDate`, `totalPoints`, `maxPoints`, `attachmentUrl`, `createdAt`, `updatedAt`, `type`, `status`, `category`, `teacherName`, `isPublished`, `allowLateSubmissions`, `latePenaltyPercentage`, `publishAt` | `title`, `description`, `classId`, `className`, `subject`, `teacherId`, `dueDate`, `createdAt`, `hasSubmissions`, `needsGrading`, `totalPoints`, `attachments[]` |
| Citation | `lib/features/assignments/domain/models/assignment.dart:222-297 (Assignment) @ 7808a91` | `lib/features/assignments/domain/models/assignment_model.dart:34-66 (AssignmentModel) @ 7808a91` |

`Assignment.status` takes `draft | active | completed | archived`. Nothing imports `AssignmentModel`.

**Disagreements:**
- **Query on an unused model's field.** `dashboard_service.dart` queries `needsGrading == true`, a field only `AssignmentModel` declares. `lib/features/dashboard/data/services/dashboard_service.dart:77 (DashboardService) @ 7808a91`
- **Hand-built write.** `assignment_provider.dart` writes a caller-supplied map instead of `toFirestore()`. `lib/features/assignments/presentation/providers/assignment_provider.dart:54-62 (SimpleAssignmentProvider) @ 7808a91`

**Indexes** (`firestore.indexes.json:40-174 (assignments) @ 7808a91`):

| Line | Fields | Scope |
|---|---|---|
| 40 | `classId` + `dueDate` | collection group |
| 58 | `teacherId` + `createdAt` | collection group |
| 76 | `classId` + `createdAt` | collection |
| 94 | `classId` + `dueDate` | collection |
| 112 | `classId` + `isPublished` + `dueDate` | collection |
| 134 | `classId` + `status` + `dueDate` | collection |
| 156 | `isPublished` + `publishAt` | collection |
| 174 | `teacherId` + `createdAt` | collection |

**Call sites:**
- `assignment_service.dart`, through the repository `lib/features/assignments/data/services/assignment_service.dart:23-253 (AssignmentService) @ 7808a91`
  - Writes: `:34`, `:66`, `:73-93` (transaction that also deletes grades), `:137`, `:147`, `:160-177`, `:228-244`
  - Reads: `:60`, `:103`, `:113`, `:127`, `:198`, `:213`, `:253`
- `assignment_provider.dart`: reads at `:32`, `:79`, `:106`, `:131`, `:206`; writes at `:62`, `:166`, `:188`
- `student_assignment_provider.dart`: reads at `:51`, `:109`
- `assignments_list_screen.dart`: delete at `:671`
- `dashboard_service.dart`: reads at `:68`, `:75`, `:81`, `:109`, `:116`, `:153`
- `grade_analytics_service.dart`: read at `:26`
- `grade_provider.dart`: reads at `:46`, `:161`

### `submissions`

**Shape.** `Submission` has `assignmentId`, `studentId`, `studentName`, `fileUrl`, `fileName`, `textContent`, `submittedAt`, `gradedAt`, `updatedAt` and `status`. `submittedAt` is hard-cast to `Timestamp`. `status` takes `submitted | graded | returned | late`. `lib/features/assignments/domain/models/submission.dart:79-122 (Submission) @ 7808a91`

**Disagreements:**
- **Nested `grade` map.** `grade_provider.dart` writes a `grade` map (`points`, `maxPoints`, `percentage`, `letter`, `feedback`, `gradedAt`, `gradedBy`) that the model does not have. It also queries `grade != null`. `lib/features/grades/presentation/providers/grade_provider.dart:135-145 (gradeSubmission) @ 7808a91`
- **Missing `status` and a local path.** `student_assignment_provider.dart` adds a submission with no `status` and with `fileUrl: file?.path`. `lib/features/assignments/presentation/providers/student_assignment_provider.dart:181-188 (submitAssignment) @ 7808a91`

**Indexes.** None exist for `submissions`. The service still queries `assignmentId` + `orderBy submittedAt` and `studentId` + `orderBy submittedAt`. `lib/features/assignments/data/services/submission_service.dart:127-151 (getSubmissionsForAssignment) @ 7808a91`

**Call sites:**
- `submission_service.dart` `lib/features/assignments/data/services/submission_service.dart:34-294 (SubmissionService) @ 7808a91`
  - Writes: `:58`, `:170-172`, `:189`, `:209`
  - Reads: `:76`, `:100`, `:126`, `:149`, `:226`, `:272`, `:292`
- `student_assignment_provider.dart`: reads at `:73`, `:123`; write at `:181`
- `assignments_list_screen.dart`: read, then delete of each document, at `:677-682`
- `grade_analytics_service.dart`: read at `:55`
- `grade_provider.dart`: reads at `:66`, `:73`, `:103`, `:177`, `:184`, `:207`, `:268`; write at `:135`

### `grades` (top-level, the `submissions` subcollection, the collection group) and `archived_grades`

**Shape.** `Grade` has:
- `assignmentId`, `studentId`, `studentName`, `teacherId`, `classId`
- `pointsEarned`, `pointsPossible`, `percentage`, `letterGrade`, `feedback`, `status`
- `gradedAt`, `returnedAt`, `createdAt`, `updatedAt`
- `rubricScores`, `attachmentUrls`

`toFirestore` always writes server timestamps for `createdAt` and `updatedAt`.

`lib/features/grades/domain/models/grade.dart:265-325 (Grade) @ 7808a91`

**Disagreements:**
- **Where grades live.**
  - Writes go only to the top-level `grades` collection.
  - `grade_analytics_service.dart` reads a `submissions/{id}/grades` subcollection that nothing writes. `lib/features/grades/data/services/grade_analytics_service.dart:67-71 (generateClassAnalytics) @ 7808a91`
  - It also runs `collectionGroup('grades')` on `classId` + `gradedAt`. `lib/features/grades/data/services/grade_analytics_service.dart:464-468 (getGradeTrends) @ 7808a91`
- **`isGraded`.** `dashboard_service.dart` queries `isGraded == true` on top-level `grades`, but `Grade` has `status`, not `isGraded`. `lib/features/dashboard/data/services/dashboard_service.dart:174-194 (getRecentGrades) @ 7808a91`
- **A second grade store.** The `grade` map inside `submissions` uses `points`/`maxPoints`/`letter`/`gradedBy`, where `Grade` uses `pointsEarned`/`pointsPossible`/`letterGrade`.

**Indexes:**

| Line | Fields | Scope |
|---|---|---|
| 548 | `classId` + `gradedAt` | collection group |
| 566 | `studentId` + `classId` + `assignmentId` | collection group |
| 588 | `assignmentId` + `status` | collection |
| 606 | `classId` + `createdAt` | collection |
| 624 | `classId` + `gradedAt` | collection |
| 642–722 | five more collection-scope entries | collection |

The five entries at 642–722 include `isGraded` + `studentId` + `gradedAt` (twice) and `studentId` + `status` + `classId`; the remaining shapes are UNVERIFIED. Which line holds which shape is UNVERIFIED. `archived_grades` has no index.

**Call sites:**
- `grade_service.dart` `lib/features/grades/data/services/grade_service.dart:19-298 (GradeService) @ 7808a91`
  - Writes: `:28`, `:48`, `:55`, `:116-119`, `:139-143`, `:158-171`, and `:278-289` (archives to `archived_grades`, then deletes)
  - Reads: `:40`, `:64`, `:76`, `:85`, `:94`, `:103`, `:178`, `:199-214`, `:224`, `:242`, `:254`, `:270`, `:298`
- `assignment_service.dart`: reads grades outside the transaction, then deletes them inside it. `lib/features/assignments/data/services/assignment_service.dart:82-89 (AssignmentService) @ 7808a91`
- `grade_analytics_service.dart`: reads at `:68` (subcollection) and `:464` (collection group)
- `dashboard_service.dart`: reads at `:174`, `:192`

### `calendar_events`

**Shape.** `CalendarEvent` has:
- `title`, `description`, `type`, `startTime`, `endTime`, `isAllDay`, `location`
- `createdBy`, `createdByName`, `classId`, `assignmentId`
- `participantIds[]`, `participantEmails[]`, `colorHex`
- `recurrence`, `recurrenceEndDate`, `recurrenceDetails`, `hasReminder`, `reminderMinutes`
- `metadata`, `createdAt`, `updatedAt`, `isActive`

`lib/features/calendar/domain/models/calendar_event.dart:189-255 (CalendarEvent) @ 7808a91`

The service's create writes the same keys by hand. Whether that map includes `isActive` is UNVERIFIED.

**Indexes:**
- line 192: `createdBy` + `isActive` + `startTime`
- line 214: `participantIds` CONTAINS + `isActive` + `startTime`
- line 236: `participantIds` CONTAINS + `startTime`

**Call sites**, all in `calendar_service.dart`: `lib/features/calendar/data/services/calendar_service.dart:19-279 (SimpleCalendarService) @ 7808a91`
- Reads: `:19`, `:42`, `:175`, `:229`
- Writes: `:92`, `:136`, `:152`, `:263`, `:279`

## 7. Where are `chatRooms`, `conversations`, `messages`, `typing`, `discussion_boards`, `threads`, `replies` and `likes` defined and accessed?

### Two chat systems, one chat screen

The client has two chat systems:

- **`chatRooms`** is run by `SimpleChatProvider`. `lib/features/chat/presentation/providers/chat_provider.dart:8 (SimpleChatProvider) @ 7808a91` The provider is registered at `lib/shared/core/app_providers.dart:47 (AppProviders) @ 7808a91`. Screens that use it:
  - the chat list
  - user selection
  - group creation
  - class selection
  - `user_list`
- **`conversations`** is run by `FlyerChatScreen` through `FirestoreChatController`. `lib/features/chat/presentation/screens/flyer_chat_screen.dart:75 (_FlyerChatScreenState) @ 7808a91`

Every chat route builds `FlyerChatScreen(conversationId: chatRoomId)`. `lib/shared/routing/app_router.dart:374-418 (AppRouter) @ 7808a91` and `lib/shared/routing/app_router.dart:574-581 (createRouter) @ 7808a91` This means a `chatRooms` id picked from the chat list is opened as `conversations/{chatRoomId}`. `SimpleChatProvider.loadChatMessages` and `sendMessage` have no callers outside `chat_provider.dart`.

When the conversation document is missing, `_ensureConversationExists` creates it with participants set to `conversationId.split('_')`. `lib/features/chat/data/controllers/firestore_chat_controller.dart:65-73 (FirestoreChatController) @ 7808a91`

### Field-name differences between the two systems

| Field | `chatRooms` system | `conversations` system |
|---|---|---|
| message sender | `senderId` | `authorId` |
| message time | `timestamp` | `createdAt` |
| message body | `content`, plus `text` from the provider | `text`, plus `attachments[]` |
| parent members | `participantIds` | `participants` and `participantIds`; the server reads `participants ?? participantIds` |
| `lastMessage` | a string | a map `{text, authorId, authorName, createdAt}` |
| unread | `unreadCounts` map plus `unreadCount` int | an `unreadCount.{uid}` map |
| last activity | `lastMessageTime` | `lastActivity` |

The `chatRooms` side of each row comes from the provider's raw message write. `lib/features/chat/presentation/providers/chat_provider.dart:153-170 (sendMessage) @ 7808a91` Those messages are read raw, ordered by `timestamp`. `lib/features/chat/presentation/providers/chat_provider.dart:60-73 (loadChatMessages) @ 7808a91` The `Message` model uses the same field names. Its `toFirestore` has one caller in `lib/features/chat`, which embeds the result under `scheduled_messages/{id}.message`. `lib/features/chat/data/services/scheduled_messages_service.dart:111-117 (scheduleMessage) @ 7808a91` (An earlier draft said `Message.toFirestore` writes the `chatRooms` messages; the verifier found its only caller writes `scheduled_messages`.) The `conversations` side comes from the `sendMessage` object literal. `functions/src/chatFunctions.ts:86-114 (sendMessage) @ 7808a91`

### `chatRooms`

**Shape.** `ChatRoom.fromFirestore`/`toFirestore` defines the shape. `lib/features/chat/domain/models/chat_room.dart:95-155 (ChatRoom) @ 7808a91` Its fields:

- `name`, `type`, `classId`, `createdBy`, `mutedUsers`
- `participantIds`, `participants[]`
- `lastMessage`, `lastMessageTime`, `lastMessageSenderId`
- `unreadCount`, `unreadCounts`
- `createdAt`, `updatedAt`

Each entry in `participants[]` is a `ParticipantInfo` with `{id, name, role, photoUrl}`. Nothing in `lib` calls `ChatRoom.fromFirestore`; the provider reads and writes raw maps.

**Writes** (all in `chat_provider.dart` except as noted):

- direct-chat create at `:115-123`
- group create at `:303-316`
- mark-read at `:193`, which writes `lastReadTime`, a field the model does not have

**Indexes.**
- `chatRooms`: `participantIds` CONTAINS + `lastMessageTime` DESC. `firestore.indexes.json:290 (chatRooms) @ 7808a91`
- `chat_rooms` (legacy): `firestore.indexes.json:254 (chat_rooms) @ 7808a91` and `firestore.indexes.json:272 (chat_rooms) @ 7808a91`. No code references `chat_rooms`.

**Call sites** (all in `chat_provider.dart` except as noted):

- reads:
  - `:34-38`, a stream on `participantIds` ordered by `lastMessageTime`
  - `:98-102`
  - `:210-213`
  - `lib/features/chat/presentation/screens/user_list.dart:67-71 (SimpleUserList) @ 7808a91`
- creates: `:125`, `:318`
- updates:
  - `:173-180`, last-message fields
  - `:192-194`
  - `:234-236`, arrayRemove on `participantIds`
- delete: `:270`

### `conversations`

**Shape.** There is no model class. The document id is the two uids sorted and joined with `_`. `lib/features/chat/presentation/screens/flyer_chat_screen.dart:102-122 (_FlyerChatScreenState) @ 7808a91` Creates also happen at `lib/features/chat/data/controllers/firestore_chat_controller.dart:67-73 (_ensureConversationExists) @ 7808a91`. There is no index.

**Call sites:**

- reads:
  - `lib/features/chat/presentation/screens/flyer_chat_screen.dart:107-110 (_getOrCreateConversation) @ 7808a91`
  - `lib/features/chat/data/controllers/firestore_chat_controller.dart:54-57 (_ensureConversationExists) @ 7808a91`
  - `functions/src/chatFunctions.ts:13-14 (ensureConversationMembership) @ 7808a91`
- sets: `lib/features/chat/presentation/screens/flyer_chat_screen.dart:114 (_getOrCreateConversation) @ 7808a91`, `lib/features/chat/data/controllers/firestore_chat_controller.dart:67 (_ensureConversationExists) @ 7808a91`
- updates:
  - `functions/src/chatFunctions.ts:105 (sendMessage) @ 7808a91`, `:125` (sendMessage)
  - `functions/src/chatFunctions.ts:188 (markMessagesAsRead) @ 7808a91`

### `messages`

**Shape A: `chatRooms/{id}/messages`.** The provider writes raw maps with the same field names as the `Message` model; the model's `toFirestore` is used only for `scheduled_messages`. `lib/features/chat/domain/models/message.dart:91-193 (Message) @ 7808a91` The model's fields:

- `senderId`, `senderName`, `senderRole`
- `content`, `timestamp`, `isRead`
- `attachmentUrl`, `attachmentType`
- `scheduledFor`, `isScheduled`, `status`
- `isEdited`, `editedAt`

`Message.fromFirestore` has no callers. The provider's raw write adds `text` and `imageUrl`. `lib/features/chat/presentation/providers/chat_provider.dart:153-164 (sendMessage) @ 7808a91`

**Shape B: `conversations/{id}/messages`.** Defined by an object literal in `sendMessage`, with fields `{id, authorId, authorName, authorRole, text, attachments, createdAt, sentAt, metadata}`. `functions/src/chatFunctions.ts:86-96 (sendMessage) @ 7808a91` `markMessagesAsRead` adds `seenAt` and `readBy.{uid}`. The reader `_convertToFlyerMessage` reads:

- `sentAt`, `seenAt`, `failedAt`
- `attachments[0]`
- `authorId`, `createdAt`, `text`, `metadata`

`lib/features/chat/data/controllers/firestore_chat_controller.dart:175-243 (FirestoreChatController) @ 7808a91`

**Indexes.**
- `conversationId` + `timestamp`: `firestore.indexes.json:802 (messages) @ 7808a91` and `:838`
- `senderId` + `timestamp`: `:820` and `:856`

Neither message shape has a `conversationId` field, and no index covers `createdAt`.

**Call sites:**

- `chatRooms/{id}/messages`: in `chat_provider.dart`
  - read at `:60-66` (`timestamp` DESC, limit 100)
  - create at `:166-170`
  - batch delete at `:256-267`
- `conversations/{id}/messages`:
  - reads in `firestore_chat_controller.dart`
    - `:93-99` (limit 30)
    - `:128-133` (stream)
    - `:516-523` (paging)
  - set at `functions/src/chatFunctions.ts:99-102 (sendMessage) @ 7808a91`
  - batch update at `:177-184`
  - The client writes these only through the `sendMessage` and `markMessagesAsRead` callables.

### `typing` (`conversations/{id}/typing/{uid}`)

**Shape.** `{isTyping, startedAt, userName}`, with no model class and no index. `functions/src/chatFunctions.ts:238-246 (updateTypingStatus) @ 7808a91`

**Call sites:**

- read: a stream at `lib/features/chat/data/controllers/firestore_chat_controller.dart:248-252 (FirestoreChatController) @ 7808a91`
- writes, all in `chatFunctions.ts`:
  - set at `:242`
  - delete at `:256`
  - delete at `:265`

### `discussion_boards`

**Shape.** `SimpleDiscussionBoard` defines `title`, `description`, `createdBy`, `createdAt`, `threadCount`, `isPinned` and `tags`. `lib/features/discussions/presentation/providers/discussion_provider.dart:36-60 (SimpleDiscussionBoard) @ 7808a91`

**Indexes.** `isPinned` + `createdAt` (`firestore.indexes.json:424 (discussion_boards) @ 7808a91`) and `isPinned` + `updatedAt` (`:442`). The model has no `updatedAt`.

**Call sites:**

- stream: `lib/features/discussions/presentation/providers/discussion_provider.dart:329-333 (loadBoards) @ 7808a91`
- create: `lib/features/discussions/presentation/providers/discussion_provider.dart:452 (createBoard) @ 7808a91`
- `threadCount`: `+1` at `lib/features/discussions/presentation/providers/discussion_provider.dart:580-582 (createThread) @ 7808a91`; `-1` at `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:441-444 (_showDeleteThreadDialog) @ 7808a91`
- delete: `lib/features/discussions/presentation/screens/discussion_boards_screen.dart:356-359 (_showDeleteBoardDialog) @ 7808a91`. This removes only the board document.

### `threads` (`discussion_boards/{b}/threads`)

**Shape.** `SimpleDiscussionThread` defines `boardId`, `title`, `content`, `authorId`, `authorName`, `createdAt`, `replyCount`, `likeCount`, `isPinned` and `isLocked`. `lib/features/discussions/presentation/providers/discussion_provider.dart:93-123 (SimpleDiscussionThread) @ 7808a91`

**Indexes.** `firestore.indexes.json:1084 (threads) @ 7808a91` (collection group), `:1102` and `:1120`.

**Call sites:**

- reads: stream at `lib/features/discussions/presentation/providers/discussion_provider.dart:473-479 (loadThreadsForBoard) @ 7808a91`; get at `lib/features/discussions/presentation/screens/thread_detail_screen.dart:42-47 (_loadThreadAndReplies) @ 7808a91`
- create: `lib/features/discussions/presentation/providers/discussion_provider.dart:573-577 (createThread) @ 7808a91`
- `replyCount`: `+1` at `lib/features/discussions/presentation/screens/thread_detail_screen.dart:137-142 (_addReply) @ 7808a91`; `-1` at `:521-526`
- `likeCount`: `±1` at `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:295-306 (threadRef) @ 7808a91`
- delete: `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:433-438 (_showDeleteThreadDialog) @ 7808a91`. Its `replies` and `likes` subcollections are not deleted.

### `replies` (`.../threads/{t}/replies`)

**Shape.** There is no model class. The write map is `{content, authorId, authorName, createdAt}`. `likeCount` is read and incremented but is not set when a reply is created. `lib/features/discussions/presentation/screens/thread_detail_screen.dart:123-134 (_addReply) @ 7808a91` There is no index.

**Call sites** (all in `thread_detail_screen.dart`):

- reads: get at `:56-63`; stream at `:75-83`
- create: `:123-134`
- `likeCount`: `:480`, `:491`
- delete: `:511-518`. Its `likes` subcollection is not deleted.

### `likes`

**Shape.** `{userId, likedAt}`, keyed by uid, with no model class and no index. Two writers produce it:

- `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:300-303 (likeRef) @ 7808a91`
- `lib/features/discussions/presentation/screens/thread_detail_screen.dart:487-490 (_toggleLike) @ 7808a91`

**Call sites:**

- `threads/{t}/likes/{uid}`:
  - reads: `lib/features/discussions/presentation/providers/discussion_provider.dart:633-640 (_updateThreadLikes) @ 7808a91`, `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:287-290 (_buildThreadCard) @ 7808a91`
  - delete: `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:294 (likeRef) @ 7808a91`
  - set: `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:300 (likeRef) @ 7808a91`
- `replies/{r}/likes/{uid}`:
  - read: `lib/features/discussions/presentation/screens/thread_detail_screen.dart:441-450 (_checkIfLiked) @ 7808a91`
  - delete: `lib/features/discussions/presentation/screens/thread_detail_screen.dart:479 (_toggleLike) @ 7808a91`
  - set: `lib/features/discussions/presentation/screens/thread_detail_screen.dart:487 (_toggleLike) @ 7808a91`

## 8. Where are `studentPoints`, `behaviors`, `history`, `activities`, the `jeopardy_*` collections, `oauth_pkce_challenges` and `_rate_limits` defined and accessed?

### `studentPoints` (`classes/{c}/studentPoints/{studentId}`)

**Shapes.** Three definitions exist:

- **Client model.** `StudentPointsAggregate` has `studentId`, `studentName`, `classId`, `totalPoints`, `positivePoints`, `negativePoints`, `behaviorCounts` (a map), `lastUpdated`, `lastBehaviorName` and `lastPoints`. `lib/features/behavior_points/data/models/student_points_aggregate.dart:8-70 (StudentPointsAggregate) @ 7808a91`
- **Server write.** A merge-set writes `studentId`, `studentName`, the incremented counters, `behaviorCounts.<behaviorId>`, `lastUpdated` and `lastUpdatedBy`. `functions/src/behaviorPoints.ts:106-119 (awardBehaviorPoints) @ 7808a91`
- **Older model.** `StudentPoints` is imported by nothing. `lib/features/behavior_points/domain/models/student_points.dart:23 (StudentPoints) @ 7808a91`

**Disagreements.**
- The server never writes `classId`, `lastBehaviorName` or `lastPoints`, so those come back empty or null on the client.
- The server writes `lastUpdatedBy`, which the model does not have.
- `behaviorCounts` is written with a dotted key and read as a nested map. `lib/features/behavior_points/data/models/student_points_aggregate.dart:46 (StudentPointsAggregate) @ 7808a91` Whether `set` with merge treats the dotted key as a path is SDK behavior (UNVERIFIED).

**Indexes.** None.

**Call sites.**

| Operation | Site | Citation |
|---|---|---|
| Server write | set at `:102-119` (award); `batch.update` at `:236-251` (undo) | `functions/src/behaviorPoints.ts:236-251 (undoBehaviorPoints) @ 7808a91` |
| Server read | `:332-335` (summary) | `functions/src/behaviorPoints.ts:332-335 (getClassPointsSummary) @ 7808a91` |
| Client read | stream in `watchClassPointsSummary` | `lib/features/behavior_points/domain/services/behavior_points_service.dart:137-162 (watchClassPointsSummary) @ 7808a91` |
| Client read | `getStudentPoints` at `:242-247` (no callers) | `lib/features/behavior_points/domain/services/behavior_points_service.dart:242-247 (getStudentPoints) @ 7808a91` |

### `history` (`.../studentPoints/{s}/history/{operationId}`, also queried as a collection group)

**Server write shape.** `operationId`, `studentId`, `studentName`, `behaviorId`, `behaviorName`, `points`, `type`, `teacherId`, `teacherName`, `awardedBy`, `awardedByName`, `timestamp`, `awardedAt`, `isUndone`, `classId`, `gender`, `gradeLevel`, `studentAvatarUrl` and `note`. An undo adds `undoneBy` and `undoneAt`. `functions/src/behaviorPoints.ts:125-145 (awardBehaviorPoints) @ 7808a91`

**Client model.** `BehaviorHistoryEntry.fromMap` reads `teacherId ?? awardedBy` and `timestamp ?? awardedAt`. Its `toFirestore` has no callers. `lib/features/behavior_points/data/models/behavior_history_entry.dart:7-118 (BehaviorHistoryEntry) @ 7808a91` A second reader, `BehaviorPoint.fromFirestore` in the provider, also has no callers. `lib/features/behavior_points/presentation/providers/behavior_point_provider.dart:47-93 (BehaviorPoint) @ 7808a91`

**Indexes.** Four collection-group indexes, all ending in `awardedAt` desc. None includes `timestamp`.

| Line | Fields before `awardedAt` |
|---|---|
| `:1138` | `classId`, `isUndone` |
| `:1160` | adds `studentId` |
| `:1186` | adds `gender` |
| `:1212` | adds `type` |

`firestore.indexes.json:1138 (history) @ 7808a91`

**Call sites.**

- **Server, in `behaviorPoints.ts`:**
  - `awardBehaviorPoints`: idempotency read and write at `:86-99` and `:125`
  - `undoBehaviorPoints`: read and write at `:213-223` and `:254`
  - `getBehaviorHistory`: collection-group query at `:426-472` and count at `:493-509`

  `functions/src/behaviorPoints.ts:426-472 (getBehaviorHistory) @ 7808a91`
- **Client, in `watchRecentHistory`:** a collection-group stream on `classId` and `isUndone`, ordered by `awardedAt`. `lib/features/behavior_points/domain/services/behavior_points_service.dart:170-176 (watchRecentHistory) @ 7808a91`
- **Client, in `watchStudentHistory`:** at `:208-216`, with no callers.
- **Indirect read:** the `getBehaviorHistory` callable, parsed with `fromMap`. `lib/features/behavior_points/presentation/widgets/behavior_history_panel.dart:123-136 (_BehaviorHistoryPanelState) @ 7808a91`

**Disagreements.**
- **Date range filters on one field, orders on another.** The query filters the date range on `timestamp` and orders by `awardedAt`, the field every index uses. `functions/src/behaviorPoints.ts:445-461 (getBehaviorHistory) @ 7808a91`
- **Callable dates come back as strings.** The callable turns timestamps into ISO strings. The client's `parseTimestamp` handles null, `Timestamp`, `DateTime` and `{_seconds}`, so a string falls back to `DateTime.now()`. `lib/features/behavior_points/data/models/behavior_history_entry.dart:54-66 (BehaviorHistoryEntry) @ 7808a91`

### `behaviors` (`classes/{c}/behaviors/{id}`)

**Shape.** `Behavior` has `name`, `description`, `points`, `type`, `iconName`, `iconCodePoint`, `isCustom`, `teacherId`, `classId`, `createdAt` and `updatedAt`. `lib/features/behavior_points/domain/models/behavior.dart:29-218 (Behavior) @ 7808a91`

**Index.** `name`. `firestore.indexes.json:1238 (behaviors) @ 7808a91`

**Call sites.** All are on the client; the server has none.

| Operation | Site |
|---|---|
| Read, ordered by `name` | `watchClassBehaviors`, `:262-282` |
| Merge-set | `saveBehavior`, `:297-317` |
| Delete | `deleteBehavior`, `:332-337` |

`lib/features/behavior_points/domain/services/behavior_points_service.dart:262-337 (watchClassBehaviors) @ 7808a91`

**Disagreements.** `saveBehavior` never writes `iconName`, and it overwrites `createdAt` on every save.

### `activities`

**Shape.** `ActivityModel` has `type` (an `ActivityType` name), `title`, `description`, `timestamp`, `userId`, `userName`, `classId`, `className`, `assignmentId`, `metadata` and `isRead`. `lib/features/dashboard/domain/models/activity_model.dart:14-78 (ActivityModel) @ 7808a91`

**Indexes.** `classId` + `timestamp` at line 4, and `teacherId` + `timestamp` at line 22. `firestore.indexes.json:4 (activities) @ 7808a91`

**Client call sites.**

- **`dashboard_service.dart`:**
  - reads: `getTeacherActivities` on `teacherId` at `:17-22`; `getStudentActivities` on `classId` whereIn at `:47-52`
  - write: `logActivity` at `:135`. Its only caller, `DashboardProvider.logActivity`, has no callers.

  `lib/features/dashboard/data/services/dashboard_service.dart:17-135 (DashboardService) @ 7808a91`
- **`bulk_import_service.dart`:** write in `_logBulkImportActivity`. `lib/features/admin/data/services/bulk_import_service.dart:346 (_logBulkImportActivity) @ 7808a91`
- **`user_management_service.dart`:** read on `userId` at `:338-343`; write at `:363-369`.
- **`admin_provider.dart`:** reads at `:145-149` and `:214-218`.

**Server call sites.** All writes are `add`.

- `adminFunctions.ts`: `:160`, `:263`, `:365`, `:441`, `:507`. A read at `:569-572`. `functions/src/adminFunctions.ts:160 (createStudentAccount) @ 7808a91`
- `bulkImport.ts`: `:395`.
- `authBlocking.ts`: `:84`. `functions/src/authBlocking.ts:84 (autoAssignRole) @ 7808a91`

**Disagreements.**
- **`teacherId` is never written.** No writer writes `teacherId`, yet `getTeacherActivities` filters on it and the line-22 index exists for it.
- **`userId` is nested on the server.** The server puts the user id in `details.userId`, while `getUserDetails` filters on top-level `userId`.
- **`type` values do not match.** Writer values such as `user_created` and `bulk_import` are not `ActivityType` names, and `fromFirestore` maps unknown values to `announcement`. `lib/features/dashboard/domain/models/activity_model.dart:47-50 (ActivityModel) @ 7808a91`

### `jeopardy_games`, `jeopardy_questions`, `jeopardy_sessions`

**No reachable code reads or writes these collections.** Two classes are named `SimpleJeopardyProvider`:

- **The wired one** is a stub with no Firestore import. Its methods return stub data. `lib/features/games/presentation/providers/jeopardy_provider.dart:6-149 (SimpleJeopardyProvider) @ 7808a91` It is imported at `lib/shared/core/app_providers.dart:17 (import) @ 7808a91`.
- **The other one** is under `lib/features/jeopardy/`, and nothing imports it.

**Shape (model).** `JeopardyGame` has `title`, `teacherId`, `categories[]` (each `{name, questions[]}`, with questions nested), `doubleJeopardyCategories`, `finalJeopardy`, `createdAt`, `updatedAt`, `isPublic`, `gameMode`, `assignedClassIds`, `dailyDoubles[]` and `randomDailyDoubles`. `lib/features/games/domain/models/jeopardy_game.dart:4-61 (JeopardyGame) @ 7808a91`

`JeopardyGameSession` has `gameId`, `teacherId`, `classId`, `startedAt`, `endedAt`, `players[]`, `teams[]`, `currentRound`, `answeredQuestions` and `isActive`. `lib/features/games/domain/models/jeopardy_game.dart:323 (JeopardyGameSession) @ 7808a91`

**Indexes.** Only `jeopardy_games` has any, all on `teacherId`, `isPublic` and `updatedAt`. `firestore.indexes.json:744-784 (jeopardy_games) @ 7808a91`

**Call sites, all in the unreachable provider.** `lib/features/jeopardy/presentation/providers/jeopardy_provider.dart:35-330 (SimpleJeopardyProvider) @ 7808a91`

| Collection | Lines |
|---|---|
| `jeopardy_games` | `:35-39`, `:77-79`, `:289`, `:313`, `:327-330` |
| `jeopardy_questions` | `:105`, `:123-128`, `:209`, `:217-220`, `:303-309` |
| `jeopardy_sessions` | `:162-164`, `:187`, `:225-228`, `:238-241`, `:256`, `:271-274` |

**Disagreements.** The unreachable writer and the model differ:

| | Unreachable writer | Model |
|---|---|---|
| Owner and visibility | `createdBy`, `isPublished`, `playCount` | `teacherId`, `isPublic` |
| Questions | a separate `jeopardy_questions` collection | nested in categories |
| Sessions | `hostId`, `status`, `currentQuestion` | `teacherId`, `isActive`, `currentRound` |

### `oauth_pkce_challenges`

**Shape.** `PKCEChallenge` has `codeVerifier`, `expiresAt` (epoch ms), `createdAt` and an optional `clientId`. The document id is the OAuth `state`. `functions/src/types/oauth.types.ts:30-35 (PKCEChallenge) @ 7808a91`

**Indexes.** None.

**Call sites.** All are on the server.

- **`oauth.ts`:**
  - accessor at `:63-64`
  - set at `:123-129`
  - read at `:222`
  - deletes at `:229` and `:240`

  `functions/src/oauth.ts:123-129 (getOAuthUrl) @ 7808a91`
- **`cleanup.ts`:**
  - `cleanupExpiredPKCEChallenges` queries and batch-deletes at `:21-100`
  - a count at `:108`

  - `manualPKCECleanup` runs the same queries at `:131-163`.

  `functions/src/cleanup.ts:21-108 (cleanupExpiredPKCEChallenges) @ 7808a91`

### `_rate_limits`

**Shape.** `RateLimitRecord` has `count`, `firstCall` and `lastCall`. The document id is `${name}_${identifier}`. `functions/src/rate-limiter.ts:9-13 (RateLimitRecord) @ 7808a91`

**Indexes.** None.

**Call sites.** All are on the server.

- **Transaction:** reads, then sets or updates. `functions/src/rate-limiter.ts:32-80 (FirestoreRateLimiter) @ 7808a91` It is reached through `applyRateLimit`. `functions/src/security.ts:44 (applyRateLimit) @ 7808a91`
- **`cleanupOldRateLimitRecords`:** at `:92-115`, with no callers.

## 9. What do the functions in `adminFunctions.ts`, `bulkImport.ts`, `oauth.ts` and `cleanup.ts` do, and what triggers each?

### Shared setup

- `index.ts` calls `admin.initializeApp()`. `functions/src/index.ts:14 (setGlobalOptions) @ 7808a91`
- Global options are maxInstances 10 and region us-east4. `functions/src/index.ts:29-32 (setGlobalOptions) @ 7808a91`
- All four modules are re-exported with `export *`. `functions/src/index.ts:38-50 (cleanup) @ 7808a91`

The callables in `adminFunctions.ts` and `bulkImport.ts` share one admin gate. It checks the Firestore document `users/{request.auth.uid}.role === "admin"`, not a token claim. It throws `unauthenticated` when there is no `request.auth`, and `permission-denied` when the role is not admin. `functions/src/adminFunctions.ts:51-61 (createStudentAccount) @ 7808a91`

None of the four files calls Storage or Messaging.

### `adminFunctions.ts`

All six exports are `onCall` with `{region: "us-east4", maxInstances: 10}`, and each one runs the admin gate.

| Function | Input | Auth calls | Firestore writes | Returns |
|---|---|---|---|---|
| `createStudentAccount` | `{email, password, displayName, gradeLevel, parentEmail, classIds, isGoogleAuth}` | `getUserByEmail` (if `isGoogleAuth`), `createUser` with `emailVerified: true`, `setCustomUserClaims({role:"student"})` | `users/{uid}.set`, batch `classes/{id}` `studentIds` arrayUnion, `activities.add` | `{success, userId, email, displayName, isGoogleAuth}` |
| `createTeacherAccount` | `{email, password, displayName}` | `createUser`, `setCustomUserClaims({role:"teacher"})` | `users/{uid}.set`, `activities.add` | `{success, userId, email, displayName}` |
| `createAdminAccount` | `{email, password, displayName}` | `createUser`, `setCustomUserClaims({role:"admin"})` | `users/{uid}.set`, `activities.add` | `{success, userId, email, displayName}` |
| `deleteUserAccount` | `{userId}` | `deleteUser` | `users/{userId}.delete()`, `activities.add` (`classes` untouched) | `{success, message}` |
| `resetUserPassword` | `{userId}` | `updateUser({password})` with a generated password | `activities.add` | `{success, newPassword, message}`: the plaintext password goes back to the caller |
| `getSystemStats` | none | — | reads all of `users` and `activities` from the last day | counts by role, plus online and recent-activity counts |

Citations for the table:
- `functions/src/adminFunctions.ts:47-193 (createStudentAccount) @ 7808a91`
- `functions/src/adminFunctions.ts:199-293 (createTeacherAccount) @ 7808a91`
- `functions/src/adminFunctions.ts:299-395 (createAdminAccount) @ 7808a91`
- `functions/src/adminFunctions.ts:401-464 (deleteUserAccount) @ 7808a91`
- `functions/src/adminFunctions.ts:470-529 (resetUserPassword) @ 7808a91`
- `functions/src/adminFunctions.ts:535-582 (getSystemStats) @ 7808a91`

Checks that reject input, all `invalid-argument`:

- **Student emails:** must be `@rosellestudent.org` or `@rosellestudent.com`. `functions/src/adminFunctions.ts:75-81 (createStudentAccount) @ 7808a91`
- **Student passwords:** 6 or more characters, unless `isGoogleAuth`. `functions/src/adminFunctions.ts:85-88 (createStudentAccount) @ 7808a91`
- **Teacher accounts:** `@roselleschools.org` and a password of 6 or more characters. `functions/src/adminFunctions.ts:227-234 (createTeacherAccount) @ 7808a91`
- **Admin accounts:** `@fermi-plus.com` and a password of 8 or more characters. `functions/src/adminFunctions.ts:328-335 (createAdminAccount) @ 7808a91`
- **Self-deletion:** an admin cannot delete their own account. `functions/src/adminFunctions.ts:425 (deleteUserAccount) @ 7808a91`

Errors are mapped two ways: `auth/email-already-exists` becomes `already-exists`, and anything else becomes `internal`. `functions/src/adminFunctions.ts:186-190 (createStudentAccount) @ 7808a91`

The password generator `generateSecurePassword` is not exported. It uses `crypto.randomBytes` with rejection sampling. `functions/src/adminFunctions.ts:14-41 (generateSecurePassword) @ 7808a91`

### `bulkImport.ts`

**`bulkImportStudents`**

`onCall` with `{region: "us-east4", maxInstances: 10, memory: "512MiB", timeoutSeconds: 300}`, behind the admin gate. `functions/src/bulkImport.ts:31-50 (bulkImportStudents) @ 7808a91`

1. **Input.** It takes `{users, csvData, sendPasswordResetEmails = true}`. `functions/src/bulkImport.ts:53 (bulkImportStudents) @ 7808a91` `parseCSV` requires `name` and `email` headers. `functions/src/bulkImport.ts:437-506 (parseCSV) @ 7808a91`
2. **Whole-request rejections.** These throw `invalid-argument`:
   - a CSV parse error
   - no users
   - more than 1000 users
   - any row whose email is missing or not a rosellestudent domain, or duplicated within the import

   `functions/src/bulkImport.ts:62-126 (bulkImportStudents) @ 7808a91`
3. **Existing users.** They are split out with `auth.getUserByEmail` via `Promise.allSettled`. If every user already exists, the function returns `success: false`. `functions/src/bulkImport.ts:129-152 (bulkImportStudents) @ 7808a91`
4. **Class validation.** It checks `classes/{classId}` exists, or queries `enrollmentCode == code.toUpperCase()` with `isActive == true`. Invalid classes are only logged. `functions/src/bulkImport.ts:167-202 (bulkImportStudents) @ 7808a91`
5. **Account creation.** It calls `auth.importUsers(records, {hash: {algorithm: "BCRYPT"}})`. Each record has a 28-character uid from `Math.random`, `emailVerified: true` and `customClaims {role: "student", gradeLevel}`. `functions/src/bulkImport.ts:206-248 (bulkImportStudents) @ 7808a91`
6. **Placeholder hashes.** Users without Google auth get a placeholder bcrypt hash made of random characters, not the hash of any known password. `functions/src/bulkImport.ts:221-225 (bulkImportStudents) @ 7808a91`
7. **`users` writes.** One unchunked batch of `users/{uid}.set` runs over all `newUsers`, not only those `importUsers` reported as succeeding. `functions/src/bulkImport.ts:256-329 (bulkImportStudents) @ 7808a91`
8. **Class membership.** It updates `classes/{classId}` with `studentIds` arrayUnion. `functions/src/bulkImport.ts:347-357 (bulkImportStudents) @ 7808a91`
9. **Reset links.** `generatePasswordResetLink` runs for each new user without Google auth. The link is only written to `logger.info`; nothing sends it. `functions/src/bulkImport.ts:361-379 (bulkImportStudents) @ 7808a91`
10. **Activity log.** It adds a `bulk_import` entry to `activities`. `functions/src/bulkImport.ts:395-406 (bulkImportStudents) @ 7808a91`

**`migrateStudentClassEnrollment`**

`onCall` (256MiB, 60s), behind the admin gate. `functions/src/bulkImport.ts:549-673 (migrateStudentClassEnrollment) @ 7808a91`

- It reads `users` where `role == "student"` and all of `classes`.
- It maps `className` to a class id by lowercase name.
- It sets `classId` and `enrolledClasses`, deletes `className`, and adds the user to `classes.studentIds` with arrayUnion.

### `oauth.ts`

All three functions are `onRequest` with `{cors: true, secrets: [GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET]}`. `functions/src/oauth.ts:21-22 (googleClientId) @ 7808a91`

None of them checks a Firebase ID token or App Check. What gates them is:

- **Rate limits.** `applyRateLimit` throws `resource-exhausted`. `functions/src/security.ts:38-51 (applyRateLimit) @ 7808a91` The limit is kept per IP in `_rate_limits/{name}_{ip}` by a transaction that lets the request through when the limiter fails. `functions/src/rate-limiter.ts:32-86 (FirestoreRateLimiter) @ 7808a91`
- **User-agent check.** It rejects a missing user-agent, or one that looks like a bot, curl, wget or python-requests. `functions/src/security.ts:70-100 (oauthValidator) @ 7808a91`

| Function | Rate limit | Input | Firestore | External / Auth | Returns |
|---|---|---|---|---|---|
| `getOAuthUrl` | 10/60s | `redirect_uri` query, localhost or 127.0.0.1 only | sets `oauth_pkce_challenges/{state}` to `{codeVerifier, expiresAt: now+600000, createdAt, clientId: ip}` | — | `{authUrl, state, codeVerifier}` |
| `exchangeOAuthCode` | 5/60s | body `{code, state, codeVerifier, redirectUri?}` | reads, then deletes, the PKCE doc before calling Google | Google token and userinfo endpoints; `getUserByEmail`, falling back to `createUser`; `createCustomToken(uid, {provider:"google.com", email})` | `{firebaseToken, googleTokens, user}` |
| `refreshOAuthToken` | 20/60s | body `{refreshToken}` | `_rate_limits` only | Google refresh grant | `{accessToken, expiresIn, idToken}` |

Citations for the table:
- `functions/src/oauth.ts:70-164 (getOAuthUrl) @ 7808a91`
- `functions/src/oauth.ts:170-345 (exchangeOAuthCode) @ 7808a91`
- `functions/src/oauth.ts:350-434 (refreshOAuthToken) @ 7808a91`

`exchangeOAuthCode` rejects:
- a malformed state or verifier (40-50 base64url characters required)
- a missing PKCE document
- a verifier that does not match the stored one

An expired document is deleted and the call throws `deadline-exceeded`. `functions/src/oauth.ts:203-237 (exchangeOAuthCode) @ 7808a91`

`exchangeOAuthCode` also does not check the email domain, assigns no role or claim, and writes nothing to `users`. `functions/src/oauth.ts:297-314 (exchangeOAuthCode) @ 7808a91`

### `cleanup.ts`

**`cleanupExpiredPKCEChallenges`**

`onSchedule` with `{schedule: "every 1 hours", timeZone: "America/New_York", retryCount: 3, memory: "256MiB"}`. It has no caller check. `functions/src/cleanup.ts:9-15 (cleanupExpiredPKCEChallenges) @ 7808a91`

- It deletes `oauth_pkce_challenges` where `expiresAt < now`, in batches of 500.
- It returns early when nothing has expired, so the second sweep (`createdAt` older than 30 days) only runs when at least one expired document was found. `functions/src/cleanup.ts:28-102 (cleanupExpiredPKCEChallenges) @ 7808a91`

**`manualPKCECleanup`**

A plain exported `async` function with no trigger wrapper. It is still re-exported through `index.ts`. `functions/src/cleanup.ts:129-171 (manualPKCECleanup) @ 7808a91`

The only `manualPKCECleanup` hit in the repository is its definition.

## 10. What do the functions in `chatFunctions.ts`, `behaviorPoints.ts`, `security.ts`, `rate-limiter.ts` and `migrate-usernames.ts` do, and which are exported?

### Exported from `index.ts`

`index.ts` re-exports `./chatFunctions` and `./behaviorPoints`, so they deploy. It has no export line for `./security`, `./rate-limiter` or `./migrate-usernames`. `functions/src/index.ts:35-59 (chatFunctions) @ 7808a91` `security.ts` is reached only because `oauth.ts` imports it. `functions/src/oauth.ts:5-11 (import) @ 7808a91` No file imports `migrate-usernames.ts`.

None of the five modules has a schedule, Firestore-event or auth-event trigger.

### `chatFunctions.ts`

All four exports are v2 `https.onCall` with `maxInstances: 10, region: "us-east4"`. The module creates `admin.firestore()`, `admin.messaging()` and `admin.storage()` when it loads. `functions/src/chatFunctions.ts:5-7 (db) @ 7808a91`

**Membership check.** The helper `ensureConversationMembership` reads `conversations/{id}`. It throws `not-found` when the document is missing, and `permission-denied` when the caller is not in `participants` (falling back to `participantIds`). `functions/src/chatFunctions.ts:13-34 (ensureConversationMembership) @ 7808a91`

**Error handling.** Each callable wraps its body in a catch that rethrows every error as `internal`, including the membership errors. Only the checks that run before the `try` reach the client with their own codes. `functions/src/chatFunctions.ts:132-137 (sendMessage) @ 7808a91`

**`sendMessage`**
- **Input:** `{conversationId, text, attachments}`.
- **Checks:** `unauthenticated` when there is no auth; `invalid-argument` when `conversationId` is missing, or both `text` and `attachments` are missing. `functions/src/chatFunctions.ts:43-69 (sendMessage) @ 7808a91`
- **Reads:** `users/{senderId}`.
- **Writes `conversations/{id}/messages/{newId}`** with `{id, authorId, authorName, authorRole, text, attachments, createdAt, sentAt, metadata}`. `attachments` is stored without checks. `functions/src/chatFunctions.ts:75-102 (sendMessage) @ 7808a91`
- **Updates the conversation:** sets `lastMessage`, `lastActivity` and the sender's `unreadCount.{uid}=0`, and increments each other participant's count. `functions/src/chatFunctions.ts:105-126 (sendMessage) @ 7808a91`

**`markMessagesAsRead`**
- **Input:** `{conversationId, messageIds}`.
- **Writes, in one batch:** `seenAt` and `readBy.{uid}` on each message, and `unreadCount.{uid}=0` on the conversation.
- **No limit** on the length of `messageIds`.

`functions/src/chatFunctions.ts:146-192 (markMessagesAsRead) @ 7808a91`

**`updateTypingStatus`**
- **Input:** `{conversationId, isTyping}`.
- **When true:** sets `conversations/{id}/typing/{uid}` to `{isTyping, startedAt, userName}`, then starts an 11-second `setTimeout` that deletes the document after the handler has returned.
- **When false:** deletes the document.

`functions/src/chatFunctions.ts:209-265 (updateTypingStatus) @ 7808a91`

**`uploadChatFile`**
- **Input:** `{conversationId, fileName, mimeType, base64Data, fileSize}`, with 512MiB of memory.
- **Checks:** rejects a client-supplied `fileSize` over 10 MB (the decoded buffer is never measured) and MIME types outside 11 allowed types. `functions/src/chatFunctions.ts:283-331 (uploadChatFile) @ 7808a91`
- **Storage:** saves `chat-attachments/{conversationId}/{uid}/{ts}_{sanitizedName}` and returns a signed read URL that expires `03-01-2500`. It writes nothing to Firestore. `functions/src/chatFunctions.ts:338-363 (uploadChatFile) @ 7808a91`

**`sendPushNotifications`** (not exported)
- **Reads:** `users/{id}.fcmToken` for each recipient.
- **Sends:** calls `messaging.sendEachForMulticast` with data `{type: "chat", conversationId}`.
- **Errors:** caught and swallowed.

`functions/src/chatFunctions.ts:386-428 (sendPushNotifications) @ 7808a91`

### `behaviorPoints.ts`

All four exports are v2 `onCall` with `maxInstances: 50, region: "us-east4"`. None of them calls Admin Auth, Storage or Messaging.

**`awardBehaviorPoints`**
- **Checks, in order:**
  1. `unauthenticated`
  2. `permission-denied` unless `users/{uid}.role === "teacher"`
  3. `not-found` when the class is missing
  4. `permission-denied` unless `classes/{classId}.teacherId` (or `teacherUID`) equals the caller

  `functions/src/behaviorPoints.ts:31-77 (awardBehaviorPoints) @ 7808a91`
- **No check** on the type or range of `points`.
- **Idempotency:** the operation id is `${teacherId}_${studentId}_${behaviorId}_${Date.now()}`, and an existing history document with that id returns `{success: false}`. `functions/src/behaviorPoints.ts:80-99 (awardBehaviorPoints) @ 7808a91`
- **Writes, in one batch:**
  - a merge into `classes/{c}/studentPoints/{s}` with incremented `totalPoints`, `positivePoints`, `negativePoints` and `behaviorCounts.{id}`
  - a history document with `operationId`, student, behavior, `points`, `type`, teacher fields, `timestamp`, `awardedAt`, `isUndone: false`, `classId`, `gender`, `gradeLevel`, `studentAvatarUrl` and `note`

  `functions/src/behaviorPoints.ts:102-145 (awardBehaviorPoints) @ 7808a91`

**`undoBehaviorPoints`**
- **Checks:** the same four as `awardBehaviorPoints`.
- **Writes:** reverses the increments, then marks the history entry `isUndone`, `undoneBy`, `undoneAt`.

`functions/src/behaviorPoints.ts:162-258 (undoBehaviorPoints) @ 7808a91`

**`getClassPointsSummary`**
- **Callers:** only a teacher who owns the class. Students and every other role get `permission-denied`.
- **Reads:** all of `classes/{c}/studentPoints`.
- **Returns:** `{success, summaries}`.

`functions/src/behaviorPoints.ts:274-335 (getClassPointsSummary) @ 7808a91`

**`getBehaviorHistory`**
- **Teachers:** must own the class.
- **Students:** have `studentId` forced to their own uid instead of a membership check. `functions/src/behaviorPoints.ts:394-422 (getBehaviorHistory) @ 7808a91`
- **Query:** a `collectionGroup('history')` query on `classId ==` and `isUndone == false`, with optional `studentId`, `gender`, `type` and `timestamp` range, then `orderBy awardedAt desc`, `offset` and `limit` (default 50).
- **Count:** a `count()` query with the same filters minus the date range. `functions/src/behaviorPoints.ts:426-509 (getBehaviorHistory) @ 7808a91`

### `security.ts` (helpers only)

`createRateLimiter` and `oauthRateLimiters` set three limits:

| Limiter | Limit |
|---|---|
| `oauth_get_url` | 10 calls per 60 s |
| `oauth_exchange` | 5 calls per 60 s |
| `oauth_refresh` | 20 calls per 60 s |

`functions/src/security.ts:8-35 (oauthRateLimiters) @ 7808a91`

| Helper | What it does |
|---|---|
| `applyRateLimit` | Turns any limiter error into `resource-exhausted`. |
| `oauthValidator` | Returns booleans: user-agent, redirect URI (localhost or 127.0.0.1), and the state and verifier format (40–50 base64url characters). |
| `applySecurityHeaders` | Sets six response headers. |
| `getClientIdentifier` | Takes the first `x-forwarded-for` entry, then `x-real-ip`, the remote address, `req.ip`, or `"unknown"`. |

`functions/src/security.ts:38-198 (applyRateLimit) @ 7808a91`

### `rate-limiter.ts` (helpers only)

**`FirestoreRateLimiter.rejectOnQuotaExceededOrRecordUsage`** runs a transaction on `_rate_limits/{name}_{id}` that writes `{count, firstCall, lastCall}`.
- It throws `Error("Rate limit exceeded")` when `count >= maxCalls`.
- Any other error is logged and swallowed, so the request goes through.

`functions/src/rate-limiter.ts:15-88 (FirestoreRateLimiter) @ 7808a91`

**`cleanupOldRateLimitRecords`** batch-deletes up to 500 old `_rate_limits` documents. Nothing in `functions/src` calls it. `functions/src/rate-limiter.ts:92-115 (cleanupOldRateLimitRecords) @ 7808a91`

### `migrate-usernames.ts` (not deployed from `index.ts`)

**`migrateUsernamesToPublic`**
- **Trigger and caller:** a v2 `onCall` for callers whose `users` role is teacher or admin.
- **Reads:** `users` where `username != null`.
- **Writes:** `public_usernames/{lowercased username}` as `{uid, role, migratedAt}`, in batches of 500, skipping usernames that already exist.

`functions/src/migrate-usernames.ts:12-138 (migrateUsernamesToPublic) @ 7808a91`

**`migrateUsernamesHttp`**
- **Trigger:** a v2 `onRequest`.
- **Auth:** requires a `Bearer` header, verifies it with `admin.auth().verifyIdToken`, and applies the same role check.
- **Work:** calls the internal `runMigration`, which does the same copy.

`functions/src/migrate-usernames.ts:146-251 (migrateUsernamesHttp) @ 7808a91`

The deploy configuration beyond `functions/package.json`'s `"main": "lib/index.js"` could not be checked, because `firebase.json` is not tracked at this commit. `functions/package.json:17 (main) @ 7808a91`

## 11. How does the client register for, receive and display push notifications?

Android and iOS register for FCM. Web never registers and shows an in-app SnackBar instead. No code anywhere shows a local notification. Tapping a push does nothing, because no code installs the navigation callback.

### Registration

**Platforms.** Messaging is set up on Android and iOS only:
- `_initializeDeferredServices` adds `_initializeFirebaseMessaging` only when `!kIsWeb && _isFirebaseMessagingSupported()`, which is true for Android and iOS. `lib/shared/core/app_initializer.dart:54-89 (_initializeDeferredServices) @ 7808a91`
- Web is blocked twice more:
  - `_initializeFirebaseMessaging` returns early on web. `lib/shared/core/app_initializer.dart:227-230 (AppInitializer) @ 7808a91`
  - `FirebaseMessagingService.initialize` starts with `if (kIsWeb) return`. `lib/features/notifications/data/services/firebase_messaging_service.dart:46 (initialize) @ 7808a91`

  So the web VAPID-key branch in `_updateFCMToken` can never run.

**`initialize`, in order.** `lib/features/notifications/data/services/firebase_messaging_service.dart:45-107 (initialize) @ 7808a91`
1. Calls `deleteToken()`.
2. Requests permissions.
3. Registers the background handler, `onMessage` and `onMessageOpenedApp`.
4. Checks `getInitialMessage`.
5. Sets the iOS foreground presentation to alert, badge and sound.
6. Fetches and saves the token.
7. Listens on `onTokenRefresh`.

Exceptions are only logged.

**Permissions.**
- FCM calls `requestPermission` only on iOS and macOS. `lib/features/notifications/data/services/firebase_messaging_service.dart:124-146 (_requestPermissions) @ 7808a91`
- Separately, on Android and iOS, `NotificationService.requestPermissions()` asks through `flutter_local_notifications`. `lib/features/notifications/data/services/notification_service.dart:63-96 (requestPermissions) @ 7808a91`

**Token storage.** `_saveFCMToken` does nothing when no user is signed in. Otherwise it makes two writes:
- `users/{uid}.update({fcmToken, fcmTokenUpdatedAt, platform})`. This throws, and the error is logged, when the user document does not exist.
- `fcm_tokens/{uid}.set({token, userId, platform, updatedAt})`. There is one token per user, so the last device overwrites it.

`lib/features/notifications/data/services/firebase_messaging_service.dart:235-263 (_saveFCMToken) @ 7808a91`

**Sign-in does not save the token.** `_updateFCMToken` is called only from `initialize`. If nobody is signed in when the deferred init runs, the token is not saved until `onTokenRefresh` fires.

**Logout does not remove the token.** `deleteToken()` removes both the field and the `fcm_tokens` document, but nothing in `lib` calls it, so logout leaves the token behind. `lib/features/notifications/data/services/firebase_messaging_service.dart:400-423 (deleteToken) @ 7808a91`

### Receiving

**Server sender.** `sendPushNotifications` reads only `users/{id}.fcmToken`, never `fcm_tokens`. It sends `notification{title, body}` and `data{type: "chat", conversationId}` with `sendEachForMulticast`. `functions/src/chatFunctions.ts:386-425 (sendPushNotifications) @ 7808a91`

**Background and terminated.** The handler only logs; the OS draws the notification from the payload. `lib/features/notifications/data/services/firebase_messaging_service.dart:13-18 (_firebaseMessagingBackgroundHandler) @ 7808a91`

**Foreground.** `_handleForegroundMessage`:
- Calls `onMessage?.call`. Nothing in `lib` assigns `onMessage`.
- Skips a chat message when `_activeConversationId` matches.
- Otherwise calls `NotificationService().sendImmediateNotification(...)`.

`lib/features/notifications/data/services/firebase_messaging_service.dart:277-320 (_handleForegroundMessage) @ 7808a91`

`FlyerChatScreen` sets the active conversation after it builds the controller, and clears it in `dispose`. `lib/features/chat/presentation/screens/flyer_chat_screen.dart:78 (_FlyerChatScreenState) @ 7808a91` and `lib/features/chat/presentation/screens/flyer_chat_screen.dart:148 (dispose) @ 7808a91`

**Opened from a notification.** `_handleMessageOpenedApp` routes `chat`, `assignment`, `grade` and `behavior` through `_navigationCallback`. `lib/features/notifications/data/services/firebase_messaging_service.dart:323-356 (_handleMessageOpenedApp) @ 7808a91` `setNavigationCallback` has no callers in `lib`, so every tap-to-open path does nothing. `lib/features/notifications/data/services/firebase_messaging_service.dart:110-116 (setNavigationCallback) @ 7808a91`

### What is displayed

**Local notifications are never shown.** `flutter_local_notifications` is initialized, with an Android channel `teacher_dashboard_calls`, but nothing in the repository calls `.show(` or `zonedSchedule`. `lib/features/notifications/data/services/notification_service.dart:323-383 (_initializeLocalNotifications) @ 7808a91`

**Display methods are stubs.** `sendImmediateNotification`, `scheduleEventReminder` and `scheduleAssignmentReminder` only log and call `_storeNotificationRecord`. `lib/features/notifications/data/services/notification_service.dart:218-267 (NotificationService) @ 7808a91`

**The stored record.** `_storeNotificationRecord` writes `notifications.add({type, title, message, relatedId, scheduledFor, createdAt, status: 'scheduled'})`. The record has no `userId`, `read` or `body` field. `lib/features/notifications/data/services/notification_service.dart:295-319 (_storeNotificationRecord) @ 7808a91`

**What users see, by platform:**

| Platform | App state | What appears |
|---|---|---|
| Android, iOS | background or closed | the OS-drawn FCM notification |
| iOS | foreground | the system banner from the presentation options, even inside the open conversation |
| Android | foreground | nothing on screen, only a `notifications` document |

### Web in-app path

**Listener.** On web, `AuthProvider` starts `WebInAppNotificationService` after sign-in. `lib/features/auth/providers/auth_provider.dart:566-570 (AuthProvider) @ 7808a91` The service listens to `notifications where userId == uid && read == false orderBy createdAt desc limit 20`. For each document added, it calls `onNotificationReceived` and marks the document `delivered`. `lib/features/notifications/data/services/web_in_app_notification_service.dart:46-127 (WebInAppNotificationService) @ 7808a91`

**Display.** `WebNotificationHandler` wraps the router and shows a 4-second floating SnackBar. `lib/shared/widgets/web_notification_handler.dart:27-61 (WebNotificationHandler) @ 7808a91`

**The two paths do not connect.** Records from `_storeNotificationRecord` lack `userId` and `read`, so this query never matches them.

### Platform configuration

- **iOS.** `UIBackgroundModes` includes `remote-notification`. `ios/Runner/Info.plist:39-44 (UIBackgroundModes) @ 7808a91` `aps-environment` is `development`. `ios/Runner/Runner.entitlements:5-6 (aps-environment) @ 7808a91`
- **Android.** The manifest has no `POST_NOTIFICATIONS` permission, no FCM channel meta-data and no messaging service. `android/app/src/main/AndroidManifest.xml:1-50 (manifest) @ 7808a91`
- **Web.** There is no `firebase-messaging-sw.js`, and `index.html` unregisters every service worker. `web/index.html:65-85 (script) @ 7808a91`

### Open

- UNVERIFIED: whether plugin manifests merge `POST_NOTIFICATIONS` into the Android build.
- The other `notifications` writer, `firebase_notification_service.dart`, is listed in question 5.

## 12. Which client files call Cloud Functions callables, and with what arguments?

Eight client files call 18 distinct callables from 29 call sites. Every server callable runs in `us-east4`. `functions/src/index.ts:29-32 (setGlobalOptions) @ 7808a91` Three client files use the default `FirebaseFunctions.instance`. In the cloud_functions plugin that default is believed to be `us-central1`; it comes from the library, not this repository (UNVERIFIED). Nothing in `lib` or `test` sets an emulator or another region.

| Client file | Instance | Callable (line) | Arguments | Matches server? |
|---|---|---|---|---|
| `behavior_points_service.dart` | `us-east4` | `awardBehaviorPoints` (:38) | `classId, studentId, studentName, behaviorId, behaviorName, points, gender, gradeLevel, studentAvatarUrl, note` | yes |
| | | `undoBehaviorPoints` (:79) | `classId, studentId, historyId` | yes |
| | | `getClassPointsSummary` (:109) | `classId` | yes. No caller of this method was found. |
| `behavior_history_panel.dart` | `us-east4` | `getBehaviorHistory` (:122) | `BehaviorHistoryFilters.toMap` plus `classId, limit, offset` | no: sends `studentName`; the server filters only on `studentId` |
| `firestore_chat_controller.dart` | `us-east4` | `updateTypingStatus` (:292) | `conversationId, isTyping` | yes |
| | | `sendMessage` (:323) | `conversationId, text, attachments` | yes |
| | | `uploadChatFile` (:383, :473) | `conversationId, fileName, mimeType, base64Data, fileSize` | keys match. A `.jpg` produces `image/jpg`, which the server rejects. |
| | | `markMessagesAsRead` (:547) | `conversationId, messageIds` | yes. No caller of this method was found. |
| `bulk_import_service.dart` | `us-east4` | `bulkImportStudents` (:66) | `users[], sendPasswordResetEmails` | partly: `className` is not a server key; `imported[]` has no `displayName` |
| | | `createTeacherAccount` (:154) | `email, password, displayName, subjects` | no: `subjects` is ignored, and the client reads `uid` where the server returns `userId` |
| `user_management_service.dart` | default region | `updateUserRole` (:154) | `userId, newRole` | no such server callable |
| | | `resetUserPassword` (:179) | `userId` | keys match |
| | | `deleteUserAccount` (:203, :285) | `userId` | keys match |
| `admin_provider.dart` | default region | `createStudentAccount` (:237) | `username, password, displayName, grade` | no: the server requires `email` and uses `gradeLevel`, so every call fails |
| | | `createTeacherAccount` (:271) | `email, password, displayName` | keys match |
| | | `deleteUserAccount` (:300) | `userId` | keys match |
| | | `resetUserPassword` (:319) | `userId` | keys match |
| | | `createStudentAccount` (:345) | `email, displayName, gradeLevel, password, parentEmail, classIds, isGoogleAuth` | keys match. No caller was found. |
| | | `createTeacherAccount` (:376) | `email, password, displayName, subjects` | `subjects` is ignored. No caller was found. |
| `set_user_role_claims.dart` | default region | `setRoleClaim` (:20) | `uid, role` | keys match. The file is not reachable. |
| `run_migration.dart` | `us-east4` | `migrateAllUserRoles` (:48) | none | yes. The file is not reachable. |

### Citations for the table

**Client side**
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:13-110 (BehaviorPointsService) @ 7808a91`
- `lib/features/behavior_points/presentation/widgets/behavior_history_panel.dart:122-130 (_BehaviorHistoryPanelState) @ 7808a91`
- `lib/features/chat/data/controllers/firestore_chat_controller.dart:17-551 (FirestoreChatController) @ 7808a91`
- `lib/features/admin/data/services/bulk_import_service.dart:9-160 (BulkImportService) @ 7808a91`
- `lib/features/admin/data/services/user_management_service.dart:10-286 (UserManagementService) @ 7808a91`
- `lib/features/admin/presentation/providers/admin_provider.dart:13-382 (AdminProvider) @ 7808a91`
- `lib/shared/utils/set_user_role_claims.dart:7-21 (UserRoleClaims) @ 7808a91`
- `lib/shared/utils/run_migration.dart:47-50 (runUserRoleMigration) @ 7808a91`

**Server side**
- `functions/src/behaviorPoints.ts:367-433 (getBehaviorHistory) @ 7808a91`
- `functions/src/chatFunctions.ts:317-329 (uploadChatFile) @ 7808a91`
- `functions/src/adminFunctions.ts:64 (createStudentAccount) @ 7808a91`
- `functions/src/adminFunctions.ts:216-282 (createTeacherAccount) @ 7808a91`

### Effects of the region and name mismatches

- **`UserManagementService.updateUserRole`** catches the failed call and returns false. Its Firestore role update comes after the call, so the update never runs. `lib/features/admin/data/services/user_management_service.dart:152-175 (updateUserRole) @ 7808a91`
- **`AdminProvider` and `UserManagementService`** both use the default instance. Neither targets `us-east4`, where every server callable lives.

### HTTP endpoints (not callables)

`SecureDesktopOAuthHandler` builds `https://<region>-<project>.cloudfunctions.net/{getOAuthUrl, exchangeOAuthCode, refreshOAuthToken}`. The region defaults to `us-east4`. Nothing outside its own file references the class. `lib/features/auth/data/services/desktop_oauth_handler_secure.dart:19-41 (SecureDesktopOAuthHandler) @ 7808a91`

### Server callables with no client call site

- `createAdminAccount`
- `getSystemStats`
- `migrateStudentClassEnrollment`
- `migrateUsernamesToPublic`. This one is also not exported from `index.ts`.

### Not checked

- Reachability was checked with `git grep` for constructors and callers. The calling files were not read.
- The request bodies of the three OAuth HTTP calls were not read, because the analyzer's file budget ran out.

## 13. How are the client auth code, `firestore.rules`, `storage.rules` and the Cloud Functions tested?

At this commit there are no tests for the client auth code, either rules file, or the Cloud Functions. There is no emulator configuration, and no CI step runs tests, checks the rules, or builds the functions.

### Tracked test files

Exactly one test file is tracked: `test/unit/firestore_thread_safe_test.dart`. Its imports are `flutter_test`, `flutter/material`, the `firestore_thread_safe` utility, and `fake_async`. It imports nothing from Firebase or the auth code. Its 11 cases cover only the callback scheduler:
- priority ordering
- 20 ms deduplication
- metrics
- `safeNotify`
- queue depth

`test/unit/firestore_thread_safe_test.dart:7-307 (main) @ 7808a91`

`pubspec.yaml` has scripts for `test/widgets/` and `integration_test`, but neither directory exists. `pubspec.yaml:193-194 (scripts) @ 7808a91`

### Rules and functions

- **Rules:** nothing tests either rules file. No file in the tree mentions `rules-unit-testing`.
- **Rules review:** the only check on the rules is a review prompt asking an AI reviewer to flag rule changes. `.github/workflows/claude-code-review.yml:125-128 (prompt) @ 7808a91`
- **Functions tests:** `functions/` has no test files and no `test` script. `functions/package.json:3-13 (scripts) @ 7808a91`
- **Functions test tooling:** `firebase-functions-test ^3.3.0` is declared as a dev dependency, but nothing imports it. `functions/package.json:28 (devDependencies) @ 7808a91`

### Emulator configuration

- **`firebase.json`:** not tracked at this commit. `.gitignore` ignores `**/firebase.json`. `.gitignore:114 (firebase.json) @ 7808a91` The `serve` script (`firebase emulators:start --only functions`) depends on that file. `functions/package.json:7 (scripts) @ 7808a91`
- **Local copy:** a copy exists in the working tree but is not part of the commit. This research reads only the commit, so nothing it records about emulator ports, rules paths, or deploy targets comes from that file.
- **Client emulator calls:** none. The tree has no `use*Emulator` or `connect*Emulator` calls. `AppInitializer` has only a comment saying emulator configuration is skipped. `lib/shared/core/app_initializer.dart:138-139 (AppInitializer) @ 7808a91`
- **Desktop OAuth handler:** `SecureDesktopOAuthHandler` points at `localhost:5001` in debug mode, but nothing references the class. `lib/features/auth/data/services/desktop_oauth_handler_secure.dart:25-37 (SecureDesktopOAuthHandler) @ 7808a91`

### Seams for testing

`AuthService` hard-wires `FirebaseAuth.instance` and `FirebaseFirestore.instance`, so neither can be swapped for a fake. `lib/features/auth/data/services/auth_service.dart:27-29 (AuthService) @ 7808a91`

Several services do take an optional `FirebaseFirestore`. `StudentService` is one; its doc comment says the parameter supports unit testing. `lib/features/student/data/services/student_service.dart:34 (StudentService) @ 7808a91` Others are `AssignmentService`, `SubmissionService`, `ClassService`, `GradeService`, `ScheduledMessagesService` and `FirestoreService`. No test constructs any of them.

### Tooling declared vs used

- **Dev dependencies:** `pubspec.yaml` declares `flutter_test`, `integration_test`, `fake_cloud_firestore`, `test` and `fake_async`. Only `flutter_test` and `fake_async` are imported anywhere. `pubspec.yaml:121-135 (dev_dependencies) @ 7808a91`
- **Mis-indented packages:** `mockito`, `faker` and `freezed` are indented under the `flutter_launcher_icons:` block, so YAML parses them as keys of that block, not as dev dependencies. `pubspec.yaml:153-161 (flutter_launcher_icons) @ 7808a91`

### CI

The `validate` job does four things:
- runs `flutter pub get`
- runs `flutter analyze --no-fatal-infos`
- runs `dart format --set-exit-if-changed`
- runs a dead-code analyzer, set to `continue-on-error`

`.github/workflows/01_ci.yml:13-55 (validate) @ 7808a91`

It has no `flutter test` step and does nothing in `functions/`. It also checks out `ref: main`, not the PR head. No workflow anywhere has a `run:` step that runs tests or emulators.

## Where the answers meet

These are methods and fields that the answers to more than one question pass through, with the checks in each that reject a call or throw. Every line repeats a claim already cited in a question section above.

- **The `users/{uid}.role` lookup.** Questions 1, 2, 3, 9 and 10 all depend on it.
  - In the rules, `getUserRole` reads it with `get()`, and `isTheTeacher`, `isStudent` and `isAdmin` each also require a matching email domain. `firestore.rules:43-46 (getUserRole) @ 7808a91`
  - The admin callables throw `unauthenticated` or `permission-denied` from this field. `functions/src/adminFunctions.ts:51-61 (createStudentAccount) @ 7808a91`
  - The behavior-points callables require role teacher and class ownership. `functions/src/behaviorPoints.ts:31-77 (awardBehaviorPoints) @ 7808a91`
  - The client signs the user out when the role is null. `lib/features/auth/providers/auth_provider.dart:140-187 (AuthProvider) @ 7808a91`
  - `syncUserRole` copies it into the claim only for teacher or student. `functions/src/customClaims.ts:106-114 (syncUserRole) @ 7808a91`
- **`ensureConversationMembership`.** Questions 4, 7 and 10 depend on it. It throws `not-found` when the conversation is missing and `permission-denied` when the caller is not a participant. The callable's catch then rewrites both as `internal`. `functions/src/chatFunctions.ts:13-34 (ensureConversationMembership) @ 7808a91` and `functions/src/chatFunctions.ts:132-137 (sendMessage) @ 7808a91`
- **`uploadChatFile`.** Questions 4, 10 and 12 depend on it.
  - It rejects a declared `fileSize` over 10 MB. `functions/src/chatFunctions.ts:309-314 (uploadChatFile) @ 7808a91`
  - It rejects a MIME type outside its allow-list. `functions/src/chatFunctions.ts:317-331 (uploadChatFile) @ 7808a91`
  - The client sends `image/jpg` for `.jpg` files. `lib/features/chat/data/controllers/firestore_chat_controller.dart:387 (FirestoreChatController) @ 7808a91`
- **`sendPushNotifications` and `_saveFCMToken`.** Questions 5, 10 and 11 depend on them.
  - The sender reads only `users/{id}.fcmToken` and swallows errors. `functions/src/chatFunctions.ts:386-428 (sendPushNotifications) @ 7808a91`
  - The client writes both `users.fcmToken` and `fcm_tokens/{uid}`, and does nothing when no user is signed in. `lib/features/notifications/data/services/firebase_messaging_service.dart:235-263 (_saveFCMToken) @ 7808a91`
- **`getBehaviorHistory`.** Questions 8, 10 and 12 depend on it.
  - It rejects a missing `classId`, and rejects a teacher who does not own the class. `functions/src/behaviorPoints.ts:394-422 (getBehaviorHistory) @ 7808a91`
  - It filters the date range on `timestamp` and orders by `awardedAt`. `functions/src/behaviorPoints.ts:445-461 (getBehaviorHistory) @ 7808a91`
  - The client sends `studentName`, which the server ignores. `functions/src/behaviorPoints.ts:367-433 (getBehaviorHistory) @ 7808a91`
- **`FirestoreRateLimiter`.** Questions 8, 9 and 10 depend on it. It throws when `count >= maxCalls` and lets the request through on any other error. `applyRateLimit` turns the throw into `resource-exhausted`. `functions/src/rate-limiter.ts:15-88 (FirestoreRateLimiter) @ 7808a91` and `functions/src/security.ts:38-51 (applyRateLimit) @ 7808a91`

## Open questions

- **`firebase.json` is not in the commit.** It is ignored by `.gitignore:114 (firebase.json) @ 7808a91`. A copy exists in the working tree, and this research did not read it. That leaves unchecked which rules files, functions source, hosting targets and emulator ports the project deploys with. Next ask, once the file is committed: *What does `firebase.json` configure for Firestore rules, Storage rules, indexes, functions source, hosting and emulators?*
- **Collections outside the question set.** `firestore.rules` and `firestore.indexes.json` name collections this research did not trace: `calls` (and `candidates`), `announcements`, `games`/`scores`, `teachers`, `files`, `archived_grades` and the legacy `chat_rooms`. Next ask: *Where are `calls`, `announcements`, `games`, `teachers`, `files`, `archived_grades` and `chat_rooms` read and written?*
- **Platform behavior the code does not show (UNVERIFIED):**
  - whether Admin SDK `createUser`/`importUsers` fire `beforeUserCreated`
  - the default region of `FirebaseFunctions.instance` (believed to be `us-central1`)
  - how `set` with merge treats a dotted `behaviorCounts.<id>` key
  - how `resource == null` behaves in rules list queries
  - whether plugin manifests merge `POST_NOTIFICATIONS` into the Android build
- **Items left unread:**
  - the operation at `lib/features/student/presentation/providers/student_provider.dart:105 (loadTeacherStudents) @ 7808a91` and `:165`
  - which `grades` index entries sit at `firestore.indexes.json` lines 642–722
  - whether the hand-built `calendar_events` create includes `isActive`
  - which collection `StudentEnhanced` would read
  - the request bodies of the three OAuth HTTP calls
  - the calling files in question 12, whose reachability was checked by `git grep` only
- **Budget:** the analyzers for questions 5 (about 31 short reads), 7 (16 files) and 8 (15 full reads plus 12 excerpts) went past the 15-file budget to finish their call-site lists.

## Prior documents

None. No research run folders existed under this initiative and the repository holds no ADRs at 7808a91.
