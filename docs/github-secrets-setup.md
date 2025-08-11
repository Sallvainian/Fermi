# GitHub Secrets Setup for PWA Deployment

This guide will help you configure the necessary GitHub secrets for deploying your Flutter app as a PWA to Firebase Hosting.

## Required GitHub Secrets

### 1. Firebase Configuration Secrets

These are used to configure Firebase in your web build:

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `FIREBASE_API_KEY` | Firebase Web API Key | Firebase Console → Project Settings → General → Web App |
| `FIREBASE_PROJECT_ID` | Your Firebase project ID | Firebase Console → Project Settings → General |
| `FIREBASE_MESSAGING_SENDER_ID` | Cloud Messaging sender ID | Firebase Console → Project Settings → Cloud Messaging |
| `FIREBASE_STORAGE_BUCKET` | Storage bucket URL | Firebase Console → Storage → Copy bucket URL |
| `FIREBASE_DATABASE_URL` | Realtime Database URL | Firebase Console → Realtime Database → Copy URL |
| `FIREBASE_APP_ID_WEB` | Web app ID | Firebase Console → Project Settings → General → Web App |

### 2. Firebase Service Account (For Deployment)

| Secret Name | Description | How to Create |
|-------------|-------------|---------------|
| `FIREBASE_SERVICE_ACCOUNT_TEACHER_DASHBOARD_FLUTTERFIRE` | Service account JSON | See instructions below |

## Step-by-Step Setup

### Step 1: Get Firebase Configuration Values

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `teacher-dashboard-flutterfire`
3. Click the gear icon → Project Settings
4. Scroll to "Your apps" section
5. Find your Web app configuration
6. Copy each value from the Firebase config:

```javascript
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",           // → FIREBASE_API_KEY
  authDomain: "...",
  projectId: "YOUR_PROJECT_ID",     // → FIREBASE_PROJECT_ID
  storageBucket: "YOUR_BUCKET",     // → FIREBASE_STORAGE_BUCKET
  messagingSenderId: "YOUR_SENDER",  // → FIREBASE_MESSAGING_SENDER_ID
  appId: "YOUR_APP_ID",             // → FIREBASE_APP_ID_WEB
  measurementId: "..."
};
```

### Step 2: Create Firebase Service Account

1. In Firebase Console, go to Project Settings → Service Accounts
2. Click "Generate new private key"
3. Download the JSON file
4. **IMPORTANT**: This file contains sensitive credentials - keep it secure!

### Step 3: Add Secrets to GitHub

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret:

#### For Firebase Config (one by one):
- **Name**: `FIREBASE_API_KEY`
- **Value**: (paste the actual API key)
- Click "Add secret"

Repeat for all Firebase configuration values.

#### For Service Account:
- **Name**: `FIREBASE_SERVICE_ACCOUNT_TEACHER_DASHBOARD_FLUTTERFIRE`
- **Value**: (paste the ENTIRE JSON content from the downloaded service account file)
- Click "Add secret"

### Step 4: Verify Secrets

Run this checklist to ensure all secrets are configured:

- [ ] `FIREBASE_API_KEY`
- [ ] `FIREBASE_PROJECT_ID`
- [ ] `FIREBASE_MESSAGING_SENDER_ID`
- [ ] `FIREBASE_STORAGE_BUCKET`
- [ ] `FIREBASE_DATABASE_URL`
- [ ] `FIREBASE_APP_ID_WEB`
- [ ] `FIREBASE_SERVICE_ACCOUNT_TEACHER_DASHBOARD_FLUTTERFIRE`

### Step 5: Test Deployment

1. Push a commit to trigger the workflow:
```bash
git add .
git commit -m "test: PWA deployment"
git push origin main
```

2. Check GitHub Actions tab for deployment status

3. Visit your app at: `https://teacher-dashboard-flutterfire.web.app`

## Troubleshooting

### Error: "Missing required secret"
- Ensure all secret names match exactly (case-sensitive)
- Check for typos in secret names

### Error: "Firebase deployment failed"
- Verify service account JSON is valid
- Check that service account has necessary permissions
- Ensure Firebase Hosting is enabled in your project

### Error: "Build failed - Firebase config"
- Double-check all Firebase configuration values
- Ensure no extra spaces or quotes in secret values

## Security Best Practices

1. **Never commit secrets to code**
   - Use GitHub Secrets for CI/CD
   - Use environment variables locally

2. **Rotate service account keys periodically**
   - Generate new keys every 3-6 months
   - Delete old keys after rotation

3. **Limit service account permissions**
   - Only grant necessary permissions
   - Use separate accounts for different environments

4. **Monitor secret usage**
   - Check GitHub Actions logs regularly
   - Enable Firebase audit logs

## Local Development

For local testing, create a `.env` file (never commit this!):

```env
FIREBASE_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=teacher-dashboard-flutterfire
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_STORAGE_BUCKET=your_bucket
FIREBASE_DATABASE_URL=your_database_url
FIREBASE_APP_ID_WEB=your_app_id
```

Then build with:
```bash
flutter build web --dart-define-from-file=.env
```

## Quick Reference

### Firebase Console Links
- [Project Settings](https://console.firebase.google.com/project/teacher-dashboard-flutterfire/settings/general)
- [Service Accounts](https://console.firebase.google.com/project/teacher-dashboard-flutterfire/settings/serviceaccounts/adminsdk)
- [Hosting](https://console.firebase.google.com/project/teacher-dashboard-flutterfire/hosting)

### GitHub Repository Links
- [Secrets Settings](https://github.com/YOUR_USERNAME/teacher-dashboard-flutter-firebase/settings/secrets/actions)
- [Actions](https://github.com/YOUR_USERNAME/teacher-dashboard-flutter-firebase/actions)

## Support

If you encounter issues:
1. Check the GitHub Actions logs for detailed error messages
2. Verify all secrets are correctly set
3. Ensure Firebase project is properly configured
4. Check Firebase quota limits haven't been exceeded