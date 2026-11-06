Nine claims checked, all `verified`. I read each one through git at commit 7808a91 and left out the brief's excluded paths.

ref=[1] — lib/shared/core/app_initializer.dart:54-89 (AppInitializer) @ 7808a91 — **verified**. FCM is added to the startup list only when `!kIsWeb && _isFirebaseMessagingSupported()`, and that check is `Platform.isAndroid || Platform.isIOS`. The actual `FirebaseMessagingService()` call is in `_initializeFirebaseMessaging` at lines 217-233. No other code in `lib` calls `initialize` on it; chat screens only call `markConversationActive`.

ref=[2] — lib/shared/core/app_initializer.dart:150-165 (AppInitializer) @ 7808a91 — **verified**. The cited lines only fetch `FirebaseDatabase.instance` and call `setPersistenceEnabled(true)` when not on web. `firebase_database` is imported only in `app_initializer.dart`. The only `.ref()` calls in `lib` are on `FirebaseStorage` in `settings_screen.dart`.

ref=[3] — lib/features/auth/data/services/auth_service.dart:19-20 (AuthService) @ 7808a91 — **verified**. Two other handler classes exist but are never created anywhere in `lib` or `test`: `DesktopOAuthHandler` (`desktop_oauth_handler.dart:21`) and `SecureDesktopOAuthHandler` (`desktop_oauth_handler_secure.dart:12`).

ref=[4] — lib/features/auth/providers/auth_provider.dart:86-137 (AuthProvider) @ 7808a91 — **verified**. The file never uses `authStateChanges`, `userChanges` or `idTokenChanges`. The constructor calls `_initializeAuthState` once. That method checks `getRedirectResult` on web, then `currentUser`, then `reload`, then `_processUser`.

ref=[5] — lib/features/auth/providers/auth_provider.dart:140-187 (AuthProvider) @ 7808a91 — **verified**. When no model loads and the email ends in `@fermi-plus.com`, it writes `users/{uid}` with `role: 'admin'` and loads again. It accepts the model only if `loadedUserModel != null && loadedUserModel.role != null`; otherwise it signs out and reports "User profile not found".

ref=[6] — lib/features/auth/data/services/auth_service.dart:254-414 (AuthService) @ 7808a91 — **verified**. `_isValidSchoolEmail` (line 46) is called only at lines 166 and 226, both outside `signInWithGoogle`. The three branches are as claimed: web popup with a redirect fallback, desktop `_directOAuthHandler.performDirectOAuthFlow()`, and mobile `signInWithProvider`. Any other platform throws `UnsupportedError`.

ref=[7] — functions/src/authBlocking.ts:18-50 (autoAssignRole) @ 7808a91 — **verified**. Missing event data also throws `invalid-argument`. A missing email throws `invalid-argument`, and a domain failing `isValidSchoolEmail` throws `permission-denied`. A further `permission-denied` comes at lines 55-61 if no role can be worked out from the email.

ref=[8] — functions/src/authBlocking.ts:106-110 (customClaims) @ 7808a91 — **verified**. It returns `customClaims` (`{role, emailDomain}`, built at lines 66-69) and `emailVerified: role === "admin"`. That field is always returned, so non-admin accounts get an explicit `false`, not an omitted value.

ref=[9] — functions/src/customClaims.ts:106-114 (syncUserRole) @ 7808a91 — **verified**. Claims are set only if `role && ["teacher", "student"].includes(role)`. Admin, null or any other role leaves the existing claim alone. One edge the claim doesn't mention: if the document is deleted, the claims are cleared to null (lines 95-103).