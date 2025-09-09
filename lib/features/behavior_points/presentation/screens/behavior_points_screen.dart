import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../../shared/widgets/common/responsive_layout.dart';
import '../widgets/student_point_card.dart';
import '../widgets/behavior_assignment_popup.dart';
import '../providers/behavior_point_provider.dart';

/// Main screen for behavior points system showing class overview and student grid.
///
/// Features:
/// - Class total points display at the top
/// - Grid of student cards with names, avatars, and points
/// - Tap student cards to open behavior assignment popup
/// - View Reports button in app bar
/// - Mock data for testing purposes
class BehaviorPointsScreen extends StatefulWidget {
  const BehaviorPointsScreen({super.key});

  @override
  State<BehaviorPointsScreen> createState() => _BehaviorPointsScreenState();
}

class _BehaviorPointsScreenState extends State<BehaviorPointsScreen> {
  // Mock student data for testing (fallback when provider not available)
  List<StudentPointData> _mockStudents = [
    StudentPointData(
      id: '1',
      name: 'Emma Thompson',
      totalPoints: 85,
      avatarColor: Colors.purple,
    ),
    StudentPointData(
      id: '2',
      name: 'James Wilson',
      totalPoints: 72,
      avatarColor: Colors.blue,
    ),
    StudentPointData(
      id: '3',
      name: 'Sophia Garcia',
      totalPoints: 94,
      avatarColor: Colors.green,
    ),
    StudentPointData(
      id: '4',
      name: 'Michael Brown',
      totalPoints: 67,
      avatarColor: Colors.orange,
    ),
    StudentPointData(
      id: '5',
      name: 'Isabella Davis',
      totalPoints: 88,
      avatarColor: Colors.pink,
    ),
    StudentPointData(
      id: '6',
      name: 'William Johnson',
      totalPoints: 79,
      avatarColor: Colors.teal,
    ),
    StudentPointData(
      id: '7',
      name: 'Olivia Miller',
      totalPoints: 91,
      avatarColor: Colors.indigo,
    ),
    StudentPointData(
      id: '8',
      name: 'Alexander Lee',
      totalPoints: 58,
      avatarColor: Colors.red,
    ),
    StudentPointData(
      id: '9',
      name: 'Charlotte Wilson',
      totalPoints: 83,
      avatarColor: Colors.cyan,
    ),
    StudentPointData(
      id: '10',
      name: 'Benjamin Taylor',
      totalPoints: 76,
      avatarColor: Colors.amber,
    ),
  ];

  // Mock class data
  final String _className = 'Period 3 - Mathematics';
  bool _useProvider = false;

  @override
  void initState() {
    super.initState();
    // Initialize provider if available
    _initializeProvider();
  }

  void _initializeProvider() {
    try {
      final provider = context.read<BehaviorPointProvider>();
      _useProvider = true;
      // Load mock data for demonstration
      provider.loadBehaviorsForClass('demo_class_123');
      provider.loadBehaviorPointsForClass('demo_class_123');
    } catch (e) {
      // Provider not available, use mock data
      _useProvider = false;
    }
  }

  List<StudentPointData> get _students {
    if (_useProvider) {
      try {
        final provider = context.read<BehaviorPointProvider>();
        final summaries = provider.studentSummaries;
        final colors = [
          Colors.purple, Colors.blue, Colors.green, Colors.orange, Colors.pink,
          Colors.teal, Colors.indigo, Colors.red, Colors.cyan, Colors.amber
        ];
        
        return summaries.entries.map((entry) {
          final index = entry.key.hashCode % colors.length;
          return StudentPointData(
            id: entry.key,
            name: entry.value.studentName,
            totalPoints: entry.value.totalPoints,
            avatarColor: colors[index],
          );
        }).toList();
      } catch (e) {
        return _mockStudents;
      }
    }
    return _mockStudents;
  }

  int get _classTotalPoints {
    if (_useProvider) {
      try {
        final provider = context.read<BehaviorPointProvider>();
        return provider.calculateClassTotalPoints();
      } catch (e) {
        return _mockStudents.fold(0, (sum, student) => sum + student.totalPoints);
      }
    }
    return _mockStudents.fold(0, (sum, student) => sum + student.totalPoints);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Behavior Points',
      actions: [
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
            // Class Summary Header
            SliverToBoxAdapter(
              child: _buildClassSummary(theme),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),

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
                      '${_students.length} students',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),

            // Student Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85, // Slightly taller than wide
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final student = _students[index];
                    return StudentPointCard(
                      student: student,
                      onTap: () => _showBehaviorAssignmentPopup(student),
                    );
                  },
                  childCount: _students.length,
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the class summary header with total points and class info
  Widget _buildClassSummary(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class name
          Text(
            _className,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          
          // Points summary
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.star,
                  title: 'Total Points',
                  value: _classTotalPoints.toString(),
                  color: theme.colorScheme.primary,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.trending_up,
                  title: 'Average',
                  value: (_classTotalPoints / _students.length).round().toString(),
                  color: theme.colorScheme.secondary,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
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
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
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
    if (screenWidth > 1200) return 5; // Desktop
    if (screenWidth > 900) return 4;  // Tablet landscape
    if (screenWidth > 600) return 3;  // Tablet portrait
    return 2; // Mobile
  }

  /// Shows the behavior assignment popup for the selected student
  void _showBehaviorAssignmentPopup(StudentPointData student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BehaviorAssignmentPopup(
        student: student,
        onPointsAwarded: (points, behaviorType) {
          _awardPoints(student.id, points, behaviorType);
        },
      ),
    );
  }

  /// Awards points to a student and updates the UI
  void _awardPoints(String studentId, int points, String behaviorType) {
    if (_useProvider) {
      try {
        final provider = context.read<BehaviorPointProvider>();
        // Find matching behavior from the provider or create a custom one
        final behavior = provider.behaviors.firstWhere(
          (b) => b.name == behaviorType,
          orElse: () => provider.behaviors.first, // Fallback to first behavior
        );
        
        provider.awardPoints(
          studentId: studentId,
          behaviorId: behavior.id,
          points: points,
          customReason: behaviorType,
        );
      } catch (e) {
        debugPrint('Error awarding points via provider: $e');
        _awardPointsMock(studentId, points, behaviorType);
      }
    } else {
      _awardPointsMock(studentId, points, behaviorType);
    }
  }

  /// Mock version for when provider is not available
  void _awardPointsMock(String studentId, int points, String behaviorType) {
    setState(() {
      final studentIndex = _mockStudents.indexWhere((s) => s.id == studentId);
      if (studentIndex != -1) {
        _mockStudents[studentIndex] = _mockStudents[studentIndex].copyWith(
          totalPoints: _mockStudents[studentIndex].totalPoints + points,
        );
      }
    });

    // Show success message
    if (mounted) {
      final student = _students.firstWhere((s) => s.id == studentId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${points > 0 ? '+' : ''}$points points awarded to ${student.name} for $behaviorType',
          ),
          backgroundColor: points > 0 
              ? Colors.green.withOpacity(0.9)
              : Colors.orange.withOpacity(0.9),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Navigates to reports screen (placeholder)
  void _viewReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reports feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
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

  /// Determines if points are positive, neutral, or negative for color coding
  Color get pointsColor {
    if (totalPoints >= 80) return Colors.green;
    if (totalPoints >= 60) return Colors.orange;
    return Colors.red;
  }
}