# TODO API Troubleshooting Guide
# Firebase Integration Issues & Solutions

## Current Issues & Solutions

### 1. Authentication State Not Persisting
**Problem**: User gets logged out on app restart
**Solution**:
```dart
// In main.dart
await Firebase.initializeApp();
// Check auth state
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // Route to dashboard
} else {
  // Route to login
}
```

### 2. Role-Based Routing Failing
**Problem**: Teacher/Student routing not working correctly
**Solution**:
```dart
// Get custom claims
final idTokenResult = await user.getIdTokenResult();
final role = idTokenResult.claims?['role'];

// Route based on role
if (role == 'teacher') {
  context.go('/teacher/dashboard');
} else if (role == 'student') {
  context.go('/student/dashboard');
}
```

### 3. Firestore Permission Denied
**Problem**: Read/Write operations failing
**Solution**:
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read their data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Teachers can manage students
    match /students/{studentId} {
      allow read, write: if request.auth != null && 
        request.auth.token.role == 'teacher';
    }
  }
}
```

### 4. Storage Upload Failing
**Problem**: File uploads not working
**Solution**:
```dart
// Proper storage reference
final ref = FirebaseStorage.instance
    .ref()
    .child('users/${user.uid}/uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName');

// Upload with metadata
final metadata = SettableMetadata(
  contentType: 'image/jpeg',
  customMetadata: {'userId': user.uid},
);

await ref.putFile(file, metadata);
```

### 5. Cloud Functions Not Deploying
**Problem**: Functions deployment fails
**Solution**:
```bash
# Check Node version
node --version  # Should be 18 or 20

# Clean and reinstall
cd functions
rm -rf node_modules package-lock.json
npm install
npm run build
firebase deploy --only functions
```

### 6. Real-time Updates Not Working
**Problem**: Firestore listeners not triggering
**Solution**:
```dart
// Proper listener setup
StreamSubscription? subscription;

subscription = FirebaseFirestore.instance
    .collection('assignments')
    .where('classId', isEqualTo: classId)
    .orderBy('dueDate')
    .snapshots()
    .listen((snapshot) {
      // Handle updates
    }, onError: (error) {
      print('Error: $error');
    });

// Don't forget to cancel
@override
void dispose() {
  subscription?.cancel();
  super.dispose();
}
```

### 7. Custom Claims Not Updating
**Problem**: Role changes not reflecting
**Solution**:
```javascript
// Cloud Function to set claims
exports.setUserRole = functions.https.onCall(async (data, context) => {
  // Check admin privileges
  if (!context.auth?.token?.admin) {
    throw new functions.https.HttpsError('permission-denied');
  }

  const {userId, role} = data;
  await admin.auth().setCustomUserClaims(userId, {role});
  
  // Force token refresh
  await admin.firestore().collection('users').doc(userId).update({
    forceTokenRefresh: Date.now()
  });
  
  return {success: true};
});
```

```dart
// Client-side force refresh
await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

### 8. Offline Persistence Issues
**Problem**: App crashes when offline
**Solution**:
```dart
// Enable offline persistence
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);

// Handle offline states
StreamBuilder(
  stream: Connectivity().onConnectivityChanged,
  builder: (context, snapshot) {
    if (snapshot.data == ConnectivityResult.none) {
      return OfflineIndicator();
    }
    return OnlineContent();
  },
);
```

### 9. Transaction Failures
**Problem**: Concurrent updates causing conflicts
**Solution**:
```dart
// Use transactions for atomic updates
await FirebaseFirestore.instance.runTransaction((transaction) async {
  final doc = await transaction.get(docRef);
  if (!doc.exists) {
    throw Exception('Document does not exist');
  }
  
  final newValue = doc.data()!['count'] + 1;
  transaction.update(docRef, {'count': newValue});
});
```

### 10. Query Performance Issues
**Problem**: Slow query responses
**Solution**:
```dart
// Create composite indexes in Firebase Console
// Use query cursors for pagination
Query query = FirebaseFirestore.instance
    .collection('students')
    .orderBy('name')
    .limit(20);

// For next page
query = query.startAfterDocument(lastDocument);
```

## Common Error Codes

### Auth Errors
- `auth/user-not-found` - Email doesn't exist
- `auth/wrong-password` - Incorrect password
- `auth/email-already-in-use` - Registration with existing email
- `auth/weak-password` - Password too simple
- `auth/network-request-failed` - Network connectivity issue

### Firestore Errors
- `permission-denied` - Security rules blocking
- `not-found` - Document doesn't exist
- `already-exists` - Document ID collision
- `resource-exhausted` - Quota exceeded
- `deadline-exceeded` - Operation timeout

### Storage Errors
- `storage/unauthorized` - User not authenticated
- `storage/quota-exceeded` - Storage limit reached
- `storage/invalid-checksum` - Upload corrupted
- `storage/canceled` - User canceled upload

## Debug Commands

```bash
# Check Firebase project
firebase projects:list
firebase use PROJECT_ID

# Test Firestore rules
firebase emulators:start --only firestore
npm test  # Run rules tests

# View function logs
firebase functions:log --only functionName

# Check deployment status
firebase deploy --only hosting --debug
```

## Testing Checklist

- [ ] Auth flow works on all platforms
- [ ] Roles are properly assigned
- [ ] Firestore read/write permissions correct
- [ ] File uploads work for all file types
- [ ] Offline mode handles gracefully
- [ ] Real-time updates trigger properly
- [ ] Error messages are user-friendly
- [ ] Loading states show appropriately
- [ ] Transactions handle conflicts
- [ ] Queries are optimized with indexes

## Performance Monitoring

```dart
// Add performance traces
final Trace trace = FirebasePerformance.instance.newTrace('load_students');
await trace.start();

// Your operation
final students = await loadStudents();

// Add metrics
trace.setMetric('student_count', students.length);
await trace.stop();
```

## Useful Resources

- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Cloud Functions Best Practices](https://firebase.google.com/docs/functions/bestpractices)
- [Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon)