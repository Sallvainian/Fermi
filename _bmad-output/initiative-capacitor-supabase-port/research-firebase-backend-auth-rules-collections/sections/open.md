## Open questions

- **`firebase.json` is not in the commit.** It is ignored by `.gitignore:114 (firebase.json) @ 7808a91`. A copy exists in the working tree, and this research did not read it. That leaves unchecked which rules files, functions source, hosting targets and emulator ports the project deploys with. Next ask, once the file is committed: *What does `firebase.json` configure for Firestore rules, Storage rules, indexes, functions source, hosting and emulators?*
- **Collections outside the question set.** `firestore.rules` and `firestore.indexes.json` name collections this research did not trace: `calls` (and `candidates`), `announcements`, `games`/`scores`, `teachers`, `files`, `archived_grades` and the legacy `chat_rooms`. Next ask: *Where are `calls`, `announcements`, `games`, `teachers`, `files`, `archived_grades` and `chat_rooms` read and written?*
- **Platform behavior the code does not show (UNVERIFIED):**
  - whether Admin SDK `createUser`/`importUsers` fire `beforeUserCreated`
  - the default region of `FirebaseFunctions.instance` (believed to be `us-central1`)
  - how `set` with merge treats a dotted `behaviorCounts.<id>` key
  - how `resource == null` behaves in rules list queries
  - whether plugin manifests merge `POST_NOTIFICATIONS` into the Android build
- **Items left unread:**
  - the operation at `lib/features/student/presentation/providers/student_provider.dart:105 (loadTeacherStudents) @ 7808a91` and `:165`
  - which `grades` index entries sit at `firestore.indexes.json` lines 642–722
  - whether the hand-built `calendar_events` create includes `isActive`
  - which collection `StudentEnhanced` would read
  - the request bodies of the three OAuth HTTP calls
  - the calling files in question 12, whose reachability was checked by `git grep` only
- **Budget:** the analyzers for questions 5 (about 31 short reads), 7 (16 files) and 8 (15 full reads plus 12 excerpts) went past the 15-file budget to finish their call-site lists.
