import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { teacher, student, admin }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
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
    required this.role,
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

  // Factory constructor to create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.toString().split('.').last == data['role'],
        orElse: () => UserRole.student,
      ),
      photoURL: data['photoURL'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: (data['lastActive'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      teacherId: data['teacherId'],
      classIds: data['classIds'] != null 
          ? List<String>.from(data['classIds']) 
          : null,
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
      'role': role.toString().split('.').last,
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
}