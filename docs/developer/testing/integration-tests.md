# Integration Testing Guide

Comprehensive integration testing strategy for the Fermi Flutter application covering end-to-end workflows and system interactions.

## Overview

Integration tests verify that different parts of the application work together correctly:
- **User Flows**: Complete user journeys from start to finish
- **Firebase Integration**: Real database and authentication interactions
- **Cross-Feature Integration**: How different features interact with each other
- **Platform-Specific Features**: Testing iOS, Android, and Web specific functionality

## Testing Framework

### Dependencies
```yaml
dev_dependencies:
  integration_test: ^1.0.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  patrol: ^2.6.0  # Advanced testing capabilities
  flutter_driver: ^0.0.0
```

### Test Structure
```
integration_test/
├── app_test.dart
├── flows/
│   ├── authentication_flow_test.dart
│   ├── assignment_flow_test.dart
│   ├── chat_flow_test.dart
│   └── grading_flow_test.dart
├── features/
│   ├── dashboard_test.dart
│   ├── calendar_test.dart
│   └── notifications_test.dart
├── platform/
│   ├── web_test.dart
│   ├── ios_test.dart
│   └── android_test.dart
└── helpers/
    ├── test_helpers.dart
    └── firebase_test_helpers.dart
```

## Authentication Flow Testing

### Complete Registration Flow
```dart
// integration_test/flows/authentication_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fermi/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow', () {
    testWidgets('complete user registration flow', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to registration
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Fill registration form
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_password_field')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('display_name_field')),
        'Test User',
      );

      // Submit registration
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify redirect to role selection
      expect(find.byKey(const Key('role_selection_screen')), findsOneWidget);

      // Select student role
      await tester.tap(find.byKey(const Key('student_role_button')));
      await tester.pumpAndSettle();

      // Verify redirect to email verification
      expect(find.byKey(const Key('email_verification_screen')), findsOneWidget);
    });

    testWidgets('login flow with existing user', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'existing@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      // Submit login
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Verify navigation to dashboard
      expect(find.byKey(const Key('student_dashboard')), findsOneWidget);
    });
  });
}
```

### Google Sign-In Integration
```dart
testWidgets('Google Sign-In flow', (tester) async {
  app.main();
  await tester.pumpAndSettle();

  // Tap Google Sign-In button
  await tester.tap(find.byKey(const Key('google_signin_button')));
  await tester.pumpAndSettle();

  // Note: Google Sign-In requires actual Google account
  // Use test accounts or mock responses for CI/CD
  
  // Verify successful authentication
  await tester.pumpAndSettle(Duration(seconds: 10));
  expect(find.byKey(const Key('dashboard_screen')), findsOneWidget);
});
```

## Assignment Workflow Testing

### Teacher Assignment Creation
```dart
// integration_test/flows/assignment_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Assignment Flow', () {
    testWidgets('teacher creates and publishes assignment', (tester) async {
      // Login as teacher
      await loginAsTeacher(tester);

      // Navigate to assignments
      await tester.tap(find.byKey(const Key('assignments_tab')));
      await tester.pumpAndSettle();

      // Create new assignment
      await tester.tap(find.byKey(const Key('create_assignment_fab')));
      await tester.pumpAndSettle();

      // Fill assignment form
      await tester.enterText(
        find.byKey(const Key('assignment_title_field')),
        'Math Quiz 1',
      );
      await tester.enterText(
        find.byKey(const Key('assignment_description_field')),
        'Complete problems 1-10',
      );

      // Set due date
      await tester.tap(find.byKey(const Key('due_date_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Set total points
      await tester.enterText(
        find.byKey(const Key('total_points_field')),
        '100',
      );

      // Publish assignment
      await tester.tap(find.byKey(const Key('publish_assignment_button')));
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Verify assignment appears in list
      expect(find.text('Math Quiz 1'), findsOneWidget);
      expect(find.byIcon(Icons.published_with_changes), findsOneWidget);
    });
  });
}
```

### Student Assignment Submission
```dart
testWidgets('student submits assignment', (tester) async {
  // Login as student
  await loginAsStudent(tester);

  // Navigate to assignments
  await tester.tap(find.byKey(const Key('assignments_tab')));
  await tester.pumpAndSettle();

  // Find and open assignment
  await tester.tap(find.text('Math Quiz 1'));
  await tester.pumpAndSettle();

  // Verify assignment details
  expect(find.text('Complete problems 1-10'), findsOneWidget);
  expect(find.text('Due:'), findsOneWidget);

  // Start submission
  await tester.tap(find.byKey(const Key('start_submission_button')));
  await tester.pumpAndSettle();

  // Add submission text
  await tester.enterText(
    find.byKey(const Key('submission_text_field')),
    'My answers: 1) 5, 2) 10, 3) 15...',
  );

  // Upload file (mock file picker)
  await tester.tap(find.byKey(const Key('upload_file_button')));
  await tester.pumpAndSettle();

  // Submit assignment
  await tester.tap(find.byKey(const Key('submit_assignment_button')));
  await tester.pumpAndSettle(Duration(seconds: 3));

  // Verify submission confirmation
  expect(find.text('Assignment submitted successfully'), findsOneWidget);
  expect(find.byIcon(Icons.check_circle), findsOneWidget);
});
```

## Chat and Messaging Testing

### Real-time Chat Flow
```dart
// integration_test/flows/chat_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Flow', () {
    testWidgets('send and receive messages in real-time', (tester) async {
      // Login as first user
      await loginAsUser(tester, 'user1@example.com');

      // Navigate to chat
      await tester.tap(find.byKey(const Key('chat_tab')));
      await tester.pumpAndSettle();

      // Start new conversation
      await tester.tap(find.byKey(const Key('new_chat_fab')));
      await tester.pumpAndSettle();

      // Select user to chat with
      await tester.tap(find.text('Test User 2'));
      await tester.pumpAndSettle();

      // Send message
      await tester.enterText(
        find.byKey(const Key('message_input_field')),
        'Hello, how are you?',
      );
      await tester.tap(find.byKey(const Key('send_message_button')));
      await tester.pumpAndSettle();

      // Verify message appears
      expect(find.text('Hello, how are you?'), findsOneWidget);
      
      // Verify message status
      expect(find.byIcon(Icons.done), findsOneWidget); // Sent
    });

    testWidgets('file sharing in chat', (tester) async {
      await loginAsUser(tester, 'teacher@example.com');
      
      // Open existing chat
      await navigateToChat(tester, 'Student Group');

      // Share file
      await tester.tap(find.byKey(const Key('attach_file_button')));
      await tester.pumpAndSettle();

      // Select image from mock picker
      await tester.tap(find.text('Image'));
      await tester.pumpAndSettle();

      // Add caption
      await tester.enterText(
        find.byKey(const Key('file_caption_field')),
        'Assignment reference image',
      );

      // Send file
      await tester.tap(find.byKey(const Key('send_file_button')));
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify file message appears
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Assignment reference image'), findsOneWidget);
    });
  });
}
```

## Class Management Integration

### Complete Class Workflow
```dart
// integration_test/flows/class_management_test.dart
testWidgets('complete class creation and enrollment flow', (tester) async {
  // Teacher creates class
  await loginAsTeacher(tester);
  
  await tester.tap(find.byKey(const Key('classes_tab')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('create_class_fab')));
  await tester.pumpAndSettle();

  // Fill class details
  await tester.enterText(
    find.byKey(const Key('class_name_field')),
    'Advanced Mathematics',
  );
  await tester.enterText(
    find.byKey(const Key('class_description_field')),
    'Advanced calculus and algebra course',
  );
  await tester.enterText(
    find.byKey(const Key('subject_field')),
    'Mathematics',
  );
  await tester.enterText(
    find.byKey(const Key('grade_field')),
    '12',
  );

  // Create class
  await tester.tap(find.byKey(const Key('create_class_button')));
  await tester.pumpAndSettle(Duration(seconds: 3));

  // Get class code
  final classCode = await getClassCode(tester);
  
  // Logout teacher
  await logout(tester);

  // Student enrolls in class
  await loginAsStudent(tester);
  
  await tester.tap(find.byKey(const Key('join_class_button')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('class_code_field')),
    classCode,
  );

  await tester.tap(find.byKey(const Key('join_class_submit_button')));
  await tester.pumpAndSettle(Duration(seconds: 3));

  // Verify enrollment success
  expect(find.text('Successfully joined Advanced Mathematics'), findsOneWidget);
  expect(find.text('Advanced Mathematics'), findsOneWidget);
});
```

## Grading System Integration

### End-to-End Grading Flow
```dart
// integration_test/flows/grading_flow_test.dart
testWidgets('complete grading workflow', (tester) async {
  // Setup: Create assignment and submission
  await setupAssignmentWithSubmission(tester);

  // Teacher grades submission
  await loginAsTeacher(tester);
  
  await tester.tap(find.byKey(const Key('assignments_tab')));
  await tester.pumpAndSettle();

  // Open assignment
  await tester.tap(find.text('Math Quiz 1'));
  await tester.pumpAndSettle();

  // View submissions
  await tester.tap(find.byKey(const Key('view_submissions_button')));
  await tester.pumpAndSettle();

  // Grade first submission
  await tester.tap(find.byKey(const Key('grade_submission_0')));
  await tester.pumpAndSettle();

  // Enter grade
  await tester.enterText(
    find.byKey(const Key('grade_points_field')),
    '85',
  );

  // Add feedback
  await tester.enterText(
    find.byKey(const Key('feedback_field')),
    'Good work! Remember to show all steps.',
  );

  // Submit grade
  await tester.tap(find.byKey(const Key('submit_grade_button')));
  await tester.pumpAndSettle(Duration(seconds: 3));

  // Verify grade was saved
  expect(find.text('Grade: 85/100'), findsOneWidget);
  
  // Logout teacher, login as student
  await logout(tester);
  await loginAsStudent(tester);

  // Check grade notification
  await tester.tap(find.byKey(const Key('notifications_tab')));
  await tester.pumpAndSettle();

  expect(find.text('Your assignment has been graded'), findsOneWidget);

  // View grade details
  await tester.tap(find.text('Math Quiz 1 - Grade Available'));
  await tester.pumpAndSettle();

  // Verify grade and feedback
  expect(find.text('85'), findsOneWidget);
  expect(find.text('Good work! Remember to show all steps.'), findsOneWidget);
});
```

## Platform-Specific Testing

### Web Platform Testing
```dart
// integration_test/platform/web_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Web Platform Tests', () {
    testWidgets('responsive layout on different screen sizes', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test desktop layout
      await tester.binding.setSurfaceSize(Size(1200, 800));
      await tester.pumpAndSettle();
      
      // Verify sidebar navigation is visible
      expect(find.byKey(const Key('desktop_sidebar')), findsOneWidget);

      // Test tablet layout
      await tester.binding.setSurfaceSize(Size(768, 1024));
      await tester.pumpAndSettle();
      
      // Verify drawer navigation
      expect(find.byKey(const Key('app_drawer')), findsOneWidget);

      // Test mobile layout
      await tester.binding.setSurfaceSize(Size(375, 667));
      await tester.pumpAndSettle();
      
      // Verify bottom navigation
      expect(find.byKey(const Key('bottom_navigation')), findsOneWidget);
    });

    testWidgets('keyboard navigation', (tester) async {
      await loginAsUser(tester, 'test@example.com');
      
      // Test tab navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      
      // Verify focus moved to next element
      expect(find.byKey(const Key('focused_element')), findsOneWidget);
    });
  });
}
```

### iOS Platform Testing
```dart
// integration_test/platform/ios_test.dart
testWidgets('iOS-specific features', (tester) async {
  app.main();
  await tester.pumpAndSettle();

  // Test Apple Sign-In (iOS only)
  await tester.tap(find.byKey(const Key('apple_signin_button')));
  await tester.pumpAndSettle();

  // Verify Apple Sign-In flow
  // Note: Requires actual device or simulator with Apple ID

  // Test iOS swipe gestures
  await tester.drag(
    find.byKey(const Key('swipeable_item')),
    Offset(-200, 0),
  );
  await tester.pumpAndSettle();

  // Verify swipe action revealed
  expect(find.byKey(const Key('delete_action')), findsOneWidget);

  // Test iOS-specific notifications
  await scheduleLocalNotification();
  await tester.pumpAndSettle(Duration(seconds: 2));
  
  // Verify notification appeared
  expect(find.text('Assignment Due Tomorrow'), findsOneWidget);
});
```

## Test Helpers and Utilities

### Authentication Helpers
```dart
// integration_test/helpers/test_helpers.dart
Future<void> loginAsTeacher(WidgetTester tester) async {
  await loginAsUser(tester, 'teacher@example.com', 'password123');
}

Future<void> loginAsStudent(WidgetTester tester) async {
  await loginAsUser(tester, 'student@example.com', 'password123');
}

Future<void> loginAsUser(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.enterText(find.byKey(const Key('email_field')), email);
  await tester.enterText(find.byKey(const Key('password_field')), password);
  await tester.tap(find.byKey(const Key('login_button')));
  await tester.pumpAndSettle(Duration(seconds: 5));
}

Future<void> logout(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profile_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('logout_button')));
  await tester.pumpAndSettle();
}
```

### Firebase Test Helpers
```dart
// integration_test/helpers/firebase_test_helpers.dart
Future<void> setupTestData() async {
  final firestore = FirebaseFirestore.instance;
  
  // Create test users
  await firestore.collection('users').doc('teacher-test-id').set({
    'email': 'teacher@example.com',
    'role': 'teacher',
    'displayName': 'Test Teacher',
  });

  await firestore.collection('users').doc('student-test-id').set({
    'email': 'student@example.com',
    'role': 'student',
    'displayName': 'Test Student',
  });

  // Create test class
  await firestore.collection('classes').doc('test-class-id').set({
    'name': 'Test Class',
    'teacherId': 'teacher-test-id',
    'studentIds': ['student-test-id'],
  });
}

Future<void> cleanupTestData() async {
  final firestore = FirebaseFirestore.instance;
  
  // Clean up test collections
  await deleteCollection(firestore, 'users');
  await deleteCollection(firestore, 'classes');
  await deleteCollection(firestore, 'assignments');
  await deleteCollection(firestore, 'messages');
}
```

## Running Integration Tests

### Local Testing
```bash
# Run all integration tests
flutter test integration_test/

# Run specific test file
flutter test integration_test/flows/authentication_flow_test.dart

# Run with specific device
flutter test integration_test/ -d chrome
flutter test integration_test/ -d ios
```

### CI/CD Integration
```yaml
# .github/workflows/integration_tests.yml
name: Integration Tests
on: [push, pull_request]

jobs:
  integration_tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run integration tests
        run: flutter test integration_test/
        env:
          FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}
          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
```

## Best Practices

### Test Data Management
- Use dedicated test Firebase project
- Create and cleanup test data for each test
- Use meaningful test data that represents real scenarios
- Avoid hardcoded production data

### Performance Considerations
- Use `pumpAndSettle()` with timeouts for async operations
- Minimize test execution time while ensuring reliability
- Run tests in parallel when possible
- Use test-specific builds to reduce app size

### Reliability Strategies
- Add retry logic for flaky network operations
- Use proper waiting mechanisms for async operations
- Handle platform-specific differences gracefully
- Include error scenarios and edge cases

[content placeholder]