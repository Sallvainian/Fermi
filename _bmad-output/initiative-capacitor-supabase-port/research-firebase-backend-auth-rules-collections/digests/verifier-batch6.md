Seven of the eight claims are verified against 7808a91. Claim [48] is disputed. Everything was read through git at the commit, with the excluded paths left out.

- **ref=[45]** `lib/features/notifications/data/services/firebase_messaging_service.dart:110-116 (setNavigationCallback) @ 7808a91`: **verified**. Searching `lib` and `test` at the commit finds only the definition at line 110 and no callers.

- **ref=[46]** `lib/features/notifications/data/services/firebase_messaging_service.dart:235-263 (_saveFCMToken) @ 7808a91`: **verified**. Line 237 returns when no user is signed in. Lines 241-245 update `users/{uid}` with `fcmToken`, `fcmTokenUpdatedAt` and `platform`. Lines 248-253 set `fcm_tokens/{uid}`.

- **ref=[47]** `lib/features/admin/data/services/user_management_service.dart:152-175 (updateUserRole) @ 7808a91`: **verified**, with the citation re-anchored to the method itself, which starts at 152. Line 154 calls `httpsCallable('updateUserRole')`. No file in `functions/src` contains `updateUserRole`; `index.ts` re-exports nine modules and none exports it. The `users.role` update (160-163) comes after the awaited call inside the same try block, so a failed call skips it and returns false.

- **ref=[48]** `lib/features/admin/presentation/providers/admin_provider.dart:11-493 (AdminProvider) @ 7808a91`: **disputed**. Line 13 does use the default `FirebaseFunctions.instance`. The provider calls `createStudentAccount` twice, though:
  - The `createStudentAccount` method (230-243) sends `{username, password, displayName, grade}` with no email, as claimed.
  - `bulkCreateStudent` (345-354) calls the same callable with `{email, displayName, gradeLevel, password, parentEmail, classIds, isGoogleAuth}`, so that call does send an email.

  The claim holds only for the first call.

- **ref=[49]** `lib/features/chat/data/controllers/firestore_chat_controller.dart:387 (FirestoreChatController) @ 7808a91`: **verified**. The MIME type is `'image/${image.path.split('.').last}'`, so a `.jpg` file sends `image/jpg`. The extension comes from `image.path`, not `image.name`.

- **ref=[50]** `test/unit/firestore_thread_safe_test.dart:6-308 (main) @ 7808a91`: **verified**. This is the only tracked file under `test/` and the only `_test.dart` file in the repository. It imports only `flutter_test`, `flutter/material`, `fermi_plus/shared/utils/firestore_thread_safe.dart` and `fake_async`, so nothing from Firebase or auth.

- **ref=[51]** `.gitignore:114 (firebase.json) @ 7808a91`: **verified**. Line 114 is `**/firebase.json`, and no `firebase.json` is tracked anywhere at the commit.

- **ref=[52]** `.github/workflows/01_ci.yml:14-55 (validate) @ 7808a91`: **verified**. The `validate` job runs `flutter pub get`, `flutter analyze --no-fatal-infos`, `dart format --set-exit-if-changed .` and `dead_code_analyzer -p lib`, then saves a report. It has no `flutter test` step and nothing that touches `functions/`.