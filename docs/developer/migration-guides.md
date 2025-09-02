# Migration Guides

Comprehensive guides for upgrading and migrating the Fermi Flutter application across different versions and major framework updates.

## Table of Contents
- [Flutter Framework Migrations](#flutter-framework-migrations)
- [Firebase SDK Migrations](#firebase-sdk-migrations)
- [Dart Language Migrations](#dart-language-migrations)
- [Dependency Updates](#dependency-updates)
- [Architecture Migrations](#architecture-migrations)
- [Breaking Changes](#breaking-changes)

## Flutter Framework Migrations

### Flutter 3.24 to 3.27 Migration

#### Preparation Steps
```bash
# Check current Flutter version
flutter --version

# Update Flutter
flutter upgrade

# Check for deprecation warnings
flutter analyze --no-sound-null-safety
```

#### Key Changes and Updates

##### Material Design 3 Updates
```dart
// Old (Material 2)
ThemeData(
  primarySwatch: Colors.blue,
  accentColor: Colors.blueAccent,
)

// New (Material 3)
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  ),
)
```

##### Widget Constructor Changes
```dart
// Old: Deprecated constructors
AppBar(
  backgroundColor: Colors.blue,
  foregroundColor: Colors.white,
)

// New: Updated constructors
AppBar(
  backgroundColor: Theme.of(context).colorScheme.primary,
  foregroundColor: Theme.of(context).colorScheme.onPrimary,
)
```

#### Required Code Updates

##### Update Theme Configuration
```dart
// lib/config/theme.dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0175C2),
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0175C2),
      brightness: Brightness.dark,
    ),
  );
}
```

##### Update Button Usage
```dart
// Old: Deprecated buttons
RaisedButton(
  onPressed: () {},
  child: Text('Submit'),
)

FlatButton(
  onPressed: () {},
  child: Text('Cancel'),
)

// New: Modern buttons
FilledButton(
  onPressed: () {},
  child: Text('Submit'),
)

TextButton(
  onPressed: () {},
  child: Text('Cancel'),
)
```

#### Testing the Migration
```bash
# Run tests after migration
flutter test

# Check for visual regressions
flutter run --profile
flutter drive --target=test_driver/app.dart
```

### Flutter 4.0 Preparation (Future)

#### Expected Breaking Changes
1. **Null Safety**: Complete migration to null safety
2. **Widget Tree**: Potential widget tree optimizations
3. **Platform Support**: Updates to platform-specific code
4. **Performance**: New rendering optimizations

#### Preparation Checklist
- [ ] Audit deprecated API usage
- [ ] Update to latest stable dependencies
- [ ] Ensure 100% null safety compliance
- [ ] Test on all target platforms
- [ ] Update CI/CD pipelines

## Firebase SDK Migrations

### Firebase 10.x to 11.x Migration

#### SDK Version Updates
```yaml
# pubspec.yaml - Update versions
dependencies:
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.4
  cloud_firestore: ^5.2.1
  firebase_storage: ^12.1.3
  firebase_messaging: ^15.0.4
```

#### Authentication Changes

##### FirebaseAuth API Updates
```dart
// Old: Deprecated methods
final user = FirebaseAuth.instance.currentUser();
final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);

// New: Updated methods
final user = FirebaseAuth.instance.currentUser;
final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);
final user = credential.user;
```

##### Authentication State Handling
```dart
// Old: authStateChanges only
FirebaseAuth.instance.authStateChanges().listen((user) {
  // Handle auth state change
});

// New: Combined state listening
FirebaseAuth.instance.userChanges().listen((user) {
  // Handles both auth state and user profile changes
});

// Or use specific streams
FirebaseAuth.instance.authStateChanges().listen((user) {
  // Auth state only
});

FirebaseAuth.instance.idTokenChanges().listen((user) {
  // Token changes
});
```

#### Firestore Changes

##### Query Syntax Updates
```dart
// Old: Deprecated query methods
final query = FirebaseFirestore.instance
    .collection('assignments')
    .where('classId', isEqualTo: classId)
    .orderBy('createdAt', descending: true)
    .limit(20);

// New: Same syntax (no changes needed)
final query = FirebaseFirestore.instance
    .collection('assignments')
    .where('classId', isEqualTo: classId)
    .orderBy('createdAt', descending: true)
    .limit(20);
```

##### Security Rules Updates
```javascript
// Old: Rules v1
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth.uid != null;
    }
  }
}

// New: Rules v2 (required for Firebase 10+)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /assignments/{assignmentId} {
      allow read: if isEnrolledStudent() || isTeacher();
      allow write: if isTeacher() && isClassOwner();
    }
    
    function isEnrolledStudent() {
      return request.auth != null && 
             exists(/databases/$(database)/documents/enrollments/$(request.auth.uid));
    }
    
    function isTeacher() {
      return request.auth != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'teacher';
    }
  }
}
```

#### Storage Changes

##### Upload Methods
```dart
// Old: UploadTask handling
final uploadTask = FirebaseStorage.instance
    .ref()
    .child('assignments/${assignment.id}')
    .putFile(file);

uploadTask.events.listen((event) {
  // Handle upload progress
});

// New: Simplified upload handling
final ref = FirebaseStorage.instance.ref('assignments/${assignment.id}');
final uploadTask = ref.putFile(file);

uploadTask.snapshotEvents.listen((snapshot) {
  final progress = snapshot.bytesTransferred / snapshot.totalBytes;
  print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
});
```

## Dart Language Migrations

### Dart 3.0 to 3.5 Migration

#### New Language Features

##### Pattern Matching
```dart
// Old: Traditional conditional logic
String getAssignmentStatus(Assignment assignment) {
  if (assignment.isCompleted) {
    return 'Completed';
  } else if (assignment.dueDate.isBefore(DateTime.now())) {
    return 'Overdue';
  } else if (assignment.dueDate.difference(DateTime.now()).inDays <= 1) {
    return 'Due Soon';
  } else {
    return 'Pending';
  }
}

// New: Pattern matching
String getAssignmentStatus(Assignment assignment) {
  return switch (assignment) {
    Assignment(isCompleted: true) => 'Completed',
    Assignment(dueDate: var date) when date.isBefore(DateTime.now()) => 'Overdue',
    Assignment(dueDate: var date) when date.difference(DateTime.now()).inDays <= 1 => 'Due Soon',
    _ => 'Pending',
  };
}
```

##### Records
```dart
// Old: Custom classes for simple data
class UserInfo {
  final String name;
  final String email;
  final int age;
  
  const UserInfo(this.name, this.email, this.age);
}

// New: Records
typedef UserInfo = (String name, String email, int age);

UserInfo getUserInfo(String userId) {
  // Return record
  return ('John Doe', 'john@example.com', 25);
}

// Usage
final (name, email, age) = getUserInfo('123');
```

##### Destructuring
```dart
// Old: Manual property access
void processAssignment(Assignment assignment) {
  final title = assignment.title;
  final dueDate = assignment.dueDate;
  final points = assignment.totalPoints;
  
  // Process assignment
}

// New: Destructuring
void processAssignment(Assignment assignment) {
  final Assignment(
    title: title,
    dueDate: dueDate,
    totalPoints: points,
  ) = assignment;
  
  // Process assignment
}
```

#### Null Safety Improvements

##### Enhanced Null Safety
```dart
// Old: Null-aware operators
String? getName() => user?.displayName ?? user?.email?.split('@').first;

// New: Enhanced null-aware cascades
String? getName() => user?..displayName ??= user?.email?.split('@').first;
```

## Dependency Updates

### Major Package Migrations

#### Provider 6.x to 7.x Migration
```dart
// Old: ChangeNotifierProvider
ChangeNotifierProvider(
  create: (context) => AssignmentProvider(),
  child: MyApp(),
)

// New: Enhanced provider with better performance
ChangeNotifierProvider<AssignmentProvider>.value(
  value: AssignmentProvider(),
  child: MyApp(),
)

// Multi-provider updates
MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
    ),
    ChangeNotifierProxyProvider<AuthProvider, AssignmentProvider>(
      create: (context) => AssignmentProvider(),
      update: (context, auth, previous) => 
          previous ?? AssignmentProvider()..updateAuth(auth),
    ),
  ],
  child: MyApp(),
)
```

#### GoRouter 13.x to 14.x Migration
```dart
// Old: Route definitions
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/assignments',
      builder: (context, state) => AssignmentScreen(),
      routes: [
        GoRoute(
          path: '/:id',
          builder: (context, state) => AssignmentDetailScreen(
            assignmentId: state.params['id']!,
          ),
        ),
      ],
    ),
  ],
);

// New: Enhanced route definitions with type safety
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/assignments',
      name: 'assignments',
      builder: (context, state) => const AssignmentScreen(),
      routes: [
        GoRoute(
          path: '/:id',
          name: 'assignment-detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AssignmentDetailScreen(assignmentId: id);
          },
        ),
      ],
    ),
  ],
);
```

## Architecture Migrations

### Clean Architecture Refactoring

#### From Feature-First to Layer-First
```
# Old Structure
lib/features/
├── auth/
│   ├── auth_screen.dart
│   ├── auth_provider.dart
│   └── auth_service.dart
├── assignments/
│   ├── assignment_screen.dart
│   ├── assignment_provider.dart
│   └── assignment_service.dart

# New Structure
lib/
├── data/
│   ├── repositories/
│   │   ├── auth_repository_impl.dart
│   │   └── assignment_repository_impl.dart
│   └── datasources/
│       ├── auth_remote_datasource.dart
│       └── assignment_remote_datasource.dart
├── domain/
│   ├── entities/
│   │   ├── user.dart
│   │   └── assignment.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   └── assignment_repository.dart
│   └── usecases/
│       ├── sign_in_user.dart
│       └── create_assignment.dart
└── presentation/
    ├── screens/
    │   ├── auth_screen.dart
    │   └── assignment_screen.dart
    └── providers/
        ├── auth_provider.dart
        └── assignment_provider.dart
```

#### Repository Pattern Implementation
```dart
// Old: Direct service calls
class AssignmentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> loadAssignments(String classId) async {
    final snapshot = await _firestore
        .collection('assignments')
        .where('classId', isEqualTo: classId)
        .get();
    
    // Process data
  }
}

// New: Repository pattern
abstract class AssignmentRepository {
  Future<List<Assignment>> getAssignments(String classId);
  Future<Assignment> createAssignment(Assignment assignment);
  Future<void> updateAssignment(Assignment assignment);
  Future<void> deleteAssignment(String id);
}

class AssignmentRepositoryImpl implements AssignmentRepository {
  final AssignmentRemoteDataSource _remoteDataSource;
  final AssignmentLocalDataSource _localDataSource;
  
  const AssignmentRepositoryImpl({
    required AssignmentRemoteDataSource remoteDataSource,
    required AssignmentLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;
  
  @override
  Future<List<Assignment>> getAssignments(String classId) async {
    try {
      final assignments = await _remoteDataSource.getAssignments(classId);
      await _localDataSource.cacheAssignments(assignments);
      return assignments;
    } catch (e) {
      // Fallback to cached data
      return await _localDataSource.getCachedAssignments(classId);
    }
  }
}

class AssignmentProvider extends ChangeNotifier {
  final AssignmentRepository _repository;
  
  const AssignmentProvider({required AssignmentRepository repository})
      : _repository = repository;
  
  Future<void> loadAssignments(String classId) async {
    _setLoading(true);
    try {
      final assignments = await _repository.getAssignments(classId);
      _assignments = assignments;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }
}
```

## Breaking Changes

### Flutter 3.24 Breaking Changes

#### Navigator 2.0 Mandatory
```dart
// Old: Navigator 1.0 (deprecated)
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => AssignmentScreen()),
);

// New: GoRouter (recommended)
context.go('/assignments');
```

#### Material Design 3 Default
```dart
// Old: Material 2 default
MaterialApp(
  theme: ThemeData(
    primarySwatch: Colors.blue,
  ),
)

// New: Material 3 default (explicit)
MaterialApp(
  theme: ThemeData(
    useMaterial3: true, // Now default
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  ),
)
```

### Firebase Breaking Changes

#### Authentication Changes
```dart
// Old: Deprecated methods
await FirebaseAuth.instance.signOut();
final user = FirebaseAuth.instance.currentUser();

// New: Updated methods  
await FirebaseAuth.instance.signOut();
final user = FirebaseAuth.instance.currentUser; // Property, not method
```

## Migration Checklist

### Pre-Migration Steps
- [ ] Create backup branch
- [ ] Document current functionality
- [ ] Run full test suite
- [ ] Check dependency compatibility
- [ ] Review breaking changes documentation

### Migration Process
- [ ] Update Flutter SDK
- [ ] Update dependencies
- [ ] Fix compilation errors
- [ ] Update deprecated API usage
- [ ] Run analyzer and fix warnings
- [ ] Update tests
- [ ] Test on all platforms

### Post-Migration Verification
- [ ] All tests pass
- [ ] No analyzer warnings
- [ ] App builds successfully on all platforms
- [ ] No runtime errors
- [ ] Performance hasn't degraded
- [ ] UI looks correct on all screen sizes

### Rollback Plan
```bash
# If migration fails, rollback steps:
git checkout main
flutter clean
flutter pub get
flutter test

# Document issues for future attempt
# Create GitHub issue with migration blockers
```

[content placeholder]