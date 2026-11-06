Everything below comes from `git grep` and `git show` at 7808a91, limited to `functions/` (minus `functions/cloudflare-email-worker.js`). All citations are `@ 7808a91`.

**About `functions/lib/`:** it is not tracked at the commit. `functions/.gitignore` ignores `lib/**/*.js` and `lib/**/*.js.map`, and `functions/tsconfig.json` builds `src` into `outDir: "lib"`. So it is compiled output of `functions/src/`, and `functions/package.json` (`"main": "lib/index.js"`) points at it. The untracked copy in the working tree is out of date: it has no `behaviorPoints.js`, `bulkImport.js` or `chatFunctions.js`. I left it out.

**Wiring:** `functions/src/index.ts:14` calls `admin.initializeApp()`. `index.ts:29` (setGlobalOptions) sets `maxInstances: 10` and `region: "us-east4"`. Lines 35–59 re-export, with `export *`, from customClaims, oauth, cleanup, migrate-user-roles-cloud, adminFunctions, bulkImport, chatFunctions, authBlocking and behaviorPoints.

---

### Q2: how role claims are assigned and changed
- `functions/src/authBlocking.ts:13 (autoAssignRole) @ 7808a91`
  - **Trigger:** `beforeUserCreated`, an Auth blocking function.
  - Rejects users with no email (line 28) or an email outside the school domains (line 37).
  - Gets the role from `getRoleFromEmail` (line 53).
  - **Writes:** `users/{uid}` with `{email, displayName, role, createdAt, emailVerified:false, isEmailUser:true, profileComplete:false}` (line 73), and a `user_created` entry in `activities` (line 84).
  - **Returns** `customClaims: {role, emailDomain}` and sets `emailVerified` to true only when the role is admin (lines 106–110).
- `functions/src/config/domainRoles.ts:7 (DOMAIN_ROLE_MAPPINGS) @ 7808a91`
  - `@roselleschools.org` maps to teacher, `@rosellestudent.org` to student, `@fermi-plus.com` to admin.
  - `ADMIN_EMAILS` is empty (line 26).
  - `getRoleFromEmail` (line 33) and `isValidSchoolEmail` (line 56) do suffix matching.
- `functions/src/customClaims.ts:10 (setRoleClaim) @ 7808a91`
  - **Trigger:** `onCall`, with `{uid, role}`.
  - Accepts only `teacher` or `student` (line 29).
  - The caller must have a teacher role in their `users` doc, or must be setting their own uid (line 46).
  - **Writes:** `admin.auth().setCustomUserClaims(uid,{role})` (line 54) and `users/{uid}.update({role})` (line 60).
- `functions/src/customClaims.ts:80 (syncUserRole) @ 7808a91`
  - **Trigger:** `onDocumentWritten` on `users/{userId}` (line 81).
  - Does nothing if the role did not change (line 90).
  - On delete it calls `setCustomUserClaims(userId, null)` (line 97).
  - Otherwise it sets `{role}` only for teacher or student (lines 107–109). An `admin` role in Firestore is not synced to a claim here.
- `functions/src/migrate-user-roles.ts:12 (migrateUserRoles) @ 7808a91`
  - A standalone Node script, not exported from index. It runs `initializeApp` at line 10 and is started by the npm script `migrate:roles` in `functions/package.json`.
  - Reads every `users` doc (line 20) and calls `setCustomUserClaims(userId,{role})` for teacher or student (line 41).
- `functions/src/migrate-user-roles-cloud.ts:13 (migrateAllUserRoles) @ 7808a91`
  - **Trigger:** `https.onCall`. The caller's `users` role must be teacher (line 32).
  - Does the same full loop over `users` (line 46) with `setCustomUserClaims` (line 69).
- **Other code that sets claims:**
  - `adminFunctions.ts:127`, `:248` and `:350` (createStudentAccount, createTeacherAccount, createAdminAccount) set `{role}`.
  - `bulkImport.ts:228` (bulkImportStudents) sets `record.customClaims = {role:"student"}` and passes it to `auth.importUsers` (line 244).
  - `oauth.ts:311` (exchangeOAuthCode) calls `createCustomToken(uid,{provider:"google.com", email})`, with no role in it.

### Q4: Storage
- `functions/src/chatFunctions.ts:339 (uploadChatFile) @ 7808a91`
  - Writes the object `chat-attachments/${conversationId}/${userId}/${timestamp}_${sanitizedFileName}` with `bucket.file().save` (line 348), with metadata `uploadedBy`, `conversationId` and `originalName`.
  - Returns a signed URL from `getSignedUrl`, `expires: "03-01-2500"` (line 360).
  - Admin SDK calls bypass `storage.rules`.
- The comment at `customClaims.ts:7–8` says claims are "needed for Storage rules to check if a user is a teacher".

### Q5: `users`, `public_usernames`, `presence`, `fcm_tokens`, `notifications`, `scheduled_messages`, `bug_reports`
- **`users`:**
  - The functions code defines no model type for it. The shape is set inline at `authBlocking.ts:73`, `adminFunctions.ts:132 (createStudentAccount)`, `:253`, `:355` and `bulkImport.ts:295 (bulkImportStudents)`. The bulk import also writes `studentId`, `classId` and `enrolledClasses`.
  - Role-check reads by the caller's uid: `adminFunctions.ts:56` and at every other export, `bulkImport.ts:45`/`:563`, `customClaims.ts:39`, `behaviorPoints.ts:54`, `migrate-usernames.ts:26`/`:164`, `migrate-user-roles-cloud.ts:27`.
  - Full scans: `adminFunctions.ts:553 (getSystemStats)`, `migrate-user-roles*.ts:20/46`, and `migrate-usernames.ts:46`/`:195`, which query `where("username","!=",null)`.
  - `bulkImport.ts:574 (migrateStudentClassEnrollment)` queries `where("role","==","student")` and updates `classId`, `enrolledClasses` and deletes `className` (line 620).
  - Delete: `adminFunctions.ts:438 (deleteUserAccount)`.
  - The chat code reads the fields `name`, `role` and **`fcmToken`** from `users`: `chatFunctions.ts:75`, `:245`, `:397–399 (sendPushNotifications)`.
- **`public_usernames`:** `migrate-usernames.ts:77` reads it, and `:92` and `:222` write `{uid, role, migratedAt}` keyed by `username.toLowerCase()`.
- **Variable collection names:** `collection(this.collectionName)` is at `functions/src/rate-limiter.ts:34 (rejectOnQuotaExceededOrRecordUsage)`, and `collectionName` is `"_rate_limits"` (line 18). The calls `collection(path)` and `collection(collectionPath)` do not appear in `functions/src`.
- **Not found** in `functions/src` (searched `presence|fcm_tokens|notifications|scheduled_messages|bug_reports`): no collection access. The only matches are comments and log strings in `chatFunctions.ts`. Push tokens come from the `users.fcmToken` field, not from an `fcm_tokens` collection.

### Q6: `classes`, `students`, `assignments`, `submissions`, `grades`, `calendar_events`
- **`classes`:**
  - `adminFunctions.ts:149 (createStudentAccount)` does a batch `update` with `studentIds: arrayUnion` and `updatedAt`.
  - `bulkImport.ts:167` reads it.
  - `bulkImport.ts:180` queries `where("enrollmentCode","==",…)`, `where("isActive","==",true)` and `limit(1)`.
  - `bulkImport.ts:348` and `:648` do `studentIds` arrayUnion updates.
  - `bulkImport.ts:588` reads every class (uses the `name` field).
  - `behaviorPoints.ts:64`, `:195`, `:309` and `:400` check ownership with `teacherId || teacherUID` (for example at line 74).
- **Not found** (searched `"students"|assignments|submissions|grades|calendar_events`): no collection access and no `collectionGroup('grades')`. The only match is a comment at `bulkImport.ts:154`.

### Q7: `chatRooms`, `conversations`, `messages`, `typing`, `discussion_boards`, `threads`, `replies`, `likes`
- **`conversations`:**
  - `chatFunctions.ts:13 (ensureConversationMembership)` checks `participants ?? participantIds` (line 24).
  - `:87` uses `doc().id` only to generate an id.
  - `:105` and `:125 (sendMessage)` update `lastMessage`, `lastActivity` and `unreadCount.<uid>`.
  - `:188 (markMessagesAsRead)` resets `unreadCount.<uid>`.
- **`conversations/{id}/messages`:**
  - `chatFunctions.ts:99 (sendMessage)` sets `{id, authorId, authorName, authorRole, text, attachments, createdAt, sentAt, metadata}`.
  - `:177 (markMessagesAsRead)` updates `seenAt` and `readBy.<uid>`.
- **`conversations/{id}/typing/{uid}`:** `chatFunctions.ts:236 (updateTypingStatus)` sets `{isTyping, startedAt, userName}` and deletes it again (line 256 in a `setTimeout`, and line 265).
- **Not found** (searched `chatRooms|discussion_boards|threads|replies|likes`): none.

### Q8: `studentPoints`, `behaviors`, `history`, `activities`, `jeopardy_*`, `oauth_pkce_challenges`, `_rate_limits`
- **`classes/{classId}/studentPoints/{studentId}`:**
  - `behaviorPoints.ts:102 (awardBehaviorPoints)` does a merge set of `{studentId, studentName, totalPoints, positivePoints, negativePoints, behaviorCounts.<id>, lastUpdated, lastUpdatedBy}` (line 106).
  - `:237 (undoBehaviorPoints)` updates it.
  - `:333 (getClassPointsSummary)` reads the collection.
- **`.../studentPoints/{id}/history/{operationId}`:**
  - `behaviorPoints.ts:86` checks for an existing operation id (idempotency), and `:125` sets `{operationId, studentId, studentName, behaviorId, behaviorName, points, type, teacherId, teacherName, awardedBy, awardedByName, timestamp, awardedAt, isUndone, classId, gender, gradeLevel, studentAvatarUrl, note}`.
  - `:214`/`:254 (undoBehaviorPoints)` set `isUndone`, `undoneBy` and `undoneAt`.
  - `collectionGroup("history")` is queried at `:427 (getBehaviorHistory)` with filters on `classId` and `isUndone==false`, optional `studentId`, `gender`, `type` and a `timestamp` range, then `orderBy("awardedAt","desc")`, `offset` and `limit` (lines 428–469). A count query at `:494` uses the same filters except the date range (line 508).
- **`activities`:** `add` at `adminFunctions.ts:160`, `:263`, `:365`, `:441` and `:507`, at `bulkImport.ts:395`, and at `authBlocking.ts:84`. `adminFunctions.ts:570 (getSystemStats)` queries `where("timestamp", ">", oneDayAgo)`.
- **`oauth_pkce_challenges`:**
  - The shape is `PKCEChallenge {codeVerifier, expiresAt:number, createdAt, clientId?}` at `functions/src/types/oauth.types.ts:30 @ 7808a91`.
  - `oauth.ts:64 (getPKCECollection)` is the accessor. `:129` sets it, `:222` reads it, and `:229`/`:240` delete it.
  - `cleanup.ts:21` and `:131` query `where("expiresAt","<",now)` (lines 29 and 139) and `where("createdAt","<",30 days ago)` (lines 73 and 151), then delete in batches or one by one. Line 163 runs `count()`.
- **`_rate_limits`:** `rate-limiter.ts:18` names it. `:34–79` run a transaction that writes `{count, firstCall, lastCall}` (interface at line 9), with doc id `${name}_${identifier}`. `:102` queries `where("lastCall","<",…)` with `limit(500)` and batch-deletes.
- **Not found** (searched `behaviors|jeopardy`): none. Behavior ids arrive as callable parameters and are not read from a collection.

### Q9: adminFunctions, bulkImport, oauth, cleanup
- **`functions/src/adminFunctions.ts`** (all are `onCall` and all require the caller's `users.role == "admin"`):
  - **createStudentAccount** (`:47`)
    - **Arguments:** `{email, password, displayName, gradeLevel, parentEmail, classIds, isGoogleAuth}`.
    - The email domain must be `@rosellestudent.org` or `.com` (line 75).
    - When `isGoogleAuth` is set it calls `auth.getUserByEmail`, otherwise `auth.createUser` (`emailVerified:true`).
    - Then: `setCustomUserClaims` with student, a `users` set, a batch arrayUnion on `classes`, and an `activities` add.
  - **createTeacherAccount** (`:199`)
    - **Arguments:** `{email, password, displayName}`.
    - Requires an `@roselleschools.org` email (line 230).
    - Calls `createUser` and `setCustomUserClaims` (teacher), then writes `users` and `activities`.
  - **createAdminAccount** (`:299`)
    - Requires an `@fermi-plus.com` email and a password of 8 or more characters (lines 331–337).
    - Same calls as the teacher flow, with the admin role.
  - **deleteUserAccount** (`:401`)
    - **Arguments:** `{userId}`. Admins cannot delete themselves (line 425).
    - Reads `users`, calls `auth.deleteUser` (line 435), deletes the `users` doc, and adds to `activities`.
  - **resetUserPassword** (`:470`)
    - **Arguments:** `{userId}`.
    - Generates a password with `generateSecurePassword` (line 14, using `crypto.randomBytes`), then calls `auth.updateUser({password})` (line 498) and adds to `activities`.
  - **getSystemStats** (`:535`)
    - Counts every `users` doc by role (lines 553–560) and queries `activities` for the last 24 hours (line 570).
- **`functions/src/bulkImport.ts`** (both are `onCall` and require an admin):
  - **bulkImportStudents** (`:31`)
    - Options: 512MiB memory, 300s timeout.
    - **Arguments:** `{users, csvData, sendPasswordResetEmails=true}`.
    - Calls `auth.getUserByEmail` to find existing users (line 130) and looks up `classes` by id or `enrollmentCode`.
    - Creates the accounts with `auth.importUsers` and a `customClaims` role (line 244).
    - Then: a batch set of `users` docs, `classes` arrayUnion updates, `auth.generatePasswordResetLink` (only logged, line 369), and an `activities` add.
  - **migrateStudentClassEnrollment** (`:549`)
    - Maps `users.className` to a `classes` id by name, then updates the user and the class's `studentIds`.
- **`functions/src/oauth.ts`** (all are `onRequest` with `cors: true`, the secrets `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` via `defineSecret` at lines 21–22, and Firestore-backed rate limits through security.ts):
  - **getOAuthUrl** (`:70`)
    - Takes the redirect URI from the query string and allows localhost only.
    - Creates a state and a PKCE verifier/challenge, sets the `oauth_pkce_challenges/{state}` doc, and returns `{authUrl, state, codeVerifier}` (line 146).
  - **exchangeOAuthCode** (`:170`)
    - **Request body:** `{code, state, codeVerifier, redirectUri}`.
    - Checks the stored verifier and expiry, then deletes the doc.
    - Exchanges the code for tokens at Google's token endpoint, then fetches the userinfo.
    - Calls `auth.getUserByEmail`, falling back to `auth.createUser` (lines 299–302), then `createCustomToken` (line 311).
    - Returns `{firebaseToken, googleTokens, user}`.
  - **refreshOAuthToken** (`:350`)
    - **Request body:** `{refreshToken}`.
    - Sends a `refresh_token` grant to Google and returns `{accessToken, expiresIn, idToken}`.
    - Touches only `_rate_limits` in Firestore.
- **`functions/src/cleanup.ts`:**
  - **cleanupExpiredPKCEChallenges** (`:9`)
    - **Trigger:** `onSchedule` "every 1 hours", America/New_York, `retryCount: 3`.
    - Batch-deletes expired `oauth_pkce_challenges` docs, and also docs whose `createdAt` is more than 30 days old.
  - **manualPKCECleanup** (`:129`)
    - A plain async function, not a trigger. It is re-exported by `index.ts:41`, but nothing in the searched paths calls it (search: `manualPKCECleanup`).

### Q10: chatFunctions, behaviorPoints, security, rate-limiter, migrate-usernames
- **`functions/src/chatFunctions.ts`:**
  - All four exports are v2 `https.onCall` and all are exported through `index.ts:53`.
  - Module-level Admin SDK handles: `admin.messaging()` (line 6) and `admin.storage()` (line 7).
  - Every export checks membership through `ensureConversationMembership` (line 9), which is not exported.
  - **sendMessage** (`:43`, `{conversationId, text, attachments}`)
    - Writes to `messages`, updates the `conversations` doc, then calls `sendPushNotifications` (line 386, not exported).
    - `sendPushNotifications` reads `users.fcmToken` and calls `messaging.sendEachForMulticast` (line 419) with data `{type:"chat", conversationId}`.
  - **markMessagesAsRead** (`:146`, `{conversationId, messageIds}`).
  - **updateTypingStatus** (`:209`, `{conversationId, isTyping}`).
  - **uploadChatFile** (`:283`, `{conversationId, fileName, mimeType, base64Data, fileSize}`)
    - Limit: 10MB.
    - Allowed MIME types are listed at line 317.
    - Writes to Storage and returns a signed URL.
- **`functions/src/behaviorPoints.ts`:**
  - All four exports are v2 `https.onCall` and all are exported through `index.ts:59`.
  - **awardBehaviorPoints** (`:31`, `maxInstances: 50`)
    - Requires the teacher role in `users`, and the class's `teacherId` or `teacherUID` must equal the caller.
    - Batch writes the aggregate and the history entry.
  - **undoBehaviorPoints** (`:162`, `{classId, studentId, historyId}`)
    - Same checks.
    - Updates the aggregate with negative increments (line 240) and marks the history entry undone.
  - **getClassPointsSummary** (`:274`, `{classId}`)
    - Teachers only. Students get "use a different endpoint" (line 326).
    - Reads `studentPoints`.
  - **getBehaviorHistory** (`:352`)
    - A teacher must own the class. A student has `studentId` forced to their own uid (line 420).
    - Runs the collection-group query with a count.
- **`functions/src/security.ts`:**
  - No triggers, so it is not exported from index. oauth.ts imports it.
  - Exports: `createRateLimiter` (`:8`); `oauthRateLimiters` (`:26`, with getUrl 10/60s, exchangeCode 5/60s, refreshToken 20/60s); `applyRateLimit` (`:38`, which throws `resource-exhausted`); `oauthValidator` (`:69`); `securityHeaders` (`:167`); `applySecurityHeaders` (`:177`); `getClientIdentifier` (`:184`, which reads x-forwarded-for, then x-real-ip, then the remote address).
- **`functions/src/rate-limiter.ts`:**
  - No triggers, so it is not exported from index.
  - `export class FirestoreRateLimiter` (`:15`), with `rejectOnQuotaExceededOrRecordUsage` at line 32. It is fail-open: errors other than the quota error are only logged (line 86).
  - `cleanupOldRateLimitRecords` (`:92`) is never called (search: `cleanupOldRateLimitRecords`).
- **`functions/src/migrate-usernames.ts`:**
  - **Not imported by `index.ts`**, so it is not deployed.
  - **migrateUsernamesToPublic** (`:12`, `https.onCall`): the caller must be a teacher or admin. It copies `users.username` into `public_usernames`.
  - **migrateUsernamesHttp** (`:146`, `https.onRequest`): Bearer token, then `auth().verifyIdToken` (line 159), the same role check, then runs `runMigration` (line 190, not exported).

### Q12: callables defined here, for matching against client calls
| Callable | Arguments |
|---|---|
| `setRoleClaim` | `{uid, role}` |
| `migrateAllUserRoles` | `{}` |
| `createStudentAccount`, `createTeacherAccount`, `createAdminAccount` | see Q9 |
| `deleteUserAccount`, `resetUserPassword` | `{userId}` |
| `getSystemStats` | none |
| `bulkImportStudents`, `migrateStudentClassEnrollment` | see Q9 |
| `sendMessage`, `markMessagesAsRead`, `updateTypingStatus`, `uploadChatFile` | see Q10 |
| `awardBehaviorPoints`, `undoBehaviorPoints`, `getClassPointsSummary` | see Q10 |
| `getBehaviorHistory` | `{classId, studentId?, gender?, behaviorType?, startDate?, endDate?, limit?, offset?}` |
| `migrateUsernamesToPublic` | not deployed |

The OAuth endpoints (`getOAuthUrl`, `exchangeOAuthCode`, `refreshOAuthToken`) are HTTP endpoints, not callables. All functions run in region `us-east4`.

### Q13: tests in `functions/`
- `functions/package.json` lists `firebase-functions-test ^3.3.0` as a devDependency. It has `lint`, `build` and `serve` scripts (serve is `firebase emulators:start --only functions`) and no `test` script.
- No test files are tracked under `functions/` (`git ls-tree` shows only src, config and lockfile). A search for `describe(|it(|jest|mocha` found nothing.

### Questions with nothing in this area
For Q1, Q3 and Q11 there is no client or rules code under `functions/`. On the server side for Q11, the push sending is `chatFunctions.ts:386–419`. History touching `functions/src` (last 10 commits, newest first): db051f7, 40224ae, ba5bc32, 1c81d68, b06fe44, 9cd9b77, efb2396, 67264c3, 3e0d950, 26168d4.