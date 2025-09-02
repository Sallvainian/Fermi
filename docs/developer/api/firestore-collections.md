# Firestore Collections Schema

Complete database schema documentation for all 30+ collections in the Fermi platform.

## Collection Structure Overview

The Firestore database is organized into the following main categories:

### Core Collections
- `users` - User profiles and basic information
- `pending_users` - Users awaiting email verification
- `presence` - Real-time user online status

### Class Management
- `classes` - Class definitions and settings
- `students` - Student enrollment and profiles
- `teachers` - Teacher profiles and assignments

### Assignment System
- `assignments` - Assignment definitions and metadata
- `submissions` - Student assignment submissions
- `grades` - Grade records and feedback

### Communication
- `chat_rooms` - Chat room configurations
- `messages` - Individual chat messages
- `conversations` - Direct message threads
- `notifications` - System and user notifications

### Discussion System
- `discussion_boards` - Discussion board definitions
- `threads` - Discussion thread topics
- `replies` - Thread replies and responses
- `likes` - Like/reaction tracking
- `comments` - Comment system

### Calendar & Events
- `calendar_events` - Scheduled events and deadlines
- `scheduled_messages` - Automated message scheduling

### Games & Activities
- `games` - Educational game definitions
- `jeopardy_games` - Jeopardy game instances
- `jeopardy_sessions` - Active game sessions
- `scores` - Game scoring and leaderboards

### System Collections
- `activities` - User activity tracking
- `announcements` - System-wide announcements
- `bug_reports` - User-submitted bug reports
- `fcm_tokens` - Push notification tokens
- `calls` - Video/voice call records
- `candidates` - WebRTC call candidates

## Detailed Schema Definitions

### Users Collection
```javascript
{
  "uid": "string", // Firebase Auth UID
  "email": "string",
  "displayName": "string",
  "role": "teacher" | "student" | "admin",
  "profileImage": "string", // Storage URL
  "isEmailVerified": "boolean",
  "createdAt": "timestamp",
  "lastActive": "timestamp",
  "preferences": {
    "notifications": "boolean",
    "theme": "light" | "dark" | "system"
  }
}
```

### Classes Collection
```javascript
{
  "id": "string",
  "name": "string",
  "description": "string",
  "teacherId": "string", // Reference to users collection
  "studentIds": ["string"], // Array of student UIDs
  "subject": "string",
  "grade": "string",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "settings": {
    "allowDiscussions": "boolean",
    "allowChat": "boolean",
    "autoGrading": "boolean"
  }
}
```

### Assignments Collection
```javascript
{
  "id": "string",
  "title": "string",
  "description": "string",
  "classId": "string", // Reference to classes collection
  "teacherId": "string",
  "type": "homework" | "quiz" | "project" | "exam",
  "dueDate": "timestamp",
  "totalPoints": "number",
  "instructions": "string",
  "attachments": ["string"], // Storage URLs
  "isPublished": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Chat Rooms Collection
```javascript
{
  "id": "string",
  "name": "string",
  "type": "direct" | "group" | "class",
  "participants": ["string"], // Array of user UIDs
  "classId": "string", // Optional, for class chats
  "isActive": "boolean",
  "lastMessage": {
    "text": "string",
    "senderId": "string",
    "timestamp": "timestamp"
  },
  "createdAt": "timestamp"
}
```

### Discussion Boards Collection
```javascript
{
  "id": "string",
  "title": "string",
  "description": "string",
  "classId": "string",
  "teacherId": "string",
  "isActive": "boolean",
  "allowAnonymous": "boolean",
  "moderationEnabled": "boolean",
  "createdAt": "timestamp",
  "threadCount": "number",
  "participantCount": "number"
}
```

## Security Rules Structure

### Role-Based Access
- **Teachers**: Full CRUD access to their classes and content
- **Students**: Read access to enrolled classes, limited write access
- **Admins**: Full system access with additional moderation capabilities

### Data Protection
- User data is protected by authentication requirements
- Cross-user data access is strictly controlled
- Sensitive information is encrypted at rest

### Validation Rules
- All writes include server timestamp validation
- Required fields are enforced at the database level
- Data types and formats are validated on write

## Indexes and Queries

### Composite Indexes
```javascript
// Optimized for assignment queries
assignments: ["classId", "dueDate", "isPublished"]

// Optimized for message retrieval
messages: ["chatRoomId", "timestamp"]

// Optimized for discussion threads
threads: ["boardId", "isPinned", "createdAt"]
```

### Query Patterns
- Paginated queries for large collections
- Real-time listeners for live data
- Batch operations for bulk updates
- Transactional operations for data consistency

## Data Relationships

### Primary Relationships
- Users → Classes (many-to-many through enrollment)
- Classes → Assignments (one-to-many)
- Assignments → Submissions (one-to-many)
- Users → Messages (one-to-many)
- Discussion Boards → Threads (one-to-many)

### Reference Management
- Soft references using document IDs
- Denormalized data for performance optimization
- Cleanup procedures for orphaned references

[content placeholder]