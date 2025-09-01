/// Submission model for managing student assignment submissions.
///
/// This module contains the data model for submissions, representing
/// student work submitted for assignments in the education platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Core submission model representing student work submitted for assignments.
///
/// This model encapsulates all data related to a student's submission:
/// - Link to the assignment and student
/// - Submission content (file and/or text)
/// - Timestamps for tracking submission lifecycle
/// - Status tracking (submitted, graded, returned, late)
///
/// Submissions support multiple content types:
/// - File uploads (with URL and filename tracking)
/// - Text content for inline submissions
/// - Combined file and text submissions
class Submission {
  /// Unique identifier for the submission
  final String id;

  /// ID of the assignment this submission is for
  final String assignmentId;

  /// ID of the student who submitted this work
  final String studentId;

  /// Cached student name for display purposes
  final String studentName;

  /// Optional URL to uploaded file (for file submissions)
  final String? fileUrl;

  /// Original filename of uploaded file
  final String? fileName;

  /// Optional text content (for inline text submissions)
  final String? textContent;

  /// Timestamp when the submission was created
  final DateTime submittedAt;

  /// Timestamp when the submission was graded (null if not graded)
  final DateTime? gradedAt;

  /// Timestamp of last modification to the submission
  final DateTime? updatedAt;

  /// Current status of the submission in its lifecycle
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
    this.updatedAt,
    required this.status,
  });

  /// Factory constructor to create Submission from Firestore document.
  ///
  /// Handles data parsing with safe defaults including:
  /// - Timestamp conversions for date fields
  /// - Status enum parsing with fallback to 'submitted'
  /// - Null safety for optional fields
  /// - Caching of student name for performance
  ///
  /// @param doc Firestore document snapshot containing submission data
  /// @return Parsed Submission instance
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
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      status: SubmissionStatus.values.firstWhere(
        (e) => e.toString() == 'SubmissionStatus.${data['status']}',
        orElse: () => SubmissionStatus.submitted,
      ),
    );
  }

  /// Converts the Submission instance to a Map for Firestore storage.
  ///
  /// Serializes all submission data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Status enum to string representation
  /// - Preservation of null values for optional fields
  ///
  /// @return Map containing all submission data for Firestore
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
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status.toString().split('.').last,
    };
  }

  /// Creates a copy of the Submission with updated fields.
  ///
  /// Follows immutable data pattern for state management.
  /// Useful for:
  /// - Updating submission status after grading
  /// - Adding grading timestamp
  /// - Modifying submission content
  /// - Tracking updates
  ///
  /// All parameters are optional - only provided fields will be updated.
  ///
  /// @return New Submission instance with updated fields
  Submission copyWith({
    String? id,
    String? assignmentId,
    String? studentId,
    String? studentName,
    String? fileUrl,
    String? fileName,
    String? textContent,
    DateTime? submittedAt,
    DateTime? gradedAt,
    DateTime? updatedAt,
    SubmissionStatus? status,
  }) {
    return Submission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      textContent: textContent ?? this.textContent,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}

/// Enumeration representing the lifecycle states of a submission.
///
/// Each submission progresses through these states:
/// - [submitted]: Initial state when student submits work
/// - [graded]: Teacher has assigned a grade to the submission
/// - [returned]: Graded work has been returned to student
/// - [late]: Submission was received after the due date
///
/// Note: A submission can be both 'late' and progress through
/// other states (e.g., late → graded → returned)
enum SubmissionStatus { submitted, graded, returned, late }
