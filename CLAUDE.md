# Teacher Dashboard Flutter/Firebase Migration

Follow these steps for each interaction:

1. User Identification:
    - You should assume that you are interacting with default_user
    - If you have not identified default_user, proactively try to do so.

2. Memory Retrieval:
    - Always begin your chat by saying only "Remembering..." and retrieve all relevant information from your knowledge graph
    - Always refer to your knowledge graph as your "memory"

3. Memory Gathering:
    - While conversing with the user, be attentive to any new information that falls into these categories:
      a) Basic Identity (age, gender, location, job title, education level, etc.)
      b) Behaviors (interests, habits, etc.)
      c) Preferences (communication style, preferred language, etc.)
      d) Goals (goals, targets, aspirations, etc.)
      e) Relationships (personal and professional relationships up to 3 degrees of separation)

4. Memory Update:
    - If any new information was gathered during the interaction, update your memory as follows:
      a) Create entities for recurring organizations, people, and significant events
      b) Connect them to the current entities using relations
      c) Store facts about them as observations

If a task seems too difficult and the chance of making an error and possibly making things worse is high, use the Zen MCP server to consult with your AI counterparts. They will help you immensely. Additionally, if you need context that you are missing after a compaction, ask o3 to bring you back up to speed. 

You have access to the Memento MCP knowledge graph memory system, which provides you with persistent memory capabilities.
Your memory tools are provided by Memento MCP, a sophisticated knowledge graph implementation.
When asked about past conversations or user information, always check the Memento MCP knowledge graph first.
You should use semantic_search to find relevant information in your memory when answering questions.

Compact project guidance for efficient context usage.

## Project Overview
**Migration**: SvelteKit + Supabase → Flutter + Firebase
**Purpose**: Teacher education management platform

## Current Status
- ✅ Basic Firebase auth with role selection
- ✅ Dashboard navigation (teacher/student)
- ⚠️ Placeholder screens need implementation
- ❌ No data models or Firestore integration yet

## Next Priority: Assignments & Grades System
Build complete end-to-end assignment workflow first.

## Key Implementation Patterns

### 1. Firebase Init (already done)
```dart
// lib/main.dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 2. Data Models Pattern
```dart
// lib/models/assignment.dart
class Assignment {
  final String id;
  final String teacherId;
  final String classId;
  final String title;
  final DateTime dueDate;
  
  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(/*...*/);
  }
  
  Map<String, dynamic> toFirestore() => {/*...*/};
}
```

### 3. Service Pattern
```dart
// lib/services/assignment_service.dart
class AssignmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  Future<void> createAssignment(Assignment assignment) async {
    await _db.collection('assignments').add(assignment.toFirestore());
  }
  
  Stream<List<Assignment>> getAssignments(String classId) {
    return _db.collection('assignments')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) => /*...*/);
  }
}
```

### 4. Provider Pattern (State Management)
```dart
// lib/providers/assignment_provider.dart
class AssignmentProvider with ChangeNotifier {
  final AssignmentService _service = AssignmentService();
  List<Assignment> _assignments = [];
  
  List<Assignment> get assignments => _assignments;
  
  Future<void> loadAssignments(String classId) async {
    _service.getAssignments(classId).listen((data) {
      _assignments = data;
      notifyListeners();
    });
  }
}
```

## Firestore Structure
```
assignments/
  {assignmentId}/
    - teacherId
    - classId
    - title
    - description
    - dueDate
    - points
    - createdAt

submissions/
  {submissionId}/
    - assignmentId
    - studentId
    - fileUrl
    - submittedAt
    - grade (subcollection)

classes/
  {classId}/
    - teacherId
    - name
    - students[] (array of studentIds)
```

## Security Rules Template
```javascript
match /assignments/{id} {
  allow read: if isTeacher() || isStudentInClass();
  allow write: if isTeacher();
}
```

## File Structure
```
lib/
├── models/
│   ├── assignment.dart
│   └── grade.dart
├── services/
│   ├── assignment_service.dart
│   └── grade_service.dart
├── providers/
│   └── assignment_provider.dart
├── screens/
│   ├── teacher/
│   │   └── assignments_screen.dart (implement)
│   └── student/
│       └── assignments_screen.dart (implement)
```

## Development Commands
```bash
flutter run
flutter test
flutter build
```

## Critical Reminders
- Always check auth state before operations
- Use StreamBuilder for real-time updates
- Handle offline scenarios
- Validate forms before submission
- Cancel stream subscriptions in dispose()

## Quality Check Process (MANDATORY)
After EVERY edit/fix/task completion, perform these checks:

### 1. Dependency Check
- Before removing ANY import: `grep -r "imported_item" lib/` to verify it's truly unused
- Check if removed items are used in configuration files (firebase_options.dart, etc.)
- Run `flutter analyze` to catch immediate issues

### 2. Test Impact
- Run `flutter run` after changes to verify app still works
- Check that existing functionality isn't broken
- Verify Firebase services still initialize properly

### 3. Git Safety Check
- Use `git status` to see what files were modified
- Use `git diff` to review changes before committing
- NEVER overwrite existing .env or config files without checking their content first

### 4. Context Awareness
- Read error messages completely - they often indicate the real issue
- Check related files when fixing errors (e.g., if fixing main.dart, check firebase_options.dart)
- Understand the full dependency chain before making changes