# 🚀 Simple Setup Guide

## Local Development (Android Studio)

1. **Open in Android Studio**
   - File → Open → Select this project folder
   - Wait for Gradle sync to complete

2. **Run the app**
   - Select your Android device/emulator
   - Click the green Run button (or press Shift+F10)
   - That's it!

## Deployment (GitHub Actions)

### One-time setup:
1. Push your code to GitHub
2. Go to Settings → Secrets → Actions
3. Add these 2 secrets:
   - `FIREBASE_PROJECT_ID`: Your Firebase project ID
   - `FIREBASE_SERVICE_ACCOUNT`: Your service account JSON (get it from Firebase Console → Project Settings → Service Accounts → Generate New Private Key)

### Deploy:
- Push to `main` branch → Automatically deploys to web and builds Android APK
- Or go to Actions tab → Click "Simple Deploy" → Run workflow

### Download Android APK:
- Go to Actions tab → Click latest workflow run → Download "app-release" artifact

## That's all! 

No complex configuration needed. The app just works.

### If you need to change something:
- Android settings: `android/app/build.gradle`
- CI/CD: `.github/workflows/simple-deploy.yml`
- Memory for builds: `android/gradle.properties`