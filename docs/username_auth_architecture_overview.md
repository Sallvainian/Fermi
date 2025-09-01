# 🔧 Architecture Overview – Username-Based Login with Firebase Auth

## 🔐 Overview

We will continue using **Firebase Auth** for password management while implementing a **username-based login** system. This approach uses synthetic emails behind the scenes to work with Firebase's email/password authentication.

---

## 🧱 Key Components

### 1. Database Schema Updates
- Add `username` field to `users` collection in Firestore.
- Implement **username uniqueness** validation.
- Maintain existing `uid` structure for compatibility.

### 2. Authentication Flow
- Convert `username` → **synthetic email** (e.g., `jsmith01@fermi.local`).
- Use Firebase Auth’s **email/password** authentication.
- Store actual username in Firestore for display and user management.

---

## 🛠 Implementation Tasks

### Phase 1: Core Authentication Changes

#### 1. Update `UserModel`  
Location: `lib/shared/models/user_model.dart`
- Add `username` field.
- Update `fromFirestore` and `toFirestore` methods.

#### 2. Create Username Authentication Service  
Location: `lib/features/auth/data/services/username_auth_service.dart`
- Validate username format and uniqueness.
- Handle username → email conversion.
- Support account creation using `username/password`.

#### 3. Update AuthProvider  
Location: `lib/features/auth/providers/auth_provider.dart`
- Add `signInWithUsername()` method.
- Add `createStudentAccount()` for teachers.
- Update user loading logic to include `username`.

#### 4. Update AuthService  
Location: `lib/features/auth/data/services/auth_service.dart`
- Add username-based auth methods.
- Implement synthetic email generation logic.

---

### Phase 2: UI Updates

#### 5. Modify Login Screen  
Location: `lib/features/auth/presentation/screens/login_screen.dart`
- Replace email input with **username** input.
- Remove Google/Apple sign-in buttons.
- Add username validation logic.
- Implement **role-based login** (teacher vs. student).

#### 6. Create Student Account Management Screen  
Location: `lib/features/teacher/presentation/screens/manage_student_accounts_screen.dart`
- Interface for teachers to create/edit student accounts.
- Bulk import capability.
- Support for password resets.

---

### Phase 3: Data Migration & Security

#### 7. Update Existing Users
- Add `username` field to existing teacher accounts.
- Generate and assign usernames to student accounts.
- Update Firestore security rules accordingly.

#### 8. Update Firestore Security Rules
- Enforce **unique usernames**.
- Restrict **student account creation** to teachers only.
- Prevent unauthorized changes to `username`.

---

## 👥 Initial Test Accounts

Once implemented:
- **Teacher:**  
  - `username`: `teacher1`  
  - `password`: _[provided by you]_
- **Student:**  
  - `username`: `student1`  
  - `password`: _[provided by you]_

---

## 🔢 Technical Details

### Username Format
- Pattern: `first initial + last name + number` (e.g., `jsmith01`)
- All lowercase, no special characters
- Must be **globally unique**

### Password Requirements
- Minimum 6 characters (Firebase constraint)
- Set by teachers for student accounts
- Resettable at any time by the teacher

### Synthetic Email Generation
```dart
String generateSyntheticEmail(String username) {
  return '${username.toLowerCase()}@fermi.local';
}
```

---

## ✅ Benefits

1. **Simplified Student Login** – No email needed for students.
2. **Teacher Control** – Full oversight of student credentials.
3. **Security** – Passwords remain managed by Firebase Auth.
4. **Compatibility** – No disruption to existing Firebase-based features.

---

## 📋 Next Steps

1. Implement core authentication logic  
2. Update the login and management UI  
3. Build out the teacher-facing management interface  
4. Test using initial accounts  
5. Prepare a list of usernames/passwords for student account creation