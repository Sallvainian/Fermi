Digest for commit 7808a91. Seven of the nine claims are verified as written. Ref [29] is verified but its citation misses one route. Ref [31] is disputed: its field list is right, but the "chatRooms" part is not supported by the code.

ref=[28] `lib/features/dashboard/data/services/dashboard_service.dart:173-179 (getRecentGrades) @ 7808a91` — **verified**. It queries top-level `grades` with `studentId ==`, `isGraded == true`, ordered by `gradedAt` descending. The original range 174-194 also ran into `calculateGPA` (lines 191-195), which applies the same `isGraded == true` filter.

ref=[29] `lib/shared/routing/app_router.dart:374-418, 574-581 (AppRouter) @ 7808a91` — **verified**, with the citation widened. The four routes in the cited range build `FlyerChatScreen(conversationId: chatRoomId)`: `/messages/:chatRoomId`, `/chat/:chatRoomId`, `/simple-chat/:chatRoomId` and `/chat/simple/:chatRoomId`. A fifth route, `/student/messages/:chatRoomId` at lines 574-581, does the same but was missing from the citation. The other chat routes (`/messages`, `/student/messages`, `select-user`, `user-selection`, `group-creation`, `class-selection`) take no id. On `/chat/simple/:chatRoomId`, a missing id falls back to `'default'`.

ref=[30] `functions/src/chatFunctions.ts:86-96 (sendMessage) @ 7808a91` — **verified**. The message object has exactly these fields: `id`, `authorId`, `authorName`, `authorRole`, `text`, `attachments`, `createdAt`, `sentAt`, `metadata`. It is written to `conversationRef.collection("messages").doc(message.id)` at lines 99-102.

ref=[31] `lib/features/chat/domain/models/message.dart:175-193 (Message) @ 7808a91` — **disputed**.
- **Borne out:** `toFirestore` writes `senderId`, `senderName`, `senderRole`, `content`, `timestamp`, `isRead`, `attachmentUrl`, `attachmentType`, `scheduledFor`, `isScheduled`, `status`, `isEdited` and `editedAt`.
- **Not borne out:** the cited lines never mention chatRooms.
  - The only caller of `toFirestore` in `lib/features/chat` embeds the result under `scheduled_messages/{id}.message`, at `lib/features/chat/data/services/scheduled_messages_service.dart:111-117 (scheduleMessage) @ 7808a91`.
  - Nothing in `lib` or `functions/src` reads `scheduled_messages` back and delivers it into `chatRooms/{id}/messages`.
  - `chatRooms/{id}/messages` is only read raw, ordered by `timestamp`, at `lib/features/chat/presentation/providers/chat_provider.dart:60-73 (loadChatMessages) @ 7808a91`.

ref=[32] `functions/src/behaviorPoints.ts:445-461 (getBehaviorHistory) @ 7808a91` — **verified**. The start and end dates filter on `timestamp` (lines 448 and 456) and the query orders by `awardedAt` descending (line 461). Both apply to the `history` collection group. Combining a range filter on one field with an order on another normally needs Firestore to order by the range field first.

ref=[33] `lib/features/games/presentation/providers/jeopardy_provider.dart:6-149 (SimpleJeopardyProvider) @ 7808a91` — **verified**. It uses only `FirebaseAuth` and has no Firestore import; every method is a stub. This copy is the one wired in, through the import at `lib/shared/core/app_providers.dart:17` and the `create:` at line 66, and the games screens import it too. A second class with the same name at `lib/features/jeopardy/presentation/providers/jeopardy_provider.dart` does use Firestore (`jeopardy_games`, `jeopardy_questions`, `jeopardy_sessions`), but nothing imports it.

ref=[34] `lib/features/behavior_points/data/models/behavior_history_entry.dart:54-66 (BehaviorHistoryEntry) @ 7808a91` — **verified**. It handles null (returns now), `Timestamp`, `DateTime`, and a Map with `_seconds` (plus optional `_nanoseconds`). Anything else returns `DateTime.now()`. An ISO string or epoch int would therefore silently become the current time.

ref=[35] `functions/src/adminFunctions.ts:51-61 (createStudentAccount) @ 7808a91` — **verified**. With no `request.auth` it throws `unauthenticated`. Otherwise it reads `users/{request.auth.uid}` and throws `permission-denied` unless `role === "admin"`. `resetUserPassword` repeats the same gate at lines 474-484.

ref=[36] `functions/src/adminFunctions.ts:470-529 (resetUserPassword) @ 7808a91` — **verified**. It calls `generateSecurePassword(12)`, then `auth.updateUser(userId, {password})`, and returns `{success: true, newPassword, message}`. It also adds a `password_reset` document to `activities`.