import 'package:cloud_firestore/cloud_firestore.dart';

/// Gender options for students
enum Gender {
  male,
  female,
  other,
  notSpecified;

  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
      case Gender.notSpecified:
        return 'Not Specified';
    }
  }

  static Gender fromString(String? value) {
    if (value == null) return Gender.notSpecified;
    switch (value.toLowerCase()) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        return Gender.notSpecified;
    }
  }
}

/// Enhanced student model with additional fields for behavior tracking
class StudentEnhanced {
  final String id;
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final Gender gender;
  final String? avatarUrl;
  final String? gradeLevel;
  final List<String> classIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Behavior points summary (denormalized for quick access)
  final int totalPoints;
  final int positivePoints;
  final int negativePoints;
  final DateTime? lastBehaviorUpdate;

  StudentEnhanced({
    required this.id,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.avatarUrl,
    this.gradeLevel,
    required this.classIds,
    required this.createdAt,
    this.updatedAt,
    this.totalPoints = 0,
    this.positivePoints = 0,
    this.negativePoints = 0,
    this.lastBehaviorUpdate,
  });

  /// Creates a StudentEnhanced from Firestore document
  factory StudentEnhanced.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    List<String> parseClassIds(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    return StudentEnhanced(
      id: doc.id,
      uid: data['uid']?.toString() ?? doc.id,
      email: data['email']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      gender: Gender.fromString(data['gender']?.toString()),
      avatarUrl: data['avatarUrl']?.toString(),
      gradeLevel: data['gradeLevel']?.toString(),
      classIds: parseClassIds(data['classIds']),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseTimestamp(data['updatedAt']) : null,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      positivePoints: (data['positivePoints'] as num?)?.toInt() ?? 0,
      negativePoints: (data['negativePoints'] as num?)?.toInt() ?? 0,
      lastBehaviorUpdate: data['lastBehaviorUpdate'] != null
          ? parseTimestamp(data['lastBehaviorUpdate'])
          : null,
    );
  }

  /// Converts StudentEnhanced to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender.name,
      'avatarUrl': avatarUrl,
      'gradeLevel': gradeLevel,
      'classIds': classIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'totalPoints': totalPoints,
      'positivePoints': positivePoints,
      'negativePoints': negativePoints,
      'lastBehaviorUpdate': lastBehaviorUpdate != null
          ? Timestamp.fromDate(lastBehaviorUpdate!)
          : null,
    };
  }

  /// Creates a copy of StudentEnhanced with updated fields
  StudentEnhanced copyWith({
    String? id,
    String? uid,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    Gender? gender,
    String? avatarUrl,
    String? gradeLevel,
    List<String>? classIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalPoints,
    int? positivePoints,
    int? negativePoints,
    DateTime? lastBehaviorUpdate,
  }) {
    return StudentEnhanced(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      classIds: classIds ?? this.classIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalPoints: totalPoints ?? this.totalPoints,
      positivePoints: positivePoints ?? this.positivePoints,
      negativePoints: negativePoints ?? this.negativePoints,
      lastBehaviorUpdate: lastBehaviorUpdate ?? this.lastBehaviorUpdate,
    );
  }

  /// Gets the student's initials for avatar display
  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    } else if (displayName.isNotEmpty) {
      final parts = displayName.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'S';
  }

  /// Gets a formatted name for display (First L.)
  String get formattedName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName ${lastName[0]}.';
    }
    return displayName;
  }
}