# Fermi Monorepo

A comprehensive education management platform built with Flutter and Firebase, designed to streamline classroom management, student tracking, and educational workflows.

🌐 **Live Demo**: [https://academic-tools.org](https://academic-tools.org)

## 🚀 Overview

Fermi is a modern, cross-platform educational management system that connects teachers and students. Built with Flutter for beautiful, responsive UIs and Firebase for real-time data synchronization and secure authentication.

### Key Highlights
- 📱 **Cross-Platform**: Web, Android, iOS, and Windows from a single codebase
- 🔥 **Real-time Updates**: Instant synchronization across all devices
- 🔐 **Secure**: Role-based access control with comprehensive Firestore rules
- 🎨 **Modern UI**: Material 3 design with adaptive layouts
- ⚡ **Fast**: Optimized performance with efficient state management
- 🚀 **CI/CD**: Automated testing and deployment pipeline via GitHub Actions

## 📁 Monorepo Structure

```
fermi-monorepo/
├── apps/
│   ├── fermi/          # Main Flutter application
│   └── docs/           # Documentation site
├── .github/            # GitHub Actions workflows
└── cloudflare-build.sh # Cloudflare deployment script
```

## ✨ Features

### Core Functionality
- ✅ **Authentication System**
  - Email/password authentication
  - Google Sign-In integration
  - Apple Sign-In integration (iOS)
  - OAuth2 flow (Windows desktop)
  - Email verification
  - Role-based access (Teacher/Student)

- ✅ **Class Management**
  - Create and manage classes
  - Enrollment codes for easy student registration
  - Class rosters and student tracking
  - Subject and grade level organization

- ✅ **Assignments & Grading**
  - Create and distribute assignments
  - Due date tracking
  - Grade submission and management
  - Assignment status tracking

- ✅ **Communication**
  - Direct messaging between teachers and students
  - Group chat for classes
  - Discussion boards with likes and replies
  - Real-time chat with presence indicators

- ✅ **Additional Features**
  - Calendar integration for scheduling
  - Push notifications system
  - Educational games (Jeopardy)
  - Student profile management

## 🛠️ Tech Stack

### Frontend
- **Flutter** (3.24+) - Cross-platform UI framework
- **Dart** (3.8+) - Programming language
- **Provider** (6.1.5+) - State management
- **GoRouter** (16.1.0+) - Navigation and routing

### Backend
- **Firebase Auth** - Authentication and user management
- **Cloud Firestore** - NoSQL real-time database
- **Firebase Storage** - File and media storage
- **Firebase Messaging** - Push notifications
- **Cloud Functions** - Serverless backend logic

### Deployment
- **Cloudflare Pages** - Web hosting with global CDN
- **GitHub Actions** - CI/CD pipeline
- **Firebase Hosting** - Alternative hosting option

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Web** | ✅ Production | Primary platform, PWA enabled |
| **Android** | ✅ Production | Full feature support |
| **iOS** | ✅ Production | Apple Sign-In supported |
| **Windows** | ✅ Beta | OAuth2 authentication |

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.24.0)
- Dart SDK (>=3.8.0)
- Firebase CLI
- Node.js (>=18.0.0)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Sallvainian/fermi-monorepo.git
   cd fermi-monorepo
   ```

2. **Install dependencies**
   ```bash
   # Install monorepo dependencies
   npm install
   
   # Install Flutter dependencies
   cd apps/fermi
   flutter pub get
   ```

3. **Firebase Setup**
   ```bash
   # Login to Firebase
   firebase login
   
   # Configure Firebase for your project
   flutterfire configure --project=your-project-id
   ```

4. **Run the application**
   ```bash
   # From monorepo root
   npm run dev:fermi
   
   # Or directly from Flutter app
   cd apps/fermi
   flutter run -d chrome
   ```

### Monorepo Scripts

```bash
# Development
npm run dev:fermi    # Run Flutter app in Chrome
npm run dev:docs     # Run documentation site

# Build
npm run build:fermi  # Build Flutter web app
npm run build:docs   # Build documentation

# Quality
npm run test:fermi   # Run Flutter tests
npm run analyze:fermi # Analyze Flutter code
npm run clean        # Clean Flutter build
```

## 🔥 Firebase Configuration

### Active Collections (30 total)
- **Core**: users, pending_users, presence
- **Classes**: classes, students, teachers  
- **Assignments**: assignments, submissions, grades
- **Communication**: chat_rooms, messages, conversations, notifications
- **Discussion**: discussion_boards, threads, replies, likes, comments
- **Calendar**: calendar_events, scheduled_messages
- **Games**: games, jeopardy_games, jeopardy_sessions, scores

### Security Rules
Comprehensive role-based access control with teacher/student permissions implemented in Firestore rules.

## 🚀 Deployment

### Cloudflare Pages (Production)
The app automatically deploys to Cloudflare Pages on push to master branch using the `cloudflare-build.sh` script.

### GitHub Actions CI/CD
Automated workflows handle:
- Code analysis and testing (`01_ci.yml`)
- Web deployment (`02_deploy_web.yml`)
- Windows release builds (`03_windows_release.yml`)
- macOS release builds (`04_macos_release.yml`)

### Manual Deployment

```bash
# Build for web
cd apps/fermi
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

## 🏗️ Architecture

The Flutter app follows Clean Architecture with feature-based organization:

```
apps/fermi/lib/
├── features/           # Feature modules
│   ├── auth/          # Authentication
│   ├── classes/       # Class management
│   ├── assignments/   # Assignment system
│   ├── chat/          # Messaging
│   ├── discussions/   # Discussion boards
│   └── ...
├── shared/            # Shared code
│   ├── core/         # App initialization
│   ├── routing/      # Navigation
│   └── widgets/      # Reusable widgets
└── main.dart         # App entry point
```

## 📊 Project Status

- **Version**: 0.9.5
- **Commits**: 400+
- **Feature Completion**: ~75%
- **Collections**: 30 Firestore collections
- **Implementation Files**: 113+

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes using conventional commits (`feat:`, `fix:`, `docs:`)
4. Push to your branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Live App**: [https://academic-tools.org](https://academic-tools.org)
- **Repository**: [https://github.com/Sallvainian/fermi-monorepo](https://github.com/Sallvainian/fermi-monorepo)
- **Issues**: [GitHub Issues](https://github.com/Sallvainian/fermi-monorepo/issues)

---

**Built with ❤️ using Flutter and Firebase**

*Empowering educators with modern technology for better learning outcomes*
