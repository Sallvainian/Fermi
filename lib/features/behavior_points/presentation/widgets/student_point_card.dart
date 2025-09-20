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
      margin: const EdgeInsets.all(2), // Small margin for visual separation
      elevation: isFirstPlace ? 8 : 2,
      shadowColor: isFirstPlace
          ? Colors.amber.withValues(alpha: 0.5)
          : theme.colorScheme.shadow.withValues(alpha: 0.25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: isTopThree
                  ? Border.all(
                      color: rank == 1
                          ? Colors.amber
                          : rank == 2
                              ? Colors.grey[400]!
                              : Colors.orange[700]!,
                      width: 2,
                    )
                  : Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.27,
                      ),
                      width: 1,
                    ),
            boxShadow: isFirstPlace
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(8), // Reduced padding to give more space for content
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Student Avatar with Points Badge - wrapped in Flexible to prevent overflow
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48, // Reduced size to fit better in card
                      height: 48, // Reduced size to fit better in card
                      decoration: BoxDecoration(
                        color: student.avatarColor.withValues(alpha: 0.27),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: student.avatarColor.withValues(alpha: 0.55),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          student.initials,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            fontSize: 16, // Reduced font size to match smaller circle
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: _buildPointsBadge(theme),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4), // Reduced spacing

              // Student Name - wrapped in Flexible to prevent overflow
              Flexible(
                child: Text(
                  student.formattedName,
                  textAlign: TextAlign.center,
                  maxLines: 2, // Allow 2 lines
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith( // Changed to bodySmall
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontSize: 11, // Smaller text to fit better
                  ),
                ),
              ),

              if (rank != null) ...[
                const SizedBox(height: 2), // Minimal spacing for rank
                Flexible(
                  child: _buildRankingDisplay(theme),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the points badge displayed on top of the avatar
  Widget _buildPointsBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(10), // Changed from circle to rounded rect for better fit
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.error.withValues(alpha: 0.5),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
      child: Center(
        child: Text(
          student.totalPoints.toString(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onError,
            fontWeight: FontWeight.bold,
            fontSize: 10, // Slightly bigger text
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ), // Minimal padding to prevent overflow
      decoration: BoxDecoration(
        color: rank! <= 3
            ? rankColor.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: rank! <= 3
            ? Border.all(color: rankColor.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (rankIcon != null) ...[
            Icon(
              rankIcon,
              size: 12, // Smaller icon
              color: rankColor,
            ),
            const SizedBox(width: 1), // Minimal spacing
          ],
          Text(
            rankText,
            style: theme.textTheme.labelSmall?.copyWith(
              // Changed to labelSmall
              color: rankColor,
              fontWeight: rank! <= 3 ? FontWeight.bold : FontWeight.w500,
              fontSize: 10, // Even smaller for rank text
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
  const StudentPointCardCompact({super.key, required this.student, this.onTap});

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
              backgroundColor: student.avatarColor.withValues(alpha: 0.2),
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
