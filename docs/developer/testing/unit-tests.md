# Unit Testing Guide

Comprehensive unit testing strategy for the Fermi Flutter application using the Flutter test framework.

## Overview

Unit testing in Fermi focuses on testing individual components in isolation:
- **Models**: Data validation and serialization
- **Providers**: State management and business logic  
- **Services**: Data layer and API interactions
- **Utilities**: Helper functions and extensions
- **Widgets**: Component behavior and rendering

## Testing Framework

### Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
  fake_cloud_firestore: ^2.4.0
  firebase_auth_mocks: ^0.11.0
  network_image_mock: ^2.1.1
```

### Test Structure
```
test/
├── unit/
│   ├── models/
│   ├── providers/
│   ├── services/
│   └── utils/
├── widget/
├── integration/
├── mocks/
└── helpers/
```

## Model Testing

### Data Model Validation
```dart
// test/unit/models/user_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi/features/auth/domain/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('should create valid user from JSON', () {
      // Arrange
      final json = {
        'uid': 'test-uid',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'student',
      };

      // Act
      final user = UserModel.fromJson(json);

      // Assert
      expect(user.uid, equals('test-uid'));
      expect(user.email, equals('test@example.com'));
      expect(user.role, equals(UserRole.student));
    });

    test('should throw exception for invalid role', () {
      // Arrange
      final json = {
        'uid': 'test-uid',
        'email': 'test@example.com',
        'role': 'invalid-role',
      };

      // Act & Assert
      expect(
        () => UserModel.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should convert to JSON correctly', () {
      // Arrange
      final user = UserModel(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.teacher,
      );

      // Act
      final json = user.toJson();

      // Assert
      expect(json['uid'], equals('test-uid'));
      expect(json['role'], equals('teacher'));
    });
  });
}
```

### Assignment Model Testing
```dart
// test/unit/models/assignment_model_test.dart
void main() {
  group('AssignmentModel', () {
    test('should validate due date is in future', () {
      // Arrange
      final pastDate = DateTime.now().subtract(Duration(days: 1));
      
      // Act & Assert
      expect(
        () => AssignmentModel(
          id: 'test-id',
          title: 'Test Assignment',
          dueDate: pastDate,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should calculate time remaining correctly', () {
      // Arrange
      final futureDate = DateTime.now().add(Duration(hours: 24));
      final assignment = AssignmentModel(
        id: 'test-id',
        title: 'Test Assignment',
        dueDate: futureDate,
      );

      // Act
      final timeRemaining = assignment.timeRemaining;

      // Assert
      expect(timeRemaining.inHours, closeTo(24, 1));
    });
  });
}
```

## Provider Testing

### Authentication Provider Testing
```dart
// test/unit/providers/auth_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fermi/features/auth/presentation/providers/auth_provider.dart';

class MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  group('AuthProvider', () {
    late AuthProvider authProvider;
    late MockFirebaseAuth mockAuth;
    late MockFirestoreService mockFirestore;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirestoreService();
      authProvider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );
    });

    test('should initialize with loading state', () {
      expect(authProvider.isLoading, isTrue);
      expect(authProvider.user, isNull);
      expect(authProvider.error, isNull);
    });

    test('should sign in user successfully', () async {
      // Arrange
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
      );
      
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => MockUserCredential(user: mockUser));

      // Act
      await authProvider.signInWithEmailAndPassword(
        'test@example.com',
        'password123',
      );

      // Assert
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.user, isNotNull);
      expect(authProvider.error, isNull);
    });

    test('should handle sign in failure', () async {
      // Arrange
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      // Act
      await authProvider.signInWithEmailAndPassword(
        'test@example.com',
        'wrongpassword',
      );

      // Assert
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.user, isNull);
      expect(authProvider.error, isNotNull);
      expect(authProvider.error!.code, equals('user-not-found'));
    });
  });
}
```

### Assignment Provider Testing
```dart
// test/unit/providers/assignment_provider_test.dart
void main() {
  group('AssignmentProvider', () {
    late AssignmentProvider assignmentProvider;
    late MockAssignmentRepository mockRepository;

    setUp(() {
      mockRepository = MockAssignmentRepository();
      assignmentProvider = AssignmentProvider(repository: mockRepository);
    });

    test('should load assignments for class', () async {
      // Arrange
      final mockAssignments = [
        AssignmentModel(id: '1', title: 'Assignment 1'),
        AssignmentModel(id: '2', title: 'Assignment 2'),
      ];
      
      when(mockRepository.getAssignmentsForClass('class-id'))
          .thenAnswer((_) async => mockAssignments);

      // Act
      await assignmentProvider.loadAssignmentsForClass('class-id');

      // Assert
      expect(assignmentProvider.assignments, hasLength(2));
      expect(assignmentProvider.isLoading, isFalse);
    });

    test('should create assignment successfully', () async {
      // Arrange
      final newAssignment = AssignmentModel(
        id: 'new-id',
        title: 'New Assignment',
      );
      
      when(mockRepository.createAssignment(any))
          .thenAnswer((_) async => newAssignment);

      // Act
      await assignmentProvider.createAssignment(newAssignment);

      // Assert
      expect(assignmentProvider.assignments, contains(newAssignment));
      verify(mockRepository.createAssignment(newAssignment)).called(1);
    });
  });
}
```

## Service Testing

### Firestore Service Testing
```dart
// test/unit/services/firestore_service_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('FirestoreService', () {
    late FirestoreService firestoreService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
    });

    test('should create user document', () async {
      // Arrange
      final userData = {
        'uid': 'test-uid',
        'email': 'test@example.com',
        'role': 'student',
      };

      // Act
      await firestoreService.createUserDocument('test-uid', userData);

      // Assert
      final doc = await fakeFirestore.collection('users').doc('test-uid').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['email'], equals('test@example.com'));
    });

    test('should get user by ID', () async {
      // Arrange
      await fakeFirestore.collection('users').doc('test-uid').set({
        'uid': 'test-uid',
        'email': 'test@example.com',
        'role': 'teacher',
      });

      // Act
      final user = await firestoreService.getUserById('test-uid');

      // Assert
      expect(user, isNotNull);
      expect(user!.email, equals('test@example.com'));
      expect(user.role, equals(UserRole.teacher));
    });
  });
}
```

### Chat Service Testing
```dart
// test/unit/services/chat_service_test.dart
void main() {
  group('ChatService', () {
    late ChatService chatService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      chatService = ChatService(firestore: fakeFirestore);
    });

    test('should send message to chat room', () async {
      // Arrange
      final message = MessageModel(
        id: 'msg-1',
        text: 'Hello, world!',
        senderId: 'user-1',
        chatRoomId: 'room-1',
        timestamp: DateTime.now(),
      );

      // Act
      await chatService.sendMessage(message);

      // Assert
      final doc = await fakeFirestore
          .collection('messages')
          .doc('msg-1')
          .get();
      
      expect(doc.exists, isTrue);
      expect(doc.data()!['text'], equals('Hello, world!'));
    });

    test('should get messages for chat room', () async {
      // Arrange
      await fakeFirestore.collection('messages').add({
        'text': 'Message 1',
        'senderId': 'user-1',
        'chatRoomId': 'room-1',
        'timestamp': Timestamp.now(),
      });

      // Act
      final messages = await chatService.getMessagesForRoom('room-1');

      // Assert
      expect(messages, hasLength(1));
      expect(messages.first.text, equals('Message 1'));
    });
  });
}
```

## Utility Testing

### Date Utilities Testing
```dart
// test/unit/utils/date_utils_test.dart
void main() {
  group('DateUtils', () {
    test('should format date correctly', () {
      // Arrange
      final date = DateTime(2024, 3, 15, 14, 30);

      // Act
      final formatted = DateUtils.formatDate(date);

      // Assert
      expect(formatted, equals('March 15, 2024'));
    });

    test('should calculate time ago correctly', () {
      // Arrange
      final pastDate = DateTime.now().subtract(Duration(hours: 2));

      // Act
      final timeAgo = DateUtils.timeAgo(pastDate);

      // Assert
      expect(timeAgo, equals('2 hours ago'));
    });

    test('should determine if date is overdue', () {
      // Arrange
      final overdueDate = DateTime.now().subtract(Duration(days: 1));
      final futureDate = DateTime.now().add(Duration(days: 1));

      // Act & Assert
      expect(DateUtils.isOverdue(overdueDate), isTrue);
      expect(DateUtils.isOverdue(futureDate), isFalse);
    });
  });
}
```

## Test Helpers and Mocks

### Test Data Factory
```dart
// test/helpers/test_data_factory.dart
class TestDataFactory {
  static UserModel createUser({
    String? uid,
    String? email,
    UserRole? role,
  }) {
    return UserModel(
      uid: uid ?? 'test-uid-${DateTime.now().millisecondsSinceEpoch}',
      email: email ?? 'test@example.com',
      displayName: 'Test User',
      role: role ?? UserRole.student,
    );
  }

  static AssignmentModel createAssignment({
    String? id,
    String? title,
    DateTime? dueDate,
  }) {
    return AssignmentModel(
      id: id ?? 'assignment-${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Test Assignment',
      description: 'Test assignment description',
      dueDate: dueDate ?? DateTime.now().add(Duration(days: 7)),
      totalPoints: 100,
    );
  }
}
```

### Mock Services
```dart
// test/mocks/mock_services.dart
@GenerateMocks([
  FirestoreService,
  StorageService,
  NotificationService,
  AnalyticsService,
])
void main() {}
```

## Running Tests

### Command Line
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/models/user_model_test.dart

# Run tests with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
```

### Test Configuration
```dart
// test/test_config.dart
void configureTests() {
  // Set up global test configuration
  group('Global Setup', () {
    setUpAll(() {
      // Initialize test environment
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Configure Firebase for testing
      setupFirebaseAuthMocks();
    });
  });
}
```

## Best Practices

### Test Organization
- Group related tests using `group()`
- Use descriptive test names that explain the scenario
- Follow Arrange-Act-Assert pattern
- Keep tests independent and isolated

### Mocking Strategy
- Mock external dependencies (Firebase, APIs)
- Use fake implementations for complex services
- Avoid mocking value objects and simple data classes
- Mock at the service layer, not the provider layer

### Test Data Management
- Use factories for creating test data
- Avoid hardcoded values where possible
- Create realistic test scenarios
- Use builders for complex object creation

### Performance Considerations
- Keep tests fast by avoiding real network calls
- Use `setUp()` and `tearDown()` for test initialization
- Minimize test data creation overhead
- Run tests in parallel when possible

[content placeholder]