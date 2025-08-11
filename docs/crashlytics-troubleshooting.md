# Firebase Crashlytics Troubleshooting Guide

## Why Crashlytics May Not Be Showing Data

### Common Issues and Solutions

## 1. **Debug Mode vs Release Mode** ⚠️
**Issue**: Crashlytics may not send data immediately in debug mode.

**Solution**: Build and run in release mode:
```bash
# For Android
flutter run --release

# Or build an APK
flutter build apk --release
flutter install
```

## 2. **Initial Sync Requirement** 🔄
**Issue**: Crashlytics needs a real crash to complete initial setup.

**Solution**: 
1. Navigate to `/debug/crashlytics-sync`
2. Click "Enable Collection"
3. Click "Send Test Data" first
4. If no data appears, click "FORCE REAL CRASH"
5. Restart the app after crash
6. Wait 2-5 minutes

## 3. **Collection Not Enabled** ❌
**Issue**: Crashlytics collection might be disabled.

**Solution**: The app now automatically enables collection. Check with:
```dart
FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
```

## 4. **Network/Firewall Issues** 🌐
**Issue**: Firebase endpoints might be blocked.

**Required Endpoints**:
- `firebasecrashlytics.googleapis.com`
- `firebase-settings.crashlytics.com`

## 5. **Missing or Outdated Dependencies** 📦
**Issue**: Gradle dependencies not synced.

**Solution**:
```bash
cd android
./gradlew.bat clean
./gradlew.bat build
cd ..
flutter clean
flutter pub get
```

## 6. **Google Services Not Synced** 🔧
**Issue**: google-services.json might be outdated.

**Solution**:
1. Download latest google-services.json from Firebase Console
2. Replace in `android/app/`
3. Rebuild the app

## Step-by-Step Verification Process

### 1. Check Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select `teacher-dashboard-flutterfire`
3. Navigate to **Crashlytics**
4. Look for any setup instructions or errors

### 2. Test with New Debug Screen
```dart
// Navigate to this screen in your app
context.go('/debug/crashlytics-sync');
```

This screen will:
- Check if Crashlytics is enabled
- Send test data without crashing
- Allow forcing a real crash for initial sync

### 3. Build in Release Mode
```bash
# Clean everything first
flutter clean
cd android && ./gradlew.bat clean && cd ..

# Build release APK
flutter build apk --release

# Install on device
flutter install
```

### 4. Monitor Logs
```bash
# Run with verbose logging
flutter run --release --verbose

# Check for Crashlytics initialization
# Look for: "Crashlytics is enabled"
```

### 5. Force Initial Sync
If Crashlytics still shows "Waiting for initial sync":

1. **Use the Force Sync Screen**:
   - Navigate to `/debug/crashlytics-sync`
   - Click "FORCE REAL CRASH"
   - App will close

2. **Restart and Wait**:
   - Restart the app
   - Use the app normally for 1-2 minutes
   - Check Firebase Console after 5 minutes

### 6. Check Android Studio Logcat
```
# Filter for Crashlytics logs
FirebaseCrashlytics
```

Look for:
- "Crashlytics automatic data collection ENABLED"
- "Crashlytics report upload complete"

## Expected Timeline

1. **Non-fatal errors**: May take 1-5 minutes to appear
2. **Crashes**: Usually appear within 5 minutes after app restart
3. **First-time setup**: Can take up to 15 minutes

## Verification Commands

### Check if Crashlytics Plugin is Active
```bash
cd android
./gradlew.bat :app:dependencies | grep crashlytics
```

Should show:
- `com.google.firebase:firebase-crashlytics`
- `com.google.firebase:firebase-crashlytics-gradle`

### Check Firebase Tools
```bash
firebase --version
firebase projects:list
```

## Alternative Testing Method

### Using ADB (Android Debug Bridge)
```bash
# Check if Crashlytics is initialized
adb logcat | grep Crashlytics

# Force app crash
adb shell am crash com.teacherdashboard.teacher_dashboard_flutter_firebase
```

## Still Not Working?

1. **Check Firebase Status**:
   - Visit [Firebase Status](https://status.firebase.google.com)
   - Ensure Crashlytics service is operational

2. **Verify App ID**:
   - Ensure `android/app/build.gradle.kts` has correct `applicationId`
   - Must match Firebase Console app registration

3. **Re-register App**:
   ```bash
   firebase apps:sdkconfig android 1:218352465432:android:a7d591b9db6bef6038b56d
   ```

4. **Enable in Firebase Console**:
   - Go to Firebase Console → Crashlytics
   - Click "Enable Crashlytics" if button appears

## Debug Checklist

- [ ] App built in release mode
- [ ] Crashlytics collection enabled in code
- [ ] Force crash triggered and app restarted
- [ ] Waited 5+ minutes after crash
- [ ] Network connection stable
- [ ] Firebase Console shows no errors
- [ ] google-services.json is latest version
- [ ] Crashlytics plugin added to Gradle
- [ ] No ProGuard/R8 issues (check build output)

## Contact Support

If none of the above works:
1. File a [Firebase Support ticket](https://firebase.google.com/support)
2. Include your project ID: `teacher-dashboard-flutterfire`
3. Include app ID: `1:218352465432:android:a7d591b9db6bef6038b56d`