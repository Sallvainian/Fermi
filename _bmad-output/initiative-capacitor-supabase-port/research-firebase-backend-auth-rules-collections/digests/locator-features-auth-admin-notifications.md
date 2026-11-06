I covered questions 1, 4, 5–8, 11, 12 and 13 for my area. Questions 2, 3, 9 and 10 are server-side or rules files, outside the area. Everything below comes from `git ls-tree` / `git grep` / `git show` at the commit (55 files in the area). Citations are `path:line (symbol) @ 7808a91`.

## Q1. Firebase start-up and sign-in (auth area only)

**Email/password**
- `lib/features/auth/data/services/auth_service.dart:46 (AuthService._isValidSchoolEmail) @ 7808a91`: checks the email domain on the client before sign-up or sign-in. Allowed domains are @roselleschools.org, @rosellestudent.org and @fermi-plus.com.
- `lib/features/auth/data/services/auth_service.dart:173 (AuthService.signUp) @ 7808a91`: calls `createUserWithEmailAndPassword`. It then merge-sets `users/{uid}` at :196 with firstName, lastName, username and lastActive. A comment says role, email and createdAt are "set by the blocking function".
- `lib/features/auth/data/services/auth_service.dart:236 (AuthService.signIn) @ 7808a91`: calls `signInWithEmailAndPassword`, then merge-sets `users/{uid}.lastActive` at :244.

**Google**
- `lib/features/auth/data/services/auth_service.dart:254 (AuthService.signInWithGoogle) @ 7808a91`: picks a path by platform.
  - Web: `GoogleAuthProvider` with `signInWithPopup` at :280, falling back to `signInWithRedirect` at :292.
  - Desktop: `_directOAuthHandler.performDirectOAuthFlow()` at about :341. A comment there says "secure OAuth flow via Firebase Functions", but the call uses the Direct handler.
  - Android/iOS: `signInWithProvider` at :366.
  - Afterwards it merge-sets `users/{uid}` at :393/:407 with no role ("backend blocking function assigns").
- `lib/features/auth/data/services/auth_service.dart:16 (AuthService._googleSignIn) @ 7808a91`: `GoogleSignIn.instance` (v7). It is set up only on mobile, at :143 `_configureGoogleSignInForMobile`, and signed out at :512.

**Apple**
- `lib/features/auth/data/services/auth_service.dart:441 (AuthService.signInWithApple) @ 7808a91`: `OAuthProvider('apple.com').credential` then `signInWithCredential` at :447.
  - It creates `users/{uid}` at :473 with `'role': null` ("set during role selection"), or updates it at :487.

**Other AuthService methods**
- `lib/features/auth/data/services/auth_service.dart:527 (AuthService.updateUserRole) @ 7808a91` and `:564 (AuthService.saveUserRole)` write `users/{uid}.role` directly from the client. `updateUserRole` also writes `students/{uid}` at :546.
  - `git grep` finds no callers of either outside this file. The admin `updateUserRole` is a separate method in `UserManagementService`.
- `lib/features/auth/data/services/auth_service.dart:608 (AuthService.deleteAccount) @ 7808a91`: deletes `users/{uid}` at :622 and `students/{uid}` at :628.
- `lib/features/auth/data/services/auth_service.dart:687 (AuthService.reauthenticateWithGoogle) @ 7808a91` and `:743 (reauthenticateWithApple)`: re-authentication with the same providers.

**Desktop OAuth handlers**
- `lib/features/auth/data/services/desktop_oauth_handler_direct.dart:14 (DirectDesktopOAuthHandler) @ 7808a91`: the only handler that is used (instantiated at `auth_service.dart:19`).
  - Starts a loopback `HttpServer.bind('localhost', 0)` at :97.
  - Builds a PKCE S256 challenge at :104–114.
  - Posts the code to `oauth2.googleapis.com/token` at :184–191 with `code_verifier`.
  - Signs in with `GoogleAuthProvider.credential` and `signInWithCredential` at :149–154.
- `lib/features/auth/data/services/desktop_oauth_handler_secure.dart:12 (SecureDesktopOAuthHandler) @ 7808a91`: calls HTTP functions `getOAuthUrl`, `exchangeOAuthCode` and `refreshOAuthToken`, defined at :39–41.
  - The base URL is the emulator `localhost:5001/{project}/{region}` in debug, otherwise `https://us-east4-teacher-dashboard-flutterfire.cloudfunctions.net` (:25–35).
  - It signs in with `signInWithCustomToken` at :114.
  - It is not instantiated anywhere in `lib/` (grep for `SecureDesktopOAuthHandler(` finds nothing).
- `lib/features/auth/data/services/desktop_oauth_handler.dart:21 (DesktopOAuthHandler) @ 7808a91`: an older oauth2-package flow (Google auth/token/revoke URLs at :23–25, loopback at :54). It is not instantiated anywhere.

**Username sign-in**
- `lib/features/auth/data/services/username_auth_service.dart:81 (UsernameAuthService.signInWithUsername) @ 7808a91`:
  - Looks up the username in `public_usernames/{lower}` at :98.
  - If not found, queries `users where username==` at :117 and writes back `public_usernames/{lower}` {uid, role} at :133.
  - Then reads `users/{uid}` at :159 and calls `signInWithEmailAndPassword` at :176 with a synthetic email.
- `lib/features/auth/data/services/username_auth_service.dart:30 (UsernameAuthService.generateSyntheticEmail) @ 7808a91`: picks the synthetic email domain by role.
- The only place this service is instantiated is `lib/features/teacher/presentation/screens/manage_student_accounts_screen.dart:26`, and it is used there only for username generation and validation (:56, :62, :265).

**How auth state reaches the rest of the app**
- `lib/features/auth/providers/auth_provider.dart:40 (AuthProvider) @ 7808a91`: a `ChangeNotifier` that holds `AuthStatus` and `UserModel` (getters at :75–81).
  - `_initializeAuthState` at :86 runs once from the constructor. On web it checks `getRedirectResult`, then `currentUser.reload()`, then calls `_processUser` at :140.
  - `AuthProvider` does not subscribe to `authStateChanges` (grep finds no hits in this file).
  - `_processUser` auto-creates `users/{uid}` with `role:'admin'` for @fermi-plus.com at :155. It signs out if `userModel.role` is null at :171. It also starts `WebInAppNotificationService` and presence updates (about :566–590).
- `lib/features/auth/presentation/providers/auth_provider.dart:5 @ 7808a91`: re-exports `../../providers/auth_provider.dart`. Most imports in `lib/` go through this re-export.
- `lib/features/auth/data/services/auth_service.dart:155 (AuthService.authStateChanges) @ 7808a91`: exposes the stream. Within the area, only `lib/features/student/data/services/presence_service.dart:408 (PresenceService.initializePresence)` listens to `authStateChanges`.

**How the client reads the role**
- `lib/features/auth/providers/auth_provider.dart:397 (AuthProvider._loadUserModelWithRetry) @ 7808a91`: reads the `users/{uid}` document at :425/:432 and calls `UserModel.fromFirestore` at :408. The role is the `role` field in Firestore.
- There are no `getIdTokenResult` or `claims` calls anywhere in the area.
- `lib/features/auth/providers/auth_provider.dart:632 (AuthProvider.setSelectedRole) @ 7808a91`: a no-op.
- `lib/features/auth/providers/auth_provider.dart:638 (AuthProvider.createStudentAccount) @ 7808a91`: always throws.

**Other auth files**
- `lib/features/auth/presentation/screens/login_screen.dart:63 (_signInWithGoogle) @ 7808a91` and `:96 (_signIn)`: UI entry points that call the `AuthProvider` methods.
- `lib/features/auth/presentation/screens/forgot_password_screen.dart:30 @ 7808a91`: `sendPasswordResetEmail`.
- `lib/features/auth/presentation/screens/teacher_password_reset_screen.dart:49 (_TeacherPasswordResetScreenState) @ 7808a91`: `user.updatePassword`, then updates `users/{uid}` {needsPasswordReset:false, lastPasswordChange}.
- `lib/features/auth/presentation/widgets/profile_completion_dialog.dart:56 (_ProfileCompletionDialogState) @ 7808a91`: updates `users/{uid}` {firstName, lastName, displayName, profileComplete, updatedAt}.

**Not found in the area:** `initializeApp`, `FirebaseDatabase`, secondary apps. `lib/firebase_options.dart`, `service_locator.dart` and `app_initializer.dart` are outside the area.

## Q4. Storage
No `FirebaseStorage`, `.ref(`, `putFile`, `putData` or `getDownloadURL` in the area. `lib/features/auth/providers/auth_provider.dart:704 (AuthProvider.updateProfilePicture) @ 7808a91` only writes a `photoUrl` string to `users/{uid}`.

## Q5. Collections: users, public_usernames, presence, fcm_tokens, notifications

**users**
- Read sites:
  - `lib/features/admin/data/services/user_management_service.dart:21 (getUsersStream) @ 7808a91`: role filter and `orderBy createdAt`; also `:45 (getUsers)`, `:86 (getUserStats)`, `:322 (getUserDetails)`. `UserModel.fromFirestore` is used at :62.
  - `lib/features/admin/data/services/bulk_import_service.dart:303 (_checkEmailExists) @ 7808a91`: `where email`.
  - `lib/features/admin/presentation/providers/admin_provider.dart:56 (_loadSystemStats) @ 7808a91` and `:189 (_loadRecentUsers)`.
  - `lib/features/auth/data/services/auth_service.dart:383 (signInWithGoogle) @ 7808a91`; also `:452`, `:543`, `:597 (getUserData)`.
  - `lib/features/auth/providers/auth_provider.dart:425 (_getUserDataWithRetry) @ 7808a91`.
  - `lib/features/auth/data/services/username_auth_service.dart:65 (getUidByUsername) @ 7808a91`; also `:117`, `:159`, `:184`.
  - `lib/features/student/presentation/providers/student_provider.dart:29 (SimpleStudentProvider) @ 7808a91`: `where role==student`. At `:105` and `:165` it passes the collection reference to `FirestoreBatchQuery.batchWhereInDocumentId(collection: ...)`.
  - `lib/features/teacher/presentation/screens/manage_student_accounts_screen.dart:370 @ 7808a91`; `UserModel.fromFirestore` at :403.
- Write sites:
  - `lib/features/admin/data/services/user_management_service.dart:135 (updateUser) @ 7808a91`; also `:160 (updateUserRole)`, `:222 (bulkAssignToClasses)`, `:256 (bulkUpdateUsers)`.
  - `lib/features/auth/data/services/auth_service.dart:196, 244, 393, 407, 473, 487, 536, 578 @ 7808a91`: sets and updates; delete at :622.
  - `lib/features/auth/data/services/username_auth_service.dart:253 (createStudentAccount) @ 7808a91`; `:329 (createTeacherAccount)`; batch delete at `:381 (deleteUser)`.
  - `lib/features/auth/providers/auth_provider.dart:155, 697 (updateProfile), 708 (updateProfilePicture) @ 7808a91`.
  - `lib/features/auth/presentation/widgets/profile_completion_dialog.dart:56 @ 7808a91` and `lib/features/auth/presentation/screens/teacher_password_reset_screen.dart:49 @ 7808a91`.
  - `lib/features/notifications/data/services/firebase_messaging_service.dart:241 (_saveFCMToken) @ 7808a91`: fcmToken, fcmTokenUpdatedAt, platform; cleared at `:407 (deleteToken)`.
  - `lib/features/student/presentation/providers/student_provider.dart:228 @ 7808a91`: set after a client-side `FirebaseAuth.instance.createUserWithEmailAndPassword` at :221. Update at :259, delete at :273.
- Shape: `UserModel` is defined outside the area (only used here).

**public_usernames**
- `lib/features/auth/data/services/username_auth_service.dart:50 (isUsernameAvailable) @ 7808a91`: read.
- Same file, `:98, 133 (signInWithUsername)`: read and write.
- Same file, `:268, 343`: set {uid, role, ...}.
- Same file, `:384`: delete.

**presence**
- `lib/features/student/data/services/presence_service.dart:92 (updateUserPresence) @ 7808a91`.
- Same file, reads at `:219`, `:259`, `:363`, `:388`, `:466`, `:517`, `:558` (`where online==true`); writes at `:539 (batchUpdatePresence)`.
- Shape: `_buildPresenceData` at :151 {online, lastSeen, uid, displayName, photoURL, role, isAnonymous, metadata}. `PresenceMetadata.fromMap/toMap` at :634/:641.
- `lib/features/admin/presentation/providers/admin_provider.dart:102 (_loadSystemStats) @ 7808a91`: `where online==true`.
- Presence uses Firestore only. There is no Realtime Database usage.

**fcm_tokens**
- `lib/features/notifications/data/services/firebase_messaging_service.dart:248 (_saveFCMToken) @ 7808a91`: set {token, userId, platform, updatedAt}.
- Same file, `:412 (deleteToken)`: delete.

**notifications**
- `lib/features/notifications/data/services/firebase_notification_service.dart:11 (FirebaseNotificationService._notificationsCollection) @ 7808a91`.
  - Queries on userId, isRead, type and `orderBy createdAt` at :25–35, :65, :96, :130, :153.
  - Updates at :113/:118, delete at :143, `.doc()` create at :284.
- `lib/features/notifications/data/services/notification_service.dart:303 (_storeNotificationRecord) @ 7808a91`: adds {type, title, message, relatedId, scheduledFor, createdAt, status}. There is no userId field.
- `lib/features/notifications/data/services/web_in_app_notification_service.dart:47 (startListening) @ 7808a91`: `where userId, read==false`. Update at :116, add at :137.
- The field names differ between services: `isRead` in `firebase_notification_service` vs `read` in `web_in_app_notification_service`.
- Models:
  - `lib/features/notifications/domain/models/notification_model.dart:47 (NotificationModel.fromFirestore) @ 7808a91`; `toFirestore` at :76.
  - `lib/features/notifications/domain/models/notification.dart:124 (Notification.fromFirestore) @ 7808a91`; `toFirestore` at :146.

**Not found:** `scheduled_messages`, `bug_reports`. Also no `collection(this.collectionName)`, `collection(path)` or `collection(collectionPath)` call sites in the area.

## Q6. Collections: classes, students, assignments, submissions, grades, calendar_events

**students**
- `lib/features/student/data/services/student_service.dart:37 (StudentService constructor) @ 7808a91`: `_studentsCollection`.
  - CRUD at :71, :228, :246, :263, :282, :304, :324; batches at :350, :379, :407, :434.
  - Queries on userId, isActive, classIds arrayContains, gradeLevel, `orderBy displayName` (:91–175).
  - `:541 (createStudentDocumentIfMissing)`: `where uid`.
- `lib/features/student/domain/models/student.dart:120 (Student.fromFirestore) @ 7808a91`; `toFirestore` at :163.
- `lib/features/students/data/models/student_enhanced.dart:79 (StudentEnhanced.fromFirestore) @ 7808a91`; `toFirestore` at :118.
- `lib/features/admin/data/services/bulk_import_service.dart:195 (bulkAssignToClasses) @ 7808a91`.
- `lib/features/auth/data/services/auth_service.dart:546 (updateUserRole) @ 7808a91`: set; delete at :628.

**classes**
- `lib/features/admin/data/services/bulk_import_service.dart:202 (bulkAssignToClasses) @ 7808a91`.
- `lib/features/admin/data/services/user_management_service.dart:230 (bulkAssignToClasses) @ 7808a91`; `:303 (getAvailableClasses)` with `orderBy name`; `:329 (getUserDetails)` with `where studentIds arrayContains`.
- `lib/features/student/presentation/providers/student_provider.dart:291, 306 @ 7808a91`: updates.

**assignments**
- `lib/features/dashboard/data/services/dashboard_service.dart:68, 75, 81 (getTeacherAssignmentStats) @ 7808a91`; `:109, 116 (getStudentAssignmentStats)`; `:153 (getUpcomingAssignments)`. `Assignment.fromFirestore` is used at :162.

**grades**
- `lib/features/dashboard/data/services/dashboard_service.dart:174 (getRecentGrades) @ 7808a91`: top-level `collection('grades')`, `where studentId, isGraded`, `orderBy gradedAt`.
- Same file, `:192 (calculateGPA)`. `Grade.fromFirestore` at :181/:203.
- No `collectionGroup('grades')` in the area.

**Not found:** `submissions`, `calendar_events`. `CalendarEvent` is only referenced as a type in `notification_service.dart:218`.

## Q7. Collections: chatRooms, conversations, messages, typing, discussion_boards, threads, replies, likes
None of these appear in the area. `lib/features/student/presentation/screens/messages_screen.dart` and `lib/features/teacher/presentation/screens/messages_screen.dart` have no direct Firestore calls.

## Q8. Collections: studentPoints, behaviors, history, activities, jeopardy_*, oauth_pkce_challenges, _rate_limits

**activities**
- `lib/features/admin/data/services/bulk_import_service.dart:346 (_logBulkImportActivity) @ 7808a91`: add.
- `lib/features/admin/data/services/user_management_service.dart:339 (getUserDetails) @ 7808a91`: `where userId`, `orderBy timestamp`. Add at `:363 (_logActivity)`.
- `lib/features/admin/presentation/providers/admin_provider.dart:146 (_loadSystemStats) @ 7808a91`; `:215 (_loadRecentActivities)`.
- `lib/features/dashboard/data/services/dashboard_service.dart:18 (getTeacherActivities) @ 7808a91`; `:48 (getStudentActivities)` with `classId whereIn`; add at `:135 (logActivity)`.
- `lib/features/dashboard/domain/models/activity_model.dart:43 (ActivityModel.fromFirestore) @ 7808a91`; `toMap` at :64.

**Not found:** studentPoints, behaviors, history, the jeopardy collections, `oauth_pkce_challenges`, `_rate_limits`.

## Q11. Push notifications

**FirebaseMessagingService**
- `lib/features/notifications/data/services/firebase_messaging_service.dart:45 (FirebaseMessagingService.initialize) @ 7808a91`:
  - Calls `_requestPermissions` at :124 (`requestPermission` at :127/:130).
  - Registers `FirebaseMessaging.onBackgroundMessage` at :62. The handler at :14 only logs.
  - Subscribes to `onMessage` at :67, `onMessageOpenedApp` at :72 and `onTokenRefresh` at :93.
- `_updateFCMToken` at :149: `getToken`, using `vapidKey` on web (:178–219).
- `_saveFCMToken` at :235 writes to `users` and `fcm_tokens` (see Q5).
- `_handleForegroundMessage` at :277:
  - Skips chat messages when `_activeConversationId` matches. That ID is set by `markConversationActive` at :119, together with the route resolver.
  - Otherwise calls `NotificationService().sendImmediateNotification` at about :310.
- `_handleMessageOpenedApp` at :323 routes by `data.type`: chat goes to the conversation; assignment, grade and behavior go to `/assignments`, `/grades` and `/behavior`.

**NotificationService (local notifications)**
- `lib/features/notifications/data/services/notification_service.dart:24 (NotificationService._localNotifications) @ 7808a91`: a `FlutterLocalNotificationsPlugin`.
  - `_initializeLocalNotifications` at :323 creates an `AndroidNotificationChannel` at :367.
  - `requestPermissions` at :63 handles Android and iOS; `_onNotificationResponse` is at :385.
- `sendImmediateNotification` (:250), `scheduleEventReminder` (:218), `scheduleAssignmentReminder` (:234) and `cancel*` (:270, :278) are labelled stubs.
  - They only write a `notifications` doc through `_storeNotificationRecord`.
  - No `.show(` or `zonedSchedule` call exists in the area.

**Web**
- `lib/features/notifications/data/services/notification_service_web.dart:27 (requestPermission) @ 7808a91`: browser `Notification.requestPermission`.
- `lib/features/notifications/data/services/notification_service_stub.dart:5 @ 7808a91`: the non-web stub.
- `lib/features/notifications/data/services/web_in_app_notification_service.dart:8 (WebInAppNotificationService) @ 7808a91`: a Firestore listener, started from `AuthProvider` (`auth_provider.dart` about :568).

`app_initializer.dart` and `flyer_chat_screen.dart` are outside the area.

## Q12. Cloud Functions callables

**`lib/features/admin/data/services/bulk_import_service.dart` @ 7808a91** (uses `FirebaseFunctions.instanceFor(region:'us-east4')`, :9)

| Line (symbol) | Callable | Arguments |
|---|---|---|
| :66 (bulkImportStudents) | `bulkImportStudents` | {users, sendPasswordResetEmails:true} |
| :154 (bulkImportTeachers) | `createTeacherAccount` | {email, password, displayName, subjects} |

**`lib/features/admin/data/services/user_management_service.dart` @ 7808a91** (uses `FirebaseFunctions.instance`, default region, :10)

| Line (symbol) | Callable | Arguments |
|---|---|---|
| :154 (updateUserRole) | `updateUserRole` | {userId, newRole}; then also writes `users.role` directly at :160 |
| :179 (resetUserPassword) | `resetUserPassword` | {userId} |
| :203 (deleteUser), :285 (bulkDeleteUsers) | `deleteUserAccount` | {userId} |

**`lib/features/admin/presentation/providers/admin_provider.dart` @ 7808a91** (uses `FirebaseFunctions.instance`, :13)

| Line (symbol) | Callable | Arguments |
|---|---|---|
| :237 (createStudentAccount) | `createStudentAccount` | {username, password, displayName, grade} |
| :271 (createTeacherAccount) | `createTeacherAccount` | {email, password, displayName} |
| :300 (deleteUser) | `deleteUserAccount` | {userId} |
| :319 (resetUserPassword) | `resetUserPassword` | {userId} |
| :345 (bulkCreateStudent) | `createStudentAccount` | {email, displayName, gradeLevel, password, parentEmail, classIds, isGoogleAuth} |
| :376 (bulkCreateTeacher) | `createTeacherAccount` | {email, password, displayName, subjects} |

The client uses two region setups: `bulk_import_service.dart` sets us-east4, while the other two files use the default instance.

There are also HTTP (not callable) function endpoints in `desktop_oauth_handler_secure.dart:39–41` (`getOAuthUrl`, `exchangeOAuthCode`, `refreshOAuthToken`), but that class is unused.

## Q13. Tests
The area has no test files. The only test-related hook is that `StudentService` accepts an injected `firestore` "for unit testing" (`lib/features/student/data/services/student_service.dart:34 @ 7808a91`). `test/`, `functions/` and `firebase.json` are outside the area.

## Searched and found nothing (all at 7808a91, area paths)
- `FirebaseStorage|putFile|putData|getDownloadURL`
- `FirebaseDatabase|onDisconnect|ServerValue`
- `getIdTokenResult|claims`
- `collectionGroup(`
- `collection(` with a non-literal argument
- `zonedSchedule|.show(`
- `subscribeToTopic`
- `initializeApp`
- The collection names: scheduled_messages, bug_reports, submissions, calendar_events, chatRooms, conversations, messages, typing, discussion_boards, threads, replies, likes, studentPoints, behaviors, history, jeopardy_*, oauth_pkce_challenges, _rate_limits
- `fromFirestore|fromMap|toMap` in `lib/features/admin/domain/models/admin_user.dart` and `system_stats.dart`