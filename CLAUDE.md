# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Codebase Map
The project structure is automatically indexed. Run `codebase-map scan && codebase-map format` to update.
@.codebasemap.dsl

## Project Overview

**Fermi** - A comprehensive Flutter education management platform with Firebase backend for teachers and students.

**Tech Stack**: 
- Flutter 3.24+, Dart 3.5+
- Firebase Suite: Auth, Firestore, Storage, Functions, Messaging, Database
- State Management: Provider 6.1.5+
- Routing: GoRouter 16.1.0+
- Additional: fl_chart, video_player, image_picker, flutter_local_notifications

**Architecture**: Client-side Flutter app with Firebase backend; no separate server, using Provider for state management. Clean Architecture principles inform layout, but the repository layer has been simplified: we use a thin generic `FirestoreRepository<T>` wrapper over direct Firebase access rather than heavy repository hierarchies.

**Version**: 0.9.3

**Status**: ~75% feature complete with 400+ commits, extensive functionality implemented

## Claude Interaction Guidelines

- **YOU MUST** ask clarifying questions if any requirement or code context is unclear. Do not assume unknown details.
- **YOU SHOULD** draft and confirm a step-by-step plan for complex tasks before writing code.
- **YOU MUST** use extended reasoning to consider implications of changes across the codebase.
- **YOU SHOULD** verify that your planned changes align with the architecture and workflows documented below.
- **IMPORTANT**: If something contradicts the established structure, discuss it before proceeding.

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
- **CRITICAL**

## Key Components & Files

### Core Entry Points
- `lib/main.dart` - App initialization and Firebase setup
- `lib/app.dart` - MaterialApp configuration, themes, and routing
- `lib/firebase_options.dart` - Firebase configuration (auto-generated)

### Critical Architecture Files
- `lib/shared/core/app_providers.dart` - Central provider configuration
- `lib/shared/routing/app_router.dart` - GoRouter configuration with auth guards
- `lib/features/auth/presentation/providers/auth_provider.dart` - Authentication state management

### Implemented Features (30 Firestore collections, 113+ implementation files)

#### Fully Implemented
- **Authentication** (10 files) - Email/password, Google Sign-In, Apple Sign-In, role selection, email verification
- **Chat/Messaging** (23 files) - Direct messages, group chats, real-time messaging, user presence, video/voice calling infrastructure
- **Discussion Boards** (6 files) - Boards, threads, replies, likes system, teacher moderation
- **Assignments** (13 files) - Creation, submission, grading, due dates, status tracking
- **Classes** (12 files) - Class management, enrollment, student rosters
- **Notifications** (11 files) - Push notifications, in-app notifications, notification preferences
- **Student Management** (11 files) - Student profiles, enrollment, progress tracking

#### Partially Implemented
- **Calendar** (9 files) - Event creation, scheduling, reminders
- **Grades** (8 files) - Gradebook, analytics, student grade views
- **Games** (5 files) - Jeopardy game with question banks

#### Basic Implementation
- **Dashboard** (3 files) - Teacher and student dashboard views
- **Teacher Features** (2 files) - Teacher-specific functionality

### Feature Locations
- `lib/features/auth/` - Authentication system with providers
- `lib/features/dashboard/` - Teacher and student dashboards
- `lib/features/chat/` - Complete messaging system
- `lib/features/discussions/` - Discussion boards with simplified provider
- `lib/features/assignments/` - Assignment creation and submission
- `lib/features/classes/` - Class management
- `lib/features/grades/` - Grading system
- `lib/features/calendar/` - Calendar and events
- `lib/features/notifications/` - Notification system
- `lib/features/student/` - Student management
- `lib/features/games/` - Educational games (Jeopardy)
- `lib/shared/` - Shared utilities and widgets

## Cloudflare Deployment

### Successful Build Configuration
The Cloudflare Workers deployment successfully builds with these settings:
- **Build command**: `cd apps/fermi && sh build-for-cloudflare.sh`
- **Deploy command**: `cd apps/fermi && npx wrangler deploy`
- **Root directory**: `/`

## Development Commands

### Environment Setup
- **REQUIRED**: Flutter SDK 3.24+ (run `flutter --version` to check)
- **IMPORTANT**: Run `flutter pub get` after cloning or modifying `pubspec.yaml`
- **SUPPORTED PLATFORMS**: Web, iOS, Android, Windows (with OAuth2)

### Essential Commands
```bash
# Environment Setup
flutter pub get            # Install dependencies (MUST run after cloning)
flutter doctor             # Check environment setup

# Run the app
flutter run -d chrome      # Web (recommended for development)
flutter run -d android     # Android emulator
flutter run -d ios         # iOS simulator
flutter run -d windows     # Windows desktop (OAuth2 support)

# Code Quality (MUST run before committing)
flutter analyze            # Lint and analyze code
dart format .              # Format code
dart fix --apply           # Apply automated fixes

# Testing (currently no test directory)
# TODO: Add comprehensive test suite

# Build
flutter build web --release
flutter build apk --release
flutter build ios --release
flutter build windows --release
```

### Firebase Setup
```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Configure Firebase for your Flutter project
flutterfire configure --project=your-project-id

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
└── providers/          # Feature-specific providers (legacy location)
```

### State Management
The app uses Provider pattern for state management with centralized providers in `lib/shared/core/app_providers.dart`. Key providers:
- **AuthProvider**: Manages authentication state and user sessions
- **ThemeProvider**: Handles theme switching
- **SimpleDiscussionProvider**: Simplified discussion board state
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

**Collections in Use** (30 total):
- Core: users, pending_users, presence
- Classes: classes, students, teachers
- Assignments: assignments, submissions, grades
- Communication: chat_rooms, messages, conversations, notifications, presence (online status)
- Discussion: discussion_boards, threads, replies, likes, comments
- Calendar: calendar_events, scheduled_messages
- Games: games, jeopardy_games, jeopardy_sessions, scores
- Other: activities, announcements, bug_reports, fcm_tokens, calls, candidates

**Security Rules**: Comprehensive role-based access control with teacher/student permissions

**API Keys**: Managed through environment variables and GitHub secrets for CI/CD

## Critical Context

### Current Branch & Status
- **Default Branch**: `master`
- **Active Refactor Branch**: `refactor/codebase-quality-optimization`
- **Recent Work**: logging standardization, presence real-time listeners, mounted guards, docs normalization

### Platform Support
- **Web**: Full support with PWA capabilities
- **iOS**: Full support with Apple Sign-In
- **Android**: Full support with Google Sign-In
- **Windows**: Desktop support with OAuth2 flow
- **Linux/macOS**: Not currently supported

### Recent Major Features (Last 302 commits)
1. Discussion boards with likes, replies, and moderation
2. Complete chat/messaging system with presence
3. Jeopardy educational game
4. Windows desktop support with OAuth2
5. Apple Sign-In integration
6. PWA with auto-update system
7. Notification system with push support
8. Presence/online status tracking

### Presence Architecture (Updated)
- Presence is stored in Firestore under the `presence` collection.
- UI consumes presence via real-time Firestore snapshots on all platforms.
- Windows polling fallback exists but is disabled by default; enable only if a specific environment requires it (`PresenceService.enableWindowsPollingFallback = true`).
- See `docs/developer/features/presence.md` for details.

### Known Issues & Limitations
1. **iOS Gesture Conflict**: Fixed with ClampingScrollPhysics for Dismissible widgets
2. **No Test Suite**: Test directory doesn't exist yet
3. **Desktop Limitations**: Linux/macOS not supported
4. **Performance**: Some screens may need optimization with 113+ implementation files

## Development Workflow

### When Adding New Features
1. Create feature folder under `lib/features/`
2. Follow Clean Architecture layers (data/domain/presentation)
3. Add provider to `app_providers.dart` if needed
4. Add routes to `app_router.dart` with proper guards
5. Implement Firestore security rules if adding collections
6. Update `firestore.indexes.json` for complex queries

### When Modifying Authentication
1. **MUST** check `AuthProvider` in `features/auth/presentation/providers/`
2. Update redirect logic in `app_router.dart`
3. Test OAuth flows (Google, Apple)
4. Verify email verification flow still works
5. Check role-based access control

### When Working with Firebase
1. **MUST NOT** commit API keys directly - use environment variables
2. Run `flutterfire configure` after Firebase Console changes
3. Update security rules in `firestore.rules`
4. Test with emulators when possible
5. Check indexes for new queries

### CI/CD Considerations
- GitHub Actions workflows in `.github/workflows/`
- Secrets required: Firebase configuration keys
- Workflows: CI validation, web deployment, mobile builds
- Firebase Hosting auto-deploy on merge

## Code Style Rules

### Dart/Flutter Conventions
- **MUST** use `const` constructors wherever possible for performance
- **SHOULD** prefer single quotes for strings (Flutter convention)
- **MUST NOT** use `print()` in production code - use proper logging
- **MUST** follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- **SHOULD** document public APIs with `///` doc comments
- **MUST** follow Clean Architecture layering
- **PREFER** simple implementations over complex abstractions (see SimpleDiscussionProvider)

### Error Handling
- **MUST** use try-catch for all Firebase operations
- **MUST** show user-friendly error messages via SnackBars
- **SHOULD** log errors appropriately
- **MUST** handle offline scenarios gracefully
- **IMPORTANT**: Direct Firestore calls often work better than complex abstractions

### Testing Requirements
- **TODO**: Implement comprehensive test suite
- **SHOULD** maintain >80% code coverage for critical paths
- **MUST** test authentication flows thoroughly
- **MUST** mock Firebase services in unit tests

### Git Workflow Rules
- **MUST** use Conventional Commits format: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- **MUST NOT** commit directly to `main` branch
- **MUST** run `flutter analyze` before committing
- **SHOULD** keep commits atomic and focused
- **Current Branch**: `windows-development`

## Important Reminders

- **CRITICAL**: This is a Flutter/Firebase project - no backend server needed
- **IMPORTANT**: 400+ commits with extensive functionality already implemented
- **NOTE**: Provider is used for state management, not Riverpod or Bloc
- **REMEMBER**: Simplified implementations often work better than over-engineered solutions
- **WARNING**: iOS has platform-specific quirks (e.g., ScrollPhysics conflicts)
- **PERFORMANCE**: With 113+ files, consider code splitting and lazy loading

## When You're Unsure

If any aspect of the task is unclear:
1. **ASK** for clarification before proceeding
2. **EXPLAIN** what you understand and what needs clarification
3. **PROPOSE** a solution approach and confirm it's correct
4. **CHECK** existing implementations in the 113+ files before creating new patterns
5. **NEVER** make assumptions about critical functionality

Remember: The codebase is substantial with 30 collections and extensive features - always check existing patterns first!
- DO NOT EVER MAKE TEMPORARY SCRIPTS OR PYTHON FILES FOR IMPLEMENTING FIXES. THE ONLY TIME YOU CAN DO THIS IS WHEN THE USER EXPLICITY ASKS YOU TO. ALL THIS DOES IT MAKE CLUTTER. THE SAME GOES FOR DOCUMENTATION. THERE IS ONLY 1 DEVELOPER ON THIS PROJECT AND SUCH MD FILES ARE FUCKING USLESS.

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md
