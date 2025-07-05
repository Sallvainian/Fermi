/// Student model for managing student profiles and enrollment data.
/// 
/// This module contains the data model for students, representing
/// learners enrolled in classes within the education management system.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Core student model representing a learner in the system.
/// 
/// This model encapsulates all student-specific data, including:
/// - Personal information (name, email, grade)
/// - Class enrollments
/// - Parent/guardian contact information
/// - Profile metadata
/// 
/// The Student model is separate from UserModel to allow:
/// - Teacher-specific views of student data
/// - Enrollment management without full user access
/// - Parent contact information storage
/// - Grade-level specific features
class Student {
  /// Unique identifier for the student record
  final String id;
  
  /// Associated user ID linking to authentication system
  final String userId;
  
  /// Student's email address
  final String email;
  
  /// Student's first name
  final String firstName;
  
  /// Student's last name
  final String lastName;
  
  /// Display name shown in UI (typically "FirstName LastName")
  final String displayName;
  
  /// Current grade level (1-12 for K-12 systems)
  final int gradeLevel;
  
  /// Optional parent/guardian email for notifications
  final String? parentEmail;
  
  /// List of class IDs the student is enrolled in
  final List<String> classIds;
  
  /// Optional URL to student's profile photo
  final String? photoURL;
  
  /// Timestamp when the student record was created
  final DateTime createdAt;
  
  /// Timestamp of last update to student record
  final DateTime updatedAt;
  
  /// Whether the student account is active
  final bool isActive;
  
  /// Flexible metadata for additional student information
  final Map<String, dynamic>? metadata;

  Student({
    required this.id,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.gradeLevel,
    this.parentEmail,
    required this.classIds,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.metadata,
  });

  /// Gets the student's full name by combining first and last names.
  /// @return Full name as "FirstName LastName"
  String get fullName => '$firstName $lastName';
  
  /// Gets the number of classes the student is enrolled in.
  /// @return Count of enrolled classes
  int get classCount => classIds.length;

  /// Factory constructor to create Student from Firestore document.
  /// 
  /// Handles data parsing with safe defaults including:
  /// - Null-safe timestamp conversions with fallback to current time
  /// - Default values for required fields
  /// - List casting for class IDs
  /// - Optional field preservation
  /// 
  /// @param doc Firestore document snapshot containing student data
  /// @return Parsed Student instance
  factory Student.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      displayName: data['displayName'] ?? '',
      gradeLevel: data['gradeLevel'] ?? 0,
      parentEmail: data['parentEmail'],
      classIds: List<String>.from(data['classIds'] ?? []),
      photoURL: data['photoURL'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      metadata: data['metadata'],
    );
  }

  /// Converts the Student instance to a Map for Firestore storage.
  /// 
  /// Note: DateTime fields are stored directly without conversion
  /// to Timestamp, which may need adjustment based on Firestore
  /// configuration requirements.
  /// 
  /// @return Map containing all student data for Firestore persistence
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'gradeLevel': gradeLevel,
      'parentEmail': parentEmail,
      'classIds': classIds,
      'photoURL': photoURL,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// Creates a copy of the Student with updated fields.
  /// 
  /// Follows the immutable data pattern for state management.
  /// Useful for:
  /// - Updating student information
  /// - Managing class enrollments
  /// - Modifying grade level or status
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New Student instance with updated fields
  Student copyWith({
    String? id,
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? displayName,
    int? gradeLevel,
    String? parentEmail,
    List<String>? classIds,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return Student(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      parentEmail: parentEmail ?? this.parentEmail,
      classIds: classIds ?? this.classIds,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }
}