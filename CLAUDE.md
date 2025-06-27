# CLAUDE.md - Teacher Dashboard Flutter/Firebase Migration

This file provides guidance to Claude Code when working on the Teacher Dashboard Flutter/Firebase migration project.

## Project Overview

**Teacher Dashboard Flutter/Firebase Migration** - A comprehensive migration from SvelteKit + Supabase to Flutter + Firebase for a teacher education management platform.

### Tech Stack Migration
- **FROM**: SvelteKit 5, TypeScript, Supabase, Tailwind CSS, Netlify
- **TO**: Flutter, Dart, Firebase (Firestore, Auth, Storage, Functions), Firebase Hosting

## Firebase Flutter Documentation Summary

### Core Setup & Configuration

#### 1. FlutterFire Installation
```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Add Firebase Core to Flutter project
flutter pub add firebase_core

# Configure Firebase for Flutter
flutterfire configure
```

#### 2. Firebase Initialization
```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

#### 3. Firebase Services Setup

**Authentication:**
```bash
flutter pub add firebase_auth
```

```dart
import 'package:firebase_auth/firebase_auth.dart';

// Email/Password sign in
Future<User?> signInWithEmail(String email, String password) async {
  try {
    final credential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  } catch (e) {
    print('Sign in failed: $e');
    return null;
  }
}

// Listen to auth state changes
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user == null) {
    print('User is currently signed out!');
  } else {
    print('User is signed in!');
  }
});
```

**Firestore Database:**
```bash
flutter pub add cloud_firestore
```

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Initialize Firestore
final db = FirebaseFirestore.instance;

// Add data
Future<void> addStudent(String name, String grade) async {
  await db.collection('students').add({
    'name': name,
    'grade': grade,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

// Real-time listening
Stream<QuerySnapshot> getStudents() {
  return db.collection('students').snapshots();
}

// Query data
Future<List<DocumentSnapshot>> getStudentsByGrade(String grade) async {
  final querySnapshot = await db
      .collection('students')
      .where('grade', isEqualTo: grade)
      .get();
  return querySnapshot.docs;
}
```

**Firebase Storage:**
```bash
flutter pub add firebase_storage
```

```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

final storage = FirebaseStorage.instance;

// Upload file
Future<String> uploadFile(String path, File file) async {
  try {
    final ref = storage.ref().child(path);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  } catch (e) {
    throw Exception('Upload failed: $e');
  }
}

// Download URL
Future<String> getDownloadURL(String path) async {
  return await storage.ref().child(path).getDownloadURL();
}
```

**Cloud Functions:**
```bash
flutter pub add cloud_functions
```

```dart
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instance;

// Call a function
Future<String> callFunction(Map<String, dynamic> data) async {
  try {
    final callable = functions.httpsCallable('myFunction');
    final result = await callable.call(data);
    return result.data;
  } catch (e) {
    print('Function call failed: $e');
    throw e;
  }
}
```

## Migration-Specific Guidelines

### Data Model Migration (Supabase → Firestore)

#### Current Supabase Tables → Firebase Collections
```dart
// students table → students collection
class Student {
  final String id;
  final String userId;
  final String name;
  final String gradeLevel;
  final String parentEmail;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.userId,
    required this.name,
    required this.gradeLevel,
    required this.parentEmail,
    required this.createdAt,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      gradeLevel: data['gradeLevel'] ?? '',
      parentEmail: data['parentEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'gradeLevel': gradeLevel,
      'parentEmail': parentEmail,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// grades table → grades subcollection
class Grade {
  final String id;
  final String studentId;
  final String assignmentId;
  final double points;
  final String feedback;
  final DateTime gradedAt;

  Grade({
    required this.id,
    required this.studentId,
    required this.assignmentId,
    required this.points,
    required this.feedback,
    required this.gradedAt,
  });

  factory Grade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Grade(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      assignmentId: data['assignmentId'] ?? '',
      points: (data['points'] ?? 0).toDouble(),
      feedback: data['feedback'] ?? '',
      gradedAt: (data['gradedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'assignmentId': assignmentId,
      'points': points,
      'feedback': feedback,
      'gradedAt': FieldValue.serverTimestamp(),
    };
  }
}
```

### Firebase Security Rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Teachers can manage their classes
    match /classes/{classId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == resource.data.teacherId;
      
      // Students can read their grades
      match /grades/{gradeId} {
        allow read: if request.auth != null 
          && request.auth.uid == resource.data.studentId;
        allow write: if request.auth != null 
          && request.auth.token.role == 'teacher';
      }
    }
    
    // Messages - users can read/write their conversations
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null 
        && request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read: if request.auth != null 
          && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
        allow create: if request.auth != null 
          && request.auth.uid == request.resource.data.senderId;
      }
    }
  }
}

// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Teachers can upload files to their folders
    match /teachers/{teacherId}/{allPaths=**} {
      allow read, write: if request.auth != null 
        && request.auth.uid == teacherId;
    }
    
    // Students can read shared files
    match /shared/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
        && request.auth.token.role == 'teacher';
    }
  }
}
```

### State Management with Provider/Riverpod
```dart
// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    _user = user;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// Usage in main.dart
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MyApp(),
    ),
  );
}
```

## Flutter Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── models/
│   ├── student.dart
│   ├── grade.dart
│   ├── assignment.dart
│   └── user.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── storage_service.dart
│   └── messaging_service.dart
├── providers/
│   ├── auth_provider.dart
│   ├── gradebook_provider.dart
│   └── chat_provider.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── gradebook/
│   │   ├── gradebook_screen.dart
│   │   └── grade_entry_screen.dart
│   └── chat/
│       └── chat_screen.dart
├── widgets/
│   ├── common/
│   │   ├── loading_widget.dart
│   │   └── error_widget.dart
│   ├── gradebook/
│   │   └── grade_table.dart
│   └── chat/
│       └── message_bubble.dart
└── utils/
    ├── constants.dart
    ├── helpers.dart
    └── validators.dart
```

## Performance Best Practices

### Firestore Optimization
```dart
// Use pagination for large collections
Query getPaginatedStudents({DocumentSnapshot? lastDoc, int limit = 20}) {
  Query query = FirebaseFirestore.instance
      .collection('students')
      .orderBy('name')
      .limit(limit);
  
  if (lastDoc != null) {
    query = query.startAfterDocument(lastDoc);
  }
  
  return query;
}

// Use offline persistence
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  runApp(MyApp());
}

// Optimize listeners
class GradebookScreen extends StatefulWidget {
  @override
  _GradebookScreenState createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  StreamSubscription<QuerySnapshot>? _gradesSubscription;

  @override
  void initState() {
    super.initState();
    _listenToGrades();
  }

  void _listenToGrades() {
    _gradesSubscription = FirebaseFirestore.instance
        .collection('grades')
        .where('classId', isEqualTo: widget.classId)
        .snapshots()
        .listen((snapshot) {
      // Handle updates
    });
  }

  @override
  void dispose() {
    _gradesSubscription?.cancel();
    super.dispose();
  }
}
```

## Migration Checklist

### Phase 1: Setup & Authentication
- [ ] Create Flutter project structure
- [ ] Configure Firebase project
- [ ] Implement authentication service
- [ ] Migrate user data from Supabase
- [ ] Set up role-based access control

### Phase 2: Core Data Migration
- [ ] Design Firestore collections structure
- [ ] Implement data models
- [ ] Create migration scripts
- [ ] Migrate gradebook data
- [ ] Implement real-time listeners

### Phase 3: Features Migration
- [ ] Gradebook functionality
- [ ] File storage system
- [ ] Messaging/chat features
- [ ] Student dashboard
- [ ] Teacher dashboard

### Phase 4: Advanced Features
- [ ] Push notifications
- [ ] Offline support
- [ ] Educational games
- [ ] Analytics integration

## Testing Guidelines

```dart
// Test Firebase services with mocks
void main() {
  group('AuthService Tests', () {
    late MockFirebaseAuth mockAuth;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(auth: mockAuth);
    });

    test('sign in with email and password', () async {
      // Arrange
      when(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password',
      )).thenAnswer((_) async => MockUserCredential());

      // Act
      final result = await authService.signInWithEmail(
        'test@example.com',
        'password',
      );

      // Assert
      expect(result, isA<User>());
    });
  });
}
```

## Security Best Practices

1. **Never expose API keys in client code**
2. **Use Firebase Security Rules for data access control**
3. **Implement proper authentication flows**
4. **Validate data on both client and server**
5. **Use Firebase App Check for additional security**

## Common Pitfalls to Avoid

1. **Don't forget to initialize Firebase before using services**
2. **Always handle authentication state changes**
3. **Use proper error handling for async operations**
4. **Don't ignore Firestore security rules**
5. **Remember to cancel stream subscriptions**

## Essential Firebase Resources

- [Firebase Console](https://console.firebase.google.com/)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Firestore Data Modeling](https://firebase.google.com/docs/firestore/data-model)
- [Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon)

## Environment Configuration

```dart
// lib/config/env.dart
class Environment {
  static const String dev = 'development';
  static const String prod = 'production';
  
  static const String current = String.fromEnvironment('ENV', defaultValue: dev);
  
  static bool get isDev => current == dev;
  static bool get isProd => current == prod;
}

// Different Firebase projects for different environments
await Firebase.initializeApp(
  options: Environment.isDev 
    ? DefaultFirebaseOptions.development
    : DefaultFirebaseOptions.production,
);
```

## Development Workflow

1. **Use Firebase Emulator Suite for local development**
2. **Test with real Firebase for staging**
3. **Use separate Firebase projects for dev/staging/prod**
4. **Monitor performance with Firebase Performance**
5. **Use Firebase Analytics for user insights**

Remember: This migration is not just a technology change - it's an opportunity to improve performance, user experience, and maintainability of the Teacher Dashboard application.