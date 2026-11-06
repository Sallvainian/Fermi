All eight claims check out against the code at 7808a91 (read with `git show` and `git grep`, excluded paths left out). Three citations name the wrong symbol and are corrected below; the line ranges are unchanged.

**ref=[37]** `functions/src/oauth.ts:70-164 getOAuthUrl @ 7808a91` — **verified**. It is `onRequest` with `cors: true` (lines 70-74). It never checks an authorization header or calls `verifyIdToken`. The only gates are a per-client rate limit (`applyRateLimit`), a user-agent and bot-pattern check (`oauthValidator.validateRequest`, `functions/src/security.ts:70` onward) and a localhost-only `redirect_uri`. It writes `oauth_pkce_challenges/{state}` (line 129) and returns `{authUrl, state, codeVerifier}` (lines 146-150).

**ref=[38]** `functions/src/cleanup.ts:28-102 cleanupExpiredPKCEChallenges @ 7808a91` — **verified**. When the `expiresAt < now` query comes back empty it logs and returns at lines 32-35. The 30-day `createdAt` sweep (lines 70-105) comes after that, so it only runs when at least one expired document was found.

**ref=[39]** `functions/src/bulkImport.ts:361-379 bulkImportStudents @ 7808a91` — **verified**. Symbol corrected: `updatePromise` is a class-update variable at line 349; the code at 361-379 is inside `bulkImportStudents` (line 31). When `sendPasswordResetEmails` is set it calls `auth.generatePasswordResetLink` and only logs the link with `logger.info` (line 372). A comment there says the email would be sent "in production".

**ref=[40]** `functions/src/index.ts:35-59 export @ 7808a91` — **verified**. Lines 53 and 59 re-export `./chatFunctions` and `./behaviorPoints`. No line exports `./security`, `./rate-limiter` or `./migrate-usernames`. `security` is still imported by `oauth.ts`, but it has no export line in `index.ts`.

**ref=[41]** `functions/src/chatFunctions.ts:132-137 sendMessage @ 7808a91` — **verified**. Symbol corrected: `otherParticipants` is a local variable at line 116; the catch belongs to `sendMessage` (line 43). The catch logs and always throws `HttpsError("internal", "Failed to send message")`. That includes the `not-found` and `permission-denied` errors thrown earlier in the same try block (lines 17, 30, 77).

**ref=[42]** `functions/src/rate-limiter.ts:15-88 FirestoreRateLimiter @ 7808a91` — **verified**. At lines 81-87 only the error with message "Rate limit exceeded" is rethrown. Any other error goes to `console.error` and the method returns normally, so the request is allowed through.

**ref=[43]** `functions/src/behaviorPoints.ts:31-77 awardBehaviorPoints @ 7808a91` — **verified**. It requires `users/{uid}.role === "teacher"` (line 58). It also requires `classData.teacherId || classData.teacherUID` to equal the caller's uid (lines 74-75), and throws `permission-denied` otherwise.

**ref=[44]** `lib/features/notifications/data/services/notification_service.dart:323-383 _initializeLocalNotifications @ 7808a91` — **verified**. The plugin is initialized at line 360 and an Android channel is created at lines 377-381. A search of every `*.dart` file at the commit finds no `.show(` and no `zonedSchedule`.