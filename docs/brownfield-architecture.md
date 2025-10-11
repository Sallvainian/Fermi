# Fermi Plus Brownfield Architecture Document

## Introduction

This document captures the **CURRENT STATE** of the Fermi Plus codebase, including technical debt, workarounds, and real-world patterns. It serves as a reference for AI agents working on enhancements and provides a comprehensive baseline for modernization and optimization efforts.

**Project Status**: Production v0.9.6 (May 2024 - Present)
**Development Approach**: Vibe-coded MVP → Production hardening → Modernization phase

### Document Scope

Comprehensive documentation of entire system for full-scale optimization and modernization.

### Change Log

| Date       | Version | Description                 | Author  |
| ---------- | ------- | --------------------------- | ------- |
| 2025-10-11 | 1.0     | Initial brownfield analysis | Winston |

---

## Quick Reference - Key Files and Entry Points

### Critical Files for Understanding the System

- **Main Entry**: `lib/main.dart` - Application bootstrap with Firebase initialization
- **App Configuration**: `pubspec.yaml` - Dependencies and project metadata
- **Core Initialization**: `lib/shared/core/app_initializer.dart` - Firebase and service setup
- **Service Locator**: `lib/shared/core/service_locator.dart` - Dependency injection setup
- **Routing Configuration**: `lib/shared/routing/app_router.dart` - GoRouter navigation
- **Firebase Configuration**: `firestore.rules`, `storage.rules`, `firestore.indexes.json`
- **Environment Config**: `.env` (OAuth credentials, not in git)

### Business Logic Layers

- **Feature Services**: `lib/features/*/data/services/*.dart` - Feature-specific business logic
- **Shared Services**: `lib/shared/services/*.dart` - Cross-cutting concerns
- **Domain Models**: `lib/features/*/domain/models/*.dart` - Business entities
- **State Management**: `lib/features/*/presentation/providers/*.dart` - Provider pattern

### Key Architectural Patterns

- **Feature-First Architecture**: `lib/features/` - Modular feature organization
- **Provider Pattern**: Used throughout for state management
- **Repository Pattern**: Implicit in service layer design
- **Service Layer**: Clean separation between UI and data access
- **Platform Abstraction**: Factory pattern for platform-specific implementations

---

## High Level Architecture

### Technical Summary

**Project Type**: Multi-platform Flutter Application
**Development Phase**: Production with technical debt from rapid MVP development
**Current Status**: Functional production system requiring optimization and documentation
**Key Characteristic**: "Vibe-coded" MVP evolved into production without formal architecture documentation

### Actual Tech Stack

| Category              | Technology                        | Version      | Notes                                                        |
| --------------------- | --------------------------------- | ------------ | ------------------------------------------------------------ |
| **Framework**         | Flutter                           | 3.35.6       | Stable channel, multi-platform support                       |
| **Language**          | Dart                              | 3.9.2        | Null-safe, strong typing                                     |
| **State Management**  | Provider                          | 6.1.5+1      | Reactive pattern throughout                                  |
| **Navigation**        | GoRouter                          | 16.2.1       | Declarative routing with auth awareness                      |
| **Backend**           | Firebase Suite                    | Latest       | Auth, Firestore, Storage, Functions, Messaging, Realtime DB |
| **Database**          | Cloud Firestore                   | 6.0.0        | Primary NoSQL database with offline persistence              |
| **Realtime Database** | Firebase Realtime Database        | 12.0.0       | Used for presence/online status                              |
| **File Storage**      | Firebase Storage                  | 13.0.0       | Media and assignment file storage                            |
| **Auth**              | Firebase Auth                     | 6.0.1        | Multi-provider: Google, Apple, Email/Password, Username      |
| **Push Notifications** | Firebase Cloud Messaging         | 16.0.0       | Mobile only (Android/iOS)                                    |
| **Local Notifications** | flutter_local_notifications     | 19.4.1       | Desktop support enabled                                      |
| **Charts**            | fl_chart                          | 0.69.0       | Grade analytics and behavior reports                         |
| **Chat UI**           | flutter_chat_ui + flutter_chat_core | 2.9.0/2.8.0 | Flyer Chat integration                                       |
| **Calendar Sync**     | device_calendar                   | 4.3.3        | Platform-specific implementations                            |
| **Video**             | video_player + video_compress     | 2.10.0/3.1.4 | Assignment submissions                                       |
| **Image Handling**    | cached_network_image + image_picker | 3.4.1/1.2.0 | Performance optimization                                     |

### Repository Structure Reality Check

- **Type**: Monorepo (single Flutter application)
- **Package Manager**: Flutter pub (standard)
- **Organization**: Feature-first with shared layer
- **Notable**: No formal architecture documentation existed before this document
- **Build System**: Flutter's standard build with MSIX for Windows packaging
- **CI/CD**: GitHub Actions with multiple workflows

---

## Source Tree and Module Organization

### Project Structure (Actual)

```text
fermi_plus/
├── lib/
│   ├── features/                  # Feature-based modular architecture
│   │   ├── admin/                 # Admin dashboard, user management, bulk import
│   │   │   ├── data/services/     # User management, bulk import services
│   │   │   ├── domain/models/     # Admin user, system stats
│   │   │   └── presentation/      # Admin screens, providers, widgets
│   │   ├── assignments/           # Assignment creation, submission, grading
│   │   │   ├── data/services/     # Assignment and submission services
│   │   │   ├── domain/models/     # Assignment, submission models
│   │   │   └── presentation/      # Teacher and student assignment screens
│   │   ├── auth/                  # Authentication system
│   │   │   ├── data/services/     # Auth service, OAuth handlers (3 variants!)
│   │   │   ├── domain/            # (Empty - no domain models)
│   │   │   ├── presentation/      # Login, signup, role selection screens
│   │   │   ├── providers/         # Auth provider (DUPLICATE with presentation/providers!)
│   │   │   └── utils/             # Auth error mapper
│   │   ├── behavior_points/       # UNIQUE: Behavior tracking system
│   │   │   ├── data/              # Firestore aggregation models
│   │   │   ├── domain/            # Behavior point logic, student points
│   │   │   └── presentation/      # Behavior screens, assignment popup
│   │   ├── calendar/              # Calendar integration
│   │   │   ├── data/services/     # Platform-specific calendar services (factory!)
│   │   │   ├── domain/models/     # Calendar event model
│   │   │   └── presentation/      # Calendar screen, provider
│   │   ├── chat/                  # Real-time messaging
│   │   │   ├── data/              # Firestore chat controller, scheduled messages
│   │   │   ├── domain/models/     # Chat room, message models
│   │   │   └── presentation/      # Chat screens, providers, web image handling
│   │   ├── classes/               # Class management
│   │   │   ├── data/services/     # Class CRUD service
│   │   │   ├── domain/models/     # Class model
│   │   │   └── presentation/      # Teacher and student class screens
│   │   ├── dashboard/             # Dashboard views
│   │   │   ├── data/services/     # Dashboard data aggregation
│   │   │   └── presentation/      # (No distinct presentation layer)
│   │   ├── discussions/           # Discussion boards
│   │   │   └── presentation/      # Discussion screens and providers
│   │   ├── games/                 # Educational games (Jeopardy)
│   │   │   ├── domain/models/     # Jeopardy game model
│   │   │   └── presentation/      # Game creation and play screens
│   │   ├── grades/                # Grading system
│   │   │   ├── data/services/     # Grade service, analytics service
│   │   │   └── presentation/      # Gradebook screens (teacher and student)
│   │   ├── notifications/         # Push notifications
│   │   │   ├── data/services/     # 5+ notification service variants! (platform-specific)
│   │   │   └── presentation/      # Notification screens
│   │   ├── student/               # Student management
│   │   │   ├── data/services/     # Student service, presence service
│   │   │   └── presentation/      # Student screens
│   │   ├── students/              # (DUPLICATE? Review relationship with student/)
│   │   └── teacher/               # Teacher features
│   │       ├── domain/            # (Empty)
│   │       └── presentation/      # Teacher dashboard, account management
│   ├── shared/                    # Shared components
│   │   ├── core/                  # App initialization, DI, service locator
│   │   ├── models/                # User model, role enum
│   │   ├── providers/             # Theme provider, global state
│   │   ├── routing/               # GoRouter configuration
│   │   ├── screens/               # Settings screen
│   │   ├── services/              # 10 shared services (logger, Firestore, cache, etc.)
│   │   ├── theme/                 # Material 3 theme, typography, colors
│   │   ├── utils/                 # Utility functions
│   │   └── widgets/               # Reusable UI components (splash, PWA handlers)
│   ├── firebase_options.dart      # FlutterFire CLI generated
│   └── main.dart                  # Application entry point
├── android/                       # Android platform files
├── ios/                           # iOS platform files
├── web/                           # Web platform files
├── windows/                       # Windows platform files
├── macos/                         # macOS platform files
├── functions/                     # Firebase Cloud Functions (Node.js)
├── assets/                        # Images, icons
│   ├── images/
│   └── icon/
├── docs/                          # Documentation
│   ├── claude-code-setup.md       # Development setup notes
│   ├── refactoring_report.md      # Recent refactoring documentation
│   └── brownfield-architecture.md # THIS DOCUMENT
├── test/                          # Tests (MINIMAL - only 1 unit test found!)
│   └── unit/                      # Unit tests
├── integration_test/              # Integration tests (directory exists, contents unknown)
├── pubspec.yaml                   # Dart dependencies
├── analysis_options.yaml          # Linting rules (flutter_lints)
├── .editorconfig                  # Code style
├── firestore.rules                # Firestore security rules (COMPLEX - 800+ lines)
├── firestore.indexes.json         # Firestore indexes
├── storage.rules                  # Firebase Storage rules
├── .gitignore                     # Git ignore rules
├── README.md                      # Project documentation
├── CHANGELOG.md                   # Version history
├── PRIVACY.md                     # Privacy policy
├── Context.md                     # ContextKit documentation
└── CLAUDE.md                      # Points to Context.md
```

### Key Modules and Their Purpose

#### Core Services (`lib/shared/services/`)

- **logger_service.dart**: Centralized logging (debug, info, warning, error with tags)
- **firestore_service.dart**: Firestore abstraction with retry logic
- **firestore_repository.dart**: Generic repository pattern base
- **error_handler_service.dart**: Global error handling
- **cache_service.dart**: In-memory caching layer
- **navigation_service.dart**: Programmatic navigation helper
- **validation_service.dart**: Form validation utilities
- **retry_service.dart**: Exponential backoff retry logic
- **region_detector_service.dart**: Geographic region detection
- **caps_lock_service.dart**: Keyboard state detection (Windows-specific workaround)

#### Feature-Specific Patterns

**Authentication** (`lib/features/auth/`):
- **auth_service.dart**: Firebase Auth integration, domain-based role assignment
- **desktop_oauth_handler.dart**: OAuth flow for Windows (3 variants: default, direct, secure!)
- **username_auth_service.dart**: Custom username/password authentication
- **NOTE**: Multiple OAuth handler variants suggest iterative problem-solving without cleanup

**Behavior Points** (`lib/features/behavior_points/`):
- **UNIQUE FEATURE**: Custom gamification system for student behavior
- **behavior_points_service.dart**: Firestore aggregation with atomic operations
- **student_points_aggregate.dart**: Denormalized data model for performance
- **behavior_history_entry.dart**: Audit trail pattern
- **NOTE**: Complex Firestore transactions for maintaining point totals

**Notifications** (`lib/features/notifications/`):
- **5+ service variants**: Platform-specific implementations (web, mobile, stub, Firebase)
- **notification_service_factory.dart**: Platform detection and service instantiation
- **NOTE**: Platform abstraction done manually, no formal factory pattern initially

**Calendar** (`lib/features/calendar/`):
- **device_calendar_service_factory.dart**: Platform-specific calendar access
- **Variants**: web, mobile, stub, interface
- **NOTE**: Good platform abstraction pattern, reusable approach

---

## Data Models and APIs

### Data Models

Instead of duplicating, reference actual model files:

#### Core Models
- **User Model**: `lib/shared/models/user_model.dart` - Email, role, display name, profile data
- **User Role**: `lib/shared/models/user_model.dart` (UserRole enum) - teacher, student, parent, admin

#### Feature Models
- **Class Model**: `lib/features/classes/domain/models/class_model.dart`
- **Assignment Models**: `lib/features/assignments/domain/models/` - assignment.dart, assignment_model.dart (DUPLICATE?), submission.dart
- **Behavior Point Models**: `lib/features/behavior_points/domain/models/` - behavior.dart, behavior_point.dart, student_points.dart
- **Chat Models**: `lib/features/chat/domain/models/` - chat_room.dart, message.dart
- **Calendar Model**: `lib/features/calendar/domain/models/calendar_event.dart`
- **Grade Models**: `lib/features/grades/domain/models/` (implied, not directly observed)
- **Jeopardy Game**: `lib/features/games/domain/models/jeopardy_game.dart`

### API Specifications

- **Firebase Auth API**: Standard Firebase Auth SDK methods
- **Firestore API**: NoSQL queries with collection group queries for cross-class analytics
- **Firebase Storage API**: File upload/download for assignment submissions
- **Firebase Realtime Database API**: Presence system for online status
- **Firebase Cloud Messaging API**: Push notifications (Android/iOS only)
- **Platform-Specific APIs**: Calendar access (device_calendar), local notifications

**NOTE**: No REST API - all communication through Firebase SDKs. No OpenAPI specification.

### Firestore Database Structure (Production)

See `firestore.rules` (797 lines) for comprehensive security model.

**Key Collections**:
- `users/` - User profiles with role-based access
- `public_usernames/` - Username → UID mapping for login
- `classes/` - Class documents with nested subcollections
  - `classes/{classId}/studentPoints/{studentId}` - Behavior points aggregate
  - `classes/{classId}/studentPoints/{studentId}/history/{historyId}` - Audit trail
  - `classes/{classId}/behaviors/{behaviorId}` - Class-specific behaviors
- `assignments/` - Assignment documents
- `submissions/` - Student assignment submissions
- `grades/` - Grading records
- `chatRooms/` vs `chat_rooms/` - INCONSISTENCY: Both camelCase and snake_case collections exist!
- `conversations/` - Legacy chat system being phased out
- `discussion_boards/` - Discussion board topics with nested threads/replies/likes
- `calendar_events/` - User calendar events
- `notifications/` - User notifications
- `fcm_tokens/` - Push notification tokens
- `jeopardy_games/` - Educational game templates
- `jeopardy_sessions/` - Active game sessions
- `presence/` - Online user status
- `activities/` - Dashboard activity feed
- `scheduled_messages/` - Future message delivery
- `bug_reports/` - User-submitted bug reports

---

## Technical Debt and Known Issues

### Critical Technical Debt

1. **Testing Coverage**: CRITICAL - Only 1 unit test file found (`test/unit/firestore_thread_safe_test.dart`)
   - No comprehensive test suite
   - Manual testing is primary QA method
   - Integration tests directory exists but coverage unknown
   - Risk: Regression bugs, difficult refactoring

2. **Duplicate Code Patterns**:
   - Auth providers in TWO locations: `lib/features/auth/providers/` AND `lib/features/auth/presentation/providers/`
   - Assignment models: `assignment.dart` AND `assignment_model.dart` (consolidation needed)
   - Chat collections: `chatRooms` (camelCase) AND `chat_rooms` (snake_case) - database inconsistency
   - Features: `student/` and `students/` folders - relationship unclear

3. **OAuth Handler Proliferation**: 3 desktop OAuth variants without clear delineation
   - `desktop_oauth_handler.dart`
   - `desktop_oauth_handler_direct.dart`
   - `desktop_oauth_handler_secure.dart`
   - Suggests iterative problem-solving without cleanup phase

4. **Platform-Specific Service Variants**: Multiple notification service implementations
   - 5+ notification service files (web, mobile, stub, Firebase, web_in_app)
   - Complex platform detection logic
   - Opportunity for abstraction improvement

5. **Domain-Based Role Assignment**: Security concern addressed in recent refactoring
   - Backend assigns roles based on email domain validation
   - Client code previously overwrote roles (fixed in refactoring_report.md)
   - Firestore rules enforce domain validation (@roselleschools.org, @rosellestudent.org, @fermi-plus.com)

6. **Firestore Rules Complexity**: 797 lines of security rules
   - Multiple role-checking functions (isTeacher, isStudent, isAdmin)
   - Duplicate checks in some rules (e.g., `isAdmin() || isTheTeacher()` appears frequently)
   - Complex enrollment validation logic
   - Opportunity for rule consolidation and testing

7. **No Formal Architecture Documentation**: Until this document
   - "Vibe-coded" approach worked for MVP but needs structure for scale
   - Feature growth without architectural governance
   - Inconsistent naming conventions (camelCase vs snake_case in database)

### Workarounds and Gotchas

- **Provider Type Checking Disabled**: `Provider.debugCheckInvalidValueType = null` in main.dart
  - Reason: Flyer Chat library compatibility
  - Impact: Loses Provider type safety warnings
  - Location: `lib/main.dart:38`

- **Multi-Location .env File Search**: Complex .env file discovery logic
  - Tries 4 different paths to find .env file
  - Required for non-web platforms (Google OAuth credentials)
  - Can fail silently on web (expected behavior)
  - Location: `lib/main.dart:98-161`

- **Firebase Duplicate App Error Handling**: Graceful degradation
  - Catches duplicate app initialization errors and continues
  - Required for hot restart during development
  - Location: `lib/shared/core/app_initializer.dart:119-128`

- **Desktop Platform Detection for Firebase Messaging**:
  - Firebase Messaging only supported on Android/iOS
  - Explicit platform checks to avoid runtime errors on Windows/Mac/Linux
  - Location: `lib/shared/core/app_initializer.dart:76-89`

- **Caps Lock Service**: Windows-specific keyboard state detection
  - Required because Windows doesn't expose caps lock state natively
  - Platform-specific workaround
  - Location: `lib/shared/services/caps_lock_service.dart`

- **Chat Collection Naming Inconsistency**:
  - Must query BOTH `chatRooms` and `chat_rooms` collections
  - Firestore rules support both for backward compatibility
  - Migration to single convention incomplete
  - Impact: Increased query complexity, potential data sync issues

- **Role-Based Route Middleware**: Centralized in GoRouter redirect
  - All role checks happen in global redirect function
  - Prevents students from accessing teacher routes at router level
  - Location: `lib/shared/routing/app_router.dart:124-132`

- **Firestore Offline Persistence**: Enabled with unlimited cache
  - Required for offline functionality
  - Can cause storage issues on web browsers (quota limits)
  - Location: `lib/shared/core/app_initializer.dart:142-147`

---

## Integration Points and External Dependencies

### External Services

| Service             | Purpose                    | Integration Type    | Key Files                                                    |
| ------------------- | -------------------------- | ------------------- | ------------------------------------------------------------ |
| Firebase Auth       | Authentication             | SDK                 | `lib/features/auth/data/services/auth_service.dart`          |
| Cloud Firestore     | Primary Database           | SDK                 | `lib/shared/services/firestore_service.dart`                 |
| Firebase Storage    | File Storage               | SDK                 | Multiple features use directly via SDK                       |
| Firebase Functions  | Backend Logic              | HTTP/Callable       | `functions/` directory                                       |
| Firebase Messaging  | Push Notifications         | SDK                 | `lib/features/notifications/data/services/firebase_messaging_service.dart` |
| Firebase Realtime DB | Presence System           | SDK                 | Used in `app_initializer.dart`, presence service             |
| Google Sign-In      | OAuth (Mobile)             | SDK                 | `lib/features/auth/data/services/auth_service.dart`          |
| Sign in with Apple  | OAuth (iOS requirement)    | SDK                 | `lib/features/auth/data/services/auth_service.dart`          |
| Device Calendar API | Calendar Sync              | Platform-specific   | `lib/features/calendar/data/services/`                       |
| Local Notifications | Desktop Notifications      | flutter_local_notifications | `lib/features/notifications/data/services/notification_service.dart` |

### Internal Integration Points

- **Frontend Communication**: Flutter → Firebase SDKs → Firebase Backend
- **State Management**: Provider pattern with ChangeNotifier throughout
- **Navigation**: GoRouter with auth-aware redirects
- **File Handling**: Platform-specific pickers (image_picker, file_picker)
- **Video Processing**: video_compress for assignment submissions
- **Chat UI**: Flyer Chat UI library integration
- **Charts**: fl_chart for analytics visualizations

### Platform-Specific Integrations

**Web**:
- PWA with service worker for offline
- Web-specific notification handlers
- Browser-based OAuth flows
- HTML5 video player

**Android**:
- Google Play Services for Google Sign-In
- Firebase Cloud Messaging for push notifications
- Native calendar access via device_calendar plugin

**iOS**:
- Sign in with Apple (App Store requirement)
- APNs for push notifications
- Native calendar access
- CocoaPods for dependency management

**Windows**:
- Custom OAuth flow with local server
- MSIX packaging for Microsoft Store
- Desktop-specific notification service
- No Firebase Messaging support

**macOS**:
- Similar to Windows but with different notification APIs
- No Firebase Messaging support

---

## Development and Deployment

### Local Development Setup

**Actual steps that work**:

1. **Prerequisites**: Flutter SDK 3.32.0+, Dart 3.8.0+, Firebase CLI, Node.js
2. **Clone repository**: `git clone <repo-url>`
3. **Install dependencies**: `flutter pub get`
4. **Create .env file** with OAuth credentials:
   ```env
   GOOGLE_OAUTH_CLIENT_ID=your_client_id
   GOOGLE_OAUTH_CLIENT_SECRET=your_client_secret
   ```
5. **Firebase configuration**: Already configured via `firebase_options.dart` (FlutterFire CLI generated)
6. **Platform setup**:
   - Android: `google-services.json` in `android/app/`
   - iOS: `GoogleService-Info.plist` in `ios/Runner/`
   - Web: Firebase config in `web/index.html`
7. **Run on web (recommended)**: `flutter run -d chrome`

**Known issues with setup**:
- .env file discovery can be confusing (tries 4 different paths)
- Firebase duplicate app error during hot restart (expected, handled gracefully)
- Windows OAuth requires local server on port 8080 (can conflict with other apps)

### Build and Deployment Process

**Build Commands** (from pubspec.yaml scripts):
```bash
flutter build web --release          # Web production build
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android App Bundle (Google Play)
flutter build ios --release          # iOS (macOS only)
flutter build windows --release      # Windows desktop
flutter build macos --release        # macOS desktop
```

**Deployment**:
- **Web**: Firebase Hosting via GitHub Actions (`02_deploy_web.yml`)
- **Android**: Manual deployment to Google Play (no automated workflow)
- **iOS**: Manual deployment to App Store (no automated workflow)
- **Windows**: MSIX package generation via `msix` package (configuration in pubspec.yaml)

**Environments**:
- **Development**: Local Flutter run with Firebase dev project
- **Production**: Firebase project `teacher-dashboard-flutterfire`
- **No staging environment** defined

**CI/CD Workflows** (`.github/workflows/`):
- `01_ci.yml`: Code quality, linting, dead code detection on PRs
- `02_deploy_web.yml`: Builds and deploys web app to Firebase Hosting on main branch
- Additional workflows for Windows/macOS releases

---

## Testing Reality

### Current Test Coverage

**Unit Tests**:
- **Coverage**: <5% (only 1 test file found)
- **Location**: `test/unit/firestore_thread_safe_test.dart`
- **Framework**: Flutter Test SDK

**Widget Tests**:
- **Coverage**: 0% (no widget tests found)

**Integration Tests**:
- **Directory exists**: `integration_test/`
- **Coverage unknown**: Files not analyzed in this document

**E2E Tests**: None

**Manual Testing**: Primary QA method

### Running Tests

```bash
flutter test                     # Runs all tests (very few exist!)
flutter test --coverage          # Generate coverage report
flutter test test/unit/          # Run unit tests
flutter test integration_test/   # Run integration tests
```

**NOTE**: Test commands are validated during ContextKit setup but actual test coverage is minimal.

### Code Quality Tools

```bash
flutter analyze                       # Static analysis (enforced in CI)
dart format .                         # Code formatting
dart format . --set-exit-if-changed   # Check formatting
dart fix --dry-run                    # Check for fixable issues
dart fix --apply                      # Apply automated fixes
flutter pub run import_sorter:main    # Sort imports
```

**Quality Standards**:
- **Linting**: flutter_lints package (official recommended lints)
- **Analysis**: Configured in `analysis_options.yaml`
- **EditorConfig**: Enforces 2-space indentation, LF line endings, UTF-8 encoding
- **CI Enforcement**: GitHub Actions runs analyze and format checks on PRs

---

## Code Patterns and Conventions

### Naming Conventions

**Actual patterns observed**:
- **Files**: snake_case (e.g., `auth_service.dart`, `class_model.dart`)
- **Classes**: PascalCase (e.g., `AuthService`, `ClassModel`)
- **Functions/Variables**: camelCase (e.g., `getUserData()`, `currentUser`)
- **Private members**: Leading underscore (e.g., `_firebaseInitialized`, `_initializeApp()`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `CACHE_SIZE_UNLIMITED`)

**Inconsistencies**:
- Database collections: Mix of camelCase (`chatRooms`) and snake_case (`chat_rooms`, `discussion_boards`)
- Feature folder naming: `student/` vs `students/` (relationship unclear)
- Model file naming: `assignment.dart` vs `assignment_model.dart` (redundancy)

### State Management Pattern

**Provider Pattern (used throughout)**:
```dart
// Provider definition
class AuthProvider extends ChangeNotifier {
  // State
  AuthStatus _status = AuthStatus.uninitialized;

  // Getters
  AuthStatus get status => _status;

  // Methods that update state
  Future<void> signIn() async {
    // Update state
    _status = AuthStatus.authenticated;
    notifyListeners();  // Notify UI
  }
}

// Provider registration (app_providers.dart)
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    // ... other providers
  ],
  child: App(),
)

// Provider consumption
final authProvider = context.watch<AuthProvider>();
```

**Key characteristics**:
- Reactive UI updates via `notifyListeners()`
- Provider dependency injection via `MultiProvider` in `lib/shared/core/app_providers.dart`
- Context-based provider access: `context.watch<T>()`, `context.read<T>()`
- No Redux, Bloc, or Riverpod - pure Provider pattern

### Service Layer Pattern

**Example**: `AuthService`
```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Public methods
  Future<void> signInWithEmail(String email, String password) async {
    // Business logic
    final userCredential = await _auth.signInWithEmailAndPassword(...);
    // Domain-based role assignment happens in Firestore rules
    await _createOrUpdateUserDocument(userCredential.user!);
  }

  // Private helper methods
  Future<void> _createOrUpdateUserDocument(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName,
      // Role NOT set here - backend assigns based on email domain
    }, SetOptions(merge: true));  // Preserve backend values
  }
}
```

**Pattern characteristics**:
- Services encapsulate Firebase SDK calls
- Private helper methods for code organization
- Dependency injection via `get_it` service locator
- Error handling with try-catch and `LoggerService`

### Platform Abstraction Pattern

**Example**: Calendar Service Factory
```dart
// Interface
abstract class DeviceCalendarServiceInterface {
  Future<void> requestPermissions();
  Future<List<CalendarEvent>> getEvents();
}

// Factory
class DeviceCalendarServiceFactory {
  static DeviceCalendarServiceInterface create() {
    if (kIsWeb) {
      return DeviceCalendarServiceWeb();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return DeviceCalendarServiceMobile();
    } else {
      return DeviceCalendarServiceStub();  // Desktop fallback
    }
  }
}

// Usage
final calendarService = DeviceCalendarServiceFactory.create();
```

**Pattern used for**:
- Calendar access (web vs mobile vs desktop)
- Notifications (web vs mobile with FCM vs desktop local)
- OAuth flows (mobile Google Sign-In vs desktop local server)

### Repository Pattern (Implicit)

**Observed in services**:
- Services act as repositories for Firestore data
- Generic `FirestoreRepository` base class exists but not consistently used
- Most services directly use `FirebaseFirestore.instance`
- No formal data layer abstraction

**Example**: `ClassService` as implicit repository
```dart
class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CRUD operations
  Future<ClassModel> getClass(String classId) async { ... }
  Future<void> createClass(ClassModel classModel) async { ... }
  Future<void> updateClass(String classId, Map<String, dynamic> data) async { ... }
  Future<void> deleteClass(String classId) async { ... }
  Stream<List<ClassModel>> getClasses(String teacherId) { ... }
}
```

### Error Handling Pattern

**LoggerService usage**:
```dart
try {
  await someOperation();
} catch (e, stackTrace) {
  LoggerService.error(
    'Operation failed',
    tag: 'ServiceName',
    error: e,
    stackTrace: stackTrace,
  );
  rethrow;  // or handle gracefully
}
```

**Global error handlers** (in main.dart):
- `FlutterError.onError` → forwards to LoggerService
- `PlatformDispatcher.instance.onError` → catches platform errors
- `runZonedGuarded` → catches async errors

### Firestore Security Pattern

**Role-based access control** (from firestore.rules):
```javascript
// Helper functions
function isAuthenticated() { return request.auth != null; }
function isTheTeacher() { return getUserRole(request.auth.uid) == 'teacher' && hasTeacherDomain(); }
function hasTeacherDomain() { return request.auth.token.email.matches('(?i).*@roselleschools[.]org$'); }

// Collection rules
match /classes/{classId} {
  allow read: if isTheTeacher() || isEnrolledInClass(classId);
  allow write: if isTheTeacher();
}
```

**Key security patterns**:
- Domain-based role validation (email domain = role authority)
- Role stored in Firestore but validated against email domain in rules
- Nested subcollections for class-scoped data (student points, behaviors)
- Immutable messages and audit trails
- Explicit deny for unmatched paths

---

## Deployment and Operations

### Firebase Configuration

**Project ID**: `teacher-dashboard-flutterfire`

**Enabled Services**:
- Authentication (Email/Password, Google, Apple, Anonymous)
- Cloud Firestore
- Realtime Database
- Cloud Storage
- Cloud Functions
- Firebase Hosting
- Cloud Messaging (Android/iOS only)

**Firestore Indexes** (`firestore.indexes.json`):
- Defined indexes for collection group queries
- Required for behavior points history queries across classes
- Required for grade analytics queries

**Security Rules**:
- `firestore.rules`: 797 lines, comprehensive role-based access
- `storage.rules`: File upload security for assignment submissions
- Both deployed via GitHub Actions CI/CD

### Monitoring and Logging

**LoggerService** (`lib/shared/services/logger_service.dart`):
- Custom logging system with tags
- Levels: debug, info, warning, error
- Outputs to console in debug mode
- Tag-based filtering for debugging

**Firebase Analytics**: Not explicitly configured (could be added)

**Crash Reporting**:
- Global error handlers in main.dart
- LoggerService captures errors with stack traces
- No third-party crash reporting (Firebase Crashlytics could be added)

### Performance Considerations

**Implemented Optimizations**:
- **Firestore offline persistence**: Enabled with unlimited cache
- **Image caching**: `cached_network_image` for profile pictures, media
- **Pagination**: Not observed in code (potential issue for large data sets)
- **Lazy loading**: Implicit via Flutter's build-on-demand
- **Video compression**: `video_compress` for assignment submissions
- **Provider caching**: Provider instances cached by Provider framework

**Potential Performance Issues**:
- No pagination observed for large lists (students, assignments, etc.)
- Collection group queries without limits could be expensive
- Firestore unlimited cache on web could hit browser quotas
- Duplicate database collections (chatRooms + chat_rooms) cause redundant queries

### Backup and Recovery

**Firebase built-in**:
- Firestore automatic backups (Firebase manages)
- No explicit backup strategy documented
- Storage files persisted indefinitely unless explicitly deleted

**User data recovery**:
- No documented procedure for data recovery
- Firestore security rules prevent data deletion in most cases (messages, activities)

---

## Architecture Assessment

### Strengths

1. **Feature-First Organization**: Clean modular structure makes features easy to locate
2. **Provider Pattern Consistency**: State management is predictable throughout
3. **Platform Abstraction**: Good factory pattern for platform-specific services
4. **Comprehensive Firestore Rules**: Security is taken seriously (797 lines of rules)
5. **Multi-Platform Support**: Successfully targets 5 platforms (Web, Android, iOS, Windows, macOS)
6. **Material 3**: Modern UI design system
7. **Firebase Integration**: Robust real-time backend
8. **LoggerService**: Centralized logging aids debugging
9. **EditorConfig + Linting**: Enforces code consistency

### Weaknesses & Improvement Opportunities

1. **Test Coverage**: CRITICAL - Almost no automated tests (only 1 unit test)
   - Recommendation: Implement comprehensive test suite (target: 70%+ coverage)
   - Priority: HIGH - Refactoring is risky without tests

2. **Technical Debt Accumulation**: Multiple code patterns without cleanup
   - Duplicate auth provider locations
   - Multiple OAuth handler variants
   - Inconsistent database naming (camelCase vs snake_case)
   - Recommendation: Systematic refactoring sprint to consolidate duplicates

3. **Documentation Gap**: No architecture docs until this document
   - Recommendation: Maintain this document + add inline code documentation
   - Add architectural decision records (ADRs) for future major decisions

4. **Database Schema Inconsistency**:
   - chatRooms vs chat_rooms collection naming
   - Recommendation: Migrate to single consistent naming convention
   - Create database migration strategy

5. **No Staging Environment**: Development → Production deployment
   - Recommendation: Create staging Firebase project for pre-production testing

6. **Manual Testing Primary**: No automated E2E testing
   - Recommendation: Add Patrol or integration tests for critical user flows

7. **No Pagination Strategy**: Potential performance issues with large data sets
   - Recommendation: Implement Firestore pagination for lists

8. **Complex Firestore Rules**: 797 lines with some duplication
   - Recommendation: Refactor rules for reusability, add rule testing

9. **Service Locator Pattern Incomplete**: get_it used but not consistently
   - Recommendation: Standardize dependency injection across all services

10. **Error Handling Inconsistency**: Some services use LoggerService, others don't
    - Recommendation: Standardize error handling and logging patterns

### Migration Path to Industry Standards

**Phase 1: Stabilization** (Priority: HIGH)
1. Implement comprehensive test suite (unit + integration)
2. Set up staging environment
3. Document critical user flows
4. Create incident response playbook

**Phase 2: Refactoring** (Priority: MEDIUM)
1. Consolidate duplicate code (auth providers, models)
2. Clean up unused OAuth handlers
3. Standardize database naming conventions
4. Refactor Firestore rules for reusability

**Phase 3: Architecture** (Priority: MEDIUM)
1. Formalize repository pattern
2. Standardize dependency injection
3. Implement proper pagination
4. Add performance monitoring

**Phase 4: Quality** (Priority: LOW)
1. Add E2E tests with Patrol
2. Implement CI/CD for mobile platforms
3. Add Firebase Analytics
4. Set up crash reporting

---

## Appendix - Useful Commands and Scripts

### Frequently Used Commands

```bash
# Development
flutter run -d chrome              # Web development (recommended)
flutter run -d android             # Android emulator
flutter run -d ios                 # iOS simulator (macOS only)
flutter run -d windows             # Windows desktop
flutter devices                    # List available devices

# Code Quality
flutter analyze                    # Static analysis
dart format .                      # Format code
dart fix --apply                   # Apply automated fixes
flutter pub run import_sorter:main # Sort imports

# Testing (minimal tests exist)
flutter test                       # Run all tests
flutter test --coverage            # Generate coverage
flutter test test/unit/            # Run unit tests only

# Building
flutter build web --release        # Production web build
flutter build apk --release        # Android APK
flutter build appbundle --release  # Android App Bundle
flutter build ios --release        # iOS (macOS only)
flutter build windows --release    # Windows desktop

# Maintenance
flutter clean && flutter pub get   # Clean and reinstall
flutter pub outdated               # Check for updates
flutter pub upgrade --major-versions # Upgrade dependencies

# Firebase
firebase deploy                    # Deploy all (hosting + rules)
firebase deploy --only hosting     # Web deployment
firebase deploy --only firestore:rules # Update security rules
```

### Debugging and Troubleshooting

**Common Issues**:

1. **.env file not found**:
   - Check file exists in project root
   - Try absolute path: `/full/path/to/project/.env`
   - Works from: `.`, `data/flutter_assets/`, `../`, `../../`

2. **Firebase duplicate app error**:
   - Expected during hot restart
   - Gracefully handled in `app_initializer.dart`
   - No action needed

3. **OAuth not working on Windows**:
   - Check port 8080 is available
   - Verify .env file has correct client ID/secret
   - Try `desktop_oauth_handler_direct.dart` variant if issues persist

4. **Firebase Messaging not working on desktop**:
   - Expected - FCM only supports Android/iOS
   - Use local notifications for desktop

5. **Chat messages not syncing**:
   - Check BOTH `chatRooms` and `chat_rooms` collections
   - Database naming inconsistency causes confusion

**Logs**:
- Flutter logs: Check IDE console or `flutter logs`
- LoggerService output: Tagged with service name (e.g., `[AppInitializer]`, `[AuthService]`)
- Firebase logs: Firebase Console → Functions logs

**Performance Debugging**:
- Flutter DevTools: `flutter pub global activate devtools && devtools`
- Firestore query analysis: Firebase Console → Firestore → Usage tab

---

## Conclusion

Fermi Plus is a **functional production system** built with Flutter and Firebase that successfully serves its core educational management use case. The codebase exhibits characteristics of rapid MVP development that evolved into production without formal architectural planning - the "vibe-coded" approach.

### Current State Summary

**What Works Well**:
- ✅ Multi-platform support (Web, Android, iOS, Windows, macOS)
- ✅ Real-time collaboration via Firebase
- ✅ Comprehensive feature set (assignments, grades, behavior points, chat, calendar)
- ✅ Robust security with 797-line Firestore rules
- ✅ Feature-first architecture aids code organization
- ✅ Material 3 UI with theme support
- ✅ CI/CD for web deployment

**Critical Issues Requiring Attention**:
- ⚠️ Test coverage <5% - HIGH RISK for refactoring
- ⚠️ Technical debt accumulation (duplicates, inconsistencies)
- ⚠️ No architecture documentation (until now)
- ⚠️ Database naming inconsistencies (camelCase vs snake_case)
- ⚠️ Manual testing as primary QA method
- ⚠️ No staging environment

### Recommended Optimization Strategy

**Immediate Actions** (Week 1-2):
1. Implement test suite for critical paths (auth, classes, assignments)
2. Set up staging Firebase environment
3. Consolidate duplicate code (auth providers, models)
4. Document critical user flows

**Short-Term** (Month 1-2):
1. Standardize database naming conventions (migrate chatRooms → chat_rooms or vice versa)
2. Refactor Firestore rules for reusability
3. Clean up unused OAuth handler variants
4. Implement pagination for large data sets

**Medium-Term** (Quarter 1-2):
1. Achieve 70%+ test coverage
2. Formalize repository pattern across all services
3. Add E2E testing with Patrol
4. Implement Firebase Analytics and crash reporting
5. Create architectural decision records (ADRs)

**Long-Term** (Year 1):
1. Consider architecture evolution (potentially introduce BLoC or Riverpod for complex state)
2. Evaluate microservices for Cloud Functions
3. Implement advanced monitoring and alerting
4. Create developer onboarding documentation

This document provides the foundation for AI agents and human developers to understand the true state of the Fermi Plus codebase, enabling informed decisions for modernization and optimization while respecting the working production system that serves its users effectively.

---

## QA Assessment

### Review Date: 2025-10-11

### Reviewed By: Quinn (Test Architect)

**Comprehensive Quality Analysis**: This brownfield architecture has undergone thorough risk assessment and test design analysis. The system is functional and serves users effectively, but requires stabilization before major refactoring work.

**Risk Profile**: docs/qa/assessments/brownfield-risk-20251011.md
- 11 risks identified (2 critical, 4 high, 3 medium, 2 low)
- Overall risk score: 34/100 (HIGH RISK)
- Primary concerns: Test coverage <5%, database inconsistency, no staging environment

**Test Design**: docs/qa/assessments/brownfield-test-design-20251011.md
- 67 test scenarios designed across 3 phases
- Phased implementation: P0 tests (weeks 1-4), P1 tests (weeks 5-8), P2/P3 tests (weeks 9-12)
- Target: 70% test coverage by end of Phase 3

### Gate Status

**Gate: FAIL** → docs/qa/gates/brownfield-architecture.yml

**Rationale**: Critical risks prevent safe refactoring. Stabilization phase (test coverage, staging environment, database migration) must complete before architectural optimization work.

**Path to PASS**:
1. ✅ Implement P0 test coverage ≥40% (28 scenarios)
2. ✅ Create staging Firebase environment
3. ✅ Execute database migration with validation
4. ✅ Improve risk score to ≥55/100

**Next Review**: 2025-10-25 (after Phase 1 stabilization)

---

**Document Version**: 1.0
**Generated**: 2025-10-11
**Analyst**: Winston (Holistic System Architect)
**QA Reviewer**: Quinn (Test Architect)
**Next Review**: After Phase 1 stabilization milestone
