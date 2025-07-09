# Gemini Project Configuration

This file provides context and guidelines for the Gemini AI assistant to ensure its contributions are aligned with the project's standards and conventions.

## Project Overview

This project is a teacher dashboard application built with Flutter and Firebase. It is designed to help teachers manage their classes, students, assignments, and grades.

## Coding Conventions

*   **Language:** Dart
*   **Framework:** Flutter
*   **Style:** Follow the official [Flutter style guide](https://flutter.dev/docs/development/tools/sdk/guides/linter-rules).
*   **Formatting:** Use `flutter format` to ensure consistent code formatting.
*   **Naming:**
    *   Use `PascalCase` for class names.
    *   Use `camelCase` for variable and method names.
    *   Use `snake_case` for file names.
*   **State Management:** This project uses the `provider` package for state management.

## Architecture

The project follows a layered architecture with a focus on separating concerns:

*   **`lib/models`:** Contains the data models for the application.
*   **`lib/repositories`:** Handles data operations, abstracting the data source (Firebase) from the rest of the application.
*   **`lib/providers`:** Manages the application's state and business logic.
*   **`lib/screens`:** Contains the UI for the different screens of the application.
*   **`lib/widgets`:** Contains reusable UI components.

## Key Libraries & Frameworks

*   **`flutter`:** The core framework for building the UI.
*   **`firebase_core`:** For initializing the Firebase app.
*   **`firebase_auth`:** For authentication.
*   **`cloud_firestore`:** For the database.
*   **`provider`:** For state management.

## Golden Rules

*   Do not use `flutter run`. This is disabled by a hook.
*   Always run `flutter analyze` after making code changes to ensure code quality.
*   All new features should have corresponding unit or widget tests.
*   Do not commit directly to the `main` branch. Use feature branches and pull requests.
