import 'package:cloud_firestore/cloud_firestore.dart';

class Submission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String? fileUrl;
  final String? fileName;
  final String? textContent;
  final DateTime submittedAt;
  final DateTime? gradedAt;
  final SubmissionStatus status;

  Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    this.fileUrl,
    this.fileName,
    this.textContent,
    required this.submittedAt,
    this.gradedAt,
    required this.status,
  });

  factory Submission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Submission(
      id: doc.id,
      assignmentId: data['assignmentId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      textContent: data['textContent'],
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      gradedAt: data['gradedAt'] != null 
          ? (data['gradedAt'] as Timestamp).toDate() 
          : null,
      status: SubmissionStatus.values.firstWhere(
        (e) => e.toString() == 'SubmissionStatus.${data['status']}',
        orElse: () => SubmissionStatus.submitted,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'assignmentId': assignmentId,
      'studentId': studentId,
      'studentName': studentName,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'textContent': textContent,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'gradedAt': gradedAt != null ? Timestamp.fromDate(gradedAt!) : null,
      'status': status.toString().split('.').last,
    };
  }
}

enum SubmissionStatus {
  submitted,
  graded,
  returned,
  late
}