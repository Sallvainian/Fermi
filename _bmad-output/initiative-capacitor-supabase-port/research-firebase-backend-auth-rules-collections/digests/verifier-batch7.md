All 13 citations check out against the code at 7808a91, and each cited line sits inside the symbol it names. Five citations should be tightened or made more precise; the corrected forms are below. Everything was read from the commit through git, with the excluded paths left out.

**ref=[53]** functions/src/authBlocking.ts:106-110 (autoAssignRole) @ 7808a91 — **verified**. The function returns `{customClaims, displayName, emailVerified: role === "admin"}`, and `customClaims` is `{role, emailDomain}`, built at lines 66-69. `role` comes from `getRoleFromEmail`, whose mappings are teacher, student and admin (functions/src/config/domainRoles.ts:3-20). The return has no role-specific branch except `emailVerified`.

**ref=[54]** functions/src/bulkImport.ts:228-244 (bulkImportStudents) @ 7808a91 — **verified**. `record.customClaims = {role: "student", gradeLevel: user.gradeLevel || null}` is at 228-231, and `auth.importUsers(importUserRecords, …)` is at 244. `bulkImportStudents` starts at line 31 and the cited lines are inside it.

**ref=[55]** functions/src/oauth.ts:311-314 (exchangeOAuthCode) @ 7808a91 — **verified**. `createCustomToken(firebaseUser.uid, {provider: "google.com", email: userInfo.email})` spans 311-314. The `createUser` fallback at 302-307 sets no claims either. `exchangeOAuthCode` runs from line 170 to before line 350.

**ref=[56]** functions/src/adminFunctions.ts:132-142 (createStudentAccount) @ 7808a91 — **verified**. All nine listed fields are there and nothing else. The role claim is set separately at 127-129. `createStudentAccount` runs from line 47 to before line 199.

**ref=[57]** functions/src/bulkImport.ts:294-317 (bulkImportStudents) @ 7808a91 — **verified**. The base fields plus `profileComplete: false` are at 295-306. `studentId` (309-311) is added only when one is provided. `classId` and `enrolledClasses` (314-317) are added only when the student has at least one class.

**ref=[58]** lib/features/auth/data/services/auth_service.dart:383 (signInWithGoogle) @ 7808a91 — **verified**. The line is `_firestore!.collection('users').doc(user.uid).get()`. `signInWithGoogle` runs from line 254 to before line 417.

**ref=[59]** functions/src/bulkImport.ts:315-316 (bulkImportStudents) @ 7808a91 — **verified**. Line 316 alone covers only `enrolledClasses`; the scalar `classId = studentClassIds[0]` is on line 315, so the range should be 315-316. Note that "the functions" does not include createStudentAccount, which writes neither field (adminFunctions.ts:132-142). The other writer is migrateStudentClassEnrollment at functions/src/bulkImport.ts:620-624 (`classId`, `enrolledClasses: [classId]`), which starts at line 549.

**ref=[60]** functions/src/adminFunctions.ts:149-153 (createStudentAccount) @ 7808a91 — **verified**. Line 149 only builds `classRef`. The update with `studentIds: arrayUnion(userRecord.uid)` is at 150-153, inside a loop over `classIds` that only runs when class IDs are passed in.

**ref=[61]** functions/src/bulkImport.ts:180-184 (bulkImportStudents) @ 7808a91 — **verified**. Line 180 only starts the query; the `.where("enrollmentCode", "==", …toUpperCase())` and `.where("isActive", "==", true)` filters, `limit(1)` and `get()` are at 180-184.

**ref=[62]** lib/shared/routing/app_router.dart:574-581 (createRouter) @ 7808a91 — **verified**. The route builds `FlyerChatScreen(conversationId: chatRoomId, conversationTitle: 'Chat')`, with `chatRoomId` taken from the path. The lines sit in `createRouter` (starts at 67), which is inside class `AppRouter` (starts at 59), so `createRouter` is the more precise symbol.

**ref=[63]** lib/features/chat/presentation/providers/chat_provider.dart:153-170 (sendMessage) @ 7808a91 — **verified**. Lines 153-164 only build the map: text, content, senderId, senderName, senderRole, timestamp, imageUrl, attachmentUrl, attachmentType, isRead. The write to `chatRooms/{_currentChatRoom['id']}/messages` is `.add(...)` at 166-170, so the range should run to 170. The enclosing method is `SimpleChatProvider.sendMessage`, which starts at line 141.

**ref=[64]** lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:287-290 (_buildThreadCard) @ 7808a91 — **verified**. Line 290 reads the `likes/{currentUserId}` doc under `discussion_boards/{boardId}/threads/{thread.id}`, built at 280-289. `_buildThreadCard` runs from line 128 to before line 408, in `_DiscussionBoardDetailScreenState`.

**ref=[65]** functions/src/behaviorPoints.ts:125-145 (awardBehaviorPoints) @ 7808a91 — **verified**. All 19 fields listed are in the `batch.set(historyRef, …)` call and nothing else is. `awardBehaviorPoints` runs from line 31 to before line 162.