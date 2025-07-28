import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import '../../widgets/create_class_dialog.dart';
import '../../widgets/edit_class_dialog.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../domain/models/class_model.dart';
import '../../providers/class_provider.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    // Load classes when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
  }
  
  Future<void> _loadClasses() async {
    final authProvider = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    
    if (authProvider.userModel != null) {
      await classProvider.loadTeacherClasses(authProvider.userModel!.uid);
    }
  }

  Color _getSubjectColor(String subject) {
    // Map subjects to consistent colors
    final subjectMap = {
      'Mathematics': AppTheme.subjectColors[0],
      'Science': AppTheme.subjectColors[1],
      'Biology': AppTheme.subjectColors[1],
      'Chemistry': AppTheme.subjectColors[1],
      'Physics': AppTheme.subjectColors[1],
      'English': AppTheme.subjectColors[2],
      'Social Studies': AppTheme.subjectColors[3],
      'History': AppTheme.subjectColors[3],
      'Computer Science': AppTheme.subjectColors[4],
      'Art': AppTheme.subjectColors[5],
      'Music': AppTheme.subjectColors[6],
      'Physical Education': AppTheme.subjectColors[7],
    };
    
    return subjectMap[subject] ?? AppTheme.subjectColors[0];
  }

  List<ClassModel> _getFilteredClasses(List<ClassModel> classes) {
    if (_searchQuery.isEmpty) return classes;
    return classes.where((classModel) {
      return classModel.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             classModel.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             classModel.gradeLevel.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassProvider>(
      builder: (context, classProvider, _) {
        final filteredClasses = _getFilteredClasses(classProvider.teacherClasses);
        
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
              _buildStatsHeader(classProvider),
              
              // Search bar
              _buildSearchBar(),
              
              // Classes list
              Expanded(
                child: classProvider.isLoading
                    ? const EmptyState(
                        icon: Icons.class_,
                        title: 'Loading Classes',
                        message: 'Please wait...',
                        isLoading: true,
                      )
                    : filteredClasses.isEmpty
                        ? _searchQuery.isNotEmpty
                            ? EmptyState.noSearchResults(searchTerm: _searchQuery)
                            : const EmptyState.noClasses()
                        : _buildClassesList(filteredClasses),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateClassDialog,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildStatsHeader(ClassProvider classProvider) {
    final classes = classProvider.teacherClasses;
    final totalStudents = classes.fold<int>(0, (sum, classModel) => sum + classModel.studentCount);
    // For now, we'll use a placeholder for average grade since we don't have grade data yet
    const avgGrade = 'B+';
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: 'Classes',
              value: '${classes.length}',
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
              value: avgGrade,
              icon: Icons.grade,
              valueColor: AppTheme.getGradeColor(avgGrade),
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

  Widget _buildClassesList(List<ClassModel> classes) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classModel = classes[index];
        return _buildClassCard(classModel);
      },
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return AppCard(
      onTap: () => _navigateToClassDetail(classModel),
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
                  color: _getSubjectColor(classModel.subject),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classModel.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${classModel.subject} • ${classModel.gradeLevel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Enrollment code badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      classModel.enrollmentCode ?? 'No Code',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Info row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(Icons.people, '${classModel.studentCount} students'),
              if (classModel.room != null) _buildInfoChip(Icons.room, classModel.room!),
              if (classModel.schedule != null) _buildInfoChip(Icons.schedule, classModel.schedule!),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _showEditClassDialog(classModel),
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Class',
              ),
              TextButton.icon(
                onPressed: () => _copyEnrollmentCode(classModel.enrollmentCode ?? ''),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Code'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _navigateToClassDetail(classModel),
                child: const Text('View Details'),
              ),
            ],
          ),
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

  void _copyEnrollmentCode(String code) {
    if (code.isEmpty) return;
    
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enrollment code $code copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToClassDetail(ClassModel classModel) {
    context.push('/class/${classModel.id}');
  }

  void _showCreateClassDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateClassDialog(),
    ).then((result) {
      if (result == true) {
        // Class was created successfully, reload data
        _loadClasses();
      }
    });
  }

  void _showEditClassDialog(ClassModel classModel) {
    showDialog(
      context: context,
      builder: (context) => EditClassDialog(classModel: classModel),
    ).then((result) {
      if (result == true) {
        // Class was updated or deleted successfully, reload data
        _loadClasses();
      }
    });
  }
}