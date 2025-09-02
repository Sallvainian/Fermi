# Fermi Project Knowledgebase

## Overview
Fermi (also known as Fermi Plus) is a cross-platform education management platform built primarily with Flutter. It targets teachers and students, providing tools for managing assignments, grades, classes, discussions, chat, calendar events, notifications, and educational games like Jeopardy. The app supports multiple platforms including Android, iOS, macOS, web, and Windows. Version: 0.9.3.

## Tech Stack
- **Frontend**: Flutter (Dart) with various plugins for Firebase integration, file handling, notifications, etc.
- **Backend**: Firebase Cloud Functions (TypeScript/Node.js) for server-side logic.
- **Database**: Firestore for data storage and real-time updates.
- **Authentication**: Firebase Authentication.
- **Storage**: Firebase Storage for file uploads/downloads.
- **Deployment**: Cloudflare Pages for web hosting; Firebase Hosting and Emulators for development.
- **Other Tools**: ESLint for linting, TypeScript for backend, various Node.js dependencies like Express, Jest for testing.

## Directory Structure Summary
- **lib/**: Core Flutter app code, including features (auth, assignments, chat, etc.), shared utilities, models, providers, and widgets.
- **functions/**: Firebase Cloud Functions backend (TypeScript), with dependencies like Firebase Admin, Express, CORS.
- **android/ios/macos/web/windows/**: Platform-specific code and configurations.
- **assets/**: Images and icons.
- **docs/**: Developer and user documentation.
- **node_modules/**: Dependencies for backend and tools.
- **build/**: Build outputs.
- **scripts/**: Utility scripts.
- **keys/**: Likely API keys or secrets.

## Key Files
- **pubspec.yaml**: Flutter project configuration, dependencies (e.g., firebase_core, cloud_firestore, provider).
- **lib/main.dart**: App entry point, sets up providers, theme, routing, and Firebase initialization.
- **firebase.json**: Firebase project config for hosting, Firestore rules, storage, emulators, and functions.
- **functions/package.json**: Backend dependencies and scripts (build, serve, deploy with Firebase).
- **package.json** (root): Basic config for Cloudflare deployment.

## Main Components and Features
- **Authentication**: User login, email verification, linking.
- **Dashboard**: Overview for teachers and students.
- **Classes**: Management of classes, students, teachers.
- **Assignments**: Creation, submission, grading.
- **Grades**: Tracking and viewing grades.
- **Chat**: Real-time messaging.
- **Calendar**: Event scheduling.
- **Notifications**: Push notifications via Firebase Messaging.
- **Games**: Educational games like Jeopardy.
- **Discussions**: Forums or discussion boards.
- **Shared Utilities**: Providers for state management, repositories for data access, custom widgets.

This knowledgebase provides high-level context for the project. For detailed code analysis, refer to specific files or directories.