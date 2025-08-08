@echo off
REM GitHub Secrets Setup Script for Teacher Dashboard Flutter Firebase (Windows)
REM Run this script to set up all required secrets for GitHub Actions

echo 🔧 Setting up GitHub Secrets for Teacher Dashboard Flutter Firebase
echo ==================================================

REM Check if GitHub CLI is installed
where gh >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ GitHub CLI is not installed. Please install it first:
    echo    https://cli.github.com/
    exit /b 1
)

REM Check if user is authenticated with GitHub CLI
gh auth status >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Please authenticate with GitHub CLI first:
    echo    gh auth login
    exit /b 1
)

echo ✅ GitHub CLI is ready

REM Check if .env file exists
if not exist ".env" (
    echo ❌ .env file not found. Please ensure you're in the project root directory.
    exit /b 1
)

echo 📖 Reading configuration from .env file...

REM Read .env file and set GitHub secrets
for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
    if "%%A"=="FIREBASE_API_KEY" (
        echo Setting secret: FIREBASE_API_KEY
        gh secret set "FIREBASE_API_KEY" --body "%%B"
    )
    if "%%A"=="FIREBASE_PROJECT_ID" (
        echo Setting secret: FIREBASE_PROJECT_ID
        gh secret set "FIREBASE_PROJECT_ID" --body "%%B"
    )
    if "%%A"=="FIREBASE_MESSAGING_SENDER_ID" (
        echo Setting secret: FIREBASE_MESSAGING_SENDER_ID
        gh secret set "FIREBASE_MESSAGING_SENDER_ID" --body "%%B"
    )
    if "%%A"=="FIREBASE_STORAGE_BUCKET" (
        echo Setting secret: FIREBASE_STORAGE_BUCKET
        gh secret set "FIREBASE_STORAGE_BUCKET" --body "%%B"
    )
    if "%%A"=="FIREBASE_AUTH_DOMAIN" (
        echo Setting secret: FIREBASE_AUTH_DOMAIN
        gh secret set "FIREBASE_AUTH_DOMAIN" --body "%%B"
    )
    if "%%A"=="FIREBASE_APP_ID_WEB" (
        echo Setting secret: FIREBASE_APP_ID_WEB
        gh secret set "FIREBASE_APP_ID_WEB" --body "%%B"
    )
    if "%%A"=="FIREBASE_APP_ID_ANDROID" (
        echo Setting secret: FIREBASE_APP_ID_ANDROID
        gh secret set "FIREBASE_APP_ID_ANDROID" --body "%%B"
    )
    if "%%A"=="FIREBASE_APP_ID_IOS" (
        echo Setting secret: FIREBASE_APP_ID_IOS
        gh secret set "FIREBASE_APP_ID_IOS" --body "%%B"
    )
    if "%%A"=="IOS_BUNDLE_ID" (
        echo Setting secret: IOS_BUNDLE_ID
        gh secret set "IOS_BUNDLE_ID" --body "%%B"
    )
    if "%%A"=="GOOGLE_CLOUD_PROJECT" (
        echo Setting secret: GOOGLE_CLOUD_PROJECT
        gh secret set "GOOGLE_CLOUD_PROJECT" --body "%%B"
    )
    if "%%A"=="FIREBASE_VAPID_KEY" (
        echo Setting secret: FIREBASE_VAPID_KEY
        gh secret set "FIREBASE_VAPID_KEY" --body "%%B"
    )
)

echo.
echo 🚨 IMPORTANT: You need to manually set the FIREBASE_TOKEN secret
echo Run the following command to generate a Firebase CI token:
echo    firebase login:ci
echo.
echo Then set it as a GitHub secret:
echo    gh secret set FIREBASE_TOKEN --body "your-generated-token"
echo.

echo ✅ Basic secrets setup complete!
echo.
echo 📋 Next steps:
echo 1. Generate Firebase CI token (see above)
echo 2. Commit and push your changes to test the workflows
echo 3. Check GitHub Actions tab for build status
echo 4. For production: Set up Android signing keys (see .github/ENVIRONMENT_SETUP.md)
echo.
echo 🔍 To verify secrets are set correctly:
echo    gh secret list

pause