# Authentication System Technical Implementation

## Overview

The Fermi authentication system implements a comprehensive multi-provider OAuth2 solution with role-based access control, email verification, and secure session management using Firebase Auth and custom state management.

## Technical Architecture

### Core Components

#### AuthProvider State Management
- **Location**: `lib/features/auth/presentation/providers/auth_provider.dart`
- **Pattern**: Provider pattern with ChangeNotifier
- **Scope**: Application-wide authentication state
- **Dependencies**: Firebase Auth, FirebaseFirestore, GoogleSignIn, SignInWithApple

#### Authentication Flow Controller
- **Location**: `lib/shared/routing/app_router.dart`
- **Pattern**: GoRouter with authentication guards
- **Responsibility**: Route protection, redirect logic, role-based navigation

#### User Model Architecture
- **Location**: `lib/features/auth/domain/models/user_model.dart`
- **Pattern**: Immutable domain model with JSON serialization
- **Fields**: uid, email, displayName, photoURL, role, emailVerified, createdAt, lastSignIn

### Authentication Providers

#### Email/Password Authentication
```dart
// Implementation Details
class EmailPasswordAuth {
  Future<UserCredential> signInWithEmailPassword(String email, String password);
  Future<UserCredential> createUserWithEmailPassword(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
}
```

#### Google Sign-In Integration
```dart
// OAuth2 Configuration
class GoogleSignInAuth {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: 'CLIENT_ID_FROM_FIREBASE_CONFIG'
  );
  
  Future<UserCredential> signInWithGoogle();
  Future<void> signOutGoogle();
}
```

#### Apple Sign-In Integration
```dart
// iOS/macOS Specific Implementation
class AppleSignInAuth {
  Future<UserCredential> signInWithApple();
  bool get isAppleSignInAvailable;
  Future<AuthorizationCredentialAppleID> getAppleIDCredential();
}
```

## Data Flow Architecture

### Authentication State Flow
```
User Action → AuthProvider → Firebase Auth → Firestore → Route Guard → UI Update
```

### Detailed Flow Sequence
1. **User Initiates Sign-In**
   - UI captures credentials/OAuth trigger
   - AuthProvider.signIn() method called
   - Loading state set to true

2. **Firebase Authentication**
   - Provider-specific authentication method
   - Firebase Auth validates credentials
   - UserCredential returned or error thrown

3. **User Profile Creation/Update**
   - Check if user exists in Firestore `users` collection
   - Create new user document if first sign-in
   - Update lastSignIn timestamp
   - Sync profile data (displayName, photoURL)

4. **Role Assignment Flow**
   - New users redirect to `/auth/role-selection`
   - Role stored in user document
   - Available roles: 'teacher', 'student', 'admin'

5. **Email Verification Check**
   - Check Firebase Auth emailVerified status
   - Unverified users redirect to `/auth/verify-email`
   - Verified users proceed to role-based dashboard

6. **Session Management**
   - Firebase Auth handles token refresh automatically
   - AuthProvider listens to auth state changes
   - Persistent login across app restarts

## Database Schema

### Firestore Collections

#### users Collection
```typescript
interface UserDocument {
  uid: string;                    // Firebase Auth UID
  email: string;                  // Primary email address
  displayName: string | null;     // User display name
  photoURL: string | null;        // Profile photo URL
  role: 'teacher' | 'student' | 'admin';
  emailVerified: boolean;         // Email verification status
  createdAt: Timestamp;          // Account creation timestamp
  lastSignIn: Timestamp;         // Last sign-in timestamp
  provider: string[];            // Auth providers used
  fcmToken?: string;             // Push notification token
  preferences?: {
    theme: 'light' | 'dark';
    notifications: boolean;
    language: string;
  };
}
```

#### pending_users Collection
```typescript
interface PendingUserDocument {
  email: string;                 // Email awaiting verification
  role: 'teacher' | 'student';   // Selected role
  inviteCode?: string;           // Teacher invite code
  createdAt: Timestamp;          // Pending creation time
  expiresAt: Timestamp;          // Invite expiration
}
```

## API Endpoints & Methods

### AuthProvider Public Methods

#### Sign-In Methods
```dart
Future<User?> signInWithEmailPassword(String email, String password);
Future<User?> signInWithGoogle();
Future<User?> signInWithApple();
Future<User?> signInAnonymously(); // Guest access
```

#### Registration Methods
```dart
Future<User?> createUserWithEmailPassword(String email, String password);
Future<void> sendEmailVerification();
Future<void> resendEmailVerification();
```

#### Account Management
```dart
Future<void> signOut();
Future<void> deleteAccount();
Future<void> updateProfile({String? displayName, String? photoURL});
Future<void> updateEmail(String newEmail);
Future<void> updatePassword(String newPassword);
```

#### Role Management
```dart
Future<void> selectUserRole(String role);
Future<void> updateUserRole(String uid, String role); // Admin only
Future<List<String>> getAvailableRoles();
```

### Firebase Auth Event Handlers
```dart
class AuthProvider extends ChangeNotifier {
  StreamSubscription<User?>? _authStateSubscription;
  
  void _initializeAuthStateListener() {
    _authStateSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen(_handleAuthStateChange);
  }
  
  void _handleAuthStateChange(User? user) {
    if (user != null) {
      _syncUserProfile(user);
      _updatePresenceStatus(true);
    } else {
      _clearUserData();
      _updatePresenceStatus(false);
    }
    notifyListeners();
  }
}
```

## Route Guards & Navigation

### Authentication Guards
```dart
// Router Configuration
GoRouter _router = GoRouter(
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isAuthenticated;
    final needsEmailVerification = !authProvider.isEmailVerified;
    final needsRoleSelection = authProvider.user?.role == null;
    
    // Authentication redirect logic
    if (!isLoggedIn && !state.location.startsWith('/auth')) {
      return '/auth/login';
    }
    
    if (isLoggedIn && needsRoleSelection) {
      return '/auth/role-selection';
    }
    
    if (isLoggedIn && needsEmailVerification) {
      return '/auth/verify-email';
    }
    
    if (isLoggedIn && state.location.startsWith('/auth')) {
      return _getRoleBasedDashboard(authProvider.user!.role);
    }
    
    return null; // No redirect needed
  }
);
```

### Role-Based Route Protection
```dart
// Route Definitions with Role Guards
GoRoute(
  path: '/teacher',
  builder: (context, state) => const TeacherDashboard(),
  redirect: (context, state) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user?.role != 'teacher') {
      return '/unauthorized';
    }
    return null;
  }
),
```

## Security Implementation

### Firestore Security Rules
```javascript
// Authentication Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
      
      // Admin can read/write any user profile
      allow read, write: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Pending users - temporary access
    match /pending_users/{email} {
      allow read, write: if request.auth != null 
        && request.auth.token.email == email;
      
      // Cleanup expired pending users
      allow delete: if request.auth != null 
        && request.time > resource.data.expiresAt;
    }
  }
}
```

### Input Validation
```dart
class AuthValidation {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }
  
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      return 'Password must contain uppercase, lowercase, and number';
    }
    return null;
  }
}
```

## Error Handling

### Firebase Auth Exceptions
```dart
class AuthErrorHandler {
  static String handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
```

### Global Error Handling
```dart
// AuthProvider Error Management
class AuthProvider extends ChangeNotifier {
  String? _errorMessage;
  bool _isLoading = false;
  
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  
  Future<T?> _executeWithErrorHandling<T>(Future<T> operation) async {
    try {
      _setLoading(true);
      _clearError();
      return await operation;
    } on FirebaseAuthException catch (e) {
      _setError(AuthErrorHandler.handleAuthException(e));
      return null;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      return null;
    } finally {
      _setLoading(false);
    }
  }
}
```

## Platform-Specific Implementation

### Web Platform Configuration
```dart
// Firebase Web Configuration
const firebaseConfig = {
  apiKey: "API_KEY",
  authDomain: "PROJECT_ID.firebaseapp.com",
  projectId: "PROJECT_ID",
  storageBucket: "PROJECT_ID.appspot.com",
  messagingSenderId: "SENDER_ID",
  appId: "APP_ID"
};
```

### iOS Platform Configuration
```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>REVERSED_CLIENT_ID</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### Android Platform Configuration
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="APP_ID"/>
```

### Windows Platform Configuration
```dart
// Windows OAuth2 Flow
class WindowsAuthProvider {
  Future<UserCredential> signInWithOAuth() async {
    final provider = OAuthProvider("google.com");
    return await FirebaseAuth.instance.signInWithPopup(provider);
  }
}
```

## Testing Strategies

### Unit Testing Framework
```dart
// Test Structure
group('AuthProvider Tests', () {
  late AuthProvider authProvider;
  late MockFirebaseAuth mockAuth;
  late MockFirestore mockFirestore;
  
  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestore();
    authProvider = AuthProvider(
      firebaseAuth: mockAuth,
      firestore: mockFirestore,
    );
  });
  
  testWidgets('should sign in with email and password', (tester) async {
    // Test implementation
    when(mockAuth.signInWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123'
    )).thenAnswer((_) async => mockUserCredential);
    
    final result = await authProvider.signInWithEmailPassword(
      'test@example.com', 
      'password123'
    );
    
    expect(result, isNotNull);
    expect(authProvider.isAuthenticated, isTrue);
  });
});
```

### Integration Testing
```dart
// Authentication Flow Integration Tests
void main() {
  group('Authentication Integration Tests', () {
    testWidgets('complete sign-in flow', (tester) async {
      await tester.pumpWidget(MyApp());
      
      // Navigate to login screen
      await tester.tap(find.byKey(Key('login_button')));
      await tester.pumpAndSettle();
      
      // Enter credentials
      await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(Key('password_field')), 'password123');
      
      // Submit form
      await tester.tap(find.byKey(Key('submit_button')));
      await tester.pumpAndSettle();
      
      // Verify navigation to dashboard
      expect(find.byType(TeacherDashboard), findsOneWidget);
    });
  });
}
```

## Performance Optimizations

### State Management Optimizations
```dart
// Optimized Provider with Selectors
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  // Selective rebuilds with Consumer
  bool get isAuthenticated => _user != null;
  bool get isEmailVerified => _user?.emailVerified ?? false;
  String? get userRole => _user?.role;
  
  // Prevent unnecessary rebuilds
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is AuthProvider &&
    runtimeType == other.runtimeType &&
    _user?.uid == other._user?.uid &&
    _isLoading == other._isLoading;
}
```

### Lazy Loading Authentication
```dart
// Lazy initialization of auth providers
class AuthService {
  GoogleSignIn? _googleSignIn;
  
  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: ['email', 'profile'],
    );
    return _googleSignIn!;
  }
}
```

## Monitoring and Analytics

### Authentication Events Tracking
```dart
class AuthAnalytics {
  static void trackSignInAttempt(String method) {
    FirebaseAnalytics.instance.logEvent(
      name: 'sign_in_attempt',
      parameters: {'method': method}
    );
  }
  
  static void trackSignInSuccess(String method, String role) {
    FirebaseAnalytics.instance.logEvent(
      name: 'sign_in_success',
      parameters: {
        'method': method,
        'user_role': role,
      }
    );
  }
  
  static void trackAuthError(String method, String error) {
    FirebaseAnalytics.instance.logEvent(
      name: 'auth_error',
      parameters: {
        'method': method,
        'error_code': error,
      }
    );
  }
}
```

### User Session Tracking
```dart
// Session management with analytics
class SessionManager {
  static Timer? _sessionTimer;
  
  static void startSession(String userId) {
    FirebaseAnalytics.instance.logEvent(
      name: 'session_start',
      parameters: {'user_id': userId}
    );
    
    _sessionTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _updateSessionDuration();
    });
  }
  
  static void endSession() {
    _sessionTimer?.cancel();
    FirebaseAnalytics.instance.logEvent(name: 'session_end');
  }
}
```

## Deployment Considerations

### Environment Configuration
```dart
// Environment-specific configuration
class AuthConfig {
  static const String googleClientIdDev = 'DEV_CLIENT_ID';
  static const String googleClientIdProd = 'PROD_CLIENT_ID';
  
  static String get googleClientId {
    return kDebugMode ? googleClientIdDev : googleClientIdProd;
  }
}
```

### Build Configuration
```yaml
# pubspec.yaml dependencies
dependencies:
  firebase_auth: ^4.15.3
  google_sign_in: ^6.1.6
  sign_in_with_apple: ^5.0.0
  provider: ^6.1.1
  go_router: ^16.1.0
```

This authentication system provides a robust, scalable, and secure foundation for the Fermi education platform, supporting multiple authentication providers while maintaining clean architecture principles and comprehensive error handling.