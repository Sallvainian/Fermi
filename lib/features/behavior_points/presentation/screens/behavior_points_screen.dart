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

    // Use Consumer to listen to provider changes
    return Consumer<BehaviorPointProvider>(
      builder: (context, provider, child) {
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

            // Student Grid with Class Total Card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 8,  // Reduced from 16
                  mainAxisSpacing: 8,   // Reduced from 16
                  childAspectRatio: _getAspectRatio(context), // Responsive aspect ratio
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Sort students by points (descending) for ranking
                    final sortedStudents = List<StudentPointData>.from(_students)
                      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
                    
                    // First card is the class total
                    if (index == 0) {
                      return _buildClassTotalCard(theme);
                    }
                    // Adjust index for students
                    final studentIndex = index - 1;
                    final student = sortedStudents[studentIndex];
                    
                    // Calculate rank (accounting for ties)
                    int rank = 1;
                    for (int i = 0; i < sortedStudents.length; i++) {
                      if (sortedStudents[i].totalPoints > student.totalPoints) {
                        rank++;
                      }
                    }
                    
                    return StudentPointCard(
                      student: student,
                      rank: rank,
                      onTap: () => _showBehaviorAssignmentPopup(student),
                    );
                  },
                  childCount: _students.length + 1, // Add 1 for class total card
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
      },
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

  /// Builds the class total points card for the grid
  Widget _buildClassTotalCard(ThemeData theme) {
    final totalPoints = _classTotalPoints;
    final avgPoints = _students.isNotEmpty ? (totalPoints / _students.length).round() : 0;
    
    return Card(
      elevation: 4,
      shadowColor: theme.colorScheme.primary.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.primaryContainer.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8), // Reduced padding
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Class icon
              Container(
                width: 48,  // Reduced from 60 to match student cards
                height: 48, // Reduced from 60 to match student cards
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups,
                  size: 24,  // Reduced from 32
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6), // Reduced from 8
              // Label
              Text(
                'Whole Class',
                style: theme.textTheme.bodySmall?.copyWith( // Changed from titleMedium
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 11, // Explicit smaller size
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2), // Reduced from 4
              // Total points
              Text(
                '$totalPoints',
                style: theme.textTheme.titleMedium?.copyWith( // Changed from headlineMedium
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontSize: 16, // Explicit size
                ),
              ),
              Text(
                'points',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  fontSize: 10, // Explicit smaller size
                ),
              ),
              const SizedBox(height: 4), // Reduced from 8
              // Average badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced padding
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Avg: $avgPoints',
                  style: theme.textTheme.labelSmall?.copyWith( // Changed to labelSmall
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.secondary,
                    fontSize: 11, // Explicit size
                  ),
                ),
              ),
            ],
          ),
        ),
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
    if (screenWidth > 1400) return 8; // Large desktop - fit 30+ students
    if (screenWidth > 1200) return 7; // Desktop
    if (screenWidth > 1000) return 6; // Small desktop
    if (screenWidth > 800) return 5;  // Tablet landscape
    if (screenWidth > 600) return 4;  // Tablet portrait
    if (screenWidth > 400) return 3;  // Large mobile
    return 2; // Small mobile
  }

  /// Determines the aspect ratio for the student cards based on screen size
  /// Provides more vertical space for card content on smaller screens
  double _getAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 0.85; // Desktop - slightly taller than square
    if (screenWidth > 800) return 0.8;   // Tablet - more vertical space
    if (screenWidth > 600) return 0.75;  // Small tablet
    return 0.7; // Mobile - maximum vertical space for all content
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