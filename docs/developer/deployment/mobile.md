# Mobile Deployment Guide

Complete deployment guide for iOS and Android platforms for the Fermi Flutter application.

## iOS Deployment

### Prerequisites
- macOS with Xcode installed
- Apple Developer Account (paid)
- Flutter iOS toolchain configured
- CocoaPods installed
- iOS device or simulator for testing

### Initial Setup

#### Apple Developer Account Configuration
1. Sign up for Apple Developer Program ($99/year)
2. Create App Store Connect app record
3. Configure Bundle ID: `com.fermi.education`
4. Set up certificates and provisioning profiles

#### Xcode Project Configuration
```bash
# Open iOS project in Xcode
open ios/Runner.xcworkspace
```

##### `ios/Runner/Info.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Fermi</string>
    <key>CFBundleDisplayName</key>
    <string>Fermi Education</string>
    <key>CFBundleIdentifier</key>
    <string>com.fermi.education</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    
    <!-- Firebase Configuration -->
    <key>FirebaseAppDelegateProxyEnabled</key>
    <false/>
    
    <!-- Camera and Photo Library Permissions -->
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access to upload assignment photos</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>This app needs photo library access to upload images</string>
    
    <!-- Push Notifications -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
    
    <!-- URL Schemes for OAuth -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.fermi.education.oauth</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.fermi.education</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### Build Configuration

#### Release Build Script
```bash
#!/bin/bash
# scripts/build-ios-release.sh

set -e

echo "Building iOS Release..."

# Clean previous builds
flutter clean
cd ios && rm -rf build && cd ..

# Get dependencies
flutter pub get
cd ios && pod install && cd ..

# Build release
flutter build ios --release \
  --dart-define=ENVIRONMENT=production \
  --build-name=1.0.0 \
  --build-number=1

# Archive for App Store
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/

echo "iOS build completed!"
```

#### `ios/ExportOptions.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

### Firebase Configuration for iOS

#### `ios/Runner/GoogleService-Info.plist`
```xml
<!-- Download from Firebase Console -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CLIENT_ID</key>
    <string>your-client-id</string>
    <key>REVERSED_CLIENT_ID</key>
    <string>your-reversed-client-id</string>
    <!-- ... other Firebase configuration -->
</dict>
</plist>
```

### App Store Deployment

#### Manual Deployment
```bash
# Build and archive
flutter build ios --release

# Upload to App Store Connect
cd ios
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/

# Upload IPA
xcrun altool --upload-app \
  -f build/Runner.ipa \
  -u "your-apple-id@email.com" \
  -p "app-specific-password"
```

#### Fastlane Configuration
```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and upload to App Store"
  lane :release do
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release"
    )
    
    upload_to_app_store(
      skip_metadata: true,
      skip_screenshots: true,
      submit_for_review: false
    )
  end
  
  desc "Build for testing"
  lane :beta do
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release"
    )
    
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end
end
```

## Android Deployment

### Prerequisites
- Android SDK and tools installed
- Google Play Console account ($25 one-time fee)
- Java Development Kit (JDK) 11+
- Android signing keys generated

### Initial Setup

#### Google Play Console Configuration
1. Create app in Google Play Console
2. Set up app signing with Google Play App Signing
3. Configure store listing and content ratings
4. Upload app bundle for internal testing

#### Android Project Configuration

##### `android/app/build.gradle`
```gradle
android {
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId "com.fermi.education"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    flavorDimensions "default"
    productFlavors {
        production {
            dimension "default"
            applicationIdSuffix ""
            manifestPlaceholders = [appName: "Fermi"]
        }
        staging {
            dimension "default"
            applicationIdSuffix ".staging"
            manifestPlaceholders = [appName: "Fermi Staging"]
        }
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlin_version"
    implementation 'androidx.multidex:multidex:2.0.1'
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-messaging'
}

apply plugin: 'com.google.gms.google-services'
```

#### App Signing Configuration

##### Generate Signing Key
```bash
keytool -genkey -v -keystore ~/fermi-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias fermi-key
```

##### `android/key.properties`
```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=fermi-key
storeFile=/path/to/fermi-release-key.jks
```

### Firebase Configuration for Android

#### `android/app/google-services.json`
```json
{
  "project_info": {
    "project_number": "your-project-number",
    "project_id": "fermi-education"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "your-app-id",
        "android_client_info": {
          "package_name": "com.fermi.education"
        }
      }
    }
  ]
}
```

#### `android/app/src/main/AndroidManifest.xml`
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.fermi.education">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.VIBRATE" />
    
    <application
        android:name=".MainApplication"
        android:label="${appName}"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true"
        android:usesCleartextTraffic="true">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
                
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            
            <!-- Deep link handling -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https"
                      android:host="fermi-education.web.app" />
            </intent-filter>
        </activity>
        
        <!-- Firebase Messaging -->
        <service
            android:name=".firebase.MessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/colorPrimary" />
    </application>
</manifest>
```

### Build Configuration

#### Release Build Script
```bash
#!/bin/bash
# scripts/build-android-release.sh

set -e

echo "Building Android Release..."

# Clean previous builds
flutter clean
cd android && ./gradlew clean && cd ..

# Get dependencies
flutter pub get

# Build App Bundle for Play Store
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --build-name=1.0.0 \
  --build-number=1 \
  --flavor production

# Build APK for distribution
flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --build-name=1.0.0 \
  --build-number=1 \
  --flavor production

echo "Android build completed!"
echo "App Bundle: build/app/outputs/bundle/productionRelease/app-production-release.aab"
echo "APK: build/app/outputs/flutter-apk/app-production-release.apk"
```

### Google Play Store Deployment

#### Manual Upload
1. Build app bundle: `flutter build appbundle --release`
2. Upload to Google Play Console
3. Complete store listing information
4. Set up content ratings and target audience
5. Configure app pricing and distribution
6. Submit for review

#### Automated Deployment with Fastlane
```ruby
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Build and upload to Google Play Store"
  lane :release do
    gradle(
      task: "bundle",
      flavor: "production",
      build_type: "Release"
    )
    
    upload_to_play_store(
      track: 'production',
      aab: 'build/app/outputs/bundle/productionRelease/app-production-release.aab'
    )
  end
  
  desc "Upload to internal testing"
  lane :internal do
    gradle(
      task: "bundle",
      flavor: "production", 
      build_type: "Release"
    )
    
    upload_to_play_store(
      track: 'internal',
      aab: 'build/app/outputs/bundle/productionRelease/app-production-release.aab'
    )
  end
end
```

### ProGuard Configuration

#### `android/app/proguard-rules.pro`
```proguard
# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep custom classes
-keep class com.fermi.education.** { *; }

# Gson rules (if using JSON serialization)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
```

## Cross-Platform Testing

### Device Testing Strategy
```bash
# iOS Simulator testing
flutter run -d "iPhone 14 Pro"
flutter run -d "iPad Pro (12.9-inch)"

# Android Emulator testing  
flutter run -d "Pixel 7 Pro API 34"
flutter run -d "Pixel Tablet API 34"

# Physical device testing
flutter devices
flutter run -d [device-id]
```

### Automated Testing on CI/CD
```yaml
# .github/workflows/mobile-test.yml
name: Mobile Testing
on: [push, pull_request]

jobs:
  ios-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run iOS tests
        run: flutter test --platform=ios
        
      - name: Build iOS
        run: flutter build ios --no-codesign
        
  android-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run Android tests
        run: flutter test --platform=android
        
      - name: Build Android
        run: flutter build appbundle --debug
```

## Performance Optimization

### Build Optimization
```bash
# Optimized release builds
flutter build apk --release \
  --obfuscate \
  --split-debug-info=debug_symbols \
  --tree-shake-icons

flutter build ios --release \
  --obfuscate \
  --split-debug-info=debug_symbols \
  --tree-shake-icons
```

### App Size Optimization
```dart
// pubspec.yaml
flutter:
  uses-material-design: true
  
  # Only include necessary assets
  assets:
    - assets/images/essential/
  
  # Tree shake unused icons
  generate: true
```

### Performance Monitoring
```dart
// lib/services/mobile_performance_service.dart
class MobilePerformanceService {
  static Future<void> trackAppStart() async {
    final trace = FirebasePerformance.instance.newTrace('app_start');
    await trace.start();
    
    // App initialization logic
    
    await trace.stop();
  }
  
  static Future<void> trackScreenLoad(String screenName) async {
    final trace = FirebasePerformance.instance.newTrace('screen_load_$screenName');
    await trace.start();
    
    // Screen loading logic
    
    await trace.stop();
  }
}
```

## Security Considerations

### Network Security
```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">fermi-education.firebaseapp.com</domain>
    </domain-config>
</network-security-config>
```

### Certificate Pinning
```dart
// lib/services/http_service.dart
class HttpService {
  static final Dio dio = Dio();
  
  static void configureCertificatePinning() {
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Implement certificate pinning logic
        return _validateCertificate(cert, host);
      };
      return client;
    };
  }
}
```

## Troubleshooting

### Common iOS Issues
```bash
# CocoaPods issues
cd ios && pod deintegrate && pod install

# Xcode build issues
flutter clean
cd ios && rm -rf build && cd ..
flutter build ios

# Signing issues
# Verify certificates in Xcode
# Check provisioning profiles
# Ensure bundle ID matches
```

### Common Android Issues
```bash
# Gradle issues
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get

# Signing issues
# Verify key.properties configuration
# Check keystore file path
# Ensure signing configuration is correct

# Multidex issues
# Add multidex dependency
# Enable multidex in build.gradle
```

[content placeholder]