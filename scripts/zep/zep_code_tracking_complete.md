# Zep Code Relationship Tracking System

## Overview
Using Zep Cloud's temporal knowledge graph to track code relationships and dependencies within the Flutter/Firebase project, maintaining contextual awareness of how different parts of the codebase interact and evolve over time.

## Core Concept
Instead of tracking user preferences and behaviors, we track:
- File dependencies and imports
- Function/class relationships  
- Architectural patterns and layers
- Code evolution over time

## Complete Relational Database Schema

### Primary Entities

#### 1. FILE Entity
```json
{
  "entity_type": "file",
  "file_path": "lib/features/calendar/presentation/providers/calendar_provider.dart",
  "file_type": "dart",
  "module": "calendar",
  "layer": "presentation",
  "sub_layer": "providers",
  "size_bytes": 15234,
  "line_count": 342,
  "created_at": "2024-07-15T10:00:00Z",
  "last_modified": "2024-07-22T14:30:00Z",
  "git_hash": "7442a452"
}
```

#### 2. CLASS Entity
```json
{
  "entity_type": "class",
  "class_name": "CalendarProvider",
  "file_path": "lib/features/calendar/presentation/providers/calendar_provider.dart",
  "class_type": "provider",
  "extends": "ChangeNotifier",
  "implements": [],
  "mixins": ["ChangeNotifier"],
  "is_abstract": false,
  "line_start": 23,
  "line_end": 342
}
```

#### 3. FUNCTION Entity
```json
{
  "entity_type": "function",
  "function_name": "createEvent",
  "class_name": "CalendarService",
  "file_path": "lib/features/calendar/data/services/calendar_service.dart",
  "return_type": "Future<CalendarEvent>",
  "parameters": ["title", "createdBy", "type", "startTime"],
  "is_async": true,
  "line_start": 36,
  "line_end": 89
}
```

#### 4. IMPORT Entity
```json
{
  "entity_type": "import",
  "source_file": "lib/features/calendar/presentation/providers/calendar_provider.dart",
  "imported_file": "lib/features/calendar/data/services/calendar_service.dart",
  "import_type": "relative",
  "line_number": 11,
  "alias": null
}
```

#### 5. MODULE Entity
```json
{
  "entity_type": "module",
  "module_name": "calendar",
  "module_path": "lib/features/calendar",
  "module_type": "feature",
  "has_layers": ["data", "domain", "presentation"],
  "primary_responsibility": "Calendar event management",
  "depends_on_modules": ["auth", "classes", "notifications"]
}
```

### Relationship Types

#### 1. DEPENDS_ON Relationship
```json
{
  "relationship_type": "depends_on",
  "source": {
    "type": "class",
    "name": "CalendarProvider",
    "file": "lib/features/calendar/presentation/providers/calendar_provider.dart"
  },
  "target": {
    "type": "class", 
    "name": "CalendarService",
    "file": "lib/features/calendar/data/services/calendar_service.dart"
  },
  "dependency_type": "composition",
  "is_injected": true,
  "created_at": "2024-07-15T10:00:00Z"
}
```

#### 2. CALLS Relationship
```json
{
  "relationship_type": "calls",
  "caller": {
    "class": "CalendarProvider",
    "method": "loadEvents",
    "file": "lib/features/calendar/presentation/providers/calendar_provider.dart"
  },
  "callee": {
    "class": "CalendarService",
    "method": "getEventsForDateRange",
    "file": "lib/features/calendar/data/services/calendar_service.dart"
  },
  "call_type": "async",
  "frequency": "on_demand"
}
```

#### 3. IMPLEMENTS Relationship
```json
{
  "relationship_type": "implements",
  "implementer": {
    "class": "CalendarRepositoryImpl",
    "file": "lib/features/calendar/data/repositories/calendar_repository_impl.dart"
  },
  "interface": {
    "class": "CalendarRepository",
    "file": "lib/features/calendar/domain/repositories/calendar_repository.dart"
  },
  "methods_implemented": ["createEvent", "updateEvent", "deleteEvent", "getEvents"]
}
```

#### 4. USES Relationship
```json
{
  "relationship_type": "uses",
  "user": {
    "class": "CalendarService",
    "file": "lib/features/calendar/data/services/calendar_service.dart"
  },
  "used": {
    "service": "FirebaseFirestore",
    "package": "cloud_firestore",
    "resource": "collections/events"  // Enhanced to track specific resources
  },
  "usage_type": "data_persistence",
  "operations": ["create", "read", "update", "delete"]
}
```

### Temporal Tracking

#### 1. REFACTORING Event
```json
{
  "event_type": "refactoring",
  "description": "Extracted WebRTC logic from ChatDetailScreen to WebRTCCallManager",
  "affected_entities": [
    {
      "type": "class",
      "name": "ChatDetailScreen",
      "file": "lib/features/chat/presentation/screens/chat_detail_screen.dart",
      "change": "removed_responsibility"
    },
    {
      "type": "class",
      "name": "WebRTCCallManager",
      "file": "lib/features/chat/presentation/providers/webrtc_call_manager.dart",
      "change": "new_component"
    }
  ],
  "reason": "Improve separation of concerns and testability",
  "git_commit": "7442a452",
  "timestamp": "2024-07-22T00:00:00Z",
  "valid_from": "2024-07-22T00:00:00Z"
}
```

#### 2. ARCHITECTURAL_CHANGE Event
```json
{
  "event_type": "architectural_change",
  "description": "Migrated from StatefulWidget to Provider pattern",
  "scope": "module",
  "module": "calendar",
  "pattern_before": "StatefulWidget",
  "pattern_after": "Provider/ChangeNotifier",
  "impact": ["improved_testability", "better_state_management"],
  "timestamp": "2024-07-20T00:00:00Z"
}
```

## Implementation Examples

### Initial Setup
```python
# Create codebase entity
import zep_cloud

client = zep_cloud.Client(api_key="YOUR_API_KEY")

user = client.user.add(
    user_id="teacher-dashboard-flutter",
    metadata={
        "project_type": "Flutter/Firebase",
        "architecture": "Clean Architecture",
        "main_features": ["calendar", "chat", "classes", "discussions"],
        "last_analysis": "2024-07-22T00:00:00Z"
    }
)
```

### Add Relationships
```python
# Track service dependencies
client.graph.add(
    user_id="teacher-dashboard-flutter",
    data={
        "type": "service_dependency",
        "service": "CalendarService",
        "depends_on": ["Firebase Firestore", "AuthService"],
        "used_by": ["CalendarProvider", "CalendarScreen"],
        "purpose": "Manages calendar events and scheduling"
    },
    type="json"
)

# Track recent changes
client.graph.add(
    user_id="teacher-dashboard-flutter",
    data={
        "type": "refactoring",
        "component": "WebRTC",
        "change": "Extracted WebRTC logic from UI into dedicated WebRTCCallManager",
        "reason": "Improve separation of concerns and testability",
        "affected_files": [
            "lib/features/chat/presentation/screens/chat_detail_screen.dart",
            "lib/features/chat/presentation/providers/webrtc_call_manager.dart"
        ]
    },
    type="json"
)
```

### Query Patterns

#### 1. Dependency Impact Query
```python
# What will be affected if I change CalendarService?
impacts = client.graph.search(
    user_id="teacher-dashboard-flutter",
    query="target.name:CalendarService"
)
```

#### 2. Module Dependencies Query
```python
# What does the calendar module depend on?
dependencies = client.graph.search(
    user_id="teacher-dashboard-flutter",
    query="source.module:calendar"
)
```

#### 3. Layer Violations Query
```python
# Find clean architecture violations
violations = client.graph.search(
    user_id="teacher-dashboard-flutter",
    query="source.layer:data AND target.layer:presentation"
)
```

#### 4. Historical Changes Query
```python
# How has WebRTC implementation evolved?
history = client.graph.search(
    user_id="teacher-dashboard-flutter",
    query="WebRTC",
    include_invalid=True  # Include historical facts
)
```

## Critical Implementation Steps

### 1. Validate Zep Query Capabilities (CRITICAL)
Before full implementation, test if Zep can handle our complex queries:
```python
# Test script to validate Zep capabilities
test_user = "flutter-poc"
# Add test data and run validation queries
# If Zep can't handle complex queries, consider hybrid approach
```

### 2. Automated Data Extraction (CRITICAL)
Use Dart analyzer to parse code and extract relationships:
```dart
// scripts/analyze_code.dart
import 'package:analyzer/dart/analysis/utilities.dart';
// Extract entities and relationships automatically
```

### 3. CI/CD Integration
Automate updates on every commit:
```yaml
# .github/workflows/update-zep.yml
on:
  push:
    branches: [main]
# Run analyzer and update Zep
```

## Benefits

1. **Persistent Context**: Maintain awareness across Claude sessions
2. **Impact Analysis**: Understand ripple effects of changes
3. **Temporal Evolution**: Track architectural decisions over time
4. **Cross-File Awareness**: Navigate complex dependencies
5. **Pattern Recognition**: Identify recurring architectural patterns

## Architecture Assessment

**Strengths**:
- Clean Architecture properly implemented
- Feature-based modularization
- Provider pattern for state management
- Repository pattern for data abstraction

**Opportunities**:
- WebRTC may need TURN server for production
- Opportunity to extract shared UI components
- Firebase security rules need audit

This comprehensive system transforms Zep from a user behavior tracker into a powerful code intelligence system for maintaining contextual awareness across your Flutter/Firebase project!