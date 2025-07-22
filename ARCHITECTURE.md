# Architecture - Teacher Dashboard Flutter Firebase

## Clean Architecture Pattern
```
lib/
├── features/               # Feature-based organization
│   ├── auth/              # Authentication feature
│   │   ├── data/          # Data sources, repositories impl
│   │   ├── domain/        # Entities, repositories interfaces
│   │   └── presentation/  # UI, providers, screens
│   ├── assignments/       # Assignment management
│   ├── calendar/          # Calendar & events
│   ├── chat/              # Messaging & calls
│   ├── classes/           # Class management
│   ├── discussions/       # Discussion boards
│   ├── games/             # Educational games
│   ├── grades/            # Grading & analytics
│   ├── notifications/     # Push notifications
│   ├── student/           # Student management
│   └── teacher/           # Teacher features
└── shared/                # Cross-feature utilities
    ├── core/              # App initialization
    ├── models/            # Shared data models
    ├── providers/         # Global providers
    ├── routing/           # Navigation
    ├── services/          # Common services
    ├── utils/             # Utilities
    └── widgets/           # Reusable widgets
```

## State Management: Provider Pattern
- 14 providers centralized in `app_providers.dart`
- ChangeNotifierProvider for reactive state
- Context-based dependency injection
- Feature-specific providers isolated

## Navigation: GoRouter
- Declarative routing with role-based redirects
- Authentication guards in `_handleRedirect`
- Nested routes for feature organization
- Deep linking support

## Security Architecture
- Role-based access control (Teacher/Student)
- Firestore rules enforce permissions
- Authentication required for all data
- User-specific data isolation
- Secure file upload with access control

## Platform Architecture
- **Web**: Service workers, responsive design
- **Mobile**: FCM, biometrics, camera access
- **Desktop**: Native window management
- **Linux limitation**: Firebase unsupported

## Service Layer
- GetIt for dependency injection
- Firebase services abstraction
- Platform-specific implementations
- Offline-first with Firestore persistence

## Performance Optimizations
- Lazy loading with GoRouter
- Provider selective rebuilds
- Image compression/caching
- Firebase Performance monitoring
- Offline data persistence