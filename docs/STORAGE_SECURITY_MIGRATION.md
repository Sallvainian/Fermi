# Firebase Storage Security Migration Guide

## Overview

This guide explains how to migrate from the temporary insecure storage rules to the new secure implementation that uses custom claims for role-based access control.

## Problem Summary

- Firebase Storage rules cannot query Firestore data
- The current rules attempted to use Firestore queries (which don't work)
- A temporary allow-all rule was added to make storage functional
- This creates a security vulnerability where any authenticated user can access any file

## Solution Architecture

The new solution uses:
1. **Custom Claims** for role-based access (teacher/student)
2. **Path-based Security** for file organization
3. **File Type Validation** for upload restrictions

## Implementation Steps

### 1. Deploy the Cloud Functions

First, deploy the custom claims Cloud Functions:

```bash
cd functions
npm install
firebase deploy --only functions:setRoleClaim,functions:syncUserRole
```

### 2. Set Custom Claims for Existing Users

Run this script to set custom claims for all existing users:

```javascript
// One-time migration script (run in Firebase Admin SDK environment)
const admin = require('firebase-admin');
admin.initializeApp();

async function migrateExistingUsers() {
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  const promises = usersSnapshot.docs.map(async (doc) => {
    const userData = doc.data();
    const uid = doc.id;
    const role = userData.role;
    
    if (role && ['teacher', 'student'].includes(role)) {
      try {
        await admin.auth().setCustomUserClaims(uid, { role });
        console.log(`Set custom claim for ${uid}: role=${role}`);
      } catch (error) {
        console.error(`Failed to set claim for ${uid}:`, error);
      }
    }
  });
  
  await Promise.all(promises);
  console.log('Migration complete');
}

migrateExistingUsers();
```

### 3. Update Auth Service

Update your auth service to refresh tokens after role assignment:

```dart
// In auth_service.dart, after creating a new user and setting their role:
Future<void> refreshUserToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    // Force token refresh to get new custom claims
    await user.getIdToken(true);
  }
}
```

### 4. Deploy the New Storage Rules

Deploy the new secure storage rules:

```bash
firebase deploy --only storage
```

### 5. Update File Upload Paths

Ensure your app uses the correct storage paths:

- User profiles: `/users/{userId}/profile/{fileName}`
- Class materials: `/classes/{classId}/materials/{fileName}`
- Student submissions: `/classes/{classId}/submissions/{studentId}/{fileName}`
- Chat media: `/chat_media/{chatRoomId}/{fileName}`
- Game assets: `/games/{gameId}/{fileName}`

## Testing Checklist

After deployment, test these scenarios:

### Teacher Account:
- [ ] Can upload profile image to own profile
- [ ] Can upload class materials
- [ ] Can read student submissions
- [ ] Can upload game assets
- [ ] Can delete student submissions

### Student Account:
- [ ] Can upload profile image to own profile
- [ ] Can read class materials (with valid classId)
- [ ] Can upload own submissions
- [ ] Cannot upload to other students' folders
- [ ] Can read game assets

### Security Tests:
- [ ] Cannot access files without authentication
- [ ] Cannot upload files exceeding size limits
- [ ] Cannot upload invalid file types
- [ ] Cannot access paths not explicitly allowed

## Rollback Plan

If issues occur, you can temporarily revert to the old rules:

1. Re-add the temporary allow-all rule at the top of storage.rules
2. Deploy with `firebase deploy --only storage`
3. Fix any issues with custom claims
4. Remove the allow-all rule and redeploy

## Security Trade-offs

The new system makes these trade-offs for practicality:

1. **Class Materials**: Any authenticated user can read if they know the classId
   - Mitigation: Use unguessable classIds (already using Firestore auto-generated IDs)

2. **Chat Media**: Participants verified by knowing chatRoomId
   - Mitigation: chatRoomIds are auto-generated and unguessable

3. **No Per-File Permissions**: Cannot check Firestore for file-specific permissions
   - Mitigation: Use Cloud Functions for sensitive operations requiring complex permissions

## Future Enhancements

For additional security, consider:

1. **Signed URLs**: Generate time-limited URLs via Cloud Functions for sensitive files
2. **File Encryption**: Encrypt sensitive files at rest
3. **Access Logging**: Track file access in Firestore for audit trails
4. **Lifecycle Rules**: Auto-delete temporary files after X days

## Monitoring

Set up Firebase alerts for:
- Unusual storage bandwidth usage
- Failed authentication attempts
- Storage quota approaching limits

## Support

If you encounter issues:
1. Check Firebase Console > Storage for specific error messages
2. Verify custom claims are set: Check Authentication > Users > Custom Claims
3. Test with Storage emulator first: `firebase emulators:start --only storage`