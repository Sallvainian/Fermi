# Data Model - Teacher Dashboard Flutter Firebase

## Firestore Collections

### users
```typescript
{
  uid: string,
  email: string,
  displayName: string,
  photoUrl?: string,
  role: 'teacher' | 'student',
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### classes
```typescript
{
  id: string,
  name: string,
  subject: string,
  teacherId: string,
  enrollmentCode: string,
  studentIds: string[],
  createdAt: timestamp
}
```

### assignments
```typescript
{
  id: string,
  classId: string,
  title: string,
  description: string,
  dueDate: timestamp,
  maxScore: number,
  attachments?: string[],
  createdAt: timestamp
}
```

### submissions
```typescript
{
  id: string,
  assignmentId: string,
  studentId: string,
  content: string,
  attachments?: string[],
  submittedAt?: timestamp,
  grade?: number,
  feedback?: string
}
```

### grades
```typescript
{
  id: string,
  assignmentId: string,
  studentId: string,
  classId: string,
  score: number,
  maxScore: number,
  feedback?: string,
  gradedAt: timestamp
}
```

### chat_rooms
```typescript
{
  id: string,
  name?: string,
  type: 'direct' | 'group' | 'class',
  participantIds: string[],
  lastMessage?: object,
  createdAt: timestamp
}
```

### notifications
```typescript
{
  id: string,
  userId: string,
  title: string,
  body: string,
  type: string,
  data?: object,
  read: boolean,
  createdAt: timestamp
}
```

### calendar_events
```typescript
{
  id: string,
  title: string,
  description?: string,
  startTime: timestamp,
  endTime: timestamp,
  createdBy: string,
  participantIds: string[],
  classId?: string
}
```

### discussion_boards
```typescript
{
  id: string,
  classId: string,
  title: string,
  description: string,
  createdBy: string,
  createdAt: timestamp
}
```

### games (Jeopardy)
```typescript
{
  id: string,
  title: string,
  creatorId: string,
  categories: object[],
  scores?: object[],
  createdAt: timestamp
}
```

## Security Rules Summary
- Teacher: Full CRUD on all class-related data
- Student: Read own data, limited writes
- Authentication required for all operations
- Role-based access enforced at Firestore level