# 🚀 Comprehensive Developer Guide

*Complete development workflows, best practices, and advanced techniques for the Teacher Dashboard Flutter Firebase project*

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
2. [Project Architecture Deep Dive](#project-architecture-deep-dive) 
3. [Feature Development Workflows](#feature-development-workflows)
4. [Testing & Quality Assurance](#testing--quality-assurance)
5. [Performance Optimization](#performance-optimization)
6. [Security Best Practices](#security-best-practices)
7. [Deployment & CI/CD](#deployment--cicd)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Advanced Patterns](#advanced-patterns)
10. [Contributing Guidelines](#contributing-guidelines)

---

## Development Environment Setup

### Prerequisites Checklist

**Required Tools**:
- ✅ Flutter SDK 3.6.0+
- ✅ Dart SDK 3.2.0+
- ✅ Firebase CLI 12.0.0+
- ✅ Node.js 18.0.0+ (for Firebase Functions)
- ✅ Git 2.30.0+
- ✅ VS Code or Android Studio

**Platform-Specific Requirements**:
- **iOS**: Xcode 14.0+, CocoaPods 1.11.0+
- **Android**: Android SDK 33+, Java 11+
- **Web**: Chrome 100+ for debugging
- **Desktop**: Platform-specific toolchains

### Quick Setup Commands

```bash
# Clone and setup
git clone <repository-url>
cd teacher-dashboard-flutter-firebase

# Install dependencies
flutter pub get

# Setup Firebase (requires configuration)
firebase login
firebase use <project-id>

# Run platform-specific setup
flutter precache
flutter doctor -v

# Start development server
flutter run -d chrome # Web
flutter run -d <device-id> # Mobile
```

### IDE Configuration

**VS Code Extensions**:
```json
{
  "recommendations": [
    "Dart-Code.dart-code",
    "Dart-Code.flutter",
    "firebase.firebase-vscode",
    "ms-vscode.vscode-json",
    "bradlc.vscode-tailwindcss"
  ]
}
```

**Workspace Settings**:
```json
{
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  },
  "dart.debugExternalPackageLibraries": false,
  "dart.debugSdkLibraries": false
}
```

---

## Project Architecture Deep Dive

### Clean Architecture Implementation

The project follows Uncle Bob's Clean Architecture with three distinct layers:

```
┌─────────────────────────────────────────────────────────┐
│                  PRESENTATION LAYER                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Screens   │  │  Providers  │  │   Widgets   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                          │
                    Dependency
                          │
┌─────────────────────────────────────────────────────────┐
│                   DOMAIN LAYER                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Models    │  │ Repositories│  │ Use Cases   │     │
│  │ (Entities)  │  │(Interfaces) │  │(Business)   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                          │
                    Implementation
                          │
┌─────────────────────────────────────────────────────────┐
│                    DATA LAYER                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Repositories│  │  Services   │  │ Data Sources│     │
│  │(Concrete)   │  │             │  │             │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Dependency Injection Pattern

**Service Locator Setup** (`lib/shared/core/service_locator.dart`):

```dart
void setupServiceLocator() {
  // Layer 1: Firebase Infrastructure
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  
  // Layer 2: Repository Contracts
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<AuthService>())
  );
  
  // Layer 3: Business Services  
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(getIt<FirebaseAuth>())
  );
}
```

**Usage in Providers**:

```dart
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = getIt<AuthRepository>();
  
  // Provider implementation...
}
```

### Feature-Based Organization

Each feature follows the same architectural pattern:

```
features/auth/
├── data/
│   ├── repositories/          # Repository implementations
│   │   └── auth_repository_impl.dart
│   └── services/             # External API integrations
│       └── auth_service.dart
├── domain/
│   ├── models/               # Core entities and data models
│   │   └── user_model.dart
│   └── repositories/         # Repository contracts/interfaces
│       └── auth_repository.dart
└── presentation/
    ├── providers/            # Feature-specific state management
    │   └── auth_provider.dart
    ├── screens/              # UI screens for this feature
    │   └── login_screen.dart
    └── widgets/              # Feature-specific UI components
        └── login_form.dart
```

---

## Feature Development Workflows

### Creating a New Feature

**Step 1: Feature Planning**
```bash
# Create feature directory structure
mkdir -p lib/features/new_feature/{data/{repositories,services},domain/{models,repositories},presentation/{providers,screens,widgets}}

# Add to service locator registration
# Register repositories and services in service_locator.dart
```

**Step 2: Domain Layer (Business Logic)**
```dart
// 1. Create domain models
class NewFeatureModel {
  final String id;
  final String name;
  final DateTime createdAt;
  
  const NewFeatureModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });
}

// 2. Define repository contract
abstract class NewFeatureRepository extends BaseRepository {
  Future<String> create(NewFeatureModel model);
  Future<NewFeatureModel?> getById(String id);
  Stream<List<NewFeatureModel>> getAll();
}
```

**Step 3: Data Layer (External Interfaces)**
```dart
// 1. Implement repository
class NewFeatureRepositoryImpl implements NewFeatureRepository {
  final NewFeatureService _service;
  
  NewFeatureRepositoryImpl(this._service);
  
  @override
  Future<String> create(NewFeatureModel model) async {
    return await _service.createDocument(model.toJson());
  }
}

// 2. Create service for external APIs
class NewFeatureService {
  final FirebaseFirestore _firestore;
  
  NewFeatureService(this._firestore);
  
  Future<String> createDocument(Map<String, dynamic> data) async {
    final doc = await _firestore.collection('new_features').add(data);
    return doc.id;
  }
}
```

**Step 4: Presentation Layer (UI)**
```dart
// 1. Create provider for state management
class NewFeatureProvider extends ChangeNotifier {
  final NewFeatureRepository _repository = getIt<NewFeatureRepository>();
  
  List<NewFeatureModel> _items = [];
  bool _isLoading = false;
  
  List<NewFeatureModel> get items => _items;
  bool get isLoading => _isLoading;
  
  Future<void> loadItems() async {
    _setLoading(true);
    _repository.getAll().listen((items) {
      _items = items;
      notifyListeners();
    });
    _setLoading(false);
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

// 2. Create screens and widgets
class NewFeatureScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Feature')),
      body: Consumer<NewFeatureProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }
          
          return ListView.builder(
            itemCount: provider.items.length,
            itemBuilder: (context, index) {
              final item = provider.items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(item.createdAt.toString()),
              );
            },
          );
        },
      ),
    );
  }
}
```

**Step 5: Integration**
```dart
// 1. Register in service locator
void setupServiceLocator() {
  // Add to existing registrations
  getIt.registerLazySingleton<NewFeatureService>(
    () => NewFeatureService(getIt<FirebaseFirestore>())
  );
  getIt.registerLazySingleton<NewFeatureRepository>(
    () => NewFeatureRepositoryImpl(getIt<NewFeatureService>())
  );
}

// 2. Add routes in app_router.dart
GoRoute(
  path: '/new-feature',
  name: 'new-feature',
  builder: (context, state) => NewFeatureScreen(),
),

// 3. Register provider in main.dart
MultiProvider(
  providers: [
    // Existing providers...
    ChangeNotifierProvider(create: (_) => NewFeatureProvider()),
  ],
  child: MyApp(),
)
```

### Modifying Existing Features

**Safe Modification Process**:

1. **Understand Current Implementation**:
   ```bash
   # Analyze existing code
   find lib/features/target_feature -name "*.dart" -exec grep -l "specific_method" {} \;
   
   # Check dependencies
   grep -r "TargetFeatureProvider" lib/
   ```

2. **Create Feature Branch**:
   ```bash
   git checkout -b feature/enhance-target-feature
   ```

3. **Follow TDD Approach**:
   ```dart
   // 1. Write failing tests first
   test('should update feature correctly', () async {
     // Arrange
     final provider = TargetFeatureProvider();
     
     // Act
     await provider.updateFeature(testData);
     
     // Assert
     expect(provider.isUpdated, true);
   });
   
   // 2. Implement minimal code to pass tests
   // 3. Refactor for quality
   ```

4. **Test Integration**:
   ```bash
   # Run all tests
   flutter test
   
   # Run specific feature tests
   flutter test test/features/target_feature/
   
   # Integration tests
   flutter test integration_test/
   ```

---

## Testing & Quality Assurance

### Testing Strategy

**Testing Pyramid Implementation**:

```
        ╭─────────────╮
       ╱  E2E Tests   ╲     ← 10% (High-level workflows)
      ╱   (Slow)       ╲
     ╱─────────────────╲
    ╱  Integration     ╲    ← 20% (Feature interactions)
   ╱     Tests          ╲
  ╱     (Medium)        ╲
 ╱─────────────────────╲
╱      Unit Tests       ╲   ← 70% (Individual functions)
╲       (Fast)          ╱
 ╲─────────────────────╱
```

### Unit Testing Patterns

**Repository Testing**:
```dart
// test/features/auth/data/repositories/auth_repository_test.dart
void main() {
  group('AuthRepository', () {
    late AuthRepository repository;
    late MockAuthService mockService;
    
    setUp(() {
      mockService = MockAuthService();
      repository = AuthRepositoryImpl(mockService);
    });
    
    test('should return user when sign in is successful', () async {
      // Arrange
      final testUser = UserModel(id: '1', email: 'test@test.com');
      when(mockService.signInWithEmail(any, any))
          .thenAnswer((_) async => testUser);
      
      // Act
      final result = await repository.signInWithEmail('test@test.com', 'password');
      
      // Assert
      expect(result, equals(testUser));
      verify(mockService.signInWithEmail('test@test.com', 'password'));
    });
  });
}
```

**Provider Testing**:
```dart
// test/features/auth/presentation/providers/auth_provider_test.dart
void main() {
  group('AuthProvider', () {
    late AuthProvider provider;
    late MockAuthRepository mockRepository;
    
    setUp(() {
      mockRepository = MockAuthRepository();
      provider = AuthProvider()..setRepository(mockRepository);
    });
    
    test('should update status to authenticated when sign in succeeds', () async {
      // Arrange
      final testUser = UserModel(id: '1', email: 'test@test.com');
      when(mockRepository.signInWithEmail(any, any))
          .thenAnswer((_) async => testUser);
      
      // Act
      await provider.signIn('test@test.com', 'password');
      
      // Assert
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.currentUser, testUser);
    });
  });
}
```

### Widget Testing

**Screen Testing Pattern**:
```dart
// test/features/auth/presentation/screens/login_screen_test.dart
void main() {
  group('LoginScreen', () {
    testWidgets('should display login form', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockAuthProvider(),
            child: LoginScreen(),
          ),
        ),
      );
      
      // Assert
      expect(find.byType(TextField), findsNWidgets(2)); // Email and password
      expect(find.byType(ElevatedButton), findsOneWidget); // Login button
      expect(find.text('Login'), findsOneWidget);
    });
    
    testWidgets('should call provider sign in when button pressed', (WidgetTester tester) async {
      // Arrange
      final mockProvider = MockAuthProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: mockProvider,
            child: LoginScreen(),
          ),
        ),
      );
      
      // Act
      await tester.enterText(find.byType(TextField).first, 'test@test.com');
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.tap(find.byType(ElevatedButton));
      
      // Assert
      verify(mockProvider.signIn('test@test.com', 'password'));
    });
  });
}
```

### Integration Testing

**End-to-End Testing**:
```dart
// integration_test/app_test.dart
void main() {
  group('App Integration Tests', () {
    testWidgets('complete authentication flow', (WidgetTester tester) async {
      // Start app
      app.main();
      await tester.pumpAndSettle();
      
      // Navigate to login
      expect(find.text('Login'), findsOneWidget);
      
      // Enter credentials
      await tester.enterText(find.byKey(Key('email-field')), 'test@test.com');
      await tester.enterText(find.byKey(Key('password-field')), 'password123');
      
      // Submit form
      await tester.tap(find.byKey(Key('login-button')));
      await tester.pumpAndSettle();
      
      // Verify navigation to dashboard
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
```

### Code Quality Tools

**Analysis Options Configuration**:
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - build/**
    - lib/**.g.dart
    - lib/**.freezed.dart
  
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false

linter:
  rules:
    # Additional rules
    prefer_relative_imports: true
    sort_constructors_first: true
    always_declare_return_types: true
    avoid_print: true
    avoid_unnecessary_containers: true
```

**Pre-commit Hooks**:
```bash
# .git/hooks/pre-commit
#!/bin/sh
echo "Running pre-commit checks..."

# Format code
dart format --set-exit-if-changed .

# Analyze code
flutter analyze

# Run tests
flutter test

echo "All checks passed!"
```

---

## Performance Optimization

### Flutter Performance Best Practices

**Widget Optimization**:
```dart
// ❌ Bad: Rebuilds entire widget tree
class BadPerformanceWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            ExpensiveWidget(), // Rebuilds unnecessarily
            SimpleWidget(data: provider.data),
          ],
        );
      },
    );
  }
}

// ✅ Good: Optimized rebuilds
class GoodPerformanceWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpensiveWidget(), // Never rebuilds
        Consumer<DataProvider>(
          builder: (context, provider, child) {
            return SimpleWidget(data: provider.data);
          },
        ),
      ],
    );
  }
}
```

**Provider Optimization**:
```dart
// ✅ Selector for targeted rebuilds
Selector<AuthProvider, bool>(
  selector: (context, provider) => provider.isLoading,
  builder: (context, isLoading, child) {
    return isLoading 
        ? CircularProgressIndicator()
        : child!;
  },
  child: ExpensiveChildWidget(),
)
```

**List Performance**:
```dart
// ✅ Optimized list with proper keys and builders
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return ListTile(
      key: ValueKey(item.id), // Stable keys for performance
      title: Text(item.title),
      subtitle: Text(item.subtitle),
    );
  },
)
```

### Firebase Performance

**Firestore Query Optimization**:
```dart
// ❌ Bad: Inefficient query
Stream<List<Assignment>> getBadAssignments(String classId) {
  return FirebaseFirestore.instance
      .collection('assignments')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Assignment.fromJson(doc.data()))
          .where((assignment) => assignment.classId == classId) // Client-side filtering
          .toList());
}

// ✅ Good: Server-side filtering with compound index
Stream<List<Assignment>> getGoodAssignments(String classId) {
  return FirebaseFirestore.instance
      .collection('assignments')
      .where('classId', isEqualTo: classId)
      .where('isActive', isEqualTo: true)
      .orderBy('dueDate')
      .limit(50) // Limit results
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Assignment.fromJson(doc.data()))
          .toList());
}
```

**Caching Strategy**:
```dart
class CachedDataService {
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  Future<T> getCachedData<T>(
    String key,
    Future<T> Function() fetchFunction,
  ) async {
    final cached = _cache[key];
    
    if (cached != null && 
        DateTime.now().difference(cached['timestamp']) < _cacheTimeout) {
      return cached['data'] as T;
    }
    
    final data = await fetchFunction();
    _cache[key] = {
      'data': data,
      'timestamp': DateTime.now(),
    };
    
    return data;
  }
}
```

### Memory Management

**Stream Subscription Management**:
```dart
class ProperStreamManagement extends StatefulWidget {
  @override
  _ProperStreamManagementState createState() => _ProperStreamManagementState();
}

class _ProperStreamManagementState extends State<ProperStreamManagement> {
  StreamSubscription? _dataSubscription;
  StreamSubscription? _authSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupStreams();
  }
  
  void _setupStreams() {
    _dataSubscription = DataService().dataStream.listen((data) {
      // Handle data updates
    });
    
    _authSubscription = AuthService().authStateChanges.listen((user) {
      // Handle auth changes
    });
  }
  
  @override
  void dispose() {
    _dataSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(); // Widget content
  }
}
```

---

## Security Best Practices

### Authentication Security

**Secure Token Handling**:
```dart
class SecureAuthService {
  static const _storage = FlutterSecureStorage();
  
  Future<void> storeTokenSecurely(String token) async {
    await _storage.write(
      key: 'auth_token',
      value: token,
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: IOSAccessibility.first_unlock_this_device,
      ),
    );
  }
  
  Future<String?> getStoredToken() async {
    return await _storage.read(key: 'auth_token');
  }
  
  Future<void> clearStoredToken() async {
    await _storage.delete(key: 'auth_token');
  }
}
```

**Input Validation**:
```dart
class ValidationUtils {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }
  
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    // Additional strength checks
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    if (!hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
      return 'Password must contain uppercase, lowercase, numbers, and special characters';
    }
    
    return null;
  }
}
```

### Firebase Security Rules

**Firestore Security Rules**:
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User profile security
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Class-based access control
    match /classes/{classId} {
      allow read: if request.auth != null && 
        (request.auth.uid == resource.data.teacherId ||
         request.auth.uid in resource.data.studentIds);
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.teacherId;
    }
    
    // Assignment security
    match /assignments/{assignmentId} {
      allow read: if request.auth != null &&
        exists(/databases/$(database)/documents/classes/$(resource.data.classId)) &&
        (request.auth.uid == get(/databases/$(database)/documents/classes/$(resource.data.classId)).data.teacherId ||
         request.auth.uid in get(/databases/$(database)/documents/classes/$(resource.data.classId)).data.studentIds);
      allow write: if request.auth != null &&
        exists(/databases/$(database)/documents/classes/$(resource.data.classId)) &&
        request.auth.uid == get(/databases/$(database)/documents/classes/$(resource.data.classId)).data.teacherId;
    }
  }
}
```

**Storage Security Rules**:
```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User profile images
    match /profile_images/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Assignment submissions
    match /assignments/{classId}/{assignmentId}/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == userId || 
         isTeacherOfClass(classId));
    }
  }
}

function isTeacherOfClass(classId) {
  return request.auth != null &&
    exists(/databases/$(database)/documents/classes/$(classId)) &&
    request.auth.uid == get(/databases/$(database)/documents/classes/$(classId)).data.teacherId;
}
```

### Data Protection

**Sensitive Data Handling**:
```dart
class DataProtectionService {
  // Never log sensitive information
  static void logSafely(String message, {Map<String, dynamic>? data}) {
    final sanitizedData = data != null ? _sanitizeData(data) : null;
    logger.info(message, sanitizedData);
  }
  
  static Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    
    // Remove sensitive fields
    final sensitiveFields = ['password', 'token', 'email', 'phone', 'ssn'];
    for (final field in sensitiveFields) {
      if (sanitized.containsKey(field)) {
        sanitized[field] = '[REDACTED]';
      }
    }
    
    return sanitized;
  }
  
  // Encrypt sensitive data before storage
  static String encryptSensitiveData(String data) {
    // Use proper encryption library
    // This is a placeholder implementation
    return base64Encode(utf8.encode(data));
  }
}
```

---

## Deployment & CI/CD

### Build Configuration

**Environment-Specific Builds**:
```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/config/
    - assets/images/

# Different configurations for environments
```

**Build Scripts**:
```bash
#!/bin/bash
# scripts/build.sh

set -e

ENVIRONMENT=${1:-development}
PLATFORM=${2:-web}

echo "Building for $ENVIRONMENT environment on $PLATFORM platform..."

# Set environment variables
if [ "$ENVIRONMENT" = "production" ]; then
    export FIREBASE_PROJECT_ID="teacher-dashboard-prod"
elif [ "$ENVIRONMENT" = "staging" ]; then
    export FIREBASE_PROJECT_ID="teacher-dashboard-staging"
else
    export FIREBASE_PROJECT_ID="teacher-dashboard-dev"
fi

# Build based on platform
case $PLATFORM in
    "web")
        flutter build web --release --dart-define=ENVIRONMENT=$ENVIRONMENT
        ;;
    "android")
        flutter build apk --release --dart-define=ENVIRONMENT=$ENVIRONMENT
        ;;
    "ios")
        flutter build ios --release --dart-define=ENVIRONMENT=$ENVIRONMENT
        ;;
    *)
        echo "Unknown platform: $PLATFORM"
        exit 1
        ;;
esac

echo "Build completed successfully!"
```

### GitHub Actions CI/CD

**Main Workflow** (`.github/workflows/ci-cd.yml`):
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.6.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run analyzer
        run: flutter analyze
        
      - name: Run tests
        run: flutter test --coverage
        
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info

  build-web:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.6.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build web
        run: flutter build web --release
        
      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: teacher-dashboard-prod

  build-mobile:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.6.0'
          
      - name: Setup Android SDK
        uses: android-actions/setup-android@v2
        
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build APK
        run: flutter build apk --release
        
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

### Firebase Hosting Configuration

**Firebase Configuration** (`firebase.json`):
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

---

## Troubleshooting Guide

### Common Issues & Solutions

**Firebase Connection Issues**:
```dart
// Issue: Firebase not initializing
// Solution: Proper initialization in main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
    // Handle initialization failure
  }
  
  runApp(MyApp());
}
```

**Provider State Issues**:
```dart
// Issue: Provider not updating UI
// Solution: Ensure proper notifyListeners() calls
class MyProvider extends ChangeNotifier {
  bool _isLoading = false;
  
  bool get isLoading => _isLoading;
  
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners(); // ✅ Notify before async operation
    
    try {
      // Async operation
      await someAsyncOperation();
    } finally {
      _isLoading = false;
      notifyListeners(); // ✅ Notify after completion
    }
  }
}
```

**Navigation Issues**:
```dart
// Issue: Navigation not working with GoRouter
// Solution: Proper context usage
class NavigationHelper {
  static void navigateToScreen(BuildContext context, String routeName) {
    // ✅ Use context.go for simple navigation
    context.go('/route-name');
    
    // ✅ Use context.push for stack navigation
    context.push('/modal-route');
    
    // ✅ Use context.replace for replacement
    context.replace('/new-route');
  }
}
```

### Debugging Techniques

**Logging Strategy**:
```dart
import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );
  
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error, stackTrace);
  }
  
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error, stackTrace);
  }
  
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error, stackTrace);
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error, stackTrace);
  }
}
```

**Performance Profiling**:
```dart
class PerformanceProfiler {
  static final Map<String, DateTime> _startTimes = {};
  
  static void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
    AppLogger.debug('Started: $operation');
  }
  
  static void endTimer(String operation) {
    final startTime = _startTimes[operation];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      AppLogger.info('Completed: $operation in ${duration.inMilliseconds}ms');
      _startTimes.remove(operation);
    }
  }
}

// Usage
PerformanceProfiler.startTimer('loadUserData');
await loadUserData();
PerformanceProfiler.endTimer('loadUserData');
```

---

## Advanced Patterns

### Reactive Programming with Streams

**Stream Transformation**:
```dart
class ReactiveDataService {
  final StreamController<List<Assignment>> _assignmentsController = 
      StreamController<List<Assignment>>.broadcast();
  
  Stream<List<Assignment>> get assignments => _assignmentsController.stream;
  
  // Transform stream for different views
  Stream<List<Assignment>> get upcomingAssignments => assignments
      .map((assignments) => assignments
          .where((a) => a.dueDate.isAfter(DateTime.now()))
          .toList());
  
  Stream<List<Assignment>> get overdueAssignments => assignments
      .map((assignments) => assignments
          .where((a) => a.dueDate.isBefore(DateTime.now()) && !a.isCompleted)
          .toList());
  
  Stream<int> get totalAssignmentCount => assignments
      .map((assignments) => assignments.length);
}
```

**Combining Multiple Streams**:
```dart
class CombinedDataProvider extends ChangeNotifier {
  late final Stream<DashboardData> _dashboardStream;
  
  CombinedDataProvider() {
    _dashboardStream = Rx.combineLatest3(
      classService.userClasses,
      assignmentService.userAssignments,
      gradeService.userGrades,
      (classes, assignments, grades) => DashboardData(
        classes: classes,
        assignments: assignments,
        grades: grades,
      ),
    );
    
    _dashboardStream.listen((data) {
      // Update UI
      notifyListeners();
    });
  }
}
```

### State Management Patterns

**Complex State with Riverpod Alternative**:
```dart
// Using StateNotifier pattern
class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(AuthState.initial());
  
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    
    try {
      final user = await authRepository.signIn(email, password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }
}
```

### Error Handling Patterns

**Global Error Handler**:
```dart
class GlobalErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(details.exception, details.stack);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(error, stack);
      return true;
    };
  }
  
  static void _logError(dynamic error, StackTrace? stack) {
    AppLogger.error('Global error caught', error, stack);
    
    // Send to crash reporting service
    FirebaseCrashlytics.instance.recordError(error, stack);
    
    // Show user-friendly error message
    if (navigatorKey.currentContext != null) {
      _showErrorSnackBar(navigatorKey.currentContext!, error.toString());
    }
  }
  
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('An error occurred: ${_getUserFriendlyMessage(message)}'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Report',
          onPressed: () => _reportError(message),
        ),
      ),
    );
  }
  
  static String _getUserFriendlyMessage(String error) {
    // Convert technical errors to user-friendly messages
    if (error.contains('network')) return 'Connection problem';
    if (error.contains('permission')) return 'Permission denied';
    return 'Something went wrong';
  }
}
```

---

## Contributing Guidelines

### Code Style Guidelines

**Naming Conventions**:
```dart
// ✅ Good naming examples
class UserProfileProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final UserService _userService;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters use descriptive names
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Methods use action verbs
  Future<void> loadUserProfile() async { }
  Future<void> updateUserProfile(UserModel user) async { }
  void clearErrorMessage() { }
}
```

**File Organization**:
```
lib/
├── features/
│   └── feature_name/
│       ├── data/
│       │   ├── repositories/
│       │   │   └── feature_repository_impl.dart    # Implementation
│       │   └── services/
│       │       └── feature_service.dart            # External APIs
│       ├── domain/
│       │   ├── models/
│       │   │   └── feature_model.dart              # Data entities
│       │   └── repositories/
│       │       └── feature_repository.dart         # Contracts
│       └── presentation/
│           ├── providers/
│           │   └── feature_provider.dart           # State management
│           ├── screens/
│           │   └── feature_screen.dart             # Main screens
│           └── widgets/
│               └── feature_widget.dart             # UI components
└── shared/
    ├── core/                                       # App-wide setup
    ├── models/                                     # Shared data models
    ├── repositories/                               # Base contracts
    ├── services/                                   # Business logic
    ├── utils/                                      # Helper functions
    └── widgets/                                    # Reusable UI
```

**Documentation Standards**:
```dart
/// Service responsible for managing user authentication state.
/// 
/// This service provides methods for sign in, sign out, and monitoring
/// authentication state changes. It integrates with Firebase Auth and
/// manages local authentication persistence.
/// 
/// Example usage:
/// ```dart
/// final authService = AuthService();
/// final user = await authService.signInWithEmail('user@example.com', 'password');
/// ```
class AuthService {
  /// Signs in a user with email and password.
  /// 
  /// Returns the authenticated user on success, or throws an exception
  /// if authentication fails.
  /// 
  /// Throws:
  /// - [FirebaseAuthException] if authentication fails
  /// - [NetworkException] if network connectivity is unavailable
  Future<UserModel> signInWithEmail(String email, String password) async {
    // Implementation...
  }
}
```

### Pull Request Guidelines

**PR Template**:
```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No console.log or print statements left in code
```

**Review Process**:
1. **Automated Checks**: CI/CD pipeline runs tests and analysis
2. **Code Review**: At least one team member reviews changes
3. **Testing**: Manual testing on target platforms
4. **Documentation**: Updates to relevant documentation
5. **Approval**: Required approvals before merge

### Version Control Best Practices

**Branch Naming**:
```bash
# Feature branches
feature/add-user-authentication
feature/improve-dashboard-performance

# Bug fixes
bugfix/fix-login-validation
hotfix/critical-data-loss

# Maintenance
chore/update-dependencies
docs/update-readme
```

**Commit Message Format**:
```bash
# Format: type(scope): description
feat(auth): add Google Sign-In integration
fix(grades): resolve calculation error in GPA
docs(readme): update installation instructions
test(assignment): add unit tests for submission logic
refactor(provider): simplify state management logic
```

---

## Conclusion

This comprehensive developer guide provides the foundation for effective development on the Teacher Dashboard Flutter Firebase project. By following these patterns, practices, and guidelines, developers can maintain code quality, ensure security, and deliver performant features.

### Key Takeaways

1. **Architecture First**: Always understand the Clean Architecture principles before making changes
2. **Test-Driven Development**: Write tests before implementing features
3. **Security by Design**: Consider security implications at every step
4. **Performance Matters**: Profile and optimize regularly
5. **Documentation Is Code**: Keep documentation updated with code changes

### Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Clean Architecture Guide](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Provider Package Documentation](https://pub.dev/packages/provider)
- [GoRouter Documentation](https://pub.dev/packages/go_router)

---

*For questions or suggestions about this guide, please open an issue in the project repository.*