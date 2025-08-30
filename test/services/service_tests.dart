import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fermi_plus/shared/services/firestore_repository.dart';
import 'package:fermi_plus/features/classes/data/services/class_service.dart';
import 'package:fermi_plus/features/classes/domain/models/class_model.dart';
import 'package:fermi_plus/features/assignments/data/services/assignment_service.dart';
import 'package:fermi_plus/features/assignments/domain/models/assignment.dart';
import 'package:fermi_plus/features/grades/data/services/grade_service.dart';
import 'package:fermi_plus/features/grades/domain/models/grade.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ClassService classService;
  late AssignmentService assignmentService;
  late GradeService gradeService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    classService = ClassService(firestore: fakeFirestore);
    // Pass null notificationService to avoid Firebase initialization issues in tests
    assignmentService = AssignmentService(
      firestore: fakeFirestore,
      notificationService: null,
    );
    gradeService = GradeService(firestore: fakeFirestore);
  });

  group('FirestoreRepository Tests', () {
    test('Generic repository should handle CRUD operations', () async {
      final repository = FirestoreRepository<Map<String, dynamic>>(
        collectionPath: 'test_collection',
        firestore: fakeFirestore,
        fromFirestore: (doc) => doc.data() as Map<String, dynamic>,
        toFirestore: (model) => model,
      );

      // Create
      final id = await repository.create({'name': 'Test Item', 'value': 42});
      expect(id, isNotEmpty);

      // Read
      final item = await repository.get(id);
      expect(item, isNotNull);
      expect(item!['name'], equals('Test Item'));

      // Update
      await repository.update(id, {'name': 'Updated Item', 'value': 100});
      final updated = await repository.get(id);
      expect(updated!['name'], equals('Updated Item'));

      // Delete
      await repository.delete(id);
      final deleted = await repository.get(id);
      expect(deleted, isNull);
    });

    test('Repository should handle streaming data', () async {
      final repository = FirestoreRepository<Map<String, dynamic>>(
        collectionPath: 'stream_test',
        firestore: fakeFirestore,
        fromFirestore: (doc) => doc.data() as Map<String, dynamic>,
        toFirestore: (model) => model,
      );

      final stream = repository.streamList();
      
      // Create items
      await repository.create({'name': 'Item 1'});
      await repository.create({'name': 'Item 2'});

      // Verify stream emits items
      final items = await stream.first;
      expect(items.length, equals(2));
    });
  });

  group('ClassService Tests', () {
    test('Should create class with unique enrollment code', () async {
      final classModel = ClassModel(
        id: '',
        teacherId: 'teacher123',
        name: 'Math 101',
        subject: 'Mathematics',
        gradeLevel: '10',
        studentIds: [],
        createdAt: DateTime.now(),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Fall',
      );

      final created = await classService.createClass(classModel);
      
      expect(created.id, isNotEmpty);
      expect(created.enrollmentCode, isNotNull);
      expect(created.enrollmentCode!.length, equals(6));
      expect(created.name, equals('Math 101'));
    });

    test('Should enroll student with valid code', () async {
      // Create a class first
      final classModel = ClassModel(
        id: '',
        teacherId: 'teacher123',
        name: 'Science 201',
        subject: 'Science',
        gradeLevel: '11',
        studentIds: [],
        createdAt: DateTime.now(),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Fall',
      );

      final created = await classService.createClass(classModel);
      
      // Enroll student
      final enrolled = await classService.enrollStudent(
        'student456',
        created.enrollmentCode!,
      );

      expect(enrolled.studentIds, contains('student456'));
    });

    test('Should get classes by teacher', () async {
      // Create multiple classes
      for (int i = 0; i < 3; i++) {
        await classService.createClass(ClassModel(
          id: '',
          teacherId: 'teacher123',
          name: 'Class $i',
          subject: 'Subject $i',
          gradeLevel: '10',
          studentIds: [],
          createdAt: DateTime.now(),
          isActive: true,
          academicYear: '2024-2025',
          semester: 'Fall',
        ));
      }

      final stream = classService.getClassesByTeacher('teacher123');
      final classes = await stream.first;

      expect(classes.length, equals(3));
      expect(classes.every((c) => c.teacherId == 'teacher123'), isTrue);
    });
  });

  group('AssignmentService Tests', () {
    test('Should create assignment', () async {
      final assignment = Assignment(
        id: '',
        classId: 'class123',
        teacherId: 'teacher123',
        title: 'Homework 1',
        description: 'Complete exercises 1-10',
        instructions: 'Read chapter 5 and complete exercises',
        type: AssignmentType.homework,
        totalPoints: 100,
        maxPoints: 100,
        dueDate: DateTime.now().add(Duration(days: 7)),
        createdAt: DateTime.now(),
        status: AssignmentStatus.draft,
        category: 'Homework',
        teacherName: 'Test Teacher',
        isPublished: false,
        allowLateSubmissions: true,
        latePenaltyPercentage: 10,
      );

      final created = await assignmentService.createAssignment(assignment);
      
      expect(created.id, isNotEmpty);
      expect(created.title, equals('Homework 1'));
      expect(created.totalPoints, equals(100));
    });

    test('Should publish assignment', () async {
      // Create draft assignment
      final assignment = Assignment(
        id: '',
        classId: 'class123',
        teacherId: 'teacher123',
        title: 'Quiz 1',
        description: 'Chapter 5 Quiz',
        instructions: 'Complete all questions',
        type: AssignmentType.quiz,
        totalPoints: 50,
        maxPoints: 50,
        dueDate: DateTime.now().add(Duration(days: 3)),
        createdAt: DateTime.now(),
        status: AssignmentStatus.draft,
        category: 'Quiz',
        teacherName: 'Test Teacher',
        isPublished: false,
        allowLateSubmissions: false,
        latePenaltyPercentage: 0,
      );

      final created = await assignmentService.createAssignment(assignment);
      
      // Publish it
      await assignmentService.publishAssignment(created.id);
      
      // Verify status changed
      final published = await assignmentService.getAssignment(created.id);
      expect(published?.isPublished, equals(true));
      expect(published?.status, equals(AssignmentStatus.active));
    });

    test('Should get assignments by class', () async {
      // Create multiple assignments
      for (int i = 0; i < 3; i++) {
        final assignment = await assignmentService.createAssignment(Assignment(
          id: '',
          classId: 'class123',
          teacherId: 'teacher123',
          title: 'Assignment $i',
          description: 'Description $i',
          instructions: 'Instructions $i',
          type: AssignmentType.homework,
          totalPoints: 100,
          maxPoints: 100,
          dueDate: DateTime.now().add(Duration(days: i + 1)),
          createdAt: DateTime.now(),
          status: AssignmentStatus.active,
          category: 'Homework',
          teacherName: 'Test Teacher',
          isPublished: true,
          allowLateSubmissions: true,
          latePenaltyPercentage: 10,
        ));
        // Ensure assignment is published
        await assignmentService.publishAssignment(assignment.id);
      }

      final stream = assignmentService.getAssignmentsForClass('class123');
      final assignments = await stream.first;

      expect(assignments.length, equals(3));
      expect(assignments.every((a) => a.classId == 'class123'), isTrue);
    });
  });

  group('GradeService Tests', () {
    test('Should create grade', () async {
      final grade = Grade(
        id: '',
        assignmentId: 'assignment123',
        studentId: 'student456',
        studentName: 'John Doe',
        teacherId: 'teacher123',
        classId: 'class123',
        pointsEarned: 85,
        pointsPossible: 100,
        percentage: 85,
        letterGrade: 'B',
        status: GradeStatus.graded,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await gradeService.createGrade(grade);
      
      expect(created.id, isNotEmpty);
      expect(created.pointsEarned, equals(85));
      expect(created.percentage, equals(85));
    });

    test('Should bulk create grades', () async {
      final grades = List.generate(5, (i) => Grade(
        id: '',
        assignmentId: 'assignment123',
        studentId: 'student$i',
        studentName: 'Student $i',
        teacherId: 'teacher123',
        classId: 'class123',
        pointsEarned: 80 + i * 2,
        pointsPossible: 100,
        percentage: 80 + i * 2,
        status: GradeStatus.graded,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await gradeService.bulkCreateGrades(grades);
      
      // Verify all grades were created
      final stream = gradeService.getGradesForAssignment('assignment123');
      final created = await stream.first;
      
      expect(created.length, equals(5));
    });

    test('Should calculate grade statistics', () async {
      // Create multiple grades
      for (int i = 0; i < 10; i++) {
        await gradeService.createGrade(Grade(
          id: '',
          assignmentId: 'assignment123',
          studentId: 'student$i',
          studentName: 'Student $i',
          teacherId: 'teacher123',
          classId: 'class123',
          pointsEarned: 70 + i * 3,
          pointsPossible: 100,
          percentage: 70 + i * 3,
          status: GradeStatus.graded,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      final stats = await gradeService.getAssignmentStatistics('assignment123');
      
      expect(stats.totalGrades, equals(10));
      expect(stats.average, greaterThan(0));
      expect(stats.highest, greaterThan(stats.lowest));
    });

    test('Should get teacher grade summary', () async {
      // Create grades with different statuses
      await gradeService.createGrade(Grade(
        id: '',
        assignmentId: 'assignment1',
        studentId: 'student1',
        studentName: 'Student 1',
        teacherId: 'teacher123',
        classId: 'class123',
        pointsEarned: 85,
        pointsPossible: 100,
        percentage: 85,
        status: GradeStatus.graded,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await gradeService.createGrade(Grade(
        id: '',
        assignmentId: 'assignment2',
        studentId: 'student2',
        studentName: 'Student 2',
        teacherId: 'teacher123',
        classId: 'class123',
        pointsEarned: 0,
        pointsPossible: 100,
        percentage: 0,
        status: GradeStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final summary = await gradeService.getTeacherGradeSummary('teacher123');
      
      expect(summary['totalGrades'], greaterThan(0));
      expect(summary['pendingGrades'], greaterThan(0));
      expect(summary['gradedGrades'], greaterThan(0));
    });
  });

  group('Integration Tests', () {
    test('Complete workflow: Class -> Assignment -> Grade', () async {
      // 1. Create a class
      final classModel = await classService.createClass(ClassModel(
        id: '',
        teacherId: 'teacher123',
        name: 'Integration Test Class',
        subject: 'Testing',
        gradeLevel: '12',
        studentIds: [],
        createdAt: DateTime.now(),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Fall',
      ));

      // 2. Enroll students
      await classService.enrollStudent('student1', classModel.enrollmentCode!);
      await classService.enrollStudent('student2', classModel.enrollmentCode!);

      // 3. Create assignment
      final assignment = await assignmentService.createAssignment(Assignment(
        id: '',
        classId: classModel.id,
        teacherId: 'teacher123',
        title: 'Integration Assignment',
        description: 'Test assignment',
        instructions: 'Complete the test',
        type: AssignmentType.test,
        totalPoints: 100,
        maxPoints: 100,
        dueDate: DateTime.now().add(Duration(days: 7)),
        createdAt: DateTime.now(),
        status: AssignmentStatus.active,
        category: 'Test',
        teacherName: 'Test Teacher',
        isPublished: true,
        allowLateSubmissions: true,
        latePenaltyPercentage: 10,
      ));

      // 4. Create grades for students
      final grades = [
        Grade(
          id: '',
          assignmentId: assignment.id,
          studentId: 'student1',
          studentName: 'Student 1',
          teacherId: 'teacher123',
          classId: classModel.id,
          pointsEarned: 95,
          pointsPossible: 100,
          percentage: 95,
          letterGrade: 'A',
          status: GradeStatus.graded,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Grade(
          id: '',
          assignmentId: assignment.id,
          studentId: 'student2',
          studentName: 'Student 2',
          teacherId: 'teacher123',
          classId: classModel.id,
          pointsEarned: 88,
          pointsPossible: 100,
          percentage: 88,
          letterGrade: 'B',
          status: GradeStatus.graded,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await gradeService.bulkCreateGrades(grades);

      // 5. Verify everything is connected
      final classStream = classService.getClassesByTeacher('teacher123');
      final classes = await classStream.first;
      expect(classes.any((c) => c.name == 'Integration Test Class'), isTrue);

      final assignmentStream = assignmentService.getAssignmentsForClass(classModel.id);
      final assignments = await assignmentStream.first;
      expect(assignments.any((a) => a.title == 'Integration Assignment'), isTrue);

      final gradeStream = gradeService.getGradesForAssignment(assignment.id);
      final createdGrades = await gradeStream.first;
      expect(createdGrades.length, equals(2));

      final stats = await gradeService.getAssignmentStatistics(assignment.id);
      expect(stats.average, closeTo(91.5, 0.1));
    });
  });
}