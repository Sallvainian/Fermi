# Assignment Workflow Technical Implementation

## Overview

The Fermi assignment system implements a comprehensive assignment lifecycle management platform supporting assignment creation, distribution, submission, grading, and analytics. Built with Firebase backend and Flutter frontend using Clean Architecture principles.

## Technical Architecture

### Core Components

#### Assignment Architecture Pattern
- **Data Layer**: Repository pattern with Firebase Firestore integration
- **Domain Layer**: Business logic with assignment entities and use cases
- **Presentation Layer**: Provider-based state management with Flutter widgets
- **File Management**: Firebase Storage for assignment files and submissions

#### Key Implementation Files (13 Files)
```
lib/features/assignments/
├── data/
│   ├── repositories/
│   │   ├── assignment_repository.dart        # Assignment CRUD operations
│   │   └── submission_repository.dart        # Submission management
│   └── services/
│       ├── assignment_service.dart           # Firebase integration
│       └── file_upload_service.dart          # File handling service
├── domain/
│   ├── models/
│   │   ├── assignment.dart                   # Assignment domain model
│   │   ├── submission.dart                   # Submission domain model
│   │   ├── grade.dart                        # Grade domain model
│   │   └── assignment_analytics.dart         # Analytics model
│   └── repositories/
│       └── assignment_repository_interface.dart # Repository contracts
└── presentation/
    ├── screens/
    │   ├── assignments_list_screen.dart       # Assignment overview
    │   ├── assignment_detail_screen.dart      # Individual assignment view
    │   ├── create_assignment_screen.dart      # Assignment creation
    │   ├── submission_screen.dart             # Student submission interface
    │   └── grading_screen.dart                # Teacher grading interface
    ├── widgets/
    │   ├── assignment_card.dart               # Assignment preview widget
    │   ├── submission_tile.dart               # Submission list item
    │   ├── grade_input.dart                   # Grade entry widget
    │   └── due_date_picker.dart               # Date selection widget
    └── providers/
        └── assignment_provider.dart           # Assignment state management
```

## Data Flow Architecture

### Assignment Lifecycle Flow
```
Teacher Creates → Students View → Students Submit → Teacher Grades → Analytics Generated
```

### Detailed Assignment Flow Sequence
1. **Assignment Creation**
   - Teacher accesses CreateAssignmentScreen
   - Assignment data validated and processed
   - Files uploaded to Firebase Storage
   - Assignment document created in Firestore
   - Class participants notified

2. **Assignment Distribution**
   - Assignment appears in student assignment lists
   - Push notifications sent to enrolled students
   - Due date reminders scheduled
   - Assignment status tracked per student

3. **Student Submission**
   - Student accesses SubmissionScreen
   - Files uploaded and processed
   - Submission timestamp recorded
   - Late submission handling
   - Submission status updated

4. **Teacher Grading**
   - Teacher reviews submissions in GradingScreen
   - Grades and feedback provided
   - Grade calculations and analytics
   - Student notifications for graded work

5. **Analytics & Reporting**
   - Assignment completion rates calculated
   - Grade distribution analysis
   - Performance trends generated
   - Export capabilities for reporting

## Database Schema

### Firestore Collections

#### assignments Collection
```typescript
interface AssignmentDocument {
  id: string;                               // Unique assignment identifier
  title: string;                            // Assignment title
  description: string;                      // Assignment description/instructions
  classId: string;                          // Associated class identifier
  createdBy: string;                        // Teacher UID who created assignment
  createdAt: Timestamp;                     // Creation timestamp
  dueDate: Timestamp;                       // Assignment due date
  availableFrom?: Timestamp;                // Availability start date
  availableUntil?: Timestamp;               // Availability end date
  type: 'homework' | 'quiz' | 'project' | 'exam' | 'discussion';
  status: 'draft' | 'published' | 'closed' | 'archived';
  settings: {
    allowLateSubmissions: boolean;          // Late submission policy
    lateSubmissionPenalty: number;          // Penalty percentage for late work
    maxFileSize: number;                    // Maximum file upload size (MB)
    allowedFileTypes: string[];             // Allowed file extensions
    maxSubmissions: number;                 // Maximum submission attempts
    showGradeImmediately: boolean;          // Auto-show grades to students
    allowResubmission: boolean;             // Allow submission updates
    requireTextSubmission: boolean;         // Text entry required
    requireFileSubmission: boolean;         // File upload required
  };
  rubric?: {
    criteria: Array<{
      name: string;                         // Rubric criteria name
      description: string;                  // Criteria description
      maxPoints: number;                    // Maximum points for criteria
      levels: Array<{
        name: string;                       // Level name (e.g., "Excellent")
        description: string;                // Level description
        points: number;                     // Points for this level
      }>;
    }>;
    totalPoints: number;                    // Total possible points
  };
  attachments: Array<{
    fileName: string;                       // Original file name
    fileUrl: string;                        // Firebase Storage URL
    fileSize: number;                       // File size in bytes
    mimeType: string;                       // File MIME type
    uploadedAt: Timestamp;                  // Upload timestamp
  }>;
  metadata: {
    totalSubmissions: number;               // Total submission count
    gradedSubmissions: number;              // Graded submission count
    averageGrade?: number;                  // Average grade for assignment
    completionRate: number;                 // Percentage of students submitted
    viewCount: number;                      // Number of times viewed
    lastModified: Timestamp;                // Last modification timestamp
    modifiedBy: string;                     // UID of last modifier
  };
  notifications: {
    reminderSent: boolean;                  // Due date reminder status
    gradesReleasedNotification: boolean;    // Grades released notification
    lateSubmissionNotifications: boolean;   // Late submission alerts
  };
}
```

#### submissions Collection
```typescript
interface SubmissionDocument {
  id: string;                               // Unique submission identifier
  assignmentId: string;                     // Reference to assignment
  studentId: string;                        // Student UID
  classId: string;                          // Class identifier
  submittedAt: Timestamp;                   // Submission timestamp
  textSubmission?: string;                  // Text-based submission content
  attachments: Array<{
    fileName: string;                       // Original file name
    fileUrl: string;                        // Firebase Storage URL
    fileSize: number;                       // File size in bytes
    mimeType: string;                       // File MIME type
    uploadedAt: Timestamp;                  // Upload timestamp
  }>;
  status: 'submitted' | 'late' | 'graded' | 'returned' | 'resubmission';
  isLate: boolean;                          // Late submission flag
  submissionAttempt: number;                // Submission attempt number
  grade?: {
    totalPoints: number;                    // Points earned
    maxPoints: number;                      // Total possible points
    percentage: number;                     // Grade percentage
    letterGrade?: string;                   // Letter grade (A, B, C, etc.)
    gradedBy: string;                       // Grader UID
    gradedAt: Timestamp;                    // Grading timestamp
    feedback: string;                       // Teacher feedback
    rubricGrades?: Array<{
      criteriaName: string;                 // Rubric criteria name
      pointsEarned: number;                 // Points for this criteria
      maxPoints: number;                    // Max points for criteria
      feedback?: string;                    // Specific criteria feedback
    }>;
  };
  revisions: Array<{
    submittedAt: Timestamp;                 // Revision timestamp
    textSubmission?: string;                // Revised text content
    attachments: Array<{
      fileName: string;
      fileUrl: string;
      fileSize: number;
      mimeType: string;
      uploadedAt: Timestamp;
    }>;
    comment?: string;                       // Revision comment
  }>;
  analytics: {
    timeSpent?: number;                     // Time spent on assignment (minutes)
    viewCount: number;                      // Times assignment was viewed
    downloadCount: number;                  // Times attachments downloaded
    lastViewed: Timestamp;                  // Last view timestamp
  };
}
```

#### grades Collection
```typescript
interface GradeDocument {
  id: string;                               // Unique grade identifier
  assignmentId: string;                     // Assignment reference
  submissionId: string;                     // Submission reference
  studentId: string;                        // Student UID
  classId: string;                          // Class identifier
  teacherId: string;                        // Grader UID
  createdAt: Timestamp;                     // Grade creation timestamp
  updatedAt: Timestamp;                     // Last grade update
  totalPoints: number;                      // Points earned
  maxPoints: number;                        // Total possible points
  percentage: number;                       // Grade percentage
  letterGrade?: string;                     // Letter grade
  feedback: string;                         // Overall feedback
  rubricGrades?: Array<{
    criteriaName: string;                   // Rubric criteria
    pointsEarned: number;                   // Points for criteria
    maxPoints: number;                      // Max points for criteria
    feedback?: string;                      // Criteria-specific feedback
  }>;
  gradingHistory: Array<{
    gradedAt: Timestamp;                    // Historical grading timestamp
    totalPoints: number;                    // Historical points
    feedback: string;                       // Historical feedback
    gradedBy: string;                       // Historical grader
  }>;
  status: 'draft' | 'final' | 'returned';  // Grade status
  isExcused: boolean;                       // Excused assignment flag
  extraCredit: number;                      // Extra credit points
}
```

## API Implementation

### AssignmentProvider Core Methods

#### Assignment Management
```dart
class AssignmentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<Assignment> _assignments = [];
  List<Submission> _submissions = [];
  bool _isLoading = false;
  String? _error;
  
  // Assignment creation
  Future<Assignment> createAssignment({
    required String title,
    required String description,
    required String classId,
    required DateTime dueDate,
    required AssignmentType type,
    DateTime? availableFrom,
    DateTime? availableUntil,
    List<File>? attachments,
    AssignmentSettings? settings,
    Rubric? rubric,
  }) async {
    try {
      _setLoading(true);
      
      // Upload attachments
      List<AttachmentModel> uploadedAttachments = [];
      if (attachments != null && attachments.isNotEmpty) {
        uploadedAttachments = await _uploadAssignmentAttachments(
          attachments,
          classId,
        );
      }
      
      final assignment = Assignment(
        id: _firestore.collection('assignments').doc().id,
        title: title,
        description: description,
        classId: classId,
        createdBy: _currentUserId,
        createdAt: DateTime.now(),
        dueDate: dueDate,
        availableFrom: availableFrom,
        availableUntil: availableUntil,
        type: type,
        status: AssignmentStatus.published,
        settings: settings ?? AssignmentSettings.defaultSettings(),
        rubric: rubric,
        attachments: uploadedAttachments,
      );
      
      // Save to Firestore
      await _firestore
          .collection('assignments')
          .doc(assignment.id)
          .set(assignment.toMap());
      
      // Add to local state
      _assignments.add(assignment);
      
      // Send notifications to students
      await _notifyStudentsOfNewAssignment(assignment);
      
      notifyListeners();
      return assignment;
      
    } catch (e) {
      _setError('Failed to create assignment: $e');
      throw e;
    } finally {
      _setLoading(false);
    }
  }
  
  // Assignment retrieval with filtering
  Future<void> loadAssignments({
    String? classId,
    AssignmentStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      Query query = _firestore.collection('assignments');
      
      // Apply filters
      if (classId != null) {
        query = query.where('classId', isEqualTo: classId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      
      if (fromDate != null) {
        query = query.where('dueDate', isGreaterThanOrEqualTo: fromDate);
      }
      
      if (toDate != null) {
        query = query.where('dueDate', isLessThanOrEqualTo: toDate);
      }
      
      // Execute query
      final snapshot = await query
          .orderBy('dueDate', descending: false)
          .get();
      
      _assignments = snapshot.docs
          .map((doc) => Assignment.fromFirestore(doc))
          .toList();
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to load assignments: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Assignment update
  Future<void> updateAssignment(Assignment assignment) async {
    try {
      await _firestore
          .collection('assignments')
          .doc(assignment.id)
          .update(assignment.toMap());
      
      // Update local state
      final index = _assignments.indexWhere((a) => a.id == assignment.id);
      if (index != -1) {
        _assignments[index] = assignment;
        notifyListeners();
      }
      
    } catch (e) {
      _setError('Failed to update assignment: $e');
      throw e;
    }
  }
}
```

#### Submission Management
```dart
// Student submission operations
Future<Submission> submitAssignment({
  required String assignmentId,
  String? textSubmission,
  List<File>? attachments,
  String? comment,
}) async {
  try {
    _setLoading(true);
    
    // Check if assignment allows submissions
    final assignment = await _getAssignment(assignmentId);
    if (!_canSubmitAssignment(assignment)) {
      throw Exception('Assignment is not available for submission');
    }
    
    // Upload attachments
    List<AttachmentModel> uploadedAttachments = [];
    if (attachments != null && attachments.isNotEmpty) {
      uploadedAttachments = await _uploadSubmissionAttachments(
        attachments,
        assignmentId,
        _currentUserId,
      );
    }
    
    // Check for existing submission
    final existingSubmission = await _getExistingSubmission(
      assignmentId,
      _currentUserId,
    );
    
    final now = DateTime.now();
    final isLate = now.isAfter(assignment.dueDate);
    
    if (existingSubmission != null && !assignment.settings.allowResubmission) {
      throw Exception('Resubmission not allowed for this assignment');
    }
    
    final submission = Submission(
      id: existingSubmission?.id ?? 
          _firestore.collection('submissions').doc().id,
      assignmentId: assignmentId,
      studentId: _currentUserId,
      classId: assignment.classId,
      submittedAt: now,
      textSubmission: textSubmission,
      attachments: uploadedAttachments,
      status: isLate ? SubmissionStatus.late : SubmissionStatus.submitted,
      isLate: isLate,
      submissionAttempt: (existingSubmission?.submissionAttempt ?? 0) + 1,
    );
    
    // Save submission
    await _firestore
        .collection('submissions')
        .doc(submission.id)
        .set(submission.toMap());
    
    // Update assignment metadata
    await _updateAssignmentSubmissionCount(assignmentId);
    
    // Send notification to teacher
    await _notifyTeacherOfSubmission(assignment, submission);
    
    // Update local state
    if (existingSubmission != null) {
      final index = _submissions.indexWhere((s) => s.id == submission.id);
      if (index != -1) {
        _submissions[index] = submission;
      }
    } else {
      _submissions.add(submission);
    }
    
    notifyListeners();
    return submission;
    
  } catch (e) {
    _setError('Failed to submit assignment: $e');
    throw e;
  } finally {
    _setLoading(false);
  }
}

// Grading operations
Future<void> gradeSubmission({
  required String submissionId,
  required double totalPoints,
  required double maxPoints,
  required String feedback,
  List<RubricGrade>? rubricGrades,
  double extraCredit = 0.0,
}) async {
  try {
    _setLoading(true);
    
    final submission = await _getSubmission(submissionId);
    if (submission == null) {
      throw Exception('Submission not found');
    }
    
    final percentage = ((totalPoints + extraCredit) / maxPoints) * 100;
    final letterGrade = _calculateLetterGrade(percentage);
    
    final grade = Grade(
      totalPoints: totalPoints,
      maxPoints: maxPoints,
      percentage: percentage,
      letterGrade: letterGrade,
      feedback: feedback,
      gradedBy: _currentUserId,
      gradedAt: DateTime.now(),
      rubricGrades: rubricGrades,
      extraCredit: extraCredit,
    );
    
    // Update submission with grade
    final updatedSubmission = submission.copyWith(
      grade: grade,
      status: SubmissionStatus.graded,
    );
    
    await _firestore
        .collection('submissions')
        .doc(submissionId)
        .update(updatedSubmission.toMap());
    
    // Create grade record
    await _firestore
        .collection('grades')
        .doc()
        .set({
      ...grade.toMap(),
      'assignmentId': submission.assignmentId,
      'submissionId': submissionId,
      'studentId': submission.studentId,
      'classId': submission.classId,
      'teacherId': _currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Update assignment analytics
    await _updateAssignmentAnalytics(submission.assignmentId);
    
    // Notify student of grade
    await _notifyStudentOfGrade(submission, grade);
    
    // Update local state
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index != -1) {
      _submissions[index] = updatedSubmission;
    }
    
    notifyListeners();
    
  } catch (e) {
    _setError('Failed to grade submission: $e');
    throw e;
  } finally {
    _setLoading(false);
  }
}
```

#### File Upload Service
```dart
class FileUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  static Future<AttachmentModel> uploadFile({
    required File file,
    required String path,
    String? customFileName,
    Function(double)? onProgress,
  }) async {
    try {
      final fileName = customFileName ?? 
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _storage.ref().child('$path/$fileName');
      
      // Create upload task with progress tracking
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(file.path),
          customMetadata: {
            'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Track upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }
      
      // Wait for completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Get file metadata
      final metadata = await snapshot.ref.getMetadata();
      
      return AttachmentModel(
        fileName: fileName,
        fileUrl: downloadUrl,
        fileSize: metadata.size ?? 0,
        mimeType: metadata.contentType ?? 'application/octet-stream',
        uploadedAt: DateTime.now(),
      );
      
    } catch (e) {
      throw Exception('File upload failed: $e');
    }
  }
  
  static String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
  
  static Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      // File might already be deleted or not exist
      print('Failed to delete file: $e');
    }
  }
}
```

## Security Implementation

### Firestore Security Rules
```javascript
// Assignment security rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Assignments - class members only
    match /assignments/{assignmentId} {
      allow read: if request.auth != null 
        && (request.auth.uid == resource.data.createdBy
            || exists(/databases/$(database)/documents/classes/$(resource.data.classId)/students/$(request.auth.uid))
            || exists(/databases/$(database)/documents/classes/$(resource.data.classId)/teachers/$(request.auth.uid)));
      
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.createdBy
        && exists(/databases/$(database)/documents/classes/$(request.resource.data.classId)/teachers/$(request.auth.uid));
      
      allow update: if request.auth != null 
        && (request.auth.uid == resource.data.createdBy
            || exists(/databases/$(database)/documents/classes/$(resource.data.classId)/teachers/$(request.auth.uid)));
      
      allow delete: if request.auth != null 
        && request.auth.uid == resource.data.createdBy;
    }
    
    // Submissions - student owns submission or teacher in class
    match /submissions/{submissionId} {
      allow read: if request.auth != null 
        && (request.auth.uid == resource.data.studentId
            || exists(/databases/$(database)/documents/classes/$(resource.data.classId)/teachers/$(request.auth.uid)));
      
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.studentId
        && exists(/databases/$(database)/documents/classes/$(request.resource.data.classId)/students/$(request.auth.uid));
      
      allow update: if request.auth != null 
        && (request.auth.uid == resource.data.studentId
            || exists(/databases/$(database)/documents/classes/$(resource.data.classId)/teachers/$(request.auth.uid)));
    }
    
    // Grades - read by student/teacher, write by teacher only
    match /grades/{gradeId} {
      allow read: if request.auth != null 
        && (request.auth.uid == resource.data.studentId
            || request.auth.uid == resource.data.teacherId
            || exists(/databases/$(database)/documents/classes/$(resource.data.classId)/teachers/$(request.auth.uid)));
      
      allow create, update: if request.auth != null 
        && exists(/databases/$(database)/documents/classes/$(resource.data.classId)/teachers/$(request.auth.uid));
    }
  }
}
```

### Input Validation
```dart
class AssignmentValidation {
  static String? validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return 'Title is required';
    }
    if (title.length > 100) {
      return 'Title must be 100 characters or less';
    }
    return null;
  }
  
  static String? validateDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return 'Description is required';
    }
    if (description.length > 5000) {
      return 'Description must be 5000 characters or less';
    }
    return null;
  }
  
  static String? validateDueDate(DateTime? dueDate) {
    if (dueDate == null) {
      return 'Due date is required';
    }
    if (dueDate.isBefore(DateTime.now())) {
      return 'Due date cannot be in the past';
    }
    return null;
  }
  
  static String? validatePoints(String? points) {
    if (points == null || points.isEmpty) {
      return 'Points are required';
    }
    final pointsValue = double.tryParse(points);
    if (pointsValue == null || pointsValue < 0) {
      return 'Points must be a positive number';
    }
    if (pointsValue > 1000) {
      return 'Points cannot exceed 1000';
    }
    return null;
  }
  
  static String? validateFileSize(File file, int maxSizeMB) {
    final fileSizeBytes = file.lengthSync();
    final fileSizeMB = fileSizeBytes / (1024 * 1024);
    
    if (fileSizeMB > maxSizeMB) {
      return 'File size cannot exceed ${maxSizeMB}MB';
    }
    return null;
  }
  
  static bool isAllowedFileType(String fileName, List<String> allowedTypes) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedTypes.contains(extension);
  }
}
```

## Performance Optimizations

### Lazy Loading & Pagination
```dart
class AssignmentPagination {
  static const int assignmentsPerPage = 20;
  DocumentSnapshot? _lastAssignmentDoc;
  bool _hasMoreAssignments = true;
  
  Future<List<Assignment>> loadAssignments({
    String? classId,
    bool loadMore = false,
  }) async {
    if (loadMore && !_hasMoreAssignments) return [];
    
    Query query = FirebaseFirestore.instance
        .collection('assignments')
        .orderBy('dueDate', descending: true)
        .limit(assignmentsPerPage);
    
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    
    if (loadMore && _lastAssignmentDoc != null) {
      query = query.startAfterDocument(_lastAssignmentDoc!);
    }
    
    final snapshot = await query.get();
    
    if (snapshot.docs.isEmpty) {
      _hasMoreAssignments = false;
      return [];
    }
    
    if (snapshot.docs.length < assignmentsPerPage) {
      _hasMoreAssignments = false;
    }
    
    _lastAssignmentDoc = snapshot.docs.last;
    
    return snapshot.docs
        .map((doc) => Assignment.fromFirestore(doc))
        .toList();
  }
}
```

### Caching Strategy
```dart
class AssignmentCache {
  static final Map<String, Assignment> _assignmentCache = {};
  static final Map<String, List<Submission>> _submissionCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  static Assignment? getCachedAssignment(String assignmentId) {
    final timestamp = _cacheTimestamps[assignmentId];
    if (timestamp == null || 
        DateTime.now().difference(timestamp) > _cacheExpiry) {
      _assignmentCache.remove(assignmentId);
      _cacheTimestamps.remove(assignmentId);
      return null;
    }
    return _assignmentCache[assignmentId];
  }
  
  static void cacheAssignment(Assignment assignment) {
    _assignmentCache[assignment.id] = assignment;
    _cacheTimestamps[assignment.id] = DateTime.now();
  }
  
  static void invalidateAssignmentCache(String assignmentId) {
    _assignmentCache.remove(assignmentId);
    _cacheTimestamps.remove(assignmentId);
    _submissionCache.remove(assignmentId);
  }
  
  static void clearExpiredCache() {
    final now = DateTime.now();
    _cacheTimestamps.removeWhere((key, timestamp) {
      if (now.difference(timestamp) > _cacheExpiry) {
        _assignmentCache.remove(key);
        _submissionCache.remove(key);
        return true;
      }
      return false;
    });
  }
}
```

## Analytics & Reporting

### Assignment Analytics
```dart
class AssignmentAnalytics {
  static Future<AssignmentAnalyticsData> generateAssignmentAnalytics(
    String assignmentId,
  ) async {
    final submissions = await FirebaseFirestore.instance
        .collection('submissions')
        .where('assignmentId', isEqualTo: assignmentId)
        .get();
    
    final grades = submissions.docs
        .where((doc) => doc.data()['grade'] != null)
        .map((doc) => doc.data()['grade']['percentage'])
        .cast<double>()
        .toList();
    
    final onTimeSubmissions = submissions.docs
        .where((doc) => doc.data()['isLate'] == false)
        .length;
    
    final analytics = AssignmentAnalyticsData(
      assignmentId: assignmentId,
      totalSubmissions: submissions.docs.length,
      gradedSubmissions: grades.length,
      onTimeSubmissions: onTimeSubmissions,
      lateSubmissions: submissions.docs.length - onTimeSubmissions,
      averageGrade: grades.isEmpty ? 0.0 : 
          grades.reduce((a, b) => a + b) / grades.length,
      gradeDistribution: _calculateGradeDistribution(grades),
      completionRate: _calculateCompletionRate(assignmentId, submissions.docs.length),
      submissionTimeline: await _getSubmissionTimeline(assignmentId),
    );
    
    // Cache analytics
    await FirebaseFirestore.instance
        .collection('assignment_analytics')
        .doc(assignmentId)
        .set(analytics.toMap());
    
    return analytics;
  }
  
  static Map<String, int> _calculateGradeDistribution(List<double> grades) {
    final distribution = <String, int>{
      'A': 0, 'B': 0, 'C': 0, 'D': 0, 'F': 0,
    };
    
    for (final grade in grades) {
      if (grade >= 90) distribution['A'] = distribution['A']! + 1;
      else if (grade >= 80) distribution['B'] = distribution['B']! + 1;
      else if (grade >= 70) distribution['C'] = distribution['C']! + 1;
      else if (grade >= 60) distribution['D'] = distribution['D']! + 1;
      else distribution['F'] = distribution['F']! + 1;
    }
    
    return distribution;
  }
  
  static Future<double> _calculateCompletionRate(
    String assignmentId,
    int submissionCount,
  ) async {
    // Get assignment to find class size
    final assignmentDoc = await FirebaseFirestore.instance
        .collection('assignments')
        .doc(assignmentId)
        .get();
    
    final classId = assignmentDoc.data()?['classId'];
    if (classId == null) return 0.0;
    
    // Get class enrollment count
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('students')
        .get();
    
    final classSize = studentsSnapshot.docs.length;
    return classSize > 0 ? (submissionCount / classSize) * 100 : 0.0;
  }
}
```

## Testing Implementation

### Unit Testing
```dart
group('AssignmentProvider Tests', () {
  late AssignmentProvider assignmentProvider;
  late MockFirestore mockFirestore;
  late MockStorage mockStorage;
  
  setUp(() {
    mockFirestore = MockFirestore();
    mockStorage = MockStorage();
    assignmentProvider = AssignmentProvider(
      firestore: mockFirestore,
      storage: mockStorage,
    );
  });
  
  test('should create assignment successfully', () async {
    final assignment = await assignmentProvider.createAssignment(
      title: 'Test Assignment',
      description: 'Test Description',
      classId: 'class123',
      dueDate: DateTime.now().add(Duration(days: 7)),
      type: AssignmentType.homework,
    );
    
    expect(assignment.title, equals('Test Assignment'));
    expect(assignment.classId, equals('class123'));
    expect(assignmentProvider.assignments.length, equals(1));
  });
  
  test('should validate assignment input', () {
    expect(
      AssignmentValidation.validateTitle(''),
      equals('Title is required'),
    );
    
    expect(
      AssignmentValidation.validateDueDate(DateTime.now().subtract(Duration(days: 1))),
      equals('Due date cannot be in the past'),
    );
  });
});
```

### Integration Testing
```dart
void main() {
  group('Assignment Integration Tests', () {
    testWidgets('complete assignment creation flow', (tester) async {
      await tester.pumpWidget(MyApp());
      
      // Navigate to create assignment
      await tester.tap(find.text('Create Assignment'));
      await tester.pumpAndSettle();
      
      // Fill assignment details
      await tester.enterText(find.byKey(Key('title_field')), 'Math Homework');
      await tester.enterText(find.byKey(Key('description_field')), 'Complete exercises 1-10');
      
      // Set due date
      await tester.tap(find.byKey(Key('due_date_picker')));
      await tester.pumpAndSettle();
      
      // Submit assignment
      await tester.tap(find.byKey(Key('create_button')));
      await tester.pumpAndSettle();
      
      // Verify assignment created
      expect(find.text('Assignment created successfully'), findsOneWidget);
    });
  });
}
```

This comprehensive assignment system provides a robust foundation for educational workflow management with support for complex grading rubrics, file management, analytics, and seamless integration with the broader Fermi education platform.