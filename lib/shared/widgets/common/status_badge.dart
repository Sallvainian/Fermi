import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Badge component for displaying status information with appropriate colors
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final String? customType;
  final Color? customColor;
  final IconData? icon;
  final bool isSmall;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.customType,
    this.customColor,
    this.icon,
    this.isSmall = false,
  });

  /// Create a grade badge
  const StatusBadge.grade({
    super.key,
    required String grade,
    this.icon,
    this.isSmall = false,
  })  : label = grade,
        type = StatusType.grade,
        customType = null,
        customColor = null;

  /// Create a priority badge
  const StatusBadge.priority({
    super.key,
    required String priority,
    this.icon,
    this.isSmall = false,
  })  : label = priority,
        type = StatusType.priority,
        customType = null,
        customColor = null;

  /// Create an assignment type badge
  const StatusBadge.assignmentType({
    super.key,
    required String type,
    this.icon,
    this.isSmall = false,
  })  : label = type,
        type = StatusType.assignmentType,
        customType = null,
        customColor = null;

  /// Create a custom badge
  const StatusBadge.custom({
    super.key,
    required this.label,
    required Color color,
    this.icon,
    this.isSmall = false,
  })  : type = StatusType.custom,
        customType = null,
        customColor = color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color textColor;

    switch (type) {
      case StatusType.grade:
        backgroundColor = AppTheme.getGradeColor(label);
        textColor = _getContrastColor(backgroundColor);
        break;
      case StatusType.priority:
        backgroundColor = AppTheme.getPriorityColor(label);
        textColor = _getContrastColor(backgroundColor);
        break;
      case StatusType.attendance:
        backgroundColor = _getAttendanceColor(label);
        textColor = _getContrastColor(backgroundColor);
        break;
      case StatusType.assignment:
        backgroundColor = _getAssignmentColor(label);
        textColor = _getContrastColor(backgroundColor);
        break;
      case StatusType.assignmentType:
        backgroundColor = _getAssignmentTypeColor(label);
        textColor = _getContrastColor(backgroundColor);
        break;
      case StatusType.custom:
        backgroundColor = customColor ?? colorScheme.primary;
        textColor = _getContrastColor(backgroundColor);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: textColor,
              size: isSmall ? 12 : 14,
            ),
            SizedBox(width: isSmall ? 2 : 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: isSmall ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAttendanceColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppTheme.successColor;
      case 'absent':
        return AppTheme.errorColor;
      case 'late':
        return AppTheme.warningColor;
      case 'excused':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getAssignmentColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
      case 'complete':
        return AppTheme.successColor;
      case 'missing':
      case 'not submitted':
        return AppTheme.errorColor;
      case 'late':
        return AppTheme.warningColor;
      case 'in progress':
      case 'draft':
        return Colors.blue;
      case 'graded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getAssignmentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'homework':
        return Colors.green;
      case 'quiz':
        return Colors.blue;
      case 'test':
        return Colors.orange;
      case 'project':
        return Colors.purple;
      case 'exam':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getContrastColor(Color backgroundColor) {
    // Simple contrast calculation
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

enum StatusType {
  grade,
  priority,
  attendance,
  assignment,
  assignmentType,
  custom,
}
