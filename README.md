# Fermi Plus - Education Management Platform

![Flutter Version](https://img.shields.io/badge/Flutter-3.32.0-blue)
![Dart Version](https://img.shields.io/badge/Dart-3.8.0-blue)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20Android%20%7C%20iOS%20%7C%20Windows-lightgrey)
![Version](https://img.shields.io/badge/Version-0.9.6-brightgreen)

🌐 **Live Demo**: [https://academic-tools.org](https://academic-tools.org)

## 📚 Overview

Fermi Plus is a comprehensive education management platform that revolutionizes classroom management and student engagement. Built with Flutter and Firebase, it provides real-time collaboration tools for teachers, students, and parents, creating a unified educational ecosystem.

### 🎯 Mission
Empowering educators with modern technology to create engaging, efficient, and data-driven learning environments that improve student outcomes and streamline administrative tasks.

### 🌟 Key Differentiators
- **Real-Time Collaboration**: Instant updates across all devices with Firebase real-time sync
- **Behavior Point System**: Unique gamified approach to student behavior management
- **Cross-Platform Native**: Single codebase for Web, iOS, Android, and Windows
- **Role-Based Architecture**: Tailored experiences for teachers, students, and parents
- **Privacy-First Design**: FERPA-compliant with granular access controls
- **Progressive Web App**: Installable web app with offline capabilities

## ✨ Features

### 👨‍🏫 For Teachers

#### Class Management
- Create unlimited classes with custom subjects and grade levels
- Generate unique enrollment codes for easy student registration
- Manage class rosters with bulk operations
- Archive and restore classes by academic year
- Real-time student attendance tracking

#### Assignment System
- Rich text assignment creation with file attachments
- Customizable due dates and submission requirements
- Auto-grading for objective questions
- Rubric-based assessment tools
- Assignment templates and reusability
- Bulk assignment operations

#### Grading & Analytics
- Comprehensive gradebook with weighted categories
- Real-time grade calculations and progress tracking
- Performance analytics and trend visualization
- Custom grading scales and standards
- Grade export to CSV/Excel
- Parent-viewable progress reports

#### Behavior Management
- **Behavior Points System** (Unique Feature)
  - Award positive points for achievements
  - Track negative points for infractions
  - Visual performance indicators
  - Weekly/monthly behavior reports
  - Customizable behavior categories
  - Class-wide behavior analytics

#### Communication Hub
- Direct messaging with students and parents
- Class-wide announcements
- Discussion boards for collaborative learning
- Scheduled message delivery
- Read receipts and typing indicators
- File and media sharing

### 👨‍🎓 For Students

#### Dashboard Experience
- Personalized dashboard with upcoming assignments
- Real-time grade visibility
- Behavior point tracking and achievements
- Calendar integration with due dates
- Assignment submission portal
- Resource library access

#### Learning Tools
- Interactive discussion participation
- Peer collaboration spaces
- Educational games (Jeopardy-style quizzes)
- Study groups and chat rooms
- Assignment clarification requests
- Portfolio showcase

#### Account Management
- Account claim system for student ownership
- Profile customization
- Notification preferences
- Parent account linking
- Multi-device synchronization

### 👪 For Parents

#### Monitoring & Engagement
- Real-time access to student grades
- Behavior point tracking
- Assignment completion status
- Teacher communication portal
- Attendance records
- Progress reports and analytics

## 🏗️ Architecture

### Clean Architecture Implementation

```
lib/
├── features/                    # Feature-based modular architecture
│   ├── admin/                  # Admin management features
│   │   ├── data/               # Data sources and repositories
│   │   ├── domain/             # Business logic and models
│   │   └── presentation/       # UI screens and providers
│   ├── assignments/            # Assignment management
│   ├── auth/                   # Authentication system
│   ├── behavior_points/        # Behavior tracking (Unique)
│   ├── calendar/               # Calendar integration
│   ├── chat/                   # Real-time messaging
│   ├── classes/                # Class management
│   ├── dashboard/              # Dashboard views
│   ├── discussions/            # Discussion boards
│   ├── games/                  # Educational games
│   ├── grades/                 # Grading system
│   ├── notifications/          # Push notifications
│   ├── student/                # Student management
│   ├── students/               # Students listing and management
│   └── teacher/                # Teacher features
├── shared/                      # Shared components
│   ├── core/                   # App initialization, DI
│   ├── models/                 # Shared data models
│   ├── providers/              # Global state providers
│   ├── routing/                # Navigation configuration
│   ├── screens/                # Common screens
│   ├── services/               # Shared services layer
│   ├── theme/                  # Theming and styling
│   ├── utils/                  # Utility functions
│   └── widgets/                # Reusable UI components
└── main.dart                   # Application entry point
```

### Technology Stack

#### Frontend
- **Flutter 3.32.0** - Cross-platform UI framework
- **Dart 3.8.0** - Programming language
- **Provider** - State management solution
- **GoRouter 16.2** - Declarative navigation
- **Material 3** - Modern design system

#### Backend & Infrastructure
- **Firebase Auth** - Multi-provider authentication
- **Cloud Firestore** - NoSQL real-time database
- **Firebase Storage** - Media and file storage
- **Firebase Functions** - Serverless backend logic
- **Firebase Hosting** - Web deployment
- **Firebase Cloud Messaging** - Push notifications

#### Key Dependencies
- **fl_chart** - Data visualization
- **cached_network_image** - Image optimization
- **video_player** - Media playback
- **flutter_local_notifications** - Local notifications
- **sign_in_with_apple** - iOS authentication
- **google_sign_in** - Google OAuth
- **device_calendar** - Calendar sync
- **file_picker** - File selection
- **image_picker** - Camera/gallery access

### Design Patterns

- **Provider Pattern**: Reactive state management
- **Repository Pattern**: Data access abstraction
- **Service Layer**: Business logic encapsulation
- **Feature-First Architecture**: Modular organization
- **Clean Architecture**: Separation of concerns
- **SOLID Principles**: Maintainable code structure

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.32.0, <4.0.0)
- Dart SDK (>=3.8.0)
- Firebase CLI
- Node.js (for Firebase Functions)
- Git
- IDE (VS Code or Android Studio)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/fermi-plus.git
   cd fermi-plus
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools

   # Login to Firebase
   firebase login

   # Initialize Firebase (if needed)
   flutterfire configure --project=teacher-dashboard-flutterfire
   ```

4. **Environment Setup**
   Create a `.env` file in the root directory:
   ```env
   GOOGLE_OAUTH_CLIENT_ID=your_client_id
   GOOGLE_OAUTH_CLIENT_SECRET=your_client_secret
   ```

5. **Platform-Specific Setup**

   **Android**:
   - Place `google-services.json` in `android/app/`

   **iOS**:
   - Place `GoogleService-Info.plist` in `ios/Runner/`
   - Configure Sign in with Apple in Xcode

   **Web**:
   - Firebase config is embedded in `web/index.html`

### Running the Application

```bash
# Web (recommended for development)
flutter run -d chrome

# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Windows
flutter run -d windows

# List all available devices
flutter devices
```

### Building for Production

```bash
# Web
flutter build web --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release
```

## 🔥 Firebase Configuration

### Firestore Database Structure

```javascript
// Users Collection
users/{userId} {
  email: string,
  displayName: string,
  role: "teacher" | "student" | "parent" | "admin",
  createdAt: timestamp,
  emailVerified: boolean,
  profileImageUrl?: string,
  settings?: object
}

// Classes Collection
classes/{classId} {
  teacherId: string,
  name: string,
  subject: string,
  gradeLevel: string,
  enrollmentCode: string,
  studentIds: string[],
  createdAt: timestamp,
  academicYear: string,
  isArchived: boolean
}

// Assignments Collection
assignments/{assignmentId} {
  classId: string,
  teacherId: string,
  title: string,
  description: string,
  dueDate: timestamp,
  points: number,
  status: "draft" | "published" | "closed",
  attachments?: string[],
  rubric?: object
}

// Behavior Points Collection
behaviorPoints/{pointId} {
  studentId: string,
  teacherId: string,
  classId: string,
  points: number,
  category: string,
  description: string,
  createdAt: timestamp,
  isPositive: boolean
}

// Grades Collection
grades/{gradeId} {
  studentId: string,
  assignmentId: string,
  classId: string,
  score: number,
  maxScore: number,
  feedback?: string,
  submittedAt: timestamp,
  gradedAt: timestamp
}

// Messages Collection
messages/{messageId} {
  senderId: string,
  recipientIds: string[],
  content: string,
  timestamp: timestamp,
  readBy: object,
  attachments?: string[]
}

// Discussion Boards Collection
discussionBoards/{boardId} {
  classId: string,
  title: string,
  description: string,
  createdBy: string,
  createdAt: timestamp,
  posts: subcollection
}
```

### Security Rules

The application implements comprehensive Firestore security rules that ensure:

- **Authentication Required**: All database access requires authentication
- **Role-Based Access**: Teachers, students, and parents have different permissions
- **Data Isolation**: Users can only access their authorized data
- **Email Verification**: Sensitive operations require verified email
- **Domain Validation**: School email domains are enforced
- **Write Protection**: Only authorized users can modify data

Example security rule pattern:
```javascript
match /classes/{classId} {
  allow read: if request.auth != null &&
    (isTeacher() || isStudentInClass(classId));
  allow write: if request.auth != null &&
    isTeacher() && request.auth.uid == resource.data.teacherId;
}
```

## 🧪 Testing

### Test Structure
```
test/
├── unit/           # Unit tests for services and models
├── widget/         # Widget tests for UI components
├── integration/    # Integration tests
└── fixtures/       # Test data and mocks
```

### Running Tests
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/auth_service_test.dart

# Run integration tests
flutter test integration_test/
```

### Code Quality
```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Check for issues
dart fix --dry-run

# Apply fixes
dart fix --apply
```

## 🚀 CI/CD Pipeline

### Deployment Commands

```bash
# Deploy everything to Firebase
firebase deploy

# Deploy specific services
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
firebase deploy --only functions

# Preview deployment
firebase hosting:channel:deploy preview
```

## 📊 Performance & Optimization

### Performance Features
- **Lazy Loading**: Components load on demand
- **Image Caching**: Cached network images for performance
- **Pagination**: Large lists are paginated
- **Debouncing**: Search and input optimization
- **Code Splitting**: Web build optimization
- **Tree Shaking**: Unused code elimination

### Monitoring
- Firebase Performance Monitoring
- Custom performance metrics
- Error tracking with stack traces
- User session analytics

## 🔐 Security & Privacy

### Security Features
- **OAuth 2.0**: Secure authentication
- **Email Verification**: Required for sensitive operations
- **Domain Validation**: School email enforcement
- **Role-Based Access**: Granular permissions
- **Data Encryption**: In-transit and at-rest
- **Session Management**: Secure token handling

### Privacy Compliance
- **FERPA Compliant**: Educational privacy standards
- **COPPA Considerations**: Child privacy protection
- **Data Minimization**: Only essential data collected
- **User Control**: Data export and deletion
- **Transparent Policies**: Clear privacy documentation

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md).

### Development Workflow
1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

### Commit Convention
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation
- `style:` Formatting
- `refactor:` Code restructuring
- `test:` Testing
- `chore:` Maintenance

## 📈 Roadmap

### Current Version (0.9.6)
- ✅ Core platform features
- ✅ Multi-platform support
- ✅ Real-time collaboration
- ✅ Behavior point system
- ✅ Firebase integration
- ✅ Student management improvements

### Version 1.0 (Q1 2025)
- [ ] Parent portal enhancements
- [ ] Advanced analytics dashboard
- [ ] Attendance tracking system
- [ ] Report card generation
- [ ] Bulk import/export tools

### Version 1.1 (Q2 2025)
- [ ] AI-powered insights
- [ ] Video conferencing integration
- [ ] LMS integration (Canvas, Blackboard)
- [ ] Multi-language support
- [ ] Custom branding options

### Future Enhancements
- [ ] Offline mode with sync
- [ ] Voice assistant integration
- [ ] AR/VR learning experiences
- [ ] Blockchain certificates
- [ ] API for third-party integrations

## 📞 Support

- **Documentation**: [Wiki](https://github.com/your-org/fermi-plus/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-org/fermi-plus/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/fermi-plus/discussions)
- **Email**: support@fermi-plus.com
- **Discord**: [Join our community](https://discord.gg/fermi-plus)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for the robust backend platform
- Material Design team for design guidelines
- Open source community for invaluable packages
- Our educators for feedback and insights
- Students and parents for their patience and support

---

**Built with ❤️ by the Fermi Plus Team**

*Transforming education through technology, one classroom at a time.*