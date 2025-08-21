# Assignment Routing Fixes Summary

## Issues Fixed

### 1. ✅ Removed Duplicate Route
**Problem**: There were two routes for assignments:
- `/teacher/assignments` (correct)
- `/assignments` (duplicate)

**Solution**: Removed the duplicate `/assignments` route from `app_router.dart` (line 431-434)

### 2. ✅ Fixed Navigation Pattern
**Problem**: After creating an assignment, `context.pop()` failed because the create screen was navigated to with `context.go()` instead of `context.push()`.

**Solution**: Changed navigation in `assignments_list_screen.dart`:
- Line 581: Changed from `context.go()` to `context.push()` for create assignment
- Line 286: Changed from `context.go()` to `context.push()` for assignment details
- Line 408: Changed from `context.go()` to `context.push()` for gradebook
- Line 427: Changed from `context.go()` to `context.push()` for view button

### 3. ✅ Proper GoRouter Usage
According to the project's CLAUDE.md documentation and GoRouter best practices:
- `go()` - Replaces the current route stack (cannot pop back)
- `push()` - Adds to the navigation stack (can pop back)

The assignment create screen already handles navigation correctly:
- Uses `context.pop()` after successful creation (line 153 in `assignment_create_screen.dart`)
- Has fallback to `context.go('/teacher/assignments')` if pop is not available (line 183)

## Files Modified

1. `/lib/shared/routing/app_router.dart`
   - Removed duplicate `/assignments` route

2. `/lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart`
   - Fixed navigation to use `push()` instead of `go()` for all sub-navigation

## Testing

Run the app and verify:
```bash
flutter run -d chrome
```

1. Navigate to Teacher Dashboard
2. Go to Assignments
3. Click "New Assignment" - should navigate properly
4. Fill in the form and save - should return to assignments list
5. Click on an assignment - should navigate to details
6. Use back button - should return to list

## Firestore Indexes Required

The application requires these Firestore composite indexes:

### Assignments Collection
- `teacherId` (Asc) + `createdAt` (Desc) - For loading teacher assignments
- `classId` (Asc) + `isPublished` (Asc) + `dueDate` (Asc) - For student view

### Grades Collection  
- `assignmentId` (Asc) + `studentId` (Asc) - For assignment grades
- `studentId` (Asc) + `updatedAt` (Desc) - For student grades view

These indexes will be auto-created when queries are first run, or can be manually created in the Firebase Console under Firestore Database > Indexes.

## Navigation Flow

The correct navigation flow is now:
```
/dashboard 
  → /teacher/assignments (via drawer/nav)
    → /teacher/assignments/create (via push)
      ← Returns via pop()
    → /teacher/assignments/{id} (via push) 
      ← Returns via pop()
    → /teacher/gradebook?assignmentId={id} (via push)
      ← Returns via pop()
```

## Status

✅ All routing issues have been resolved
✅ Navigation follows GoRouter best practices
✅ Complies with project's CLAUDE.md guidelines