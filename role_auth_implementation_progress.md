# Role-Based Authentication Implementation Progress

## Objective
Develop a Role-Based Authentication and Account Setup Flow with teacher account creation and post-signup setup.

## Requirements
1. **Unified Authentication Screen** ✅ 
   - Modified `/lib/features/auth/presentation/screens/login_screen.dart`
   - Detects `?role=teacher` query parameter
   - Shows tabbed interface for teacher login/signup
   - Visual differentiation between teacher and student views

2. **Role-Specific User Experience** ✅
   - Teachers see "Teacher Portal" with secondary color theme
   - Students see "Student Login" with primary color theme
   - Teachers get "Sign In" and "Create Account" tabs
   - Students only get login option

3. **Post-Signup Account Setup** 🚧 IN PROGRESS
   - Password Reset Screen - NOT CREATED YET
   - Email Linking Screen - NOT CREATED YET
   - Both need to update Firebase Auth and Firestore

4. **Standardized Email Prompt** 📝 PENDING
   - Message: "Are you sure you don't want to link an email? Linking an email enables email notifications and enhanced account security as well as the ability to recover your password or username if you lose it. You can always link it later in the settings menu of your account."

## TODO List

### ✅ Completed
1. Modified login screen to detect role parameter and show teacher signup option
   - File: `/lib/features/auth/presentation/screens/login_screen.dart`
   - Added role detection via query parameter
   - Added tab interface for teachers
   - Visual differentiation implemented

### 🚧 In Progress
2. Add teacher account creation logic with username/password
   - Need to add `createTeacherAccount` method to `/lib/features/auth/providers/auth_provider.dart`
   - Need to add `needsPasswordReset` field to UserModel

### 📝 Pending
3. Create password reset screen for new teachers
   - Path: `/lib/features/auth/presentation/screens/teacher_password_reset_screen.dart`
   - Must update both Firebase Auth password and Firestore document

4. Create email linking screen with standardized prompt
   - Path: `/lib/features/auth/presentation/screens/email_linking_screen.dart`
   - Used for both new teachers and existing students without email
   - Must show the exact standardized message

5. Update routing to handle post-signup flow
   - Add routes in `/lib/shared/routing/app_router.dart`:
     - `/auth/teacher-setup/password`
     - `/auth/teacher-setup/email`
     - `/auth/student-setup/email`

6. Test the complete authentication flow

## Files Modified
1. ✅ `/lib/features/auth/presentation/screens/login_screen.dart` - COMPLETE

## Files To Modify
1. `/lib/features/auth/providers/auth_provider.dart` - Add createTeacherAccount method
2. `/lib/shared/models/user_model.dart` - Add needsPasswordReset field
3. `/lib/shared/routing/app_router.dart` - Add new routes

## Files To Create
1. `/lib/features/auth/presentation/screens/teacher_password_reset_screen.dart`
2. `/lib/features/auth/presentation/screens/email_linking_screen.dart`

## Current Status
- Login screen modifications are complete
- Currently working on adding the `createTeacherAccount` method to AuthProvider
- Need to implement the teacher account creation logic that:
  - Creates Firebase Auth user with username mapping
  - Creates Firestore user document with `needsPasswordReset: true`
  - Sets role as 'teacher'
  - Handles errors appropriately

## Next Steps After Context Reset
1. Continue adding `createTeacherAccount` method to AuthProvider (line ~500)
2. Add `needsPasswordReset` field to UserModel
3. Create the two new screens (password reset and email linking)
4. Update routing configuration
5. Test the complete flow

## Key Implementation Details

### Login Screen Implementation (COMPLETE)
- Login screen checks for `?role=teacher` query parameter in `initState()`
- Teachers get tabs for Sign In / Create Account using TabController
- Visual differences:
  - Teachers: Secondary color theme, school icon
  - Students: Primary color theme, person icon
- Form validation includes password confirmation for signup
- After successful login, routing logic:
  ```dart
  // For teachers
  if (needsPasswordReset) → '/auth/teacher-setup/password'
  else if (!hasEmail) → '/auth/teacher-setup/email'  
  else → '/dashboard'
  
  // For students
  if (!hasEmail) → '/auth/student-setup/email'
  else → '/dashboard'
  ```

### Required AuthProvider Methods (TO IMPLEMENT)
```dart
// Add around line 500 in auth_provider.dart
Future<bool> createTeacherAccount(String username, String password) async {
  // 1. Create Firebase Auth user via UsernameAuthService
  // 2. Create Firestore document with:
  //    - role: 'teacher'
  //    - needsPasswordReset: true
  //    - username: username
  //    - createdAt: DateTime.now()
  // 3. Sign in the new user
  // 4. Return success/failure
}
```

### UserModel Changes Needed
Add to `/lib/shared/models/user_model.dart`:
- Field: `final bool? needsPasswordReset;`
- Add to constructor
- Add to fromFirestore method
- Add to toFirestore method
- Add to copyWith method

### Password Reset Screen Requirements
- Must update BOTH:
  1. Firebase Auth password via `user.updatePassword(newPassword)`
  2. Firestore document: set `needsPasswordReset: false`
- Show current username (read-only)
- New password and confirm password fields
- After success → route to email linking screen

### Email Linking Screen Requirements
- Show for BOTH new teachers AND existing students without email
- Email field is OPTIONAL
- If user skips, show EXACT message:
  "Are you sure you don't want to link an email? Linking an email enables email notifications and enhanced account security as well as the ability to recover your password or username if you lose it. You can always link it later in the settings menu of your account."
- If email provided:
  1. Update Firebase Auth via `user.updateEmail(email)`
  2. Update Firestore document with email
- After completion → route to '/dashboard'

### Routing Configuration Needed
In `/lib/shared/routing/app_router.dart`, add:
```dart
GoRoute(
  path: '/auth/teacher-setup/password',
  builder: (context, state) => const TeacherPasswordResetScreen(),
),
GoRoute(
  path: '/auth/teacher-setup/email',  
  builder: (context, state) => const EmailLinkingScreen(userType: 'teacher'),
),
GoRoute(
  path: '/auth/student-setup/email',
  builder: (context, state) => const EmailLinkingScreen(userType: 'student'),
),
```

### Important Context
- Current branch: `feature/multi-role-auth-flow`
- Login screen already imports UserRole from user_model.dart
- AuthProvider uses UsernameAuthService for username-based auth
- Firebase Auth users are created with email pattern: `{username}@fermi.local`
- Teacher password for verification screen: "educator2024"