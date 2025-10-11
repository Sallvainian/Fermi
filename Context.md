# Project Context: Fermi Plus

## Project Overview

- **Version**: ContextKit 0.1.0
- **Setup Date**: 2025-10-11
- **Components**: 1 Flutter application (multi-platform)
- **Workspace**: None (standalone project)
- **Primary Tech Stack**: Flutter 3.35.6 / Dart 3.9.2
- **Development Guidelines**: None (Flutter/Dart guidelines not available in ContextKit)

## Component Architecture

**Project Structure**:

```
📁 Fermi Plus
└── 📱 Fermi Plus App (Multi-platform Flutter Application)
    Purpose: Comprehensive education management platform for classroom management and student engagement
    Tech Stack: Flutter 3.35.6, Dart 3.9.2, Firebase, Provider
    Platforms: Web, Android, iOS, Windows, macOS
    Location: ./
```

**Component Summary**:
- **1 Flutter application** - Multi-platform education management system
- **Firebase Integration** - Auth, Firestore, Storage, Functions, Messaging
- **Dependencies**: 40+ production dependencies, comprehensive feature set

---

## Component Details

### Fermi Plus App - Multi-platform Flutter Application

**Location**: `./`
**Purpose**: Comprehensive education management platform that revolutionizes classroom management and student engagement. Built with Flutter and Firebase, providing real-time collaboration tools for teachers, students, and parents.
**Tech Stack**: Flutter 3.35.6, Dart 3.9.2, Firebase Suite, Provider (state management), GoRouter (navigation)

**File Structure**:
```
fermi_plus/
├── lib/                           # Application source code
│   ├── features/                  # Feature-based modular architecture
│   │   ├── admin/                 # Admin management
│   │   ├── assignments/           # Assignment management
│   │   ├── auth/                  # Authentication system
│   │   ├── behavior_points/       # Behavior tracking (unique feature)
│   │   ├── calendar/              # Calendar integration
│   │   ├── chat/                  # Real-time messaging
│   │   ├── classes/               # Class management
│   │   ├── dashboard/             # Dashboard views
│   │   ├── discussions/           # Discussion boards
│   │   ├── games/                 # Educational games
│   │   ├── grades/                # Grading system
│   │   ├── notifications/         # Push notifications
│   │   ├── student/               # Student management
│   │   ├── students/              # Students listing
│   │   └── teacher/               # Teacher features
│   ├── shared/                    # Shared components
│   │   ├── core/                  # App initialization, DI
│   │   ├── models/                # Shared data models
│   │   ├── providers/             # Global state providers
│   │   ├── routing/               # Navigation configuration
│   │   ├── services/              # Shared services layer
│   │   ├── theme/                 # Theming and styling
│   │   ├── utils/                 # Utility functions
│   │   └── widgets/               # Reusable UI components
│   └── main.dart                  # Application entry point
├── test/                          # Unit and widget tests
├── integration_test/              # Integration tests
├── android/                       # Android platform files
├── ios/                           # iOS platform files
├── web/                           # Web platform files
├── windows/                       # Windows platform files
├── macos/                         # macOS platform files
├── assets/                        # Images, icons, and other assets
├── functions/                     # Firebase Cloud Functions
├── docs/                          # Project documentation
├── pubspec.yaml                   # Dart dependencies and configuration
├── analysis_options.yaml          # Linting and analysis rules
├── .editorconfig                  # Code style configuration
├── firestore.rules                # Firestore security rules
├── firestore.indexes.json         # Firestore indexes
└── storage.rules                  # Firebase Storage security rules
```

**Dependencies** (from pubspec.yaml):

*Core Firebase Services:*
- **firebase_core** ^4.0.0 - Firebase initialization
- **firebase_auth** ^6.0.1 - Multi-provider authentication (Google, Apple, Email)
- **cloud_firestore** ^6.0.0 - NoSQL real-time database
- **firebase_storage** ^13.0.0 - File and media storage
- **firebase_database** ^12.0.0 - Realtime Database
- **firebase_messaging** ^16.0.0 - Push notifications
- **cloud_functions** ^6.0.0 - Serverless backend logic

*Authentication:*
- **google_sign_in** ^7.0.5 - Google OAuth (mobile)
- **sign_in_with_apple** ^7.0.1 - Apple authentication (iOS requirement)
- **oauth2** ^2.0.0 - OAuth2 flow for Windows
- **flutter_dotenv** ^6.0.0 - Environment variable management

*State Management & Navigation:*
- **provider** ^6.1.5+1 - Reactive state management
- **go_router** ^16.2.1 - Declarative routing
- **get_it** ^8.2.0 - Dependency injection

*UI & Data Visualization:*
- **fl_chart** ^0.69.0 - Charts and graphs
- **cached_network_image** ^3.4.1 - Image caching and optimization
- **smooth_page_indicator** ^1.2.1 - Page indicators

*Messaging & Collaboration:*
- **flutter_chat_ui** ^2.9.0 - Chat UI components
- **flutter_chat_core** ^2.8.0 - Chat functionality
- **uuid** ^4.5.1 - Unique identifiers

*Notifications & Calendar:*
- **flutter_local_notifications** ^19.4.1 - Local notifications with desktop support
- **timezone** ^0.10.0 - Timezone handling
- **device_calendar** ^4.3.3 - Calendar synchronization
- **icalendar_parser** ^2.1.0 - iCalendar export

*Media & Files:*
- **video_player** ^2.10.0 - Video playback
- **video_compress** ^3.1.4 - Video compression
- **image_picker** ^1.2.0 - Camera and gallery access
- **file_picker** ^10.3.2 - File selection
- **path_provider** ^2.1.5 - File system paths
- **csv** ^6.0.0 - CSV file handling

*Utilities:*
- **intl** ^0.20.2 - Internationalization
- **shared_preferences** ^2.5.3 - Local storage
- **collection** ^1.19.1 - Collection utilities
- **rxdart** ^0.28.0 - Reactive extensions
- **package_info_plus** ^9.0.0 - Package metadata
- **http** ^1.5.0 - HTTP requests
- **crypto** ^3.0.6 - Cryptography utilities
- **web** ^1.1.1 - Web platform support

*Development Dependencies:*
- **flutter_test** (SDK) - Testing framework
- **integration_test** (SDK) - Integration testing
- **flutter_lints** ^6.0.0 - Linting rules
- **fake_cloud_firestore** ^4.0.0 - Firestore mocking
- **test** ^1.25.15 - Testing utilities
- **mockito** ^5.5.0 - Mocking framework
- **faker** ^2.2.0 - Test data generation
- **build_runner** ^2.7.0 - Code generation
- **json_serializable** ^6.11.0 - JSON serialization
- **flutter_launcher_icons** ^0.14.4 - App icon generation
- **msix** ^3.16.12 - Windows installer
- **import_sorter** ^4.6.0 - Import organization

**Development Commands**:
```bash
# Setup & Dependencies
source ~/.zshenv  # Required: Load Flutter environment
flutter pub get   # Install dependencies
flutter pub upgrade --major-versions  # Upgrade dependencies

# Development
flutter run -d chrome              # Run on web (recommended for development)
flutter run -d android             # Run on Android
flutter run -d ios                 # Run on iOS (macOS only)
flutter run -d windows             # Run on Windows
flutter run -d macos               # Run on macOS
flutter devices                    # List available devices

# Code Quality (validated during setup)
flutter analyze                    # Static code analysis
dart format .                      # Format code
dart format . --set-exit-if-changed  # Check formatting
dart fix --dry-run                 # Check for fixable issues
dart fix --apply                   # Apply automated fixes
flutter pub run import_sorter:main # Sort imports

# Testing (validated during setup)
flutter test                       # Run all unit and widget tests
flutter test test/                 # Run unit tests
flutter test test/widgets/         # Run widget tests
flutter test integration_test      # Run integration tests
flutter test --coverage            # Generate coverage report
flutter test --test-randomize-ordering-seed random  # Randomized test order

# Code Generation
flutter pub run build_runner build --delete-conflicting-outputs       # Generate code
flutter pub run build_runner watch --delete-conflicting-outputs       # Watch mode

# Building for Production (validated during setup)
flutter build web --release        # Build web app
flutter build apk --release        # Build Android APK
flutter build appbundle --release  # Build Android App Bundle
flutter build ios --release        # Build iOS app (macOS only)
flutter build windows --release    # Build Windows app
flutter build macos --release      # Build macOS app

# Maintenance
flutter clean && flutter pub get   # Clean build artifacts and reinstall
flutter pub outdated               # Check for outdated dependencies

# CI/CD Commands
flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs  # CI setup
flutter test --coverage --test-randomize-ordering-seed random  # CI test with coverage
flutter analyze --no-fatal-infos   # CI analysis

# Pre-commit Quality Check
flutter analyze && dart format . --set-exit-if-changed && flutter test
```

**Code Style** (from .editorconfig and analysis_options.yaml):
- **Indentation**: 2 spaces (enforced across all file types)
- **Line Endings**: LF (Unix-style)
- **Charset**: UTF-8
- **Max Line Length**: 80 characters for Dart files
- **Trailing Whitespace**: Trimmed (except in Markdown)
- **Final Newline**: Required
- **Linting**: flutter_lints package (official recommended lints)
- **Analysis**: Configured in analysis_options.yaml with standard Flutter rules

**Framework Usage**:
- **Flutter Material 3**: Modern Material Design system
- **Provider Pattern**: Reactive state management throughout
- **Repository Pattern**: Data access abstraction in features
- **Feature-First Architecture**: Modular organization by feature
- **Clean Architecture**: Separation of concerns (data/domain/presentation)
- **Service Layer**: Business logic encapsulation in shared/services

---

## Development Environment

**Requirements**:
- Flutter SDK: >=3.32.0, <4.0.0 (currently 3.35.6)
- Dart SDK: >=3.8.0 (currently 3.9.2)
- Firebase CLI: For Firebase deployment and configuration
- Node.js: For Firebase Functions development
- Git: Version control
- IDE: VS Code or Android Studio recommended

**Platform-Specific Requirements**:
- **Android**: Android Studio, Android SDK
- **iOS**: Xcode (macOS only), CocoaPods
- **Windows**: Visual Studio 2022 with Desktop development workload
- **Web**: Chrome for development

**Firebase Configuration**:
- Project ID: teacher-dashboard-flutterfire
- Security rules configured for all services
- Firestore indexes defined in firestore.indexes.json
- Environment variables in .env file for OAuth credentials

**Build Tools**:
- Flutter 3.35.6 (stable channel)
- Dart 3.9.2
- DevTools 2.48.0
- build_runner for code generation
- flutter_launcher_icons for icon generation
- msix for Windows installer packaging

**Formatters**:
- **dart format**: Built-in Dart formatter (80 character line length)
- **import_sorter**: Automatic import organization
- **EditorConfig**: Cross-editor consistency for all file types

---

## Constitutional Principles

**Core Principles**:
- ✅ **Accessibility-first design**: Material 3 components with built-in accessibility support, semantic labels, screen reader compatibility
- ✅ **Privacy by design**: FERPA-compliant data handling, minimal data collection, explicit consent for sensitive operations, domain validation for school emails
- ✅ **Localizability from day one**: intl package for internationalization, externalized strings ready for translation
- ✅ **Code maintainability**: Feature-first architecture, clean code principles, comprehensive documentation, type-safe Dart code
- ✅ **Platform-appropriate UX**: Native platform conventions respected across Web, Android, iOS, Windows, and macOS with Material 3 adaptive components

**Project-Specific Principles**:
- **Educational Data Security**: All student data protected with role-based access control
- **Real-time Collaboration**: Firebase real-time sync for instant updates across devices
- **Multi-role Architecture**: Tailored experiences for teachers, students, and parents
- **Offline Resilience**: Cached data and local notifications for offline capability

**Workspace Inheritance**: None - using global defaults (standalone project)

---

## ContextKit Workflow

**Systematic Feature Development**:
- `/ctxk:plan:1-spec` - Create business requirements specification (prompts interactively)
- `/ctxk:plan:2-research-tech` - Define technical research, architecture and implementation approach
- `/ctxk:plan:3-steps` - Break down into executable implementation tasks

**Development Execution**:
- `/ctxk:impl:start-working` - Continue development within feature branch (requires completed planning phases)
- `/ctxk:impl:commit-changes` - Auto-format code and commit with intelligent messages

**Backlog Management**:
- `/ctxk:bckl:add-idea` - Add new feature ideas with complexity evaluation
- `/ctxk:bckl:add-bug` - Report bugs with severity and impact assessment

**Quality Assurance**: Automated agents validate code quality during development
**Project Management**: All validated build/test commands documented above for immediate use

---

## Development Automation

**Quality Agents Available**:
- `build-project` - Execute Flutter builds with validation
- `check-accessibility` - Material 3 accessibility compliance, semantic labels, contrast validation
- `check-localization` - intl package usage, externalized strings validation
- `check-error-handling` - Exception handling patterns, typed errors
- `check-modern-code` - Modern Dart patterns (async/await, null safety)
- `check-code-debt` - Technical debt identification, code cleanup recommendations

**Hooks Configured**:
- **PostToolUse** (Edit/Write/MultiEdit): AutoFormat.sh - Automatic code formatting with dart format
- **SessionStart**: VersionStatus.sh - Display ContextKit version and updates

---

## Configuration Hierarchy

**Inheritance**: None (standalone project) → **Fermi Plus Project**

**This Project Configuration**:
- **Workspace**: None (standalone project)
- **Project**: Flutter application with multi-platform support
- **Platform Configurations**: Android, iOS, Web, Windows, macOS platform-specific settings

**Override Precedence**: Project settings are authoritative (no workspace inheritance)

---

*Generated by ContextKit 0.1.0 on 2025-10-11 with comprehensive component analysis. Manual edits preserved during updates.*