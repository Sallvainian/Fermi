---
title: Parity inventory
type: companion
for: initiative-capacitor-supabase-port
created: 2026-11-05
---

# Parity inventory

What the port keeps, drops and must not repeat. Each line cites the research at `research-firebase-backend-auth-rules-collections/research-firebase-backend-auth-rules-collections.md` (Q = question section) or the brief at `brief-port-goals.md` (C, D ids). Code citations are at 7808a91; the research holds the rest.

## In scope: what the Firebase app does today, by requirement

"New" means Fermi has nothing for it today.

| Req | Firebase pieces behind it today | Source |
|---|---|---|
| R1 | `AuthService.signInWithGoogle`; `autoAssignRole` (`beforeUserCreated`) and `DOMAIN_ROLE_MAPPINGS` give way to invite codes; Apple sign-in is new (only `reauthenticateWithApple` existed) | Q1, Q2, D6, D7 |
| R2 | `AuthProvider._processUser` (role from `users.role`, sign-out when null); router redirects; `/dashboard` picks by role | Q1 |
| R3 | `profile_completion_dialog`; Storage `users/{uid}/profile/avatar.jpg` | Q4, Q5 |
| R4 | `classes` (`teacherId`, `studentIds`, `enrollmentCode`, `isActive`); `ClassService`, `ClassProvider`; the roster name match is new | Q3, Q6, D17 |
| R5 | `create_student_dialog`, `student_provider.createStudent`, `students`; `bulkImportStudents` callable (CSV, 1000-row cap, class by id or enrollment code); rows become roster names, not accounts | Q5, Q6, Q9, D18 |
| R6 | `assignments` (`attachmentUrl`), `submissions` (text; `fileUrl` stores a local path, so files never upload), `grades`; `AssignmentService`, `SubmissionService`, `GradeService`, `grade_provider`; Google Drive is new | Q3, Q6, D10, D12 |
| R7 | `classes/{c}/behaviors`, `studentPoints`, `history`; callables `awardBehaviorPoints`, `undoBehaviorPoints`, `getClassPointsSummary`, `getBehaviorHistory` | Q8, Q10 |
| R8 | `calendar_events` (`createdBy`, `participantIds`) | Q3, Q6 |
| R9 | `discussion_boards` / `threads` / `replies` / `likes` and their counters | Q3, Q7 |
| R10 | `chatRooms` list, groups, class chat; `conversations/{id}/messages`, `typing`; callables `sendMessage`, `markMessagesAsRead`, `updateTypingStatus`, `uploadChatFile` | Q4, Q7, Q10 |
| R11 | `FirebaseMessagingService` (iOS); `sendPushNotifications` reading `users.fcmToken` | Q11 |
| R12 | `presence/{uid}` (`online`, `lastSeen`); admin online count | Q5 |
| R13 | `bug_reports` add from `contact_support_screen` | Q5 |
| R14 | `notifications` via `FirebaseNotificationService` (`isRead`); `NotificationsScreen` routed at `app_router.dart:585`, `:599` | Q5 |
| R15 | `UserManagementService`, `AdminProvider`; callables `createTeacherAccount` (gives way to teacher invite codes), `deleteUserAccount`; client-side system stats | Q5, Q9, Q12, D15 |
| R16 | `scheduled_messages` (`chatRoomId`, `createdAt`, embedded `message`); `ScheduledMessagesService.scheduleMessage` (`scheduled_messages_service.dart:97`); nothing delivers them | Q5, D10 |
| R17 | `WebNotificationHandler`, a 4-second SnackBar (`web_notification_handler.dart:27-61`); its listener filters `read` while writers write `isRead` | Q5, Q11, D10 |
| R18 | `GradeAnalyticsService.generateClassAnalytics` (`grade_analytics_service.dart:12`) and `getGradeTrends` (`:456`); models `GradeAnalytics`, `StudentPerformance`, `AssignmentStats`, `GradeTrend`, `CategoryPerformance`; reads `classes.students` and a `submissions/{id}/grades` subcollection nothing writes | Q6, D10 |
| R19 | `DashboardService` (`dashboard_service.dart`): teacher and student activities, assignment stats, upcoming assignments, recent grades, GPA; queries `assignments.needsGrading` and `grades.isGraded`, which nothing writes; `activities` has no writer for `teacherId` | Q6, Q8, D10 |
| R20 | "Announcements" board category (`create_board_dialog.dart:24`), thread type, `NotificationType.announcement`; the `announcements` collection has only a rule (`firestore.rules:385-388`) | Q3, D11 |
| R21 | `GradeService.archiveOldGrades` (`grade_service.dart:266`) moves returned grades older than 180 days to `archived_grades`; it has no caller, and nothing reads the archive | D13 |
| R22 | New | D14 |
| R23 | New; follows My-Love's `src/services/nativeUpdates.ts` and `scripts/package-live-update.sh` | D9 |
| R24 | New; web never registers for push today | Q11, D9 |
| R25 | New | D6, D9 |

## Out of scope

**By decision** (brief D1, D2, D4, D5, D7, D11, D12, D15):
- macOS, Windows and Linux builds; `DirectDesktopOAuthHandler`, `SecureDesktopOAuthHandler`, `DesktopOAuthHandler`; `getOAuthUrl`, `exchangeOAuthCode`, `refreshOAuthToken`; `oauth_pkce_challenges`, `_rate_limits`, `cleanupExpiredPKCEChallenges`, `manualPKCECleanup` (Q1, Q8, Q9)
- Android, including Android push and FCM (D5, Q11)
- Any Firebase Auth or Firestore data migration; `migrateAllUserRoles`, `migrateUserRoles`, `migrateUsernamesToPublic`, `migrateUsernamesHttp`, `migrateStudentClassEnrollment` (Q2, Q9, Q10)
- Jeopardy entirely: both `SimpleJeopardyProvider` classes, the games screen, `jeopardy_games`, `jeopardy_questions`, `jeopardy_sessions` (Q8)
- `calls` and `candidates`; `games` and `scores` (D11)
- Email/password sign-in, password reset and `teacher_password_reset_screen` (`needsPasswordReset`); `resetUserPassword`; the MailChannels email worker (D7, D15, Q1, Q9)
- The `files` indexes (`ownerId`, `parentFolder`, `createdAt`): no folder file manager (D12)
- The `teachers` collection: only a rule (`firestore.rules:621`), no code

**Unreachable today** (brief D3):
- Username sign-in (`signInWithUsername` has no caller); `public_usernames` login lookup (Q1, Q5)
- Push tap-to-open (`setNavigationCallback` has no caller); local notifications (`.show(` never called) (Q11)
- `setRoleClaim`, `syncUserRole`, `UserRoleClaims`, `runUserRoleMigration` (Q2)
- `createAdminAccount`, `getSystemStats` callables (no client caller) (Q12)
- Firebase Realtime Database (initialized, never used) (Q1)
- Storage paths `chat_images/`, `chat_videos/`, `public/` (no code uses them) (Q4)
- Legacy `chat_rooms` collection (Q7)
- `AssignmentModel`, `StudentEnhanced`, `StudentPoints`, `Notification` serializers, `Message.fromFirestore` (Q5, Q6, Q7, Q8)

**Always broken today and not named back in** (brief D3, D10):
- Admin `createStudentAccount` from `AdminProvider` (sends `username`, server needs `email`) (Q12)
- Admin role change (`updateUserRole` callable does not exist) (Q2, Q12)

## Defects the Supabase design must not repeat (K4, K5)

| Today | Research |
|---|---|
| An owner can update their own `users` document with no field limit, `role` included | Q3 |
| The role lives in two places (`users.role` and a custom claim) that diverge; admin claims never sync | Q2 |
| `setRoleClaim` lets any signed-in user make themselves a teacher | Q2 |
| Google sign-in skips the client's role gate, so the server alone must refuse | Q1, Q2 |
| Any student can read every `users` document; any signed-in user can read every class | Q3 |
| An enrolled student can read every classmate's points and history through the class catch-all | Q3 |
| A student can rewrite a class's `studentIds` without the result containing them or keeping others | Q3 |
| `teacherId` ownership checks on class create and delete are non-binding; assignment `classId` is not tied to its teacher; update can change `teacherId` | Q3 |
| A student can create a submission for any assignment, with no enrollment check | Q3 |
| 15 rule conditions are a placeholder `true`; duplicated `discussion_boards` blocks make the looser one win | Q3 |
| Reply `likeCount` update passes with any other keys changed (missing parentheses) | Q3 |
| `chatRooms` read by any signed-in user; chatRoom messages deletable by any signed-in user | Q3 |
| Chat file size checked against the client's declared `fileSize`, not the bytes; `image/jpg` rejected for `.jpg` | Q4, Q10 |
| Chat attachment URLs are signed until year 2500 | Q4, Q10 |
| Bulk import writes `users` for every row, not only accounts that were created | Q9 |
| Callables rethrow every error as `internal`, hiding `permission-denied` | Q2, Q10 |
| `awardBehaviorPoints` has no type or range check on `points` | Q10 |
| Push token kept on the user row, one per user, never removed at logout | Q11 |
| Nothing tests rules, functions or auth; CI runs no tests | Q13 |

## Data-shape conflicts the new schema settles once

Each pair below is one concept stored two ways today; the port picks one.

| Concept | Today | Research |
|---|---|---|
| Profile photo | `photoURL` (writers) vs `photoUrl` (chat readers) vs `avatarUrl` | Q5, Q6 |
| Class enrollment | `classes.studentIds` vs `users.enrolledClassIds` vs `users.enrolledClasses` + `classId` vs `classes.students` | Q5, Q6 |
| Display name | `displayName` vs `name` | Q5 |
| Student record | `users` documents vs `students` (two models, `gradeLevel` int vs string, `uid` vs `userId`) | Q6 |
| Grade | top-level `grades` (`pointsEarned`, `letterGrade`) vs `submissions.grade` map (`points`, `letter`) vs `submissions/{id}/grades` (read by analytics, never written) | Q6 |
| Chat | `chatRooms` (`senderId`, `timestamp`, `participantIds`) vs `conversations` (`authorId`, `createdAt`, `participants`) | Q7 |
| Notification read flag | `isRead` vs `read`; `message`/`actionData` vs `body`/`data` | Q5 |
| Behavior history time | `timestamp` (filtered) vs `awardedAt` (ordered and indexed) | Q8 |
| Push token | `users.fcmToken` (read by server) vs `fcm_tokens/{uid}` (never read) | Q5, Q11 |
| Activity owner | top-level `userId` (client) vs `details.userId` (server); `type` values outside `ActivityType` | Q8 |
