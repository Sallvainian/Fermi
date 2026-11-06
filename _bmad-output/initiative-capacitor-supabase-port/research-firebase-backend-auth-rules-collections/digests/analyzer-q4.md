`storage.rules` checks two things only: whether the caller is signed in, and, under `/users/{userId}/**`, whether the caller's uid matches `{userId}`. It has no size, content-type, custom-claim or metadata checks. The client touches exactly one Storage path, `users/{uid}/profile/avatar.jpg`, and it matches a rules block. The only other path, `chat-attachments/...`, is written by a Cloud Function through the Admin SDK and matches no rules block.

**How `storage.rules` decides access** (all @ 7808a91)

- **Load-bearing:** `storage.rules:5-7 (isAuthenticated) @ 7808a91` returns `request.auth != null`. It is the only helper, and no rule reads `request.auth.token`, `request.resource.size`, `request.resource.contentType` or `resource.metadata`. A `git grep` for `request.auth.token` in `storage.rules` found nothing.
- Every rule is written as `read` / `write`. None is split into get/list/create/update/delete, so `write` covers create, update and delete. Per-block conditions:

| Block | read | write | Rejects |
|---|---|---|---|
| `storage.rules:10-13` `/chat_images/{chatRoomId}/{fileName}` | signed in | signed in | unauthenticated callers. Nothing ties the caller to `chatRoomId`. (load-bearing) |
| `storage.rules:16-19` `/chat_videos/{chatRoomId}/{fileName}` | signed in | signed in | same as above (load-bearing) |
| `storage.rules:22-25` `/users/{userId}/profile/{fileName}` | signed in | signed in and `request.auth.uid == userId` | unauthenticated reads; writes or deletes by anyone but the owner (load-bearing) |
| `storage.rules:28-31` `/users/{userId}/{allPaths=**}` | signed in | signed in and `request.auth.uid == userId` | same as above. Its pattern also covers the profile path, and Storage grants access if any matching rule allows it, so the two blocks give the same result. (load-bearing) |
| `storage.rules:34-37` `/public/{allPaths=**}` | `true` (anyone, including signed-out users) | `false` | every client write (load-bearing) |
| `storage.rules:40-42` `/{document=**}` | `false` | `false` | everything the blocks above do not allow (load-bearing) |

- `functions/src/customClaims.ts:6-10 (setRoleClaim) @ 7808a91` has a comment saying the claim "is needed for Storage rules to check if a user is a teacher." The rules at this commit never check that claim, so the comment does not match the rules.

**Every Storage path the code touches** (load-bearing list)

1. **Client write:** `users/{user.uid}/profile/avatar.jpg`, built at `lib/shared/screens/settings_screen.dart:1029-1034 (_uploadProfilePicture) @ 7808a91` and written with `putFile` at `:1038`.
   - Matches `storage.rules:22` (and `:28`). The uid in the path comes from `authProvider.userModel.uid` (`:1016`), so the owner check passes for the signed-in user.
   - The client sends no contentType or size; the rules would not check them anyway.
2. **Client read:** the same path, via `getDownloadURL()` at `settings_screen.dart:1041 @ 7808a91`.
   - Matches `:22`, which needs only sign-in.
   - The URL is saved by `lib/features/auth/providers/auth_provider.dart:704-713 (updateProfilePicture) @ 7808a91`: `user.updatePhotoURL` plus Firestore `users/{uid}.photoURL`.
   - The rules do not govern later fetches of that URL. It is a token-bearing download URL; that is standard Firebase Storage behaviour, not something this code shows.
3. **Client delete:** the same path, via `storageRef.delete()` at `settings_screen.dart:1078-1086 (_removeProfilePicture) @ 7808a91`.
   - Matches `:22`, owner only.
   - Errors are swallowed at `:1087-1089`.
   - `photoURL` is not cleared afterwards (comment at `:1091-1093`).
4. **Server write:** `chat-attachments/{conversationId}/{userId}/{timestamp}_{sanitizedFileName}` at `functions/src/chatFunctions.ts:339 (uploadChatFile) @ 7808a91`, saved through `admin.storage().bucket().file(...).save` at `:7`, `:345-357`.
   - **No rules block matches `chat-attachments/`.** The nearest names, `chat_images` and `chat_videos`, use underscores. The default deny would apply to any client SDK access, but the Admin SDK bypasses the rules. (load-bearing)
   - The function returns a signed read URL that expires "03-01-2500" (`:360-363`).
   - The client calls it from `lib/features/chat/data/controllers/firestore_chat_controller.dart:383-390` (image) and `:473-480` (file) @ 7808a91, sending base64 data, and uses `result.data['url']` (`:397`, `:487`).
   - Chat images are displayed by plain URL fetch: `Image.network` at `lib/features/chat/presentation/widgets/web_image_stub.dart:20 @ 7808a91`, and an `<img src>` at `web_image_web.dart:45 @ 7808a91`. Neither goes through the Storage SDK or the rules.
5. **Not used by any code:** `chat_images/`, `chat_videos/` and `public/`. The repo-wide grep finds them only in `storage.rules`.

**Checks in `uploadChatFile` that stand in for the rules on the chat path** (`functions/src/chatFunctions.ts @ 7808a91`)

- `:290-295` rejects unauthenticated callers (`unauthenticated`).
- `:301-306` rejects a request missing `conversationId`, `fileName`, `base64Data` or `mimeType` (`invalid-argument`).
- `:309-314` rejects a client-declared `fileSize` over 10 MB. It checks the field the client sends, not the decoded buffer, and is skipped when `fileSize` is missing.
- `:317-331` rejects a `mimeType` outside a list of 11: jpeg/png/gif/webp, pdf, doc/docx, xls/xlsx, text/plain, text/csv. The client builds image types as `'image/${extension}'` (`firestore_chat_controller.dart:387`), so a `.jpg` file becomes `image/jpg`, which is not on the list.
- `:334` → `:9-30 (ensureConversationMembership)` rejects a conversation that does not exist (`not-found`) or a caller not in `participants` / `participantIds`.
- `:338` replaces any character outside `[a-zA-Z0-9.-]` in the file name with `_`.

**Searched for and not found** (repo-wide `git grep` @ 7808a91, with the brief's excluded paths left out)

- `FirebaseStorage`, `.ref(`, `putFile`, `putData`, `getDownloadURL` and `refFromURL` appear only in `settings_screen.dart` and `service_locator.dart`. `refFromURL`, `putData` and `firebasestorage` URL handling have no hits.
- The `ServiceLocatorExtension.storage` getter (`lib/shared/core/service_locator.dart:141`) and the `FirebaseStorage` singleton (`:88-90`) are never used through `getIt` anywhere in `lib/`.
- The only server Storage use is `functions/src/chatFunctions.ts:7, :339, :345`. No function deletes or reads Storage objects.
- `firebase.json` is not in commit 7808a91 (a copy exists in the working tree), so nothing at the commit shows how `storage.rules` gets deployed.

I read 7 of the 15 budgeted files.