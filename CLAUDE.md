# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Feature Implementation System Guidelines

### Feature Implementation Priority Rules
- IMMEDIATE EXECUTION: Launch parallel Tasks immediately upon feature requests
- NO CLARIFICATION: Skip asking what type of implementation unless absolutely critical
- PARALLEL BY DEFAULT: Always use 7-parallel-Task method for efficiency

### Parallel Feature Implementation Workflow
1. **Component**: Create main component file
2. **Styles**: Create component styles/CSS
3. **Types**: Create type definitions
4. **Hooks**: Create custom hooks/utilities
5. **Integration**: Update routing, imports, exports
6. **Remaining**: Update package.json, documentation, configuration files
7. **Review and Validation**: Coordinate integration, run tests, verify build, check for conflicts


### Context Optimization Rules
- Strip out all comments when reading code files for analysis
- Each task handles ONLY specified files or file types
- Task 7 combines small config/doc updates to prevent over-splitting

### Feature Implementation Guidelines
- **CRITICAL**: Make MINIMAL CHANGES to existing patterns and structures
- **CRITICAL**: Preserve existing naming conventions and file organization
- Follow project's established architecture and component patterns
- Use existing utility functions and avoid duplicating functionality

## Project Overview

**Fermi** - A Flutter (Dart) application with Firebase backend for education management.

**Tech Stack**: Flutter 3.24+, Dart 3.5+, Firebase (Auth, Firestore, Functions, Storage), Provider, GoRouter
**Architecture**: Client-side Flutter app with Firebase backend; no separate server, using Provider for state management and Clean Architecture principles
**Status**: ~40% feature complete - authentication, routing, and basic dashboards implemented

## Claude Interaction Guidelines

- **YOU MUST** ask clarifying questions if any requirement or code context is unclear. Do not assume unknown details.
- **YOU SHOULD** draft and confirm a step-by-step plan for complex tasks before writing code.
- **YOU MUST** use extended reasoning to consider implications of changes across the codebase.
- **YOU SHOULD** verify that your planned changes align with the architecture and workflows documented below.
- **IMPORTANT**: If something contradicts the established structure, discuss it before proceeding.

## Key Components & Files

### Core Entry Points
- `lib/main.dart` - App initialization and Firebase setup
- `lib/app.dart` - MaterialApp configuration, themes, and routing
- `lib/firebase_options.dart` - Firebase configuration (auto-generated)

### Critical Architecture Files
- `lib/shared/core/app_providers.dart` - Central provider configuration
- `lib/shared/routing/app_router.dart` - GoRouter configuration with auth guards
- `lib/features/auth/presentation/providers/auth_provider.dart` - Authentication state management

### Feature Locations
- `lib/features/auth/` - Authentication system
- `lib/features/dashboard/` - Teacher and student dashboards
- `lib/features/students/` - Student management (placeholder)
- `lib/features/assignments/` - Assignment system (planned)
- `lib/shared/` - Shared utilities and widgets

## Development Commands

### Environment Setup
- **REQUIRED**: Flutter SDK 3.24+ (run `flutter --version` to check)
- **IMPORTANT**: Run `flutter pub get` after cloning or modifying `pubspec.yaml`
- **NOTE**: Desktop platforms (Linux/Windows) not supported due to Firebase limitations

### Essential Commands
```bash
# Environment Setup
flutter pub get            # Install dependencies (MUST run after cloning)
flutter doctor             # Check environment setup

# Run the app
flutter run -d chrome      # Web (recommended for development)
flutter run -d android      # Android emulator
flutter run -d ios          # iOS simulator

# Code Quality (MUST run before committing)
flutter analyze            # Lint and analyze code
dart format .              # Format code
dart fix --apply           # Apply automated fixes

# Testing
flutter test               # Run all tests
flutter test test/         # Unit tests only
flutter test --coverage    # With coverage report

# Build
flutter build web --release
flutter build apk --release
flutter build ios --release
```

### Firebase Setup
```bash
# Configure Firebase (when changing project)
# Note: Firebase project ID remains 'teacher-dashboard-flutterfire'
flutterfire configure --project=teacher-dashboard-flutterfire

# Deploy to Firebase Hosting
flutter build web && firebase deploy --only hosting

# Local Firebase Emulators (for testing)
firebase emulators:start   # Start local Firebase emulators
```

## Architecture

### Feature-Based Structure
The codebase follows Clean Architecture with feature-based organization:

```
lib/features/{feature}/
├── data/               # Data layer (repositories, services)
│   ├── repositories/   # Repository implementations
│   └── services/       # External service integrations
├── domain/             # Business logic layer
│   ├── models/         # Domain models
│   └── repositories/   # Repository interfaces
├── presentation/       # UI layer
│   ├── screens/        # Full screen widgets
│   ├── widgets/        # Reusable components
│   └── providers/      # State management
└── providers/          # Feature-specific providers (deprecated location)
```

### State Management
The app uses Provider pattern for state management with centralized providers in `lib/shared/core/app_providers.dart`. Key providers:
- **AuthProvider**: Manages authentication state and user sessions
- **ThemeProvider**: Handles theme switching
- Feature-specific providers for data management

### Routing Architecture
GoRouter-based routing with authentication guards in `lib/shared/routing/app_router.dart`:
- **Route Protection**: Automatic redirects based on auth state
- **Role-Based Access**: Teacher/Student/Admin specific routes
- **Email Verification**: Redirects unverified users to verification screen
- **Authentication Flow**: 
  1. Unauthenticated → `/auth/login`
  2. Needs role → `/auth/role-selection`
  3. Needs verification → `/auth/verify-email`
  4. Authenticated → Role-specific dashboard

### Firebase Integration

**IMPORTANT**: Firebase API keys are managed through environment variables:
- Web: Uses `String.fromEnvironment()` with defaults in `firebase_options.dart`
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

**CI/CD Secret Management**: GitHub secrets inject Firebase configuration during builds

### Authentication System
Multi-step authentication with role management:
1. **Email/Password or Google Sign-In**
2. **Role Selection** (Teacher/Student) for new users
3. **Email Verification** required before access
4. **Custom Claims** for role-based access control

## Critical Context

### Current Limitations
- **IMPORTANT: Desktop Not Supported** - Firebase doesn't support Linux/Windows. **YOU MUST** use web browser or mobile emulator for development.
- **NOTE**: Student management, messaging, calendar, and notifications are placeholder features - not yet implemented
- **Current Branch**: Working on `fix/compilation-errors-auth-refactor` branch

### Active Issues
1. **IDE Warning (Non-Critical)**: Flutter plugin `BadgeIcon` cast exception - does not affect functionality
2. **Linting Issues**: 38 warnings - mostly print statements and unused variables that need cleanup
3. **Recent Refactor**: Auth system recently centralized to AuthProvider - watch for residual issues

### Testing Approach
```bash
# Quick database testing (development)
flutter run lib/test_db_simple.dart    # No auth required
flutter run lib/test_db_direct.dart    # Full auth test
flutter run lib/setup_test_data.dart   # Seed test data

# Unit testing
flutter test test/app_router_redirect_test.dart  # Router logic
flutter test test/widget_test.dart               # Widget tests
```

## Development Workflow

### When Adding New Features
1. Create feature folder under `lib/features/`
2. Follow Clean Architecture layers (data/domain/presentation)
3. Add provider to `app_providers.dart` if needed
4. Add routes to `app_router.dart` with proper guards
5. Implement Firestore security rules if adding collections

#### Example: Adding a Profile Feature
```
Step 1: Create structure
  lib/features/profile/
    ├── domain/
    │   ├── models/profile_model.dart      # Define ProfileModel class
    │   └── repositories/profile_repository.dart  # Repository interface
    ├── data/
    │   └── repositories/profile_repository_impl.dart  # Firestore implementation
    └── presentation/
        ├── screens/profile_screen.dart    # UI screen
        └── providers/profile_provider.dart # State management

Step 2: Register provider in lib/shared/core/app_providers.dart
Step 3: Add route in lib/shared/routing/app_router.dart with auth guard
Step 4: Add navigation to profile from dashboard
Step 5: Test authentication flow and data loading
```

### When Modifying Authentication
1. **MUST** check `AuthProvider` in `features/auth/presentation/providers/`
2. Update redirect logic in `app_router.dart` (refer to Authentication Flow above)
3. **MUST** test with `app_router_redirect_test.dart`
4. Verify email verification flow still works

### When Working with Firebase
1. **MUST NOT** commit API keys directly - use environment variables
2. Run `flutterfire configure` after Firebase Console changes
3. Update security rules in Firebase Console
4. **SHOULD** test locally with emulators when possible

### CI/CD Considerations
- GitHub Actions workflows in `.github/workflows/`
- Secrets required: `FIREBASE_API_KEY`, `FIREBASE_APP_ID_*`, etc.
- Builds trigger on push to main
- Separate workflows for web, Android, iOS

## Code Style Rules

### Dart/Flutter Conventions
- **MUST** use `const` constructors wherever possible for performance
- **SHOULD** prefer single quotes for strings (Flutter convention)
- **MUST NOT** use `print()` in production code - use proper logging utilities
- **MUST** follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- **SHOULD** document public APIs with `///` doc comments
- **MUST** follow Clean Architecture layering - no direct Firebase calls in presentation layer

### Error Handling
- **MUST** use try-catch for all Firebase operations
- **MUST** show user-friendly error messages via SnackBars (not raw errors)
- **SHOULD** log errors to Crashlytics in production builds
- **MUST** handle offline scenarios gracefully with appropriate UI feedback

### Testing Requirements
- **MUST** write tests for new features before marking them complete
- **SHOULD** maintain >80% code coverage for critical paths
- **MUST** test authentication flows thoroughly (login, logout, role changes)
- **MUST** mock Firebase services in unit tests - no real Firebase calls

### Git Workflow Rules
- **MUST** use Conventional Commits format: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- **MUST NOT** commit directly to `main` branch - use feature branches
- **MUST** run `flutter analyze` before committing code
- **SHOULD** keep commits atomic and focused on single changes

## Important Reminders

- **CRITICAL**: This is a Flutter/Firebase project - no backend server code needed
- **IMPORTANT**: Always check existing patterns in the codebase before creating new ones
- **NOTE**: Provider is used for state management, not Riverpod or Bloc
- **REMEMBER**: Authentication flow has specific steps that must be followed in order
- **WARNING**: Desktop platforms are not supported - test on web or mobile only

## When You're Unsure

If any aspect of the task is unclear:
1. **ASK** for clarification before proceeding
2. **EXPLAIN** what you understand and what needs clarification
3. **PROPOSE** a solution approach and confirm it's correct
4. **NEVER** make assumptions about critical functionality

Remember: It's better to ask questions than to implement incorrectly\!
ENDMARKER < /dev/null
