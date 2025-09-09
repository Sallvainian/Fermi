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
/// - Ranking display with special effects for top performers
class StudentPointCard extends StatelessWidget {
  /// Student data to display
  final StudentPointData student;
  
  /// Student's rank in the class (1 = first place)
  final int? rank;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Creates a student point card widget
  const StudentPointCard({
    super.key,
    required this.student,
    this.rank,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFirstPlace = rank == 1;
    final isTopThree = rank != null && rank! <= 3;
    
    return Card(
      elevation: isFirstPlace ? 8 : 2,
      shadowColor: isFirstPlace 
          ? Colors.amber.withOpacity(0.5) 
          : theme.colorScheme.shadow.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isTopThree ? Border.all(
            color: rank == 1 
                ? Colors.amber 
                : rank == 2 
                    ? Colors.grey[400]! 
                    : Colors.orange[700]!,
            width: 2,
          ) : null,
          boxShadow: isFirstPlace ? [
            BoxShadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.amber.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 3,
            ),
          ] : null,
        ),
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
              
              // Ranking Display
              if (rank != null) _buildRankingDisplay(theme),
            ],
          ),
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

  /// Builds the ranking display widget
  Widget _buildRankingDisplay(ThemeData theme) {
    String rankText;
    Color rankColor;
    IconData? rankIcon;
    
    switch (rank) {
      case 1:
        rankText = '1st';
        rankColor = Colors.amber;
        rankIcon = Icons.emoji_events; // Trophy icon
        break;
      case 2:
        rankText = '2nd';
        rankColor = Colors.grey[600]!;
        rankIcon = Icons.workspace_premium;
        break;
      case 3:
        rankText = '3rd';
        rankColor = Colors.orange[700]!;
        rankIcon = Icons.military_tech;
        break;
      default:
        rankText = _getOrdinal(rank!);
        rankColor = theme.colorScheme.onSurfaceVariant;
        rankIcon = null;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: rank! <= 3 ? rankColor.withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: rank! <= 3 ? Border.all(
          color: rankColor.withOpacity(0.3),
          width: 1,
        ) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (rankIcon != null) ...[
            Icon(
              rankIcon,
              size: 16,
              color: rankColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            rankText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: rankColor,
              fontWeight: rank! <= 3 ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Converts a number to ordinal format (1st, 2nd, 3rd, 4th, etc.)
  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
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