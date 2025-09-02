# Project Organization and Structure

## Table of Contents
- [Overview](#overview)
- [Root Directory Structure](#root-directory-structure)
- [Core Application Structure](#core-application-structure)
- [Feature-Based Organization](#feature-based-organization)
- [Shared Components](#shared-components)
- [Asset Organization](#asset-organization)
- [Configuration Files](#configuration-files)
- [Development Tools](#development-tools)
- [Documentation Structure](#documentation-structure)

## Overview

Fermi follows a **feature-based folder structure** combined with **Clean Architecture** principles. This organization promotes:
- **Feature Locality**: All related code grouped together
- **Scalability**: Easy to add new features without restructuring
- **Team Productivity**: Clear ownership and responsibility boundaries
- **Maintainability**: Consistent patterns across the codebase

## Root Directory Structure

```
Fermi/
├── .github/                    # GitHub workflows and templates
├── .vscode/                    # VS Code configuration
├── android/                    # Android platform files
├── assets/                     # Static assets (images, fonts, etc.)
├── docs/                       # Project documentation
├── functions/                  # Firebase Cloud Functions
├── ios/                        # iOS platform files
├── lib/                        # Main Dart source code
├── node_modules/               # Node.js dependencies (for functions)
├── web/                        # Web platform files
├── windows/                    # Windows platform files
├── .gitignore                  # Git ignore rules
├── CLAUDE.md                   # Claude Code project instructions
├── analysis_options.yaml      # Dart analysis configuration
├── firebase.json               # Firebase configuration
├── firestore.indexes.json     # Firestore indexes
├── firestore.rules            # Firestore security rules
├── package-lock.json          # Node.js dependencies lock
├── pubspec.yaml               # Flutter dependencies and metadata
├── pubspec.lock               # Flutter dependencies lock
└── README.md                  # Project readme
```

## Core Application Structure

```
lib/
├── main.dart                   # Application entry point
├── app.dart                    # MaterialApp configuration
├── firebase_options.dart      # Firebase configuration (auto-generated)
├── features/                   # Feature-based modules
├── shared/                     # Shared utilities and components
└── [Generated Files]           # Auto-generated files (builds, etc.)
```

### Key Files Description

#### `main.dart`
- Application initialization
- Firebase setup and configuration
- Provider initialization
- Error handling setup

#### `app.dart`
- MaterialApp configuration
- Theme management
- Router configuration
- Global app settings

#### `firebase_options.dart`
- Auto-generated Firebase configuration
- Platform-specific API keys and settings
- **Never modify manually** - use `flutterfire configure`

## Feature-Based Organization

Each feature follows the **Clean Architecture** pattern with consistent folder structure:

```
lib/features/{feature}/
├── data/                       # Data Layer
│   ├── repositories/           # Repository implementations
│   │   └── {feature}_repository_impl.dart
│   └── services/               # External service integrations
│       └── {feature}_service.dart
├── domain/                     # Business Logic Layer
│   ├── models/                 # Domain models and entities
│   │   └── {feature}_model.dart
│   └── repositories/           # Repository interfaces
│       └── {feature}_repository.dart
├── presentation/               # Presentation Layer
│   ├── screens/                # Full screen widgets
│   │   ├── {feature}_screen.dart
│   │   └── {feature}_detail_screen.dart
│   ├── widgets/                # Feature-specific reusable widgets
│   │   └── {feature}_widget.dart
│   └── providers/              # State management
│       └── {feature}_provider.dart
└── providers/                  # Legacy provider location (being migrated)
    └── {feature}_provider.dart
```

## Implemented Features Structure

### Authentication Feature (`lib/features/auth/`)
```
auth/
├── data/
│   ├── repositories/
│   │   └── auth_repository_impl.dart
│   └── services/
│       └── firebase_auth_service.dart
├── domain/
│   ├── models/
│   │   ├── user_model.dart
│   │   └── auth_state_model.dart
│   └── repositories/
│       └── auth_repository.dart
├── presentation/
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── role_selection_screen.dart
│   │   └── email_verification_screen.dart
│   ├── widgets/
│   │   ├── auth_form_widget.dart
│   │   └── oauth_button_widget.dart
│   └── providers/
│       └── auth_provider.dart
└── [10 total implementation files]
```

### Chat/Messaging Feature (`lib/features/chat/`)
```
chat/
├── data/
│   ├── repositories/
│   │   ├── chat_repository_impl.dart
│   │   └── message_repository_impl.dart
│   └── services/
│       ├── firestore_chat_service.dart
│       └── realtime_presence_service.dart
├── domain/
│   ├── models/
│   │   ├── chat_room_model.dart
│   │   ├── message_model.dart
│   │   └── presence_model.dart
│   └── repositories/
│       ├── chat_repository.dart
│       └── message_repository.dart
├── presentation/
│   ├── screens/
│   │   ├── chat_list_screen.dart
│   │   ├── chat_screen.dart
│   │   └── group_chat_screen.dart
│   ├── widgets/
│   │   ├── message_bubble_widget.dart
│   │   ├── chat_input_widget.dart
│   │   └── presence_indicator_widget.dart
│   └── providers/
│       ├── chat_provider.dart
│       └── presence_provider.dart
└── [23 total implementation files]
```

### Assignment Management (`lib/features/assignments/`)
```
assignments/
├── data/
│   ├── repositories/
│   │   ├── assignment_repository_impl.dart
│   │   └── submission_repository_impl.dart
│   └── services/
│       └── assignment_grading_service.dart
├── domain/
│   ├── models/
│   │   ├── assignment_model.dart
│   │   ├── submission_model.dart
│   │   └── grade_model.dart
│   └── repositories/
│       ├── assignment_repository.dart
│       └── submission_repository.dart
├── presentation/
│   ├── screens/
│   │   ├── assignment_list_screen.dart
│   │   ├── assignment_detail_screen.dart
│   │   ├── create_assignment_screen.dart
│   │   └── submission_screen.dart
│   ├── widgets/
│   │   ├── assignment_card_widget.dart
│   │   └── submission_status_widget.dart
│   └── providers/
│       └── assignment_provider.dart
└── [13 total implementation files]
```

### Complete Feature List
- **Authentication** (10 files) - Login, signup, OAuth, role selection
- **Chat/Messaging** (23 files) - Real-time messaging, presence, voice/video
- **Discussion Boards** (6 files) - Forums, threads, replies, moderation
- **Assignments** (13 files) - Creation, submission, grading, analytics
- **Classes** (12 files) - Class management, enrollment, rosters
- **Notifications** (11 files) - Push notifications, in-app alerts
- **Student Management** (11 files) - Student profiles, progress tracking
- **Calendar** (9 files) - Events, scheduling, reminders
- **Grades** (8 files) - Gradebook, analytics, student views
- **Games** (5 files) - Educational games (Jeopardy)
- **Dashboard** (3 files) - Teacher and student dashboards
- **Teacher Features** (2 files) - Teacher-specific functionality

## Shared Components

```
lib/shared/
├── core/                       # Core application utilities
│   ├── app_providers.dart      # Central provider configuration
│   ├── constants.dart          # Application constants
│   ├── theme.dart             # Application theme configuration
│   └── utils.dart             # Utility functions
├── routing/                    # Navigation and routing
│   ├── app_router.dart        # GoRouter configuration
│   ├── route_guards.dart      # Authentication guards
│   └── route_constants.dart   # Route definitions
├── widgets/                    # Globally reusable widgets
│   ├── common/                # Generic UI components
│   │   ├── loading_widget.dart
│   │   ├── error_widget.dart
│   │   └── empty_state_widget.dart
│   ├── forms/                 # Form components
│   │   ├── custom_text_field.dart
│   │   └── submit_button.dart
│   └── layout/                # Layout components
│       ├── app_bar_widget.dart
│       └── drawer_widget.dart
├── services/                   # Global services
│   ├── notification_service.dart
│   ├── storage_service.dart
│   └── analytics_service.dart
├── models/                     # Shared data models
│   ├── base_model.dart
│   └── api_response.dart
└── extensions/                 # Dart extensions
    ├── string_extensions.dart
    └── datetime_extensions.dart
```

### Key Shared Components

#### `app_providers.dart`
Central provider configuration for the entire application:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => NotificationProvider()),
    // ... other providers
  ],
  child: MyApp(),
)
```

#### `app_router.dart`
GoRouter configuration with authentication guards:
```dart
final appRouter = GoRouter(
  initialLocation: '/auth/login',
  redirect: (context, state) {
    // Authentication and role-based routing logic
  },
  routes: [
    // Route definitions with guards
  ],
);
```

## Asset Organization

```
assets/
├── images/                     # Image assets
│   ├── icons/                 # App icons and small graphics
│   ├── logos/                 # Brand logos and identity
│   ├── illustrations/         # Large illustrations and graphics
│   └── avatars/               # User avatar placeholders
├── fonts/                      # Custom fonts
│   └── CustomFont/
│       ├── CustomFont-Regular.ttf
│       ├── CustomFont-Bold.ttf
│       └── CustomFont-Light.ttf
├── animations/                 # Lottie animations and GIFs
│   └── loading_animation.json
└── data/                       # Static data files
    └── countries.json
```

### Asset Registration (pubspec.yaml)
```yaml
flutter:
  assets:
    - assets/images/
    - assets/fonts/
    - assets/animations/
    - assets/data/
```

## Configuration Files

### Analysis Configuration (`analysis_options.yaml`)
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  
linter:
  rules:
    # Custom lint rules
```

### Firebase Configuration (`firebase.json`)
```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
  },
  "functions": {
    "source": "functions"
  }
}
```

### Firestore Indexes (`firestore.indexes.json`)
```json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "roomId", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    }
  ]
}
```

## Development Tools

### VS Code Configuration (`.vscode/`)
```
.vscode/
├── settings.json              # Editor settings
├── launch.json               # Debug configurations
├── tasks.json                # Task runner configuration
└── extensions.json           # Recommended extensions
```

### GitHub Workflows (`.github/workflows/`)
```
.github/
├── workflows/
│   ├── ci.yml                # Continuous integration
│   ├── deploy-web.yml        # Web deployment
│   ├── build-android.yml     # Android build
│   └── build-ios.yml         # iOS build
└── ISSUE_TEMPLATE/
    ├── bug_report.md
    └── feature_request.md
```

## Documentation Structure

```
docs/
├── developer/                  # Developer documentation
│   ├── architecture/          # Architecture documentation
│   │   ├── overview.md
│   │   ├── folder-structure.md
│   │   ├── state-management.md
│   │   ├── routing.md
│   │   └── security.md
│   ├── api/                   # API documentation
│   ├── setup/                 # Development setup guides
│   └── testing/               # Testing documentation
└── user/                      # User documentation
    ├── installation/          # Installation guides
    └── usage/                 # Usage documentation
```

## Best Practices

### Folder Naming Conventions
- **Features**: Snake_case for multi-word features (`student_management`)
- **Files**: Snake_case for Dart files (`user_profile_screen.dart`)
- **Classes**: PascalCase (`UserProfileScreen`)
- **Variables**: CamelCase (`userProfile`)

### File Organization Rules
- **Single Responsibility**: One main class per file
- **Barrel Exports**: Use `index.dart` files for public APIs
- **Private Files**: Prefix with underscore (`_private_helper.dart`)
- **Test Files**: Mirror source structure in `test/` directory

### Import Organization
```dart
// 1. Dart imports
import 'dart:async';
import 'dart:io';

// 2. Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Third-party package imports
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 4. Local imports (relative paths)
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
```

### Code Organization Guidelines
- Keep feature folders self-contained
- Use consistent layer separation (data/domain/presentation)
- Implement proper barrel exports for public APIs
- Follow Clean Architecture dependency rules
- Maintain clear separation between business logic and UI

### Migration Notes
- **Provider Location**: Migrating from `providers/` to `presentation/providers/`
- **Legacy Code**: Some features still use old structure - migrate gradually
- **Consistent Patterns**: New features should follow the current structure
- **Refactoring**: Prioritize high-impact areas for structural improvements

## Common Patterns

### [Code Examples Section]
[Detailed examples showing proper folder structure implementation]

### [Migration Guide Section]
[Step-by-step guide for migrating legacy code to new structure]

### [Troubleshooting Section]
[Common folder structure issues and solutions]