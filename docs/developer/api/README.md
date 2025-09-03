# API Documentation

This section covers the API and data layer architecture of the Fermi education platform.

## Overview

Fermi uses Firebase as its backend-as-a-service, providing:
- **Firestore Database**: NoSQL document database for all application data
- **Firebase Auth**: User authentication and authorization
- **Cloud Storage**: File and media storage
- **Cloud Functions**: Serverless backend logic
- **Firestore**: Also used for presence ("presence" collection with lastSeen/online)
  - Note: We currently use Firestore snapshots for presence across platforms.
  - Real-time Database is optional and not used for presence in the current build.

## Architecture

The API layer follows Clean Architecture principles with:
- **Data Layer**: Repository implementations and service integrations
- **Domain Layer**: Business logic and repository interfaces  
- **Presentation Layer**: UI components and state management

## Core Services

### Authentication
- Email/password authentication
- Google Sign-In integration
- Apple Sign-In for iOS
- Role-based access control (Teacher/Student/Admin)
- Email verification system

### Data Management
- Real-time data synchronization
- Offline data persistence
- Optimistic updates
- Conflict resolution strategies

### File Management
- Image and document uploads
- Progressive image loading
- File type validation
- Storage quota management

## Security Model

All API access is secured through:
- Firebase Security Rules
- Role-based permissions
- User authentication tokens
- Data validation at multiple layers

## Performance Considerations

- Query optimization with Firestore indexes
- Data pagination for large collections
- Caching strategies for frequently accessed data
- Connection pooling and retry logic

## Navigation

- [Firestore Collections](firestore-collections.md) - Database schema and structure
- [Cloud Functions](cloud-functions.md) - Serverless backend functions
- [Storage](storage.md) - File storage patterns and organization

[content placeholder]
