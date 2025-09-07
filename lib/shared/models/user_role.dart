/// User role enumeration for type-safe role handling throughout the app
enum UserRole {
  student,
  teacher,
  admin, // For future use
}

/// Extension methods for UserRole
extension UserRoleExtension on UserRole {
  /// Get the string representation for database storage
  String get value {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.admin:
        return 'admin';
    }
  }

  /// Create UserRole from string
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'teacher':
        return UserRole.teacher;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student; // Default fallback
    }
  }
}