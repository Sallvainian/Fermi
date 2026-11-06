# Brief

Repository commit: 7808a91cfc090824a3501648e54d466f50689675 (short: 7808a91)
File budget per question: 15 files. History budget: 10 commits.
Validation: normal.
Paths left out of every search (relative to repository root): `_bmad-output/`, `_bmad/`, `.agents/`, `.claude/`, `docs/`, `functions/cloudflare-email-worker.js`, `src/`, `wrangler.toml`.

## Questions

1. (how) How does the client start Firebase and sign users in? Cover `lib/firebase_options.dart`, `lib/shared/core/service_locator.dart`, `lib/shared/core/app_initializer.dart` (including what it initializes for Realtime Database and Messaging), each sign-in flow in `lib/features/auth` (email/password, username, Google, the desktop OAuth handlers), how auth state is exposed to the rest of the app, and how the client reads the user's role.
2. (how) How are role claims assigned and changed on the server? Cover `functions/src/authBlocking.ts`, `functions/src/customClaims.ts`, `functions/src/config/domainRoles.ts`, `functions/src/migrate-user-roles.ts`, `functions/src/migrate-user-roles-cloud.ts`, and the client's `lib/shared/utils/set_user_role_claims.dart` and `lib/shared/utils/run_migration.dart`: what triggers each and what each writes.
3. (how) How does `firestore.rules` decide read and write access for each match path: helper functions, claim/role checks, ownership and membership checks, and field-level validation?
4. (how) How does `storage.rules` decide access, and which Storage paths does the client read or write?
5. (where) Where is the document shape of each of these Firestore collections defined (model classes, serializers, `firestore.indexes.json`), and which files read or write each: `users`, `public_usernames`, `presence`, `fcm_tokens`, `notifications`, `scheduled_messages`, `bug_reports`? Also resolve the call sites that pass a collection name as a variable (`collection(this.collectionName)`, `collection(path)`, `collection(collectionPath)`).
6. (where) Same as 5 for: `classes`, `students`, `assignments`, `submissions`, `grades` (including `collectionGroup('grades')`), `calendar_events`.
7. (where) Same as 5 for: `chatRooms`, `conversations`, `messages`, `typing`, `discussion_boards`, `threads`, `replies`, `likes`.
8. (where) Same as 5 for: `studentPoints`, `behaviors`, `history` (including the `collectionGroup('history')` queries), `activities`, `jeopardy_games`, `jeopardy_sessions`, `jeopardy_questions`, `oauth_pkce_challenges`, `_rate_limits`.
9. (how) What does each exported function in `functions/src/adminFunctions.ts`, `functions/src/bulkImport.ts`, `functions/src/oauth.ts` and `functions/src/cleanup.ts` do, what triggers it (callable, HTTP, schedule, Firestore event, auth event), and which collections and Admin SDK APIs does it touch?
10. (how) Same as 9 for `functions/src/chatFunctions.ts`, `functions/src/behaviorPoints.ts`, `functions/src/security.ts`, `functions/src/rate-limiter.ts` and `functions/src/migrate-usernames.ts`, including which of their functions are or are not exported from `functions/src/index.ts`.
11. (how) How does the client register for, receive and display push notifications? Cover `lib/features/notifications/data/services/firebase_messaging_service.dart`, `lib/shared/core/app_initializer.dart`, `lib/features/chat/presentation/screens/flyer_chat_screen.dart`, and `flutter_local_notifications` usage.
12. (where) Which client files call Cloud Functions callables, and which function does each call with what arguments? (Files using `FirebaseFunctions` / `httpsCallable`.)
13. (how) How are the client auth code, `firestore.rules`, `storage.rules` and the Cloud Functions tested: `test/`, any tests under `functions/`, and the emulator configuration in `firebase.json`?
