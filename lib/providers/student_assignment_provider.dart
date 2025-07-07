/// Student assignment state management provider.
/// 
/// This module manages the student's view of assignments, combining
/// assignment details with submission status and grades into a unified
/// interface for student dashboards and assignment tracking.
library;

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../main.dart';
import '../models/assignment.dart';
import '../models/submission.dart';
import '../models/grade.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/submission_repository.dart';
import '../repositories/grade_repository.dart';
import '../repositories/student_repository.dart';
import '../core/service_locator.dart';

/// Combined model for student assignment view.
/// 
/// Aggregates assignment details, submission status, and grade
/// information into a single model for efficient UI rendering.
/// Provides computed properties for common status checks.
class StudentAssignment {
  /// The assignment details.
  final Assignment assignment;
  
  /// The student's submission, if any.
  final Submission? submission;
  
  /// The grade for this assignment, if available.
  final Grade? grade;
  
  /// Creates a student assignment view model.
  StudentAssignment({
    required this.assignment,
    this.submission,
    this.grade,
  });
  
  // Helper getters
  
  /// Whether the assignment has been submitted.
  bool get isSubmitted => submission != null;
  
  /// Whether the assignment has been graded.
  bool get isGraded => grade != null && grade!.status == GradeStatus.graded;
  
  /// Whether the assignment is past due and unsubmitted.
  bool get isOverdue => assignment.dueDate.isBefore(DateTime.now()) && !isSubmitted;
  
  /// Whether the assignment is due within 24 hours.
  bool get isDueSoon => assignment.dueDate.difference(DateTime.now()).inHours < 24 && !isSubmitted;
  
  /// Computed status string for UI display.
  /// 
  /// Priority order: Graded > Submitted > Overdue > Draft > Pending
  String get status {
    if (isGraded) return 'Graded';
    if (isSubmitted) return 'Submitted';
    if (isOverdue) return 'Overdue';
    if (assignment.status == AssignmentStatus.draft) return 'Draft';
    return 'Pending';
  }
  
  /// Points earned for this assignment.
  double? get earnedPoints => grade?.pointsEarned;
  
  /// Percentage score for this assignment.
  double? get percentage => grade?.percentage;
  
  /// Letter grade representation.
  String? get letterGrade => grade?.letterGrade ?? 
    (grade != null ? Grade.calculateLetterGrade(grade!.percentage) : null);
  
  /// Teacher's feedback on the submission.
  String? get feedback => grade?.feedback;
}

/// Provider managing student's assignment view and operations.
/// 
/// This provider coordinates between multiple repositories to present
/// a unified view of assignments, submissions, and grades. Key features:
/// - Real-time updates combining assignment, submission, and grade data
/// - Status tracking (pending, submitted, graded, overdue)
/// - Assignment filtering and categorization
/// - Submission handling and tracking
/// - Performance statistics calculation
/// - Multi-class assignment aggregation
/// 
/// Uses stream combination to maintain synchronized state across
/// assignment lifecycle stages.
class StudentAssignmentProvider with ChangeNotifier {
  /// Repository for assignment data.
  late final AssignmentRepository _assignmentRepository;
  
  /// Repository for submission operations.
  late final SubmissionRepository _submissionRepository;
  
  /// Repository for grade data.
  late final GradeRepository _gradeRepository;
  
  /// Repository for student information.
  late final StudentRepository _studentRepository;
  
  /// Creates provider with repository dependencies.
  /// 
  /// Retrieves repositories from dependency injection container.
  StudentAssignmentProvider() {
    _assignmentRepository = getIt<AssignmentRepository>();
    _submissionRepository = getIt<SubmissionRepository>();
    _gradeRepository = getIt<GradeRepository>();
    _studentRepository = getIt<StudentRepository>();
  }
  
  /// All assignments for the current student.
  List<StudentAssignment> _assignments = [];
  
  /// Loading state for async operations.
  bool _isLoading = false;
  
  /// Latest error message.
  String _error = '';
  
  /// Current student identifier.
  String? _currentStudentId;
  
  
  // Stream subscriptions
  
  /// Subscription for combined assignment data.
  StreamSubscription<List<StudentAssignment>>? _assignmentsSubscription;
  
  /// Stream controller for broadcasting combined data.
  final StreamController<List<StudentAssignment>> _studentAssignmentsController = 
      StreamController<List<StudentAssignment>>.broadcast();
  
  
  // Getters
  
  /// List of all student assignments.
  List<StudentAssignment> get assignments => _assignments;
  
  /// Whether data is currently loading.
  bool get isLoading => _isLoading;
  
  /// Latest error message or empty string.
  String get error => _error;
  
  /// Stream of assignment updates.
  Stream<List<StudentAssignment>> get assignmentsStream {
    // Create a new stream that emits current data immediately
    return Stream<List<StudentAssignment>>.multi((controller) {
      // Emit current assignments immediately
      controller.add(_assignments);
      
      // Then listen to future updates
      final subscription = _studentAssignmentsController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      
      // Clean up subscription when done
      controller.onCancel = () {
        subscription.cancel();
      };
    });
  }
  
  // Filtered lists
  
  /// Assignments awaiting submission (not overdue).
  List<StudentAssignment> get pendingAssignments => 
    _assignments.where((a) => !a.isSubmitted && !a.isOverdue).toList();
  
  /// Assignments past due date without submission.
  List<StudentAssignment> get overdueAssignments =>
    _assignments.where((a) => a.isOverdue).toList();
    
  /// Submitted assignments awaiting grading.
  List<StudentAssignment> get submittedAssignments =>
    _assignments.where((a) => a.isSubmitted && !a.isGraded).toList();
    
  /// Assignments with grades available.
  List<StudentAssignment> get gradedAssignments =>
    _assignments.where((a) => a.isGraded).toList();

  /// Initializes the provider for a specific student.
  /// 
  /// Sets up real-time streams for assignments across all enrolled
  /// classes or a specific class if provided.
  /// 
  /// @param studentId Student's user identifier
  /// @param classId Optional class filter
  Future<void> initializeForStudent(String studentId, {String? classId}) async {
    _currentStudentId = studentId;
    
    // If Firebase is not initialized, emit empty data immediately
    if (!isFirebaseInitialized) {
      _assignments = [];
      _isLoading = false;
      notifyListeners();
      _studentAssignmentsController.add([]);
      return;
    }
    
    await setupAssignmentsStream();
  }

  /// Sets up real-time stream combining assignments, submissions, and grades.
  /// 
  /// Creates a unified stream that:
  /// - Monitors assignments from enrolled classes
  /// - Tracks submission status for each assignment
  /// - Updates grade information as available
  /// - Filters to show only published, active assignments
  /// 
  /// @throws Exception if student has no enrolled classes
  Future<void> setupAssignmentsStream() async {
    if (_currentStudentId == null) return;
    
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Cancel existing subscription if any
      await _assignmentsSubscription?.cancel();

      // Get student document to get enrolled classes
      debugPrint('[StudentAssignmentProvider] Getting student document for userId: $_currentStudentId');
      final student = await _studentRepository.getStudentByUserId(_currentStudentId!);
      debugPrint('[StudentAssignmentProvider] Student found: ${student != null}');
      
      List<String> classIds = [];
      if (student != null) {
        debugPrint('[StudentAssignmentProvider] Student ID: ${student.id}');
        debugPrint('[StudentAssignmentProvider] Student name: ${student.displayName}');
        classIds = student.classIds;
        debugPrint('[StudentAssignmentProvider] Student classIds: $classIds');
      } else {
        debugPrint('[StudentAssignmentProvider] No student document found for userId: $_currentStudentId');
        // Student document doesn't exist yet, emit empty list
        _assignments = [];
        _isLoading = false;
        notifyListeners();
        _studentAssignmentsController.add([]);
        return;
      }

      if (classIds.isEmpty) {
        _assignments = [];
        _isLoading = false;
        notifyListeners();
        // Emit empty list to stream so UI updates
        _studentAssignmentsController.add([]);
        return;
      }

      // Create combined stream
      _assignmentsSubscription = _createCombinedStream(classIds).listen(
        (studentAssignments) {
          _assignments = studentAssignments;
          _isLoading = false;
          _error = '';
          notifyListeners();
          _studentAssignmentsController.add(studentAssignments);
        },
        onError: (error) {
          _error = 'Error loading assignments: $error';
          _isLoading = false;
          notifyListeners();
          // Also emit error to the stream controller
          _studentAssignmentsController.addError(error);
        },
      );
    } catch (e) {
      _error = 'Error setting up assignments stream: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a combined stream merging assignment, submission, and grade data.
  /// 
  /// Implements manual stream combination to synchronize data from
  /// three separate sources. Updates emit whenever any source changes.
  /// 
  /// @param classIds List of class identifiers to monitor
  /// @return Stream of combined student assignment data
  Stream<List<StudentAssignment>> _createCombinedStream(List<String> classIds) {
    // Using a StreamController to manually combine streams
    final controller = StreamController<List<StudentAssignment>>();
    
    // Store latest data from each stream
    List<Assignment>? latestAssignments;
    Map<String, Submission>? latestSubmissions = {};
    Map<String, Grade>? latestGrades = {};
    
    // Helper function to combine and emit data
    void combineAndEmit() {
      if (latestAssignments != null) {
        final studentAssignments = latestAssignments!.map((assignment) {
          return StudentAssignment(
            assignment: assignment,
            submission: latestSubmissions?[assignment.id],
            grade: latestGrades?[assignment.id],
          );
        }).toList();

        // Sort by due date
        studentAssignments.sort((a, b) => a.assignment.dueDate.compareTo(b.assignment.dueDate));
        
        controller.add(studentAssignments);
      }
    }

    // Subscribe to assignments stream
    final assignmentsSubscription = _assignmentRepository
        .getClassAssignmentsForMultipleClasses(classIds)
        .listen(
          (assignments) {
            final now = DateTime.now();
            latestAssignments = assignments
                .where((assignment) {
                  // Only show published assignments that are active or completed
                  return assignment.isPublished &&
                      (assignment.status == AssignmentStatus.active ||
                       assignment.status == AssignmentStatus.completed) &&
                      (assignment.publishAt == null || assignment.publishAt!.isBefore(now));
                })
                .toList();
            combineAndEmit();
          },
          onError: (error) {
            // Forward error to the controller
            controller.addError(error);
          },
        );

    // Subscribe to submissions stream
    final submissionsSubscription = _submissionRepository
        .getStudentSubmissions(_currentStudentId!)
        .listen(
          (submissions) {
            final submissionMap = <String, Submission>{};
            for (final submission in submissions) {
              submissionMap[submission.assignmentId] = submission;
            }
            latestSubmissions = submissionMap;
            combineAndEmit();
          },
          onError: (error) {
            // Forward error to the controller
            controller.addError(error);
          },
        );

    // Subscribe to grades stream
    final gradesSubscription = _gradeRepository
        .getStudentGrades(_currentStudentId!)
        .listen(
          (grades) {
            final gradeMap = <String, Grade>{};
            for (final grade in grades) {
              gradeMap[grade.assignmentId] = grade;
            }
            latestGrades = gradeMap;
            combineAndEmit();
          },
          onError: (error) {
            // Forward error to the controller
            controller.addError(error);
          },
        );

    // Clean up subscriptions when the controller is closed
    controller.onCancel = () {
      assignmentsSubscription.cancel();
      submissionsSubscription.cancel();
      gradesSubscription.cancel();
    };

    return controller.stream;
  }

  /// Submits an assignment for grading.
  /// 
  /// Creates a submission record and updates local state immediately.
  /// Supports both text content and file uploads. Files are uploaded
  /// to Firebase Storage before creating the submission record.
  /// 
  /// @param assignmentId Assignment to submit
  /// @param studentName Student's display name
  /// @param textContent Text-based submission content
  /// @param file Optional file attachment
  /// @return true if submission successful
  Future<bool> submitAssignment({
    required String assignmentId,
    required String studentName,
    String? textContent,
    PlatformFile? file,
  }) async {
    if (_currentStudentId == null) return false;

    try {
      Submission submission;
      
      // If file is provided, upload it first
      if (file != null && file.bytes != null) {
        // Upload file to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final fileRef = storageRef.child('submissions/$assignmentId/$_currentStudentId/$fileName');
        
        // Upload the file
        final uploadTask = await fileRef.putData(file.bytes!);
        final fileUrl = await uploadTask.ref.getDownloadURL();
        
        // Submit with file
        submission = await _submissionRepository.submitFile(
          assignmentId: assignmentId,
          studentId: _currentStudentId!,
          studentName: studentName,
          fileUrl: fileUrl,
          fileName: file.name,
        );
      } else {
        // Submit with text content only
        submission = await _submissionRepository.submitTextContent(
          assignmentId: assignmentId,
          studentId: _currentStudentId!,
          studentName: studentName,
          textContent: textContent ?? '',
        );
      }

      // Update local state
      final index = _assignments.indexWhere((a) => a.assignment.id == assignmentId);
      if (index != -1) {
        _assignments[index] = StudentAssignment(
          assignment: _assignments[index].assignment,
          submission: submission,
          grade: _assignments[index].grade,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Error submitting assignment: $e';
      notifyListeners();
      return false;
    }
  }

  /// Loads assignment details if not already loaded.
  /// 
  /// Ensures assignment data is available for submission screen.
  /// This is useful when navigating directly to submission screen.
  /// 
  /// @param assignmentId Assignment to load
  Future<void> loadAssignmentDetails(String assignmentId) async {
    // Check if assignment is already loaded
    final existing = getAssignmentById(assignmentId);
    if (existing != null) return;
    
    // If not loaded, trigger a refresh
    await refresh();
  }

  /// Retrieves a specific assignment by ID.
  /// 
  /// @param assignmentId Assignment identifier
  /// @return Student assignment or null if not found
  StudentAssignment? getAssignmentById(String assignmentId) {
    try {
      return _assignments.firstWhere((a) => a.assignment.id == assignmentId);
    } catch (e) {
      return null;
    }
  }

  /// Filters assignments by type.
  /// 
  /// @param type Assignment type to filter by
  /// @return List of assignments matching the type
  List<StudentAssignment> getAssignmentsByType(AssignmentType type) {
    return _assignments.where((a) => a.assignment.type == type).toList();
  }

  /// Filters assignments by category.
  /// 
  /// @param category Category name to filter by
  /// @return List of assignments in the category
  List<StudentAssignment> getAssignmentsByCategory(String category) {
    return _assignments.where((a) => a.assignment.category == category).toList();
  }

  /// Gets assignments due within specified days.
  /// 
  /// Filters unsubmitted assignments with due dates in the
  /// near future for deadline awareness.
  /// 
  /// @param days Number of days to look ahead (default: 7)
  /// @return List of upcoming unsubmitted assignments
  List<StudentAssignment> getUpcomingAssignments({int days = 7}) {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));
    
    return _assignments.where((a) {
      return !a.isSubmitted && 
             a.assignment.dueDate.isAfter(now) && 
             a.assignment.dueDate.isBefore(future);
    }).toList();
  }

  /// Calculates comprehensive assignment statistics.
  /// 
  /// Computes metrics including:
  /// - Submission and completion rates
  /// - Grade averages and distribution
  /// - Overdue assignment counts
  /// - Overall performance indicators
  /// 
  /// @return Map of statistical metrics
  Map<String, dynamic> getStatistics() {
    final total = _assignments.length;
    final submitted = _assignments.where((a) => a.isSubmitted).length;
    final graded = _assignments.where((a) => a.isGraded).length;
    final overdue = _assignments.where((a) => a.isOverdue).length;
    
    // Calculate average grade
    final gradedAssignments = _assignments.where((a) => a.isGraded).toList();
    double averageGrade = 0;
    if (gradedAssignments.isNotEmpty) {
      final totalPercentage = gradedAssignments.fold<double>(
        0,
        (total, a) => total + (a.grade?.percentage ?? 0),
      );
      averageGrade = totalPercentage / gradedAssignments.length;
    }
    
    return {
      'total': total,
      'submitted': submitted,
      'graded': graded,
      'overdue': overdue,
      'pending': total - submitted - overdue,
      'submissionRate': total > 0 ? (submitted / total * 100) : 0,
      'averageGrade': averageGrade,
      'letterGrade': averageGrade > 0 ? Grade.calculateLetterGrade(averageGrade) : 'N/A',
    };
  }

  /// Refreshes all assignment data.
  /// 
  /// Resets and re-establishes data streams for fresh data.
  Future<void> refresh() async {
    await setupAssignmentsStream();
  }

  /// Searches assignments by title, description, or category.
  /// 
  /// Case-insensitive search across multiple fields.
  /// 
  /// @param query Search terms
  /// @return List of matching assignments
  List<StudentAssignment> searchAssignments(String query) {
    if (query.isEmpty) return _assignments;
    
    final lowercaseQuery = query.toLowerCase();
    return _assignments.where((a) {
      return a.assignment.title.toLowerCase().contains(lowercaseQuery) ||
             a.assignment.description.toLowerCase().contains(lowercaseQuery) ||
             a.assignment.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Sorts assignments by specified criteria.
  /// 
  /// Supports sorting by:
  /// - dueDate: Chronological order
  /// - title: Alphabetical order
  /// - points: Highest value first
  /// - status: Status priority order
  /// 
  /// @param sortBy Sort criterion
  void sortAssignments(String sortBy) {
    switch (sortBy) {
      case 'dueDate':
        _assignments.sort((a, b) => a.assignment.dueDate.compareTo(b.assignment.dueDate));
        break;
      case 'title':
        _assignments.sort((a, b) => a.assignment.title.compareTo(b.assignment.title));
        break;
      case 'points':
        _assignments.sort((a, b) => b.assignment.totalPoints.compareTo(a.assignment.totalPoints));
        break;
      case 'status':
        _assignments.sort((a, b) => a.status.compareTo(b.status));
        break;
    }
    notifyListeners();
  }

  /// Cleans up resources when provider is disposed.
  /// 
  /// Cancels stream subscriptions, closes controllers,
  /// and disposes repositories to prevent memory leaks.
  @override
  void dispose() {
    _assignmentsSubscription?.cancel();
    _studentAssignmentsController.close();
    _assignments.clear();
    
    // Dispose repositories
    _assignmentRepository.dispose();
    _submissionRepository.dispose();
    _gradeRepository.dispose();
    _studentRepository.dispose();
    
    super.dispose();
  }
}