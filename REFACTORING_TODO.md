# Flutter Project Feature-Based Refactoring TODO

## Current Status

### ✅ Completed Steps
1. **Created Git Branch**: `feature-based-refactor` 
2. **Created Directory Structure**:
   ```
   lib/
   ├── features/
   │   ├── auth/
   │   ├── calendar/
   │   ├── chat/
   │   ├── assignments/
   │   ├── grades/
   │   ├── classes/
   │   ├── discussions/
   │   ├── games/
   │   ├── notifications/
   │   ├── student/
   │   └── teacher/
   │       └── (each with data/domain/presentation subdirs)
   ├── shared/
   │   ├── models/
   │   ├── repositories/
   │   ├── services/
   │   ├── widgets/
   │   ├── theme/
   │   ├── core/
   │   └── utils/
   └── config/
   ```
3. **Created File Mapping**: See `REFACTORING_MAP.md` for complete mappings

### 🔄 Current Task
Moving shared resources first (Step 4 of 10)

## Remaining Tasks

### 4. Move Shared Resources (HIGH PRIORITY)
Order is critical - many features depend on these:

```bash
# Models (2 files)
git mv lib/models/user_model.dart lib/shared/models/
git mv lib/models/nav_item.dart lib/shared/models/

# Base Repositories (4 files)
git mv lib/repositories/base_repository.dart lib/shared/repositories/
git mv lib/repositories/firestore_repository.dart lib/shared/repositories/
git mv lib/repositories/firestore_repository_enhanced.dart lib/shared/repositories/
git mv lib/repositories/mixins lib/shared/repositories/

# Core Services (9 files)
git mv lib/services/firestore_service.dart lib/shared/services/
git mv lib/services/firestore_service_enhanced.dart lib/shared/services/
git mv lib/services/logger_service.dart lib/shared/services/
git mv lib/services/error_handler_service.dart lib/shared/services/
git mv lib/services/navigation_service.dart lib/shared/services/
git mv lib/services/cache_service.dart lib/shared/services/
git mv lib/services/performance_service.dart lib/shared/services/
git mv lib/services/retry_service.dart lib/shared/services/
git mv lib/services/validation_service.dart lib/shared/services/

# Common Widgets (14 files)
git mv lib/widgets/common/*.dart lib/shared/widgets/common/
# Except navigation widgets:
git mv lib/widgets/common/app_drawer.dart lib/shared/widgets/navigation/
git mv lib/widgets/common/bottom_nav_bar.dart lib/shared/widgets/navigation/
git mv lib/widgets/common/favorites_nav_bar.dart lib/shared/widgets/navigation/

# Theme (3 files)
git mv lib/theme/* lib/shared/theme/

# Core (2 files)
git mv lib/core/* lib/shared/core/

# Utils (1 file)
git mv lib/utils/error_handler.dart lib/shared/utils/

# Routing (1 file)
git mv lib/routing/app_router.dart lib/shared/routing/

# Config
git mv lib/firebase_options.dart lib/config/
```

### 5. Move Games Feature (MEDIUM PRIORITY)
Most isolated feature - good test case:
```bash
# Models
git mv lib/models/jeopardy_game.dart lib/features/games/domain/models/

# Screens
git mv lib/screens/games/*.dart lib/features/games/presentation/screens/
```

### 6. Move Calendar Feature (MEDIUM PRIORITY)
```bash
# Follow mappings in REFACTORING_MAP.md
# Total: ~11 files
```

### 7. Move Remaining Features (MEDIUM PRIORITY)
Order: Notifications → Discussions → Student → Teacher → Classes → Grades → Assignments → Chat → Auth
(From least to most interconnected)

### 8. Update Imports (HIGH PRIORITY)
After moving files:
```bash
# Check for import errors
flutter analyze

# Update main.dart imports
# Update provider setup imports in app_providers.dart
# Update router imports
```

### 9. Test Build (HIGH PRIORITY)
```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build web
flutter build apk  # or appropriate platform
```

### 10. Cleanup (LOW PRIORITY)
```bash
# Remove empty directories
find lib -type d -empty -delete

# Commit changes
git add -A
git commit -m "refactor: migrate to feature-based architecture"
```

## Critical Information

### Dependencies to Watch
1. **User Model**: Used by almost all features
2. **Auth Service/Provider**: Core dependency for all authenticated features
3. **Firestore Services**: Base services for all data operations
4. **Navigation**: Must update router imports after moves

### Import Update Pattern
Old: `import 'package:teacher_dashboard_flutter_firebase/models/user_model.dart';`
New: `import 'package:teacher_dashboard_flutter_firebase/shared/models/user_model.dart';`

### Testing After Each Feature
```bash
flutter analyze  # Check for import errors
flutter run      # Quick runtime test
```

### Rollback Plan
If something breaks:
```bash
git status       # See what changed
git checkout .   # Discard all changes
# OR
git checkout feature-based-refactor~1  # Go back one commit
```

## Key Files to Update After Moving

1. **lib/main.dart** - Update all imports
2. **lib/shared/providers/app_providers.dart** - Update provider imports
3. **lib/shared/routing/app_router.dart** - Update screen imports
4. **lib/shared/core/service_locator.dart** - Update service imports

## Notes

- Using `git mv` preserves file history
- IDE refactoring tools can help update imports automatically
- Test after each major feature move
- Shared resources MUST be moved first
- Total files to move: ~140+
- Estimated time: 2-4 hours

## Quick Commands

```bash
# Check current branch
git branch

# See what's changed
git status

# Run analysis
flutter analyze

# Quick test
flutter run -d chrome  # or your preferred device
```