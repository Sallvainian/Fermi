Client startup and sign-in, as of 7808a91

**Short answer:** the app starts Firebase once, with no emulator, through `AppInitializer`. Every sign-in goes through `AuthProvider` and `AuthService`. Only `DirectDesktopOAuthHandler` is live on desktop. The client reads the role from the Firestore `users/{uid}.role` field. It never reads an ID-token claim on any live path.

## 1. Startup

- `lib/main.dart:30 (main)` @ 7808a91. On non-web it loads `.env` from one of four paths, `:99-161`, then calls `runApp(InitializationWrapper)` at `:163`.
  - `lib/main.dart:341 (_InitializationWrapperState._initializeApp)` @ 7808a91 calls `AppInitializer.initialize()`. If Firebase is already up (hot restart), the fast path at `:308-320` skips it.
    - `lib/shared/core/app_initializer.dart:29-51 (initialize)` @ 7808a91 does Firebase, then the service locator, then deferred services in a post-frame callback. It catches and logs errors and carries on (`:43-50`).
      - `lib/shared/core/app_initializer.dart:101-105 (_initializeFirebase)` @ 7808a91: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` runs only if `Firebase.apps.isEmpty`. A `duplicate-app` error is ignored (`:119-124`); any other error is rethrown (`:127`), then swallowed and logged (`:166-176`). No emulator is configured (`:138-139`).
      - Options: `lib/firebase_options.dart:18-38 (DefaultFirebaseOptions.currentPlatform)` @ 7808a91 has web, android, ios, macos, windows and linux entries. It throws `UnsupportedError` on any other platform (`:34`). Every entry uses project `teacher-dashboard-flutterfire` (`:44, :56, :66, :81, :94, :108`).
      - Firestore: `persistenceEnabled: true` with an unlimited cache, on non-web only (`lib/shared/core/app_initializer.dart:142-147` @ 7808a91).
      - **Realtime Database:** the only setup is `FirebaseDatabase.instance` plus `setPersistenceEnabled(true)` on non-web. Errors are only logged (`lib/shared/core/app_initializer.dart:150-165 (_initializeFirebase)` @ 7808a91).
      - Service locator: `lib/shared/core/service_locator.dart:55-119 (setupServiceLocator)` @ 7808a91. It returns early if `FirebaseAuth` is already registered (`:59-65`) or Firebase is not initialized (`:68-74`). It registers lazy singletons for `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage` and `AuthService` (`:84-101`), and factories for `AssignmentService` and `SubmissionService` (`:108-114`).
      - Deferred services: `lib/shared/core/app_initializer.dart:54-74 (_initializeDeferredServices)` @ 7808a91.
        - `NotificationService().initialize()` runs on all platforms; `requestPermissions()` runs on non-web only (`:195-214`).
        - **Messaging:** `FirebaseMessagingService().initialize()` runs on Android and iOS only. It is gated at `:66` and `:77-89`, and again at `:217-230`, where web returns early. Desktop and web never start FCM.
        - I did not read the internals of `NotificationService` or `FirebaseMessagingService` (budget).
  - `lib/main.dart:198-244 (_TeacherDashboardAppState.build)` @ 7808a91 builds the providers from `AppProviders.getProviders()`. It shows a loading `MaterialApp` while the status is `uninitialized` or `authenticating` (`:207-241`), then creates `AppRouter.createRouter(authProvider)` once (`:244`).

**`AuthService` instances:** `lib/shared/core/app_providers.dart:28` @ 7808a91 is `ChangeNotifierProvider(create: (_) => AuthProvider())` (I saw it by grep only). `AuthProvider` builds its own instance with `authService ?? AuthService()` (`lib/features/auth/providers/auth_provider.dart:66` @ 7808a91). A grep for `get<AuthService>`, `.authService` and `<AuthService>()` finds no resolver of the GetIt `AuthService` outside `service_locator.dart`, so the registered singleton is never built.

`AuthService()` (`lib/features/auth/data/services/auth_service.dart:27-43` @ 7808a91) calls `setPersistence(Persistence.LOCAL)` on web only (`:40-42`). On Android and iOS it initializes `GoogleSignIn.instance` (`:132-135, :143-151`). On desktop it only logs (`:123-131`).

## 2. Sign-in methods (load-bearing)

**Email/password sign-in:**
- `lib/features/auth/presentation/screens/login_screen.dart:96-117 (_signIn)` @ 7808a91 calls `authProvider.signIn`, then `context.go('/dashboard')` if `userModel != null`.
  - `lib/features/auth/providers/auth_provider.dart:193-224 (signIn)` @ 7808a91.
    - Rejects: a concurrent auth operation returns silently (`:194-197`); an empty email or password throws (`:204-206`).
    - `lib/features/auth/data/services/auth_service.dart:211-251 (signIn)` @ 7808a91.
      - Throws `UnsupportedError` if `_auth` or `_firestore` is null (`:215-219`).
      - Rejects `invalid-email-domain` (`:226-232`) unless the email ends with `@roselleschools.org`, `@rosellestudent.org` or `@fermi-plus.com` (`_isValidSchoolEmail`, `:46-73`).
      - The debug bypass address is `fcottone@rosellestudent.com` (`:25, :51`). Its `.com` does not match the allowed `.org` domain.
      - **Auth API:** `signInWithEmailAndPassword` (`:236`).
      - Firestore write: `users/{uid}.set({lastActive}, merge)` with errors swallowed (`:243-247`).
    - Then `_processUser` (section 3).

**Email/password sign-up:**
- `lib/features/auth/presentation/screens/signup_screen.dart:145` @ 7808a91 calls `lib/features/auth/providers/auth_provider.dart:228-268 (signUp)` @ 7808a91, which has the same guards as sign-in.
  - `lib/features/auth/data/services/auth_service.dart:159-208 (signUp)` @ 7808a91.
    - Rejects with the same domain check (`:166-171`).
    - **Auth API:** `createUserWithEmailAndPassword` (`:173`), then `updateDisplayName` (`:179`).
    - Firestore write: `users/{uid}.set({uid, firstName, lastName, username, lastActive}, merge)` (`:196-204`). It does not set a role; the comment at `:202-203` says a blocking function sets it.
    - Username fallback: it takes the username from an `@fermi.local` email (`:190`). The username service creates `@students.fermi-app.local` and `@teachers.fermi-app.local` addresses (`username_auth_service.dart:23-24`), which do not match that suffix.
  - Then `_processUser`.

**Username sign-in:** `lib/features/auth/data/services/username_auth_service.dart:81-192 (signInWithUsername)` @ 7808a91. **No caller:** a grep for `signInWithUsername` finds only its definition.
- It finds the uid in `public_usernames/{username}` (`:97-110`). As a fallback it queries `users` where `username ==` (`:116-124`) and writes `public_usernames/{username} = {uid, role}` (`:133-138`).
- It then reads `users/{uid}.email` (`:158-173`). **Auth API:** `signInWithEmailAndPassword` (`:176`). Write: `users/{uid}.update({lastActive})` (`:183-189`).
- Rejects with `Invalid username or password` (`:123, :147`), `Invalid username mapping` (`:109`), `User profile not found` (`:164`) and `Invalid user profile` (`:172`).
- The only user of `UsernameAuthService` is `manage_student_accounts_screen.dart:26`, which calls its username generator and validator (`:56, :62, :265`).

**Google:**
- `lib/features/auth/presentation/screens/login_screen.dart:63-81 (_signInWithGoogle)` @ 7808a91 calls `lib/features/auth/providers/auth_provider.dart:272-299 (signInWithGoogle)` @ 7808a91. A null user sets `unauthenticated` (`:284-288`); errors go to `_handleOAuthError` (`:531-563`).
  - `lib/features/auth/data/services/auth_service.dart:254-414 (signInWithGoogle)` @ 7808a91 never calls `_isValidSchoolEmail`.
    - **Web:** `GoogleAuthProvider` with `prompt=select_account`, then `signInWithPopup` (`:280`). If the popup was blocked or closed, it falls back to `signInWithRedirect` and `getRedirectResult` (`:292-295`). Errors are rethrown with these messages: `unauthorized-domain`, `invalid-credential`, `auth/popup-blocked` (`:315-331`).
    - **Desktop (Windows, macOS, Linux):** `_directOAuthHandler.performDirectOAuthFlow()` (`:341`); null returns null (`:343-346`).
    - **Android/iOS:** `signInWithProvider(GoogleAuthProvider)` (`:366`).
    - Any other platform throws `UnsupportedError` (`:378`).
    - Firestore: it reads `users/{uid}` (`:383`). If the document is missing it writes `set({uid, email, displayName, firstName, lastName, photoURL, createdAt, lastActive}, merge)` with no role (`:393-404`). Otherwise it writes `set({lastActive}, merge)` (`:407-409`).
  - Then `_processUser`.

**Apple:** `lib/features/auth/data/services/auth_service.dart:417-498 (signInWithApple)` @ 7808a91.
- Throws if Apple sign-in is unavailable (`:420-422`). It gets the credential from `SignInWithApple.getAppleIDCredential`, builds `OAuthProvider('apple.com').credential`, then calls **`signInWithCredential`** (`:425-447`).
- A new user gets `users/{uid}.set({..., role: null, authProvider: 'apple'})` with no merge (`:473-484`). An existing user gets `update({lastActive})` (`:487-489`).
- UI entry: the login and signup screens never call it. The only path is `settings_screen.dart:822` calling `reauthenticateWithApple`, which calls `signInWithApple` (`auth_provider.dart:648-650`).

## 3. Desktop OAuth handlers (load-bearing)

- **Live:** `DirectDesktopOAuthHandler`, built as a field of `AuthService` (`lib/features/auth/data/services/auth_service.dart:9, :19-20` @ 7808a91). A grep for the three class names in `lib` and `test` finds no other construction site.
  - `lib/features/auth/data/services/desktop_oauth_handler_direct.dart:64-175 (performDirectOAuthFlow)` @ 7808a91.
    - The client ID and secret come from `--dart-define`, falling back to `.env` (`:18-58`). Empty credentials throw (`:74-87`).
    - Flow: a loopback server `HttpServer.bind('localhost', 0)` (`:97`); PKCE S256 (`:104-105, :283-298`); `launchUrl` to `accounts.google.com/o/oauth2/v2/auth` (`:108-124`).
    - The client exchanges the code itself at `oauth2.googleapis.com/token`, sending the `client_secret` (`:178-207`).
    - **Auth API:** `GoogleAuthProvider.credential(idToken, accessToken)`, then `FirebaseAuth.instance.signInWithCredential` (`:149-156`).
    - Rejects: no code (`:129-131`), a failed exchange (`:142-144`), and redirect errors `invalid_client`, `redirect_uri_mismatch`, `access_denied` and others (`:221-241`).
- **Not instantiated:** `SecureDesktopOAuthHandler` (`lib/features/auth/data/services/desktop_oauth_handler_secure.dart:12-118` @ 7808a91). It calls Functions endpoints `getOAuthUrl` and `exchangeOAuthCode` (`:39-40`), then `signInWithCustomToken(tokenResponse['firebaseToken'])` (`:114`).
- **Not instantiated:** `DesktopOAuthHandler` (`lib/features/auth/data/services/desktop_oauth_handler.dart:21-54` @ 7808a91). It returns `oauth2.Credentials` and makes no Firebase Auth call (it does not import `firebase_auth`, `:1-7`).
- The log text in `auth_service.dart:131` and `:336-340` says "secure OAuth via Firebase Functions", but the code calls the direct handler.

## 4. How auth state reaches the rest of the app

- `AuthStatus` has five values: `uninitialized`, `authenticated`, `authenticating`, `unauthenticated`, `error` (`lib/features/auth/providers/auth_provider.dart:14-29` @ 7808a91). `AuthProvider` is a `ChangeNotifier` that exposes `status`, `userModel`, `firebaseUser` and `isAuthenticated` (`:75-81`).
- `lib/features/auth/presentation/providers/auth_provider.dart:5` @ 7808a91 is just a re-export of the canonical provider.
- **`AuthProvider` does not subscribe to `authStateChanges`.** `_initializeAuthState` (`:86-137`) does these steps once, in order:
  1. Web only: `getRedirectResult`, then `_processUser` (`:89-103`).
  2. Reads `currentUser`; null sets `unauthenticated` (`:105-110`).
  3. Sets `authenticating` (`:113`).
  4. Calls `user.reload()`. If it fails, `_handleInvalidUser` signs the user out (`:116-122`).
  5. If the user is null after reload, signs out (`:125-129`).
  6. Calls `_processUser` (`:132`).
- The only `authStateChanges()` listener in `lib` is `lib/features/student/data/services/presence_service.dart:408` @ 7808a91. `AuthService.authStateChanges` (`auth_service.dart:155-156`) has no subscriber.
- `_processUser` (`lib/features/auth/providers/auth_provider.dart:140-187` @ 7808a91):
  - It calls `_loadUserModelWithRetry` (`:397-420`): up to 5 tries with backoff capped at 3 s. It reads `users/{uid}` (`:423-438`) and accepts the model only if `role != null` (`:409`).
  - If no model loads and the email ends with `@fermi-plus.com`, it writes `users/{uid}.set({uid, email, displayName, role: 'admin', createdAt, lastActive, isEmailUser: true, profileComplete: false})` with no merge, then loads again (`:147-168`).
  - Success sets `authenticated`, starts web in-app notifications (`:566-570`) and sets presence online with the role name (`:573-581`).
  - **Rejection:** a missing model or a null role calls `_authService.signOut()` with "User profile not found" and sets `error` (`:177-182`). So an Apple user whose new document has `role: null` is signed out unless something else sets the role.
- Routing: `lib/shared/routing/app_router.dart:67-136 (AppRouter.createRouter)` @ 7808a91 uses `refreshListenable: authProvider` (`:70`). Its redirect rules:
  - `uninitialized` or `authenticating`: no redirect (`:82-87`).
  - `error` outside `/auth`: `/auth/login` (`:91-93`).
  - Not authenticated: `/auth/role-selection` (`:96-100`).
  - `needsPasswordReset`: `/auth/teacher-setup/password` (`:103-108`).
  - Authenticated on an `/auth` route: `/dashboard` (`:110-122`).
  - A `/student` route without `userModel.role == UserRole.student`: `/dashboard` (`:126-132`).
- `/dashboard` (`app_router.dart:194-254`) picks the teacher, student or admin dashboard from `userModel.role`. If the role is null but `firebaseUser` is set, it defaults to the student dashboard (`:242-245`).
- `computeAuthRedirect` (`lib/shared/routing/auth_redirect.dart:21` @ 7808a91) has no caller in `lib` or `test`.

## 5. Where the client reads the role (load-bearing)

- **Source:** the Firestore field `users/{uid}.role`, mapped by `UserModel.fromFirestore` (`lib/shared/models/user_model.dart:146` @ 7808a91) through `_roleFromString` (`:251-262`). Only `'teacher'`, `'student'` and `'admin'` map to a role; anything else becomes null, which triggers the sign-out above.
- **ID-token claims:** `UserRoleClaims.hasRole` and `getCurrentUserRole` read `getIdTokenResult().claims['role']` (`lib/shared/utils/set_user_role_claims.dart:41-69` @ 7808a91). A grep for `UserRoleClaims` and `set_user_role_claims` finds no importer, so no live path reads a claim. A grep for `getIdTokenResult` finds only these two lines.
- **Client role writers:**
  - `AuthService.updateUserRole` (`auth_service.dart:527-561`) writes `users.role`, and `students/{uid}` for students.
  - `AuthService.saveUserRole` (`:564-588`).
  - Neither has a caller in `lib`. The admin `updateUserRole` in `user_management_service.dart:154` is a different method that calls the `updateUserRole` Cloud Function.
  - `AuthProvider.setSelectedRole` is a no-op (`auth_provider.dart:632-635`); `role_selection_screen.dart:24` calls it.
  - `createStudentAccount` always throws (`:638-645`).

## Not read (15-file budget reached)

The 15 files I read in full or in part:
- `main.dart`
- `firebase_options.dart`
- `app_initializer.dart`
- `service_locator.dart`
- the re-exporting `presentation/providers/auth_provider.dart`
- `auth_service.dart`
- `providers/auth_provider.dart`
- the three desktop handlers
- `username_auth_service.dart`
- `login_screen.dart` lines 55-135
- `app_router.dart`
- `user_model.dart`
- `set_user_role_claims.dart`

I only grepped `app_providers.dart`, `auth_redirect.dart`, `signup_screen.dart`, `role_selection_screen.dart`, `settings_screen.dart`, `presence_service.dart` and `manage_student_accounts_screen.dart`. I did not open `user_role.dart`, `notification_service.dart`, `firebase_messaging_service.dart`, `web_in_app_notification_service.dart` or the presence service internals, so whether presence writes to the Realtime Database is UNVERIFIED. Whether a blocking function really sets the role on sign-up is also UNVERIFIED: the client only says so in comments (`auth_service.dart:194-203, :401`) and maps `permission-denied` errors to a domain message (`auth_provider.dart:541-547`).