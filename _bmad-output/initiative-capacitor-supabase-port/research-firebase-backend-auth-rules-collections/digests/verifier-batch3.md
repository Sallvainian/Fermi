Eight of the nine claims are verified and one is disputed (ref [20]); none are overturned. I read everything with `git show` and `git grep` at 7808a91 and left out the excluded paths.

ref=[19] lib/shared/screens/settings_screen.dart:1029-1038 (_uploadProfilePicture) @ 7808a91 — **verified**. The reference is `users/{user.uid}/profile/avatar.jpg`, uploaded with `putFile(File(image.path))`. For context, storage.rules:22-25 (`match /users/{userId}/profile/{fileName}`) allows this write for the owner.

ref=[20] functions/src/chatFunctions.ts:339-357 (uploadChatFile) @ 7808a91 — **disputed**. Two parts are borne out:
- The path is `chat-attachments/${conversationId}/${userId}/${timestamp}_${sanitizedFileName}` (line 339).
- It is written with the Admin SDK through `bucket.file(filePath).save(...)` (lines 345-357).

The other part is wrong: a rules block does match the path. storage.rules:40-42, `match /{document=**} { allow read, write: if false; }`, is the default deny and covers it. What is true is that no *allow* block covers `chat-attachments/` (the only allow blocks are `chat_images`, `chat_videos`, `users/{userId}/...` and `public`). Client access to these files is therefore denied, and only the Admin SDK and the signed URL (line 360) reach them.

ref=[21] functions/src/chatFunctions.ts:397-399 (sendPushNotifications) @ 7808a91 — **verified**. It reads `db.collection("users").doc(participantId)` and pushes `data().fcmToken`. Nothing in the function reads `fcm_tokens`. For context, the client writes both places: `users/{uid}.fcmToken` and `fcm_tokens/{uid}.token` (lib/features/notifications/data/services/firebase_messaging_service.dart:241-253, _saveFCMToken @ 7808a91).

ref=[22] lib/features/notifications/data/services/web_in_app_notification_service.dart:46-66 (startWebInAppNotifications) @ 7808a91 — **verified**. The query is `notifications` where `userId == uid` and `read == false`. It also orders by `createdAt` descending and limits to 20, which the claim leaves out. It reads `title`, `body` and `data` (lines 61-63). I tightened the range: the original 46-149 also took in `_markAsDelivered` and `createTestNotification`.

ref=[23] lib/features/student/data/services/presence_service.dart:151-173 (_buildPresenceData) @ 7808a91 — **verified**. The keys are `online`, `lastSeen` (serverTimestamp), `uid`, `displayName`, `photoURL`, `role`, `isAnonymous` and `metadata`. The data goes to the Firestore `presence` collection (line 92 `_firestore.collection('presence').doc(user.uid)`). `displayName`, `photoURL` and `role` depend on privacy settings, and `metadata` holds `{platform, version}`.

ref=[24] lib/features/chat/presentation/screens/class_selection_screen.dart:117 (_createOrJoinClassChat) @ 7808a91 — **verified**. Line 117 reads `'photoUrl': data['photoUrl']` from `users` documents. The `users` writers all use `photoURL`:
- auth_service.dart:400 and 583
- username_auth_service.dart:262 and 337
- auth_provider.dart:709 (updateProfilePicture)

Only `UserModel.fromMap` (user_model.dart:133) falls back to `photoUrl`.

ref=[25] lib/features/chat/presentation/screens/class_selection_screen.dart:52 (_loadClasses) @ 7808a91 — **verified**. Line 52 is `.where('students', arrayContains: userId)`. The same file also uses `students` at lines 62 and 99. Elsewhere the model and writers use `studentIds`: class_model.dart:173 and 225, class_service.dart:194 and 232, and class_provider.dart:394, 437 and 480. I re-anchored the symbol from the class `_ClassSelectionScreenState` to its method `_loadClasses`. For context, grade_analytics_service.dart:35 also reads `students`.

ref=[26] lib/features/grades/data/services/grade_analytics_service.dart:67-71 (generateClassAnalytics) @ 7808a91 — **verified**. The code is `submissionDoc.reference.collection('grades').orderBy('gradedAt', descending: true).limit(1).get()`. I re-anchored the symbol from the class `GradeAnalyticsService` to its method `generateClassAnalytics`.

ref=[27] lib/features/grades/presentation/providers/grade_provider.dart:135-145 (gradeSubmission) @ 7808a91 — **verified**. It calls `submissions/{submissionId}.update({'grade': {...}})` with a nested map holding `points`, `maxPoints`, `percentage`, `letter`, `feedback`, `gradedAt` (serverTimestamp) and `gradedBy` (the current uid).

One point for whoever compares ref [26] with ref [27]: the analytics service reads a `grades` subcollection, but `gradeSubmission` writes a nested `grade` field on the submission and never writes such a subcollection.