import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { teacher, student, admin }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final UserRole? role; // Made optional
  final String? photoURL;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isActive;

  // Teacher-specific fields
  final String? teacherId;
  final List<String>? classIds;
  final String? department;

  // Student-specific fields
  final String? studentId;
  final int? gradeLevel;
  final String? parentEmail;
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
  String get name => displayName;
  String? get photoUrl => photoURL;

  // Factory constructor to create UserModel from Firestore document
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

  // Convert UserModel to Map for Firestore
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

  // Create a copy with updated fields
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

  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  bool get isAdmin => role == UserRole.admin;
  bool get hasRole => role != null;
}
