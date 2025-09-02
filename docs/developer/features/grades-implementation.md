# Grading System Implementation

## Overview

The Fermi grading system provides comprehensive grade management, analytics, and reporting capabilities for educational institutions. Built with Firebase backend and Flutter frontend, supporting multiple grading scales, weighted categories, and advanced analytics for performance tracking.

## Technical Architecture

### Core Components

#### Grading Architecture Pattern
- **Data Layer**: Repository pattern with Firebase Firestore for grade storage
- **Business Logic**: Grade calculations, weighted averages, and analytics processing
- **Presentation Layer**: Provider-based state management with responsive Flutter widgets
- **Analytics Engine**: Real-time grade analytics and performance insights

#### Key Implementation Files (8 Files)
```
lib/features/grades/
├── data/
│   ├── repositories/
│   │   └── grade_repository.dart           # Grade CRUD operations
│   └── services/
│       ├── grade_calculation_service.dart  # Grade calculation logic
│       └── analytics_service.dart          # Grade analytics processing
├── domain/
│   ├── models/
│   │   ├── grade.dart                      # Grade domain model
│   │   ├── grade_category.dart             # Grade category model
│   │   ├── grade_scale.dart                # Grading scale configuration
│   │   └── grade_analytics.dart            # Analytics data model
│   └── repositories/
│       └── grade_repository_interface.dart # Repository contracts
└── presentation/
    ├── screens/
    │   ├── gradebook_screen.dart           # Teacher gradebook interface
    │   ├── student_grades_screen.dart      # Student grade view
    │   └── grade_analytics_screen.dart     # Analytics dashboard
    ├── widgets/
    │   ├── grade_cell.dart                 # Individual grade display
    │   ├── grade_input_dialog.dart         # Grade entry interface
    │   ├── grade_chart.dart                # Grade visualization
    │   └── grade_summary_card.dart         # Grade summary widget
    └── providers/
        └── grade_provider.dart             # Grade state management
```

## Data Flow Architecture

### Grade Management Flow
```
Teacher Input → Grade Validation → Calculation Engine → Storage → Analytics → Student View
```

### Detailed Grading Flow Sequence
1. **Grade Entry**
   - Teacher accesses gradebook interface
   - Grade values entered with validation
   - Category weights and scaling applied
   - Real-time calculation updates

2. **Grade Processing**
   - Input validation and sanitization
   - Automatic grade calculations (weighted averages)
   - Letter grade assignment based on scale
   - Historical grade tracking

3. **Analytics Generation**
   - Performance trends calculation
   - Class-wide statistics generation
   - Individual student progress tracking
   - Comparative analysis processing

4. **Student Access**
   - Real-time grade updates
   - Progress visualization
   - Performance insights display
   - Grade history tracking

5. **Reporting & Export**
   - Grade report generation
   - Export capabilities (PDF, CSV)
   - Parent/guardian access
   - Administrative reporting

## Database Schema

### Firestore Collections

#### grades Collection
```typescript
interface GradeDocument {
  id: string;                               // Unique grade identifier
  studentId: string;                        // Student UID reference
  classId: string;                          // Class identifier
  teacherId: string;                        // Teacher UID who assigned grade
  assignmentId?: string;                    // Optional assignment reference
  categoryId: string;                       // Grade category reference
  
  // Grade Values
  pointsEarned: number;                     // Points received
  pointsPossible: number;                   // Maximum possible points  
  percentage: number;                       // Calculated percentage (0-100)
  letterGrade: string;                      // Letter grade (A, B, C, D, F, etc.)
  gradeValue: number;                       // Numerical grade value for GPA
  
  // Metadata
  gradedAt: Timestamp;                      // When grade was assigned
  updatedAt: Timestamp;                     // Last modification timestamp
  gradingPeriod: string;                    // Academic period (Q1, Q2, Semester, etc.)
  isExcused: boolean;                       // Excused grade flag
  isIncomplete: boolean;                    // Incomplete work flag
  isExtraCredit: boolean;                   // Extra credit flag
  
  // Feedback & Notes
  feedback: string;                         // Teacher feedback/comments
  privateNotes: string;                     // Teacher-only notes
  rubricScores?: Array<{
    criteriaId: string;                     // Rubric criteria identifier
    score: number;                          // Score for this criteria
    maxScore: number;                       // Maximum score possible
    feedback?: string;                      // Criteria-specific feedback
  }>;
  
  // Audit Trail
  history: Array<{
    modifiedAt: Timestamp;                  // Modification timestamp
    modifiedBy: string;                     // Modifier UID
    previousGrade: {
      pointsEarned: number;
      percentage: number;
      letterGrade: string;
    };
    changeReason: string;                   // Reason for grade change
  }>;
  
  // Analytics Support
  submittedLate: boolean;                   // Late submission flag
  attemptNumber: number;                    // Submission attempt count
  timeSpentMinutes?: number;                // Time spent on assignment
}
```

#### grade_categories Collection
```typescript
interface GradeCategoryDocument {
  id: string;                               // Unique category identifier
  name: string;                             // Category name (Homework, Tests, etc.)
  classId: string;                          // Associated class
  teacherId: string;                        // Category creator
  
  // Category Configuration
  weight: number;                           // Category weight (0.0 - 1.0)
  dropLowest: number;                       // Number of lowest grades to drop
  color: string;                            // Display color for category
  description: string;                      // Category description
  
  // Grade Calculation Rules
  calculationMethod: 'average' | 'total_points' | 'weighted_average';
  allowExtraCredit: boolean;                // Extra credit permitted
  maxExtraCreditPoints: number;             // Maximum extra credit points
  
  // Display & Behavior
  isVisible: boolean;                       // Visible to students
  showInGradebook: boolean;                 // Show in gradebook view
  includeInFinalGrade: boolean;             // Include in final grade calculation
  sortOrder: number;                        // Display sort order
  
  // Metadata
  createdAt: Timestamp;
  updatedAt: Timestamp;
  isArchived: boolean;                      // Archive status
}
```

#### grade_scales Collection
```typescript
interface GradeScaleDocument {
  id: string;                               // Unique scale identifier
  name: string;                             // Scale name (4.0 Scale, Percentage, etc.)
  classId?: string;                         // Class-specific scale (optional)
  schoolId?: string;                        // School-wide scale (optional)
  isDefault: boolean;                       // Default scale flag
  
  // Scale Configuration
  type: 'percentage' | 'points' | 'letter' | 'gpa';
  ranges: Array<{
    minPercentage: number;                  // Minimum percentage for grade
    maxPercentage: number;                  // Maximum percentage for grade
    letterGrade: string;                    // Letter grade representation
    gradePoint: number;                     // GPA point value
    description: string;                    // Grade description
    color: string;                          // Display color
  }>;
  
  // GPA Configuration
  gpaScale: number;                         // GPA scale (4.0, 5.0, 100, etc.)
  honorRollThreshold: number;               // Honor roll minimum GPA
  passingThreshold: number;                 // Minimum passing grade
  
  // Metadata
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  isActive: boolean;
}
```

#### grade_analytics Collection
```typescript
interface GradeAnalyticsDocument {
  id: string;                               // Analytics record identifier
  classId: string;                          // Class reference
  studentId?: string;                       // Student-specific analytics (optional)
  generatedAt: Timestamp;                   // Analytics generation timestamp
  periodStart: Timestamp;                   // Analysis period start
  periodEnd: Timestamp;                     // Analysis period end
  
  // Overall Performance
  overallGPA: number;                       // Current GPA
  overallPercentage: number;                // Overall percentage
  overallLetterGrade: string;               // Overall letter grade
  creditsEarned: number;                    // Credits completed
  creditsAttempted: number;                 // Total credits attempted
  
  // Category Performance
  categoryPerformance: Array<{
    categoryId: string;                     // Category identifier
    categoryName: string;                   // Category name
    averageGrade: number;                   // Category average
    totalPoints: number;                    // Total points earned
    possiblePoints: number;                 // Total possible points
    gradeCount: number;                     // Number of grades
    trendDirection: 'up' | 'down' | 'stable'; // Performance trend
  }>;
  
  // Performance Trends
  weeklyTrends: Array<{
    weekStartDate: Timestamp;               // Week start date
    averageGrade: number;                   // Week average
    assignmentsCompleted: number;           // Assignments completed
    averageSubmissionTime: number;          // Average submission time (hours)
  }>;
  
  // Class Comparison (if student-specific)
  classRanking?: {
    position: number;                       // Student rank in class
    totalStudents: number;                  // Total students in class
    percentile: number;                     // Performance percentile
  };
  
  // Insights & Recommendations
  insights: Array<{
    type: 'strength' | 'concern' | 'improvement' | 'achievement';
    title: string;                          // Insight title
    description: string;                    // Detailed description
    actionItems: string[];                  // Recommended actions
    priority: 'low' | 'medium' | 'high';   // Priority level
  }>;
  
  // Statistical Data
  statistics: {
    meanGrade: number;                      // Mean grade
    medianGrade: number;                    // Median grade
    standardDeviation: number;              // Standard deviation
    gradeDistribution: {                    // Grade distribution
      [letterGrade: string]: number;        // Count per letter grade
    };
    assignmentCompletionRate: number;       // Completion rate percentage
    averageDaysLate: number;                // Average days assignments are late
  };
}
```

## API Implementation

### GradeProvider Core Methods

#### Grade Management
```dart
class GradeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GradeCalculationService _calculationService = GradeCalculationService();
  final GradeAnalyticsService _analyticsService = GradeAnalyticsService();
  
  List<Grade> _grades = [];
  List<GradeCategory> _categories = [];
  GradeScale? _currentGradeScale;
  GradeAnalytics? _analytics;
  bool _isLoading = false;
  String? _error;
  
  // Grade creation and updates
  Future<Grade> addGrade({
    required String studentId,
    required String classId,
    required String categoryId,
    required double pointsEarned,
    required double pointsPossible,
    String? assignmentId,
    String? feedback,
    List<RubricScore>? rubricScores,
    bool isExtraCredit = false,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Validate input
      if (pointsEarned < 0 || pointsPossible <= 0) {
        throw Exception('Invalid point values');
      }
      
      if (pointsEarned > pointsPossible && !isExtraCredit) {
        throw Exception('Points earned cannot exceed points possible');
      }
      
      // Calculate grade values
      final percentage = (pointsEarned / pointsPossible) * 100;
      final letterGrade = _currentGradeScale?.getLetterGrade(percentage) ?? 'N/A';
      final gradeValue = _currentGradeScale?.getGradePoint(percentage) ?? 0.0;
      
      // Create grade object
      final grade = Grade(
        id: _firestore.collection('grades').doc().id,
        studentId: studentId,
        classId: classId,
        teacherId: _currentUserId,
        assignmentId: assignmentId,
        categoryId: categoryId,
        pointsEarned: pointsEarned,
        pointsPossible: pointsPossible,
        percentage: percentage,
        letterGrade: letterGrade,
        gradeValue: gradeValue,
        gradedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        gradingPeriod: _getCurrentGradingPeriod(),
        isExtraCredit: isExtraCredit,
        feedback: feedback ?? '',
        rubricScores: rubricScores,
      );
      
      // Save to Firestore
      await _firestore
          .collection('grades')
          .doc(grade.id)
          .set(grade.toMap());
      
      // Update local state
      _grades.add(grade);
      
      // Trigger analytics update
      await _updateStudentAnalytics(studentId, classId);
      
      notifyListeners();
      return grade;
      
    } catch (e) {
      _setError('Failed to add grade: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // Grade updates with audit trail
  Future<void> updateGrade({
    required String gradeId,
    double? pointsEarned,
    double? pointsPossible,
    String? feedback,
    String? changeReason,
  }) async {
    try {
      final gradeIndex = _grades.indexWhere((g) => g.id == gradeId);
      if (gradeIndex == -1) {
        throw Exception('Grade not found');
      }
      
      final currentGrade = _grades[gradeIndex];
      
      // Create history entry
      final historyEntry = GradeHistory(
        modifiedAt: DateTime.now(),
        modifiedBy: _currentUserId,
        previousGrade: GradePreviousValue(
          pointsEarned: currentGrade.pointsEarned,
          percentage: currentGrade.percentage,
          letterGrade: currentGrade.letterGrade,
        ),
        changeReason: changeReason ?? 'Grade updated',
      );
      
      // Calculate new values
      final newPointsEarned = pointsEarned ?? currentGrade.pointsEarned;
      final newPointsPossible = pointsPossible ?? currentGrade.pointsPossible;
      final newPercentage = (newPointsEarned / newPointsPossible) * 100;
      final newLetterGrade = _currentGradeScale?.getLetterGrade(newPercentage) ?? 'N/A';
      final newGradeValue = _currentGradeScale?.getGradePoint(newPercentage) ?? 0.0;
      
      // Update grade
      final updatedGrade = currentGrade.copyWith(
        pointsEarned: newPointsEarned,
        pointsPossible: newPointsPossible,
        percentage: newPercentage,
        letterGrade: newLetterGrade,
        gradeValue: newGradeValue,
        feedback: feedback,
        updatedAt: DateTime.now(),
        history: [...currentGrade.history, historyEntry],
      );
      
      // Save to Firestore
      await _firestore
          .collection('grades')
          .doc(gradeId)
          .update(updatedGrade.toMap());
      
      // Update local state
      _grades[gradeIndex] = updatedGrade;
      
      // Update analytics
      await _updateStudentAnalytics(
        currentGrade.studentId, 
        currentGrade.classId,
      );
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to update grade: $e');
      rethrow;
    }
  }
  
  // Bulk grade operations
  Future<void> addBulkGrades({
    required List<Map<String, dynamic>> gradeData,
    required String classId,
    required String categoryId,
  }) async {
    try {
      _setLoading(true);
      
      final batch = _firestore.batch();
      final grades = <Grade>[];
      
      for (final data in gradeData) {
        final percentage = (data['pointsEarned'] / data['pointsPossible']) * 100;
        final letterGrade = _currentGradeScale?.getLetterGrade(percentage) ?? 'N/A';
        final gradeValue = _currentGradeScale?.getGradePoint(percentage) ?? 0.0;
        
        final grade = Grade(
          id: _firestore.collection('grades').doc().id,
          studentId: data['studentId'],
          classId: classId,
          teacherId: _currentUserId,
          categoryId: categoryId,
          pointsEarned: data['pointsEarned'],
          pointsPossible: data['pointsPossible'],
          percentage: percentage,
          letterGrade: letterGrade,
          gradeValue: gradeValue,
          gradedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          gradingPeriod: _getCurrentGradingPeriod(),
          feedback: data['feedback'] ?? '',
        );
        
        batch.set(
          _firestore.collection('grades').doc(grade.id),
          grade.toMap(),
        );
        
        grades.add(grade);
      }
      
      await batch.commit();
      
      // Update local state
      _grades.addAll(grades);
      
      // Update analytics for all affected students
      final studentIds = grades.map((g) => g.studentId).toSet();
      for (final studentId in studentIds) {
        await _updateStudentAnalytics(studentId, classId);
      }
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to add bulk grades: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
```

#### Grade Calculation Service
```dart
class GradeCalculationService {
  
  // Calculate weighted category average
  static double calculateCategoryAverage({
    required List<Grade> grades,
    required GradeCategory category,
  }) {
    if (grades.isEmpty) return 0.0;
    
    // Filter grades for this category
    final categoryGrades = grades
        .where((g) => g.categoryId == category.id)
        .toList();
    
    if (categoryGrades.isEmpty) return 0.0;
    
    switch (category.calculationMethod) {
      case GradeCategoryCalculation.average:
        return _calculateSimpleAverage(categoryGrades, category);
      
      case GradeCategoryCalculation.totalPoints:
        return _calculateTotalPointsAverage(categoryGrades);
      
      case GradeCategoryCalculation.weightedAverage:
        return _calculateWeightedAverage(categoryGrades);
      
      default:
        return _calculateSimpleAverage(categoryGrades, category);
    }
  }
  
  static double _calculateSimpleAverage(
    List<Grade> grades,
    GradeCategory category,
  ) {
    // Sort by percentage (descending) for drop lowest
    grades.sort((a, b) => b.percentage.compareTo(a.percentage));
    
    // Drop lowest grades if configured
    final gradesToInclude = category.dropLowest > 0 && 
        grades.length > category.dropLowest
        ? grades.take(grades.length - category.dropLowest).toList()
        : grades;
    
    if (gradesToInclude.isEmpty) return 0.0;
    
    final totalPercentage = gradesToInclude
        .fold(0.0, (sum, grade) => sum + grade.percentage);
    
    return totalPercentage / gradesToInclude.length;
  }
  
  static double _calculateTotalPointsAverage(List<Grade> grades) {
    final totalEarned = grades.fold(
      0.0, 
      (sum, grade) => sum + grade.pointsEarned,
    );
    final totalPossible = grades.fold(
      0.0, 
      (sum, grade) => sum + grade.pointsPossible,
    );
    
    return totalPossible > 0 ? (totalEarned / totalPossible) * 100 : 0.0;
  }
  
  static double _calculateWeightedAverage(List<Grade> grades) {
    // Implementation would depend on specific weighting scheme
    // For now, use simple average
    return _calculateSimpleAverage(grades, GradeCategory.defaultCategory());
  }
  
  // Calculate final course grade
  static CourseGradeResult calculateFinalGrade({
    required List<Grade> grades,
    required List<GradeCategory> categories,
    required GradeScale gradeScale,
  }) {
    double totalWeightedScore = 0.0;
    double totalWeight = 0.0;
    final categoryResults = <CategoryGradeResult>[];
    
    for (final category in categories) {
      if (!category.includeInFinalGrade) continue;
      
      final categoryGrades = grades
          .where((g) => g.categoryId == category.id)
          .toList();
      
      if (categoryGrades.isEmpty) continue;
      
      final categoryAverage = calculateCategoryAverage(
        grades: categoryGrades,
        category: category,
      );
      
      final weightedScore = categoryAverage * category.weight;
      totalWeightedScore += weightedScore;
      totalWeight += category.weight;
      
      categoryResults.add(CategoryGradeResult(
        categoryId: category.id,
        categoryName: category.name,
        average: categoryAverage,
        weight: category.weight,
        weightedScore: weightedScore,
        gradeCount: categoryGrades.length,
      ));
    }
    
    final finalPercentage = totalWeight > 0 
        ? totalWeightedScore / totalWeight 
        : 0.0;
    
    return CourseGradeResult(
      finalPercentage: finalPercentage,
      letterGrade: gradeScale.getLetterGrade(finalPercentage),
      gradePoint: gradeScale.getGradePoint(finalPercentage),
      categoryResults: categoryResults,
      totalGrades: grades.length,
      calculatedAt: DateTime.now(),
    );
  }
  
  // Calculate GPA
  static double calculateGPA({
    required List<CourseGradeResult> courseGrades,
    required Map<String, double> creditHours,
  }) {
    double totalGradePoints = 0.0;
    double totalCredits = 0.0;
    
    for (final courseGrade in courseGrades) {
      final courseId = courseGrade.courseId;
      final credits = creditHours[courseId] ?? 1.0;
      
      totalGradePoints += courseGrade.gradePoint * credits;
      totalCredits += credits;
    }
    
    return totalCredits > 0 ? totalGradePoints / totalCredits : 0.0;
  }
}
```

#### Grade Analytics Service
```dart
class GradeAnalyticsService {
  
  static Future<GradeAnalytics> generateStudentAnalytics({
    required String studentId,
    required String classId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    // Get student grades for period
    final gradesSnapshot = await FirebaseFirestore.instance
        .collection('grades')
        .where('studentId', isEqualTo: studentId)
        .where('classId', isEqualTo: classId)
        .where('gradedAt', isGreaterThanOrEqualTo: periodStart)
        .where('gradedAt', isLessThanOrEqualTo: periodEnd)
        .get();
    
    final grades = gradesSnapshot.docs
        .map((doc) => Grade.fromFirestore(doc))
        .toList();
    
    // Get categories
    final categoriesSnapshot = await FirebaseFirestore.instance
        .collection('grade_categories')
        .where('classId', isEqualTo: classId)
        .get();
    
    final categories = categoriesSnapshot.docs
        .map((doc) => GradeCategory.fromFirestore(doc))
        .toList();
    
    // Calculate overall performance
    final overallGrade = GradeCalculationService.calculateFinalGrade(
      grades: grades,
      categories: categories,
      gradeScale: await _getGradeScale(classId),
    );
    
    // Calculate category performance
    final categoryPerformance = categories.map((category) {
      final categoryGrades = grades
          .where((g) => g.categoryId == category.id)
          .toList();
      
      final averageGrade = categoryGrades.isEmpty
          ? 0.0
          : GradeCalculationService.calculateCategoryAverage(
              grades: categoryGrades,
              category: category,
            );
      
      return CategoryPerformance(
        categoryId: category.id,
        categoryName: category.name,
        averageGrade: averageGrade,
        gradeCount: categoryGrades.length,
        trendDirection: _calculateTrend(categoryGrades),
      );
    }).toList();
    
    // Calculate weekly trends
    final weeklyTrends = await _calculateWeeklyTrends(
      grades, 
      periodStart, 
      periodEnd,
    );
    
    // Generate insights
    final insights = _generateInsights(
      grades: grades,
      categoryPerformance: categoryPerformance,
      weeklyTrends: weeklyTrends,
    );
    
    // Calculate statistics
    final statistics = _calculateStatistics(grades);
    
    // Get class ranking if available
    final classRanking = await _calculateClassRanking(
      studentId, 
      classId, 
      overallGrade.finalPercentage,
    );
    
    final analytics = GradeAnalytics(
      id: '${studentId}_${classId}_${DateTime.now().millisecondsSinceEpoch}',
      classId: classId,
      studentId: studentId,
      generatedAt: DateTime.now(),
      periodStart: periodStart,
      periodEnd: periodEnd,
      overallGPA: overallGrade.gradePoint,
      overallPercentage: overallGrade.finalPercentage,
      overallLetterGrade: overallGrade.letterGrade,
      categoryPerformance: categoryPerformance,
      weeklyTrends: weeklyTrends,
      classRanking: classRanking,
      insights: insights,
      statistics: statistics,
    );
    
    // Save analytics
    await FirebaseFirestore.instance
        .collection('grade_analytics')
        .doc(analytics.id)
        .set(analytics.toMap());
    
    return analytics;
  }
  
  static List<GradeInsight> _generateInsights({
    required List<Grade> grades,
    required List<CategoryPerformance> categoryPerformance,
    required List<WeeklyTrend> weeklyTrends,
  }) {
    final insights = <GradeInsight>[];
    
    // Strength identification
    final strongCategories = categoryPerformance
        .where((cp) => cp.averageGrade >= 90)
        .toList();
    
    if (strongCategories.isNotEmpty) {
      insights.add(GradeInsight(
        type: GradeInsightType.strength,
        title: 'Strong Performance Areas',
        description: 'Excellent performance in ${strongCategories.map((c) => c.categoryName).join(', ')}',
        actionItems: ['Continue current study methods', 'Consider peer tutoring opportunities'],
        priority: GradeInsightPriority.low,
      ));
    }
    
    // Concern identification
    final weakCategories = categoryPerformance
        .where((cp) => cp.averageGrade < 70)
        .toList();
    
    if (weakCategories.isNotEmpty) {
      insights.add(GradeInsight(
        type: GradeInsightType.concern,
        title: 'Areas Needing Attention',
        description: 'Below-average performance in ${weakCategories.map((c) => c.categoryName).join(', ')}',
        actionItems: [
          'Schedule study sessions for these topics',
          'Seek additional help from teacher',
          'Form study groups with classmates'
        ],
        priority: GradeInsightPriority.high,
      ));
    }
    
    // Trend analysis
    if (weeklyTrends.length >= 3) {
      final recentTrend = _analyzeTrend(weeklyTrends.take(3).toList());
      if (recentTrend == 'improving') {
        insights.add(GradeInsight(
          type: GradeInsightType.improvement,
          title: 'Improving Performance Trend',
          description: 'Grades have been consistently improving over the last few weeks',
          actionItems: ['Maintain current study habits', 'Track progress weekly'],
          priority: GradeInsightPriority.medium,
        ));
      }
    }
    
    return insights;
  }
}
```

## Performance Optimizations

### Efficient Grade Queries
```dart
class OptimizedGradeQueries {
  
  // Paginated grade loading
  static Future<List<Grade>> loadGradesPaginated({
    required String classId,
    String? studentId,
    DocumentSnapshot? lastDocument,
    int limit = 50,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection('grades')
        .where('classId', isEqualTo: classId)
        .orderBy('gradedAt', descending: true)
        .limit(limit);
    
    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Grade.fromFirestore(doc))
        .toList();
  }
  
  // Cached gradebook data
  static final Map<String, GradebookData> _gradebookCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  static Future<GradebookData> getGradebookData(String classId) async {
    final cacheKey = classId;
    final cachedTimestamp = _cacheTimestamps[cacheKey];
    
    // Check cache validity
    if (cachedTimestamp != null &&
        DateTime.now().difference(cachedTimestamp) < _cacheExpiry) {
      final cachedData = _gradebookCache[cacheKey];
      if (cachedData != null) return cachedData;
    }
    
    // Fetch fresh data
    final gradebookData = await _fetchGradebookData(classId);
    
    // Update cache
    _gradebookCache[cacheKey] = gradebookData;
    _cacheTimestamps[cacheKey] = DateTime.now();
    
    return gradebookData;
  }
  
  static Future<GradebookData> _fetchGradebookData(String classId) async {
    // Parallel data fetching
    final futures = await Future.wait([
      FirebaseFirestore.instance
          .collection('grades')
          .where('classId', isEqualTo: classId)
          .get(),
      FirebaseFirestore.instance
          .collection('grade_categories')
          .where('classId', isEqualTo: classId)
          .get(),
      FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('students')
          .get(),
    ]);
    
    final grades = futures[0].docs
        .map((doc) => Grade.fromFirestore(doc))
        .toList();
    
    final categories = futures[1].docs
        .map((doc) => GradeCategory.fromFirestore(doc))
        .toList();
    
    final students = futures[2].docs
        .map((doc) => StudentInfo.fromFirestore(doc))
        .toList();
    
    return GradebookData(
      grades: grades,
      categories: categories,
      students: students,
      lastUpdated: DateTime.now(),
    );
  }
}
```

## Testing Implementation

### Unit Testing
```dart
group('Grade Calculation Tests', () {
  test('should calculate simple average correctly', () {
    final grades = [
      Grade(percentage: 85.0),
      Grade(percentage: 90.0),
      Grade(percentage: 78.0),
    ];
    
    final category = GradeCategory(
      calculationMethod: GradeCategoryCalculation.average,
      dropLowest: 0,
    );
    
    final result = GradeCalculationService.calculateCategoryAverage(
      grades: grades,
      category: category,
    );
    
    expect(result, closeTo(84.33, 0.1));
  });
  
  test('should drop lowest grade when configured', () {
    final grades = [
      Grade(percentage: 85.0),
      Grade(percentage: 90.0),
      Grade(percentage: 60.0), // This should be dropped
    ];
    
    final category = GradeCategory(
      calculationMethod: GradeCategoryCalculation.average,
      dropLowest: 1,
    );
    
    final result = GradeCalculationService.calculateCategoryAverage(
      grades: grades,
      category: category,
    );
    
    expect(result, equals(87.5)); // (85 + 90) / 2
  });
  
  test('should calculate weighted final grade', () {
    final categories = [
      GradeCategory(id: 'homework', weight: 0.4),
      GradeCategory(id: 'tests', weight: 0.6),
    ];
    
    final grades = [
      Grade(categoryId: 'homework', percentage: 85.0),
      Grade(categoryId: 'homework', percentage: 90.0),
      Grade(categoryId: 'tests', percentage: 80.0),
      Grade(categoryId: 'tests', percentage: 85.0),
    ];
    
    final gradeScale = GradeScale.standardScale();
    
    final result = GradeCalculationService.calculateFinalGrade(
      grades: grades,
      categories: categories,
      gradeScale: gradeScale,
    );
    
    // Homework average: 87.5, weighted: 35.0
    // Tests average: 82.5, weighted: 49.5
    // Final: 84.5
    expect(result.finalPercentage, closeTo(84.5, 0.1));
  });
});
```

This comprehensive grading system provides robust grade management, calculation, and analytics capabilities essential for educational institutions while maintaining performance and scalability through optimized data structures and caching strategies.