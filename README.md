# Fermi

A comprehensive education management platform built with Flutter and Firebase, designed to streamline classroom management, student tracking, and educational workflows.

🌐 **Live Demo**: [https://academic-tools.org](https://academic-tools.org)

## 🚀 Overview

Teacher Dashboard is a modern, cross-platform educational management system that connects teachers, students, and parents. Built with Flutter for beautiful, responsive UIs and Firebase for real-time data synchronization and secure authentication.

### Key Highlights
- 📱 **Cross-Platform**: Web, Android, and iOS from a single codebase
- 🔥 **Real-time Updates**: Instant synchronization across all devices
- 🔐 **Secure**: Role-based access control with comprehensive Firestore rules
- 🎨 **Modern UI**: Material 3 design with adaptive layouts
- ⚡ **Fast**: Optimized performance with efficient state management
- 🚀 **CI/CD**: Automated testing and deployment pipeline

## ✨ Features

### Core Functionality
- ✅ **Authentication System**
  - Email/password authentication
  - Google Sign-In integration
  - Email verification
  - Password reset
  - Role-based access (Teacher/Student/Parent)

- ✅ **Class Management**
  - Create and manage classes
  - Enrollment codes for easy student registration
  - Class rosters and student tracking
  - Subject and grade level organization

- ✅ **Student Management**
  - Student profiles and enrollment
  - Grade tracking and progress monitoring
  - Parent contact information
  - Account claim system for students

- ✅ **Assignments & Grading**
  - Create and distribute assignments
  - Due date tracking
  - Grade submission and management
  - Assignment status tracking

- ✅ **Communication**
  - Direct messaging between teachers and students
  - Group chat for classes
  - Discussion boards for collaborative learning
  - Real-time chat with read receipts

- ✅ **Dashboard & Analytics**
  - Teacher dashboard with key metrics
  - Student dashboard with assignments and grades
  - Recent activity tracking
  - Performance analytics (in progress)

### Additional Features
- 📅 **Calendar Integration** - Schedule and event management
- 🔔 **Notifications** - Assignment reminders and updates
- 🎮 **Educational Games** - Interactive learning activities (Jeopardy)
- 📊 **Reports** - Grade reports and progress tracking
- 🌙 **Theme Support** - Light and dark modes

## 🛠️ Tech Stack

### Frontend
- **Flutter** (3.24+) - Cross-platform UI framework
- **Dart** (3.5+) - Programming language
- **Provider** - State management
- **GoRouter** - Navigation and routing
- **Material 3** - Design system

### Backend
- **Firebase Auth** - Authentication and user management
- **Cloud Firestore** - NoSQL real-time database
- **Firebase Storage** - File and media storage
- **Firebase Hosting** - Web app hosting
- **Firebase Functions** - Serverless backend logic

### DevOps
- **GitHub Actions** - CI/CD pipeline
- **Firebase CLI** - Deployment and management
- **Flutter Web** - Progressive Web App (PWA) support

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Web** | ✅ Production | Primary platform, PWA enabled |
| **Android** | ✅ Production | Full feature support |
| **iOS** | ✅ Production | Full feature support |
| **macOS** | ❌ Not Supported | Firebase SDK limitations |
| **Windows** | ❌ Not Supported | Firebase SDK limitations |
| **Linux** | ❌ Not Supported | Firebase SDK limitations |

## 🏗️ Architecture

The project follows Clean Architecture principles with a feature-based structure:

```
lib/
├── features/                 # Feature modules
│   ├── auth/                # Authentication
│   │   ├── data/           # Services and Firebase integration
│   │   ├── domain/         # Models and business logic
│   │   └── presentation/   # Screens and providers
│   ├── classes/             # Class management
│   ├── students/            # Student management
│   ├── assignments/         # Assignment system
│   ├── grades/              # Grading system
│   ├── chat/                # Messaging
│   ├── discussions/         # Discussion boards
│   └── calendar/            # Calendar feature
├── shared/                   # Shared code
│   ├── core/               # App initialization, DI
│   ├── routing/            # Navigation configuration
│   ├── theme/              # App theming
│   ├── widgets/            # Reusable widgets
│   ├── utils/              # Utilities
│   └── services/           # Shared services
└── main.dart                # App entry point
```

### Design Patterns
- **Provider Pattern** - State management
- **Repository Pattern** (simplified) - Data access abstraction
- **Service Layer** - Business logic encapsulation
- **Feature-First Organization** - Modular architecture

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.24.0)
- Dart SDK (>=3.5.0)
- Firebase CLI
- Git
- IDE (VS Code or Android Studio recommended)

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
   # Install Firebase CLI (if not already installed)
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Configure Firebase for your project
   flutterfire configure --project=teacher-dashboard-flutterfire
   ```

4. **Run the application**
   ```bash
   # Web (recommended for development)
   flutter run -d chrome
   
   # Android
   flutter run -d android
   
   # iOS (macOS only)
   flutter run -d ios
   ```

### Development Commands

```bash
# Check code quality
flutter analyze

# Run tests
flutter test

# Format code
dart format .

# Build for production
flutter build web --release
flutter build apk --release
flutter build ios --release
```

## 🔥 Firebase Configuration

### Firestore Structure
```
users/{userId}
├── email: string
├── displayName: string
├── role: string (teacher/student/parent)
├── createdAt: timestamp
└── emailVerified: boolean

classes/{classId}
├── teacherId: string
├── name: string
├── subject: string
├── gradeLevel: string
├── enrollmentCode: string
├── studentIds: array
└── createdAt: timestamp

assignments/{assignmentId}
├── classId: string
├── teacherId: string
├── title: string
├── description: string
├── dueDate: timestamp
└── status: string

grades/{gradeId}
├── studentId: string
├── assignmentId: string
├── classId: string
├── score: number
└── feedback: string

discussionBoards/{boardId}
├── classId: string
├── title: string
├── posts/{postId}
│   ├── authorId: string
│   ├── content: string
│   └── createdAt: timestamp
```

### Security Rules
Comprehensive Firestore security rules ensure:
- Users can only access their own data
- Teachers manage their classes and students
- Students access only enrolled classes
- Role-based permissions throughout
- Email verification requirements for sensitive operations

## 🚀 Deployment

### Automatic Deployment (CI/CD)
The project uses GitHub Actions for automated deployment:

1. **Push to main branch** triggers the CI/CD pipeline
2. **CI workflow** runs tests and builds the app
3. **Deploy workflow** automatically deploys to Firebase

### Manual Deployment

```bash
# Deploy everything
firebase deploy

# Deploy specific services
firebase deploy --only hosting           # Web app
firebase deploy --only firestore:rules   # Security rules
firebase deploy --only storage:rules     # Storage rules
firebase deploy --only functions         # Cloud Functions
```

## 🧪 Testing

### Run Tests
```bash
# All tests
flutter test

# With coverage
flutter test --coverage

# Specific test file
flutter test test/widget_test.dart
```

### Test Database Connection
```bash
# Simple database test
flutter run lib/test_db_simple.dart

# Setup test data
flutter run lib/setup_test_data.dart
```

## 📊 CI/CD Pipeline

The project includes comprehensive GitHub Actions workflows:

### Workflows
- **CI** - Runs on every push and PR
  - Code analysis
  - Unit tests
  - Build verification
  
- **Deploy Web** - Triggered on main branch
  - Builds production app
  - Deploys to Firebase Hosting
  - Updates Firestore rules

- **Mobile Builds** - Creates APK/IPA artifacts

### Status Badges
![CI](https://github.com/Sallvainian/teacher-dashboard-flutter-firebase/workflows/CI/badge.svg)
![Deploy](https://github.com/Sallvainian/teacher-dashboard-flutter-firebase/workflows/Deploy%20Web/badge.svg)

## 🔧 Environment Variables

The project uses environment-specific configuration:

### Required Secrets (GitHub Actions)
- `FIREBASE_TOKEN` - Firebase CI token
- `FIREBASE_API_KEY` - Web API key
- `FIREBASE_PROJECT_ID` - Firebase project ID
- `FIREBASE_APP_ID_*` - Platform-specific app IDs

### Local Development
Create platform-specific configuration files:
- `android/app/google-services.json` - Android
- `ios/Runner/GoogleService-Info.plist` - iOS
- `web/index.html` - Web configuration

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
   - Follow Dart style guide
   - Add tests for new features
   - Update documentation
4. **Commit with conventional commits**
   ```bash
   git commit -m "feat: add amazing feature"
   ```
5. **Push and create PR**
   ```bash
   git push origin feature/amazing-feature
   ```

### Commit Convention
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation
- `style:` - Formatting, no code change
- `refactor:` - Code restructuring
- `test:` - Adding tests
- `chore:` - Maintenance

## 📱 Development Best Practices

### Code Quality
- Run `flutter analyze` before committing
- Maintain >80% test coverage for critical features
- Use meaningful variable and function names
- Document complex logic with comments

### State Management
- Use Provider for global state
- Keep state as local as possible
- Implement proper loading and error states
- Use `ChangeNotifier` with `notifyListeners()` carefully

### Firebase Best Practices
- Enable offline persistence for better UX
- Use batch operations for multiple writes
- Implement proper error handling
- Optimize queries with composite indexes

### Performance
- Use `const` constructors where possible
- Implement lazy loading for lists
- Optimize images and assets
- Monitor bundle size

## 🆘 Troubleshooting

### Common Issues

**setState() during build**
- Wrap state changes in `WidgetsBinding.instance.addPostFrameCallback()`

**Firebase Permission Denied**
- Check Firestore security rules
- Ensure user is authenticated and email verified
- Verify document paths

**Web Package Compatibility**
- Use conditional imports for web-specific code
- Create stub files for platform-specific implementations

**Build Failures**
- Run `flutter clean` and `flutter pub get`
- Check for dependency conflicts
- Verify Firebase configuration files

## 📈 Roadmap

### Current Sprint
- [ ] Complete performance analytics dashboard
- [ ] Add export functionality for grades
- [ ] Implement attendance tracking
- [ ] Add parent portal access

### Future Enhancements
- [ ] AI-powered assignment suggestions
- [ ] Video conferencing integration
- [ ] Advanced reporting and analytics
- [ ] Mobile offline support
- [ ] Multi-language support
- [ ] Integration with Google Classroom
- [ ] Automated grading for objective questions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- **Development**: Sallvainian
- **Design**: Material Design 3 Guidelines
- **Infrastructure**: Firebase Platform

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for the backend platform
- Material Design team for design guidelines
- Open source community for invaluable packages

## 📞 Support

- 📧 **Issues**: [GitHub Issues](https://github.com/Sallvainian/teacher-dashboard-flutter-firebase/issues)
- 📖 **Documentation**: [Wiki](https://github.com/Sallvainian/teacher-dashboard-flutter-firebase/wiki)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Sallvainian/teacher-dashboard-flutter-firebase/discussions)

---

**Built with ❤️ using Flutter and Firebase**

*Empowering educators with modern technology for better learning outcomes*