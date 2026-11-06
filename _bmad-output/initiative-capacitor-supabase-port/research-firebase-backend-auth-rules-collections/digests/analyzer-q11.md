Push notifications only partly work at 7808a91. Android and iOS register for FCM. Web never does and uses an in-app SnackBar instead. No code anywhere shows a local notification. Tapping a push does nothing, because no code installs the navigation callback.

**Registration (which platforms set up messaging)**
- **Load-bearing:** `AppInitializer._initializeDeferredServices` runs after the first frame and only if Firebase came up (`lib/shared/core/app_initializer.dart:54-74 (_initializeDeferredServices) @ 7808a91`). It always adds `_initializeNotifications`. It adds `_initializeFirebaseMessaging` only when `!kIsWeb && _isFirebaseMessagingSupported()`, which is true only for Android and iOS (`:77-89 (_isFirebaseMessagingSupported)`).
- Web is blocked a second and third time: `_initializeFirebaseMessaging` returns early on web (`:227-230`), and `FirebaseMessagingService.initialize` starts with `if (kIsWeb) return` (`lib/features/notifications/data/services/firebase_messaging_service.dart:46 (initialize) @ 7808a91`). The web VAPID-key branch in `_updateFCMToken` (`:153-217`) and `getCurrentToken` (`:359-388`) can never run.
- `initialize` runs these steps in order (`:45-107 (initialize)`):
  1. `deleteToken()` at :52, so every launch forces a new token.
  2. `_requestPermissions` at :59.
  3. Registers the background handler at :62, the `onMessage` listener at :67 and the `onMessageOpenedApp` listener at :72.
  4. Checks `getInitialMessage` at :77-80.
  5. Sets iOS foreground presentation to alert, badge and sound at :83-87.
  6. Fetches and saves the token via `_updateFCMToken` at :90.
  7. Listens on `onTokenRefresh` with `_saveFCMToken` at :93.
  Any exception is caught and only logged (:100-106).
- Permission prompts:
  - On iOS and macOS, FCM calls `requestPermission` (`:124-146 (_requestPermissions)`). On Android it requests nothing; the comment says permissions are "handled at runtime" (:145).
  - Separately, on non-web `NotificationService.requestPermissions()` is called (`app_initializer.dart:200-202`). That goes to `requestNotificationsPermission()` on Android and to the iOS plugin's `requestPermissions` on iOS and macOS (`lib/features/notifications/data/services/notification_service.dart:63-96 (requestPermissions) @ 7808a91`).
  - `DarwinInitializationSettings` also sets `requestAlertPermission/Badge/Sound: true` (`:328-339`).
  - So iOS has three separate permission requests, all running in parallel through `Future.wait`.
- **Load-bearing (token storage):** `_saveFCMToken` (`firebase_messaging_service.dart:235-263`) does nothing if `_auth.currentUser` is null (:237). Otherwise it does two writes:
  - `users/{uid}.update({fcmToken, fcmTokenUpdatedAt, platform})` (:241-245). This is an `update`, so it throws, and the error is logged, if the user document doesn't exist.
  - `fcm_tokens/{uid}.set({token, userId, platform, updatedAt})` (:248-253). This is one token per user, and the last device overwrites it.
- Neither auth flow saves the token: `_updateFCMToken` is called only from `initialize` (:90), and `initialize` is called only from `app_initializer.dart:233-234`. If no one is signed in when the deferred init runs, the token is never saved until `onTokenRefresh` fires.
- `deleteToken()` (`:400-423`) removes both fields and the `fcm_tokens` document, but nothing in `lib` calls it (grep for `deleteToken` at 7808a91). Logout leaves the stale token behind.

**Receiving messages**
- Server sender: `sendPushNotifications` (`functions/src/chatFunctions.ts:386-425 @ 7808a91`) reads only `users/{id}.fcmToken`. It never reads `fcm_tokens`. It sends `notification{title: senderName, body ≤100 chars}` plus `data{type:"chat", conversationId}` through `sendEachForMulticast`, and it's called at `:129` after a message is written. I did not check whether the Flutter chat client actually goes through that callable path.
- Background and terminated: `_firebaseMessagingBackgroundHandler` only logs (`firebase_messaging_service.dart:13-18`). Display is left to the OS, from the `notification` block of the payload.
- Foreground (`:277-320 (_handleForegroundMessage)`):
  1. Calls `onMessage?.call` (:284). I found nothing in `lib` that assigns `onMessage`.
  2. For chat messages, it returns without displaying anything when `_activeConversationId == conversationId` (:290-296) or when the current route contains the id (:298-305). `_currentRouteResolver` is never set, so in practice only the first check applies.
  3. Otherwise it calls `NotificationService().sendImmediateNotification(...)` (:309-318).
- How the chat screen suppresses alerts: `FlyerChatScreen` calls `markConversationActive(_actualConversationId)` after building the controller (`lib/features/chat/presentation/screens/flyer_chat_screen.dart:78 @ 7808a91`) and `markConversationActive(null)` in `dispose` (:148). That sets `_activeConversationId` (`firebase_messaging_service.dart:119-121`).
- Opened from a notification (`:323-356 (_handleMessageOpenedApp)`): chat goes to `/messages/chat/$conversationId` only if `_navigationCallback != null` (:333). The `assignment`, `grade` and `behavior` types use `_navigationCallback?.call` (:346-355).
  - **Load-bearing:** `setNavigationCallback` (:110-116) has no callers in `lib` (grep for `setNavigationCallback` at 7808a91). Every tap-to-open path does nothing.

**What gets displayed**
- **Load-bearing:** `flutter_local_notifications` is set up but never used to display anything.
  - It is instantiated at `notification_service.dart:24-25`. `_initializeLocalNotifications` (`:323-383`) calls `initialize(...)` with `onDidReceiveNotificationResponse: _onNotificationResponse`. On Android it creates channel `teacher_dashboard_calls` ("Incoming Calls", `Importance.max`) at :366-382.
  - I confirmed there is no `.show(` and no `zonedSchedule` call anywhere in the repo (grep at 7808a91).
- `sendImmediateNotification` (`:250-267`), `scheduleEventReminder` (`:218-231`) and `scheduleAssignmentReminder` (`:234-247`) are stubs. Each only logs and calls `_storeNotificationRecord`, which writes `notifications.add({type, title, message, relatedId, scheduledFor, createdAt, status:'scheduled'})` (`:295-319`). That document has no `userId`, no `read` and no `body` field.
- `cancelNotification`, `cancelAllNotifications` and `getPendingNotifications` are log-only stubs (`:270-292`).
- `_onNotificationResponse` (`:385-422`) only logs. It would never be triggered, since nothing is ever shown.
- What the user actually sees:
  - Android or iOS, app in background or closed: the OS-drawn FCM notification.
  - iOS, app in foreground: the system banner from `setForegroundNotificationPresentationOptions`, which fires even when the user is in that conversation, because the suppression above only skips the Firestore write.
  - Android, app in foreground: nothing on screen, just a Firestore `notifications` document.

**Web in-app path (a second, independent mechanism)**
- `AuthProvider._startNotificationsIfNeeded` runs on successful auth (`lib/features/auth/providers/auth_provider.dart:175, :566-570 @ 7808a91`) and calls `WebInAppNotificationService.instance.startListening` on web only.
- The service listens to `notifications where userId==uid && read==false orderBy createdAt desc limit 20` (`lib/features/notifications/data/services/web_in_app_notification_service.dart:46-85 (startWebInAppNotifications) @ 7808a91`). For each document added it calls `onNotificationReceived(title, body, data)` and then marks it `delivered` (:114-127).
- `WebNotificationHandler` wraps `MaterialApp.router` (`lib/main.dart:249 @ 7808a91`). On web it sets `onNotificationReceived` to show a floating `SnackBar` for 4 seconds with a Dismiss button (`lib/shared/widgets/web_notification_handler.dart:27-61`).
- The records written by `_storeNotificationRecord` don't fit this query, because they lack `userId` and `read`. So the two paths never connect. Besides `createTestNotification` (`:130-162`, which has no callers), the only other writer to `notifications` is `lib/features/notifications/data/services/firebase_notification_service.dart:11`, which I did not read.
- Web browser permission goes through a conditional import (`notification_service.dart:12-14`): `notification_service_web.dart:7-41` wraps `web.Notification.permission/requestPermission`, and `notification_service_stub.dart:2-6` returns `false`/`'denied'`. It is never actually reached, because `requestPermissions` is skipped on web (`app_initializer.dart:200`).

**Platform configuration**
- iOS: `UIBackgroundModes` includes `remote-notification` (`ios/Runner/Info.plist:39-44 @ 7808a91`). `aps-environment` is `development` (`ios/Runner/Runner.entitlements:5-6`), and the time-sensitive notifications entitlement is set (:27-28).
- Android: the manifest has no `POST_NOTIFICATIONS` permission, no FCM default-channel or icon meta-data, and no messaging service (`android/app/src/main/AndroidManifest.xml:1-50 @ 7808a91`; grep for `POST_NOTIFICATIONS|default_notification_channel` found nothing). Whether plugin manifests merge in `POST_NOTIFICATIONS` is UNVERIFIED.
- Web: there is no `firebase-messaging-sw.js` (`git ls-tree web` at 7808a91), and `web/index.html:65-85` unregisters every service worker and clears caches.

**Searched for and not found (grep at 7808a91)**
- Callers of `setNavigationCallback`, `deleteToken`, `createTestNotification` or `scheduleEventReminder`.
- Any assignment to `FirebaseMessagingService.onMessage`.
- Any `.show(` or `zonedSchedule`.
- `POST_NOTIFICATIONS`, `default_notification_channel` or `firebase-messaging-sw`.
- The only caller of `scheduleAssignmentReminder` is `lib/features/assignments/data/services/assignment_service.dart:39`, which I did not open.

**Budget**
I read all 15 files the budget allowed (the 15 named above, through `web/index.html`). Not read:
- `firebase_notification_service.dart` and `notification_provider.dart`, which hold the other `notifications` reader and writer.
- `firestore_chat_controller.dart`, which would show whether sending a chat message reaches the callable that triggers `sendPushNotifications`.
- The rest of `app_initializer.dart:1-39`.