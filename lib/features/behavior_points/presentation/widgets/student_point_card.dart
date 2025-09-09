import 'package:flutter/material.dart';
import '../screens/behavior_points_screen.dart';

/// Widget that displays a student's avatar, name, and points in a card format.
///
/// Features:
/// - Colorful circular avatar with student initials
/// - Student name with text overflow handling
/// - Points badge with color coding (green/yellow/red)
/// - Tap gesture support for opening behavior assignment
/// - Responsive design for different screen sizes
/// - Hover effects and accessibility support
class StudentPointCard extends StatelessWidget {
  /// Student data to display
  final StudentPointData student;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Creates a student point card widget
  const StudentPointCard({
    super.key,
    required this.student,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Student Avatar with Points Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Avatar Circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: student.avatarColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: student.avatarColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        student.initials,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: student.avatarColor,
                        ),
                      ),
                    ),
                  ),
                  
                  // Points Badge
                  Positioned(
                    top: -8,
                    right: -8,
                    child: _buildPointsBadge(theme),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Student Name
              Text(
                student.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Points Display
              Text(
                '${student.totalPoints} points',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: student.pointsColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Progress Indicator
              _buildProgressIndicator(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the points badge displayed on top of the avatar
  Widget _buildPointsBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: student.pointsColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: student.pointsColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        student.totalPoints.toString(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Builds a simple progress indicator bar based on points
  Widget _buildProgressIndicator(ThemeData theme) {
    // Calculate progress (assuming 100 is max for visualization)
    final maxPoints = 100.0;
    final progress = (student.totalPoints / maxPoints).clamp(0.0, 1.0);
    
    return Column(
      children: [
        // Progress bar
        Container(
          width: double.infinity,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: student.pointsColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Status text
        Text(
          _getStatusText(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// Gets status text based on points level
  String _getStatusText() {
    if (student.totalPoints >= 80) return 'Excellent';
    if (student.totalPoints >= 60) return 'Good';
    if (student.totalPoints >= 40) return 'Fair';
    return 'Needs Support';
  }
}

/// Compact version of the student card for smaller spaces
class StudentPointCardCompact extends StatelessWidget {
  /// Student data to display
  final StudentPointData student;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Creates a compact student point card widget
  const StudentPointCardCompact({
    super.key,
    required this.student,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: student.avatarColor.withOpacity(0.2),
              child: Text(
                student.initials,
                style: TextStyle(
                  color: student.avatarColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Mini points badge
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: student.pointsColor,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  student.totalPoints.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          student.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${student.totalPoints} points',
          style: TextStyle(
            color: student.pointsColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}