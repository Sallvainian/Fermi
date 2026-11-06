# Q10 digest: exported functions in five `functions/src` modules @ 7808a91

**Answer.** `chatFunctions.ts` (4 callables) and `behaviorPoints.ts` (4 callables) are re-exported from `functions/src/index.ts`, so they deploy. `migrate-usernames.ts` defines one callable and one HTTP trigger, but `index.ts` does not export either, so they are not deployed from this entry point. `security.ts` and `rate-limiter.ts` hold no triggers. They are helpers: `oauth.ts` uses `security.ts`, and nothing outside `rate-limiter.ts` calls `cleanupOldRateLimitRecords`. None of the five modules has a schedule, Firestore-event or auth-event trigger.

## Entry point
- The package entry is `"main": "lib/index.js"` (functions/package.json:17 @ 7808a91). `firebase.json` is not tracked at 7808a91, so I could not check whether it names another source (UNVERIFIED).
- `index.ts` calls `admin.initializeApp()` (functions/src/index.ts:14 @ 7808a91) and sets global options `maxInstances: 10, region: "us-east4"` (functions/src/index.ts:29-32 @ 7808a91).
- **Load-bearing:** `index.ts` re-exports `./chatFunctions` (functions/src/index.ts:53 @ 7808a91) and `./behaviorPoints` (functions/src/index.ts:59 @ 7808a91). It has no line for `./security`, `./rate-limiter` or `./migrate-usernames` (functions/src/index.ts:35-59 @ 7808a91).

## chatFunctions.ts
All four are v2 `functions.https.onCall` with `maxInstances: 10, region: "us-east4"`, and all are exported via index.ts:53. **Load-bearing.**

Module-level setup:
- It creates `admin.firestore()`, `admin.messaging()` and `admin.storage()` at load time (functions/src/chatFunctions.ts:5-7 @ 7808a91).

**`ensureConversationMembership`** (not exported, helper)
- Reads `conversations/{id}`. If the doc is missing it throws `not-found` (functions/src/chatFunctions.ts:13-21 @ 7808a91).
- It takes `participants`, falling back to `participantIds`, and keeps only string entries (functions/src/chatFunctions.ts:24-27 @ 7808a91).
- If the caller's uid is not in that list it throws `permission-denied` (functions/src/chatFunctions.ts:29-34 @ 7808a91).

**Errors are swallowed into `internal`.** Each of the four callables wraps its body in a catch that rethrows every error as `internal`. That includes the `not-found` and `permission-denied` errors from the membership check (functions/src/chatFunctions.ts:132-137, 195-200, 269-274, 373-378 @ 7808a91). Only the checks that run before the `try` reach the client with their own error code.

**`sendMessage`** (functions/src/chatFunctions.ts:43 @ 7808a91)
- **Authorization (load-bearing):** throws `unauthenticated` if `!request.auth` (functions/src/chatFunctions.ts:50 @ 7808a91). Then it calls the membership check (functions/src/chatFunctions.ts:69 @ 7808a91).
- **Input check:** `{conversationId, text, attachments}` are required. It throws `invalid-argument` if `conversationId` is missing or both `text` and `attachments` are missing (functions/src/chatFunctions.ts:61 @ 7808a91).
- **Reads:** `users/{senderId}`. If the doc is missing it throws `not-found`, which the catch turns into `internal` (functions/src/chatFunctions.ts:75-81 @ 7808a91).
- **Write 1:** `conversations/{id}/messages/{newId}` gets `id`, `authorId`, `authorName`, `authorRole`, `text` (trimmed), `attachments`, `createdAt`, `sentAt` and `metadata`. The id comes from `db.collection("conversations").doc().id` (functions/src/chatFunctions.ts:86-102 @ 7808a91). The `attachments` value is stored as sent, with no checks.
- **Write 2:** the conversation doc gets `lastMessage{text, authorId, authorName, createdAt}`, `lastActivity` and `unreadCount.{sender}=0` (functions/src/chatFunctions.ts:105-114 @ 7808a91).
- **Write 3:** a second update sets `unreadCount.{other}=increment(1)` for each other participant (functions/src/chatFunctions.ts:119-126 @ 7808a91).
- It then calls `sendPushNotifications` (functions/src/chatFunctions.ts:129 @ 7808a91).
- **Returns** `{success, messageId}`.

**`markMessagesAsRead`** (functions/src/chatFunctions.ts:146 @ 7808a91)
- **Authorization (load-bearing):** throws `unauthenticated` if there is no auth (functions/src/chatFunctions.ts:152 @ 7808a91), then calls the membership check (functions/src/chatFunctions.ts:170 @ 7808a91).
- **Input check:** throws `invalid-argument` unless `conversationId` is set and `messageIds` is an array (functions/src/chatFunctions.ts:162 @ 7808a91).
- **Writes (one batch):** each `conversations/{id}/messages/{mid}` gets `seenAt` and `readBy.{uid}`. The conversation gets `unreadCount.{uid}=0` (functions/src/chatFunctions.ts:173-192 @ 7808a91).
- It does not check the length of `messageIds`.
- **Returns** `{success, readCount}`.

**`updateTypingStatus`** (functions/src/chatFunctions.ts:209 @ 7808a91)
- **Authorization (load-bearing):** throws `unauthenticated` (functions/src/chatFunctions.ts:215 @ 7808a91), then calls the membership check (functions/src/chatFunctions.ts:233 @ 7808a91).
- **Input check:** throws `invalid-argument` if `conversationId` is missing or `isTyping === undefined` (functions/src/chatFunctions.ts:225 @ 7808a91).
- **When `isTyping` is true:**
  - It sets `conversations/{id}/typing/{uid}` to `{isTyping: true, startedAt, userName}`, reading `users/{uid}.name` for the name (functions/src/chatFunctions.ts:236-246 @ 7808a91).
  - It starts an 11-second `setTimeout` that deletes the doc if `startedAt` is more than 10 seconds old. This timer runs after the handler returns (functions/src/chatFunctions.ts:249-262 @ 7808a91).
- **When `isTyping` is false:** it deletes the doc (functions/src/chatFunctions.ts:265 @ 7808a91).
- **Returns** `{success}`.

**`uploadChatFile`** (functions/src/chatFunctions.ts:283 @ 7808a91; also sets `memory: "512MiB"`)
- **Authorization (load-bearing):** throws `unauthenticated` (functions/src/chatFunctions.ts:290 @ 7808a91), then calls the membership check (functions/src/chatFunctions.ts:334 @ 7808a91).
- **Input checks, each throwing `invalid-argument`:**
  - `conversationId`, `fileName`, `base64Data` or `mimeType` is missing (functions/src/chatFunctions.ts:301 @ 7808a91).
  - The client-supplied `fileSize` is over 10 MB (functions/src/chatFunctions.ts:309 @ 7808a91). The size of the decoded buffer is never checked.
  - `mimeType` is not one of 11 allowed types (functions/src/chatFunctions.ts:317-331 @ 7808a91).
- **Storage:**
  - Writes to `chat-attachments/{conversationId}/{uid}/{ts}_{sanitizedName}` in the default bucket via `storage.bucket().file().save` with `contentType` and `metadata{uploadedBy, conversationId, originalName}` (functions/src/chatFunctions.ts:338-357 @ 7808a91).
  - Then calls `getSignedUrl({action: "read", expires: "03-01-2500"})` (functions/src/chatFunctions.ts:360-363 @ 7808a91).
- It writes nothing to Firestore.
- **Returns** `{success, url, fileName, mimeType, fileSize: buffer.length, filePath}`.

**`sendPushNotifications`** (not exported, helper; functions/src/chatFunctions.ts:386 @ 7808a91)
- Reads `users/{id}.fcmToken` for each recipient (functions/src/chatFunctions.ts:396-400 @ 7808a91).
- Calls `messaging.sendEachForMulticast` with a notification (title is the sender name, body is the message cut to 100 characters), `data{type: "chat", conversationId}` and the tokens (functions/src/chatFunctions.ts:406-419 @ 7808a91).
- It catches all errors and does not rethrow (functions/src/chatFunctions.ts:425-428 @ 7808a91).

## behaviorPoints.ts
All four are v2 `onCall` with `maxInstances: 50, region: "us-east4"`, and all are exported via index.ts:59. **Load-bearing.** None of them calls Admin Auth, Storage or Messaging.

**`awardBehaviorPoints`** (functions/src/behaviorPoints.ts:31 @ 7808a91)
- **Authorization (load-bearing):**
  - Throws `unauthenticated` (functions/src/behaviorPoints.ts:40 @ 7808a91).
  - Throws `permission-denied` unless `users/{uid}.role === "teacher"` (functions/src/behaviorPoints.ts:53-60 @ 7808a91).
  - Throws `not-found` if the class is missing (functions/src/behaviorPoints.ts:68 @ 7808a91).
  - Throws `permission-denied` unless `classes/{classId}.teacherId`, falling back to `teacherUID`, equals the uid (functions/src/behaviorPoints.ts:74-77 @ 7808a91).
- **Input check:** throws `invalid-argument` if `classId`, `studentId` or `behaviorId` is missing (functions/src/behaviorPoints.ts:48 @ 7808a91). It does not check the type or range of `points`.
- **Idempotency check:** the `operationId` is `${teacherId}_${studentId}_${behaviorId}_${Date.now()}` (functions/src/behaviorPoints.ts:80 @ 7808a91). If `classes/{c}/studentPoints/{s}/history/{operationId}` already exists, it returns `{success: false}` (functions/src/behaviorPoints.ts:86-99 @ 7808a91).
- **Write 1 (batch):** `classes/{c}/studentPoints/{s}`, merged, gets `studentId`, `studentName`, `totalPoints` (incremented), `positivePoints` and `negativePoints` (incremented), `behaviorCounts.{behaviorId}` (incremented), `lastUpdated` and `lastUpdatedBy` (functions/src/behaviorPoints.ts:102-119 @ 7808a91).
- **Write 2 (batch):** the history doc gets `operationId`, `studentId`, `studentName`, `behaviorId`, `behaviorName`, `points`, `type`, `teacherId`, `teacherName`, `awardedBy`, `awardedByName`, `timestamp`, `awardedAt`, `isUndone: false`, `classId`, `gender`, `gradeLevel`, `studentAvatarUrl` and `note`. `teacherName` comes from `users.displayName`, then `name`, then the literal `'Teacher'` (functions/src/behaviorPoints.ts:122-145 @ 7808a91).
- **Returns** `{success, operationId, message}`.

**`undoBehaviorPoints`** (functions/src/behaviorPoints.ts:162 @ 7808a91)
- **Authorization (load-bearing):** the same four checks as `awardBehaviorPoints`: unauthenticated, teacher role, class exists, class owner (functions/src/behaviorPoints.ts:171, 189, 199, 205-208 @ 7808a91).
- **Input check:** throws `invalid-argument` if `classId`, `studentId` or `historyId` is missing (functions/src/behaviorPoints.ts:179 @ 7808a91).
- **History checks:**
  - Throws `not-found` if the history doc is missing (functions/src/behaviorPoints.ts:213-221 @ 7808a91).
  - Returns `{success: false}` if `isUndone` is already set (functions/src/behaviorPoints.ts:226 @ 7808a91).
- **Write 1 (batch):** `studentPoints/{s}` is updated with the reversed increments, `behaviorCounts.{id}` minus 1, `lastUpdated` and `lastUpdatedBy` (functions/src/behaviorPoints.ts:236-251 @ 7808a91).
- **Write 2 (batch):** the history doc gets `isUndone`, `undoneBy` and `undoneAt` (functions/src/behaviorPoints.ts:254-258 @ 7808a91).
- **Returns** `{success, message}`.

**`getClassPointsSummary`** (functions/src/behaviorPoints.ts:274 @ 7808a91)
- **Authorization (load-bearing):**
  - Throws `unauthenticated` (functions/src/behaviorPoints.ts:283 @ 7808a91).
  - Throws `permission-denied` if there is no users doc (functions/src/behaviorPoints.ts:301 @ 7808a91).
  - For a teacher: throws `not-found` if the class is missing, and `permission-denied` if the caller does not own it (functions/src/behaviorPoints.ts:306-322 @ 7808a91).
  - For a student: throws `permission-denied` (functions/src/behaviorPoints.ts:326 @ 7808a91).
  - For any other role: throws `permission-denied` (functions/src/behaviorPoints.ts:328 @ 7808a91).
- **Input check:** throws `invalid-argument` if `classId` is missing (functions/src/behaviorPoints.ts:290 @ 7808a91).
- **Reads** every doc in `classes/{c}/studentPoints` (functions/src/behaviorPoints.ts:332-335 @ 7808a91).
- **Returns** `{success, summaries}`, keyed by doc id.

**`getBehaviorHistory`** (functions/src/behaviorPoints.ts:352 @ 7808a91)
- **Authorization (load-bearing):**
  - Throws `unauthenticated` (functions/src/behaviorPoints.ts:361 @ 7808a91).
  - Throws `permission-denied` if there is no users doc (functions/src/behaviorPoints.ts:394 @ 7808a91).
  - For a teacher: throws `not-found` if the class doc is missing (functions/src/behaviorPoints.ts:404 @ 7808a91) or has no data (functions/src/behaviorPoints.ts:409 @ 7808a91), and `permission-denied` if the caller does not own the class (functions/src/behaviorPoints.ts:414-417 @ 7808a91).
  - For a student: it sets `studentId = uid` instead of checking class membership (functions/src/behaviorPoints.ts:418-420 @ 7808a91).
  - For any other role: throws `permission-denied` (functions/src/behaviorPoints.ts:422 @ 7808a91).
- **Input check:** throws `invalid-argument` if `classId` is missing (functions/src/behaviorPoints.ts:381 @ 7808a91).
- **Query:**
  - It runs a collection-group query on `history` with `classId ==` and `isUndone == false`, plus optional `studentId`, `gender`, `type` and a `timestamp` range (functions/src/behaviorPoints.ts:426-458 @ 7808a91).
  - It orders by `awardedAt desc`, then applies `offset` and `limit`, with a default limit of 50 (functions/src/behaviorPoints.ts:461-469 @ 7808a91).
  - It converts Timestamps to ISO strings (functions/src/behaviorPoints.ts:474-490 @ 7808a91).
- **Count query:** `count()` on the same filters but without the date range (functions/src/behaviorPoints.ts:493-509 @ 7808a91).
- **Errors:** it rethrows `HttpsError` as is and wraps everything else as `internal` (functions/src/behaviorPoints.ts:521-529 @ 7808a91).
- **Returns** `{success, history, totalCount, hasMore}`.

## security.ts
Every export is a helper, not a trigger, and `index.ts` does not export this module. **Load-bearing.** Its only importer in `functions/src` is `oauth.ts` (functions/src/oauth.ts:5-11 @ 7808a91), which index.ts re-exports.

- **`createRateLimiter(name, maxCalls, periodSeconds)`** returns a `FirestoreRateLimiter` backed by `admin.firestore()` (functions/src/security.ts:8-23 @ 7808a91).
- **`oauthRateLimiters`** defines three limiters (functions/src/security.ts:26-35 @ 7808a91). It runs at module load.
  - `getUrl`: `oauth_get_url`, 10 calls per 60 s. Used at functions/src/oauth.ts:94 @ 7808a91.
  - `exchangeCode`: `oauth_exchange`, 5 calls per 60 s. Used at functions/src/oauth.ts:194 @ 7808a91.
  - `refreshToken`: `oauth_refresh`, 20 calls per 60 s. Used at functions/src/oauth.ts:374 @ 7808a91.
- **`applyRateLimit(limiter, id)`** calls `rejectOnQuotaExceededOrRecordUsage`. Any error it throws becomes `HttpsError("resource-exhausted")` (functions/src/security.ts:38-51 @ 7808a91).
- **`oauthValidator`** returns booleans and touches no Firestore or Admin APIs (functions/src/security.ts:69-164 @ 7808a91). Its methods:
  - `validateRequest` rejects a missing or non-string user agent, and user agents matching bot, crawler, spider, scraper, curl, wget or python-requests (functions/src/security.ts:70-100 @ 7808a91).
  - `validateRedirectUri` rejects hosts other than `localhost` and `127.0.0.1`, protocols other than http and https, and ports other than 80, 443 or 1024-65535 (functions/src/security.ts:102-132 @ 7808a91).
  - `validateState` rejects values outside 40-50 characters or not matching `^[A-Za-z0-9_-]+$` (functions/src/security.ts:134-148 @ 7808a91).
  - `validateCodeVerifier` applies the same length and pattern rule (functions/src/security.ts:150-163 @ 7808a91).
- **`securityHeaders` / `applySecurityHeaders(res)`** set six response headers with `res.set` (functions/src/security.ts:167-181 @ 7808a91).
- **`getClientIdentifier(req)`** returns the first of: the first `x-forwarded-for` entry, `x-real-ip`, `connection.remoteAddress`, `req.ip`, or the literal `"unknown"` (functions/src/security.ts:184-198 @ 7808a91).

## rate-limiter.ts
Helpers only, and `index.ts` does not export this module. **Load-bearing.**

**`class FirestoreRateLimiter`** (functions/src/rate-limiter.ts:15 @ 7808a91)
- Stores records in the `_rate_limits` collection (functions/src/rate-limiter.ts:18 @ 7808a91).
- `withFirestoreBackend` is a static factory (functions/src/rate-limiter.ts:25-30 @ 7808a91).

**`rejectOnQuotaExceededOrRecordUsage(id)`** (functions/src/rate-limiter.ts:32-88 @ 7808a91)
- It runs a transaction on `_rate_limits/{name}_{id}`.
- If the doc is missing, or `firstCall` is older than `periodSeconds`, it sets `{count: 1, firstCall: now, lastCall: now}`.
- If `count >= maxCalls` it throws `Error("Rate limit exceeded")`.
- Otherwise it updates `{count+1, firstCall, lastCall: now}`.
- Any other error is logged and swallowed, so the request is allowed through (functions/src/rate-limiter.ts:81-87 @ 7808a91).

**`cleanupOldRateLimitRecords(firestore, hoursToKeep = 24)`** (functions/src/rate-limiter.ts:92-115 @ 7808a91)
- It batch-deletes up to 500 `_rate_limits` docs where `lastCall` is older than the cutoff.
- No file in `functions/src` calls it. A `git grep` for `cleanupOldRateLimitRecords|_rate_limits` at 7808a91 matches only rate-limiter.ts. The cleanup module, `cleanup.ts`, exports only `cleanupExpiredPKCEChallenges` (`onSchedule`, functions/src/cleanup.ts:9 @ 7808a91) and `manualPKCECleanup` (functions/src/cleanup.ts:129 @ 7808a91).

## migrate-usernames.ts
Nothing in this file is exported from `index.ts`, and a `git grep` for `migrate-usernames|migrateUsernames` at 7808a91 finds no importer. **Load-bearing:** neither trigger is in the deployed entry point.

**`migrateUsernamesToPublic`** (v2 `https.onCall`, `{region: "us-east4"}`; functions/src/migrate-usernames.ts:12 @ 7808a91)
- **Authorization (load-bearing):**
  - Throws `unauthenticated` (functions/src/migrate-usernames.ts:16 @ 7808a91).
  - Throws `permission-denied` unless `users/{uid}.role` is `teacher` or `admin` (functions/src/migrate-usernames.ts:24-36 @ 7808a91).
- **Reads:**
  - `users` where `username != null` (functions/src/migrate-usernames.ts:44-47 @ 7808a91).
  - `public_usernames/{lowercased username}` for each user, which it skips if present (functions/src/migrate-usernames.ts:76-85 @ 7808a91).
- **Writes:** `public_usernames/{lower}` gets `{uid, role (default "student"), migratedAt}`, committed in batches of 500 (functions/src/migrate-usernames.ts:88-109, 118-122 @ 7808a91).
- **Errors:** a failure on one user is collected and the loop continues (functions/src/migrate-usernames.ts:110-114 @ 7808a91). A failure of the whole run throws `internal` (functions/src/migrate-usernames.ts:138 @ 7808a91).
- **Returns** `{success, message, successCount, skipCount, errorCount, totalUsers, errors?}`.

**`migrateUsernamesHttp`** (v2 `https.onRequest`, `{region: "us-east4"}`; functions/src/migrate-usernames.ts:146 @ 7808a91)
- **Authorization (load-bearing):**
  - Returns 401 if there is no `Bearer` header (functions/src/migrate-usernames.ts:151-154 @ 7808a91).
  - Verifies the token with `admin.auth().verifyIdToken` (functions/src/migrate-usernames.ts:159 @ 7808a91).
  - Returns 403 unless the `users/{uid}` role is `teacher` or `admin` (functions/src/migrate-usernames.ts:162-172 @ 7808a91).
- It then calls the internal `runMigration` (functions/src/migrate-usernames.ts:190-251 @ 7808a91). That function does the same `users` query, the same `public_usernames` existence check and the same `{uid, role, migratedAt}` write in 500-doc batches, without per-user error collection.
- **Returns** JSON `{success, successCount, skipCount, totalUsers}`, or 500 with `{success: false, error}`. A failed token verification also lands in this 500 path (functions/src/migrate-usernames.ts:177-183 @ 7808a91).

## Searched and not found @ 7808a91
- No `onSchedule`, Firestore-event or auth-event trigger in any of the five files. That was checked by reading each file in full.
- `index.ts` has no export line for `security`, `rate-limiter` or `migrate-usernames`, and the code has no other route to them except `security` via `oauth.ts`. That was checked with `git grep` over `functions` for those module names and their symbols.
- `firebase.json` is not tracked at 7808a91, so I could not check the deploy config beyond `package.json` `main`.

I read 8 of the 15-file budget: index.ts, the five target files, `oauth.ts` (only the security imports and its HttpsError-to-status handling at functions/src/oauth.ts:89-160 @ 7808a91) and `cleanup.ts` (only its export lines).