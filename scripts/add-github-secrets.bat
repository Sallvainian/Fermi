@echo off
REM Script to add GitHub secrets for Firebase deployment using GitHub CLI
REM Run this script to configure all required secrets

echo.
echo =====================================
echo 📝 Adding GitHub Secrets for PWA Deployment
echo =====================================
echo.

REM Check if gh CLI is installed
where gh >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ GitHub CLI is not installed.
    echo Please install it from: https://cli.github.com/
    pause
    exit /b 1
)

REM Check if authenticated
gh auth status >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ GitHub CLI is not authenticated.
    echo Please run: gh auth login
    pause
    exit /b 1
)

echo ✅ GitHub CLI is ready!
echo.

REM Firebase configuration values from firebase_options.dart
echo 🔐 Adding Firebase configuration secrets...
echo.

REM Add Firebase configuration secrets
gh secret set FIREBASE_API_KEY --body="AIzaSyD_nLVRdyd6ZlIyFrRGCW5IStXnM2-uUac"
echo ✅ Added FIREBASE_API_KEY

gh secret set FIREBASE_PROJECT_ID --body="teacher-dashboard-flutterfire"
echo ✅ Added FIREBASE_PROJECT_ID

gh secret set FIREBASE_MESSAGING_SENDER_ID --body="218352465432"
echo ✅ Added FIREBASE_MESSAGING_SENDER_ID

gh secret set FIREBASE_STORAGE_BUCKET --body="teacher-dashboard-flutterfire.firebasestorage.app"
echo ✅ Added FIREBASE_STORAGE_BUCKET

gh secret set FIREBASE_DATABASE_URL --body="https://teacher-dashboard-flutterfire-default-rtdb.firebaseio.com"
echo ✅ Added FIREBASE_DATABASE_URL

gh secret set FIREBASE_APP_ID_WEB --body="1:218352465432:web:6e1c0fa4f21416df38b56d"
echo ✅ Added FIREBASE_APP_ID_WEB

gh secret set FIREBASE_APP_ID_IOS --body="1:218352465432:ios:5lt4mte28dqof4ae3igmi6m8i261jh99"
echo ✅ Added FIREBASE_APP_ID_IOS

gh secret set IOS_BUNDLE_ID --body="com.teacherdashboard.teacherDashboardFlutter"
echo ✅ Added IOS_BUNDLE_ID

echo.
echo =====================================
echo ⚠️  IMPORTANT: Service Account Setup
echo =====================================
echo.
echo You need to manually add the Firebase service account:
echo.
echo 1. Go to Firebase Console:
echo    https://console.firebase.google.com/project/teacher-dashboard-flutterfire/settings/serviceaccounts/adminsdk
echo.
echo 2. Click "Generate new private key"
echo.
echo 3. Download the JSON file
echo.
echo 4. Run this command with the path to your JSON file:
echo    gh secret set FIREBASE_SERVICE_ACCOUNT_TEACHER_DASHBOARD_FLUTTERFIRE ^< path\to\your\service-account.json
echo.
echo    Example:
echo    gh secret set FIREBASE_SERVICE_ACCOUNT_TEACHER_DASHBOARD_FLUTTERFIRE ^< C:\Downloads\teacher-dashboard-firebase-adminsdk.json
echo.
echo =====================================
echo.

REM List all secrets to verify
echo 📋 Current GitHub Secrets:
echo.
gh secret list

echo.
echo =====================================
echo ✅ Basic secrets added successfully!
echo.
echo 📌 Next steps:
echo 1. Add the service account secret (see instructions above)
echo 2. Push your code to trigger deployment:
echo    git push origin main
echo 3. Check deployment at:
echo    https://github.com/Sallvainian/teacher-dashboard-flutter-firebase/actions
echo =====================================
echo.
pause