# Digest: how `firestore.rules` decides access @ 7808a91

I read the file at the commit with `git show 7808a91:firestore.rules`. It is identical to the working tree and is 805 lines long. I read 1 repository file out of the 15-file budget. Statements about how Firestore evaluates rules are language semantics, not something the code shows, and are labelled that way.

## 1. How roles are determined (load-bearing)

- **No custom claims (confirmed).** `git grep -n 'request\.auth\.token' 7808a91 -- firestore.rules` finds only `request.auth.token.email`, at lines 24-25, 31-32 and 38-39. A search for `token\.(role|admin|teacher|student|email_verified)|\.claims|customClaims` and a search for `email_verified|emailVerified` both found nothing. `firestore.rules:7-79 @ 7808a91`
- **Role comes from the database.** `getUserRole(userId)` calls `get(/users/$(userId))` and returns `data.role`, or null. Every role helper calls it with `request.auth.uid`. `firestore.rules:43-46 (getUserRole) @ 7808a91` — **load-bearing**
- **Email domain helpers** match the token email against a case-insensitive regex:
  - `hasTeacherDomain`: `@roselleschools.org` (`:22-26`)
  - `hasStudentDomain`: `@rosellestudent.org` (`:29-33`)
  - `hasAdminDomain`: `@fermi-plus.com` (`:36-40`)
  - `hasValidSchoolDomain` is any of the three (`:17-19`). `@ 7808a91`
- **`isTheTeacher()`** requires role `'teacher'` and either `hasTeacherDomain()` or `isAdmin()`. `isAdmin()` needs role `'admin'`, so it is always false when the role is `'teacher'`. In practice this is role teacher plus the teacher domain. It checks no ownership of any document, so any user with teacher role and domain qualifies. `firestore.rules:49-55 (isTheTeacher) @ 7808a91` — **load-bearing**
- **`isStudent()`** works the same way: role `'student'` and (`hasStudentDomain()` or `isAdmin()`). Again `isAdmin()` can never be true here. `firestore.rules:58-64 (isStudent) @ 7808a91` — **load-bearing**
- **`isAdmin()`** requires role `'admin'` and `hasAdminDomain()`. `firestore.rules:67-73 (isAdmin) @ 7808a91` — **load-bearing**
- **`isEnrolledInClass(classId)`** requires `isStudent()` and the caller's uid in `classes/{classId}.studentIds`. `firestore.rules:76-79 (isEnrolledInClass) @ 7808a91`
- **`isOwner(userId)`** requires the caller to be signed in and `auth.uid == userId`. `firestore.rules:12-14 (isOwner) @ 7808a91`
- **Users can set their own role.** The `users` create rule checks only the uid and the domain, and the update rule `isOwner(userId)` has no `affectedKeys` limit. Nothing restricts the `role` field. The domain check inside each role helper is the only thing that ties a role to an email. `firestore.rules:92-97 @ 7808a91` — **load-bearing**

## 2. Rules for each match block

Placeholders (`&& true`) are listed in section 3.

### `users/{userId}` (`:82-100`) — load-bearing
- **read:** signed in and one of: own doc, `isTheTeacher()`, `isAdmin() || isTheTeacher()` (the teacher check is written twice), or `isStudent() && hasValidSchoolDomain()`. Any student can read every user doc. (`:85-90`)
- **create:** signed in, `auth.uid == userId`, `request.resource.data.uid == userId`, and `hasValidSchoolDomain()`. No other field is checked, including `role`. (`:92-95`)
- **update:** `isOwner(userId) || isAdmin() || isTheTeacher()`, with no field checks. (`:97`)
- **delete:** `isAdmin() || isTheTeacher()`. The comment says "Only admins". (`:98-99`)

### `public_usernames/{username}` (`:104-113`)
- **read:** `if true`, so unauthenticated reads are allowed. (`:106`)
- **create:** `request.resource.data.uid == auth.uid`, and `get(users/{auth.uid}).data.username == username`. (`:108-110`)
- **update, delete:** `isAdmin() || isTheTeacher()`. (`:112`)

### `classes/{classId}` (`:117-199`) — load-bearing
- **read:** `isTheTeacher() || isAdmin() || isTheTeacher() || resource == null || isAuthenticated()`. Any signed-in user can read any class. The comment lists "enrolled in the class" as a condition, but the rule never checks it. (`:124-127`)
- **create:** `(isTheTeacher() && request.resource.data.teacherId == auth.uid) || isAdmin() || isTheTeacher()`. The bare `isTheTeacher()` at the end makes the `teacherId` check non-binding. (`:130-131`)
- **update** (`:134-143`), either branch:
  - `isTheTeacher()`, for any class and any fields; or
  - `isAuthenticated() && true && isStudent()`, changed keys `hasOnly(['studentIds','updatedAt'])`, and the caller's uid not already in `resource.data.studentIds`.
  - Nothing checks that the new `studentIds` contains the caller or keeps the existing entries.
- **delete:** `(isTheTeacher() && resource.data.teacherId == auth.uid) || isAdmin() || isTheTeacher()`. The ownership check is non-binding for the same reason as create. (`:146-147`)

Subcollections of `classes/{classId}`:
- **`studentPoints/{studentId}`** (`:150-161`)
  - read: teacher, admin, or `isStudent() && auth.uid == studentId`
  - create, update: `isTheTeacher()`
  - delete: `isAdmin() || isTheTeacher()`
- **`studentPoints/{studentId}/history/{historyId}`** (`:163-177`)
  - read: teacher, admin, or the student whose `studentId` it is
  - create and update: `isTheTeacher()`
  - delete: admin or teacher
- **`behaviors/{behaviorId}`** (`:181-192`)
  - read: teacher, admin, or `isEnrolledInClass(classId)`
  - create, update: `isTheTeacher()`
  - delete: teacher or admin
- **`{document=**}` catch-all** (`:195-198`)
  - read: `isTheTeacher() || isEnrolledInClass(classId)`
  - write: `isTheTeacher()`
  - Firestore semantics: overlapping matches are combined with OR. This catch-all therefore also covers `studentPoints` and `history` docs, so any enrolled student gets read access to every student's points.

### `conversations/{conversationId}` (`:203-247`) — load-bearing
- **read:** signed in and (`resource == null` or caller in `resource.data.participants`). (`:205-207`)
- **create:** caller in `request.resource.data.participants`. (`:210-211`)
- **update:** `resource != null` and caller in the existing `participants`. No field checks, so participants can rewrite the participant list. (`:214-216`)
- **delete:** `false`. (`:218`)
- **`messages/{messageId}`** (`:220-233`)
  - read: caller in the parent's `participants`, via `get`
  - create: `auth.uid == authorId || auth.uid == senderId`, and caller in the parent's `participants`
  - update and delete: `false`
- **`typing/{userId}`** (`:236-246`)
  - read: any signed-in user
  - write and delete: `auth.uid == userId`. `delete` repeats what `write` already covers.

### `chatRooms/{chatRoomId}` (`:250-275`) — load-bearing
- **read:** any signed-in user. (`:252`)
- **create:** caller in `request.resource.data.participantIds`, plus `&& true`. (`:254-256`)
- **update and delete:** caller in the existing `participantIds`. No field checks. (`:258-262`)
- **`messages/{messageId}`** (`:264-274`)
  - read: caller in the parent's `participantIds`
  - create: `auth.uid == senderId`, caller in the parent's `participantIds`, plus `&& true`
  - update: `false`
  - delete: any signed-in user (`:273`)

### `chat_rooms/{chatRoomId}` (`:278-307`), the older snake_case path — load-bearing
- **read:** signed in and (`isTheTeacher()`, `resource == null`, or caller in `participantIds`). (`:283-286`)
- **create:** caller in the new `participantIds`, plus `&& true`. (`:287-289`)
- **update:** (`isTheTeacher()` or participant), and (`isTheTeacher()` or the new `participantIds.hasAll(old participantIds)`). This rejects a non-teacher removing participants. (`:290-293`)
- **delete:** `false`. (`:294`)
- **`messages/{messageId}`** (`:296-306`)
  - read: caller in the parent's `participantIds`
  - create: `senderId == uid`, participant, plus `&& true`
  - update: `false`
  - delete: `isTheTeacher()` or the sender

### `assignments/{assignmentId}` (`:310-325`) — load-bearing
- **read:** `isTheTeacher() || resource == null || (isStudent() && resource.data.classId != null && isEnrolledInClass(resource.data.classId))`. (`:312-314`)
- **create:** `isTheTeacher() && request.resource.data.teacherId == auth.uid`. Nothing checks that `classId` belongs to that teacher. (`:317-318`)
- **update and delete:** `isTheTeacher() && resource.data.teacherId == auth.uid`. The update rule does not stop `request.resource.data.teacherId` from being changed. (`:321-324`)

### `grades/{gradeId}` (`:328-341`) — load-bearing
- **read:** `isTheTeacher() || resource == null || (isStudent() && resource.data.studentId == auth.uid)`. (`:330-332`)
- **create:** `isTheTeacher()` and the new `teacherId == uid`. (`:335-336`)
- **update and delete:** `isTheTeacher()` and the existing `teacherId == uid`. (`:337-340`)

### Collection-group rules
- **`{path=**}/grades/{gradeId}`:** read if `isTheTeacher()`. (`:344-346`)
- **`{path=**}/history/{historyId}`:** read if `isTheTeacher() || isAdmin() || isTheTeacher()`, or if signed in, `resource.data.classId` exists, and `get(classes/{classId}).data.teacherId == auth.uid`. (`:349-358`)

### `submissions/{submissionId}` (`:361-382`) — load-bearing
- **read:** teacher, `resource == null`, or the student whose `studentId` it is. (`:363-365`)
- **create:** `isStudent()`, `auth.uid == request.resource.data.studentId`, plus `&& true`. The comment says "with email verification". Nothing checks the assignment or class enrollment. (`:368-370`)
- **update**, either branch (`:373-378`):
  - `isStudent()`, own `studentId`, `resource.data.submittedAt == null`, and `studentId` unchanged; or
  - `isTheTeacher()`.
  - The student branch has no `affectedKeys` limit.
- **delete:** `isTheTeacher()`. (`:381`)

### Other collections
- **`announcements/{announcementId}`** (`:385-388`). The locator missed this block.
  - read: `request.auth != null`
  - create, update, delete: `isTheTeacher()`
- **`discussion_boards/{boardId}`, first block** (`:391-471`)
  - board: read signed in; create signed in plus `&& true`; update when `auth.uid == createdBy`; delete `isTheTeacher()`
  - threads (`:400-415`): update when the caller is the author, or changed keys are only `likeCount` and it changes by ±1, or only `replyCount` and it changes by ±1; delete by teacher or author
  - comments (`:418-426`): create signed in plus `&& true`; update by author; delete by teacher or author
  - replies (`:429-440`): update condition is `uid == authorId || (hasOnly(['likeCount']) && likeCount == old+1 || likeCount == old-1)`. The inner parentheses are missing, unlike the thread rule. By standard precedence (`&&` binds tighter than `||`), any update where `likeCount == old-1` passes whatever other keys change.
  - likes (`:443-454`, `:458-469`): create when `auth.uid == likeId == request.resource.data.userId`; delete when `auth.uid == likeId`; update `false`
- **`games/{gameId}`** (`:474-488`)
  - read and create: signed in
  - update, delete: `resource.data.creatorId == uid`
  - `scores/{scoreId}` (`:481-487`): read signed in; create when the new `studentId == uid`; update when the existing `studentId == uid`. There is no delete rule, so delete is denied.
- **`scheduled_messages/{messageId}`** (`:492-503`): every operation keys on the nested field `message.senderId == uid`. Update also requires the new `message.senderId == uid`. Create has `&& true`.
- **`discussion_boards/{boardId}`, second block** (`:506-588`)
  - board: create `isTheTeacher()`; update `createdBy == uid`; delete teacher
  - threads, comments and replies: create requires `request.resource.data.authorId == uid`
  - the replies update has the same precedence pattern as the first block (`:550-555`)
  - likes rules are the same as the first block (`:560-586`)
- **`calendar_events/{eventId}`** (`:591-601`)
  - read: `createdBy == uid` or caller in `participantIds`
  - create: the new `createdBy == uid`
  - update, delete: `createdBy == uid`
- **`students/{studentId}`** (`:604-618`)
  - read: signed in and (teacher, `resource == null`, or `isStudent()` with `uid == studentId` or `uid == resource.data.userId`)
  - update: `isStudent()` and (`uid == studentId` or `uid == resource.data.userId`), with no field checks
  - create, delete: `isTheTeacher()`
- **`teachers/{teacherId}`** (`:621-624`): read and write if `isTheTeacher() && uid == teacherId`.
- **`calls/{callId}`** (`:627-660`)
  - read: signed in and (`resource == null`, caller, receiver, or `status == 'ringing'`). Any signed-in user can read a ringing call.
  - create: `uid == callerId`, plus `&& true`
  - update: caller or receiver, and (new `status` in `['ended','rejected','missed','answered']` or old `status == 'ringing'`)
  - delete: `false`
  - `candidates/{userId}/candidates/{candidateId}` (`:655-659`): read and write if the caller is `callerId` or `receiverId` of the parent call, via `get`. The locator missed this block.
- **`activities/{activityId}`** (`:663-682`)
  - read: signed in and (admin, teacher, `resource == null`, or `isStudent()` with uid in `get(classes/{resource.data.classId}).data.studentIds`)
  - create: admin, teacher, or the new `userId == uid`
  - update, delete: `isAdmin() || isTheTeacher()`. The comment says "Only admins".
- **`notifications/{notificationId}`** (`:685-703`)
  - read: `resource == null` or `userId == uid`
  - create: `isTheTeacher()` or the new `userId == uid`
  - update, delete: `userId == uid`
- **`fcm_tokens/{userId}`** (`:706-708`): read and write if `uid == userId`.
- **`bug_reports/{reportId}`** (`:711-722`)
  - read: `isTheTeacher()`
  - create: the new `userId == uid`, plus `&& true`
  - update, delete: `false`
- **`jeopardy_games/{gameId}`** (`:725-749`)
  - read: signed in and (`resource == null`, `isPublic == true`, or `teacherId == uid`). The read rule has no role check.
  - create: `isTheTeacher()` and the new `teacherId == uid`
  - update: teacher, owner, and `teacherId` unchanged
  - delete: teacher and owner
- **`jeopardy_sessions/{sessionId}`** (`:752-772`)
  - read: `resource == null`, `teacherId == uid`, or caller in `participantIds`
  - create: `isTheTeacher()` and `teacherId == uid`
  - update: `teacherId == uid` or caller in `participantIds`, with no field checks
  - delete: teacher and owner
- **`presence/{userId}`** (`:775-790`): read by any signed-in user; create, update and delete if `uid == userId`.
- **Default deny `{document=**}`** (`:793-795`): read and write `false`. In Firestore semantics this does not cancel the allow rules above, because matches combine with OR.

## 3. Duplicates, placeholders and comments that disagree with the code

- **`discussion_boards/{boardId}` is matched twice** (`:391` and `:506`). Under Firestore OR semantics the more permissive block wins:
  - any signed-in user can create a board (`:393`), even though `:508` says teacher only;
  - thread, comment and reply create needs no `authorId` check (`:402`, `:420`, `:431`), even though `:517`, `:536` and `:548` require one.
- **Placeholder `true`** appears 15 times, all found by `grep -n -E '^\s*true( &&|;)'`: `:136`, `:256`, `:270`, `:289`, `:302`, `:370`, `:394`, `:403`, `:421`, `:432`, `:497`, `:641`, `:718`, `:738`, `:762`. The comments next to several of them mention email verification (`:367`, `:638`, `:715`; `:209` says "NO EMAIL VERIFICATION"). This suggests the `true` replaced a verification check — that is my inference.
- **The footer claims "Email verification required for content creation"** (`:800`). No `email_verified` check exists anywhere in the file.
- **Redundant `isAdmin() || isTheTeacher()` after an earlier `isTheTeacher()`:** `:88`, `:125`, `:153`, `:166`, `:184`, `:191`, `:352`, `:668-669`, `:676-677`.
- **Comments that say "only admins" while the code also allows `isTheTeacher()`:** `:98-99`, `:111-112`, `:159-160`, `:175-176`, `:680-681`.
- **Field-level checks in the whole file** (searched for `hasOnly|affectedKeys|hasAll|.diff(`):
  - `affectedKeys().hasOnly` at `:140`, `:407`, `:411`, `:436`, `:522`, `:526`, `:553`;
  - `hasAll` at `:293`.
  - Everything else compares individual `request.resource.data` and `resource.data` fields, as listed above.

## 4. Not found or not verified

- **No custom claims or `email_verified` checks** (searches in section 1, at 7808a91).
- **The locator's list missed 3 blocks:** `announcements :385`, `games/scores :481` and `calls/candidates :655`.
- **UNVERIFIED:** how `resource == null` behaves in list (collection query) evaluations, and how errors are handled when an unauthenticated request hits `getUserRole(request.auth.uid)`. Both depend on Firestore runtime semantics that the code does not show.