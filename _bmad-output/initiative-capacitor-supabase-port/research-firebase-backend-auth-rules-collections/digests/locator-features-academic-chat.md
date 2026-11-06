I searched all 62 files in the six assigned folders at commit `7808a91` using `git ls-tree` and `git grep`. Each citation is `path:line (symbol) @ 7808a91`. The symbol is the class that encloses the hit.

**Q1 (sign-in and role reads; only the role-read part falls in my area)**
- No hits in my area for `getIdTokenResult`, `claims` (the token-claims sense), `authStateChanges` or `idTokenChanges`. Screens get the user and role from `AuthProvider`, for example `lib/features/chat/presentation/screens/class_selection_screen.dart:32 (_ClassSelectionScreenState) @ 7808a91` reads `authProvider.userModel?.role` and compares it with `UserRole.teacher` at :43 and :154.
- Other `context.read/watch<AuthProvider>()` call sites:
  - `lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart:30,150,267 (_TeacherAssignmentsScreenState) @ 7808a91`
  - `lib/features/calendar/presentation/screens/calendar_screen.dart:29 (_CalendarScreenState) @ 7808a91`
  - `lib/features/chat/presentation/screens/chat_list_screen.dart:27-28 (_ChatListScreenState) @ 7808a91`, which passes it on through `lib/features/chat/presentation/providers/chat_provider.dart:335 (SimpleChatProvider) @ 7808a91` (`setAuthProvider(dynamic)`)
  - `lib/features/classes/presentation/widgets/create_class_dialog.dart:72 (_CreateClassDialogState) @ 7808a91`
  - about 8 more under `lib/features/classes` and `lib/features/assignments`
- Two places read the role from the Firestore `users` document instead of from claims:
  - `lib/features/discussions/presentation/providers/discussion_provider.dart:184 (SimpleDiscussionProvider) @ 7808a91`: `_fetchUserRole` reads `users/{uid}.role` and falls back to `'student'`.
  - `lib/features/chat/data/services/scheduled_messages_service.dart:97-105 (ScheduledMessagesService) @ 7808a91`: reads `users/{uid}.role` to fill in `senderRole`, also defaulting to `'student'`.

**Q2, Q3, Q4 (server role claims, `firestore.rules`, `storage.rules`)**
- Nothing in my area for `FirebaseStorage`, `firebase_storage`, `.ref(`, `putFile`, `putData`, `getDownloadURL` or `refFromURL`.
- Chat files and images are not uploaded to Storage directly. They go as base64 to the `uploadChatFile` callable, which returns `url` (see Q12). The returned URL is shown with `Image.network` at `lib/features/chat/presentation/widgets/web_image_stub.dart:20 @ 7808a91`, and on web with an `HTMLImageElement` at `lib/features/chat/presentation/widgets/web_image_web.dart:45 @ 7808a91`.

**Q5 (only `users` and `scheduled_messages` appear in my area)**
- **`users`** (reads only, no writes in my area):
  - `lib/features/calendar/presentation/providers/calendar_provider.dart:164 (CalendarProvider) @ 7808a91`: reads displayName/username.
  - `lib/features/classes/presentation/providers/class_provider.dart:271 (ClassProvider) @ 7808a91`: `documentId whereIn` plus `role == 'student'`; :455 (ClassProvider) queries students and maps them with `Student.fromFirestore`.
  - `lib/features/chat/presentation/screens/class_selection_screen.dart:107 @ 7808a91`
  - `lib/features/chat/presentation/screens/flyer_chat_screen.dart:243 (_FlyerChatScreenState) @ 7808a91`
  - `lib/features/chat/presentation/screens/group_creation_screen.dart:48 @ 7808a91`
  - `lib/features/chat/presentation/screens/user_list.dart:28 (SimpleUserList) @ 7808a91`: streams the whole collection.
  - `lib/features/chat/presentation/screens/user_selection_screen.dart:44 @ 7808a91`
  - `lib/features/discussions/presentation/providers/discussion_provider.dart:184, 247 (UserModel.fromFirestore snapshot listener), 350, 514 @ 7808a91`
  - `lib/features/grades/data/services/grade_analytics_service.dart:40 (GradeAnalyticsService) @ 7808a91`: uses `Student.fromFirestore`.
  - `UserModel` and `Student` are both defined outside my area; `Student` is imported from `lib/features/student/domain/models/student.dart`.
- **`scheduled_messages`**:
  - Write: `lib/features/chat/data/services/scheduled_messages_service.dart:111-117 (ScheduledMessagesService) @ 7808a91` does `.doc().set({chatRoomId, message: Message.toFirestore(), createdAt})`.
  - Queries: :145 (`chatRoomId` plus `message.senderId`), :263 (`message.senderId`).
  - Delete at :185-187; update at :232-234.
  - Model: `ScheduledMessage.fromFirestore` at :320 of the same file.
- **Collections passed as a variable** (resolved through files outside my area):
  - `lib/shared/services/firestore_service.dart:52 @ 7808a91`: `collection(collectionPath)`.
  - `lib/shared/services/firestore_repository.dart:145 (getCollectionReference) @ 7808a91`: `collection(path)`.
  - In my area, `collectionPath` resolves to `'assignments'`, `'classes'` and `'grades'` (Q6). `getCollectionReference` is called with `'grades'` and `'archived_grades'` (Q6).
  - `collection(this.collectionName)` does not appear in my area.
- No hits for `public_usernames`, `presence`, `fcm_tokens`, `notifications` (as a collection) or `bug_reports`.

**Q6 (classes, students, assignments, submissions, grades, calendar_events)**
- **`classes`**:
  - Model: `lib/features/classes/domain/models/class_model.dart:137 fromFirestore, :216 toFirestore (ClassModel) @ 7808a91`.
  - `lib/features/classes/data/services/class_service.dart:22 (ClassService) @ 7808a91`: a `FirestoreRepository` with `collectionPath: 'classes'`. Create at :46, update at :78, delete at :87. Enroll and unenroll run in transactions (:162, :207) that call `transaction.update` (:193, :231).
  - `lib/features/classes/presentation/providers/class_provider.dart (ClassProvider) @ 7808a91`: about 15 hits. `add(toFirestore())` at :181, a raw add at :442, deletes at :210, and updates at :305, :319, :333, :347 and :479.
  - `lib/features/chat/presentation/screens/class_selection_screen.dart:46,51,94 @ 7808a91` (reads) and :132-134 (`update({'chatRoomId'})`).
  - `lib/features/classes/presentation/widgets/create_student_dialog.dart:131-136 @ 7808a91`: `arrayUnion` into `studentIds`, plus `studentCount` increment.
  - `lib/features/assignments/presentation/providers/student_assignment_provider.dart:34 (SimpleStudentAssignmentProvider) @ 7808a91`
  - `lib/features/grades/data/services/grade_analytics_service.dart:16 @ 7808a91`
- **`students`**: `lib/features/classes/presentation/widgets/create_student_dialog.dart:96 (generates the doc ID), :125-127 (.set(student.toFirestore())) (_CreateStudentDialogState) @ 7808a91`. The model is `Student` from `lib/features/student`, outside my area.
- **`assignments`**:
  - Models: `lib/features/assignments/domain/models/assignment.dart:222 fromFirestore, :277 toFirestore (Assignment) @ 7808a91` and `lib/features/assignments/domain/models/assignment_model.dart:34 fromFirestore, :53 toMap (AssignmentModel) @ 7808a91`.
  - `lib/features/assignments/data/services/assignment_service.dart:23 (AssignmentService) @ 7808a91`: repository with `collectionPath: 'assignments'`. Create at :34, update at :66, field updates at :137 and :147, and `batchUpdate` at :177 and :244.
  - `lib/features/assignments/presentation/providers/assignment_provider.dart:32-206 (SimpleAssignmentProvider) @ 7808a91`: 8 hits, including add at :62 and delete at :188.
  - Reads: `student_assignment_provider.dart:51,109 @ 7808a91`, `lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart:671 @ 7808a91`, `grade_analytics_service.dart:26 @ 7808a91`, `lib/features/grades/presentation/providers/grade_provider.dart:46,161 (SimpleGradeProvider) @ 7808a91`.
- **`submissions`**:
  - Model: `lib/features/assignments/domain/models/submission.dart:79 fromFirestore, :111 toFirestore (Submission) @ 7808a91`.
  - `lib/features/assignments/data/services/submission_service.dart:35 (SubmissionService) @ 7808a91`: add at :58, update at :172 and :189 (`gradedAt`), delete at :209.
  - `student_assignment_provider.dart:73,123 (reads), :181 (add) @ 7808a91`
  - `grade_provider.dart:66,73 (FirestoreBatchQuery.batchWhereIn),103,135 (update writes a nested 'grade' map),177,184,207,268 @ 7808a91`
  - `assignments_list_screen.dart:677 @ 7808a91`, `grade_analytics_service.dart:55 @ 7808a91`
- **`grades`**:
  - Model: `lib/features/grades/domain/models/grade.dart:265 fromFirestore, :307 toFirestore (Grade) @ 7808a91`. `grade_analytics.dart` has no serializers.
  - `lib/features/grades/data/services/grade_service.dart:19 (GradeService) @ 7808a91`: repository with `collectionPath: 'grades'`. Batch set at :116-119, batch update at :139-143, `batchUpdate` at :171, and an archive step at :279-289 that copies to `archived_grades/{id}` and deletes the original.
  - `assignment_service.dart:83 @ 7808a91`: inside a transaction, `getCollectionReference('grades').where('assignmentId')` finds the grades, which are deleted along with the assignment.
  - `grade_analytics_service.dart:68 @ 7808a91`: subcollection `submissions/{id}/grades` ordered by `gradedAt`, limit 1.
  - `grade_analytics_service.dart:464 (getGradeTrends) @ 7808a91`: `collectionGroup('grades')` filtered on `classId` and `gradedAt >=`, ordered by `gradedAt`.
- **`calendar_events`**:
  - Model: `lib/features/calendar/domain/models/calendar_event.dart:189 fromFirestore, :229 toFirestore (CalendarEvent) @ 7808a91`.
  - `lib/features/calendar/data/services/calendar_service.dart (SimpleCalendarService) @ 7808a91`: 9 hits. Reads at :19, :42, :175, :229 and :263; add at :92; update at :136; deletes at :152 and :279.

**Q7 (chat and discussion collections)**
- **`chatRooms`**:
  - Model: `lib/features/chat/domain/models/chat_room.dart:95 fromFirestore, :136 toFirestore (ChatRoom) @ 7808a91`, with `ParticipantInfo.fromMap` at :281 and `toMap` at :296.
  - `lib/features/chat/presentation/providers/chat_provider.dart (SimpleChatProvider) @ 7808a91`: query at :35; adds at :125 and :318; updates at :176 (lastMessage), :192 (lastReadTime) and :234 (`arrayRemove` on `participantIds`); delete at :270.
  - `user_list.dart:68 @ 7808a91`
- **`chatRooms/{id}/messages`**: `chat_provider.dart:61-63 (stream), :167-169 (add of text/content/senderId/senderRole/timestamp/imageUrl/attachment*/isRead), :257-265 (batch delete) @ 7808a91`.
- **`conversations`**:
  - `lib/features/chat/data/controllers/firestore_chat_controller.dart:55-71 (FirestoreChatController) @ 7808a91`: creates the doc if missing with `participants`, `participantIds`, `createdAt`, `updatedAt` and `type: 'direct'`.
  - `lib/features/chat/presentation/screens/flyer_chat_screen.dart:108-114 (_FlyerChatScreenState) @ 7808a91`: builds the doc ID from the sorted uids joined by `_`, and sets the same fields plus `lastMessage` and `lastMessageTime`.
- **`conversations/{id}/messages`**: the client only reads, at `firestore_chat_controller.dart:94-96 (limit 30), :129-131 (listener), :517-519 (pagination with startAfter) @ 7808a91`. Sending goes through the `sendMessage` callable. Model: `lib/features/chat/domain/models/message.dart:91 fromFirestore, :136 fromMap, :175 toFirestore (Message) @ 7808a91`.
- **`conversations/{id}/typing`**: read via listener at `firestore_chat_controller.dart:249-251 @ 7808a91`. Writes go through the `updateTypingStatus` callable.
- **`discussion_boards`**:
  - Model: `lib/features/discussions/presentation/providers/discussion_provider.dart:36 fromFirestore, :50 toFirestore (SimpleDiscussionBoard) @ 7808a91`.
  - In the same file: stream ordered by `isPinned` and `createdAt` at :330; add at :452; `threadCount` increment at :580.
  - `lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart:442-444 (threadCount -1) @ 7808a91`
  - `lib/features/discussions/presentation/screens/discussion_boards_screen.dart:357-359 (delete) @ 7808a91`
- **`threads`**:
  - Model: `discussion_provider.dart:93 fromFirestore, :110 toFirestore (SimpleDiscussionThread) @ 7808a91`; the same file has a read at :474-476 and an add at :574-577.
  - `discussion_board_detail_screen.dart:434-438 (delete) @ 7808a91`
  - `lib/features/discussions/presentation/screens/thread_detail_screen.dart:43-45, 138-142 (replyCount +1), 522-526 (replyCount -1) (_ThreadDetailScreenState) @ 7808a91`
- **`replies`** (`discussion_boards/{b}/threads/{t}/replies`): `thread_detail_screen.dart:57-61, 76-80, 124-129 (add), 512-518 (delete) @ 7808a91`. Replies are written as raw maps; there is no model class for them.
- **`likes`**:
  - On threads: `discussion_board_detail_screen.dart:281-305 (_DiscussionBoardDetailScreenState) @ 7808a91` toggles `likes/{uid}` (set with `likedAt`, or delete) and applies ±1 to `likeCount`. `discussion_provider.dart:634-638 @ 7808a91` reads them.
  - On replies: `thread_detail_screen.dart:442-448, 468-491 (_ReplyCardState) @ 7808a91`, same toggle with `likeCount` ±1.

**Q8 (behaviour points, games, PKCE, rate limits)**: no hits in my area for `studentPoints`, `behaviors`, `history`, `activities`, `jeopardy_*`, `oauth_pkce_challenges` or `_rate_limits`.

**Q9, Q10 (Cloud Functions source)**: outside my area. The only server touchpoints are the four callables listed under Q12.

**Q11 (push notifications)**
- `flyer_chat_screen.dart:78 @ 7808a91` calls `FirebaseMessagingService().markConversationActive(_actualConversationId)` after creating the controller, and :148 (dispose) calls `markConversationActive(null)`. The service is imported at :10.
- No hits in my area for `FirebaseMessaging`, `flutter_local_notifications` or `FlutterLocalNotificationsPlugin`.
- `assignment_service.dart:6,21 @ 7808a91` imports and injects `NotificationService` to schedule notifications when an assignment is created.

**Q12 (callables)**
- All of them are in `lib/features/chat/data/controllers/firestore_chat_controller.dart (FirestoreChatController) @ 7808a91`, which uses `FirebaseFunctions.instanceFor(region: 'us-east4')` (:17):

| Line | Callable | Arguments | Returns |
|---|---|---|---|
| :292 | `updateTypingStatus` | `{conversationId, isTyping}` | not read |
| :323 | `sendMessage` | `{conversationId, text, attachments}` | not read |
| :383 (image) | `uploadChatFile` | `{conversationId, fileName, mimeType, base64Data, fileSize}` | `url`, `fileName` |
| :473 (file) | `uploadChatFile` | same as above | `url`, `fileName` |
| :547 | `markMessagesAsRead` | `{conversationId, messageIds}` | not read |

- No other `httpsCallable` or `FirebaseFunctions` use in my area.

**Q13 (tests)**: no test files in my area.

**Searched with nothing found** (all at `7808a91`, across the six folders):
- `FirebaseDatabase` / `firebase_database` (no Realtime Database use)
- Storage APIs (`FirebaseStorage`, `.ref(`, `putFile`, `putData`, `getDownloadURL`, `refFromURL`)
- `FirebaseMessaging`, `flutter_local_notifications`
- `getIdTokenResult`, `authStateChanges`
- `collection(this.collectionName)`
- The Q8 collection names, and in Q5 every collection except `users` and `scheduled_messages`