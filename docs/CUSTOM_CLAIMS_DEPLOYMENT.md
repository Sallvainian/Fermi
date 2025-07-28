# Custom Claims Deployment Guide

This guide explains how to deploy the Cloud Functions for custom claims and migrate existing users.

## Overview

We've migrated from Firestore-based role checking in Storage rules to using Firebase Auth custom claims. This change was necessary because Firebase Storage rules cannot query Firestore data.

## Deployment Steps

### 1. Deploy Cloud Functions

Due to Git Bash limitations on Windows, use **Windows Command Prompt** or **PowerShell**:

```cmd
cd functions
firebase deploy --only functions
```

This will deploy two functions to the **us-east4** region:
- `setRoleClaim` - HTTP callable function to set user role custom claims
- `syncUserRole` - Firestore trigger to automatically sync role changes

### 2. Verify Deployment

Check that functions are deployed:
```cmd
firebase functions:list
```

You should see the two new functions listed in the us-east4 region.

### 3. Migrate Existing Users

#### Option A: Cloud Function Migration (Recommended)

The migration is now implemented as a Cloud Function to avoid local authentication issues.

1. First, deploy the updated functions with the migration function:
```cmd
cd C:\Users\frank\Projects\teacher-dashboard-flutter-firebase
deploy-functions.cmd
```

2. In your Flutter app, sign in as a **teacher** user

3. Run the migration from within your app. You can temporarily add a button that calls:
```dart
import 'package:your_app/shared/utils/run_migration.dart';

// In your widget (e.g., settings screen)
ElevatedButton(
  onPressed: () => runUserRoleMigration(context),
  child: const Text('Run User Migration'),
)
```

4. After successful migration, remove:
   - The migration button from your UI
   - The `migrateAllUserRoles` function from `functions/src/migrate-user-roles-cloud.ts`
   - The export from `functions/src/index.ts`
   - The `run_migration.dart` utility file

#### Option B: Local Script (Requires Service Account)

If you need to run locally, you'll need to:
1. Download a service account key from Firebase Console
2. Set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable
3. Run `npm run migrate:roles`

This is more complex and not recommended.

### 4. Test the Implementation

1. **For new users**: The `syncUserRole` function will automatically set custom claims when a user document is created in Firestore
2. **For role changes**: Custom claims will be updated automatically when the role field changes in Firestore
3. **Manual role setting**: Use the `setRoleClaim` function from your Flutter app (see `lib/shared/utils/set_user_role_claims.dart`)

## Troubleshooting

### IAM Permission Errors

If you encounter IAM permission errors during deployment, you need to grant the required roles. This is common with Firebase Functions v2.

#### Option 1: Using gcloud CLI

Run these commands in Command Prompt or PowerShell:

```cmd
gcloud projects add-iam-policy-binding teacher-dashboard-flutterfire --member=serviceAccount:service-218352465432@gcp-sa-pubsub.iam.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator

gcloud projects add-iam-policy-binding teacher-dashboard-flutterfire --member=serviceAccount:218352465432-compute@developer.gserviceaccount.com --role=roles/run.invoker

gcloud projects add-iam-policy-binding teacher-dashboard-flutterfire --member=serviceAccount:218352465432-compute@developer.gserviceaccount.com --role=roles/eventarc.eventReceiver
```

#### Option 2: Using Firebase Console

1. Go to the [Google Cloud Console](https://console.cloud.google.com)
2. Select your project: `teacher-dashboard-flutterfire`
3. Navigate to **IAM & Admin** > **IAM**
4. Click **Add** at the top
5. Add the following bindings:
   - Member: `service-218352465432@gcp-sa-pubsub.iam.gserviceaccount.com`
     - Role: `Service Account Token Creator`
   - Member: `218352465432-compute@developer.gserviceaccount.com`
     - Roles: `Cloud Run Invoker` and `Eventarc Event Receiver`
6. Click **Save**

After granting these permissions, wait 1-2 minutes and run the deployment again:
```cmd
cd C:\Users\frank\Projects\teacher-dashboard-flutter-firebase
deploy-functions.cmd
```

### Windows Deployment Issues

If you encounter the error `/usr/bin/bash: Files\Git\bin\bash.exe: No such file or directory`:
- Use Windows Command Prompt (cmd) instead of Git Bash
- Or use PowerShell
- Or deploy from WSL (Windows Subsystem for Linux)

### Migration Errors

If the migration script reports errors:
1. Check that the functions are deployed successfully
2. Ensure you have the correct Firebase Admin permissions
3. Review the error messages - common issues include:
   - User not found in Auth (user exists in Firestore but not in Firebase Auth)
   - Invalid role values (should be 'teacher' or 'student')

### Storage Access Issues

After migration, if users still can't access storage:
1. Ensure the user has refreshed their auth token (sign out and back in)
2. Check that the custom claim was set correctly using Firebase Console > Authentication > User
3. Verify the storage rules are deployed correctly

## Storage Rules Reference

The new storage rules use custom claims:
```javascript
function isTeacher() {
  return request.auth != null && 
    request.auth.token.role == 'teacher';
}

function isStudent() {
  return request.auth != null && 
    request.auth.token.role == 'student';
}
```

These functions replace the previous Firestore query-based approach that wasn't working.