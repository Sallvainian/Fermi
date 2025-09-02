# Dependencies Documentation

Complete overview of all package dependencies used in the Fermi Flutter application, including their purposes, versions, and configuration details.

## Core Dependencies

### Flutter Framework
```yaml
# SDK Constraints
environment:
  sdk: '>=3.5.0 <4.0.0'
  flutter: ">=3.24.0"
```

### Firebase Integration
```yaml
# Firebase Core Services
firebase_core: ^3.3.0              # Firebase initialization and configuration
firebase_auth: ^5.1.4              # User authentication and authorization
cloud_firestore: ^5.2.1            # NoSQL database for app data
firebase_storage: ^12.1.3          # File and media storage
firebase_messaging: ^15.0.4        # Push notifications
firebase_analytics: ^11.2.1        # User analytics and insights
firebase_crashlytics: ^4.0.4       # Crash reporting and monitoring
firebase_performance: ^0.10.0+4    # Performance monitoring
firebase_remote_config: ^5.0.4     # Remote configuration management
firebase_app_check: ^0.3.0+4       # App integrity verification
```

**Configuration:**
- Handles all backend services
- Provides real-time data synchronization
- Manages user authentication flows
- Enables offline data persistence

### State Management
```yaml
provider: ^6.1.2                   # State management solution
```

**Usage:**
- Primary state management pattern
- Manages UI state and business logic
- Provides reactive updates to widgets
- Handles data flow between components

### Routing and Navigation
```yaml
go_router: ^14.2.3                 # Declarative routing solution
```

**Configuration:**
- Type-safe navigation
- Authentication-based route guards
- Deep linking support
- Nested routing capabilities

### UI and Design
```yaml
# Material Design and Theming
flutter_localizations:             # Internationalization support
  sdk: flutter
intl: ^0.19.0                      # Internationalization utilities

# Custom Widgets and Components
fl_chart: ^0.68.0                  # Charts and data visualization
image_picker: ^1.1.2               # Camera and gallery image selection
cached_network_image: ^3.3.1       # Network image caching
photo_view: ^0.15.0                # Zoomable image viewer
flutter_staggered_grid_view: ^0.7.0 # Advanced grid layouts
```

### Utilities and Helpers
```yaml
# Date and Time
timeago: ^3.6.1                    # Human-readable time differences

# HTTP and Networking
http: ^1.2.1                       # HTTP client for API calls
dio: ^5.4.3                        # Advanced HTTP client

# Local Storage
shared_preferences: ^2.2.3         # Simple key-value storage
hive: ^2.2.3                       # Lightweight database
hive_flutter: ^1.1.0               # Hive Flutter integration

# File Handling
path_provider: ^2.1.3              # File system path access
file_picker: ^8.0.0                # File selection from device

# Permissions
permission_handler: ^11.3.1        # Runtime permissions management

# Device Information
device_info_plus: ^10.1.0          # Device information access
package_info_plus: ^8.0.0          # App package information

# Connectivity
connectivity_plus: ^6.0.3          # Network connectivity status
```

## Development Dependencies

### Testing Framework
```yaml
dev_dependencies:
  # Core Testing
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  
  # Mocking and Test Utilities
  mockito: ^5.4.4                  # Mock object generation
  build_runner: ^2.4.9             # Code generation tool
  json_annotation: ^4.9.0          # JSON serialization annotations
  json_serializable: ^6.8.0        # JSON serialization code generation
  
  # Firebase Testing
  fake_cloud_firestore: ^3.0.1     # Mock Firestore for testing
  firebase_auth_mocks: ^0.14.1     # Mock Firebase Auth
  
  # Widget Testing
  network_image_mock: ^2.1.1       # Mock network images in tests
  patrol: ^3.9.0                   # Advanced testing capabilities
```

### Code Quality and Analysis
```yaml
  # Linting and Analysis
  flutter_lints: ^4.0.0            # Official Flutter linting rules
  very_good_analysis: ^6.0.0       # Additional strict linting rules
  
  # Code Generation
  freezed: ^2.5.2                  # Immutable data classes
  freezed_annotation: ^2.4.3       # Freezed annotations
  
  # Asset Generation
  flutter_launcher_icons: ^0.13.1  # App icon generation
  flutter_native_splash: ^2.4.0    # Splash screen generation
```

### Platform-Specific Dependencies

#### iOS Dependencies
```yaml
# iOS-specific packages
sign_in_with_apple: ^6.1.1        # Apple Sign-In integration
```

**Configuration in `ios/Podfile`:**
```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!
  
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

# Firebase configuration
pod 'Firebase/Analytics'
pod 'Firebase/Auth'
pod 'Firebase/Firestore'
pod 'Firebase/Storage'
pod 'Firebase/Messaging'
```

#### Android Dependencies
```yaml
# Android-specific packages handled via Gradle
```

**Configuration in `android/app/build.gradle`:**
```gradle
dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlin_version"
    implementation 'androidx.multidex:multidex:2.0.1'
    
    // Firebase
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-firestore'
    implementation 'com.google.firebase:firebase-storage'
    implementation 'com.google.firebase:firebase-messaging'
    
    // Google Play Services
    implementation 'com.google.android.gms:play-services-auth'
}
```

#### Web Dependencies
```html
<!-- web/index.html -->
<!-- Firebase SDKs -->
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-storage-compat.js"></script>
```

## Dependency Management

### Version Constraints Strategy
```yaml
# Exact version for critical dependencies
firebase_core: 3.3.0

# Caret constraints for stable packages
provider: ^6.1.2                  # Allows 6.1.x and 6.2.x
go_router: ^14.2.3               # Allows 14.x.x

# Range constraints for flexible dependencies
intl: ">=0.18.0 <0.20.0"        # Specific range
```

### Dependency Update Process
```bash
# Check for outdated dependencies
flutter pub outdated

# Update dependencies
flutter pub upgrade

# Update specific package
flutter pub upgrade firebase_core

# Get dependencies after pubspec.yaml changes
flutter pub get

# Verify dependency tree
flutter pub deps
```

### Security and Maintenance
```bash
# Check for security vulnerabilities
flutter pub audit

# Analyze package health
flutter pub deps --style=compact

# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build
```

## Platform-Specific Configurations

### iOS Configuration

#### `ios/Runner/Info.plist`
```xml
<!-- Required permissions and configurations -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos for assignments</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice recordings</string>

<!-- Firebase configuration -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<!-- Background modes for push notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Android Configuration

#### `android/app/src/main/AndroidManifest.xml`
```xml
<!-- Required permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Firebase Messaging Service -->
<service
    android:name=".firebase.MessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

## Development Tools Integration

### VS Code Extensions
```json
// .vscode/extensions.json
{
  "recommendations": [
    "dart-code.dart-code",
    "dart-code.flutter",
    "ms-vscode.vscode-json",
    "bradlc.vscode-tailwindcss",
    "formulahendry.auto-rename-tag"
  ]
}
```

### IDE Configuration
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  
linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    unnecessary_const: true
    avoid_print: true
    prefer_single_quotes: true
```

## Build Tools and Scripts

### Code Generation
```bash
# Generate JSON serialization code
flutter packages pub run build_runner build

# Generate continuously during development
flutter packages pub run build_runner watch

# Clean generated files
flutter packages pub run build_runner clean
```

### Asset Generation
```bash
# Generate app icons
flutter pub run flutter_launcher_icons

# Generate splash screen
flutter pub run flutter_native_splash:create

# Remove splash screen
flutter pub run flutter_native_splash:remove
```

## Performance Optimization

### Bundle Analysis
```bash
# Analyze app size
flutter build appbundle --analyze-size
flutter build ios --analyze-size

# Check for unused dependencies
flutter pub deps --style=compact | grep -E '^\s*\w+:'
```

### Tree Shaking
```yaml
# pubspec.yaml - Enable tree shaking for icons
flutter:
  uses-material-design: true
  generate: true  # Enables tree shaking
```

## Troubleshooting Dependencies

### Common Issues and Solutions

#### Version Conflicts
```bash
# Resolve version conflicts
flutter pub dependency_override
```

```yaml
# pubspec_overrides.yaml
dependency_overrides:
  meta: ^1.10.0  # Force specific version
```

#### Platform-Specific Issues

**iOS CocoaPods Issues:**
```bash
cd ios
pod deintegrate
pod clean
pod install --repo-update
```

**Android Gradle Issues:**
```bash
cd android
./gradlew clean
./gradlew build --refresh-dependencies
```

#### Firebase Configuration Issues
```bash
# Reconfigure Firebase
flutterfire configure

# Check Firebase configuration
flutter pub run firebase_core:check_updates
```

### Dependency Health Monitoring
```yaml
# Set up automated dependency updates in CI/CD
name: Dependency Updates
on:
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Monday

jobs:
  update-dependencies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update dependencies
        run: flutter pub upgrade --major-versions
      - name: Run tests
        run: flutter test
```

## Migration Guides

### Major Version Upgrades
When upgrading major versions:

1. **Check Breaking Changes**: Review changelog for breaking changes
2. **Update Gradually**: Update one major dependency at a time
3. **Test Thoroughly**: Run full test suite after each update
4. **Check Platform Compatibility**: Ensure iOS/Android compatibility
5. **Update Documentation**: Update this file with new versions

### Flutter SDK Updates
```bash
# Check current Flutter version
flutter --version

# Update Flutter
flutter upgrade

# Check for breaking changes
flutter doctor

# Update dependencies after Flutter upgrade
flutter pub upgrade
```

[content placeholder]