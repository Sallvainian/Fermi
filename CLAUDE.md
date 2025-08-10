# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Teacher Dashboard - A Flutter/Firebase education management platform currently migrating from SvelteKit/Supabase. The project is ~40% feature complete with authentication, routing, and basic dashboards implemented.

## Development Commands

### Essential Commands
```bash
# Run the app
flutter run -d chrome      # Web (recommended for development)
flutter run -d android      # Android emulator
flutter run -d ios          # iOS simulator

# Code Quality
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
flutterfire configure --project=teacher-dashboard-flutterfire

# Deploy to Firebase Hosting
flutter build web && firebase deploy --only hosting
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
- **Desktop Support**: Firebase doesn't support Linux/Windows - use web or emulator
- **Placeholder Features**: Student management, messaging, calendar, notifications not yet implemented
- **Compilation Branch**: Working on `fix/compilation-errors-auth-refactor` branch

### Active Issues
1. **IDE Error**: Flutter plugin `BadgeIcon` cast exception - doesn't affect functionality
2. **38 Linting Issues**: Need to remove print statements and fix unused variables
3. **Auth Refactor**: Recently centralized AuthProvider, may have residual issues

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

### When Modifying Authentication
1. Check `AuthProvider` in `features/auth/presentation/providers/`
2. Update redirect logic in `app_router.dart`
3. Test with `app_router_redirect_test.dart`
4. Verify email verification flow still works

### When Working with Firebase
1. Never commit API keys directly - use environment variables
2. Run `flutterfire configure` after Firebase Console changes
3. Update security rules in Firebase Console
4. Test locally with emulators when possible

### CI/CD Considerations
- GitHub Actions workflows in `.github/workflows/`
- Secrets required: `FIREBASE_API_KEY`, `FIREBASE_APP_ID_*`, etc.
- Builds trigger on push to main
- Separate workflows for web, Android, iOS

## Code Style Guidelines

### Dart/Flutter Conventions
- Use `const` constructors where possible
- Prefer single quotes for strings
- Avoid `print()` in production code - use proper logging
- Follow effective dart guidelines
- Document public APIs with `///` comments

### Error Handling
- Use try-catch for Firebase operations
- Show user-friendly error messages via SnackBars
- Log errors to Crashlytics in production
- Handle offline scenarios gracefully

### Testing Requirements
- Write tests for new features
- Maintain existing test coverage
- Test authentication flows thoroughly
- Mock Firebase services in unit tests