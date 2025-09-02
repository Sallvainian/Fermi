# CI/CD Pipeline Guide

Comprehensive continuous integration and deployment setup for the Fermi Flutter application using GitHub Actions.

## Overview

The CI/CD pipeline automates:
- **Code Quality**: Linting, formatting, and analysis
- **Testing**: Unit, widget, and integration tests
- **Building**: Web, iOS, and Android builds
- **Deployment**: Automated deployment to Firebase Hosting and app stores
- **Monitoring**: Build status and deployment notifications

## GitHub Actions Workflows

### Main CI Pipeline

#### `.github/workflows/ci.yml`
```yaml
name: CI Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  FLUTTER_VERSION: '3.24.0'
  JAVA_VERSION: '11'

jobs:
  analyze:
    name: Code Analysis
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .
        
      - name: Analyze code
        run: flutter analyze
        
      - name: Check for outdated dependencies
        run: flutter pub outdated --mode=null-safety
        
  test:
    name: Unit and Widget Tests
    runs-on: ubuntu-latest
    needs: analyze
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run tests with coverage
        run: flutter test --coverage
        
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info
          fail_ci_if_error: true
          
  build-web:
    name: Build Web
    runs-on: ubuntu-latest
    needs: [analyze, test]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build web
        run: |
          flutter build web --release \
            --web-renderer html \
            --tree-shake-icons \
            --dart-define=ENVIRONMENT=production
            
      - name: Upload web build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: build/web/
          retention-days: 30
          
  build-android:
    name: Build Android
    runs-on: ubuntu-latest
    needs: [analyze, test]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: ${{ env.JAVA_VERSION }}
          
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build Android APK
        run: |
          flutter build apk --release \
            --dart-define=ENVIRONMENT=production \
            --obfuscate \
            --split-debug-info=debug_symbols
            
      - name: Build Android App Bundle
        run: |
          flutter build appbundle --release \
            --dart-define=ENVIRONMENT=production \
            --obfuscate \
            --split-debug-info=debug_symbols
            
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          
      - name: Upload App Bundle
        uses: actions/upload-artifact@v4
        with:
          name: android-aab
          path: build/app/outputs/bundle/release/app-release.aab
          
  build-ios:
    name: Build iOS
    runs-on: macos-latest
    needs: [analyze, test]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.0'
          
      - name: Build iOS (no code signing)
        run: |
          flutter build ios --release --no-codesign \
            --dart-define=ENVIRONMENT=production \
            --obfuscate \
            --split-debug-info=debug_symbols
```

### Deployment Pipeline

#### `.github/workflows/deploy.yml`
```yaml
name: Deploy
on:
  push:
    branches: [main]
    tags: ['v*']

env:
  FLUTTER_VERSION: '3.24.0'

jobs:
  deploy-web:
    name: Deploy Web to Firebase
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build web for production
        run: |
          flutter build web --release \
            --web-renderer html \
            --tree-shake-icons \
            --dart-define=ENVIRONMENT=production \
            --dart-define=FIREBASE_API_KEY=${{ secrets.FIREBASE_API_KEY }} \
            --dart-define=FIREBASE_PROJECT_ID=${{ secrets.FIREBASE_PROJECT_ID }}
            
      - name: Deploy to Firebase Hosting
        uses: w9jds/firebase-action@master
        with:
          args: deploy --only hosting --project production
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
          
      - name: Create deployment status
        uses: chrnorm/deployment-action@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          environment: production
          state: success
          deployment_id: ${{ steps.deployment.outputs.deployment_id }}
          
  deploy-android:
    name: Deploy Android to Play Store
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'
          
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Decode signing key
        run: |
          echo "${{ secrets.ANDROID_SIGNING_KEY }}" | base64 -d > android/app/fermi-release-key.jks
          
      - name: Create key.properties
        run: |
          echo "storePassword=${{ secrets.STORE_PASSWORD }}" > android/key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
          echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> android/key.properties
          echo "storeFile=fermi-release-key.jks" >> android/key.properties
          
      - name: Build App Bundle
        run: |
          flutter build appbundle --release \
            --dart-define=ENVIRONMENT=production \
            --obfuscate \
            --split-debug-info=debug_symbols
            
      - name: Deploy to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT }}
          packageName: com.fermi.education
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: production
          status: completed
          
  deploy-ios:
    name: Deploy iOS to App Store
    runs-on: macos-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.0'
          
      - name: Import certificates
        uses: apple-actions/import-codesign-certs@v2
        with:
          p12-file-base64: ${{ secrets.IOS_CERTIFICATE_P12 }}
          p12-password: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
          
      - name: Download provisioning profile
        uses: apple-actions/download-provisioning-profiles@v1
        with:
          bundle-id: com.fermi.education
          profile-type: IOS_APP_STORE
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}
          
      - name: Build iOS
        run: |
          flutter build ios --release \
            --dart-define=ENVIRONMENT=production \
            --obfuscate \
            --split-debug-info=debug_symbols
            
      - name: Build and upload to App Store
        run: |
          cd ios
          xcodebuild -workspace Runner.xcworkspace \
            -scheme Runner \
            -configuration Release \
            -archivePath Runner.xcarchive \
            archive
            
          xcodebuild -exportArchive \
            -archivePath Runner.xcarchive \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath build/
            
          xcrun altool --upload-app \
            -f build/Runner.ipa \
            -u "${{ secrets.APPLE_ID }}" \
            -p "${{ secrets.APPLE_APP_PASSWORD }}"
```

### Integration Testing Pipeline

#### `.github/workflows/integration-tests.yml`
```yaml
name: Integration Tests
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  integration-tests-web:
    name: Web Integration Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Start Chrome
        run: |
          google-chrome --headless --disable-gpu --remote-debugging-port=9222 &
          
      - name: Run integration tests
        run: |
          flutter drive \
            --driver=test_driver/integration_test.dart \
            --target=integration_test/app_test.dart \
            -d web-server
            
  integration-tests-android:
    name: Android Integration Tests
    runs-on: macos-latest
    strategy:
      matrix:
        api-level: [28, 30, 33]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          cache: true
          
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run Android integration tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: ${{ matrix.api-level }}
          target: google_apis
          arch: x86_64
          profile: Nexus 6
          script: flutter test integration_test/
          
  integration-tests-ios:
    name: iOS Integration Tests
    runs-on: macos-latest
    strategy:
      matrix:
        device: ['iPhone 14', 'iPad Pro (12.9-inch) (6th generation)']
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          cache: true
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Start iOS Simulator
        run: |
          xcrun simctl boot "${{ matrix.device }}" || true
          
      - name: Run iOS integration tests
        run: |
          flutter test integration_test/ -d "${{ matrix.device }}"
```

## Security and Secrets Management

### Required GitHub Secrets

#### Firebase Secrets
```bash
FIREBASE_TOKEN              # Firebase CLI token
FIREBASE_API_KEY            # Firebase API key
FIREBASE_PROJECT_ID         # Firebase project ID
FIREBASE_MESSAGING_SENDER_ID # FCM sender ID
FIREBASE_APP_ID             # Firebase app ID
```

#### Android Secrets
```bash
ANDROID_SIGNING_KEY         # Base64 encoded keystore
STORE_PASSWORD             # Keystore password
KEY_PASSWORD               # Key password
KEY_ALIAS                  # Key alias
PLAY_STORE_SERVICE_ACCOUNT # Google Play service account JSON
```

#### iOS Secrets
```bash
IOS_CERTIFICATE_P12        # Base64 encoded P12 certificate
IOS_CERTIFICATE_PASSWORD   # Certificate password
APPSTORE_ISSUER_ID         # App Store Connect issuer ID
APPSTORE_KEY_ID           # App Store Connect key ID
APPSTORE_PRIVATE_KEY      # App Store Connect private key
APPLE_ID                  # Apple ID email
APPLE_APP_PASSWORD        # App-specific password
```

### Secret Management Script
```bash
#!/bin/bash
# scripts/setup-secrets.sh

# This script helps set up GitHub secrets
# Run: gh secret set SECRET_NAME < secret_file.txt

echo "Setting up GitHub secrets..."

# Firebase secrets
gh secret set FIREBASE_TOKEN --body "$FIREBASE_CLI_TOKEN"
gh secret set FIREBASE_API_KEY --body "$FIREBASE_API_KEY"

# Android secrets
base64 -i android/app/fermi-release-key.jks | gh secret set ANDROID_SIGNING_KEY
gh secret set STORE_PASSWORD --body "$STORE_PASSWORD"
gh secret set KEY_PASSWORD --body "$KEY_PASSWORD"

# iOS secrets  
base64 -i ios/certs/distribution.p12 | gh secret set IOS_CERTIFICATE_P12
gh secret set IOS_CERTIFICATE_PASSWORD --body "$CERT_PASSWORD"

echo "Secrets configured successfully!"
```

## Build Optimization

### Cache Configuration
```yaml
# Optimized caching strategy
- name: Cache Flutter dependencies
  uses: actions/cache@v3
  with:
    path: |
      ~/.pub-cache
      **/.flutter-plugins
      **/.flutter-plugins-dependencies
      **/GeneratedPluginRegistrant.swift
    key: ${{ runner.os }}-flutter-${{ hashFiles('**/pubspec.lock') }}
    restore-keys: |
      ${{ runner.os }}-flutter-

- name: Cache Gradle dependencies
  uses: actions/cache@v3
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
      android/.gradle
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
    restore-keys: |
      ${{ runner.os }}-gradle-

- name: Cache CocoaPods dependencies
  uses: actions/cache@v3
  with:
    path: |
      ios/Pods
      ios/Podfile.lock
      ~/.cocoapods
    key: ${{ runner.os }}-cocoapods-${{ hashFiles('**/Podfile.lock') }}
    restore-keys: |
      ${{ runner.os }}-cocoapods-
```

### Parallel Job Configuration
```yaml
jobs:
  build:
    strategy:
      matrix:
        platform: [web, android, ios]
        include:
          - platform: web
            os: ubuntu-latest
            build_command: flutter build web --release
          - platform: android
            os: ubuntu-latest  
            build_command: flutter build appbundle --release
          - platform: ios
            os: macos-latest
            build_command: flutter build ios --release --no-codesign
    
    runs-on: ${{ matrix.os }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Build ${{ matrix.platform }}
        run: ${{ matrix.build_command }}
```

## Monitoring and Notifications

### Slack Integration
```yaml
# Add to deployment jobs
- name: Notify Slack on success
  if: success()
  uses: 8398a7/action-slack@v3
  with:
    status: success
    text: '🚀 Deployment successful to ${{ github.ref }}'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

- name: Notify Slack on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    text: '❌ Deployment failed for ${{ github.ref }}'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Email Notifications
```yaml
- name: Send email notification
  if: always()
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 587
    username: ${{ secrets.MAIL_USERNAME }}
    password: ${{ secrets.MAIL_PASSWORD }}
    subject: 'Fermi CI/CD Pipeline - ${{ job.status }}'
    body: |
      Build Status: ${{ job.status }}
      Commit: ${{ github.sha }}
      Branch: ${{ github.ref }}
      View details: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
    to: dev-team@fermi-education.com
    from: ci-cd@fermi-education.com
```

## Performance Monitoring

### Build Time Tracking
```yaml
- name: Start build timer
  run: echo "BUILD_START=$(date +%s)" >> $GITHUB_ENV

- name: Build application
  run: flutter build web --release

- name: Calculate build time
  run: |
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))
    echo "Build completed in ${BUILD_TIME} seconds"
    echo "BUILD_TIME=${BUILD_TIME}" >> $GITHUB_ENV

- name: Report build metrics
  run: |
    curl -X POST "${{ secrets.METRICS_WEBHOOK }}" \
      -H "Content-Type: application/json" \
      -d '{
        "build_time": ${{ env.BUILD_TIME }},
        "platform": "web",
        "branch": "${{ github.ref }}",
        "commit": "${{ github.sha }}"
      }'
```

### Test Coverage Reporting
```yaml
- name: Generate coverage report
  run: flutter test --coverage

- name: Upload to Codecov
  uses: codecov/codecov-action@v3
  with:
    file: coverage/lcov.info
    flags: unittests
    name: codecov-umbrella

- name: Comment PR with coverage
  if: github.event_name == 'pull_request'
  uses: 5monkeys/cobertura-action@master
  with:
    path: coverage/lcov.info
    repo_token: ${{ secrets.GITHUB_TOKEN }}
    minimum_coverage: 80
```

## Environment Management

### Multi-Environment Deployment
```yaml
# Deploy to different environments based on branch
- name: Determine environment
  run: |
    if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
      echo "ENVIRONMENT=production" >> $GITHUB_ENV
      echo "FIREBASE_PROJECT=fermi-education" >> $GITHUB_ENV
    elif [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
      echo "ENVIRONMENT=staging" >> $GITHUB_ENV
      echo "FIREBASE_PROJECT=fermi-education-staging" >> $GITHUB_ENV
    else
      echo "ENVIRONMENT=development" >> $GITHUB_ENV
      echo "FIREBASE_PROJECT=fermi-education-dev" >> $GITHUB_ENV
    fi

- name: Deploy to ${{ env.ENVIRONMENT }}
  run: |
    firebase use ${{ env.FIREBASE_PROJECT }}
    firebase deploy --only hosting
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

## Troubleshooting

### Common CI/CD Issues
```yaml
# Debug workflow issues
- name: Debug information
  run: |
    echo "GitHub event: ${{ github.event_name }}"
    echo "GitHub ref: ${{ github.ref }}"
    echo "GitHub actor: ${{ github.actor }}"
    echo "Runner OS: ${{ runner.os }}"
    flutter doctor -v
    flutter --version
```

### Build Failure Recovery
```yaml
- name: Clean build on failure
  if: failure()
  run: |
    flutter clean
    flutter pub get
    rm -rf build/
    rm -rf .dart_tool/

- name: Retry build
  if: failure()
  run: flutter build web --release
```

[content placeholder]