import 'package:flutter/material.dart';

enum StatusType {
  success,
  warning,
  error,
  info,
  custom,
}

/// A status badge widget for displaying various states
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final double? fontSize;
  final EdgeInsets? padding;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.color,
    this.textColor,
    this.icon,
    this.fontSize,
    this.padding,
  });

  /// Factory constructor for grade badges
  factory StatusBadge.grade({required String grade}) {
    final color = _getGradeColor(grade);
    return StatusBadge(
      label: grade,
      type: StatusType.custom,
      color: color,
      textColor: Colors.white,
    );
  }

  /// Factory constructor for assignment type badges
  factory StatusBadge.assignmentType({required String type}) {
    final color = _getAssignmentTypeColor(type);
    return StatusBadge(
      label: type,
      type: StatusType.custom,
      color: color,
      textColor: Colors.white,
    );
  }

  /// Factory constructor for custom badges
  factory StatusBadge.custom({
    required String label,
    required Color color,
    Color? textColor,
    IconData? icon,
  }) {
    return StatusBadge(
      label: label,
      type: StatusType.custom,
      color: color,
      textColor: textColor ?? Colors.white,
      icon: icon,
    );
  }

  static Color _getGradeColor(String grade) {
    switch (grade[0]) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static Color _getAssignmentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'homework':
        return Colors.blue;
      case 'quiz':
        return Colors.purple;
      case 'test':
      case 'exam':
        return Colors.orange;
      case 'project':
        return Colors.green;
      case 'participation':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor() {
    if (color != null) return color!;

    switch (type) {
      case StatusType.success:
        return Colors.green;
      case StatusType.warning:
        return Colors.orange;
      case StatusType.error:
        return Colors.red;
      case StatusType.info:
        return Colors.blue;
      case StatusType.custom:
        return Colors.grey;
    }
  }

  IconData? _getTypeIcon() {
    if (icon != null) return icon;

    switch (type) {
      case StatusType.success:
        return Icons.check_circle;
      case StatusType.warning:
        return Icons.warning;
      case StatusType.error:
        return Icons.error;
      case StatusType.info:
        return Icons.info;
      case StatusType.custom:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getTypeColor();
    final badgeIcon = _getTypeIcon();
    final badgeTextColor = textColor ?? Colors.white;

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeIcon != null) ...[
            Icon(
              badgeIcon,
              size: fontSize ?? 12,
              color: badgeTextColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: badgeTextColor,
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}