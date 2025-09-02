# Code Standards and Conventions

Comprehensive coding standards for the Fermi Flutter application to ensure consistency, maintainability, and quality across the codebase.

## Table of Contents
- [Dart Language Standards](#dart-language-standards)
- [Flutter Framework Conventions](#flutter-framework-conventions)
- [File and Directory Structure](#file-and-directory-structure)
- [Naming Conventions](#naming-conventions)
- [Code Organization](#code-organization)
- [Error Handling](#error-handling)
- [Documentation Standards](#documentation-standards)
- [Performance Guidelines](#performance-guidelines)
- [Security Standards](#security-standards)

## Dart Language Standards

### General Principles
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Prefer immutable data structures where possible
- Use meaningful variable and function names
- Keep functions small and focused
- Minimize nesting depth

### Code Formatting
```dart
// ✅ Good: Proper formatting and spacing
class AssignmentService {
  final FirebaseFirestore _firestore;
  
  const AssignmentService({required FirebaseFirestore firestore})
      : _firestore = firestore;
      
  Future<List<Assignment>> getAssignments({
    required String classId,
    int? limit,
    String? startAfter,
  }) async {
    Query query = _firestore
        .collection('assignments')
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true);
        
    if (limit != null) {
      query = query.limit(limit);
    }
    
    if (startAfter != null) {
      query = query.startAfter([startAfter]);
    }
    
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Assignment.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }
}

// ❌ Bad: Poor formatting and structure
class assignmentService{
final FirebaseFirestore firestore;
assignmentService(this.firestore);
getAssignments(classId,{limit,startAfter})async{
var query=firestore.collection('assignments').where('classId',isEqualTo: classId).orderBy('createdAt',descending: true);
if(limit!=null)query=query.limit(limit);
if(startAfter!=null)query=query.startAfter([startAfter]);
return (await query.get()).docs.map((doc)=>Assignment.fromJson(doc.data())).toList();
}
}
```

### Type Safety
```dart
// ✅ Good: Explicit types and null safety
class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.displayName,
    this.metadata,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      role: UserRole.values.byName(json['role'] as String),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

// ❌ Bad: Implicit types and poor null handling
class UserModel {
  var id;
  var email;
  var displayName;
  var role;
  var createdAt;
  var metadata;
  
  UserModel.fromJson(json) {
    id = json['id'];
    email = json['email'];
    displayName = json['displayName'];
    role = json['role'];
    createdAt = json['createdAt'];
    metadata = json['metadata'];
  }
}
```

### Function Design
```dart
// ✅ Good: Pure functions with clear parameters
Future<Result<Assignment, CreateAssignmentError>> createAssignment({
  required String classId,
  required String title,
  required String description,
  required DateTime dueDate,
  required int totalPoints,
  List<String>? attachments,
}) async {
  try {
    // Validation
    if (title.trim().isEmpty) {
      return Result.error(CreateAssignmentError.invalidTitle);
    }
    
    if (dueDate.isBefore(DateTime.now())) {
      return Result.error(CreateAssignmentError.pastDueDate);
    }
    
    // Create assignment
    final assignment = Assignment(
      id: generateId(),
      classId: classId,
      title: title.trim(),
      description: description.trim(),
      dueDate: dueDate,
      totalPoints: totalPoints,
      attachments: attachments ?? [],
      createdAt: DateTime.now(),
    );
    
    await _repository.createAssignment(assignment);
    return Result.success(assignment);
  } catch (e) {
    return Result.error(CreateAssignmentError.unknown);
  }
}

// ❌ Bad: Side effects and unclear parameters  
void createAssignment(data) async {
  var assignment = Assignment();
  assignment.classId = data['classId'];
  assignment.title = data['title'];
  // ... direct property assignment
  
  await FirebaseFirestore.instance
      .collection('assignments')
      .add(assignment.toJson());
}
```

## Flutter Framework Conventions

### Widget Structure
```dart
// ✅ Good: Well-structured stateless widget
class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback? onTap;
  final bool isSelected;
  
  const AssignmentCard({
    super.key,
    required this.assignment,
    this.onTap,
    this.isSelected = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = assignment.dueDate.isBefore(DateTime.now());
    
    return Card(
      elevation: isSelected ? 4.0 : 2.0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, isOverdue),
              const SizedBox(height: 8.0),
              _buildDescription(),
              const SizedBox(height: 12.0),
              _buildFooter(theme, isOverdue),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(ThemeData theme, bool isOverdue) {
    return Row(
      children: [
        Expanded(
          child: Text(
            assignment.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isOverdue ? theme.colorScheme.error : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (isOverdue)
          Icon(
            Icons.warning,
            color: theme.colorScheme.error,
            size: 20.0,
          ),
      ],
    );
  }
  
  Widget _buildDescription() {
    return Text(
      assignment.description,
      style: const TextStyle(color: Colors.grey),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  Widget _buildFooter(ThemeData theme, bool isOverdue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Due: ${DateFormat.MMMd().format(assignment.dueDate)}',
          style: TextStyle(
            color: isOverdue ? theme.colorScheme.error : Colors.grey,
            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text('${assignment.totalPoints} pts'),
      ],
    );
  }
}
```

### State Management Patterns
```dart
// ✅ Good: Provider pattern implementation
class AssignmentProvider extends ChangeNotifier {
  final AssignmentRepository _repository;
  
  List<Assignment> _assignments = [];
  bool _isLoading = false;
  String? _error;
  Assignment? _selectedAssignment;
  
  AssignmentProvider({required AssignmentRepository repository})
      : _repository = repository;
  
  // Getters
  List<Assignment> get assignments => List.unmodifiable(_assignments);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Assignment? get selectedAssignment => _selectedAssignment;
  bool get hasError => _error != null;
  
  // Public methods
  Future<void> loadAssignments(String classId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      final assignments = await _repository.getAssignments(classId);
      _assignments = assignments;
    } catch (e) {
      _setError('Failed to load assignments: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }
  
  Future<bool> createAssignment(Assignment assignment) async {
    _clearError();
    
    try {
      await _repository.createAssignment(assignment);
      _assignments.insert(0, assignment);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to create assignment: ${e.toString()}');
      return false;
    }
  }
  
  void selectAssignment(Assignment assignment) {
    if (_selectedAssignment?.id != assignment.id) {
      _selectedAssignment = assignment;
      notifyListeners();
    }
  }
  
  void clearSelection() {
    if (_selectedAssignment != null) {
      _selectedAssignment = null;
      notifyListeners();
    }
  }
  
  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }
}
```

## File and Directory Structure

### Project Organization
```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── environment.dart
│   ├── theme.dart
│   └── constants.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   └── services/
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   └── presentation/
│   │       ├── screens/
│   │       ├── widgets/
│   │       └── providers/
│   ├── assignments/
│   └── ...other features/
├── shared/
│   ├── core/
│   │   ├── app_providers.dart
│   │   ├── error_handler.dart
│   │   └── result.dart
│   ├── routing/
│   │   └── app_router.dart
│   ├── services/
│   │   ├── firestore_service.dart
│   │   ├── storage_service.dart
│   │   └── analytics_service.dart
│   ├── utils/
│   │   ├── date_utils.dart
│   │   ├── validation_utils.dart
│   │   └── string_extensions.dart
│   └── widgets/
│       ├── common/
│       ├── forms/
│       └── loading/
└── generated/
    └── ...generated files/
```

### File Naming Conventions
```bash
# Dart files: snake_case
assignment_repository.dart
user_profile_screen.dart
date_picker_widget.dart

# Directories: snake_case
user_management/
assignment_grading/
notification_system/

# Constants and enums: snake_case files, PascalCase content
user_roles.dart          # File name
enum UserRole { ... }    # Enum name

# Test files: match source with _test suffix
assignment_repository.dart → assignment_repository_test.dart
user_profile_screen.dart → user_profile_screen_test.dart
```

## Naming Conventions

### Classes and Enums
```dart
// ✅ Good: PascalCase for classes
class AssignmentRepository {}
class UserProfileScreen extends StatefulWidget {}
abstract class BaseRepository {}
mixin CacheableMixin {}

enum UserRole { student, teacher, admin }
enum AssignmentStatus { draft, published, completed }

// ❌ Bad: Wrong casing
class assignmentRepository {}
class user_profile_screen {}
enum userRole {}
```

### Variables and Functions
```dart
// ✅ Good: camelCase for variables and functions
String userName = 'John Doe';
int totalAssignments = 0;
bool isUserLoggedIn = false;
List<Assignment> pendingAssignments = [];

Future<void> loadUserData() async {}
bool validateEmailFormat(String email) {}
String formatDisplayName(String firstName, String lastName) {}

// Private members: underscore prefix
String _internalUserId;
void _updateInternalState() {}

// ❌ Bad: Wrong casing or naming
String user_name;
int TotalAssignments;
bool IsUserLoggedIn;
List<Assignment> pending_assignments;
```

### Constants
```dart
// ✅ Good: lowerCamelCase for constants
const int maxRetryAttempts = 3;
const Duration defaultTimeout = Duration(seconds: 30);
const String defaultAvatarUrl = 'https://example.com/avatar.png';

// Class-level constants
class ApiConstants {
  static const String baseUrl = 'https://api.fermi-education.com';
  static const String authEndpoint = '/auth';
  static const String assignmentsEndpoint = '/assignments';
}

// ❌ Bad: Wrong casing
const int MAX_RETRY_ATTEMPTS = 3;
const Duration DEFAULT_TIMEOUT = Duration(seconds: 30);
```

## Code Organization

### Import Organization
```dart
// ✅ Good: Organized imports
// Dart imports
import 'dart:async';
import 'dart:convert';

// Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Local imports
import '../../../shared/core/result.dart';
import '../../../shared/services/firestore_service.dart';
import '../domain/models/assignment_model.dart';
import '../domain/repositories/assignment_repository.dart';

// ❌ Bad: Disorganized imports
import '../domain/models/assignment_model.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../shared/core/result.dart';
```

### Class Organization
```dart
// ✅ Good: Well-organized class structure
class AssignmentScreen extends StatefulWidget {
  // 1. Static constants
  static const String routeName = '/assignments';
  
  // 2. Instance variables
  final String classId;
  final String? initialAssignmentId;
  
  // 3. Constructor
  const AssignmentScreen({
    super.key,
    required this.classId,
    this.initialAssignmentId,
  });
  
  // 4. Public methods
  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  // 1. Instance variables
  late final AssignmentProvider _assignmentProvider;
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  
  // 2. Lifecycle methods
  @override
  void initState() {
    super.initState();
    _assignmentProvider = context.read<AssignmentProvider>();
    _loadInitialData();
    _setupRefreshTimer();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  // 3. Build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  // 4. Private widget builders
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Assignments'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _handleRefresh,
        ),
      ],
    );
  }
  
  Widget _buildBody() {
    return Consumer<AssignmentProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.assignments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (provider.hasError) {
          return _buildErrorWidget(provider.error!);
        }
        
        return _buildAssignmentsList(provider.assignments);
      },
    );
  }
  
  // 5. Private helper methods
  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _assignmentProvider.loadAssignments(widget.classId);
    });
  }
  
  void _setupRefreshTimer() {
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _assignmentProvider.loadAssignments(widget.classId),
    );
  }
  
  void _handleRefresh() {
    _assignmentProvider.loadAssignments(widget.classId);
  }
}
```

## Error Handling

### Result Pattern Implementation
```dart
// ✅ Good: Result pattern for error handling
abstract class Result<T, E> {
  const Result();
  
  bool get isSuccess;
  bool get isError;
  
  T get value;
  E get error;
  
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) error,
  });
}

class Success<T, E> extends Result<T, E> {
  final T _value;
  
  const Success(this._value);
  
  @override
  bool get isSuccess => true;
  
  @override
  bool get isError => false;
  
  @override
  T get value => _value;
  
  @override
  E get error => throw StateError('Success result has no error');
  
  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) error,
  }) => success(_value);
}

// Usage example
Future<Result<User, AuthError>> signInUser(
  String email, 
  String password,
) async {
  try {
    if (!_isValidEmail(email)) {
      return const Failure(AuthError.invalidEmail);
    }
    
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final user = await _getUserFromCredential(credential);
    return Success(user);
  } on FirebaseAuthException catch (e) {
    return Failure(_mapFirebaseError(e));
  } catch (e) {
    return const Failure(AuthError.unknown);
  }
}
```

### Exception Classes
```dart
// ✅ Good: Structured exception hierarchy
abstract class FermiException implements Exception {
  const FermiException(this.message, [this.cause]);
  
  final String message;
  final Object? cause;
  
  @override
  String toString() => 'FermiException: $message';
}

class AuthenticationException extends FermiException {
  const AuthenticationException(super.message, [super.cause]);
}

class ValidationException extends FermiException {
  const ValidationException(super.message, [super.cause]);
  
  ValidationException.invalidEmail() 
      : this('Invalid email format');
  
  ValidationException.passwordTooShort()
      : this('Password must be at least 8 characters');
}

class NetworkException extends FermiException {
  const NetworkException(super.message, [super.cause]);
  
  NetworkException.noConnection() 
      : this('No internet connection available');
  
  NetworkException.timeout()
      : this('Request timed out');
}
```

## Documentation Standards

### Code Documentation
```dart
/// Repository for managing assignment data operations.
/// 
/// This repository provides methods for creating, reading, updating, and 
/// deleting assignments. It handles integration with Firebase Firestore
/// and includes caching for performance optimization.
/// 
/// Example usage:
/// ```dart
/// final repository = AssignmentRepository(
///   firestore: FirebaseFirestore.instance,
/// );
/// 
/// final assignments = await repository.getAssignments('class-123');
/// ```
class AssignmentRepository {
  final FirebaseFirestore _firestore;
  final Map<String, List<Assignment>> _cache = {};
  
  /// Creates a new assignment repository.
  /// 
  /// The [firestore] parameter is required for database operations.
  const AssignmentRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;
  
  /// Retrieves all assignments for the specified class.
  /// 
  /// Returns a list of assignments ordered by creation date (newest first).
  /// Results are cached for 5 minutes to improve performance.
  /// 
  /// Throws [AssignmentException] if the operation fails.
  /// 
  /// Parameters:
  /// - [classId]: The unique identifier of the class
  /// - [forceRefresh]: If true, bypasses cache and fetches fresh data
  /// 
  /// Returns:
  /// A [Future] that completes with a list of [Assignment] objects.
  Future<List<Assignment>> getAssignments(
    String classId, {
    bool forceRefresh = false,
  }) async {
    // Implementation with detailed comments
  }
  
  /// Creates a new assignment in the specified class.
  /// 
  /// The assignment will be validated before creation. Due date must be
  /// in the future, and title must not be empty.
  /// 
  /// Throws [ValidationException] if the assignment data is invalid.
  /// Throws [AssignmentException] if the creation operation fails.
  /// 
  /// Parameters:
  /// - [classId]: The class where the assignment will be created
  /// - [assignment]: The assignment data to create
  /// 
  /// Returns:
  /// A [Future] that completes with the created assignment including
  /// the generated ID.
  Future<Assignment> createAssignment(
    String classId,
    Assignment assignment,
  ) async {
    // Implementation
  }
}
```

### README Documentation
```markdown
# Assignment Management Feature

## Overview
The assignment management feature allows teachers to create, edit, and grade assignments while students can view and submit their work.

## Architecture
```
assignments/
├── data/
│   ├── repositories/assignment_repository_impl.dart
│   └── services/assignment_service.dart
├── domain/
│   ├── models/assignment_model.dart
│   └── repositories/assignment_repository.dart
└── presentation/
    ├── screens/assignment_list_screen.dart
    ├── widgets/assignment_card.dart
    └── providers/assignment_provider.dart
```

## Key Components

### AssignmentRepository
Handles all data operations for assignments including:
- Creating new assignments
- Retrieving assignment lists
- Updating assignment details
- Managing submission data

### AssignmentProvider
Manages assignment state throughout the application:
- Loading states
- Error handling
- Real-time updates
- User interactions

## Usage Examples

### Creating an Assignment
```dart
final provider = context.read<AssignmentProvider>();
await provider.createAssignment(
  classId: 'class-123',
  assignment: Assignment(
    title: 'Math Quiz Chapter 5',
    description: 'Complete problems 1-20',
    dueDate: DateTime.now().add(Duration(days: 7)),
    totalPoints: 100,
  ),
);
```
```

## Performance Guidelines

### Widget Performance
```dart
// ✅ Good: Optimized widget building
class OptimizedAssignmentList extends StatelessWidget {
  final List<Assignment> assignments;
  
  const OptimizedAssignmentList({
    super.key,
    required this.assignments,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Use builder for large lists
      itemCount: assignments.length,
      itemBuilder: (context, index) => AssignmentListItem(
        key: ValueKey(assignments[index].id), // Stable keys
        assignment: assignments[index],
      ),
      // Add separators efficiently
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }
}

class AssignmentListItem extends StatelessWidget {
  final Assignment assignment;
  
  const AssignmentListItem({
    super.key,
    required this.assignment,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.assignment), // Const icons
      title: Text(assignment.title),
      subtitle: Text(
        assignment.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text('${assignment.totalPoints} pts'),
    );
  }
}

// ❌ Bad: Inefficient widget building
class InefficiencyAssignmentList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AssignmentProvider>(
      builder: (context, provider, child) {
        // Rebuilds entire list on any change
        return Column(
          children: provider.assignments.map((assignment) {
            return Container( // Unnecessary container
              child: ListTile(
                leading: Icon(Icons.assignment), // Non-const icon
                title: Text(assignment.title),
                subtitle: Text(assignment.description), // No maxLines
                trailing: Container( // Unnecessary wrapper
                  child: Text('${assignment.totalPoints} pts'),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
```

### State Management Performance
```dart
// ✅ Good: Selective rebuilding with Selector
class AssignmentCounter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<AssignmentProvider, int>(
      selector: (context, provider) => provider.assignments.length,
      builder: (context, count, child) => Text('$count assignments'),
    );
  }
}

// Use Consumer2 for multiple providers
class AssignmentStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AssignmentProvider, GradeProvider>(
      builder: (context, assignmentProvider, gradeProvider, child) {
        return Column(
          children: [
            Text('Assignments: ${assignmentProvider.assignments.length}'),
            Text('Graded: ${gradeProvider.gradedCount}'),
          ],
        );
      },
    );
  }
}
```

## Security Standards

### Data Validation
```dart
// ✅ Good: Input validation and sanitization
class AssignmentValidator {
  static ValidationResult validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return const ValidationResult.invalid('Title is required');
    }
    
    final trimmedTitle = title.trim();
    if (trimmedTitle.length < 3) {
      return const ValidationResult.invalid('Title must be at least 3 characters');
    }
    
    if (trimmedTitle.length > 100) {
      return const ValidationResult.invalid('Title must not exceed 100 characters');
    }
    
    // Check for malicious content
    if (_containsMaliciousContent(trimmedTitle)) {
      return const ValidationResult.invalid('Title contains invalid characters');
    }
    
    return ValidationResult.valid(trimmedTitle);
  }
  
  static ValidationResult validateDueDate(DateTime? dueDate) {
    if (dueDate == null) {
      return const ValidationResult.invalid('Due date is required');
    }
    
    final now = DateTime.now();
    final minDate = now.add(const Duration(hours: 1)); // At least 1 hour from now
    final maxDate = now.add(const Duration(days: 365)); // Not more than 1 year
    
    if (dueDate.isBefore(minDate)) {
      return const ValidationResult.invalid('Due date must be at least 1 hour from now');
    }
    
    if (dueDate.isAfter(maxDate)) {
      return const ValidationResult.invalid('Due date cannot be more than 1 year from now');
    }
    
    return ValidationResult.valid(dueDate);
  }
  
  static bool _containsMaliciousContent(String input) {
    final maliciousPatterns = [
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),
    ];
    
    return maliciousPatterns.any((pattern) => pattern.hasMatch(input));
  }
}
```

### Secure Data Handling
```dart
// ✅ Good: Secure Firebase operations
class SecureAssignmentService {
  Future<void> createAssignment(Assignment assignment) async {
    // Validate current user permissions
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw AuthenticationException('User must be authenticated');
    }
    
    // Verify user role
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    final userRole = userDoc.data()?['role'] as String?;
    if (userRole != 'teacher') {
      throw AuthorizationException('Only teachers can create assignments');
    }
    
    // Validate assignment data
    final validatedAssignment = _validateAndSanitizeAssignment(assignment);
    
    // Use security rules compliant structure
    await FirebaseFirestore.instance
        .collection('assignments')
        .add({
      ...validatedAssignment.toJson(),
      'teacherId': currentUser.uid, // Ensure teacher ownership
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  Assignment _validateAndSanitizeAssignment(Assignment assignment) {
    return assignment.copyWith(
      title: _sanitizeString(assignment.title),
      description: _sanitizeString(assignment.description),
      // Remove any potentially dangerous content
    );
  }
  
  String _sanitizeString(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[^\w\s\-.,!?()]'), '') // Allow only safe characters
        .trim();
  }
}
```

[content placeholder]