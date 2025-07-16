import 'package:cloud_firestore/cloud_firestore.dart';

/// Enumeration representing the different user roles in the system.
/// 
/// Each user must have one of these roles which determines:
/// - Access permissions and available features
/// - Dashboard layout and navigation options
/// - Data visibility and modification rights
enum UserRole { teacher, student, admin }

/// Core user model representing authenticated users in the system.
/// 
/// This model serves as the central user representation throughout the app,
/// containing both common user properties and role-specific fields.
/// 
/// The model supports three user types:
/// 1. **Teachers**: Can create classes, assignments, and manage students
/// 2. **Students**: Can view assignments, submit work, and check grades
/// 3. **Admins**: Have system-wide access (future implementation)
/// 
/// Role-specific fields are nullable to allow a single model to represent
/// all user types while maintaining type safety.
class UserModel {
  /// Unique identifier from Firebase Authentication
  final String uid;
  
  /// User's email address (used for authentication)
  final String email;
  
  /// Full display name shown in the UI
  final String displayName;
  
  /// User's first name
  final String firstName;
  
  /// User's last name
  final String lastName;
  
  /// User's role in the system (optional for new/unconfigured users)
  final UserRole? role; // Made optional
  
  /// URL to user's profile photo (optional)
  final String? photoURL;
  
  /// Timestamp when the user account was created
  final DateTime createdAt;
  
  /// Timestamp of user's last activity
  final DateTime lastActive;
  
  /// Whether the user account is active
  final bool isActive;

  // Teacher-specific fields
  /// Unique teacher identifier (e.g., employee ID)
  final String? teacherId;
  
  /// List of class IDs that this teacher manages
  final List<String>? classIds;
  
  /// Teacher's department (e.g., "Mathematics", "Science")
  final String? department;

  // Student-specific fields
  /// Unique student identifier (e.g., student ID number)
  final String? studentId;
  
  /// Student's current grade level (1-12)
  final int? gradeLevel;
  
  /// Parent/guardian email for notifications
  final String? parentEmail;
  
  /// List of class IDs that this student is enrolled in
  final List<String>? enrolledClassIds;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    this.role,
    this.photoURL,
    required this.createdAt,
    required this.lastActive,
    this.isActive = true,
    this.teacherId,
    this.classIds,
    this.department,
    this.studentId,
    this.gradeLevel,
    this.parentEmail,
    this.enrolledClassIds,
  });

  // Convenience getters
  /// Alias for displayName for backward compatibility
  String get name => displayName;
  
  /// Alias for photoURL for consistent naming convention
  String? get photoUrl => photoURL;

  /// Factory constructor to create UserModel from Firestore document.
  /// 
  /// Handles data validation and transformation including:
  /// - Legacy data migration (splitting displayName into firstName/lastName)
  /// - Type conversions for timestamps
  /// - Null safety for optional fields
  /// - Role enumeration parsing
  /// 
  /// @param doc Firestore document snapshot containing user data
  /// @return Parsed UserModel instance
  /// @throws Exception if required fields are missing
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle legacy data where firstName/lastName might not exist
    String firstName = data['firstName'] ?? '';
    String lastName = data['lastName'] ?? '';

    // If firstName/lastName are empty but displayName exists, try to split it
    if (firstName.isEmpty && lastName.isEmpty && data['displayName'] != null) {
      final nameParts = (data['displayName'] as String).split(' ');
      firstName = nameParts.isNotEmpty ? nameParts.first : '';
      lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    }

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '$firstName $lastName'.trim(),
      firstName: firstName,
      lastName: lastName,
      role: data['role'] != null
          ? UserRole.values.firstWhere(
              (r) => r.toString().split('.').last == data['role'],
              orElse: () => UserRole.teacher,
            )
          : null,
      photoURL: data['photoURL'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
      teacherId: data['teacherId'],
      classIds:
          data['classIds'] != null ? List<String>.from(data['classIds']) : null,
      department: data['department'],
      studentId: data['studentId'],
      gradeLevel: data['gradeLevel'],
      parentEmail: data['parentEmail'],
      enrolledClassIds: data['enrolledClassIds'] != null
          ? List<String>.from(data['enrolledClassIds'])
          : null,
    );
  }

  /// Converts the UserModel instance to a Map for Firestore storage.
  /// 
  /// This method serializes the model data for Firebase Firestore persistence.
  /// Only non-null role-specific fields are included to minimize storage usage.
  /// 
  /// Date fields are converted to Firestore Timestamp format.
  /// Role enum is converted to string representation without the enum prefix.
  /// 
  /// @return Map containing all user data ready for Firestore document update
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      if (role != null) 'role': role!.toString().split('.').last,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'isActive': isActive,
      if (teacherId != null) 'teacherId': teacherId,
      if (classIds != null) 'classIds': classIds,
      if (department != null) 'department': department,
      if (studentId != null) 'studentId': studentId,
      if (gradeLevel != null) 'gradeLevel': gradeLevel,
      if (parentEmail != null) 'parentEmail': parentEmail,
      if (enrolledClassIds != null) 'enrolledClassIds': enrolledClassIds,
    };
  }

  /// Creates a copy of the UserModel with updated fields.
  /// 
  /// This method follows the immutable data pattern, creating a new instance
  /// with selective field updates while preserving unchanged values.
  /// 
  /// Only fields provided as parameters will be updated in the new instance.
  /// All other fields retain their original values from the current instance.
  /// 
  /// Note: The uid, email, role, and createdAt fields cannot be changed
  /// through this method as they represent immutable user properties.
  /// 
  /// @param displayName New display name (optional)
  /// @param firstName New first name (optional)
  /// @param lastName New last name (optional)
  /// @param photoURL New photo URL (optional)
  /// @param lastActive New last active timestamp (optional)
  /// @param isActive New active status (optional)
  /// @param classIds New list of class IDs for teachers (optional)
  /// @param department New department for teachers (optional)
  /// @param gradeLevel New grade level for students (optional)
  /// @param parentEmail New parent email for students (optional)
  /// @param enrolledClassIds New list of enrolled classes for students (optional)
  /// @return New UserModel instance with updated fields
  UserModel copyWith({
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoURL,
    DateTime? lastActive,
    bool? isActive,
    List<String>? classIds,
    String? department,
    int? gradeLevel,
    String? parentEmail,
    List<String>? enrolledClassIds,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      isActive: isActive ?? this.isActive,
      teacherId: teacherId,
      classIds: classIds ?? this.classIds,
      department: department ?? this.department,
      studentId: studentId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      parentEmail: parentEmail ?? this.parentEmail,
      enrolledClassIds: enrolledClassIds ?? this.enrolledClassIds,
    );
  }

  /// Checks if the user has the teacher role.
  /// @return true if user role is teacher, false otherwise
  bool get isTeacher => role == UserRole.teacher;
  
  /// Checks if the user has the student role.
  /// @return true if user role is student, false otherwise
  bool get isStudent => role == UserRole.student;
  
  /// Checks if the user has the admin role.
  /// @return true if user role is admin, false otherwise
  bool get isAdmin => role == UserRole.admin;
  
  /// Checks if the user has any assigned role.
  /// @return true if role is not null, false if no role assigned
  bool get hasRole => role != null;
}
