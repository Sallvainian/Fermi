Digest for Question 2: how role claims are assigned and changed on the server (@ 7808a91)

**Answer in brief.** A role claim gets set in seven places:
- `autoAssignRole`, a blocking function that runs before any user is created.
- `syncUserRole`, a Firestore trigger on `users/{userId}`.
- `setRoleClaim`, a callable.
- Two migration paths: the callable `migrateAllUserRoles` and a standalone node script.
- Three admin account-creation callables, plus a bulk import.

Domain decides the role only at signup. After that, the claim follows the Firestore `users.role` field through `syncUserRole`, but only for `teacher` and `student`. `admin` is skipped everywhere except signup and `createAdminAccount`. The claim and `users.role` can diverge in several ways, listed in the last section.

**Domain-to-role mapping (load-bearing)**
- `functions/src/config/domainRoles.ts:7-23 DOMAIN_ROLE_MAPPINGS @ 7808a91`:
  - `@roselleschools.org` → teacher
  - `@rosellestudent.org` → student
  - `@fermi-plus.com` → admin
- `ADMIN_EMAILS` is an empty array: `functions/src/config/domainRoles.ts:26 ADMIN_EMAILS @ 7808a91`.
- `getRoleFromEmail` lowercases the email, checks `ADMIN_EMAILS`, then returns the first mapping whose domain the email ends with, otherwise `null`: `functions/src/config/domainRoles.ts:33-49 getRoleFromEmail @ 7808a91`.
- `isValidSchoolEmail` applies the same `endsWith` test: `functions/src/config/domainRoles.ts:56-66 isValidSchoolEmail @ 7808a91`.

**1. `autoAssignRole`: blocking function before user creation (load-bearing)**
- **Trigger:** `beforeUserCreated` in region `us-east4`: `functions/src/authBlocking.ts:13-14 autoAssignRole @ 7808a91`. It is re-exported at `functions/src/index.ts:56 @ 7808a91`.
- **Rejections:**
  - `invalid-argument` "Invalid user data" when there is no `event.data`: `functions/src/authBlocking.ts:18-24`.
  - `invalid-argument` "Email is required" when there is no email: `:28-34`.
  - `permission-denied` when the domain is not a school domain. The message changes when the provider is `google.com`: `:37-50`.
  - `permission-denied` "Unable to determine user role" when `getRoleFromEmail` returns null: `:55-61`. This cannot happen in practice, because it uses the same mapping the check at `:37` already passed.
  - `internal` "Failed to create user profile" when either Firestore write throws: `:98-104`.
- **Firestore writes:**
  - `users/{uid}.set({email, displayName, role, createdAt, emailVerified:false, isEmailUser:true, profileComplete:false})`: `:73-81`.
  - `activities.add({type:"user_created", userName, userRole, createdBy:"system", timestamp, details:{userId, email, autoAssigned:true}})`: `:84-95`.
- **Returned claims:** `{customClaims:{role, emailDomain}, displayName, emailVerified: role === "admin"}`: `:66-69, :106-110`. It handles all three roles.

**2. `syncUserRole`: Firestore trigger (load-bearing)**
- **Trigger:** `onDocumentWritten` on `users/{userId}` in `us-east4`: `functions/src/customClaims.ts:80-81 syncUserRole @ 7808a91`.
- It does nothing when `before.role === after.role`: `:90-92`.
- When the document is deleted, it calls `setCustomUserClaims(userId, null)`, which clears every claim: `:95-103`.
- **Role filter:** it sets `{role}` only when the role is `teacher` or `student`: `:106-114`. A change to `admin`, to any other value, or to a missing field writes nothing, so the old claim stays.
- It writes the claims object as exactly `{role}`, replacing any other claim keys.
- It never rejects. Errors are logged and swallowed: `:99-101, :111-113`.

**3. `setRoleClaim`: callable**
- **Trigger:** `onCall` in `us-east4`: `functions/src/customClaims.ts:10 setRoleClaim @ 7808a91`.
- **Rejections before the try block:**
  - `unauthenticated` when there is no auth: `:12-17`.
  - `invalid-argument` when `uid` or `role` is missing: `:22-27`.
  - `invalid-argument` when the role is not `teacher` or `student`, so admin is rejected: `:29-34`.
- **Caller check:** permission is denied when the caller's `users.role` is not `teacher` and `uid` is not the caller's own: `:46-51`. Two consequences:
  - Any authenticated user can set their own role to teacher.
  - The `permission-denied` error is thrown inside the try block, and the catch at `:66-71` turns every error into `internal` "Error setting custom claim". The client never receives `permission-denied`.
- **Writes:** `setCustomUserClaims(uid, {role})` at `:54`, then `users/{uid}.update({role})` at `:57-60`.
  - If the document is missing, `update` throws after the claim is already set.
  - The `update` changes `role`, so it also fires `syncUserRole`, which writes the same `{role}` again.

**4. `migrateAllUserRoles`: callable**
- **Trigger:** `https.onCall` in `us-east4`: `functions/src/migrate-user-roles-cloud.ts:13-14 migrateAllUserRoles @ 7808a91`. It is exported at `functions/src/index.ts:44`.
- **Rejections:**
  - `unauthenticated`: `:17-22`.
  - `permission-denied` "Only teachers can run migration" when the caller's `users.role` is not `teacher`: `:32-37`. Admins cannot run it.
  - `internal` "Migration failed: …" when reading the `users` collection fails: `:90-93`.
- **Behaviour:** it reads every `users` document (`:46`) and calls `setCustomUserClaims(id, {role})` for `teacher` and `student` only (`:60-69`). Admin and missing roles are counted as errors and skipped.
- **Returns:** `{success, message, successCount, errorCount, totalUsers, errors?}`: `:79-86`. It writes nothing to Firestore.

**5. `migrateUserRoles`: standalone script**
- **Trigger:** run by hand with `npm run migrate:roles`, which builds and then runs `node lib/migrate-user-roles.js`: `functions/package.json:12 @ 7808a91`. It calls `admin.initializeApp()` at module load: `functions/src/migrate-user-roles.ts:10`. It is not exported from `index.ts`, and there is no caller check.
- It has the same loop and the same `teacher`/`student` filter as the callable, writing `setCustomUserClaims(userId, {role})`: `functions/src/migrate-user-roles.ts:12, :20, :33-41 migrateUserRoles @ 7808a91`.
- It exits with code 1 if the read fails (`:66-68`), otherwise 0. It writes nothing to Firestore.

**6. Other places that set claims**
- **`createStudentAccount`** (`functions/src/adminFunctions.ts:47 @ 7808a91`):
  - The caller's `users.role` must be `admin`, else `permission-denied`: `:59-61`.
  - Email must end in `@rosellestudent.org` or `@rosellestudent.com`, else `invalid-argument`: `:75-81`. The `.com` domain is not in `DOMAIN_ROLE_MAPPINGS`.
  - Sets claims `{role:"student"}` (`:127-129`), then `users.set({…role:"student"…})` (`:132-135`).
- **`createTeacherAccount`** (`:199`): requires an admin caller (`:211`) and an `@roselleschools.org` email (`:227-232`). Sets claims `{role:"teacher"}` (`:248-250`) and `users.role = "teacher"` (`:253-256`).
- **`createAdminAccount`** (`:299`): requires an admin caller (`:311`) and an `@fermi-plus.com` email (`:328-333`). Sets claims `{role:"admin"}` (`:350-352`) and `users.role = "admin"` (`:355-358`). Outside signup, this is the only server path that writes an admin claim.
- **`bulkImportStudents`** (`functions/src/bulkImport.ts:31 @ 7808a91`): requires an admin caller (`:48-50`). Sets `customClaims = {role:"student", gradeLevel}` (`:228-231`) through `auth.importUsers` (`:244`), then writes `users.role = "student"` in a batch (`:294-298`).
- **OAuth exchange** (`functions/src/oauth.ts:311 exchangeOAuthCode @ 7808a91`): `createCustomToken(uid, {provider:"google.com", email})` puts developer claims on the custom token. It sets no role.
- **UNVERIFIED (platform behaviour, not in this code):** whether the Admin SDK's `createUser` and `importUsers` fire `beforeUserCreated`. Firebase documentation says blocking functions do not run for Admin SDK creation.

**7. Client utilities**
- **`UserRoleClaims.setRoleClaim`** calls the callable `setRoleClaim` with `{uid, role}`, then forces a token refresh when the uid is the current user's: `lib/shared/utils/set_user_role_claims.dart:14-37 UserRoleClaims.setRoleClaim @ 7808a91`.
  - It uses `FirebaseFunctions.instance` (`:7`), with no region. The other callers use `instanceFor(region:'us-east4')`: `lib/shared/utils/run_migration.dart:47`, `lib/features/admin/data/services/bulk_import_service.dart:9`.
  - UNVERIFIED: the default region is `us-central1` (platform default), which would not reach the `us-east4` deployment.
  - `hasRole` (`:41-55`) and `getCurrentUserRole` (`:58-69`) only read `claims['role']`.
- **`runUserRoleMigration`** calls `migrateAllUserRoles` in `us-east4` after a local check that a user is signed in, and shows the result in a dialog: `lib/shared/utils/run_migration.dart:13-50 runUserRoleMigration @ 7808a91`.
- **No callers, confirmed:** `git grep` for `UserRoleClaims|runUserRoleMigration|set_user_role_claims|run_migration` in `lib`, `test` and `integration_test` @ 7808a91 found only the definitions and the example comment at `set_user_role_claims.dart:75, :81`.

**How the claim and `users.role` each change, and how they diverge**
- **`users.role` changes from the client and from server functions.**
  - The rules allow the document owner to update their own user document with no field restriction: `firestore.rules:97 @ 7808a91`. Admins and teachers may also update it.
  - Create is allowed for one's own uid when the email domain is valid: `:92-95`.
  - Role checks in the rules read `users.role` from the database (`:43-73`), not the token claim.
  - Client paths that write `role` include:
    - `lib/features/auth/data/services/auth_service.dart:536-539 updateUserRole` (set with merge)
    - `:578-587 saveUserRole`
    - `lib/features/admin/data/services/user_management_service.dart:160-163 updateUserRole`, which first calls a callable named `updateUserRole` that does not exist under `functions/src` (`git grep updateUserRole` returned nothing).
  - Other grep hits not read: `lib/features/auth/providers/auth_provider.dart:159` (`'role': 'admin'`) and `username_auth_service.dart:260, :270, :336, :345`.
- **The claim follows the field only through `syncUserRole`, and only for teacher/student.** The ways they diverge:
  - **Change to admin:** if `users.role` becomes `admin`, or any other value, or is removed, the old claim stays.
  - **Self-promotion:** because the owner may write their own `role`, they can change it to `teacher` or `student`, and `syncUserRole` then copies it into the claim.
  - **Signup claims get replaced:** the users document written at signup triggers `syncUserRole` (role goes from absent to set). For teacher/student that writes `{role}`, which replaces `{role, emailDomain}` and drops `emailDomain`. Admin keeps `{role:"admin", emailDomain}`.
    - Whether the Auth user exists yet when the trigger runs is not shown in the code. If it does not, the error is logged and swallowed (`customClaims.ts:111-113`).
  - **Bulk import:** the same replacement drops the `gradeLevel` claim set at `bulkImport.ts:230`.
  - **Order of writes in `setRoleClaim`:** it writes the claim before the document. If the document update fails, the claim has changed and the field has not.
  - **Migrations:** they only push field values to claims, never the other way, and skip admin.
  - **Deleted user document:** deletion clears all claims (`customClaims.ts:97`).

**Looked for and not found @ 7808a91**
- `ADMIN_EMAILS` entries: the array is empty.
- A server-side `updateUserRole` callable.
- Any caller of the two Dart utilities.

**Not read:** I reached the 15-file budget, so these are left:
- `storage.rules`, which presumably consumes the claim, per the comment at `customClaims.ts:8`.
- `auth_provider.dart`, `username_auth_service.dart`, and the rest of `user_management_service.dart`.
- `adminFunctions.ts` beyond the three account-creation functions.