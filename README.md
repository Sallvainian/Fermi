# Teacher Dashboard - Flutter Firebase

A Flutter-based teacher dashboard application with Firebase backend for managing students, grades, messaging, and educational content.

## Overview

This project is migrating from a multi-framework SvelteKit + Supabase application to a unified Flutter + Firebase ecosystem to simplify development and improve mobile performance.

## Features

- **Authentication**: Role-based access for teachers and students
- **Gradebook**: Real-time grade management and calculations
- **Messaging**: Chat system with file attachments
- **File Management**: Hierarchical file storage with permissions
- **Educational Games**: Interactive learning tools
- **Mobile-First Design**: Optimized for all devices

## Getting Started

### Prerequisites
- Flutter SDK 3.27.1+
- Firebase CLI
- Android Studio / VS Code

### Setup
1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase (see Firebase Setup section)
4. Run the app: `flutter run`

## Firebase Setup

This project uses Firebase for backend services. You'll need to:

1. Create a Firebase project
2. Configure authentication, Firestore, and Storage
3. Update `lib/firebase_options.dart` with your project config
4. Deploy security rules: `firebase deploy --only firestore:rules,storage`

## Project Structure

```
lib/
├── models/          # Data models
├── services/        # Firebase and API services
├── providers/       # State management
├── screens/         # App screens
├── widgets/         # Reusable components
└── main.dart       # App entry point
```

## Development

See [CLAUDE.md](CLAUDE.md) for Firebase Flutter documentation and [COMPREHENSIVE_MIGRATION_ANALYSIS.md](COMPREHENSIVE_MIGRATION_ANALYSIS.md) for detailed migration strategy.
