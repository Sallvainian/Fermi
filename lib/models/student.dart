import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final int gradeLevel;
  final String? parentEmail;
  final List<String> classIds;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
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

  String get fullName => '$firstName $lastName';
  int get classCount => classIds.length;

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