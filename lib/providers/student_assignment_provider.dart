import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/assignment.dart';
import '../models/submission.dart';
import '../models/grade.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/submission_repository.dart';
import '../repositories/grade_repository.dart';
import '../repositories/student_repository.dart';
import '../core/service_locator.dart';

// Combined model for student assignment view
class StudentAssignment {
  final Assignment assignment;
  final Submission? submission;
  final Grade? grade;
  
  StudentAssignment({
    required this.assignment,
    this.submission,
    this.grade,
  });
  
  // Helper getters
  bool get isSubmitted => submission != null;
  bool get isGraded => grade != null && grade!.status == GradeStatus.graded;
  bool get isOverdue => assignment.dueDate.isBefore(DateTime.now()) && !isSubmitted;
  bool get isDueSoon => assignment.dueDate.difference(DateTime.now()).inHours < 24 && !isSubmitted;
  
  String get status {
    if (isGraded) return 'Graded';
    if (isSubmitted) return 'Submitted';
    if (isOverdue) return 'Overdue';
    if (assignment.status == AssignmentStatus.draft) return 'Draft';
    return 'Pending';
  }
  
  double? get earnedPoints => grade?.pointsEarned;
  String? get letterGrade => grade?.letterGrade ?? 
    (grade != null ? Grade.calculateLetterGrade(grade!.percentage) : null);
  String? get feedback => grade?.feedback;
}

class StudentAssignmentProvider with ChangeNotifier {
  late final AssignmentRepository _assignmentRepository;
  late final SubmissionRepository _submissionRepository;
  late final GradeRepository _gradeRepository;
  late final StudentRepository _studentRepository;
  
  StudentAssignmentProvider() {
    _assignmentRepository = getIt<AssignmentRepository>();
    _submissionRepository = getIt<SubmissionRepository>();
    _gradeRepository = getIt<GradeRepository>();
    _studentRepository = getIt<StudentRepository>();
  }
  
  List<StudentAssignment> _assignments = [];
  bool _isLoading = false;
  String _error = '';
  String? _currentStudentId;
  String? _currentClassId;
  
  // Stream subscriptions
  StreamSubscription<List<StudentAssignment>>? _assignmentsSubscription;
  
  // Stream controller for combined data
  final StreamController<List<StudentAssignment>> _studentAssignmentsController = 
      StreamController<List<StudentAssignment>>.broadcast();
  
  // Getters
  List<StudentAssignment> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String get error => _error;
  Stream<List<StudentAssignment>> get assignmentsStream => _studentAssignmentsController.stream;
  
  // Filtered lists
  List<StudentAssignment> get pendingAssignments => 
    _assignments.where((a) => !a.isSubmitted && !a.isOverdue).toList();
  
  List<StudentAssignment> get overdueAssignments =>
    _assignments.where((a) => a.isOverdue).toList();
    
  List<StudentAssignment> get submittedAssignments =>
    _assignments.where((a) => a.isSubmitted && !a.isGraded).toList();
    
  List<StudentAssignment> get gradedAssignments =>
    _assignments.where((a) => a.isGraded).toList();

  // Initialize provider for a student
  Future<void> initializeForStudent(String studentId, {String? classId}) async {
    _currentStudentId = studentId;
    _currentClassId = classId;
    await setupAssignmentsStream();
  }

  // Setup real-time stream for assignments with submissions and grades
  Future<void> setupAssignmentsStream() async {
    if (_currentStudentId == null) return;
    
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Cancel existing subscription if any
      await _assignmentsSubscription?.cancel();

      // Get all classes for the student if no specific class is provided
      List<String> classIds = [];
      if (_currentClassId != null) {
        classIds = [_currentClassId!];
      } else {
        // Get student document to get enrolled classes
        final student = await _studentRepository.getStudentByUserId(_currentStudentId!);
        if (student != null) {
          classIds = student.classIds;
        }
      }

      if (classIds.isEmpty) {
        _assignments = [];
        _isLoading = false;
        notifyListeners();
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
        },
      );
    } catch (e) {
      _error = 'Error setting up assignments stream: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create combined stream of assignments, submissions, and grades
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
        .listen((assignments) {
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
        });

    // Subscribe to submissions stream
    final submissionsSubscription = _submissionRepository
        .getStudentSubmissions(_currentStudentId!)
        .listen((submissions) {
          final submissionMap = <String, Submission>{};
          for (final submission in submissions) {
            submissionMap[submission.assignmentId] = submission;
          }
          latestSubmissions = submissionMap;
          combineAndEmit();
        });

    // Subscribe to grades stream
    final gradesSubscription = _gradeRepository
        .getStudentGrades(_currentStudentId!)
        .listen((grades) {
          final gradeMap = <String, Grade>{};
          for (final grade in grades) {
            gradeMap[grade.assignmentId] = grade;
          }
          latestGrades = gradeMap;
          combineAndEmit();
        });

    // Clean up subscriptions when the controller is closed
    controller.onCancel = () {
      assignmentsSubscription.cancel();
      submissionsSubscription.cancel();
      gradesSubscription.cancel();
    };

    return controller.stream;
  }

  // Submit assignment
  Future<bool> submitAssignment({
    required String assignmentId,
    required String studentName,
    String? textContent,
    String? fileUrl,
    String? fileName,
  }) async {
    if (_currentStudentId == null) return false;

    try {
      final submission = await _submissionRepository.submitTextContent(
        assignmentId: assignmentId,
        studentId: _currentStudentId!,
        studentName: studentName,
        textContent: textContent ?? '',
      );

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

  // Get assignment by ID
  StudentAssignment? getAssignmentById(String assignmentId) {
    try {
      return _assignments.firstWhere((a) => a.assignment.id == assignmentId);
    } catch (e) {
      return null;
    }
  }

  // Filter assignments by type
  List<StudentAssignment> getAssignmentsByType(AssignmentType type) {
    return _assignments.where((a) => a.assignment.type == type).toList();
  }

  // Filter assignments by category
  List<StudentAssignment> getAssignmentsByCategory(String category) {
    return _assignments.where((a) => a.assignment.category == category).toList();
  }

  // Get upcoming assignments (next 7 days)
  List<StudentAssignment> getUpcomingAssignments({int days = 7}) {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));
    
    return _assignments.where((a) {
      return !a.isSubmitted && 
             a.assignment.dueDate.isAfter(now) && 
             a.assignment.dueDate.isBefore(future);
    }).toList();
  }

  // Get assignment statistics
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

  // Refresh data
  Future<void> refresh() async {
    await setupAssignmentsStream();
  }

  // Search assignments
  List<StudentAssignment> searchAssignments(String query) {
    if (query.isEmpty) return _assignments;
    
    final lowercaseQuery = query.toLowerCase();
    return _assignments.where((a) {
      return a.assignment.title.toLowerCase().contains(lowercaseQuery) ||
             a.assignment.description.toLowerCase().contains(lowercaseQuery) ||
             a.assignment.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Sort assignments
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