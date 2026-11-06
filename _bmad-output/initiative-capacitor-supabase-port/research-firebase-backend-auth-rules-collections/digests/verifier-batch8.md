All 13 claims are verified, and every cited line range sits inside the symbol it names. Each citation can stay as written; for refs 71, 72 and 77 I've noted extra lines worth adding.

**Digest (commit 7808a91)**

- **ref=[66]** `functions/src/behaviorPoints.ts:445-461 (getBehaviorHistory) @ 7808a91`. **verified.** The function runs from 352. Lines 448 and 456 filter `timestamp` with `>=` and `<=`, and 461 does `orderBy("awardedAt", "desc")`.

- **ref=[67]** `functions/src/adminFunctions.ts:160 (createStudentAccount) @ 7808a91`. **verified.** The function runs 47-193. Line 160 is `db.collection("activities").add({type: "user_created", ...})`.

- **ref=[68]** `functions/src/adminFunctions.ts:186-190 (createStudentAccount) @ 7808a91`. **verified.** `auth/email-already-exists` becomes `already-exists` (186-188), and everything else becomes `internal` (190).

- **ref=[69]** `functions/src/bulkImport.ts:129-152 (bulkImportStudents) @ 7808a91`. **verified.** The function runs 31-432. `Promise.allSettled` over `auth.getUserByEmail` puts fulfilled results into `alreadyExistingUsers`. If `newUsers` is empty it returns `success: false` with "All users already exist".

- **ref=[70]** `functions/src/bulkImport.ts:167-202 (bulkImportStudents) @ 7808a91`. **verified.**
  - Lines 167-168 check that `classes/{classId}` exists.
  - The other branch queries `enrollmentCode == user.enrollmentCode.toUpperCase()` and `isActive == true` with a limit of 1 (180-184).
  - Invalid classes go into `classErrors`, which is only passed to `logger.warn` (200-202). Lookup exceptions are only passed to `logger.error` (195).

- **ref=[71]** `functions/src/bulkImport.ts:206-248 (bulkImportStudents) @ 7808a91`. **verified.** `importUsers(importUserRecords, {hash: {algorithm: "BCRYPT"}})` is at 244-248. Each record sets `emailVerified: true` (215) and `customClaims {role: "student", gradeLevel}` (228-231). The 28-character uid and `Math.random` come from helpers outside the cited range: `generateUid` returns `randomString(28)` (541-543), and `randomString` uses `Math.random` (528-535). Consider adding 528-543 to the citation.

- **ref=[72]** `functions/src/bulkImport.ts:221-225 (bulkImportStudents) @ 7808a91`. **verified.** When `!user.isGoogleAuth`, the record gets `passwordHash = generateTempPasswordHash()` and `passwordSalt = generateSalt()`. The hash is `"$2b$10$" + randomString(53)` (512-516), random characters rather than the hash of any password. The salt is `randomString(16)` (521-523). Consider adding 512-523.

- **ref=[73]** `functions/src/bulkImport.ts:256-329 (bulkImportStudents) @ 7808a91`. **verified.**
  - One `db.batch()` (256) loops over every `newUsers[i]` (262), calls `batch.set` on `users/{uid}` (319), and has a single `commit` (329).
  - There is no chunking, although the input cap is 1000 users (75).
  - The only check is `importResult.successCount > 0` (251). The per-user `importResult.errors` are not used until 383-392, after the users have already been written.

- **ref=[74]** `functions/src/bulkImport.ts:347-357 (bulkImportStudents) @ 7808a91`. **verified.** Each `classes/{classId}` is updated with `studentIds: arrayUnion(...studentIds)` and `updatedAt` (349-352), followed by `Promise.all` (357).

- **ref=[75]** `functions/src/bulkImport.ts:361-379 (bulkImportStudents) @ 7808a91`. **verified.** Only when `sendPasswordResetEmails` is set (it defaults to true, line 53), results that succeeded and are not Google auth get `auth.generatePasswordResetLink`. The link only goes to `logger.info` (372).

- **ref=[76]** `functions/src/bulkImport.ts:395-406 (bulkImportStudents) @ 7808a91`. **verified.** `activities.add({type: "bulk_import", action: "students_imported", ...})`.

- **ref=[77]** `functions/src/oauth.ts:297-311 (exchangeOAuthCode) @ 7808a91`. **verified.** The function runs 170-345.
  - It looks the user up with `getUserByEmail`, or creates one with `createUser` and no claims (297-308).
  - The `createCustomToken` call (311-314) carries only `{provider: "google.com", email}`, with no role.
  - A search of `oauth.ts` finds no domain check (`endsWith` or `rosellestudent`), no `setCustomUserClaims` and no `collection("users")` write.
  - Consider widening the range to 297-314.

- **ref=[78]** `functions/src/chatFunctions.ts:132-137 (sendMessage) @ 7808a91`. **verified.** `sendMessage` runs 43-140. Its catch rethrows everything as `internal`. That includes the `not-found` and `permission-denied` errors from `ensureConversationMembership` (16-34), which is called at 69 inside the `try`. The other three callables do the same:
  - `markMessagesAsRead`: catch at 195-200
  - `updateTypingStatus`: catch at 269-274
  - `uploadChatFile`: catch at 373-378