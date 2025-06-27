# Teacher Dashboard Flutter/Firebase

A comprehensive teacher education management platform built with Flutter and Firebase, designed to streamline classroom management, student tracking, and educational workflows.

## 🚀 Project Overview

This is a migration project from SvelteKit + Supabase to Flutter + Firebase, providing a modern, cross-platform solution for educational management.

### Tech Stack Migration
- **FROM**: SvelteKit 5, TypeScript, Supabase, Tailwind CSS, Netlify
- **TO**: Flutter, Dart, Firebase (Firestore, Auth, Storage, Functions), Firebase Hosting

## ✨ Features

### Current Implementation (Phase 1-2)
- ✅ **Authentication System** - Email/password and Google Sign-In
- ✅ **Responsive Design** - Material 3 design system with adaptive layouts
- ✅ **Firebase Integration** - Firestore database, Authentication, Storage
- ✅ **Cross-Platform** - Web, Android, iOS support
- ✅ **Navigation** - Go Router with protected routes
- ✅ **State Management** - Provider pattern for app state

### Planned Features (Phase 3-4)
- 📚 **Gradebook Management** - Grade tracking and analytics
- 👥 **Student Management** - Enrollment, profiles, progress tracking
- 📝 **Assignment System** - Create, distribute, and grade assignments
- 💬 **Messaging** - Teacher-student-parent communication
- 📊 **Analytics Dashboard** - Performance insights and reports
- 🎮 **Educational Games** - Interactive learning activities
- 📱 **Push Notifications** - Assignment reminders and updates
- 📴 **Offline Support** - Work without internet connection

## 🛠️ Setup Instructions

### Prerequisites
- Flutter SDK (>=3.6.0)
- Firebase CLI
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Sallvainian/teacher-dashboard-flutter-firebase.git
   cd teacher-dashboard-flutter-firebase
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   firebase login
   
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure --project=teacher-dashboard-flutterfire
   ```

4. **Run the application**
   ```bash
   # Web
   flutter run -d chrome
   
   # Android (requires device/emulator)
   flutter run -d android
   
   # iOS (requires macOS and device/simulator)
   flutter run -d ios
   ```

## 🔥 Firebase Configuration

The project uses Firebase for:
- **Authentication** - Email/password and Google Sign-In
- **Firestore** - Real-time database for app data
- **Storage** - File uploads and media management
- **Analytics** - User behavior tracking
- **Crashlytics** - Error monitoring

### Security Rules
Firestore security rules are configured for:
- User document access (users can only access their own data)
- Class management (creators can manage their classes)
- Message/conversation access (participants only)
- File storage permissions

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Web** | ✅ Ready | Primary development platform |
| **Android** | ✅ Ready | Requires google-services.json |
| **iOS** | ✅ Ready | Requires GoogleService-Info.plist |
| **macOS** | 🚧 Planned | Future release |
| **Windows** | ❌ Not Supported | Firebase limitations |
| **Linux** | ❌ Not Supported | Firebase limitations |

## 🗂️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   ├── user_model.dart
│   ├── class_model.dart
│   └── assignment_model.dart
├── services/                 # Business logic
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── storage_service.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   └── data_provider.dart
├── screens/                  # UI screens
│   ├── auth/
│   ├── teacher/
│   └── student/
├── widgets/                  # Reusable components
├── theme/                    # App theming
└── utils/                    # Helper functions
```

## 🔐 Authentication

The app supports multiple authentication methods:

### Email/Password
- Create account with email and password
- Sign in with existing credentials
- Password reset functionality

### Google Sign-In
- One-tap Google authentication
- Automatic profile information sync
- Seamless cross-platform experience

## 💾 Database Schema

### Collections Structure
```
users/{userId}
├── email: string
├── displayName: string
├── createdAt: timestamp
└── lastActive: timestamp

classes/{classId}
├── name: string
├── teacherId: string
├── subject: string
├── createdAt: timestamp
├── students/{studentId}
├── assignments/{assignmentId}
└── grades/{gradeId}

conversations/{conversationId}
├── participants: array
├── lastMessage: timestamp
└── messages/{messageId}
```

## 🧪 Testing

### Database Testing
Use the built-in test utilities:

```bash
# Simple database test (no authentication required)
flutter run lib/test_db_simple.dart

# Full authentication test
flutter run lib/test_db_direct.dart

# Setup test data
flutter run lib/setup_test_data.dart
```

### Unit Tests
```bash
flutter test
```

## 🚀 Deployment

### Web Deployment (Firebase Hosting)
```bash
flutter build web
firebase deploy --only hosting
```

### Android Deployment
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS Deployment
```bash
flutter build ios --release
```

## 🔧 Development Guidelines

### Code Style
- Follow Dart conventions and linting rules
- Use meaningful variable and function names
- Implement proper error handling
- Add comments for complex logic

### Firebase Best Practices
- Use offline persistence for better UX
- Implement proper security rules
- Optimize queries with indexes
- Handle authentication states properly

### State Management
- Use Provider for global state
- Keep state as local as possible
- Implement proper loading states
- Handle errors gracefully

## 📋 Migration Progress

### ✅ Completed Phases
- **Phase 1.1**: Flutter project initialization
- **Phase 1.2**: Firebase project setup
- **Phase 1.3**: Authentication system
- **Phase 1.4**: Navigation and routing
- **Phase 1.5**: Theme and UI foundation
- **Phase 2.1**: Database schema design
- **Phase 2.2**: Security rules implementation

### 🚧 Current Phase
- **Phase 2.3**: Real-time data synchronization
- **Phase 3.1**: Gradebook implementation

### 📅 Upcoming Phases
- **Phase 3.2**: Student management system
- **Phase 3.3**: Assignment creation and distribution
- **Phase 4.1**: Messaging system
- **Phase 4.2**: Analytics and reporting

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Common Issues

**Firebase Configuration Issues**
- Ensure all platform apps are added to Firebase Console
- Verify google-services.json and GoogleService-Info.plist are in correct locations
- Check that bundle IDs match between Flutter and Firebase

**Authentication Problems**
- Enable Authentication providers in Firebase Console
- For Google Sign-In on Android, add SHA-1 fingerprints
- Verify domain authorization for web

**Database Permission Errors**
- Check Firestore security rules
- Ensure user is properly authenticated
- Verify document paths and permissions

### Getting Help
- 📧 Create an issue on GitHub
- 📖 Check the [Firebase Documentation](https://firebase.google.com/docs)
- 📱 Review [Flutter Documentation](https://flutter.dev/docs)

## 📈 Project Stats

- **Languages**: Dart, JavaScript (Firebase Functions)
- **Platforms**: Web, Android, iOS
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage
- **Hosting**: Firebase Hosting

---

**Built with ❤️ using Flutter and Firebase**

*This project represents a modern approach to educational technology, focusing on user experience, scalability, and cross-platform compatibility.*