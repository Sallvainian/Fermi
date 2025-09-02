# Developer Troubleshooting Guide

Comprehensive troubleshooting guide for common development issues encountered when working on the Fermi Flutter application.

## Table of Contents
- [Environment Setup Issues](#environment-setup-issues)
- [Build and Compilation Errors](#build-and-compilation-errors)
- [Firebase Integration Problems](#firebase-integration-problems)
- [Platform-Specific Issues](#platform-specific-issues)
- [State Management Issues](#state-management-issues)
- [Performance Problems](#performance-problems)
- [Testing Issues](#testing-issues)
- [Deployment Problems](#deployment-problems)

## Environment Setup Issues

### Flutter Doctor Issues

#### Problem: Flutter doctor shows issues
```bash
# Check Flutter installation
flutter doctor -v
```

**Common Solutions:**
```bash
# Update Flutter
flutter upgrade

# Fix Android licensing
flutter doctor --android-licenses

# Install missing Android SDK
flutter doctor --android-licenses
sdkmanager "platforms;android-34" "build-tools;34.0.0"

# Fix Xcode issues (macOS)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

#### Problem: Command not found - flutter
```bash
# Add Flutter to PATH (macOS/Linux)
export PATH="$PATH:[PATH_TO_FLUTTER_GIT_DIRECTORY]/flutter/bin"

# Add to shell profile
echo 'export PATH="$PATH:[PATH_TO_FLUTTER_GIT_DIRECTORY]/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Windows - Add to system PATH through Environment Variables
```

### Dependency Installation Issues

#### Problem: `flutter pub get` fails
```bash
# Clear pub cache
flutter pub cache clean

# Get dependencies
flutter pub get

# If persistent, delete pubspec.lock and retry
rm pubspec.lock
flutter pub get
```

#### Problem: Version conflicts
```yaml
# pubspec_overrides.yaml - Create this file to override versions
dependency_overrides:
  meta: ^1.10.0
  collection: ^1.18.0
```

```bash
# Check dependency tree
flutter pub deps

# Analyze dependency conflicts
flutter pub deps --style=compact
```

## Build and Compilation Errors

### Dart Analysis Issues

#### Problem: Analysis errors in IDE
```bash
# Run analysis
flutter analyze

# Clean and rebuild analysis
dart analysis_server --shutdown
flutter clean
flutter pub get
```

#### Problem: Import errors
```dart
// ✅ Correct import structure
// Dart imports first
import 'dart:async';
import 'dart:convert';

// Flutter imports
import 'package:flutter/material.dart';

// Package imports  
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Relative imports last
import '../models/user_model.dart';
import 'auth_service.dart';

// ❌ Avoid mixing import types
```

### Build Failures

#### Problem: Build fails with Gradle errors (Android)
```bash
# Clean Gradle cache
cd android
./gradlew clean
./gradlew build --refresh-dependencies

# Clear Gradle cache globally
rm -rf ~/.gradle/caches

# Update Gradle wrapper
./gradlew wrapper --gradle-version=8.0
```

#### Problem: iOS build fails with CocoaPods errors
```bash
# Clean and reinstall pods
cd ios
rm -rf Pods
rm Podfile.lock
pod deintegrate
pod setup
pod install --repo-update

# Clear derived data (Xcode)
rm -rf ~/Library/Developer/Xcode/DerivedData
```

#### Problem: Web build fails
```bash
# Clear web build cache
flutter clean
rm -rf build/web

# Build with verbose output
flutter build web --verbose

# Check for web-incompatible packages
flutter build web --tree-shake-icons
```

### Code Generation Issues

#### Problem: Generated files not updating
```bash
# Clean generated files
flutter packages pub run build_runner clean

# Rebuild generated files
flutter packages pub run build_runner build --delete-conflicting-outputs

# Watch mode for development
flutter packages pub run build_runner watch
```

## Firebase Integration Problems

### Authentication Issues

#### Problem: Firebase Auth not working
```dart
// Check Firebase initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(MyApp());
}
```

#### Problem: Google Sign-In not working
```bash
# Android - Check SHA1 fingerprint
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Add SHA1 to Firebase Console
# Download updated google-services.json
```

```dart
// Check GoogleSignIn configuration
final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: 'your-client-id.apps.googleusercontent.com', // iOS only
  scopes: ['email', 'profile'],
);
```

#### Problem: Apple Sign-In not working (iOS)
```bash
# Check Apple Developer configuration
# Verify Sign in with Apple capability is enabled
# Check bundle ID matches Apple Developer Console
```

### Firestore Issues

#### Problem: Permission denied errors
```javascript
// Check Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Debug rule (remove in production)
    match /{document=**} {
      allow read, write: if true; // WARNING: Only for testing
    }
  }
}
```

#### Problem: Firestore queries not working
```dart
// Check query structure and indexes
Future<List<Assignment>> getAssignments(String classId) async {
  try {
    final query = FirebaseFirestore.instance
        .collection('assignments')
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true); // Requires index
        
    final snapshot = await query.get();
    
    if (snapshot.docs.isEmpty) {
      print('No assignments found for class: $classId');
      return [];
    }
    
    return snapshot.docs
        .map((doc) => Assignment.fromJson(doc.data()))
        .toList();
  } catch (e) {
    print('Firestore query error: $e');
    rethrow;
  }
}
```

### Storage Issues

#### Problem: File upload fails
```dart
Future<String> uploadFile(File file, String path) async {
  try {
    // Check file size (Firebase Storage limits)
    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) { // 10MB limit
      throw Exception('File too large');
    }
    
    final ref = FirebaseStorage.instance.ref().child(path);
    final uploadTask = ref.putFile(file);
    
    // Monitor upload progress
    uploadTask.snapshotEvents.listen((snapshot) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
    });
    
    await uploadTask;
    return await ref.getDownloadURL();
  } catch (e) {
    print('Upload error: $e');
    rethrow;
  }
}
```

## Platform-Specific Issues

### iOS Issues

#### Problem: iOS app crashes on startup
```bash
# Check iOS logs
flutter logs --device-id=[ios-device-id]

# Common causes and solutions:
# 1. Missing Info.plist permissions
# 2. Incorrect bundle identifier
# 3. Missing Apple certificates
# 4. Incorrect Firebase configuration
```

```xml
<!-- ios/Runner/Info.plist - Add required permissions -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access</string>
```

#### Problem: iOS build architecture issues
```bash
# Clean iOS build
flutter clean
cd ios
rm -rf build
xcodebuild clean -workspace Runner.xcworkspace -scheme Runner

# Check architecture settings in Xcode
# Build Settings -> Architectures -> Excluded Architectures
# Debug -> Any iOS Simulator SDK -> arm64 (for M1 Macs)
```

### Android Issues

#### Problem: Android app won't install
```bash
# Check app signing
flutter install --debug

# For release builds, check signing configuration
keytool -list -v -keystore android/app/debug.keystore

# Uninstall and reinstall
adb uninstall com.fermi.education
flutter install
```

#### Problem: Android permissions not working
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Add to application tag -->
<application
    android:requestLegacyExternalStorage="true">
```

```dart
// Request permissions at runtime
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  final permissions = [
    Permission.camera,
    Permission.storage,
    Permission.photos,
  ];
  
  final statuses = await permissions.request();
  
  for (final permission in permissions) {
    if (statuses[permission] != PermissionStatus.granted) {
      print('Permission denied: $permission');
    }
  }
}
```

### Web Issues

#### Problem: Web app CORS errors
```javascript
// Configure CORS for Firebase Storage
// In Firebase Console -> Storage -> Rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

#### Problem: Web app not loading
```html
<!-- web/index.html - Check script loading -->
<script>
  window.addEventListener('load', function(ev) {
    // Check if Flutter is loading
    _flutter.loader.loadEntrypoint({
      serviceWorker: {
        serviceWorkerVersion: serviceWorkerVersion,
      }
    }).then(function(engineInitializer) {
      return engineInitializer.initializeEngine();
    }).then(function(appRunner) {
      return appRunner.runApp();
    }).catch(function(error) {
      console.error('Failed to load Flutter app:', error);
    });
  });
</script>
```

## State Management Issues

### Provider Issues

#### Problem: Provider not updating UI
```dart
// ✅ Correct: Extend ChangeNotifier and call notifyListeners()
class AssignmentProvider extends ChangeNotifier {
  List<Assignment> _assignments = [];
  
  List<Assignment> get assignments => _assignments;
  
  void addAssignment(Assignment assignment) {
    _assignments.add(assignment);
    notifyListeners(); // Important!
  }
  
  void updateAssignment(Assignment updated) {
    final index = _assignments.indexWhere((a) => a.id == updated.id);
    if (index != -1) {
      _assignments[index] = updated;
      notifyListeners(); // Important!
    }
  }
}

// ❌ Incorrect: Missing notifyListeners()
class BadProvider extends ChangeNotifier {
  List<Assignment> assignments = [];
  
  void addAssignment(Assignment assignment) {
    assignments.add(assignment);
    // Missing notifyListeners() - UI won't update!
  }
}
```

#### Problem: Provider scope issues
```dart
// ✅ Correct: Proper provider setup
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AssignmentProvider()),
        ProxyProvider<AuthProvider, UserProvider>(
          update: (context, auth, previous) => UserProvider(
            user: auth.currentUser,
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}

// ❌ Incorrect: Provider not accessible
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // This will fail if provider is not in widget tree above
    final provider = Provider.of<AssignmentProvider>(context);
    return Text('Assignments: ${provider.assignments.length}');
  }
}
```

## Performance Problems

### Memory Leaks

#### Problem: Memory leaks in listeners
```dart
// ✅ Correct: Proper listener management
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    
    // Set up listeners
    _subscription = FirebaseFirestore.instance
        .collection('assignments')
        .snapshots()
        .listen(_onAssignmentsChanged);
        
    _timer = Timer.periodic(Duration(minutes: 5), _refreshData);
  }
  
  @override
  void dispose() {
    // Clean up listeners
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
  
  void _onAssignmentsChanged(QuerySnapshot snapshot) {
    // Handle data changes
  }
  
  void _refreshData(Timer timer) {
    // Periodic refresh
  }
  
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

#### Problem: Large lists causing performance issues
```dart
// ✅ Correct: Use ListView.builder for large lists
class AssignmentList extends StatelessWidget {
  final List<Assignment> assignments;
  
  const AssignmentList({required this.assignments});
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        return AssignmentTile(
          key: ValueKey(assignments[index].id), // Stable key
          assignment: assignments[index],
        );
      },
    );
  }
}

// ❌ Incorrect: Building all widgets at once
class BadAssignmentList extends StatelessWidget {
  final List<Assignment> assignments;
  
  const BadAssignmentList({required this.assignments});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: assignments.map((assignment) {
        return AssignmentTile(assignment: assignment);
      }).toList(), // Creates all widgets immediately
    );
  }
}
```

## Testing Issues

### Unit Test Problems

#### Problem: Tests failing due to async operations
```dart
// ✅ Correct: Proper async testing
void main() {
  group('AssignmentProvider', () {
    testWidgets('should load assignments', (tester) async {
      // Setup
      final provider = AssignmentProvider();
      
      // Act
      await provider.loadAssignments('class-123');
      await tester.pump(); // Important for async operations
      
      // Assert
      expect(provider.assignments, isNotEmpty);
      expect(provider.isLoading, isFalse);
    });
  });
}

// ❌ Incorrect: Not handling async properly
testWidgets('bad async test', (tester) async {
  final provider = AssignmentProvider();
  provider.loadAssignments('class-123'); // No await
  
  // This will likely fail because loading isn't complete
  expect(provider.assignments, isNotEmpty);
});
```

#### Problem: Firebase testing issues
```dart
// Setup Firebase mocks for testing
void main() {
  setupFirebaseAuthMocks();
  
  group('AuthService Tests', () {
    late MockFirebaseAuth mockAuth;
    late AuthService authService;
    
    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(auth: mockAuth);
    });
    
    test('should sign in user', () async {
      // Arrange
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
      );
      
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => MockUserCredential(user: mockUser));
      
      // Act
      final result = await authService.signIn('test@example.com', 'password');
      
      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.user?.uid, equals('test-uid'));
    });
  });
}
```

### Widget Test Problems

#### Problem: Widget tests can't find widgets
```dart
// ✅ Correct: Proper widget testing setup
testWidgets('should display assignment list', (tester) async {
  // Arrange
  final assignments = [
    Assignment(id: '1', title: 'Test Assignment'),
  ];
  
  // Build widget tree with necessary providers
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => AssignmentProvider()..setAssignments(assignments),
        child: AssignmentScreen(),
      ),
    ),
  );
  
  // Wait for all animations and builds
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.text('Test Assignment'), findsOneWidget);
});

// ❌ Incorrect: Missing providers or MaterialApp
testWidgets('bad widget test', (tester) async {
  await tester.pumpWidget(AssignmentScreen()); // Missing MaterialApp and providers
  expect(find.text('Test Assignment'), findsOneWidget); // Will fail
});
```

## Deployment Problems

### Build Issues

#### Problem: Release build crashes
```bash
# Enable debugging for release builds
flutter build apk --debug
flutter build ios --debug

# Check for null safety issues
flutter analyze --no-sound-null-safety

# Test release build locally
flutter run --release
```

#### Problem: App size too large
```bash
# Analyze app size
flutter build appbundle --analyze-size
flutter build apk --analyze-size --target-platform android-arm64

# Enable code shrinking
# android/app/build.gradle
android {
    buildTypes {
        release {
            shrinkResources true
            minifyEnabled true
        }
    }
}
```

### Store Deployment Issues

#### Problem: App Store rejection (iOS)
Common rejection reasons and fixes:
1. **Missing privacy descriptions**: Add to Info.plist
2. **Crashes on launch**: Test thoroughly on physical devices
3. **Design guidelines**: Follow Apple Human Interface Guidelines
4. **Metadata issues**: Ensure keywords and description are accurate

#### Problem: Google Play rejection (Android)
Common rejection reasons and fixes:
1. **Target SDK version**: Ensure targeting latest Android API
2. **Permissions**: Only request necessary permissions
3. **64-bit requirement**: Include ARM64 architecture
4. **Store listing**: Complete all required metadata

## Debugging Tools and Techniques

### Flutter Inspector
```bash
# Launch with inspector
flutter run --debug

# Web debugging
flutter run -d chrome --web-port=8080
```

### Logging and Debugging
```dart
// ✅ Good: Structured logging
import 'dart:developer' as developer;

class LoggingService {
  static void logInfo(String message, {String? tag}) {
    developer.log(message, name: tag ?? 'Info');
  }
  
  static void logError(String message, Object? error, StackTrace? stackTrace) {
    developer.log(
      message,
      name: 'Error',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

// Usage
try {
  await loadAssignments();
} catch (e, stackTrace) {
  LoggingService.logError('Failed to load assignments', e, stackTrace);
}
```

### Performance Profiling
```bash
# Run performance analysis
flutter run --profile

# Analyze performance in DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

[content placeholder]