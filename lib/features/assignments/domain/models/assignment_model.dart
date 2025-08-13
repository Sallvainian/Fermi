import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentModel {
  final String id;
  final String title;
  final String description;
  final String classId;
  final String className;
  final String subject;
  final String teacherId;
  final DateTime dueDate;
  final DateTime createdAt;
  final bool hasSubmissions;
  final bool needsGrading;
  final int totalPoints;
  final List<String> attachments;
  
  AssignmentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.classId,
    required this.className,
    required this.subject,
    required this.teacherId,
    required this.dueDate,
    required this.createdAt,
    this.hasSubmissions = false,
    this.needsGrading = false,
    this.totalPoints = 100,
    this.attachments = const [],
  });
  
  factory AssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssignmentModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      subject: data['subject'] ?? '',
      teacherId: data['teacherId'] ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasSubmissions: data['hasSubmissions'] ?? false,
      needsGrading: data['needsGrading'] ?? false,
      totalPoints: data['totalPoints'] ?? 100,
      attachments: List<String>.from(data['attachments'] ?? []),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'classId': classId,
      'className': className,
      'subject': subject,
      'teacherId': teacherId,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'hasSubmissions': hasSubmissions,
      'needsGrading': needsGrading,
      'totalPoints': totalPoints,
      'attachments': attachments,
    };
  }
  
  String get dueDateFormatted {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    
    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays == 0) {
      return 'Due Today';
    } else if (difference.inDays == 1) {
      return 'Due Tomorrow';
    } else if (difference.inDays <= 7) {
      return 'Due in ${difference.inDays} days';
    } else {
      return 'Due in ${(difference.inDays / 7).round()} weeks';
    }
  }
  
  String get priority {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    
    if (difference.isNegative || difference.inDays <= 1) {
      return 'High';
    } else if (difference.inDays <= 3) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }
}