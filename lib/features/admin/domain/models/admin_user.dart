class AdminUser {
  final String id;
  final String email;
  final String displayName;
  final String role;
  final DateTime createdAt;
  final DateTime? lastActive;
  final bool isOnline;

  AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.lastActive,
    this.isOnline = false,
  });

  String get roleDisplay {
    switch (role) {
      case 'student':
        return 'Student';
      case 'teacher':
        return 'Teacher';
      case 'admin':
        return 'Firebase Administrator';
      default:
        return role;
    }
  }

  String get statusDisplay => isOnline ? 'Online' : 'Offline';
}