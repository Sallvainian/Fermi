# Contributing Guide

Welcome to the Fermi education platform project! This guide will help you get started with contributing to the codebase.

## Table of Contents
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Development Workflow](#development-workflow)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Architecture Guidelines](#architecture-guidelines)
- [Performance Guidelines](#performance-guidelines)

## Getting Started

### Prerequisites
- Flutter SDK 3.24+ installed
- Dart 3.5+ (comes with Flutter)
- Git for version control
- IDE with Flutter support (VS Code, Android Studio, or IntelliJ)
- Firebase CLI for backend integration

### Development Environment Setup
```bash
# Clone the repository
git clone https://github.com/your-org/fermi.git
cd fermi

# Install dependencies
flutter pub get

# Verify your environment
flutter doctor

# Run the application
flutter run -d chrome  # For web development
flutter run -d android # For Android development
flutter run -d ios     # For iOS development (macOS only)
```

### Firebase Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Configure Firebase for your development
flutterfire configure --project=fermi-education-dev
```

## Development Setup

### Branch Structure
- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/feature-name` - Feature development branches
- `hotfix/issue-description` - Critical bug fixes
- `release/version-number` - Release preparation branches

### Environment Configuration
```dart
// lib/config/environment.dart
enum Environment { development, staging, production }

class Config {
  static const Environment currentEnvironment = Environment.development;
  
  static String get apiUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return 'https://fermi-education-dev.web.app';
      case Environment.staging:
        return 'https://fermi-education-staging.web.app';
      case Environment.production:
        return 'https://fermi-education.web.app';
    }
  }
}
```

## Code Style

### Dart Style Guidelines
Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide:

```dart
// ✅ Good
class UserRepository {
  final FirebaseFirestore _firestore;
  
  const UserRepository({required FirebaseFirestore firestore}) 
    : _firestore = firestore;
    
  Future<User?> getUserById(String id) async {
    try {
      final doc = await _firestore.collection('users').doc(id).get();
      return doc.exists ? User.fromJson(doc.data()!) : null;
    } catch (e) {
      throw UserRepositoryException('Failed to get user: $e');
    }
  }
}

// ❌ Bad
class userRepository {
  FirebaseFirestore firestore;
  
  userRepository(this.firestore);
  
  getUserById(id) async {
    var doc = await firestore.collection('users').doc(id).get();
    if (doc.exists) {
      return User.fromJson(doc.data()!);
    } else {
      return null;
    }
  }
}
```

### File Organization
```
lib/features/feature_name/
├── data/
│   ├── repositories/
│   │   └── feature_repository_impl.dart
│   └── services/
│       └── feature_service.dart
├── domain/
│   ├── models/
│   │   └── feature_model.dart
│   └── repositories/
│       └── feature_repository.dart
└── presentation/
    ├── screens/
    │   └── feature_screen.dart
    ├── widgets/
    │   └── feature_widget.dart
    └── providers/
        └── feature_provider.dart
```

### Naming Conventions
```dart
// Classes: PascalCase
class AssignmentProvider extends ChangeNotifier {}

// Variables and functions: camelCase
String userName = 'John Doe';
void calculateGrade() {}

// Constants: lowerCamelCase
const int maxRetries = 3;
const String apiBaseUrl = 'https://api.example.com';

// Private members: underscore prefix
String _privateField;
void _privateMethod() {}

// Files: snake_case
user_repository.dart
assignment_screen.dart
```

## Development Workflow

### Feature Development Process
1. **Create Feature Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/assignment-grading-system
   ```

2. **Implement Feature**
   - Write code following architecture patterns
   - Add comprehensive tests
   - Update documentation
   - Follow commit message conventions

3. **Commit Standards**
   ```bash
   # Format: type(scope): description
   git commit -m "feat(assignments): add automated grading system"
   git commit -m "fix(auth): resolve login redirect issue"
   git commit -m "docs(api): update Firestore collection schemas"
   git commit -m "test(assignments): add unit tests for grading logic"
   ```

4. **Before Pushing**
   ```bash
   # Format code
   dart format .
   
   # Analyze code
   flutter analyze
   
   # Run tests
   flutter test
   
   # Check for breaking changes
   flutter pub deps
   ```

### Commit Message Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements

## Testing Requirements

### Test Coverage Requirements
- **Minimum Coverage**: 80% overall
- **Critical Paths**: 95% coverage required
- **New Features**: Must include comprehensive tests

### Testing Structure
```dart
// test/unit/providers/assignment_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('AssignmentProvider', () {
    late AssignmentProvider provider;
    late MockAssignmentRepository mockRepository;
    
    setUp(() {
      mockRepository = MockAssignmentRepository();
      provider = AssignmentProvider(repository: mockRepository);
    });
    
    group('loadAssignments', () {
      test('should load assignments successfully', () async {
        // Arrange
        final assignments = [
          AssignmentModel(id: '1', title: 'Test Assignment'),
        ];
        when(mockRepository.getAssignments()).thenAnswer((_) async => assignments);
        
        // Act
        await provider.loadAssignments();
        
        // Assert
        expect(provider.assignments, equals(assignments));
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      });
      
      test('should handle errors gracefully', () async {
        // Arrange
        when(mockRepository.getAssignments()).thenThrow(Exception('Network error'));
        
        // Act
        await provider.loadAssignments();
        
        // Assert
        expect(provider.assignments, isEmpty);
        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      });
    });
  });
}
```

### Widget Testing
```dart
// test/widget/assignment_card_test.dart
void main() {
  testWidgets('AssignmentCard displays assignment information', (tester) async {
    // Arrange
    final assignment = AssignmentModel(
      id: '1',
      title: 'Math Quiz',
      dueDate: DateTime.now().add(Duration(days: 1)),
      totalPoints: 100,
    );
    
    // Act
    await tester.pumpWidget(MaterialApp(
      home: AssignmentCard(assignment: assignment),
    ));
    
    // Assert
    expect(find.text('Math Quiz'), findsOneWidget);
    expect(find.text('100 pts'), findsOneWidget);
    expect(find.byIcon(Icons.assignment), findsOneWidget);
  });
}
```

## Pull Request Process

### PR Checklist
Before creating a pull request, ensure:

- [ ] Code follows style guidelines
- [ ] All tests pass locally
- [ ] New code has appropriate test coverage
- [ ] Documentation updated if needed
- [ ] No sensitive information committed
- [ ] Branch is up to date with target branch
- [ ] Feature is complete and working

### PR Template
```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Screenshots/Videos
Include screenshots or videos if UI changes are involved.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests added for new functionality
- [ ] Documentation updated
- [ ] No breaking changes (or marked as breaking)

## Additional Notes
Any additional information reviewers should know.
```

### Review Process
1. **Automated Checks**: CI/CD pipeline runs tests and analysis
2. **Peer Review**: At least one team member reviews code
3. **Testing**: Reviewer tests functionality manually if needed
4. **Approval**: Approved PR can be merged to develop branch

## Issue Guidelines

### Bug Reports
```markdown
**Bug Description**
Clear description of the bug.

**Steps to Reproduce**
1. Go to...
2. Click on...
3. See error...

**Expected Behavior**
What should happen.

**Actual Behavior**
What actually happens.

**Environment**
- Platform: [iOS/Android/Web]
- Flutter Version: [version]
- Device: [device model if mobile]

**Screenshots**
If applicable, add screenshots.

**Additional Context**
Any other relevant information.
```

### Feature Requests
```markdown
**Feature Summary**
Brief summary of the requested feature.

**Problem Statement**
What problem does this solve?

**Proposed Solution**
How should this work?

**Alternative Solutions**
Other ways to solve this problem.

**Additional Context**
Screenshots, mockups, or examples.

**Priority**
- [ ] Low
- [ ] Medium
- [ ] High
- [ ] Critical
```

## Architecture Guidelines

### Clean Architecture Layers
```dart
// Domain Layer - Business Logic
abstract class AssignmentRepository {
  Future<List<Assignment>> getAssignments(String classId);
  Future<void> createAssignment(Assignment assignment);
  Future<void> updateAssignment(Assignment assignment);
}

// Data Layer - Implementation
class AssignmentRepositoryImpl implements AssignmentRepository {
  final FirestoreService _firestore;
  
  const AssignmentRepositoryImpl({required FirestoreService firestore})
    : _firestore = firestore;
    
  @override
  Future<List<Assignment>> getAssignments(String classId) async {
    // Implementation details
  }
}

// Presentation Layer - UI and State
class AssignmentProvider extends ChangeNotifier {
  final AssignmentRepository _repository;
  
  List<Assignment> _assignments = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters and methods
}
```

### State Management Patterns
```dart
// Provider pattern for state management
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  
  // Methods
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      _user = await _authService.signIn(email, password);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
```

## Performance Guidelines

### Best Practices
1. **Widget Optimization**
   ```dart
   // Use const constructors
   const Text('Hello World')
   
   // Use ListView.builder for large lists
   ListView.builder(
     itemCount: items.length,
     itemBuilder: (context, index) => ItemWidget(items[index]),
   )
   ```

2. **State Management**
   ```dart
   // Minimize rebuilds with Consumer
   Consumer<AssignmentProvider>(
     builder: (context, provider, child) => Text(provider.count.toString()),
   )
   
   // Use Selector for specific properties
   Selector<AssignmentProvider, int>(
     selector: (context, provider) => provider.count,
     builder: (context, count, child) => Text(count.toString()),
   )
   ```

3. **Firebase Optimization**
   ```dart
   // Use pagination for large datasets
   Query query = FirebaseFirestore.instance
     .collection('assignments')
     .orderBy('createdAt', descending: true)
     .limit(20);
     
   // Cache frequently accessed data
   final assignments = await FirebaseFirestore.instance
     .collection('assignments')
     .where('classId', isEqualTo: classId)
     .get(GetOptions(source: Source.cache));
   ```

## Documentation Requirements

### Code Documentation
```dart
/// Repository for managing assignment data operations.
/// 
/// Provides methods for CRUD operations on assignments and handles
/// integration with Firebase Firestore backend.
class AssignmentRepository {
  /// Creates a new assignment in the specified class.
  /// 
  /// Throws [AssignmentException] if the assignment cannot be created.
  /// Returns the created assignment with generated ID.
  Future<Assignment> createAssignment(
    String classId, 
    CreateAssignmentRequest request,
  ) async {
    // Implementation
  }
}
```

### README Updates
When adding new features, update relevant README sections:
- Installation instructions if dependencies change
- Usage examples for new features
- Configuration steps for new integrations

## Getting Help

### Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Effective Dart Guide](https://dart.dev/guides/language/effective-dart)

### Communication Channels
- GitHub Issues for bugs and feature requests
- GitHub Discussions for general questions
- Code reviews for technical discussions

### Development Support
- Use descriptive branch names
- Write clear commit messages
- Include tests with new features
- Update documentation as needed
- Ask questions if unsure about implementation

[content placeholder]