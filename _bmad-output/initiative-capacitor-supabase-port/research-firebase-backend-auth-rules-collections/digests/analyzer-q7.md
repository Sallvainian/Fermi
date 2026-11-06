Each collection's shape is defined in one of three ways: a Dart model with `fromFirestore`/`toFirestore`, a raw map literal at the write site, or a Cloud Function's object literal. The two chat systems store messages under different field names. All chat routes open `FlyerChatScreen`, so only the `conversations` system shows messages, and the chat list hands `chatRooms` IDs to it. All citations are @ 7808a91.

## Chat: two systems

**Which screens use which (load-bearing):**
- **`chatRooms`** goes through `SimpleChatProvider` (`lib/features/chat/presentation/providers/chat_provider.dart:8`), registered at `lib/shared/core/app_providers.dart:47`. It is used by:
  - `chat_list_screen.dart:29` (`initializeChatRooms`) and `:347` (`deleteChatRoom`)
  - `user_selection_screen.dart:88` (`createOrGetDirectChat`)
  - `group_creation_screen.dart:110` and `class_selection_screen.dart:122` (`createGroupChat`)
  - `user_list.dart:68`
- **`conversations`** goes through `FlyerChatScreen` → `FirestoreChatController` (`flyer_chat_screen.dart:75`).
- **The crossover:** every chat route builds `FlyerChatScreen(conversationId: chatRoomId)`. The routes are `app_router.dart:374-386` `/messages/:id`, `:388-395` `/chat/:id`, `:398-407` `/simple-chat/:id`, `:410-418` `/chat/simple/:id`, and `:574-581` `/student/messages/:id`.
  - So `chatRooms` IDs from `chat_list_screen.dart:291`, `user_list.dart:89` and `user_selection_screen.dart:95` are opened as `conversations/{chatRoomId}`.
  - `SimpleChatProvider.loadChatMessages` and `sendMessage` have no callers outside `chat_provider.dart`, found by grep over `lib`.
  - If the conversation doc is missing, `_ensureConversationExists` (`firestore_chat_controller.dart:65-73`) creates it with participants set to `conversationId.split('_')`.

**Field-name disagreements (load-bearing):**

| Field | chatRooms system | conversations system |
|---|---|---|
| message sender | `senderId` (`message.dart:177`, `chat_provider.dart:156`) | `authorId` (`chatFunctions.ts:88`, read at `firestore_chat_controller.dart:202,216,232`) |
| message time | `timestamp` (`message.dart:181`, ordered by at `chat_provider.dart:64`) | `createdAt` (`chatFunctions.ts:93`, ordered by at `firestore_chat_controller.dart:97,132,520`) |
| message body | `content` (and also `text` at `chat_provider.dart:154-155`) | `text` plus `attachments[]` (`chatFunctions.ts:91-92`) |
| parent members | `participantIds` (`chat_room.dart:101,140`) | both `participants` and `participantIds` are written (`flyer_chat_screen.dart:115-116`, `firestore_chat_controller.dart:68-69`); the server reads `participants ?? participantIds` (`chatFunctions.ts:24`) |
| `lastMessage` | a string (`chat_room.dart:142`, `chat_provider.dart:177`) | a map `{text, authorId, authorName, createdAt}` (`chatFunctions.ts:106-111`) |
| unread | `unreadCounts` map plus `unreadCount` int (`chat_room.dart:147-148`) | an `unreadCount.{uid}` map (`chatFunctions.ts:113,121,189`) |
| last activity | `lastMessageTime` | `lastActivity` (`chatFunctions.ts:112`); `lastMessageTime: null` only at create (`flyer_chat_screen.dart:120`) |

### chatRooms
- **Shape (load-bearing):** `ChatRoom.fromFirestore` at `lib/features/chat/domain/models/chat_room.dart:95-126` and `ChatRoom.toFirestore` at `:136-155`.
  - Fields: `name, type, participantIds, participants[], lastMessage, lastMessageTime, lastMessageSenderId, unreadCount, unreadCounts, classId, createdAt, updatedAt, createdBy, mutedUsers`.
  - `ParticipantInfo.fromMap` (`:281-288`) and `ParticipantInfo.toMap` (`:296-298`) give `{id, name, role, photoUrl}`.
  - `ChatRoom.fromFirestore` has no callers in `lib`. The provider reads and writes raw maps.
- **Write-site shapes:**
  - `chat_provider.dart:115-123`, direct chat: `name, type, participantIds, createdAt, lastMessageTime, lastMessage, mutedUsers`.
  - `chat_provider.dart:303-316`, group chat: adds `participants, classId, createdBy, unreadCount, unreadCounts`.
  - `chat_provider.dart:193`, mark-read: `lastReadTime`, which is not in the model.
- **Indexes:**
  - `firestore.indexes.json:290`: `chatRooms` on `participantIds CONTAINS, lastMessageTime DESC`.
  - Legacy `chat_rooms` at `:254` (`participantIds`, `lastMessageTime`) and `:272` (`participantIds`, `updatedAt`). No code references `chat_rooms`.
- **Call sites** (all in `chat_provider.dart` unless noted):
  - `chatRooms`, read: `:34-38` (`initializeChatRooms`, stream filtered on `participantIds` and ordered by `lastMessageTime`), `:98-102` (`createOrGetDirectChat`), `:210-213` (`getChatRoom`); also `user_list.dart:67-71`.
  - `chatRooms`, create: `:125` and `:318` (`createGroupChat`).
  - `chatRooms/{id}`, update: `:173-180` (`sendMessage` last-message fields), `:192-194` (`markMessagesAsRead`), `:234-236` (`leaveChatRoom`, removes from `participantIds`).
  - `chatRooms/{id}`, delete: `:270` (`deleteChatRoom`).

### conversations
- **Shape:** no model class. The document ID is the two user IDs, sorted and joined with `_` (`flyer_chat_screen.dart:102-103`).
  - Create shapes: `flyer_chat_screen.dart:114-122` and `firestore_chat_controller.dart:67-73`.
  - Server updates: `chatFunctions.ts:105-114,125,188-190`.
- **Indexes:** none for `conversations`.
- **Call sites:**
  - `conversations/{id}`, read: `flyer_chat_screen.dart:107-110`, `firestore_chat_controller.dart:54-57`, `chatFunctions.ts:13-14` (`ensureConversationMembership`).
  - `conversations/{id}`, set: `flyer_chat_screen.dart:114`, `firestore_chat_controller.dart:67`.
  - `conversations/{id}`, update: `chatFunctions.ts:105,125` (`sendMessage`), `:188` (`markMessagesAsRead`).
  - `chatFunctions.ts:87` only generates an ID; it writes nothing.

### messages
- **Shape A, the domain model for `chatRooms` (load-bearing):** `Message.fromFirestore` at `lib/features/chat/domain/models/message.dart:91-121`, `Message.fromMap` at `:136-164`, `Message.toFirestore` at `:175-193`.
  - Fields: `senderId, senderName, senderRole, content, timestamp, isRead, attachmentUrl, attachmentType, scheduledFor, isScheduled, status, isEdited, editedAt`.
  - `Message.fromFirestore` has no callers. `fromMap` is called only at `scheduled_messages_service.dart:326`.
  - The provider's raw write at `chat_provider.dart:153-164` also adds `text` and `imageUrl`.
- **Shape B, for `conversations` (load-bearing):** the object literal at `functions/src/chatFunctions.ts:86-96`: `id, authorId, authorName, authorRole, text, attachments, createdAt, sentAt, metadata`.
  - `markMessagesAsRead` adds `seenAt` and `readBy.{uid}` (`:181-184`).
  - Reader: `_convertToFlyerMessage` at `firestore_chat_controller.dart:175-243` reads `sentAt, seenAt, failedAt, attachments[0].{type,url,name,size}, authorId, createdAt, text, metadata`.
- **Embedded copy:** `scheduled_messages/{id}.message` holds `Message.toFirestore` (`scheduled_messages_service.dart:111-117`). No function in `functions/src` references `scheduled_messages`.
- **Indexes:** `firestore.indexes.json:802` and `:838` on `conversationId ASC, timestamp DESC`; `:820` and `:856` on `senderId ASC, timestamp DESC`. They come in COLLECTION_GROUP and COLLECTION pairs.
  - Neither message shape has a `conversationId` field.
  - No index covers `createdAt`.
- **Call sites:**
  - `chatRooms/{id}/messages`: read `chat_provider.dart:60-66` (stream, `timestamp` DESC, limit 100); create `:166-170`; read then batch-delete `:256-267`.
  - `conversations/{id}/messages`: read `firestore_chat_controller.dart:93-99` (limit 30), `:128-133` (stream), `:516-523` (paging); set `chatFunctions.ts:99-102`; batch update `:177-184`.
  - The client writes `conversations` messages only through callables: `sendMessage` (`firestore_chat_controller.dart:323`) and `markMessagesAsRead` (`:547`).

### typing
- **Shape:** `{isTyping, startedAt, userName}` at `chatFunctions.ts:242-246`. The document ID is the user's ID (`:238`). No model class and no index.
- **Call sites, all on `conversations/{id}/typing/{uid}`:**
  - Read: stream at `firestore_chat_controller.dart:248-252`, reading `isTyping` and `userName` (`:279-280`).
  - Writes: set at `chatFunctions.ts:242`, delete at `:256` (11s cleanup) and `:265`.
  - The client reaches it through the `updateTypingStatus` callable (`firestore_chat_controller.dart:292`).

## Discussions

### discussion_boards
- **Shape (load-bearing):** `SimpleDiscussionBoard.fromFirestore` at `lib/features/discussions/presentation/providers/discussion_provider.dart:36-48` and `SimpleDiscussionBoard.toFirestore` at `:50-60`. Fields: `title, description, createdBy, createdAt, threadCount, isPinned, tags`.
- **Indexes:** `firestore.indexes.json:424` on `isPinned DESC, createdAt DESC`; `:442` on `isPinned DESC, updatedAt DESC`. The model has no `updatedAt`.
- **Call sites:**
  - Read: stream at `discussion_provider.dart:329-333`, ordered by `isPinned` then `createdAt`.
  - Create: `:452`.
  - Update `threadCount`: `+1` at `:580-582`, `-1` at `discussion_board_detail_screen.dart:441-444`.
  - Delete: `discussion_boards_screen.dart:356-359`. This removes only the board document.

### threads (`discussion_boards/{b}/threads`)
- **Shape (load-bearing):** `SimpleDiscussionThread.fromFirestore` at `discussion_provider.dart:93-108` and `SimpleDiscussionThread.toFirestore` at `:110-123`.
  - Fields: `boardId, title, content, authorId, authorName, createdAt, replyCount, likeCount, isPinned, isLocked`.
  - `isLikedByCurrentUser` is computed, not stored (`:655`).
- **Indexes:** `firestore.indexes.json:1084` (COLLECTION_GROUP, `isPinned`, `updatedAt`); `:1102` (`isPinned`, `createdAt`); `:1120` (`isPinned`, `updatedAt`).
- **Call sites:**
  - Read: stream at `discussion_provider.dart:473-479`; get at `thread_detail_screen.dart:42-47`.
  - Create: `discussion_provider.dart:573-577`.
  - Update `replyCount`: `+1` at `thread_detail_screen.dart:137-142`, `-1` at `:521-526`.
  - Update `likeCount`: `±1` at `discussion_board_detail_screen.dart:295-306`.
  - Delete: `discussion_board_detail_screen.dart:433-438`. Its `replies` and `likes` subcollections are not deleted.

### replies (`.../threads/{t}/replies`)
- **Shape:** no model class. The write map at `thread_detail_screen.dart:129-134` is `{content, authorId, authorName, createdAt}`.
  - `likeCount` is read (`:432`) and incremented (`:480,491`) but is not set at create.
  - The UI reads `authorId, authorName, content, createdAt, id, likeCount`.
- **Indexes:** none.
- **Call sites:**
  - Read: get at `:56-63` and stream at `:75-83`, both ordered by `createdAt`.
  - Create: `:123-134`.
  - Update `likeCount`: `:480`, `:491`.
  - Delete: `:511-518`. Its `likes` subcollection is not deleted.

### likes
- **Shape:** `{userId, likedAt}`, written in two places (two patterns): `discussion_board_detail_screen.dart:300-303` and `thread_detail_screen.dart:487-490`. The document ID is the user's ID. No model class and no index.
- **Call sites:**
  - `threads/{t}/likes/{uid}`: read `discussion_provider.dart:633-640` and `discussion_board_detail_screen.dart:287-290`; delete `:294`; set `:300`.
  - `replies/{r}/likes/{uid}`: read `thread_detail_screen.dart:441-450`; delete `:479`; set `:487`.

## What was searched and not covered
- **Search:** `git grep` @ 7808a91 over `lib`, `functions/src` and `firestore.indexes.json` for `collection(...)` / `collectionGroup(...)` with each name and `chat_rooms`. I also searched quoted name literals outside those calls (only navigation IDs matched) and variable-argument `.collection(...)` calls (`rate-limiter.ts:34`, `firestore_repository.dart:145`, `firestore_service.dart:52`). None of them targets these collections by literal.
- **No `fieldOverrides`** in `firestore.indexes.json` mention these collections.
- **Budget:** I opened 16 files, one over the cap of 15. Not read: `firestore.rules`, which may hold field validation, and `chat_list_screen.dart`, which reads the `chatRooms` map fields (I only grepped it).