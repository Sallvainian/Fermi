Twenty-nine callable call sites in 8 client files call 18 distinct callables. Every server callable is pinned to `us-east4` (`functions/src/index.ts:29-32 setGlobalOptions @ 7808a91`, plus a per-function `region: "us-east4"` on each one below), and all six server modules are exported from `functions/src/index.ts:35-59 @ 7808a91`. Three client files use the default `FirebaseFunctions.instance`, which in the cloud_functions plugin means `us-central1`. That default comes from the library, not this repo, so it is UNVERIFIED. The git grep found no other region or emulator override in `lib` or `test`.

## Call sites, grouped by client file

**1. `lib/features/behavior_points/domain/services/behavior_points_service.dart`**
- Instance: `:13-15 (BehaviorPointsService) @ 7808a91`, `instanceFor(region: 'us-east4')`. **Load-bearing.**
- Reachable: `behavior_point_provider.dart:144 @ 7808a91` creates it.
- `:38-50 (awardBehaviorPoints) @ 7808a91`, calls **`awardBehaviorPoints`** (load-bearing).
  - Args: `classId, studentId, studentName, behaviorId, behaviorName, points, gender, gradeLevel, studentAvatarUrl, note`.
  - Reads `success, operationId, message`.
  - Server `functions/src/behaviorPoints.ts:5-16 (AwardPointsRequest), :31-35 @ 7808a91`: the keys match. It rejects a missing classId, studentId or behaviorId (`:48`), and rejects callers whose role is not `teacher` (`:58`). It returns `{success, operationId, message}` (`:151-155`).
  - Called from `behavior_point_provider.dart:312`.
- `:79-84 (undoBehaviorPoints) @ 7808a91`, calls **`undoBehaviorPoints`** (load-bearing).
  - Args: `classId, studentId, historyId`. Reads `success, message`.
  - Server `behaviorPoints.ts:162-181 @ 7808a91`: the keys match, and it rejects any of the three if missing (`:179`).
  - Called from `behavior_point_provider.dart:348`.
- `:109-110 (getClassPointsSummary) @ 7808a91`, calls **`getClassPointsSummary`** (load-bearing).
  - Args: `{classId}`. Reads `success, summaries`.
  - Server `behaviorPoints.ts:274-292, :342-344 @ 7808a91`: matches.
  - No caller of this method was found in `lib` or `test`.

**2. `lib/features/behavior_points/presentation/widgets/behavior_history_panel.dart`**
- `:122-130 (_loadHistory) @ 7808a91`, `instanceFor(region: 'us-east4')`, calls **`getBehaviorHistory`** (load-bearing).
  - Args: whatever `BehaviorHistoryFilters.toMap` (`:27-37`) returns, which can be `studentName`, `gender`, `startDate`, `endDate` and `behaviorType`. The panel then adds `classId`, `limit` and `offset`.
  - Reads `success, history, hasMore`.
- **Mismatch (load-bearing):** the client sends `studentName`. The server's `HistoryRequest` (`functions/src/behaviorPoints.ts:367-376 @ 7808a91`) has `studentId` and no `studentName`, and filters only on `params.studentId` (`:432-433`). The student-name filter therefore does nothing on the server.
  - The server rejects a missing classId (`:381`).
  - It returns `{success, history, hasMore}` (`:511-515`).
- Reachable: `behavior_points_screen.dart:379`.

**3. `lib/features/chat/data/controllers/firestore_chat_controller.dart`**
- Instance: `:17-19 @ 7808a91`, `instanceFor(region: 'us-east4')`. **Load-bearing.**
- Reachable: `flyer_chat_screen.dart:75`, which is routed from `app_router.dart:381` and other routes.
- `:292-296 (updateTypingStatus)`, calls **`updateTypingStatus`**.
  - Args: `{conversationId, isTyping}`.
  - Server `functions/src/chatFunctions.ts:209-230 @ 7808a91`: matches. It rejects a missing conversationId or an undefined isTyping (`:225`).
  - Called from `flyer_chat_screen.dart:178`.
- `:323-328 (sendMessage)`, calls **`sendMessage`**.
  - Args: `{conversationId, text, attachments}`.
  - Server `chatFunctions.ts:43-66 @ 7808a91`: destructures the same keys (`:57`). It rejects a missing conversationId, or a call with neither text nor attachments (`:61`). It returns `{success, messageId}` (`:131`), and the client reads no result fields.
  - Called from `flyer_chat_screen.dart:165`.
- `:383-390 (uploadImage)` and `:473-480 (uploadFile)`, both call **`uploadChatFile`**.
  - Args: `{conversationId, fileName, mimeType, base64Data, fileSize}`. Reads `url, fileName`.
  - Server `chatFunctions.ts:283-330 @ 7808a91`: destructures the same keys (`:297`) and returns `url, fileName, …` (`:365-371`).
  - The server rejects a missing conversationId, fileName, base64Data or mimeType (`:301`), a file over 10 MB (`:309`), and any MIME type outside its allow-list (`:317-329`). The allow-list has `image/jpeg` but not `image/jpg`.
  - **Value mismatch:** `uploadImage` builds the type as `'image/${extension}'` (`firestore_chat_controller.dart:387`). For a `.jpg` file that gives `image/jpg`, which the server rejects.
  - Called from `flyer_chat_screen.dart:208, :219, :227`.
- `:547-551 (markMessagesAsRead)`, calls **`markMessagesAsRead`**.
  - Args: `{conversationId, messageIds}`.
  - Server `chatFunctions.ts:146-167 @ 7808a91`: matches, and it rejects a messageIds value that is not an array (`:162`).
  - No caller of this controller method was found. `chat_provider.dart:189` has a different method with the same name.

**4. `lib/features/admin/data/services/bulk_import_service.dart`**
- Instance: `:9 @ 7808a91`, `instanceFor(region: 'us-east4')`. **Load-bearing.**
- Reachable: created by `admin_provider.dart:14` and used at `:397` and `:419`. Those are reached from `bulk_import_screen.dart:914, :950`.
- `:66-70 (bulkImportStudents)`, calls **`bulkImportStudents`**.
  - Args: `{users: [...], sendPasswordResetEmails: true}`. Each user carries `email, displayName, gradeLevel, parentEmail, isGoogleAuth`, plus optional `classIds`, `enrollmentCode`/`className`, and `studentId` (`:34-62`).
  - Reads `imported[].uid/email/displayName/isGoogleAuth`, `failed[].email/error`, `alreadyExisting`, and `summary`.
  - Server `functions/src/bulkImport.ts:31-37, :53 @ 7808a91`: accepts `{users, csvData, sendPasswordResetEmails}`. It requires the caller's role to be `admin` (`:48`). It rejects input with no users array or csvData (`:67`), with 0 users (`:71`), or with more than 1000 (`:75`), and rejects emails outside `@rosellestudent.org/.com` (`:99-105`).
  - The server's `BulkImportUser` has no `className` key (`:8-17`).
  - The `imported` entries are `ImportResult {email, success, uid, error}` (`:19-24, :427`), so `displayName` and `isGoogleAuth` are absent and the client falls back to `''` and `false`.
- `:154-160 (bulkImportTeachers)`, calls **`createTeacherAccount`**.
  - Args: `{email, password, displayName, subjects}`. Reads `response.data['uid']`.
  - **Mismatch (load-bearing):** the server destructures only `{email, password, displayName}` (`functions/src/adminFunctions.ts:216 @ 7808a91`), so `subjects` is ignored. It returns `userId`, not `uid` (`:277-282`), so the uid this client records is null.
  - The server rejects a missing field (`:218`), a domain other than `@roselleschools.org` (`:227`), and a password under 6 characters (`:234`).

**5. `lib/features/admin/data/services/user_management_service.dart`**
- Instance: `:10 @ 7808a91`, default `FirebaseFunctions.instance` with no region set. **Load-bearing:** it does not target `us-east4`, where every server callable lives.
- Reachable: `user_management_screen.dart:21` (route `app_router.dart:541`), `user_edit_dialog.dart:19`, `class_assignment_dialog.dart:17`.
- `:154-158 (updateUserRole)`, calls **`updateUserRole`** with `{userId, newRole}`.
  - **No such server callable (load-bearing):** the `export const` grep over `functions/src` at 7808a91 lists no `updateUserRole`.
  - Called from `user_edit_dialog.dart:112`.
  - The method catches the error and returns false (`:171-173`). The Firestore role update at `:160` comes after the call, so it never runs.
- `:179-183 (resetUserPassword)`, calls **`resetUserPassword`**.
  - Args: `{userId}`. Reads `newPassword`.
  - Server `adminFunctions.ts:470-471, :487-490, :519-523 @ 7808a91`: the keys match.
  - Called from `user_management_screen.dart:152, :273`.
- `:203-204 (deleteUser)` and `:285-286 (bulkDeleteUsers)`, both call **`deleteUserAccount`** with `{userId}`.
  - Server `adminFunctions.ts:401-426 @ 7808a91`: the keys match. It rejects a missing userId (`:420`) and self-deletion (`:425`).
  - Called from `user_management_screen.dart:215, :352`.

**6. `lib/features/admin/presentation/providers/admin_provider.dart`**
- Instance: `:13 @ 7808a91`, default `FirebaseFunctions.instance`. **Load-bearing,** for the same region reason as file 5.
- Reachable: `app_providers.dart:72`.
- `:237-243 (createStudentAccount)`, calls **`createStudentAccount`**.
  - Args: `{username, password, displayName, grade}`. Reads `userId, email`.
  - **Mismatch (load-bearing):** the server destructures `{email, password, displayName, gradeLevel, parentEmail, classIds, isGoogleAuth}` (`adminFunctions.ts:64 @ 7808a91`) and rejects a missing email (`:66-67`). It also rejects non-`@rosellestudent` domains (`:75-80`) and passwords under 6 characters for non-Google accounts (`:84-90`). Since no `email` is sent, every call fails.
  - `grade` is also not read, because the server key is `gradeLevel`.
  - Called from `admin_dashboard_screen.dart:312-319`.
- `:271-276 (createTeacherAccount)`, calls **`createTeacherAccount`**.
  - Args: `{email, password, displayName}`. Reads `userId`.
  - The keys match the server (`:216`, returns at `:277-282`).
  - Called from `admin_dashboard_screen.dart:491`.
- `:300-301 (deleteUser)`, calls **`deleteUserAccount`** with `{userId}`. This matches the server.
- `:319-323 (resetUserPassword)`, calls **`resetUserPassword`** with `{userId}` and reads `newPassword`. This matches the server.
- `:345-354 (bulkCreateStudent)`, calls **`createStudentAccount`**.
  - Args: `{email, displayName, gradeLevel (string), password (null if Google), parentEmail, classIds, isGoogleAuth}`. The keys match `:64`.
  - No caller was found.
- `:376-382 (bulkCreateTeacher)`, calls **`createTeacherAccount`**.
  - Args: `{email, password, displayName, subjects}`. The server ignores `subjects` (`:216`).
  - No caller was found.

**7. `lib/shared/utils/set_user_role_claims.dart`**
- `:7 @ 7808a91`, default instance. **Load-bearing,** because the server is in `us-east4`.
- `:20-21 (UserRoleClaims.setRoleClaim)`, calls **`setRoleClaim`** with `{uid, role}`.
  - Server `functions/src/customClaims.ts:10, :19-34 @ 7808a91`: the keys match.
  - The server rejects a missing uid or role (`:22`), and any role other than `teacher` or `student` (`:29`). It also rejects a caller who is not a teacher setting another user's role (`:46`).
- Not reachable: `UserRoleClaims` appears only in comments in its own file.

**8. `lib/shared/utils/run_migration.dart`**
- `:47-50 (runUserRoleMigration) @ 7808a91`, `instanceFor(region: 'us-east4')`, calls **`migrateAllUserRoles`** with no arguments.
  - Reads `success, message, totalUsers, successCount, errorCount, errors`.
  - Server `functions/src/migrate-user-roles-cloud.ts:13-14, :80-85 @ 7808a91`: returns exactly those fields.
- Not reachable: no caller was found outside its own file.

## HTTP endpoints (not callables)
- `lib/features/auth/data/services/desktop_oauth_handler_secure.dart:19-22, :35-41 (SecureDesktopOAuthHandler) @ 7808a91` builds `https://<region>-<project>.cloudfunctions.net/{getOAuthUrl, exchangeOAuthCode, refreshOAuthToken}`. The region comes from `FIREBASE_FUNCTIONS_REGION` and defaults to `us-east4`.
- The server defines all three as `onRequest` at `functions/src/oauth.ts:70, :170, :350 @ 7808a91`.
- I found no reference to `SecureDesktopOAuthHandler` outside its own file. `auth_service.dart:19-20` uses `DirectDesktopOAuthHandler`.
- I did not read the request bodies of the three OAuth calls.

## Server callables with no client call site
- `createAdminAccount`, `getSystemStats` (`adminFunctions.ts:299, :535`).
- `migrateStudentClassEnrollment` (`bulkImport.ts:549`).
- `migrateUsernamesToPublic` (`migrate-usernames.ts:12`). This one is also not exported from `index.ts`.

## Not checked
- The file budget ran out at 15 files, with `functions/src/oauth.ts` and the OAuth handler's request bodies still unread.
- Reachability was checked with `git grep` at 7808a91 for constructors and method callers, not by reading the calling files.
- No call sites were found under `test`.