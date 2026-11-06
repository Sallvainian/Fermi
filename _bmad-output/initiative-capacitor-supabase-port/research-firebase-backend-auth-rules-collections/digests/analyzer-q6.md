The shape of each collection is set by one or two Dart model classes. Several writers and readers use field names those models don't have. Below, for each collection: the shape, the index entries, then every call site marked R (read) or W (write). All citations are @ 7808a91.

`firestore.indexes.json` has 1,272 lines and no `fieldOverrides` entry for any of the six collections. Its line numbers below are the `"collectionGroup"` line of each entry.

---

## classes

**Shape (load-bearing):** `lib/features/classes/domain/models/class_model.dart:137-206 (ClassModel.fromFirestore) @ 7808a91` and `:216-236 (toFirestore) @ 7808a91`.
- Fields: `teacherId, name, subject, description, gradeLevel, room, schedule, studentIds[], syllabusUrl, createdAt, updatedAt, isActive, academicYear` (default `'2024-2025'`), `semester` (default `'Fall'`), `maxStudents, enrollmentCode, settings`.
- Timestamps are parsed leniently: Timestamp, DateTime, String or int, falling back to now.

**Disagreements (load-bearing):**
- **`students` vs `studentIds`:** `chat/presentation/screens/class_selection_screen.dart:52 @ 7808a91` queries `where('students', arrayContains:)`, and `:62` and `:99` read `data['students']`. `grades/data/services/grade_analytics_service.dart:35 @ 7808a91` reads `classDoc['students']`. The model and every writer use `studentIds`.
- **`studentCount`** is incremented at `create_student_dialog.dart:135` and `student_provider.dart:293` and `:308`. It is not a field of ClassModel.
- **`chatRoomId`** is written at `class_selection_screen.dart:134` and is not in the model.
- **`teacherUID`:** `functions/src/behaviorPoints.ts:74, :205, :319, :414 @ 7808a91` read `classData.teacherId || classData.teacherUID` (commented "legacy"). Nothing in `lib` reads or writes `teacherUID`.
- **Two class writers:** `class_provider.dart:426-442` writes a hand-built map that leaves out `semester`, `syllabusUrl`, `maxStudents` and `settings`, and uses server timestamps. `class_provider.dart:181` and `class_service.dart:46` write `toFirestore()`.

**Indexes:** `firestore.indexes.json` lines:
- 308: enrollmentCode + isActive
- 326: studentIds CONTAINS + isActive + name
- 348: studentIds CONTAINS + name
- 366: teacherId + isActive
- 384: teacherId + isActive + createdAt desc
- 406: teacherId + name

**Call sites:**
- `lib/features/classes/data/services/class_service.dart`. All go through `FirestoreRepository` with `collectionPath: 'classes'` (:22).
  - W: create (:46), update (:78), delete (:87), archive `isActive:false` (:93), enroll transaction writing `studentIds` (:162, :193), unenroll (:207, :231), new enrollment code (:247).
  - R: get (:65), getAll (:70), stream by `teacherId` (+`isActive`, order `createdAt`) (:105), stream by `studentIds` contains (+`isActive`, order `name`) (:124), by enrollmentCode + isActive (:140), stats by teacherId + isActive (:259), code uniqueness check (:310).
- `lib/features/classes/presentation/providers/class_provider.dart`
  - R: snapshots by teacherId (:92, :124), snapshots by studentIds (:145), get (:221, :248), enrollmentCode + isActive (:372).
  - W: add `toFirestore` (:181), update `toFirestore` (:195), delete (:210), enrollmentCode (:305), `studentIds` arrayRemove (:319), `isActive` false (:333) and true (:347), add hand-built map (:442), `studentIds` arrayUnion (:479).
- `lib/features/chat/presentation/screens/class_selection_screen.dart`: R by teacherId (:46), R by `students` (:51), R doc (:94), W `chatRoomId` (:132-134).
- `lib/features/classes/presentation/widgets/create_student_dialog.dart:131-137`: W studentIds, studentCount, updatedAt.
- `lib/features/student/presentation/providers/student_provider.dart:291, :306`: W studentIds and studentCount ±1.
- `lib/features/admin/data/services/bulk_import_service.dart:202`: W batch, studentIds.
- `lib/features/admin/data/services/user_management_service.dart`: W batch studentIds (:230), R orderBy name (:303), R studentIds contains (:329).
- `lib/features/assignments/presentation/providers/student_assignment_provider.dart:34`: R studentIds contains.
- `lib/features/grades/data/services/grade_analytics_service.dart:16`: R doc.
- `lib/shared/utils/fix_teacher_id.dart:24-40`: R where teacherId equals a hardcoded uid, then W batch teacherId.
- `lib/features/behavior_points/domain/services/behavior_points_service.dart`: subcollections only.
  - R `classes/{id}/studentPoints` (:138, :243) and `/history` (:209).
  - R `/behaviors` (:263), W `/behaviors` (:298, delete :333).
- `functions/src/adminFunctions.ts:149`: W batch studentIds arrayUnion.
- `functions/src/bulkImport.ts`: R doc (:167), R enrollmentCode + isActive (:180), W studentIds (:348), R all (:588), W studentIds (:648).
- `functions/src/behaviorPoints.ts`
  - R class doc (:64, :195, :309, :400).
  - `studentPoints/{id}/history`: R (:87, :214).
  - `studentPoints` aggregate: W set (:103), W update (:237), R (:333).

---

## students

**Shape (load-bearing), two models:**
- `lib/features/student/domain/models/student.dart:120-152 (Student.fromFirestore) @ 7808a91` and `:163-182 (toFirestore) @ 7808a91`.
  - Fields: `uid, username, temporaryPassword, accountClaimed, passwordChanged, backupEmail, email, firstName, lastName, displayName, gradeLevel` (int), `parentEmail, classIds[], photoURL, createdAt, updatedAt, isActive, metadata`.
- `lib/features/students/data/models/student_enhanced.dart:79-112 (StudentEnhanced.fromFirestore) @ 7808a91` and `:118-134 (toFirestore) @ 7808a91`.
  - Fields: `uid` (falls back to doc.id), `email, displayName, firstName, lastName, gender, avatarUrl, gradeLevel` (String), `classIds, createdAt, updatedAt, totalPoints, positivePoints, negativePoints, lastBehaviorUpdate`.

**Disagreements (load-bearing):**
- **Student vs StudentEnhanced:** `gradeLevel` is an int in one and a String in the other. The photo field is `photoURL` in one and `avatarUrl` in the other. The gender and behavior-points fields exist only in StudentEnhanced; the account fields exist only in Student.
  - Nothing in `lib` calls `StudentEnhanced.fromFirestore`. Its only import is `behavior_points/presentation/widgets/behavior_history_panel.dart:5`. Which collection it reads is UNVERIFIED.
- **`userId` vs `uid`:**
  - `auth/data/services/auth_service.dart:546-558 @ 7808a91` writes `id`, `userId` and `gradeLevel: 9` with merge.
  - `student_service.dart:91 (getStudentByUserId) @ 7808a91` queries `userId`.
  - `student_service.dart:545 (createStudentDocumentIfMissing) @ 7808a91` queries `uid`. The Student model reads `uid` and has no `userId`.
- **Index fields:** the `students` indexes at lines 1012 and 1030 are on `classIds` + `name`, but neither model has a `name` field.
  - `student_service.dart:154-155` queries `classIds` contains + orderBy `displayName`, and no index entry has that combination.
- **Student lists come from `users`:** `class_provider.dart:270-277` and `grade_analytics_service.dart:39-44` build `Student.fromFirestore` from `users` docs, not `students`. The same happens at `class_provider.dart:454-460`.

**Indexes:**
- 1012: classIds CONTAINS + name (COLLECTION_GROUP)
- 1030: same, COLLECTION
- 1048: gradeLevel + displayName
- 1066: isActive + displayName

**Call sites:**
- `lib/features/student/data/services/student_service.dart`. The collection is set at :36-37.
  - W: add (:52), update (:227), delete (:246), isActive false (:263), isActive true (:282), classIds arrayUnion (:304), classIds arrayRemove (:324), batch enroll (:350), batch unenroll (:379), batch set (:407), batch update (:433).
  - R: doc (:71), userId (:90), all by displayName (:112), isActive (:130), classIds contains (:153), gradeLevel (:173), full scan for search (:199), count (:457), isActive count (:473), class count (:493), stats (:513).
  - `createStudentDocumentIfMissing`: R by `uid` (:541-547), W add map (:579-603).
- `lib/features/classes/presentation/widgets/create_student_dialog.dart`: W `doc()` with a new id (:96), W `set(Student.toFirestore())` (:125-127).
- `lib/features/admin/data/services/bulk_import_service.dart:195`: W batch, classIds arrayUnion.
- `lib/features/auth/data/services/auth_service.dart`: W set with merge (:546), W delete (:628).
- Nothing in `functions/src` touches `students`.

---

## assignments

**Shape (load-bearing), two models:**
- `lib/features/assignments/domain/models/assignment.dart:222-265 (Assignment.fromFirestore) @ 7808a91` and `:277-297 (toFirestore) @ 7808a91`.
  - Fields: `teacherId, classId, title, description, instructions, dueDate, totalPoints, maxPoints, attachmentUrl, createdAt, updatedAt, type, status, category, teacherName, isPublished, allowLateSubmissions, latePenaltyPercentage, publishAt`.
  - `type` and `status` accept either `name` or `Enum.name` strings. Status values are `draft | active | completed | archived` (:17).
- `lib/features/assignments/domain/models/assignment_model.dart:34-49 (AssignmentModel.fromFirestore) @ 7808a91` and `:53-66 (toMap) @ 7808a91`.
  - Fields: `title, description, classId, className, subject, teacherId, dueDate, createdAt, hasSubmissions, needsGrading, totalPoints` (default 100), `attachments[]`.

**Disagreements (load-bearing):**
- AssignmentModel has `className`, `subject`, `hasSubmissions`, `needsGrading` and `attachments[]`. Assignment has `attachmentUrl` and none of those five.
  - Nothing in `lib` or `test` imports AssignmentModel or calls its `fromFirestore`.
  - `dashboard/data/services/dashboard_service.dart:77 @ 7808a91` queries `needsGrading == true`, a field only AssignmentModel declares.
- `assignment_provider.dart:54-62 @ 7808a91` writes a caller-supplied map plus `teacherId` and a server `createdAt`, not `Assignment.toFirestore()`.

**Indexes:**
- 40: classId + dueDate (COLLECTION_GROUP)
- 58: teacherId + createdAt desc (COLLECTION_GROUP)
- 76: classId + createdAt desc
- 94: classId + dueDate
- 112: classId + isPublished + dueDate
- 134: classId + status + dueDate
- 156: isPublished + publishAt
- 174: teacherId + createdAt desc

**Call sites:**
- `lib/features/assignments/data/services/assignment_service.dart`. Goes through the repository with `collectionPath: 'assignments'` (:23).
  - W: create (:34), update (:66), delete in a transaction that also deletes grades (:73-93), publish (:137), unpublish (:147), batch publish of scheduled assignments (:160-177), batch archive (:228-244).
  - R: get (:60), stream classId + isPublished order dueDate (:103), stream teacherId order createdAt (:113), classId whereIn + isPublished (:127), upcoming (:198), overdue (:213), stats (:253).
- `lib/features/assignments/presentation/providers/assignment_provider.dart`
  - R: teacherId + createdAt (:32), classId + dueDate (:79), snapshots (:106), doc (:131, :206).
  - W: add (:62), update (:166), delete (:188).
- `lib/features/assignments/presentation/providers/student_assignment_provider.dart`: R classId whereIn + dueDate (:51), R doc (:109).
- `lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart:671`: W delete.
- `lib/features/dashboard/data/services/dashboard_service.dart`
  - R teacherId + status (:68), R teacherId + needsGrading (:75), R limit(0) (:81).
  - R classId whereIn + status (:109), R classId whereIn + dueDate range (:116), R classId whereIn + status + dueDate order (:153).
- `lib/features/grades/data/services/grade_analytics_service.dart:26`: R classId.
- `lib/features/grades/presentation/providers/grade_provider.dart`: R teacherId (:46), R classId (:161).

---

## submissions

**Shape (load-bearing):** `lib/features/assignments/domain/models/submission.dart:79-100 (Submission.fromFirestore) @ 7808a91` and `:111-122 (toFirestore) @ 7808a91`.
- Fields: `assignmentId, studentId, studentName, fileUrl, fileName, textContent, submittedAt` (hard cast to Timestamp at :89), `gradedAt, updatedAt, status`.
- Status values are `submitted | graded | returned | late` (:177), defaulting to `submitted` (:98).

**Disagreements (load-bearing):**
- `grades/presentation/providers/grade_provider.dart:135-145 @ 7808a91` writes a nested `grade` map (`points, maxPoints, percentage, letter, feedback, gradedAt, gradedBy`). The Submission model has no `grade` field.
  - The same file queries `where('grade', isNotEqualTo: null)` (:105, :208).
  - `student_assignment_provider.dart:82, :132` derive `isGraded` from `submission['grade']`.
- `student_assignment_provider.dart:181-188 @ 7808a91` adds a submission without `status` and with `fileUrl: file?.path`.

**Indexes:** none. No `submissions` entry exists in `firestore.indexes.json`. `submission_service.dart` queries assignmentId + orderBy submittedAt (:127-128), studentId + orderBy submittedAt (:150-151), and assignmentId + submittedAt greater-than (:293-294).

**Call sites:**
- `lib/features/assignments/data/services/submission_service.dart`. The collection is set at :34-35.
  - W: add (:58), update `toFirestore` (:170-172), markGraded `gradedAt` (:189), delete (:209).
  - R: doc (:76), student + assignment (:100), assignment stream (:126), student stream (:149), count (:226), watch status (:272), late submissions (:292).
- `lib/features/assignments/presentation/providers/student_assignment_provider.dart`: R assignmentId + studentId (:73, :123), W add (:181).
- `lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart:677-682`: R by assignmentId, then W delete of each doc.
- `lib/features/grades/data/services/grade_analytics_service.dart:55`: R by assignmentId.
- `lib/features/grades/presentation/providers/grade_provider.dart`
  - R: assignmentId whereIn (:66, :177), passed as a collection reference (:73, :184), studentId + grade not null (:103), snapshots of grade not null (:207), studentId (:268).
  - W: update of the `grade` map (:135).

---

## grades (top-level, submission subcollection, collectionGroup) and archived_grades

**Shape (load-bearing):** `lib/features/grades/domain/models/grade.dart:265-293 (Grade.fromFirestore) @ 7808a91` and `:307-325 (toFirestore) @ 7808a91`.
- Fields: `assignmentId, studentId, studentName, teacherId, classId, pointsEarned, pointsPossible, percentage, letterGrade, feedback, status, gradedAt, returnedAt, createdAt, updatedAt, rubricScores, attachmentUrls`.
- Status values are `draft | pending | graded | returned | revised | notSubmitted` (:18).
- `toFirestore` always writes server timestamps for `createdAt` and `updatedAt` (:322-323). `fromFirestore` hard-casts both to Timestamp (:289-290).

**Disagreements (load-bearing):**
- **Top-level vs subcollection:**
  - Writes go only to top-level `grades` (`grade_service.dart` through the repository at :19).
  - `grade_analytics_service.dart:67-71 @ 7808a91` reads `submissions/{id}/grades` via `submissionDoc.reference.collection('grades')`. No write to that subcollection exists in `lib` or `functions/src`.
  - `grade_analytics_service.dart:464-468 @ 7808a91` runs `collectionGroup('grades')` on classId + gradedAt. A collection group covers every collection with that ID, both the top-level one and subcollections.
- **`isGraded`:** `dashboard_service.dart:176, :194 @ 7808a91` query `isGraded == true` on top-level `grades`. Grade has no `isGraded` field; it has `status`. Index line 682 (isGraded + studentId + gradedAt desc) supports that query.
- **Grades stored inside submissions:** the `grade` map written into `submissions` by `grade_provider.dart:135` is a second grade store, with field names `points/maxPoints/letter/gradedBy` instead of `pointsEarned/pointsPossible/letterGrade`.

**Indexes:**
- 548: classId + gradedAt (COLLECTION_GROUP)
- 566: studentId + classId + assignmentId (COLLECTION_GROUP)
- 588: assignmentId + status
- 606: classId + createdAt desc
- 624: classId + gradedAt
- 642: isGraded + studentId + gradedAt desc. Two entries carry this content, at 664 and 682; which line holds which is UNVERIFIED.
- 704: studentId + status + classId
- 722: the last grades entry; which shape it holds is UNVERIFIED.
- The parsed index list holds 10 `grades` entries and the file has 10 `grades` lines, but the exact pairing of lines 642-722 to shapes is UNVERIFIED. The remaining shapes are studentId + assignmentId, studentId + classId + assignmentId, and studentId + createdAt desc.
- No `archived_grades` index.

**Call sites:**
- `lib/features/grades/data/services/grade_service.dart` (repository, :19)
  - W: create (:28), update (:48), delete (:55), batch set (:116-119), batch update (:139-143), return `status/returnedAt` (:158-171), archive with set into `archived_grades` and delete from `grades` (:278-289).
  - R: get (:40), student + assignment (:64), assignment stream (:76), student stream (:85), class stream (:94), teacher (:103), assignment stats (:178), student stats (:199-214), class stats (:224), pending (:242), recent (:254), archive candidates (:270), teacher summary (:298).
- `lib/features/assignments/data/services/assignment_service.dart:82-89`: R top-level `grades` by assignmentId outside the transaction, then W `transaction.delete`.
- `lib/features/grades/data/services/grade_analytics_service.dart`: R the subcollection (:68), R the collectionGroup (:464).
- `lib/features/dashboard/data/services/dashboard_service.dart`: R studentId + isGraded order gradedAt (:174), R studentId + isGraded (:192).

---

## calendar_events

**Shape (load-bearing):** `lib/features/calendar/domain/models/calendar_event.dart:189-224 (CalendarEvent.fromFirestore) @ 7808a91` and `:229-255 (toFirestore) @ 7808a91`.
- Fields: `title, description, type, startTime, endTime, isAllDay, location, createdBy, createdByName, classId, assignmentId, participantIds[], participantEmails[], colorHex, recurrence, recurrenceEndDate, recurrenceDetails, hasReminder, reminderMinutes, metadata, createdAt, updatedAt, isActive`.
- `startTime`, `createdAt` and `updatedAt` are hard-cast to Timestamp.
- **Disagreement:** `calendar_service.dart:92-116` writes the same keys by hand with server timestamps rather than calling `toFirestore`. Whether that map includes `isActive` is UNVERIFIED (I read only to :116).

**Indexes:**
- 192: createdBy + isActive + startTime
- 214: participantIds CONTAINS + isActive + startTime
- 236: participantIds CONTAINS + startTime

**Call sites:** all in `lib/features/calendar/data/services/calendar_service.dart`.
- R: participantIds contains (:19), snapshots order startTime (:42), participantIds + startTime ≥ (:175), conflict check on participantIds + startTime ≤ (:229).
- W: add (:92), update (:136), delete (:152), update `toFirestore` (:263), delete (:279).

---

**Searched and not found:**
- I ran `git grep` @ 7808a91 over `lib` and `functions/src` for `collection(`/`collectionGroup(` with each name, plus `FirestoreRepository collectionPath` and `getCollectionReference`.
- There are no `students`, `assignments`, `submissions`, `grades` or `calendar_events` sites in `functions/src`, and no writer of `submissions/{id}/grades`.
- There are no `submissions` or `archived_grades` index entries, and no `fieldOverrides` for these collections.
- I used 12 of the 15-file budget. The model files and the service query fields were read through `git grep` excerpts, not full opens.