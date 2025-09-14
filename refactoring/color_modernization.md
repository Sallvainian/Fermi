# Color Modernization Refactoring Guide

## Files to Update (Optional - Not Critical)

These changes will improve theme support but are not required for functionality:

### 1. lib/shared/widgets/pwa_update_notifier_web.dart
```dart
// Line 203 - Replace:
backgroundColor: Colors.blueGrey.shade800,
// With:
backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,

// Line 267 - Replace:
color: Colors.blue.shade700,
// With:
color: Theme.of(context).colorScheme.primary,
```

### 2. lib/features/auth/presentation/screens/role_selection_screen.dart
```dart
// Line 39 - Replace:
backgroundColor: Colors.red.shade700,
// With:
backgroundColor: Theme.of(context).colorScheme.error,
```

### 3. lib/features/student/presentation/widgets/online_users_card.dart
```dart
// Line 223 - Replace:
backgroundColor = Colors.red.shade700;
// With:
backgroundColor = Theme.of(context).colorScheme.error;

// Line 226 - Replace:
backgroundColor = Colors.blue.shade700;
// With:
backgroundColor = Theme.of(context).colorScheme.primary;
```

### 4. lib/features/assignments/presentation/screens/teacher/assignment_detail_screen.dart
```dart
// Line 513 - Replace:
color: Colors.grey.shade600,
// With:
color: Theme.of(context).colorScheme.onSurfaceVariant,
```

### 5. lib/features/behavior_points/domain/models/student_points.dart
```dart
// Line 329 - Replace:
return Colors.red.shade800;
// With:
return Theme.of(context).colorScheme.error;
// Note: This requires passing context to the method
```

## Benefits of These Changes:
- Better support for dark/light theme switching
- More consistent with Material 3 design system
- Easier to maintain custom themes
- Improves accessibility when users have custom color preferences

## These are NOT bugs:
- The current implementation works correctly
- These are optional improvements for better theming support