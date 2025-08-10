/// Central repository for example/preview data used across the app.
/// 
/// This module provides consistent, realistic example data that appears
/// in empty states to help users understand the app's potential.
library;

import '../../features/student/domain/models/student.dart';
import '../../features/classes/domain/models/class_model.dart';

/// Enumeration of different example data domains.
enum ExampleDomain {
  students,
  classes,
  assignments,
  grades,
}

/// Central repository for managing example data across the application.
/// 
/// Provides consistent, realistic example data for empty states.
/// All example data is clearly distinguishable from real content.
class ExampleRepository {
  ExampleRepository._();
  static final ExampleRepository _instance = ExampleRepository._();
  static ExampleRepository get instance => _instance;
  
  /// Get example data for a specific domain and type.
  static List<T> of<T>(ExampleDomain domain) {
    switch (domain) {
      case ExampleDomain.students:
        return _exampleStudents.cast<T>();
      case ExampleDomain.classes:
        return _exampleClasses.cast<T>();
      case ExampleDomain.assignments:
        return _exampleAssignments.cast<T>();
      case ExampleDomain.grades:
        return _exampleGrades.cast<T>();
    }
  }
  
  /// Example students with realistic but clearly fake data.
  static final List<Student> _exampleStudents = [
    Student(
      id: 'example_student_1',
      uid: 'example_user_1',
      username: 'eexample01',
      firstName: 'Emma',
      lastName: 'Example',
      displayName: 'Emma Example',
      email: 'emma.example@preview.edu',
      gradeLevel: 10,
      parentEmail: 'sarah.example@preview.edu',
      classIds: ['example_class_1', 'example_class_2'],
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      isActive: true,
    ),
    Student(
      id: 'example_student_2',
      uid: 'example_user_2',
      username: 'msample02',
      firstName: 'Marcus',
      lastName: 'Sample',
      displayName: 'Marcus Sample',
      email: 'marcus.sample@preview.edu',
      gradeLevel: 10,
      parentEmail: 'carlos.sample@preview.edu',
      classIds: ['example_class_1', 'example_class_3'],
      createdAt: DateTime.now().subtract(const Duration(days: 85)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      isActive: true,
    ),
    Student(
      id: 'example_student_3',
      uid: 'example_user_3',
      username: 'ademo03',
      firstName: 'Aisha',
      lastName: 'Demo',
      displayName: 'Aisha Demo',
      email: 'aisha.demo@preview.edu',
      gradeLevel: 10,
      parentEmail: 'priya.demo@preview.edu',
      classIds: ['example_class_2', 'example_class_4'],
      createdAt: DateTime.now().subtract(const Duration(days: 92)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      isActive: true,
    ),
    Student(
      id: 'example_student_4',
      uid: 'example_user_4',
      username: 'dpreview04',
      firstName: 'David',
      lastName: 'Preview',
      displayName: 'David Preview',
      email: 'david.preview@preview.edu',
      gradeLevel: 10,
      parentEmail: 'michael.preview@preview.edu',
      classIds: ['example_class_1'],
      createdAt: DateTime.now().subtract(const Duration(days: 88)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      isActive: true,
    ),
    Student(
      id: 'example_student_5',
      uid: 'example_user_5',
      username: 'stest05',
      firstName: 'Sophie',
      lastName: 'Test',
      displayName: 'Sophie Test',
      email: 'sophie.test@preview.edu',
      gradeLevel: 10,
      parentEmail: 'lisa.test@preview.edu',
      classIds: ['example_class_3', 'example_class_4'],
      createdAt: DateTime.now().subtract(const Duration(days: 94)),
      updatedAt: DateTime.now().subtract(const Duration(days: 7)),
      isActive: true,
    ),
  ];
  
  /// Example classes with realistic scheduling and enrollment data.
  static final List<ClassModel> _exampleClasses = [
    ClassModel(
      id: 'example_class_1',
      teacherId: 'current_teacher',
      name: 'Advanced Mathematics',
      subject: 'Mathematics',
      gradeLevel: '10th Grade',
      room: 'Room 205',
      schedule: 'MWF 9:00-10:00 AM',
      studentIds: ['example_student_1', 'example_student_2', 'example_student_4'],
      maxStudents: 30,
      enrollmentCode: 'MATH205',
      description: 'Advanced algebra and introduction to calculus concepts.',
      academicYear: '2024-2025',
      semester: 'Fall',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    ClassModel(
      id: 'example_class_2',
      teacherId: 'current_teacher',
      name: 'Environmental Science',
      subject: 'Science',
      gradeLevel: '10th Grade',
      room: 'Lab 101',
      schedule: 'TTh 1:00-2:30 PM',
      studentIds: ['example_student_1', 'example_student_3'],
      maxStudents: 25,
      enrollmentCode: 'ENVS101',
      description: 'Study of environmental systems and sustainability.',
      academicYear: '2024-2025',
      semester: 'Fall',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 115)),
    ),
    ClassModel(
      id: 'example_class_3',
      teacherId: 'current_teacher',
      name: 'Creative Writing',
      subject: 'English',
      gradeLevel: '10th Grade',
      room: 'Room 312',
      schedule: 'MWF 2:00-3:00 PM',
      studentIds: ['example_student_2', 'example_student_5'],
      maxStudents: 24,
      enrollmentCode: 'ENG312',
      description: 'Develop writing skills through poetry, short stories, and essays.',
      academicYear: '2024-2025',
      semester: 'Fall',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 110)),
    ),
    ClassModel(
      id: 'example_class_4',
      teacherId: 'current_teacher',
      name: 'Physics Honors',
      subject: 'Physics',
      gradeLevel: '10th Grade',
      room: 'Lab 203',
      schedule: 'TTh 10:00-11:30 AM',
      studentIds: ['example_student_3', 'example_student_5'],
      maxStudents: 20,
      enrollmentCode: 'PHYS203',
      description: 'Advanced physics concepts with hands-on laboratory work.',
      academicYear: '2024-2025',
      semester: 'Fall',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 105)),
    ),
  ];
  
  /// Example assignments for gradebook demonstrations.
  static final List<dynamic> _exampleAssignments = [
    {
      'id': 'example_assignment_1',
      'name': 'Quadratic Functions Worksheet',
      'type': 'homework',
      'dueDate': DateTime.now().subtract(const Duration(days: 14)),
      'maxPoints': 25,
      'weight': 1.0,
      'description': 'Practice problems on quadratic equations and graphing.',
    },
    {
      'id': 'example_assignment_2',
      'name': 'Chapter 5 Quiz',
      'type': 'quiz',
      'dueDate': DateTime.now().subtract(const Duration(days: 10)),
      'maxPoints': 50,
      'weight': 1.5,
      'description': 'Quiz covering polynomial functions and factoring.',
    },
    {
      'id': 'example_assignment_3',
      'name': 'Midterm Exam',
      'type': 'test',
      'dueDate': DateTime.now().subtract(const Duration(days: 7)),
      'maxPoints': 100,
      'weight': 3.0,
      'description': 'Comprehensive exam covering units 1-4.',
    },
    {
      'id': 'example_assignment_4',
      'name': 'Trigonometry Project',
      'type': 'project',
      'dueDate': DateTime.now().add(const Duration(days: 5)),
      'maxPoints': 75,
      'weight': 2.5,
      'description': 'Real-world application of trigonometric functions.',
    },
    {
      'id': 'example_assignment_5',
      'name': 'Functions Review',
      'type': 'homework',
      'dueDate': DateTime.now().add(const Duration(days: 3)),
      'maxPoints': 20,
      'weight': 1.0,
      'description': 'Review exercises for upcoming test.',
    },
  ];
  
  /// Example grades for gradebook demonstrations.
  static final List<dynamic> _exampleGrades = [
    // Emma Example's grades
    {'studentId': 'example_student_1', 'assignmentId': 'example_assignment_1', 'points': 23.0, 'status': 'graded'},
    {'studentId': 'example_student_1', 'assignmentId': 'example_assignment_2', 'points': 47.0, 'status': 'graded'},
    {'studentId': 'example_student_1', 'assignmentId': 'example_assignment_3', 'points': 94.0, 'status': 'graded'},
    {'studentId': 'example_student_1', 'assignmentId': 'example_assignment_4', 'points': null, 'status': 'not_submitted'},
    {'studentId': 'example_student_1', 'assignmentId': 'example_assignment_5', 'points': null, 'status': 'not_submitted'},
    
    // Marcus Sample's grades
    {'studentId': 'example_student_2', 'assignmentId': 'example_assignment_1', 'points': 21.0, 'status': 'graded'},
    {'studentId': 'example_student_2', 'assignmentId': 'example_assignment_2', 'points': 43.0, 'status': 'graded'},
    {'studentId': 'example_student_2', 'assignmentId': 'example_assignment_3', 'points': 87.0, 'status': 'graded'},
    {'studentId': 'example_student_2', 'assignmentId': 'example_assignment_4', 'points': null, 'status': 'not_submitted'},
    {'studentId': 'example_student_2', 'assignmentId': 'example_assignment_5', 'points': null, 'status': 'not_submitted'},
    
    // Aisha Demo's grades
    {'studentId': 'example_student_3', 'assignmentId': 'example_assignment_1', 'points': 25.0, 'status': 'graded'},
    {'studentId': 'example_student_3', 'assignmentId': 'example_assignment_2', 'points': 49.0, 'status': 'graded'},
    {'studentId': 'example_student_3', 'assignmentId': 'example_assignment_3', 'points': 98.0, 'status': 'graded'},
    {'studentId': 'example_student_3', 'assignmentId': 'example_assignment_4', 'points': null, 'status': 'not_submitted'},
    {'studentId': 'example_student_3', 'assignmentId': 'example_assignment_5', 'points': null, 'status': 'not_submitted'},
    
    // David Preview's grades
    {'studentId': 'example_student_4', 'assignmentId': 'example_assignment_1', 'points': 18.0, 'status': 'graded'},
    {'studentId': 'example_student_4', 'assignmentId': 'example_assignment_2', 'points': null, 'status': 'missing'},
    {'studentId': 'example_student_4', 'assignmentId': 'example_assignment_3', 'points': 82.0, 'status': 'graded'},
    {'studentId': 'example_student_4', 'assignmentId': 'example_assignment_4', 'points': null, 'status': 'not_submitted'},
    {'studentId': 'example_student_4', 'assignmentId': 'example_assignment_5', 'points': null, 'status': 'not_submitted'},
    
    // Sophie Test's grades
    {'studentId': 'example_student_5', 'assignmentId': 'example_assignment_1', 'points': 22.0, 'status': 'graded'},
    {'studentId': 'example_student_5', 'assignmentId': 'example_assignment_2', 'points': 45.0, 'status': 'graded'},
    {'studentId': 'example_student_5', 'assignmentId': 'example_assignment_3', 'points': 91.0, 'status': 'graded'},
    {'studentId': 'example_student_5', 'assignmentId': 'example_assignment_4', 'points': null, 'status': 'not_submitted'},
    {'studentId': 'example_student_5', 'assignmentId': 'example_assignment_5', 'points': null, 'status': 'not_submitted'},
  ];
}