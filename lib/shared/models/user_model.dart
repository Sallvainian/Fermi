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

  /// Constructs a new [UserModel]. All fields other than [uid] are optional.
  const UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    this.photoURL,
    this.parentEmail,
    this.teacherId,
    this.studentId,
    this.gradeLevel,
    this.enrolledClassIds,
    this.createdAt,
    this.lastActive,
    this.role,
  });

  /// Creates a new [UserModel] from a Firestore document map.
  ///
  /// Only the fields defined on this model are extracted from the map.
  /// Unknown fields are ignored. If [uid] is missing, an empty string
  /// will be used.
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      photoURL: data['photoURL'] as String? ?? data['photoUrl'] as String?,
      parentEmail: data['parentEmail'] as String?,
      teacherId: data['teacherId'] as String?,
      studentId: data['studentId'] as String?,
      gradeLevel: data['gradeLevel'] as String?,
      enrolledClassIds: (data['enrolledClassIds'] as List?)?.cast<String>(),
      createdAt: data['createdAt'] is DateTime ? data['createdAt'] as DateTime? : null,
      lastActive: data['lastActive'] is DateTime ? data['lastActive'] as DateTime? : null,
      role: _roleFromString(data['role'] as String?),
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
      if (parentEmail != null) 'parentEmail': parentEmail,
      if (teacherId != null) 'teacherId': teacherId,
      if (studentId != null) 'studentId': studentId,
      if (gradeLevel != null) 'gradeLevel': gradeLevel,
      if (enrolledClassIds != null) 'enrolledClassIds': enrolledClassIds,
      if (createdAt != null) 'createdAt': createdAt,
      if (lastActive != null) 'lastActive': lastActive,
      if (role != null) 'role': role.toString().split('.').last,
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
    String? parentEmail,
    String? teacherId,
    String? studentId,
    String? gradeLevel,
    List<String>? enrolledClassIds,
    DateTime? createdAt,
    DateTime? lastActive,
    UserRole? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoURL: photoURL ?? this.photoURL,
      parentEmail: parentEmail ?? this.parentEmail,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      enrolledClassIds: enrolledClassIds ?? this.enrolledClassIds,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      role: role ?? this.role,
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
    final nameParts = [firstName, lastName].where((e) => e != null && e!.isNotEmpty).toList();
    if (nameParts.isNotEmpty) {
      return nameParts.join(' ');
    }
    return email ?? '';
  }

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