I searched three folders at 7808a91 through git: `lib/features/behavior_points/` (14 files), `lib/features/games/` (5 files) and `lib/features/jeopardy/` (1 file). The area bears only on questions 5, 6, 8 and 12. All Firestore traffic comes from two files. One is `behavior_points_service.dart`. The other is the jeopardy provider under `lib/features/jeopardy/`, and nothing in the repo imports it.

**Q5 (`users`, `public_usernames`, `presence`, `fcm_tokens`, `notifications`, `scheduled_messages`, `bug_reports`)**
- Nothing in this area touches these collections.
- There are no variable-name `collection(...)` calls here (`collection(this.collectionName)`, `collection(path)`, `collection(collectionPath)`). Every `.collection(` hit uses a fixed string.

**Q6 (`classes` only)**
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:138, 209, 243, 263, 298, 333 (BehaviorPointsService) @ 7808a91`: `classes` appears only as the parent document `.collection('classes').doc(classId)` for the `studentPoints` and `behaviors` paths in Q8. Nothing here reads or writes a `classes` document itself.
- Nothing in this area touches `students`, `assignments`, `submissions`, `grades`, `collectionGroup('grades')` or `calendar_events`.

**Q7 (`chatRooms`, `conversations`, `messages`, `typing`, `discussion_boards`, `threads`, `replies`, `likes`)**
- Nothing in this area touches these collections.

**Q8**

`studentPoints` (`classes/{classId}/studentPoints/{studentId}`)
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:138-140 (BehaviorPointsService.watchClassPointsSummary) @ 7808a91`: streams the whole subcollection with `.snapshots()` and maps each doc with `StudentPointsAggregate.fromMap` (line 152).
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:243-246 (BehaviorPointsService.getStudentPoints) @ 7808a91`: `.get()` on one student's doc.
- The client never writes here. The class comment says all writes go through Functions (see Q12).
- Shape: `lib/features/behavior_points/data/models/student_points_aggregate.dart:8 (StudentPointsAggregate) @ 7808a91`, with `fromFirestore` :33 (sets `studentId` from the doc id), `fromMap` :38 and `toFirestore` :57.
- A second, older shape: `lib/features/behavior_points/domain/models/student_points.dart:23 (StudentPoints) @ 7808a91`, with `fromFirestore` :86, `fromMap` :129, `toFirestore` :174, `toJson` :198 and `fromJson` :221. It embeds a list of `BehaviorPoint`. No `.collection(` call here uses it.

`history` (`classes/{classId}/studentPoints/{studentId}/history`)
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:171 (BehaviorPointsService.watchRecentHistory) @ 7808a91`: `collectionGroup('history')` with `.where('classId', isEqualTo: classId)`, `.where('isUndone', isEqualTo: false)`, `.orderBy('awardedAt', descending: true)` and `.limit(limit)`. The provider calls it with `limit: 100` (`behavior_point_provider.dart:250`). This query needs a collection-group composite index on `classId` + `isUndone` + `awardedAt` desc.
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:209-213 (BehaviorPointsService.watchStudentHistory) @ 7808a91`: the direct path, with `.where('isUndone', isEqualTo: false)`, `.orderBy('awardedAt', descending: true)` and `.limit`.
- Both map with `BehaviorHistoryEntry.fromMap` (lines 181 and 222). The client never writes here.
- Shape: `lib/features/behavior_points/data/models/behavior_history_entry.dart:7 (BehaviorHistoryEntry) @ 7808a91`, with `fromFirestore` :46, `fromMap` :52 and `toFirestore` :99.

`behaviors` (`classes/{classId}/behaviors/{behaviorId}`)
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:263-265 (BehaviorPointsService.watchClassBehaviors) @ 7808a91`: `.orderBy('name').snapshots()`, mapped with `Behavior.fromFirestore` (line 272).
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:298-304 (BehaviorPointsService.saveBehavior) @ 7808a91`: direct client write using `.doc(behaviorId)` or `.doc()`, then `set(..., SetOptions(merge: true))`. Fields written: `name`, `description`, `points`, `type`, `iconCodePoint`, `isCustom: true`, `teacherId`, `classId`, `createdAt`, `updatedAt` (server timestamps).
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:333-336 (BehaviorPointsService.deleteBehavior) @ 7808a91`: `.delete()`.
- Shape: `lib/features/behavior_points/domain/models/behavior.dart:29 (Behavior) @ 7808a91`, with `fromFirestore` :92, `fromMap` :168 and `toFirestore` :218.

Other behavior models with no `.collection(` call of their own
- `lib/features/behavior_points/domain/models/behavior_point.dart:22 (BehaviorPoint) @ 7808a91`, with `fromFirestore` :80, `fromMap` :113, `toFirestore` :143, `toJson` :164 and `fromJson` :186.
- `lib/features/behavior_points/presentation/providers/behavior_point_provider.dart:47 (BehaviorPoint) @ 7808a91`: a second class with the same name, with `fromFirestore` :93.
- `lib/features/behavior_points/presentation/providers/behavior_point_provider.dart:114 (BehaviorPointProvider) @ 7808a91`: has no Firestore calls of its own and goes through `BehaviorPointsService` (lines 197, 215, 250, 312, 348, 384, 407).

`jeopardy_games`, `jeopardy_questions`, `jeopardy_sessions`
- All live in `lib/features/jeopardy/presentation/providers/jeopardy_provider.dart (SimpleJeopardyProvider) @ 7808a91`.
- Searching for `features/jeopardy` across the repo returned no hits. The provider actually used is the one under `games/`, imported at `lib/shared/core/app_providers.dart:17`.
- `jeopardy_games`:
  - :36 (`loadGames`): `.where('createdBy', ==uid).orderBy('createdAt', desc).get()`.
  - :78 (`createGame`): `.add` with `title`, `description`, `categories`, `createdBy`, `createdAt`, `isPublished: false`, `playCount: 0`.
  - :289 (`updateGame`): `.update(updates)`.
  - :313 (`deleteGame`): `.delete()`.
  - :328-329 (`getGameById`): `.get()`.
- `jeopardy_questions`:
  - :105 (`_createCategoryQuestions`): `.add` with `gameId`, `category`, `question`, `answer`, `points`, `isAnswered`, `answeredBy`.
  - :124 (`loadGameQuestions`): `.where('gameId').orderBy('category').orderBy('points')`. This query needs a composite index.
  - :209 and :218-219 (`answerQuestion`): `.update` of `isAnswered`, `answeredBy`, `answeredAt`, then a `.get()`.
  - :304 (`deleteGame`): `.where('gameId')`, then deletes each doc.
- `jeopardy_sessions`:
  - :163 (`startGameSession`): `.add` with `gameId`, `classId`, `hostId`, `startedAt`, `status: 'active'`, `teams: []`, `currentQuestion`.
  - :187 (`joinSession`): `teams` `arrayUnion` with `name`, `playerIds`, `score`, `joinedAt`.
  - :226-227 and :239-240 (`answerQuestion`): reads the session, then rewrites `teams`.
  - :256 (`endSession`): sets `status: 'completed'` and `endedAt`.
  - :272-273: `.snapshots()` on one session.
- The model this code would map to: `lib/features/games/domain/models/jeopardy_game.dart:4 (JeopardyGame) @ 7808a91`, with `toFirestore` :44 and `fromFirestore(data, id)` :61. Nested classes all have `toJson`/`fromJson`: `JeopardyCategory` :129, `JeopardyQuestion` :157, `JeopardyPlayer` :210, `JeopardyTeam` :238, `FinalJeopardyData` :266, `DailyDouble` :298 and `JeopardyGameSession` :323. The unused provider writes raw maps instead of using this model, and its field names differ (`createdBy` vs the model's `teacherId`).
- `lib/features/games/presentation/providers/jeopardy_provider.dart:6 (SimpleJeopardyProvider) @ 7808a91`: the one that is actually wired in. It is a stub with no Firestore access; its comments say "Stub - would query Firestore" (lines 31, 53, 77, 94…). It only reads `FirebaseAuth.instance.currentUser?.uid` (line 7).

Not found in this area: `activities`, `oauth_pkce_challenges`, `_rate_limits`.

**Q12 (callables, all in region `us-east4`)**
- `lib/features/behavior_points/domain/services/behavior_points_service.dart:13 (BehaviorPointsService) @ 7808a91`: creates the client with `FirebaseFunctions.instanceFor(region: 'us-east4')`.
  - :38 (`awardBehaviorPoints`): calls `awardBehaviorPoints` with `{classId, studentId, studentName, behaviorId, behaviorName, points, gender, gradeLevel, studentAvatarUrl, note}`. It expects `success` and `operationId` back.
  - :79 (`undoBehaviorPoints`): calls `undoBehaviorPoints` with `{classId, studentId, historyId}`.
  - :109 (`getClassPointsSummary`): calls `getClassPointsSummary` with `{classId}`. It expects `success` plus a `summaries` map of `StudentPointsAggregate`.
- `lib/features/behavior_points/presentation/widgets/behavior_history_panel.dart:122-123 (_BehaviorHistoryPanelState) @ 7808a91`: calls `getBehaviorHistory`. The arguments come from `BehaviorHistoryFilters.toMap` (:27), which may include `studentName`, `gender`, `startDate`/`endDate` (ISO strings) and `behaviorType`, plus `classId`, `limit` and `offset`. It expects `success` and a `history` list mapped with `BehaviorHistoryEntry.fromMap`.

**Questions 1–4, 9–11 and 13**
- Searches at 7808a91 across all three folders for `FirebaseStorage`, `firebase_storage`, `FirebaseDatabase`, `firebase_database`, `FirebaseMessaging`, `firebase_messaging` and `flutter_local_notifications` returned no hits.
- The only Auth use is reading `FirebaseAuth.instance` and `currentUser?.uid`:
  - `lib/features/behavior_points/presentation/providers/behavior_point_provider.dart:118, 145 (BehaviorPointProvider) @ 7808a91`
  - `lib/features/games/presentation/providers/jeopardy_provider.dart:7 @ 7808a91`
  - `lib/features/jeopardy/presentation/providers/jeopardy_provider.dart:8 @ 7808a91`
- None of these files read role claims or sign users in.