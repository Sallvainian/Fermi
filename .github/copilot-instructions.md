# GitHub Copilot Instructions for Fermi Project

This document provides context and guidelines for GitHub Copilot to generate code that aligns with the Fermi project's architecture, conventions, and best practices.

## Project Overview

**Fermi** is a comprehensive Flutter education management platform for teachers and students with Firebase backend.

### Tech Stack
- **Frontend**: Flutter 3.24+, Dart 3.5+
- **State Management**: Provider 6.1.5+
- **Backend**: Firebase (Auth, Firestore, Storage, Functions, Messaging, Database)
- **Routing**: GoRouter 16.1.0+
- **Key Libraries**: fl_chart, video_player, image_picker, flutter_local_notifications

### Architecture
- Clean Architecture with feature-based organization
- No separate backend server - Firebase handles all backend operations
- Provider pattern for state management
- Repository pattern for data access

## Code Generation Guidelines

### 1. Project Structure

Always follow this feature-based structure:
```dart
lib/features/{feature}/
├── data/               # Data layer
│   ├── repositories/   # Repository implementations
│   └── services/       # External service integrations
├── domain/             # Business logic layer
│   ├── models/         # Domain models
│   └── repositories/   # Repository interfaces
├── presentation/       # UI layer
│   ├── screens/        # Full screen widgets
│   ├── widgets/        # Reusable components
│   └── providers/      # State management
```

### 2. Dart/Flutter Conventions

```dart
// ALWAYS use const constructors where possible
const MyWidget({super.key});

// PREFER single quotes for strings
String message = 'Hello World';

// MUST use proper error handling for Firebase operations
try {
  final result = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  // Handle success
} catch (e) {
  // Show user-friendly error via SnackBar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: ${e.toString()}')),
  );
}

// NEVER use print() in production - use debugPrint()
debugPrint('Debug message');
```

### 3. Common Import Patterns

```dart
// For screens
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/feature_provider.dart';
import '../widgets/custom_widget.dart';

// For Firebase operations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// For models
import '../../../../shared/models/user_model.dart';
```

### 4. Provider State Management Pattern

```dart
// Provider class pattern
class FeatureProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  Future<void> performAction() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Perform async operation
      await someAsyncOperation();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Using provider in widgets
Consumer<FeatureProvider>(
  builder: (context, provider, child) {
    if (provider.isLoading) {
      return const CircularProgressIndicator();
    }
    return YourWidget();
  },
)
```

### 5. Firebase Firestore Patterns

```dart
// Query pattern with error handling
Future<List<Model>> fetchData() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('collection_name')
        .where('field', isEqualTo: value)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    
    return snapshot.docs
        .map((doc) => Model.fromFirestore(doc.data()))
        .toList();
  } catch (e) {
    debugPrint('Error fetching data: $e');
    throw Exception('Failed to load data');
  }
}

// Document operations
Future<void> updateDocument(String docId, Map<String, dynamic> data) async {
  try {
    await FirebaseFirestore.instance
        .collection('collection_name')
        .doc(docId)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    debugPrint('Error updating document: $e');
    rethrow;
  }
}
```

### 6. Authentication Patterns

```dart
// Check authentication state
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // User is signed in
  final isTeacher = context.read<AuthProvider>().userModel?.role == UserRole.teacher;
}

// Sign in pattern
Future<void> signIn(String email, String password) async {
  try {
    final credential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    // Handle success
  } on FirebaseAuthException catch (e) {
    // Handle specific Firebase auth errors
    switch (e.code) {
      case 'user-not-found':
        throw 'No user found with this email';
      case 'wrong-password':
        throw 'Incorrect password';
      default:
        throw 'Authentication failed';
    }
  }
}
```

### 7. Widget Patterns

```dart
// Stateful widget with proper lifecycle
class FeatureScreen extends StatefulWidget {
  const FeatureScreen({super.key});

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Post-frame operations
    });
  }

  @override
  void dispose() {
    // Clean up controllers, listeners
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: // Your content
      ),
    );
  }
}
```

### 8. Navigation with GoRouter

```dart
// Navigation patterns
context.go('/path'); // Navigate to route
context.push('/path'); // Push route onto stack
context.go('/path?param=value'); // With query parameters

// Route guards in router configuration
redirect: (context, state) {
  final isAuthenticated = context.read<AuthProvider>().isAuthenticated;
  if (!isAuthenticated) {
    return '/auth/login';
  }
  return null;
}
```

## Firebase Collections

Main collections in use:
- `users` - User profiles and settings
- `classes` - Class information
- `assignments` - Assignment data
- `submissions` - Student submissions
- `grades` - Grade records
- `chat_rooms` & `messages` - Messaging system
- `discussion_boards`, `threads`, `replies` - Discussion forums
- `notifications` - Push notification data
- `calendar_events` - Calendar and scheduling

## Security Patterns

```dart
// Role-based access control
if (userRole == UserRole.teacher) {
  // Teacher-specific functionality
} else if (userRole == UserRole.student) {
  // Student-specific functionality
}

// Never expose sensitive data
// NEVER: await prefs.setString('password', password);
// ALWAYS: Use secure authentication methods

// Firestore security rules enforcement
// Always assume client-side checks can be bypassed
// Real security is in Firestore rules
```

## Testing Patterns

```dart
// Widget test pattern
testWidgets('Widget test description', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: YourWidget(),
      ),
    ),
  );
  
  expect(find.text('Expected Text'), findsOneWidget);
  
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
  
  expect(find.text('New Text'), findsOneWidget);
});

// Unit test pattern
test('Function test description', () {
  final result = yourFunction(input);
  expect(result, expectedOutput);
});
```

## Performance Guidelines

```dart
// Use const constructors for better performance
const MyWidget();

// Lazy loading for lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
);

// Avoid rebuilding entire widget tree
// Use Consumer or Selector for targeted rebuilds
Selector<Provider, SpecificData>(
  selector: (context, provider) => provider.specificData,
  builder: (context, data, child) => YourWidget(data),
);
```

## Common DO's and DON'Ts

### DO's ✅
- Use `const` constructors wherever possible
- Handle all Firebase errors with try-catch
- Show user-friendly error messages via SnackBar
- Follow Clean Architecture layering
- Use Provider for state management
- Implement proper loading states
- Dispose controllers in dispose() method
- Use debugPrint() instead of print()
- Follow existing patterns in the codebase
- Write descriptive variable and function names

### DON'Ts ❌
- Don't use print() in production code
- Don't commit API keys or secrets
- Don't access Firebase directly from UI widgets
- Don't use setState() when Provider would be better
- Don't ignore null safety
- Don't create widgets without const constructors when possible
- Don't skip error handling for async operations
- Don't use synchronous Firebase operations
- Don't hardcode strings - use constants or localization
- Don't create unnecessary stateful widgets

## Git Commit Convention

Use conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Test additions or changes
- `chore:` Maintenance tasks

Example: `feat: add teacher dashboard analytics widget`

## Platform-Specific Considerations

```dart
// Platform checks when needed
if (Platform.isIOS) {
  // iOS specific code
} else if (Platform.isAndroid) {
  // Android specific code
} else if (kIsWeb) {
  // Web specific code
}

// Responsive design
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      // Tablet/Desktop layout
    } else {
      // Mobile layout
    }
  },
)
```

## File Naming Conventions

- **Screens**: `feature_name_screen.dart`
- **Widgets**: `custom_widget_name.dart`
- **Providers**: `feature_provider.dart`
- **Models**: `model_name.dart`
- **Services**: `service_name_service.dart`
- **Repositories**: `feature_repository.dart`

## When Generating Code

1. **Check existing patterns** in similar files first
2. **Use appropriate imports** based on the feature location
3. **Follow the Clean Architecture** layers
4. **Include proper error handling** for all async operations
5. **Add loading states** for better UX
6. **Use theme colors** instead of hardcoded colors
7. **Make widgets const** when possible
8. **Follow the existing code style** in the project
9. **Generate complete implementations**, not stubs
10. **Include necessary dispose() calls** for controllers

Remember: The goal is to generate code that seamlessly integrates with the existing Fermi codebase, follows Flutter best practices, and maintains consistency throughout the project.