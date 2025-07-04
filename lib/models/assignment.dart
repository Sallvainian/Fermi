import 'package:cloud_firestore/cloud_firestore.dart';

enum AssignmentStatus {
  draft,
  active,
  completed,
  archived
}

class Assignment {
  final String id;
  final String teacherId;
  final String classId;
  final String title;
  final String description;
  final String instructions;
  final DateTime dueDate;
  final double totalPoints;
  final double maxPoints;
  final String? attachmentUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final AssignmentType type;
  final AssignmentStatus status;
  final String category;
  final String teacherName;
  final bool isPublished;
  final bool allowLateSubmissions;
  final int latePenaltyPercentage;
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