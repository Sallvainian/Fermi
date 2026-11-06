## Where the answers meet

These are methods and fields that the answers to more than one question pass through, with the checks in each that reject a call or throw. Every line repeats a claim already cited in a question section above.

- **The `users/{uid}.role` lookup.** Questions 1, 2, 3, 9 and 10 all depend on it.
  - In the rules, `getUserRole` reads it with `get()`, and `isTheTeacher`, `isStudent` and `isAdmin` each also require a matching email domain. `firestore.rules:43-46 (getUserRole) @ 7808a91`
  - The admin callables throw `unauthenticated` or `permission-denied` from this field. `functions/src/adminFunctions.ts:51-61 (createStudentAccount) @ 7808a91`
  - The behavior-points callables require role teacher and class ownership. `functions/src/behaviorPoints.ts:31-77 (awardBehaviorPoints) @ 7808a91`
  - The client signs the user out when the role is null. `lib/features/auth/providers/auth_provider.dart:140-187 (AuthProvider) @ 7808a91`
  - `syncUserRole` copies it into the claim only for teacher or student. `functions/src/customClaims.ts:106-114 (syncUserRole) @ 7808a91`
- **`ensureConversationMembership`.** Questions 4, 7 and 10 depend on it. It throws `not-found` when the conversation is missing and `permission-denied` when the caller is not a participant. The callable's catch then rewrites both as `internal`. `functions/src/chatFunctions.ts:13-34 (ensureConversationMembership) @ 7808a91` and `functions/src/chatFunctions.ts:132-137 (sendMessage) @ 7808a91`
- **`uploadChatFile`.** Questions 4, 10 and 12 depend on it.
  - It rejects a declared `fileSize` over 10 MB. `functions/src/chatFunctions.ts:309-314 (uploadChatFile) @ 7808a91`
  - It rejects a MIME type outside its allow-list. `functions/src/chatFunctions.ts:317-331 (uploadChatFile) @ 7808a91`
  - The client sends `image/jpg` for `.jpg` files. `lib/features/chat/data/controllers/firestore_chat_controller.dart:387 (FirestoreChatController) @ 7808a91`
- **`sendPushNotifications` and `_saveFCMToken`.** Questions 5, 10 and 11 depend on them.
  - The sender reads only `users/{id}.fcmToken` and swallows errors. `functions/src/chatFunctions.ts:386-428 (sendPushNotifications) @ 7808a91`
  - The client writes both `users.fcmToken` and `fcm_tokens/{uid}`, and does nothing when no user is signed in. `lib/features/notifications/data/services/firebase_messaging_service.dart:235-263 (_saveFCMToken) @ 7808a91`
- **`getBehaviorHistory`.** Questions 8, 10 and 12 depend on it.
  - It rejects a missing `classId`, and rejects a teacher who does not own the class. `functions/src/behaviorPoints.ts:394-422 (getBehaviorHistory) @ 7808a91`
  - It filters the date range on `timestamp` and orders by `awardedAt`. `functions/src/behaviorPoints.ts:445-461 (getBehaviorHistory) @ 7808a91`
  - The client sends `studentName`, which the server ignores. `functions/src/behaviorPoints.ts:367-433 (getBehaviorHistory) @ 7808a91`
- **`FirestoreRateLimiter`.** Questions 8, 9 and 10 depend on it. It throws when `count >= maxCalls` and lets the request through on any other error. `applyRateLimit` turns the throw into `resource-exhausted`. `functions/src/rate-limiter.ts:15-88 (FirestoreRateLimiter) @ 7808a91` and `functions/src/security.ts:38-51 (applyRateLimit) @ 7808a91`
