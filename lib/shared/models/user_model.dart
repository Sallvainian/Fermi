/// User roles supported by the application.
///
/// This enumeration defines the high‑level roles that a user can have
/// within the Teacher Dashboard. It is used throughout the routing and
/// authorization logic to determine which dashboard and features should
/// be available to a user.
enum UserRole { teacher, student, admin }

/// Data model representing an authenticated user.
///
/// In the full application this model would mirror the user document
/// stored in Firestore and include many more properties. For the
/// purposes of routing and basic UI display, we include only the
/// commonly accessed fields. Additional fields can be added as needed
/// without breaking existing code.
class UserModel {
  /// Unique identifier for the user.
  final String uid;

  /// User's email address.
  final String? email;

  /// Display name as shown in the UI. May be null if the user has not
  /// chosen a display name.
  final String? displayName;

  /// User's first name.
  final String? firstName;

  /// User's last name.
  final String? lastName;

  /// URL to the user's profile picture.
  final String? photoURL;

  /// Username for login (unique identifier for username/password auth)
  final String? username;

  /// Parent's email, for student accounts.
  final String? parentEmail;

  /// Associated teacher ID, for student accounts.
  final String? teacherId;

  /// Associated student ID, for teacher accounts or when referencing a student.
  final String? studentId;

  /// Grade level of the student.
  final String? gradeLevel;

  /// List of class IDs the student is enrolled in.
  final List<String>? enrolledClassIds;

  /// Timestamp when the user was created.
  final DateTime? createdAt;

  /// Timestamp when the user was last active.
  final DateTime? lastActive;

  /// The role assigned to the user.
  final UserRole? role;

  /// Whether the user needs to reset their password (for new teacher accounts).
  final bool? needsPasswordReset;

  /// The real email address for notifications (different from synthetic email).
  final String? realEmail;

  /// Whether the user has linked a real email address.
  final bool? hasLinkedEmail;

  /// Constructs a new [UserModel]. All fields other than [uid] are optional.
  const UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    this.photoURL,
    this.username,
    this.parentEmail,
    this.teacherId,
    this.studentId,
    this.gradeLevel,
    this.enrolledClassIds,
    this.createdAt,
    this.lastActive,
    this.role,
    this.needsPasswordReset,
    this.realEmail,
    this.hasLinkedEmail,
  });

  /// Creates a new [UserModel] from Firestore data or snapshot.
  ///
  /// Accepts either a `Map<String, dynamic>`, a `DocumentSnapshot`, or a
  /// `QueryDocumentSnapshot`. When a snapshot is provided, the method
  /// extracts the underlying data map via `.data()` and falls back to
  /// the document `id` when `uid` is not present.
  factory UserModel.fromFirestore(dynamic dataOrSnapshot) {
    Map<String, dynamic> data = const {};
    String? docId;

    // Attempt to handle different input types without importing Firestore
    // types explicitly. This keeps the model usable in pure Dart contexts.
    if (dataOrSnapshot is Map<String, dynamic>) {
      data = dataOrSnapshot;
    } else {
      try {
        final dynamic snapshot = dataOrSnapshot;
        final dynamic raw = snapshot.data();
        if (raw is Map<String, dynamic>) {
          data = raw;
        }
        // Try to read `id` property from snapshot for uid fallback
        final dynamic maybeId = snapshot.id;
        if (maybeId is String && maybeId.isNotEmpty) {
          docId = maybeId;
        }
      } catch (_) {
        // Ignore and use empty map
      }
    }

    String? asString(dynamic v) => v is String ? v : null;

    return UserModel(
      uid: asString(data['uid']) ?? docId ?? '',
      email: asString(data['email']),
      displayName: asString(data['displayName']),
      firstName: asString(data['firstName']),
      lastName: asString(data['lastName']),
      photoURL: asString(data['photoURL']) ?? asString(data['photoUrl']),
      username: asString(data['username']),
      parentEmail: asString(data['parentEmail']),
      teacherId: asString(data['teacherId']),
      studentId: asString(data['studentId']),
      gradeLevel: asString(data['gradeLevel']),
      enrolledClassIds: (data['enrolledClassIds'] as List?)?.cast<String>(),
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime?
          : null,
      lastActive: data['lastActive'] is DateTime
          ? data['lastActive'] as DateTime?
          : null,
      role: _roleFromString(asString(data['role'])),
      needsPasswordReset: data['needsPasswordReset'] is bool
          ? data['needsPasswordReset'] as bool?
          : null,
      realEmail: asString(data['realEmail']),
      hasLinkedEmail: data['hasLinkedEmail'] is bool
          ? data['hasLinkedEmail'] as bool?
          : null,
    );
  }

  /// Converts this user into a map suitable for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (photoURL != null) 'photoURL': photoURL,
      if (needsPasswordReset != null) 'needsPasswordReset': needsPasswordReset,
      if (username != null) 'username': username,
      if (parentEmail != null) 'parentEmail': parentEmail,
      if (teacherId != null) 'teacherId': teacherId,
      if (studentId != null) 'studentId': studentId,
      if (gradeLevel != null) 'gradeLevel': gradeLevel,
      if (enrolledClassIds != null) 'enrolledClassIds': enrolledClassIds,
      if (createdAt != null) 'createdAt': createdAt,
      if (lastActive != null) 'lastActive': lastActive,
      if (role != null) 'role': role.toString().split('.').last,
      if (realEmail != null) 'realEmail': realEmail,
      if (hasLinkedEmail != null) 'hasLinkedEmail': hasLinkedEmail,
    };
  }

  /// Creates a copy of this user with the given fields replaced by new values.
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoURL,
    String? username,
    String? parentEmail,
    String? teacherId,
    String? studentId,
    String? gradeLevel,
    List<String>? enrolledClassIds,
    DateTime? createdAt,
    DateTime? lastActive,
    UserRole? role,
    bool? needsPasswordReset,
    String? realEmail,
    bool? hasLinkedEmail,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoURL: photoURL ?? this.photoURL,
      username: username ?? this.username,
      parentEmail: parentEmail ?? this.parentEmail,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      enrolledClassIds: enrolledClassIds ?? this.enrolledClassIds,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      role: role ?? this.role,
      needsPasswordReset: needsPasswordReset ?? this.needsPasswordReset,
      realEmail: realEmail ?? this.realEmail,
      hasLinkedEmail: hasLinkedEmail ?? this.hasLinkedEmail,
    );
  }

  /// Convenience getter to determine if the user is a teacher.
  bool get isTeacher => role == UserRole.teacher;

  /// Convenience getter to determine if the user is a student.
  bool get isStudent => role == UserRole.student;

  /// Alias for [photoURL] to support older code that references
  /// `photoUrl` instead of `photoURL`. This simply returns [photoURL].
  String? get photoUrl => photoURL;

  /// Returns the most appropriate name to display for this user.
  ///
  /// Falls back to the email address if no display or personal name is
  /// available. If all fields are null, returns an empty string.
  String get safeDisplayName {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    final nameParts = [
      firstName,
      lastName,
    ].where((e) => e != null && e.isNotEmpty).toList();
    if (nameParts.isNotEmpty) {
      return nameParts.join(' ');
    }
    return email ?? '';
  }

  /// Backwards-compatible `name` getter used by some UI widgets.
  /// Returns [safeDisplayName].
  String get name => safeDisplayName;

  /// Helper to convert a role string into a [UserRole] enum.
  static UserRole? _roleFromString(String? role) {
    switch (role) {
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }
}

/// Extension on UserModel to provide consistent display name logic.
///
/// This extension addresses code duplication identified by Copilot PR review.
/// It provides a standardized way to get a user's display name with fallbacks.
extension UserModelDisplayName on UserModel? {
  /// Returns the most appropriate display name for the user with fallbacks.
  ///
  /// Priority order:
  /// 1. firstName + lastName (if both exist)
  /// 2. displayName (if not empty)
  /// 3. email prefix (before @)
  /// 4. 'Unknown User' as final fallback
  String get displayNameOrFallback {
    if (this == null) return 'Unknown User';

    final user = this!;

    // Prefer firstName + lastName if both exist
    if (user.firstName != null && user.lastName != null) {
      final fullName = '${user.firstName} ${user.lastName}'.trim();
      if (fullName.isNotEmpty) return fullName;
    }

    // Fall back to displayName
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }

    // Fall back to email prefix
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }

    return 'Unknown User';
  }
}
