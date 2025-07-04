import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/common/common_widgets.dart';
import '../../../theme/app_theme.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  String _searchQuery = '';
  final bool _isLoading = false;

  // Hardcoded class data for demonstration
  final List<ClassData> _classes = [
    ClassData(
      id: '1',
      name: 'Advanced Mathematics',
      subject: 'Mathematics',
      studentCount: 28,
      schedule: 'Mon, Wed, Fri - 9:00 AM',
      room: 'Room 204',
      gradeLevel: '11th Grade',
      averageGrade: 'B+',
      nextAssignment: 'Calculus Quiz - Due Tomorrow',
      recentActivity: '3 new submissions',
      color: AppTheme.subjectColors[0], // Blue for Math
    ),
    ClassData(
      id: '2',
      name: 'Biology Lab',
      subject: 'Science',
      studentCount: 24,
      schedule: 'Tue, Thu - 2:00 PM',
      room: 'Lab 105',
      gradeLevel: '10th Grade',
      averageGrade: 'A-',
      nextAssignment: 'Cell Division Report - Due Friday',
      recentActivity: '5 students need feedback',
      color: AppTheme.subjectColors[1], // Green for Science
    ),
    ClassData(
      id: '3',
      name: 'Creative Writing',
      subject: 'English',
      studentCount: 22,
      schedule: 'Mon, Wed - 11:00 AM',
      room: 'Room 108',
      gradeLevel: '9th Grade',
      averageGrade: 'B',
      nextAssignment: 'Poetry Assignment - Due Next Week',
      recentActivity: '2 late submissions',
      color: AppTheme.subjectColors[2], // Orange for English
    ),
    ClassData(
      id: '4',
      name: 'World History',
      subject: 'Social Studies',
      studentCount: 30,
      schedule: 'Daily - 1:00 PM',
      room: 'Room 302',
      gradeLevel: '10th Grade',
      averageGrade: 'B-',
      nextAssignment: 'Renaissance Essay - Due Monday',
      recentActivity: '12 graded papers ready',
      color: AppTheme.subjectColors[3], // Purple for History
    ),
    ClassData(
      id: '5',
      name: 'AP Physics',
      subject: 'Physics',
      studentCount: 18,
      schedule: 'Mon, Wed, Fri - 3:00 PM',
      room: 'Lab 203',
      gradeLevel: '12th Grade',
      averageGrade: 'A',
      nextAssignment: 'Quantum Mechanics Test - Next Friday',
      recentActivity: 'All caught up',
      color: AppTheme.subjectColors[1], // Green for Science
    ),
  ];

  List<ClassData> get _filteredClasses {
    if (_searchQuery.isEmpty) return _classes;
    return _classes.where((classData) {
      return classData.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             classData.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             classData.gradeLevel.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back to Dashboard',
        ),
        title: const Text('My Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateClassDialog,
            tooltip: 'Add Class',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with stats
          _buildStatsHeader(),
          
          // Search bar
          _buildSearchBar(),
          
          // Classes list
          Expanded(
            child: _isLoading
                ? const EmptyState(
                    icon: Icons.class_,
                    title: 'Loading Classes',
                    message: 'Please wait...',
                    isLoading: true,
                  )
                : _filteredClasses.isEmpty
                    ? _searchQuery.isNotEmpty
                        ? EmptyState.noSearchResults(searchTerm: _searchQuery)
                        : const EmptyState.noClasses()
                    : _buildClassesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateClassDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalStudents = _classes.fold<int>(0, (sum, classData) => sum + classData.studentCount);
    final avgGradePoints = _calculateAverageGradePoints();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: 'Classes',
              value: '${_classes.length}',
              icon: Icons.class_,
              subtitle: 'Active',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Students',
              value: '$totalStudents',
              icon: Icons.people,
              subtitle: 'Total',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Avg Grade',
              value: _getLetterGrade(avgGradePoints),
              icon: Icons.grade,
              valueColor: AppTheme.getGradeColor(_getLetterGrade(avgGradePoints)),
              subtitle: 'Overall',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search classes...',
          hintStyle: Theme.of(context).textTheme.bodyMedium,
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: Theme.of(context).textTheme.bodyMedium,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildClassesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredClasses.length,
      itemBuilder: (context, index) {
        final classData = _filteredClasses[index];
        return _buildClassCard(classData);
      },
    );
  }

  Widget _buildClassCard(ClassData classData) {
    return AppCard(
      onTap: () => _navigateToClassDetail(classData),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with class name and grade
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: classData.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classData.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${classData.subject} • ${classData.gradeLevel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.grade(grade: classData.averageGrade),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Info row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(Icons.people, '${classData.studentCount} students'),
              _buildInfoChip(Icons.room, classData.room),
              _buildInfoChip(Icons.schedule, classData.schedule),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Next assignment
          if (classData.nextAssignment != null) ...[
            Row(
              children: [
                Icon(
                  Icons.assignment,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    classData.nextAssignment!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          // Recent activity
          if (classData.recentActivity != null) ...[
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  classData.recentActivity!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAverageGradePoints() {
    if (_classes.isEmpty) return 0.0;
    
    double totalPoints = 0;
    for (final classData in _classes) {
      totalPoints += _gradeToPoints(classData.averageGrade);
    }
    return totalPoints / _classes.length;
  }

  double _gradeToPoints(String grade) {
    switch (grade.toUpperCase()) {
      case 'A+': return 4.3;
      case 'A': return 4.0;
      case 'A-': return 3.7;
      case 'B+': return 3.3;
      case 'B': return 3.0;
      case 'B-': return 2.7;
      case 'C+': return 2.3;
      case 'C': return 2.0;
      case 'C-': return 1.7;
      case 'D+': return 1.3;
      case 'D': return 1.0;
      case 'D-': return 0.7;
      case 'F': return 0.0;
      default: return 0.0;
    }
  }

  String _getLetterGrade(double points) {
    if (points >= 4.2) return 'A+';
    if (points >= 3.85) return 'A';
    if (points >= 3.5) return 'A-';
    if (points >= 3.15) return 'B+';
    if (points >= 2.85) return 'B';
    if (points >= 2.5) return 'B-';
    if (points >= 2.15) return 'C+';
    if (points >= 1.85) return 'C';
    if (points >= 1.5) return 'C-';
    if (points >= 1.15) return 'D+';
    if (points >= 0.85) return 'D';
    if (points >= 0.5) return 'D-';
    return 'F';
  }

  void _navigateToClassDetail(ClassData classData) {
    // TODO: Navigate to class detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${classData.name}...'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showCreateClassDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Class'),
        content: const Text('Class creation dialog would appear here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon!')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// Data model for class information
class ClassData {
  final String id;
  final String name;
  final String subject;
  final int studentCount;
  final String schedule;
  final String room;
  final String gradeLevel;
  final String averageGrade;
  final String? nextAssignment;
  final String? recentActivity;
  final Color color;

  ClassData({
    required this.id,
    required this.name,
    required this.subject,
    required this.studentCount,
    required this.schedule,
    required this.room,
    required this.gradeLevel,
    required this.averageGrade,
    this.nextAssignment,
    this.recentActivity,
    required this.color,
  });
}