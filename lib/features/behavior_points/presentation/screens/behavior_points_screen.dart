import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/logger_service.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';
import '../widgets/student_point_card.dart';
import '../widgets/behavior_assignment_popup.dart';
import '../widgets/behavior_history_panel.dart';
import '../providers/behavior_point_provider.dart';
import '../../../classes/presentation/providers/class_provider.dart';
import '../../../classes/domain/models/class_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Main screen for behavior points system showing class overview and student grid.
///
/// Features:
/// - Class total points display at the top
/// - Grid of student cards with names, avatars, and points
/// - Tap student cards to open behavior assignment popup
/// - View Reports button in app bar
/// - Class selector dropdown for switching between classes
class BehaviorPointsScreen extends StatefulWidget {
  const BehaviorPointsScreen({super.key});

  @override
  State<BehaviorPointsScreen> createState() => _BehaviorPointsScreenState();
}

class _BehaviorPointsScreenState extends State<BehaviorPointsScreen> {
  String? _selectedClassId;
  ClassModel? _selectedClass;
  bool _isInitialized = false;

  // History panel state
  bool _showHistoryPanel = false;
  PanelPosition _panelPosition = PanelPosition.right;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _initializeProvider();
      }
    });
  }

  void _initializeProvider() {
    if (_isInitialized) return;

    final authProvider = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final behaviorProvider = context.read<BehaviorPointProvider>();
    final teacherId =
        authProvider.firebaseUser?.uid ?? authProvider.userModel?.uid;

    if (teacherId != null) {
      _isInitialized = true;

      // Load teacher's classes
      classProvider.loadTeacherClasses(teacherId);

      // Set first class as selected if available
      if (classProvider.teacherClasses.isNotEmpty) {
        final firstClass = classProvider.teacherClasses.first;
        setState(() {
          _selectedClassId = firstClass.id;
          _selectedClass = firstClass;
        });

        behaviorProvider.loadBehaviorPointsForClass(firstClass.id);

        // Load students only once (removed duplicate call)
        classProvider.loadClassStudents(firstClass.id);
      }
    }
  }

  void _onClassChanged(String? classId) {
    if (classId == null) return;

    final classProvider = context.read<ClassProvider>();
    final behaviorProvider = context.read<BehaviorPointProvider>();

    final selectedClass = classProvider.teacherClasses.firstWhere(
      (c) => c.id == classId,
      orElse: () => classProvider.teacherClasses.first,
    );

    setState(() {
      _selectedClassId = classId;
      _selectedClass = selectedClass;
    });

    behaviorProvider.loadBehaviorPointsForClass(classId);

    // Load all students for the class (single source of truth)
    classProvider.loadClassStudents(classId);
  }

  List<StudentPointData> get _students {
    try {
      final classProvider = context.read<ClassProvider>();
      final behaviorProvider = context.read<BehaviorPointProvider>();
      final summaries = behaviorProvider.studentSummaries;
      final colors = [
        Colors.purple,
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.pink,
        Colors.teal,
        Colors.indigo,
        Colors.red,
        Colors.cyan,
        Colors.amber,
      ];

      // Get all enrolled students from the class
      final enrolledStudents = classProvider.classStudents;

      // Create a map of all students with their points (0 if no points)
      final studentDataList = <StudentPointData>[];

      for (final student in enrolledStudents) {
        final points = summaries[student.id]?.totalPoints ?? 0;
        final index = student.id.hashCode % colors.length;

        studentDataList.add(
          StudentPointData(
            id: student.id,
            name: student.displayName,
            totalPoints: points,
            avatarColor: colors[index],
          ),
        );
      }

      // Also add any students who have points but aren't in the enrolled list
      // (in case of data inconsistency)
      for (final entry in summaries.entries) {
        if (!studentDataList.any((s) => s.id == entry.key)) {
          final index = entry.key.hashCode % colors.length;
          studentDataList.add(
            StudentPointData(
              id: entry.key,
              name: entry.value.studentName,
              totalPoints: entry.value.totalPoints,
              avatarColor: colors[index],
            ),
          );
        }
      }

      return studentDataList;
    } catch (e) {
      return [];
    }
  }

  Map<String, int> _buildRankMap(List<StudentPointData> sortedStudents) {
    final ranks = <String, int>{};
    int processed = 0;
    int? previousPoints;
    int currentRank = 0;

    for (final student in sortedStudents) {
      if (student.totalPoints <= 0) {
        continue;
      }

      processed += 1;
      if (previousPoints == null || student.totalPoints != previousPoints) {
        currentRank = processed;
        previousPoints = student.totalPoints;
      }

      ranks[student.id] = currentRank;
    }

    return ranks;
  }

  int get _classTotalPoints {
    try {
      final provider = context.read<BehaviorPointProvider>();
      return provider.calculateClassTotalPoints();
    } catch (e) {
      return 0;
    }
  }

  String get _className {
    return _selectedClass?.name ?? 'Select a Class';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classProvider = context.watch<ClassProvider>();

    // Use Consumer to listen to provider changes
    return Consumer<BehaviorPointProvider>(
      builder: (context, provider, child) {
        // This check should only set the selected class if it's not already set
        // The data loading happens in _initializeProvider, not here
        if (_selectedClassId == null &&
            classProvider.teacherClasses.isNotEmpty &&
            !_isInitialized) {
          final firstClass = classProvider.teacherClasses.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedClassId = firstClass.id;
              _selectedClass = firstClass;
            });
          });
        }

        final students = _students;
        final sortedStudents = List<StudentPointData>.from(students)
          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
        final rankMap = _buildRankMap(sortedStudents);
        final totalPoints = _classTotalPoints;
        final averagePoints = students.isEmpty
            ? 0
            : (totalPoints / students.length).round();
        final positivePoints = provider.calculateClassPositivePoints();
        final negativePoints = provider.calculateClassNegativePoints();
        final trackedPoints = positivePoints + negativePoints;
        final positiveRate = trackedPoints == 0
            ? 0.0
            : (positivePoints / trackedPoints) * 100;
        final negativeRate = trackedPoints == 0
            ? 0.0
            : (negativePoints / trackedPoints) * 100;

        return Stack(
          children: [
            AdaptiveLayout(
              title: 'Behavior Points',
              actions: [
                // History panel toggle
                IconButton(
                  icon: Icon(_showHistoryPanel ? Icons.history : Icons.history_outlined),
                  onPressed: () {
                    setState(() {
                      _showHistoryPanel = !_showHistoryPanel;
                    });
                  },
                  tooltip: _showHistoryPanel ? 'Hide History' : 'Show History',
                ),
                // Panel position toggle
                if (_showHistoryPanel)
                  IconButton(
                    icon: Icon(
                      _panelPosition == PanelPosition.right
                          ? Icons.view_sidebar_rounded
                          : Icons.vertical_split,
                    ),
                    onPressed: () {
                      setState(() {
                        _panelPosition = _panelPosition == PanelPosition.right
                            ? PanelPosition.bottom
                            : PanelPosition.right;
                      });
                    },
                    tooltip: _panelPosition == PanelPosition.right
                        ? 'Move to Bottom'
                        : 'Move to Side',
                  ),
                TextButton.icon(
                  onPressed: _viewReports,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Reports'),
                ),
                const SizedBox(width: 8),
              ],
          body: ResponsiveContainer(
            child: CustomScrollView(
              slivers: [
                // Class Selector
                if (classProvider.teacherClasses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildClassSelector(theme, classProvider),
                  ),

                // Class Summary Header
                SliverToBoxAdapter(
                  child: _buildClassSummary(
                    theme,
                    totalPoints: totalPoints,
                    averagePoints: averagePoints,
                    positiveRate: positiveRate,
                    negativeRate: negativeRate,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Students Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Students',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${students.length} students',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Student Grid with Class Total Card
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(context),
                      crossAxisSpacing: 12, // Proper spacing between cards
                      mainAxisSpacing: 12, // Proper spacing between cards
                      childAspectRatio: 1.0, // SQUARE aspect ratio
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == 0) {
                        return _buildClassTotalCard(
                          theme,
                          totalPoints: totalPoints,
                          averagePoints: averagePoints,
                        );
                      }

                      final studentIndex = index - 1;
                      if (studentIndex >= sortedStudents.length) {
                        return const SizedBox.shrink();
                      }

                      final student = sortedStudents[studentIndex];
                      final rank = rankMap[student.id];

                      return StudentPointCard(
                        student: student,
                        rank: rank,
                        onTap: () => _showBehaviorAssignmentPopup(student),
                      );
                    }, childCount: sortedStudents.length + 1),
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
        // History Panel Overlay
        if (_showHistoryPanel && _selectedClassId != null)
          BehaviorHistoryPanel(
            classId: _selectedClassId!,
            position: _panelPosition,
            onClose: () {
              setState(() {
                _showHistoryPanel = false;
              });
            },
          ),
      ],
    );
      },
    );
  }

  /// Builds the class selector dropdown
  Widget _buildClassSelector(ThemeData theme, ClassProvider classProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            'Class:',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedClassId,
                hint: const Text('Select a class'),
                items: classProvider.teacherClasses.map((classModel) {
                  return DropdownMenuItem<String>(
                    value: classModel.id,
                    child: Text(
                      classModel.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onClassChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the class summary header with total points and class info
  Widget _buildClassSummary(
    ThemeData theme, {
    required int totalPoints,
    required int averagePoints,
    required double positiveRate,
    required double negativeRate,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class name
          Text(
            _className,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Points summary - First row with 2 cards
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: _buildSummaryCard(
                    icon: Icons.star,
                    title: 'Total Points',
                    value: totalPoints.toString(),
                    color: theme.colorScheme.primary,
                    theme: theme,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: _buildSummaryCard(
                    icon: Icons.trending_up,
                    title: 'Average',
                    value: averagePoints.toString(),
                    color: theme.colorScheme.secondary,
                    theme: theme,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row with 2 cards
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: _buildSummaryCard(
                    icon: Icons.thumb_up,
                    title: 'Positive Rate',
                    value: '${positiveRate.round()}%',
                    color: Colors.green,
                    theme: theme,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: _buildSummaryCard(
                    icon: Icons.thumb_down,
                    title: 'Negative Rate',
                    value: '${negativeRate.round()}%',
                    color: Colors.redAccent,
                    theme: theme,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the class total points card for the grid
  Widget _buildClassTotalCard(
    ThemeData theme, {
    required int totalPoints,
    required int averagePoints,
  }) {
    return Card(
      margin: const EdgeInsets.all(2), // Small margin for consistency with student cards
      elevation: 4,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.25),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.88), // Match student cards opacity
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.55), // Match student cards border opacity
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(8), // Same padding as student cards
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48, // Same as student cards
                    height: 48, // Same as student cards
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.27), // Match student cards avatar opacity
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.55), // Match student cards border opacity
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.groups,
                      color: theme.colorScheme.onPrimary,
                      size: 24, // Adjusted icon size to match container
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Same as student cards
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(10), // Rounded rect like student cards
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.error.withValues(alpha: 0.5), // Match student cards badge shadow
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          totalPoints.toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onError,
                            fontWeight: FontWeight.bold,
                            fontSize: 10, // Same as student cards
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4), // Same spacing as student cards
            Flexible(
              child: Text(
                'Whole Class',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  fontSize: 11, // Same text size as student cards
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds individual summary cards within the class summary
  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Determines the number of columns for the student grid based on screen size
  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1400) return 8; // Large desktop - fit 30+ students
    if (screenWidth > 1200) return 7; // Desktop
    if (screenWidth > 1000) return 6; // Small desktop
    if (screenWidth > 800) return 5; // Tablet landscape
    if (screenWidth > 600) return 4; // Tablet portrait
    if (screenWidth > 400) return 3; // Large mobile
    return 2; // Small mobile
  }

  /// Determines the aspect ratio for the student cards based on screen size

  /// Shows the behavior assignment popup for the selected student
  void _showBehaviorAssignmentPopup(StudentPointData student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BehaviorAssignmentPopup(
        student: student,
        onPointsAwarded: (points, behaviorType) {
          _awardPoints(student.id, student.name, points, behaviorType);
        },
      ),
    );
  }

  /// Awards points to a student and updates the UI
  void _awardPoints(
    String studentId,
    String studentName,
    int points,
    String behaviorType,
  ) {
    try {
      final provider = context.read<BehaviorPointProvider>();
      // Find matching behavior from the provider or create a custom one
      final behavior = provider.behaviors.firstWhere(
        (b) => b.name == behaviorType,
        orElse: () => provider.behaviors.first, // Fallback to first behavior
      );

      provider.awardPoints(
        studentId: studentId,
        studentName: studentName,
        behaviorId: behavior.id,
        points: points,
        reason: behaviorType,
      );
    } catch (e) {
      LoggerService.error('Error awarding points', error: e, tag: 'BehaviorPointsScreen');
    }
  }

  /// Navigates to reports screen
  void _viewReports() {
    context.push('/teacher/behavior-reports');
  }
}

/// Data model for student point information
class StudentPointData {
  final String id;
  final String name;
  final int totalPoints;
  final Color avatarColor;

  const StudentPointData({
    required this.id,
    required this.name,
    required this.totalPoints,
    required this.avatarColor,
  });

  /// Creates a copy of this student data with updated values
  StudentPointData copyWith({
    String? id,
    String? name,
    int? totalPoints,
    Color? avatarColor,
  }) {
    return StudentPointData(
      id: id ?? this.id,
      name: name ?? this.name,
      totalPoints: totalPoints ?? this.totalPoints,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  /// Gets initials from the student name for avatar display
  String get initials {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0].substring(0, names[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'S';
  }

  /// Formats the student's name as "First L" for card display.
  String get formattedName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final last = parts.last;
      final lastInitial = last.isNotEmpty ? last[0].toUpperCase() : '';
      return '${parts.first} $lastInitial';
    }
    return name;
  }

  /// Determines if points are positive, neutral, or negative for color coding
  Color get pointsColor {
    if (totalPoints >= 80) return Colors.green;
    if (totalPoints >= 60) return Colors.orange;
    return Colors.red;
  }
}
