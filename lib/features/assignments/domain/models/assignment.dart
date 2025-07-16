/// Assignment model for managing educational assignments and tasks.
/// 
/// This module contains the data models for assignments, including
/// their lifecycle states and various types used throughout the
/// teacher dashboard application.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enumeration representing the lifecycle states of an assignment.
/// 
/// Each assignment progresses through these states:
/// - [draft]: Assignment is being created/edited, not visible to students
/// - [active]: Assignment is published and accepting submissions
/// - [completed]: Assignment due date has passed or manually marked complete
/// - [archived]: Assignment is no longer active but kept for records
enum AssignmentStatus {
  draft,
  active,
  completed,
  archived
}

/// Core assignment model representing educational tasks and assessments.
/// 
/// This model encapsulates all data related to an assignment, including:
/// - Basic information (title, description, instructions)
/// - Grading configuration (points, late penalties)
/// - Publishing controls (status, scheduled publishing)
/// - Submission settings (late submissions, attachments)
/// 
/// Assignments can be of various types (homework, quiz, test, etc.) and
/// progress through different lifecycle states from draft to archived.
class Assignment {
  /// Unique identifier for the assignment
  final String id;
  
  /// ID of the teacher who created this assignment
  final String teacherId;
  
  /// ID of the class this assignment belongs to
  final String classId;
  
  /// Assignment title displayed to students
  final String title;
  
  /// Brief description of the assignment
  final String description;
  
  /// Detailed instructions for completing the assignment
  final String instructions;
  
  /// Due date and time for submissions
  final DateTime dueDate;
  
  /// Total points possible for this assignment
  final double totalPoints;
  
  /// Maximum points that can be earned (may differ from totalPoints for extra credit)
  final double maxPoints;
  
  /// Optional URL to attached file or resource
  final String? attachmentUrl;
  
  /// Timestamp when the assignment was created
  final DateTime createdAt;
  
  /// Timestamp of last modification (null if never updated)
  final DateTime? updatedAt;
  
  /// Type of assignment (homework, quiz, test, etc.)
  final AssignmentType type;
  
  /// Current status in the assignment lifecycle
  final AssignmentStatus status;
  
  /// Category for organizing assignments (e.g., "Math", "Science")
  final String category;
  
  /// Name of the teacher (cached for display purposes)
  final String teacherName;
  
  /// Whether the assignment is visible to students
  final bool isPublished;
  
  /// Whether submissions are accepted after the due date
  final bool allowLateSubmissions;
  
  /// Percentage penalty applied to late submissions (0-100)
  final int latePenaltyPercentage;
  
  /// Optional future date/time to automatically publish the assignment
  final DateTime? publishAt; // For scheduled publishing

  Assignment({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.title,
    required this.description,
    required this.instructions,
    required this.dueDate,
    required this.totalPoints,
    required this.maxPoints,
    this.attachmentUrl,
    required this.createdAt,
    this.updatedAt,
    required this.type,
    required this.status,
    required this.category,
    required this.teacherName,
    required this.isPublished,
    required this.allowLateSubmissions,
    required this.latePenaltyPercentage,
    this.publishAt,
  });

  /// Factory constructor to create Assignment from Firestore document.
  /// 
  /// Handles data parsing and type conversions including:
  /// - Timestamp to DateTime conversions
  /// - Enum parsing with fallback defaults
  /// - Null safety for optional fields
  /// - Type casting for numeric values
  /// 
  /// @param doc Firestore document snapshot containing assignment data
  /// @return Parsed Assignment instance
  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      classId: data['classId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      instructions: data['instructions'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      totalPoints: (data['totalPoints'] ?? 0).toDouble(),
      maxPoints: (data['maxPoints'] ?? data['totalPoints'] ?? 0).toDouble(),
      attachmentUrl: data['attachmentUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      type: AssignmentType.values.firstWhere(
        (e) => e.toString() == 'AssignmentType.${data['type']}',
        orElse: () => AssignmentType.homework,
      ),
      status: AssignmentStatus.values.firstWhere(
        (e) => e.toString() == 'AssignmentStatus.${data['status']}',
        orElse: () => AssignmentStatus.draft,
      ),
      category: data['category'] ?? 'Other',
      teacherName: data['teacherName'] ?? '',
      isPublished: data['isPublished'] ?? false,
      allowLateSubmissions: data['allowLateSubmissions'] ?? true,
      latePenaltyPercentage: data['latePenaltyPercentage'] ?? 10,
      publishAt: data['publishAt'] != null 
          ? (data['publishAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Converts the Assignment instance to a Map for Firestore storage.
  /// 
  /// Serializes all assignment data for persistence, including:
  /// - DateTime fields to Firestore Timestamps
  /// - Enum values to string representations
  /// - Null checks for optional fields
  /// 
  /// @return Map containing all assignment data ready for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'teacherId': teacherId,
      'classId': classId,
      'title': title,
      'description': description,
      'instructions': instructions,
      'dueDate': Timestamp.fromDate(dueDate),
      'totalPoints': totalPoints,
      'maxPoints': maxPoints,
      'attachmentUrl': attachmentUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'category': category,
      'teacherName': teacherName,
      'isPublished': isPublished,
      'allowLateSubmissions': allowLateSubmissions,
      'latePenaltyPercentage': latePenaltyPercentage,
      'publishAt': publishAt != null ? Timestamp.fromDate(publishAt!) : null,
    };
  }

  /// Creates a copy of the Assignment with updated fields.
  /// 
  /// Follows the immutable data pattern, allowing selective field updates
  /// while preserving all other values. Useful for:
  /// - Updating assignment details
  /// - Changing status or publishing state
  /// - Modifying grading settings
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New Assignment instance with updated fields
  Assignment copyWith({
    String? id,
    String? teacherId,
    String? classId,
    String? title,
    String? description,
    String? instructions,
    DateTime? dueDate,
    double? totalPoints,
    double? maxPoints,
    String? attachmentUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    AssignmentType? type,
    AssignmentStatus? status,
    String? category,
    String? teacherName,
    bool? isPublished,
    bool? allowLateSubmissions,
    int? latePenaltyPercentage,
    DateTime? publishAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      title: title ?? this.title,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      dueDate: dueDate ?? this.dueDate,
      totalPoints: totalPoints ?? this.totalPoints,
      maxPoints: maxPoints ?? this.maxPoints,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      status: status ?? this.status,
      category: category ?? this.category,
      teacherName: teacherName ?? this.teacherName,
      isPublished: isPublished ?? this.isPublished,
      allowLateSubmissions: allowLateSubmissions ?? this.allowLateSubmissions,
      latePenaltyPercentage: latePenaltyPercentage ?? this.latePenaltyPercentage,
      publishAt: publishAt ?? this.publishAt,
    );
  }
}

/// Enumeration of supported assignment types.
/// 
/// These types help categorize assignments and may influence:
/// - Default grading rubrics
/// - UI presentation
/// - Submission requirements
/// - Time limits or restrictions
/// 
/// Types include:
/// - [homework]: Regular take-home assignments
/// - [quiz]: Short assessments, often timed
/// - [test]: Formal assessments covering specific topics
/// - [exam]: Major assessments, typically weighted heavily
/// - [project]: Long-term assignments with multiple components
/// - [classwork]: In-class activities and assignments
/// - [essay]: Written assignments requiring extended responses
/// - [lab]: Science or practical lab assignments
/// - [presentation]: Oral or visual presentation assignments
/// - [other]: Miscellaneous assignment types
enum AssignmentType {
  homework,
  quiz,
  test,
  exam,
  project,
  classwork,
  essay,
  lab,
  presentation,
  other
}