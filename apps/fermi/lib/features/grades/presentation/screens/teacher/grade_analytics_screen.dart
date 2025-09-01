import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/grade_analytics_provider.dart';
import '../../../domain/models/grade_analytics.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../../shared/widgets/common/responsive_layout.dart';
import '../../../../../features/classes/presentation/providers/class_provider.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';

class GradeAnalyticsScreen extends StatefulWidget {
  final String? classId;

  const GradeAnalyticsScreen({super.key, this.classId});

  @override
  State<GradeAnalyticsScreen> createState() => _GradeAnalyticsScreenState();
}

class _GradeAnalyticsScreenState extends State<GradeAnalyticsScreen> {
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.classId;

    // Load analytics and classes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final analyticsProvider = context.read<GradeAnalyticsProvider>();

    // Load teacher's classes
    if (authProvider.userModel != null) {
      classProvider.loadTeacherClasses(authProvider.userModel!.uid);
    }

    // Load analytics for selected class
    if (_selectedClassId != null) {
      analyticsProvider.loadClassAnalytics(_selectedClassId!);
    } else if (classProvider.teacherClasses.isNotEmpty) {
      // Auto-select first class if none specified
      _selectedClassId = classProvider.teacherClasses.first.id;
      analyticsProvider.loadClassAnalytics(_selectedClassId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = context.watch<GradeAnalyticsProvider>();

    return AdaptiveLayout(
      title: 'Grade Analytics',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            if (_selectedClassId != null) {
              analyticsProvider.refreshClassAnalytics(_selectedClassId!);
            }
          },
        ),
        PopupMenuButton<int>(
          icon: const Icon(Icons.date_range),
          onSelected: (days) {
            analyticsProvider.updateTrendDays(days);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 7, child: Text('Last 7 days')),
            const PopupMenuItem(value: 30, child: Text('Last 30 days')),
            const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            const PopupMenuItem(value: 180, child: Text('Last 6 months')),
          ],
        ),
      ],
      body: Column(
        children: [
          // Class selector
          Consumer<ClassProvider>(
            builder: (context, classProvider, _) {
              final classes = classProvider.teacherClasses;

              // Ensure selected class is valid
              if (_selectedClassId != null &&
                  !classes.any((c) => c.id == _selectedClassId)) {
                _selectedClassId = classes.isNotEmpty ? classes.first.id : null;
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Select Class',
                    border: OutlineInputBorder(),
                  ),
                  items: classes.map((classModel) {
                    return DropdownMenuItem(
                      value: classModel.id,
                      child: Text('${classModel.name} - ${classModel.subject}'),
                    );
                  }).toList(),
                  onChanged: classes.isEmpty
                      ? null
                      : (classId) {
                          setState(() {
                            _selectedClassId = classId;
                          });
                          if (classId != null) {
                            analyticsProvider.loadClassAnalytics(classId);
                          }
                        },
                  hint: classes.isEmpty
                      ? const Text('No classes available')
                      : const Text('Select a class'),
                ),
              );
            },
          ),
          Expanded(
            child: _selectedClassId != null
                ? _buildClassAnalytics(context, _selectedClassId!)
                : _buildOverviewAnalytics(context),
          ),
        ],
      ),
    );
  }

  Widget _buildClassAnalytics(BuildContext context, String classId) {
    final analyticsProvider = context.watch<GradeAnalyticsProvider>();
    final analytics = analyticsProvider.getClassAnalytics(classId);
    final trends = analyticsProvider.getClassTrends(classId);
    final isLoading = analyticsProvider.isLoading(classId);
    final error = analyticsProvider.getError(classId);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => analyticsProvider.refreshClassAnalytics(classId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (analytics == null) {
      return const Center(child: Text('No analytics data available'));
    }

    return ResponsiveContainer(
      child: RefreshIndicator(
        onRefresh: () => analyticsProvider.refreshClassAnalytics(classId),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildSummaryCards(analytics),
              const SizedBox(height: 24),

              // Grade Distribution Chart
              _buildSectionTitle('Grade Distribution'),
              const SizedBox(height: 16),
              _buildGradeDistributionChart(analytics),
              const SizedBox(height: 32),

              // Performance Trend Chart
              if (trends != null && trends.isNotEmpty) ...[
                _buildSectionTitle('Performance Trend'),
                const SizedBox(height: 16),
                _buildTrendChart(trends),
                const SizedBox(height: 32),
              ],

              // Category Performance
              _buildSectionTitle('Performance by Category'),
              const SizedBox(height: 16),
              _buildCategoryPerformanceChart(analytics),
              const SizedBox(height: 32),

              // Student Performance Table
              _buildSectionTitle('Student Performance'),
              const SizedBox(height: 16),
              _buildStudentPerformanceTable(analytics),
              const SizedBox(height: 32),

              // Assignment Statistics
              _buildSectionTitle('Assignment Statistics'),
              const SizedBox(height: 16),
              _buildAssignmentStatsTable(analytics),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewAnalytics(BuildContext context) {
    // Implementation for overview across all classes
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Grade Analytics Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
              'Select a class from the dropdown to view detailed analytics'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // For testing, load analytics for a hardcoded class
              context
                  .read<GradeAnalyticsProvider>()
                  .loadClassAnalytics('test-class-1');
            },
            child: const Text('Load Test Analytics'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildSummaryCards(GradeAnalytics analytics) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildSummaryCard(
          'Class Average',
          '${analytics.averageGrade.toStringAsFixed(1)}%',
          analytics.averageLetterGrade,
          Icons.grade,
          _getGradeColor(analytics.averageLetterGrade),
        ),
        _buildSummaryCard(
          'Completion Rate',
          '${analytics.completionRate.toStringAsFixed(0)}%',
          '${analytics.gradedAssignments}/${analytics.totalAssignments}',
          Icons.assignment_turned_in,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Pending Grading',
          analytics.pendingSubmissions.toString(),
          'Submissions',
          Icons.pending_actions,
          Colors.orange,
        ),
        _buildSummaryCard(
          'At-Risk Students',
          analytics.studentPerformances
              .where((s) => s.riskLevel == 'at-risk')
              .length
              .toString(),
          'Students',
          Icons.warning,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionChart(GradeAnalytics analytics) {
    final distribution = analytics.gradeDistributionPercentages;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: distribution.values.isEmpty
              ? 100
              : distribution.values.reduce((a, b) => a > b ? a : b) * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final grade = ['A', 'B', 'C', 'D', 'F'][groupIndex];
                return BarTooltipItem(
                  '$grade\n${rod.toY.toStringAsFixed(1)}%',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const grades = ['A', 'B', 'C', 'D', 'F'];
                  return Text(
                    grades[value.toInt() % grades.length],
                    style: const TextStyle(fontSize: 14),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _createGradeDistributionBars(distribution),
        ),
      ),
    );
  }

  List<BarChartGroupData> _createGradeDistributionBars(
      Map<String, double> distribution) {
    final grades = ['A', 'B', 'C', 'D', 'F'];
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.yellow[700]!,
      Colors.orange,
      Colors.red,
    ];

    return List.generate(grades.length, (index) {
      final grade = grades[index];
      double percentage = 0;

      // Sum all sub-grades for main grade
      distribution.forEach((key, value) {
        if (key.startsWith(grade)) {
          percentage += value;
        }
      });

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: percentage,
            color: colors[index],
            width: 40,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });
  }

  Widget _buildTrendChart(List<GradeTrend> trends) {
    if (trends.isEmpty) return const SizedBox();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Theme.of(context).colorScheme.outline.withAlpha(26),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Theme.of(context).colorScheme.outline.withAlpha(26),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < trends.length) {
                    final date = trends[value.toInt()].date;
                    return Text(
                      '${date.month}/${date.day}',
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withAlpha(51),
            ),
          ),
          minX: 0,
          maxX: trends.length - 1,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: trends.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.averageGrade);
              }).toList(),
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withAlpha(51),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPerformanceChart(GradeAnalytics analytics) {
    final categories = analytics.categoryAverages;

    if (categories.isEmpty) {
      return const Center(child: Text('No category data available'));
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final category = categories.keys.toList()[groupIndex];
                return BarTooltipItem(
                  '$category\n${rod.toY.toStringAsFixed(1)}%',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < categories.length) {
                    final category = categories.keys.toList()[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        category.length > 10
                            ? '${category.substring(0, 10)}...'
                            : category,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: categories.entries.toList().asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  color: _getCategoryColor(entry.value.value),
                  width: 30,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStudentPerformanceTable(GradeAnalytics analytics) {
    final students =
        List<StudentPerformance>.from(analytics.studentPerformances)
          ..sort((a, b) => b.averageGrade.compareTo(a.averageGrade));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Average')),
            DataColumn(label: Text('Grade')),
            DataColumn(label: Text('Completed')),
            DataColumn(label: Text('Missing')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Trend')),
          ],
          rows: students.map((student) {
            return DataRow(
              cells: [
                DataCell(Text(student.studentName)),
                DataCell(Text('${student.averageGrade.toStringAsFixed(1)}%')),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getGradeColor(student.letterGrade).withAlpha(51),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      student.letterGrade,
                      style: TextStyle(
                        color: _getGradeColor(student.letterGrade),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(student.completedAssignments.toString())),
                DataCell(Text(student.missingAssignments.toString())),
                DataCell(
                  _buildRiskBadge(student.riskLevel),
                ),
                DataCell(
                  Row(
                    children: [
                      Icon(
                        student.trend > 0
                            ? Icons.trending_up
                            : student.trend < 0
                                ? Icons.trending_down
                                : Icons.trending_flat,
                        color: student.trend > 0
                            ? Colors.green
                            : student.trend < 0
                                ? Colors.red
                                : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${student.trend > 0 ? '+' : ''}${student.trend.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: student.trend > 0
                              ? Colors.green
                              : student.trend < 0
                                  ? Colors.red
                                  : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAssignmentStatsTable(GradeAnalytics analytics) {
    final assignments = List<AssignmentStats>.from(analytics.assignmentStats)
      ..sort((a, b) => a.averageScore.compareTo(b.averageScore));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Assignment')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Average')),
            DataColumn(label: Text('Median')),
            DataColumn(label: Text('Range')),
            DataColumn(label: Text('Submissions')),
            DataColumn(label: Text('Difficulty')),
          ],
          rows: assignments.map((assignment) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      assignment.assignmentTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(assignment.category)),
                DataCell(
                    Text('${assignment.averageScore.toStringAsFixed(1)}%')),
                DataCell(Text('${assignment.medianScore.toStringAsFixed(1)}%')),
                DataCell(Text(
                    '${assignment.minScore.toStringAsFixed(0)}-${assignment.maxScore.toStringAsFixed(0)}%')),
                DataCell(Text(
                    '${assignment.gradedSubmissions}/${assignment.totalSubmissions}')),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(assignment.difficultyLevel)
                          .withAlpha(51),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      assignment.difficultyLevel.toUpperCase(),
                      style: TextStyle(
                        color: _getDifficultyColor(assignment.difficultyLevel),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    Color color;
    IconData icon;

    switch (riskLevel) {
      case 'at-risk':
        color = Colors.red;
        icon = Icons.warning;
        break;
      case 'warning':
        color = Colors.orange;
        icon = Icons.error_outline;
        break;
      default:
        color = Colors.green;
        icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            riskLevel.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return Colors.blue;
    if (grade.startsWith('C')) return Colors.yellow[700]!;
    if (grade.startsWith('D')) return Colors.orange;
    return Colors.red;
  }

  Color _getCategoryColor(double average) {
    if (average >= 90) return Colors.green;
    if (average >= 80) return Colors.blue;
    if (average >= 70) return Colors.yellow[700]!;
    if (average >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
