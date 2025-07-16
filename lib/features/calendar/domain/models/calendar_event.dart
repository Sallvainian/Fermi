/// Calendar event model for educational scheduling.
/// 
/// This module defines the event structure for calendar functionality,
/// supporting various educational event types like classes, assignments,
/// meetings, and exams with Firebase integration.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enumeration of available event types.
enum EventType {
  /// Regular class sessions
  class_('Class'),
  
  /// Assignment deadlines
  assignment('Assignment'),
  
  /// Meetings with parents, staff, or students
  meeting('Meeting'),
  
  /// Exams and assessments
  exam('Exam'),
  
  /// Personal reminders and events
  personal('Personal'),
  
  /// School-wide events
  school('School'),
  
  /// Other event types
  other('Other');

  /// Display name for the event type
  final String displayName;
  
  const EventType(this.displayName);
  
  /// Creates EventType from string value
  static EventType fromString(String value) {
    return EventType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => EventType.other,
    );
  }
}

/// Enumeration of event recurrence patterns.
enum RecurrenceType {
  /// One-time event
  none,
  
  /// Repeats daily
  daily,
  
  /// Repeats weekly on same day
  weekly,
  
  /// Repeats monthly on same date
  monthly,
  
  /// Repeats yearly on same date
  yearly,
  
  /// Custom recurrence pattern
  custom;
  
  /// Creates RecurrenceType from string value
  static RecurrenceType fromString(String value) {
    return RecurrenceType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => RecurrenceType.none,
    );
  }
}

/// Calendar event model representing scheduled activities.
/// 
/// This model supports various educational events with features:
/// - Multiple event types (classes, assignments, meetings, etc.)
/// - Recurrence patterns for repeating events
/// - Participant tracking for meetings and classes
/// - Color coding for visual organization
/// - Rich metadata for event details
/// 
/// Events can be associated with classes, assignments, or standalone
/// activities in the educational platform.
class CalendarEvent {
  /// Unique identifier for the event
  final String id;
  
  /// Event title/name
  final String title;
  
  /// Detailed event description (optional)
  final String? description;
  
  /// Event category type
  final EventType type;
  
  /// Event start date and time
  final DateTime startTime;
  
  /// Event end date and time (optional)
  final DateTime? endTime;
  
  /// Whether this is an all-day event
  final bool isAllDay;
  
  /// Event location or room (optional)
  final String? location;
  
  /// Creator's user ID (teacher or admin)
  final String createdBy;
  
  /// Creator's display name for quick reference
  final String createdByName;
  
  /// Associated class ID (optional)
  final String? classId;
  
  /// Associated assignment ID (optional)
  final String? assignmentId;
  
  /// List of participant user IDs (optional)
  final List<String>? participantIds;
  
  /// List of participant emails for external attendees (optional)
  final List<String>? participantEmails;
  
  /// Event color for calendar display (hex string)
  final String? colorHex;
  
  /// Recurrence pattern for repeating events
  final RecurrenceType recurrence;
  
  /// End date for recurring events (optional)
  final DateTime? recurrenceEndDate;
  
  /// Custom recurrence pattern details (optional)
  final Map<String, dynamic>? recurrenceDetails;
  
  /// Whether to send reminders for this event
  final bool hasReminder;
  
  /// Reminder time in minutes before event
  final int? reminderMinutes;
  
  /// Additional metadata for extensibility
  final Map<String, dynamic>? metadata;
  
  /// Creation timestamp
  final DateTime createdAt;
  
  /// Last update timestamp
  final DateTime updatedAt;
  
  /// Whether the event is active (not cancelled)
  final bool isActive;

  /// Creates a calendar event instance.
  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.location,
    required this.createdBy,
    required this.createdByName,
    this.classId,
    this.assignmentId,
    this.participantIds,
    this.participantEmails,
    this.colorHex,
    this.recurrence = RecurrenceType.none,
    this.recurrenceEndDate,
    this.recurrenceDetails,
    this.hasReminder = false,
    this.reminderMinutes,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Creates a CalendarEvent from Firestore document.
  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CalendarEvent(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      type: EventType.fromString(data['type'] ?? 'other'),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null 
          ? (data['endTime'] as Timestamp).toDate() 
          : null,
      isAllDay: data['isAllDay'] ?? false,
      location: data['location'],
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      classId: data['classId'],
      assignmentId: data['assignmentId'],
      participantIds: data['participantIds'] != null
          ? List<String>.from(data['participantIds'])
          : null,
      participantEmails: data['participantEmails'] != null
          ? List<String>.from(data['participantEmails'])
          : null,
      colorHex: data['colorHex'],
      recurrence: RecurrenceType.fromString(data['recurrence'] ?? 'none'),
      recurrenceEndDate: data['recurrenceEndDate'] != null
          ? (data['recurrenceEndDate'] as Timestamp).toDate()
          : null,
      recurrenceDetails: data['recurrenceDetails'],
      hasReminder: data['hasReminder'] ?? false,
      reminderMinutes: data['reminderMinutes'],
      metadata: data['metadata'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Converts CalendarEvent to Firestore document format.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isAllDay': isAllDay,
      'location': location,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'classId': classId,
      'assignmentId': assignmentId,
      'participantIds': participantIds,
      'participantEmails': participantEmails,
      'colorHex': colorHex,
      'recurrence': recurrence.name,
      'recurrenceEndDate': recurrenceEndDate != null 
          ? Timestamp.fromDate(recurrenceEndDate!) 
          : null,
      'recurrenceDetails': recurrenceDetails,
      'hasReminder': hasReminder,
      'reminderMinutes': reminderMinutes,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  /// Creates a copy with optional field updates.
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    EventType? type,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    String? createdBy,
    String? createdByName,
    String? classId,
    String? assignmentId,
    List<String>? participantIds,
    List<String>? participantEmails,
    String? colorHex,
    RecurrenceType? recurrence,
    DateTime? recurrenceEndDate,
    Map<String, dynamic>? recurrenceDetails,
    bool? hasReminder,
    int? reminderMinutes,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      classId: classId ?? this.classId,
      assignmentId: assignmentId ?? this.assignmentId,
      participantIds: participantIds ?? this.participantIds,
      participantEmails: participantEmails ?? this.participantEmails,
      colorHex: colorHex ?? this.colorHex,
      recurrence: recurrence ?? this.recurrence,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceDetails: recurrenceDetails ?? this.recurrenceDetails,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Checks if the event occurs on a specific date.
  /// 
  /// Takes into account recurrence patterns to determine
  /// if the event should appear on the given date.
  bool occursOn(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final eventDateOnly = DateTime(startTime.year, startTime.month, startTime.day);
    
    // Check if it's the original event date
    if (dateOnly == eventDateOnly) return true;
    
    // Check recurrence
    if (recurrence == RecurrenceType.none) return false;
    
    // Check if date is before event start or after recurrence end
    if (dateOnly.isBefore(eventDateOnly)) return false;
    if (recurrenceEndDate != null && dateOnly.isAfter(recurrenceEndDate!)) {
      return false;
    }
    
    switch (recurrence) {
      case RecurrenceType.daily:
        return true;
        
      case RecurrenceType.weekly:
        return date.weekday == startTime.weekday;
        
      case RecurrenceType.monthly:
        return date.day == startTime.day;
        
      case RecurrenceType.yearly:
        return date.month == startTime.month && date.day == startTime.day;
        
      case RecurrenceType.custom:
        // Handle custom recurrence logic based on recurrenceDetails
        return _checkCustomRecurrence(date);
        
      case RecurrenceType.none:
        return false;
    }
  }
  
  /// Checks custom recurrence pattern.
  bool _checkCustomRecurrence(DateTime date) {
    if (recurrenceDetails == null) return false;
    
    // Example custom patterns:
    // - Every other week
    // - First Monday of each month
    // - Every weekday
    // Implementation depends on specific requirements
    
    return false;
  }
  
  /// Gets the event duration.
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }
  
  /// Checks if the event is in the past.
  bool get isPast => endTime?.isBefore(DateTime.now()) ?? 
                     startTime.isBefore(DateTime.now());
  
  /// Checks if the event is happening now.
  bool get isHappeningNow {
    final now = DateTime.now();
    if (endTime != null) {
      return now.isAfter(startTime) && now.isBefore(endTime!);
    }
    return false;
  }
  
  /// Gets a display color for the event type.
  String get displayColor {
    if (colorHex != null) return colorHex!;
    
    switch (type) {
      case EventType.class_:
        return '#2196F3'; // Blue
      case EventType.assignment:
        return '#F44336'; // Red
      case EventType.meeting:
        return '#4CAF50'; // Green
      case EventType.exam:
        return '#FF9800'; // Orange
      case EventType.personal:
        return '#9C27B0'; // Purple
      case EventType.school:
        return '#00BCD4'; // Cyan
      case EventType.other:
        return '#607D8B'; // Blue Grey
    }
  }
}