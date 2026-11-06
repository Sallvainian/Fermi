The call-site list for all nine collections is below. Every citation is `@ 7808a91`.

**Budget:** I fully read 15 files, which is the cap. On top of that I took grep hits and line-range excerpts from 12 more files. Those are the call-site files (`dashboard_service.dart`, `bulk_import_service.dart`, `user_management_service.dart`, `admin_provider.dart`, `dashboard_provider.dart`, `behavior_history_panel.dart`, `adminFunctions.ts`, `bulkImport.ts`, `authBlocking.ts`, `oauth.ts`, `cleanup.ts`, `security.ts`). That goes past a strict 15-file count. `firestore.rules` came up only in grep hits; I did not read it.

---

## 1. studentPoints (`classes/{c}/studentPoints/{studentId}`)

**Shapes**
- **(load-bearing)** `lib/features/behavior_points/data/models/student_points_aggregate.dart:8-70 (StudentPointsAggregate) @ 7808a91`.
  - Fields: `studentId`, `studentName`, `classId`, `totalPoints`, `positivePoints`, `negativePoints`, `behaviorCounts` (a `Map<String,int>`), `lastUpdated` (a Timestamp), `lastBehaviorName?`, `lastPoints?`.
  - `fromMap` is at :38 and `toFirestore` at :57.
  - `createIncrementUpdate` (:73) and `createUndoUpdate` (:96) have no callers in `lib/`.
- **(load-bearing)** Server-written shape at `functions/src/behaviorPoints.ts:106-119 (awardBehaviorPoints) @ 7808a91`.
  - Fields: `studentId`, `studentName`, `totalPoints`, `positivePoints`, `negativePoints` (all incremented), `behaviorCounts.<behaviorId>` (incremented), `lastUpdated`, `lastUpdatedBy`.
  - It is written with `set(..., {merge: true})`.
- The older model is at `lib/features/behavior_points/domain/models/student_points.dart:23,86,129,174 (StudentPoints) @ 7808a91`.
  - Fields: `studentName`, `totalPoints`, `positivePoints`, `negativePoints`, `recentBehaviors[]` (as BehaviorPoint), `avatarColorHex`, `lastUpdated`, `classId`, `classRank`, `positiveBehaviorCount`, `negativeBehaviorCount`.
  - No file in `lib/` imports it. A `git grep` for `domain/models/student_points` found nothing.

**Indexes:** none.

**Call sites**
- Writes (server):
  - `functions/src/behaviorPoints.ts:102-119 awardBehaviorPoints`: set with merge.
  - `behaviorPoints.ts:236-251 undoBehaviorPoints`: `batch.update`, decrementing the counters and `behaviorCounts.<id>`.
- Reads (server): `behaviorPoints.ts:332-335 getClassPointsSummary`, which gets the whole subcollection and returns the raw docs.
- Reads (client), all in `lib/features/behavior_points/domain/services/behavior_points_service.dart`:
  - `:137-162 watchClassPointsSummary`: snapshot stream. It skips docs with an empty `studentId` or with `studentName == 'Loading...'`.
  - `:242-247 getStudentPoints`: single-doc get. No callers in `lib/`.
  - `:105-131 getClassPointsSummary`: wraps the callable. No callers in `lib/`.

**Disagreements (load-bearing)**
- The server never writes `classId`, `lastBehaviorName` or `lastPoints`, so the model falls back to `''` or null for them. The server writes `lastUpdatedBy`, which the model has no field for.
- `behaviorCounts` is written two ways:
  - award (:116) uses a dotted key inside `set` with merge;
  - undo (:248) uses the same dotted key inside `update`;
  - the model reads a nested map, `data['behaviorCounts']`, at `student_points_aggregate.dart:46`.
  - Whether `set` treats the dotted key as a literal field name rather than a nested path is SDK behaviour I did not verify in code. UNVERIFIED.

## 2. history (`classes/{c}/studentPoints/{s}/history/{operationId}`, plus collectionGroup)

**Shapes**
- **(load-bearing)** Server writer at `functions/src/behaviorPoints.ts:125-145 awardBehaviorPoints @ 7808a91`.
  - Fields: `operationId`, `studentId`, `studentName`, `behaviorId`, `behaviorName`, `points`, `type` (`'positive'` or `'negative'`), `teacherId`, `teacherName`, `awardedBy`, `awardedByName`, `timestamp`, `awardedAt` (both server timestamps), `isUndone: false`, `classId`, `gender`, `gradeLevel`, `studentAvatarUrl`, `note`.
  - The doc id is `${teacherId}_${studentId}_${behaviorId}_${Date.now()}` (:80).
  - Undo adds `isUndone: true`, `undoneBy` and `undoneAt` (:254-258).
- **(load-bearing)** Client model at `lib/features/behavior_points/data/models/behavior_history_entry.dart:7-118 (BehaviorHistoryEntry) @ 7808a91`.
  - `fromMap` (:52) reads `teacherId ?? awardedBy`, `teacherName ?? awardedByName`, and `timestamp ?? awardedAt`.
  - `toFirestore` (:99) writes `timestamp` only, with no `awardedAt`. `toFirestore` has no callers.
  - It does not model `undoneBy` or `undoneAt`.
- A second reader is `lib/features/behavior_points/presentation/providers/behavior_point_provider.dart:47,93 (BehaviorPoint) @ 7808a91`. It reads `reason ?? note`, `awardedBy ?? teacherId`, `awardedByName ?? teacherName`, and `awardedAt ?? timestamp`. `BehaviorPoint.fromFirestore` has no callers.
- A third, older shape is `lib/features/behavior_points/domain/models/behavior_point.dart:22,80,143 (BehaviorPoint)`. Fields: `studentId`, `studentName`, `teacherId`, `classId`, `behaviorId`, `behaviorName`, `points`, `type`, `timestamp`, `note`. It is imported only by the unimported `student_points.dart`.

**Indexes:** all four are `COLLECTION_GROUP`.
- `firestore.indexes.json:1138`: (`classId`, `isUndone`, `awardedAt` desc)
- `:1160`: (… `studentId`, `awardedAt` desc)
- `:1186`: (… `gender`, `awardedAt` desc)
- `:1212`: (… `type`, `awardedAt` desc)
- No index includes `timestamp`.

**Call sites**
- Reads and writes (server), all in `functions/src/behaviorPoints.ts`:
  - `:86-99 awardBehaviorPoints`: reads the doc for an idempotency check, then writes it in a batch at :125.
  - `:213-223 undoBehaviorPoints`: reads the doc, then updates it at :254.
  - `:426-472 getBehaviorHistory`: `collectionGroup('history')` read.
    - Filters: `classId`, `isUndone == false`, and optionally `studentId`, `gender` and `type`.
    - The date range filters on `timestamp` (:448, :456), but the query orders by `awardedAt` (:461), then applies offset and limit.
  - `:493-509 getBehaviorHistory`: `collectionGroup('history')` count query.
- Reads (client):
  - `behavior_points_service.dart:170-176 watchRecentHistory`: collectionGroup with `classId`, `isUndone == false`, `orderBy awardedAt`. It is used at `behavior_point_provider.dart:250`.
  - `behavior_points_service.dart:208-216 watchStudentHistory`: subcollection, `isUndone`, `orderBy awardedAt`. No callers in `lib/`.
  - Indirect read: `lib/features/behavior_points/presentation/widgets/behavior_history_panel.dart:123-136` calls the `getBehaviorHistory` callable and parses each item with `BehaviorHistoryEntry.fromMap`.

**Disagreements (load-bearing)**
- **Timestamp field split.** The server writes both `timestamp` and `awardedAt`. Ordering and every index use `awardedAt`, but the date-range filter uses `timestamp` (`behaviorPoints.ts:448,456` against :461 and the indexes).
- **Callable timestamps are lost on the client.** `getBehaviorHistory` turns `timestamp` and `awardedAt` into ISO strings (`behaviorPoints.ts:482-487`). `parseTimestamp` handles only null, Timestamp, DateTime and `{_seconds}`, so a String falls back to `DateTime.now()` (`behavior_history_entry.dart:54-66`).
- **Duplicate teacher fields.** The server writes `teacherId`/`awardedBy` and `teacherName`/`awardedByName` as duplicate pairs. The client model's `toFirestore` writes neither `awardedAt` nor `awardedBy`.

## 3. behaviors (`classes/{c}/behaviors/{id}`)

**Shape (load-bearing):** `lib/features/behavior_points/domain/models/behavior.dart:29,92,168,218 (Behavior) @ 7808a91`.
- Fields: `name`, `description`, `points`, `type` (enum name), `iconName`, `iconCodePoint`, `isCustom`, `teacherId`, `classId`, `createdAt`, `updatedAt`.

**Index:** `firestore.indexes.json:1238`: `behaviors` (`name` asc, `__name__` asc), `COLLECTION` scope.

**Call sites** (client only, all in `behavior_points_service.dart`; none in `functions/src`):
- `:262-282 watchClassBehaviors`: read, `orderBy('name')`, parsed with `Behavior.fromFirestore`.
- `:297-317 saveBehavior`: write, `set(merge)`. Fields: `name`, `description`, `points`, `type`, `iconCodePoint`, `isCustom: true`, `teacherId`, `classId`, `createdAt`, `updatedAt`.
- `:332-337 deleteBehavior`: delete.

**Disagreements**
- `saveBehavior` never writes `iconName`, which the model reads.
- `saveBehavior` sets `createdAt` to a server timestamp on every save, so updates overwrite it.

## 4. activities (top-level)

**Shape (load-bearing):** `lib/features/dashboard/domain/models/activity_model.dart:14-78 (ActivityModel) @ 7808a91`.
- Fields: `type` (an `ActivityType` enum name), `title`, `description`, `timestamp`, `userId`, `userName`, `classId`, `className`, `assignmentId`, `metadata`, `isRead`.
- `fromFirestore` is at :43 and `toMap` at :64.

**Indexes**
- `firestore.indexes.json:4`: (`classId`, `timestamp` desc)
- `:22`: (`teacherId`, `timestamp` desc)

**Call sites, client**
- `lib/features/dashboard/data/services/dashboard_service.dart`:
  - `:17-22 getTeacherActivities`: read, `teacherId ==` plus `orderBy timestamp`.
  - `:47-52 getStudentActivities`: read, `classId whereIn` plus `orderBy timestamp`.
  - `:135 logActivity`: write, `ActivityModel.toMap`. It is called only from `DashboardProvider.logActivity` (`dashboard_provider.dart:119`), and that method has no callers.
- `lib/features/admin/data/services/bulk_import_service.dart:346 _logBulkImportActivity`: write. Fields: `type: 'bulk_import'`, `accountType`, `performedBy`, `performedByEmail`, `successCount`, `errorCount`, `timestamp`, `details`.
- `lib/features/admin/data/services/user_management_service.dart`:
  - `:338-343 getUserDetails`: read, `userId ==` plus `orderBy timestamp`.
  - `:363-369 _logActivity`: write. Fields: `type`, `performedBy`, `performedByEmail`, `timestamp`, `details`.
- `lib/features/admin/presentation/providers/admin_provider.dart`:
  - `:145-149 loadSystemStats`: read, `timestamp >` one day ago.
  - `:214-218 _loadRecentActivities`: read, `orderBy timestamp`.

**Call sites, server** (all writes are `add`)
- `functions/src/adminFunctions.ts`:
  - `:160 createStudentAccount`, `:263 createTeacherAccount` and `:365 createAdminAccount`: `type: 'user_created'`, `userName`, `userRole`, `createdBy`, `timestamp`, `details{userId, email, …}`.
  - `:441 deleteUserAccount`: adds `deletedBy`.
  - `:507 resetUserPassword`: adds `resetBy`.
  - `:569-572 getSystemStats`: read, `timestamp >`.
- `functions/src/bulkImport.ts:395 bulkImportStudents`: write. Fields: `type: 'bulk_import'`, `action`, `performedBy`, `timestamp`, `details`.
- `functions/src/authBlocking.ts:84 autoAssignRole`: write. Fields: `type: 'user_created'`, `createdBy: 'system'`, `details`.

**Disagreements (load-bearing)**
- No writer anywhere writes `teacherId`, yet `getTeacherActivities` filters on it and index :22 exists for it.
- Only the uncalled `ActivityModel.toMap` writes top-level `userId` or `classId`. The server puts the user id in `details.userId`, while `getUserDetails` filters on top-level `userId`. No index covers (`userId`, `timestamp`).
- Writers use `type` values such as `'user_created'` and `'bulk_import'`. These are not `ActivityType` names, so `fromFirestore` maps them to `announcement` (:47-50).
- Writers also use `performedBy`, `createdBy` and `details`, none of which the model has.

## 5–7. jeopardy_games / jeopardy_questions / jeopardy_sessions

**Reachability (load-bearing):** two classes are both named `SimpleJeopardyProvider`.
- The wired one is the stub `lib/features/games/presentation/providers/jeopardy_provider.dart:6 @ 7808a91`. It is imported at `lib/shared/core/app_providers.dart:17`, constructed at :66, and used by the `games/presentation/screens/jeopardy_*` screens. It has no Firestore import, and every method returns stub data (:25-149).
- `lib/features/jeopardy/presentation/providers/jeopardy_provider.dart` is the only file in `lib/features/jeopardy/`. Nothing imports it: `git grep "features/jeopardy"` over `lib`, `test` and `integration_test` returned no import lines.
- So at this commit, no reachable code reads or writes any `jeopardy_*` collection.

**Shapes (load-bearing):** `lib/features/games/domain/models/jeopardy_game.dart @ 7808a91`.
- `JeopardyGame` (:4, `toFirestore` :44, `fromFirestore` :61):
  - Fields: `title`, `teacherId`, `categories[]`, `doubleJeopardyCategories`, `finalJeopardy`, `createdAt`, `updatedAt` (ISO strings), `isPublic`, `gameMode`, `assignedClassIds`, `dailyDoubles[]`, `randomDailyDoubles`.
  - Questions are nested inside categories:
    - `JeopardyCategory` :129 has `{name, questions[]}`.
    - `JeopardyQuestion` :157 has `{question, answer, points, isAnswered, answeredBy, isDailyDouble}`.
- `JeopardyGameSession` (:323):
  - Fields: `id`, `gameId`, `teacherId`, `classId`, `startedAt`, `endedAt`, `players[]` (`JeopardyPlayer` :210 has `{id, name, score, teamId}`), `teams[]` (`JeopardyTeam` :238 has `{id, name, memberIds, score}`), `currentRound`, `answeredQuestions`, `isActive`.
- Supporting classes: `FinalJeopardyData` :266 and `DailyDouble` :298.

**Indexes:** `jeopardy_games` only.
- `firestore.indexes.json:744`: (`isPublic`, `updatedAt` desc)
- `:762`: (`teacherId`, `isPublic`, `updatedAt` desc)
- `:784`: (`teacherId`, `updatedAt` desc)
- There are no entries for `jeopardy_questions` or `jeopardy_sessions`.

**Call sites** (all in the unreachable `lib/features/jeopardy/presentation/providers/jeopardy_provider.dart`; none in `functions/src`)
- `jeopardy_games`:
  - `:35-39 loadGames`: read, `createdBy ==` plus `orderBy createdAt`.
  - `:77-79 createGame`: write. Fields: `title`, `description`, `categories`, `createdBy`, `createdAt`, `isPublished`, `playCount`.
  - `:289 updateGame`: update, adds `updatedAt`.
  - `:313 deleteGame`: delete.
  - `:327-330 getGameById`: read.
- `jeopardy_questions`:
  - `:105 _createCategoryQuestions`: write. Fields: `gameId`, `category`, `question`, `answer`, `points`, `isAnswered`, `answeredBy`.
  - `:123-128 loadGameQuestions`: read, `gameId ==` plus `orderBy category` and `orderBy points`.
  - `:209 answerQuestion`: update. Fields: `isAnswered`, `answeredBy`, `answeredAt`.
  - `:217-220 answerQuestion`: read.
  - `:303-309 deleteGame`: read, then delete each doc.
- `jeopardy_sessions`:
  - `:162-164 startGameSession`: write. Fields: `gameId`, `classId`, `hostId`, `startedAt`, `status`, `teams`, `currentQuestion`.
  - `:187 joinSession`: update, `arrayUnion` of team `{name, playerIds, score, joinedAt}`.
  - `:225-228 answerQuestion`: read.
  - `:238-241 answerQuestion`: update `teams`.
  - `:256 endSession`: update `status` and `endedAt`.
  - `:271-274 getSessionStream`: snapshot read.

**Disagreements (load-bearing)**
- **Games.** The writer uses `createdBy`, `isPublished`, `playCount`, `description` and `createdAt` ordering. The model and all three indexes use `teacherId`, `isPublic` and `updatedAt`. No index covers (`createdBy`, `createdAt`).
- **Questions.** The writer keeps them in a separate `jeopardy_questions` collection. The model nests them in `categories[].questions[]`. No index covers (`gameId`, `category`, `points`).
- **Sessions.** The writer uses `hostId`, `status`, `currentQuestion` and teams as `{name, playerIds, score, joinedAt}`. The model uses `teacherId`, `isActive`, `currentRound`, `players` and teams as `{id, name, memberIds, score}`.
- **Rules.** `firestore.rules` has `match` blocks for `jeopardy_games` (:725) and `jeopardy_sessions` (:752). Grep found none for `jeopardy_questions`.

## 8. oauth_pkce_challenges (top-level, doc id = OAuth `state`)

**Shape (load-bearing):** `functions/src/types/oauth.types.ts:30-35 (PKCEChallenge) @ 7808a91`.
- Fields: `codeVerifier`, `expiresAt` (a number, epoch ms), `createdAt` (Timestamp or FieldValue), `clientId?`.

**Indexes:** none.

**Call sites** (server only)
- `functions/src/oauth.ts`:
  - `:63-64 getPKCECollection`: the accessor.
  - `:123-129 getOAuthUrl`: write, set with `expiresAt = now + 600000`.
  - `:222 exchangeOAuthCode`: read.
  - `:229 exchangeOAuthCode`: delete when expired.
  - `:240 exchangeOAuthCode`: delete after use.
- `functions/src/cleanup.ts`:
  - `:21-64 cleanupExpiredPKCEChallenges`: read `expiresAt < now`, then batch delete.
  - `:72-100 cleanupExpiredPKCEChallenges`: read `createdAt <` 30 days ago, then batch delete.
  - `:108`: count.
  - `:131-163 manualPKCECleanup`: the same two queries with per-doc deletes, plus a count.

## 9. _rate_limits (top-level, doc id = `${config.name}_${identifier}`)

**Shape (load-bearing):** `functions/src/rate-limiter.ts:9-13 (RateLimitRecord) @ 7808a91`.
- Fields: `count`, `firstCall`, `lastCall` (both Timestamps).

**Indexes:** none.

**Call sites** (server only)
- `rate-limiter.ts:32-80 FirestoreRateLimiter.rejectOnQuotaExceededOrRecordUsage`: a transaction that reads the doc, then sets it (:51, :65) or updates it (:75).
  - It throws `"Rate limit exceeded"` when `count >= maxCalls` (:70-71).
  - Any other error is logged and the request is not blocked (:81-87).
  - It is reached through `functions/src/security.ts:44 applyRateLimit`. The limiter names are `oauth_get_url` (10/60s), `oauth_exchange` (5/60s) and `oauth_refresh` (20/60s) at :28-34.
- `rate-limiter.ts:92-115 cleanupOldRateLimitRecords`: reads `lastCall <` cutoff with limit 500, then batch deletes. It has no callers in `functions/src`.

---

**Searched for and not found** (`git grep` at 7808a91 over `lib` and `functions/src`):
- No collection-name constants or repository indirection for these collections. The only hits for `'studentPoints'`, `'behaviors'`, `'history'` and `'activities'` outside `.collection()` calls are map keys.
- No server code touches `behaviors` or `jeopardy_*`.
- No client code touches `oauth_pkce_challenges` or `_rate_limits`.
- No `fieldOverrides` entries for any of these nine collections in `firestore.indexes.json`. The only entry there is for `calls` (:1254).