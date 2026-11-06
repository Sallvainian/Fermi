**Q9 digest: exported functions in adminFunctions, bulkImport, oauth and cleanup @ 7808a91**

I read eight files: the four named, plus `index.ts`, `security.ts`, `types/oauth.types.ts` and `rate-limiter.ts`. That is within the 15-file budget, and every file I cite was read in full.

**Shared context**
- `functions/src/index.ts:14 @ 7808a91` calls `admin.initializeApp()`.
- `functions/src/index.ts:29-32 @ 7808a91` calls `setGlobalOptions`, with maxInstances 10 and region us-east4.
- `functions/src/index.ts:38,41,47,50 @ 7808a91` re-export all four modules with `export *`.
- The callables in `adminFunctions.ts` and `bulkImport.ts` share one admin gate. **Load-bearing:** it checks the Firestore document `users/{request.auth.uid}.role === "admin"`. It does not check token custom claims. The two rejections are:
  - no `request.auth` → `unauthenticated`
  - role is not admin → `permission-denied`
- None of the four files calls Storage or Messaging. All the Admin SDK calls are Auth or Firestore.

---

### adminFunctions.ts

`generateSecurePassword` (`functions/src/adminFunctions.ts:14-41 @ 7808a91`) is not exported. It builds a password from `crypto.randomBytes` using rejection sampling over a 70-character set. If the result lacks an upper, lower, digit or special character, it calls itself again. Its only caller is `resetUserPassword` at `:495`.

**createStudentAccount** (`functions/src/adminFunctions.ts:47-193 (createStudentAccount) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, with `{region: "us-east4", maxInstances: 10}` at `:47-48`.
- **Authorization (load-bearing):** the shared admin gate at `:51-61`.
- **Input:** `{email, password, displayName, gradeLevel, parentEmail, classIds, isGoogleAuth}` at `:64`.
- **Rejections (all `invalid-argument`):**
  - email missing (`:66`)
  - no "@" in email (`:70`)
  - domain is not `@rosellestudent.org` or `@rosellestudent.com` (`:75-81`)
  - when not `isGoogleAuth`: password missing (`:85`) or shorter than 6 characters (`:88`)
- **Auth calls:**
  - If `isGoogleAuth`: `auth.getUserByEmail`, with errors swallowed to null (`:102`). If a user exists, it is reused. Otherwise `auth.createUser({email, displayName, emailVerified: true})` runs with no password (`:110`).
  - Otherwise: `auth.createUser({email, password, displayName, emailVerified: true})` at `:118`.
  - Then `auth.setCustomUserClaims(uid, {role: "student"})` at `:127`.
- **Firestore writes:**
  - `users/{uid}.set` (no merge) at `:132-142`, with fields email, displayName, role "student", gradeLevel, parentEmail, createdAt (server timestamp), createdBy, isEmailUser, isGoogleAuth.
  - For each id in `classIds`, a batch update of `classes/{classId}` at `:145-157`: `studentIds` arrayUnion(uid) and `updatedAt`.
  - `activities.add` at `:160-172`, with type "user_created", userName, userRole "student", createdBy, timestamp, and details {userId, email, gradeLevel, isGoogleAuth}.
- **Returns:** `{success, userId, email, displayName, isGoogleAuth}` at `:176-182`.
- **Error mapping:** `auth/email-already-exists` becomes `already-exists` (`:186`). Anything else becomes `internal` (`:190`).

**createTeacherAccount** (`functions/src/adminFunctions.ts:199-293 (createTeacherAccount) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, us-east4, maxInstances 10.
- **Authorization (load-bearing):** the admin gate at `:203-213`.
- **Input:** `{email, password, displayName}`.
- **Rejections (all `invalid-argument`):**
  - any of the three fields missing (`:218`)
  - no "@" in email (`:222`)
  - domain is not `@roselleschools.org` (`:227`)
  - password shorter than 6 characters (`:234`)
- **Auth calls:** `auth.createUser` with emailVerified true (`:240`), then `setCustomUserClaims({role: "teacher"})` (`:248`).
- **Firestore writes:**
  - `users/{uid}.set` at `:253-260`: email, displayName, role "teacher", createdAt, createdBy, isEmailUser true.
  - `activities.add` with type "user_created" (`:263-273`).
- **Returns:** `{success, userId, email, displayName}`.
- **Error mapping:** the same `already-exists` / `internal` mapping as above (`:286-290`).

**createAdminAccount** (`functions/src/adminFunctions.ts:299-395 (createAdminAccount) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, us-east4, maxInstances 10.
- **Authorization (load-bearing):** the admin gate at `:303-313`.
- **Input:** `{email, password, displayName}`.
- **Rejections (all `invalid-argument`):**
  - any field missing (`:318`)
  - no "@" in email (`:323`)
  - domain is not `@fermi-plus.com` (`:328`)
  - password shorter than 8 characters (`:335`)
- **Auth calls:** `createUser` (`:342`), then `setCustomUserClaims({role: "admin"})` (`:350`).
- **Firestore writes:** `users/{uid}.set` with role "admin" (`:355-362`), and `activities.add` with type "user_created" (`:365-375`).
- **Returns:** `{success, userId, email, displayName}`.
- **Error mapping:** `already-exists` / `internal`.

**deleteUserAccount** (`functions/src/adminFunctions.ts:401-464 (deleteUserAccount) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, us-east4, maxInstances 10.
- **Authorization (load-bearing):** the admin gate at `:405-415`.
- **Input:** `{userId}`.
- **Rejections (both `invalid-argument`):** userId missing (`:420`), or userId equals the caller's own uid (`:425`).
- **Firestore read:** `users/{userId}`, used for the log (`:431`).
- **Auth call:** `auth.deleteUser(userId)` at `:435`.
- **Firestore writes:**
  - `users/{userId}.delete()` at `:438`.
  - `activities.add` at `:441-451`, with type "user_deleted", userName, userRole, deletedBy, timestamp, and details {userId, email}.
- It does not touch `classes`.
- **Returns:** `{success, message}`. Any error becomes `internal`.

**resetUserPassword** (`functions/src/adminFunctions.ts:470-529 (resetUserPassword) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, us-east4, maxInstances 10.
- **Authorization (load-bearing):** the admin gate at `:474-484`.
- **Input:** `{userId}`. A missing userId is rejected with `invalid-argument` (`:489`).
- **Auth call:** `auth.updateUser(userId, {password: generateSecurePassword(12)})` at `:495-500`.
- **Firestore:** reads `users/{userId}` (`:503`), then `activities.add` with type "password_reset", userName, resetBy, timestamp, and details {userId} (`:507-515`).
- **Returns:** `{success, newPassword, message}` (`:519-523`). The new plaintext password goes back to the caller.
- Any error becomes `internal`.

**getSystemStats** (`functions/src/adminFunctions.ts:535-582 (getSystemStats) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, us-east4, maxInstances 10.
- **Authorization (load-bearing):** the admin gate at `:539-549`.
- **Input:** none.
- **Firestore reads:**
  - The whole `users` collection (`:553`), counted by role and by `isOnline === true`.
  - `activities` where `timestamp > now - 1 day` (`:569-572`).
- **Returns:** `{totalUsers, studentCount, teacherCount, adminCount, activeUsers, recentActivityCount}`.
- Any error becomes `internal`.

---

### bulkImport.ts

**bulkImportStudents** (`functions/src/bulkImport.ts:31-432 (bulkImportStudents) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, with `{region: "us-east4", maxInstances: 10, memory: "512MiB", timeoutSeconds: 300}` at `:32-37`.
- **Authorization (load-bearing):** the admin gate at `:40-50`.
- **Input:** `{users, csvData, sendPasswordResetEmails = true}` at `:53`.
  - `csvData` is parsed by `parseCSV` (`:437-506`). It needs `name` and `email` headers. Optional headers are classids/class_ids (semicolon-separated), enrollmentcode, grade/gradelevel, parentemail, authtype ("google" means Google auth) and studentid.
- **Rejections that throw `invalid-argument`:**
  - CSV parse error (`:62`), including fewer than 2 lines (`:440`), missing headers (`:450`), or a row without name or email (`:476`)
  - neither `users` array nor `csvData` given (`:67`)
  - zero users (`:72`)
  - more than 1000 users (`:76`)
  - any per-row email error (`:121-126`). These are collected (`:88-111`): missing, no "@", not a rosellestudent.org/.com domain, or a duplicate within the import. If any exist, the whole request is rejected.
- **Checks that drop users without throwing:**
  - `auth.getUserByEmail` for each user via `Promise.allSettled` (`:129-131`). Users who already exist are split out. If none are new, it returns `{success: false, message: "All users already exist", ...}` (`:144-152`).
  - Class validation reads `classes/{classId}.exists` (`:167`), or queries `classes` where `enrollmentCode == code.toUpperCase()` and `isActive == true`, limit 1 (`:180-184`). Invalid classes are only logged with `logger.warn` (`:200-202`).
- **Auth calls:**
  - `auth.importUsers(records, {hash: {algorithm: "BCRYPT"}})` at `:244-248`.
  - Each record is built at `:206-234`: a uid from `generateUid()`, which is 28 characters of `Math.random` output (`:528-543`); email; displayName; emailVerified true; disabled false; customClaims `{role: "student", gradeLevel}`.
  - Non-Google users also get `passwordHash = "$2b$10$" + 53 random chars` and `passwordSalt = 16 random chars` (`:221-225`, `:512-523`). That is a placeholder hash, not the hash of any known password.
  - If `sendPasswordResetEmails` is set, `auth.generatePasswordResetLink(email)` runs for each successful non-Google user (`:361-379`). The link is only written to `logger.info` (`:372`). Nothing sends it.
- **Firestore writes:**
  - One unchunked `db.batch()` of `users/{uid}.set` at `:256-329`, with fields email, displayName, role "student", gradeLevel (as a String or null), parentEmail, createdAt, createdBy, isEmailUser, isGoogleAuth, profileComplete false. Optional fields are studentId, `classId` (the first class) and `enrolledClasses`.
  - That loop runs over all `newUsers` (`:262`), not just the ones `importUsers` reported as succeeding.
  - `classes/{classId}.update` for each class (`:347-357`): `studentIds` arrayUnion(...) and `updatedAt`.
  - `activities.add` at `:395-406`, with type "bulk_import", action "students_imported", performedBy, timestamp, and details {totalAttempted, successCount, failureCount, alreadyExisting}.
- **Returns:** `{success: true, message, summary {attempted, imported, failed, alreadyExisting}, imported[], failed[], alreadyExisting[]}` (`:418-430`). Import failures come from `importResult.errors[].index` (`:383-392`).
- Any error inside the import block becomes `internal` (`:414`).

**migrateStudentClassEnrollment** (`functions/src/bulkImport.ts:549-673 (migrateStudentClassEnrollment) @ 7808a91`)
- **Trigger (load-bearing):** `onCall`, with `{region: "us-east4", maxInstances: 10, memory: "256MiB", timeoutSeconds: 60}`.
- **Authorization (load-bearing):** the admin gate at `:558-568`.
- **Input:** none.
- **Firestore reads:** `users` where `role == "student"` (`:574-576`), and the whole `classes` collection, used to build a name-to-id map in lowercase (`:588-598`).
- **Firestore writes:**
  - For each student with no `classId` but a `className` that matches a class: a batch update of `users/{id}` (`:619-624`). It sets `classId` and `enrolledClasses: [classId]`, and deletes `className` with `FieldValue.delete()`.
  - `classes/{id}.update` with `studentIds` arrayUnion and `updatedAt` (`:647-657`).
  - Students whose name doesn't match a class are counted as failed (`:635-636`).
- **Returns:** `{success, message, results {total, migrated, failed, errors}}`.
- Any error becomes `internal`.

---

### oauth.ts

The module defines two secrets with `defineSecret`: `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` (`functions/src/oauth.ts:21-22 @ 7808a91`). The PKCE collection is `oauth_pkce_challenges` (`:63-64 getPKCECollection`).

The three HTTP functions share a pattern:
- **Trigger (load-bearing):** `onRequest` with `{cors: true, secrets: [...]}`. There is no region option in the file, so us-east4 comes from the global options.
- **Authorization (load-bearing):** there is none. No Firebase ID token or App Check is checked. The only gating is:
  - **Rate limit.** `applyRateLimit` (`functions/src/security.ts:38-51 @ 7808a91`) throws `resource-exhausted` when over quota. The limiter uses a transaction on `_rate_limits/{name}_{ip}`, with fields count, firstCall and lastCall (`functions/src/rate-limiter.ts:32-80 @ 7808a91`). Limiter errors other than an exceeded quota are logged and the request goes through (`rate-limiter.ts:85-86`).
  - **The client key is the IP address**, taken from x-forwarded-for, x-real-ip, remoteAddress or `req.ip` (`security.ts:184-198`).
  - **User-agent check.** `oauthValidator.validateRequest` (`security.ts:70-100`) rejects a missing user-agent, or one matching bot, crawler, spider, scraper, curl, wget or python-requests. That rejection is `invalid-argument "Invalid request format"`.
- The missing-secret check throws `failed-precondition`, and it runs before the security headers are set.
- `applySecurityHeaders` (`security.ts:177-181`) sets nosniff, DENY framing, no-referrer and no-store.
- On error, an `HttpsError` is sent as `res.status(httpErrorCode.status).json({error})`. Other errors return 500.

**getOAuthUrl** (`functions/src/oauth.ts:70-164 (getOAuthUrl) @ 7808a91`)
- **Rate limit:** `oauth_get_url`, 10 per 60 seconds (`security.ts:28`).
- **Input:** `req.query.redirect_uri`, defaulting to `http://localhost`.
- **Rejection:** `validateRedirectUri` fails → `invalid-argument` (`:105`). It requires host localhost or 127.0.0.1, protocol http or https, and port 80, 443 or 1024-65535 (`security.ts:102-132`).
- **Firestore write:** `oauth_pkce_challenges/{state}.set({codeVerifier, expiresAt: now + 600000, createdAt: serverTimestamp, clientId: <ip>})` at `:123-129`. The shape is the `PKCEChallenge` type (`functions/src/types/oauth.types.ts:30-35 @ 7808a91`).
- **Returns:** JSON `{authUrl, state, codeVerifier}` (`:146-150`). The Google auth URL carries scope "email profile openid", S256, access_type offline and prompt consent.

**exchangeOAuthCode** (`functions/src/oauth.ts:170-345 (exchangeOAuthCode) @ 7808a91`)
- **Rate limit:** `oauth_exchange`, 5 per 60 seconds (`security.ts:31`).
- **Input:** body `{code, state, codeVerifier, redirectUri?}`.
- **Rejections:**
  - any of the three required fields missing → `invalid-argument` (`:203`)
  - state not 40-50 base64url characters → `invalid-argument` (`:208`, `security.ts:134-148`)
  - verifier not 40-50 base64url characters → `invalid-argument` (`:212`)
  - bad `redirectUri` → `invalid-argument` (`:217`)
  - no PKCE document for `state` → `invalid-argument` (`:223`)
  - `expiresAt < now` → the document is deleted, then `deadline-exceeded` (`:228-231`)
  - stored verifier differs from the one sent → `invalid-argument` (`:233-237`)
- **Firestore:** reads, then deletes, `oauth_pkce_challenges/{state}` (`:222`, `:240`). The delete happens before the Google calls.
- **External calls:**
  - POST to the Google token URL with the client secret (`:243-260`). A non-OK response returns 400 `{error, details}`.
  - GET userinfo (`:274-293`). A non-OK response returns 400.
  - `fetchWithTimeout` (`:38-60`) turns an abort into `deadline-exceeded` and other failures into `internal`.
- **Auth calls:**
  - `admin.auth().getUserByEmail(userInfo.email)`. Any error falls through to `createUser({email, displayName, photoURL, emailVerified: verified_email})` (`:297-308`).
  - `admin.auth().createCustomToken(uid, {provider: "google.com", email})` (`:311`).
- There is no email-domain check and no role or claim assignment. It writes nothing to `users`.
- **Returns:** `{firebaseToken, googleTokens {accessToken, refreshToken, expiresIn, idToken}, user {uid, email, displayName, photoURL}}` (`:317-331`).

**refreshOAuthToken** (`functions/src/oauth.ts:350-434 (refreshOAuthToken) @ 7808a91`)
- **Rate limit:** `oauth_refresh`, 20 per 60 seconds (`security.ts:34`).
- **Input:** body `{refreshToken}`. If missing → `invalid-argument` (`:383`).
- **External call:** POST to the Google token URL with grant_type refresh_token and the client secret (`:388-403`). A non-OK response returns 400.
- It makes no Firestore or Auth calls apart from the rate-limiter document.
- **Returns:** `{accessToken, expiresIn, idToken}` (`:416-420`).

---

### cleanup.ts

**cleanupExpiredPKCEChallenges** (`functions/src/cleanup.ts:9-116 (cleanupExpiredPKCEChallenges) @ 7808a91`)
- **Trigger (load-bearing):** `onSchedule`, with `{schedule: "every 1 hours", timeZone: "America/New_York", retryCount: 3, memory: "256MiB"}` (`:10-15`).
- **Authorization (load-bearing):** none. It is a scheduler trigger with no caller.
- **Firestore:**
  - Queries `oauth_pkce_challenges` where `expiresAt < Date.now()` and deletes the results in batches of 500 (`:28-64`). If none are found, it returns early (`:32-35`). Because of that early return, the 30-day sweep below only runs when at least one expired document was found.
  - Queries `createdAt < Timestamp(now - 30 days)` and batch-deletes the results (`:72-102`).
  - Counts the remaining documents with `collection.count()` (`:108`).
- Errors are re-thrown so the scheduler retries (`:113`).

**manualPKCECleanup** (`functions/src/cleanup.ts:129-171 (manualPKCECleanup) @ 7808a91`)
- **Trigger (load-bearing):** none. It is a plain exported `async` function with no `onCall`, `onRequest` or `onSchedule` wrapper. It is still re-exported through `index.ts:41`.
- **Authorization (load-bearing):** none.
- **Input:** none.
- **Firestore:** the same two queries on `oauth_pkce_challenges`, deleted one at a time with `doc.ref.delete()`, followed by a `count()`.
- **Returns:** `{expired, old, remaining}`.

---

### Searched for and not found @ 7808a91
- **Callers of `manualPKCECleanup`:** `git grep -n manualPKCECleanup` over the repo, excluding the brief's paths, finds only its definition at `cleanup.ts:129`.
- **Storage, Messaging and custom-claims checks:** I found no `admin.storage()` or `admin.messaging()` calls in any of the four files. None of the gates reads `request.auth.token.role`; all of them read the Firestore role. This comes from reading the four files in full, not from a grep.
- **What I did not open:** the other modules re-exported by `index.ts` (customClaims, migrate-user-roles-cloud, chatFunctions, authBlocking, behaviorPoints). They were outside Q9.