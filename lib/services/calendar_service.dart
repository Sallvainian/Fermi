/// Service layer for calendar business logic.
/// 
/// This module provides high-level calendar operations,
/// coordinating between repositories and handling complex
/// business rules for educational calendar management.
library;

import '../models/calendar_event.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/class_repository.dart';
import 'notification_service.dart';
import 'device_calendar_service_interface.dart';
import 'device_calendar_service_factory.dart';

/// Service for managing calendar operations.
/// 
/// Provides business logic for:
/// - Event creation with validation
/// - Automatic event generation from assignments/classes
/// - Conflict detection
/// - Reminder scheduling
/// - Permission management
class CalendarService {
  final CalendarRepository _calendarRepository;
  final UserRepository _userRepository;
  final ClassRepository _classRepository;
  
  /// Creates service with required repositories.
  CalendarService(
    this._calendarRepository,
    this._userRepository,
    this._classRepository,
  );
  
  /// Creates a new calendar event with validation.
  Future<CalendarEvent> createEvent({
    required String title,
    required String createdBy,
    required EventType type,
    required DateTime startTime,
    DateTime? endTime,
    String? description,
    String? location,
    String? classId,
    String? assignmentId,
    List<String>? participantIds,
    bool isAllDay = false,
    RecurrenceType recurrence = RecurrenceType.none,
    DateTime? recurrenceEndDate,
    bool hasReminder = false,
    int? reminderMinutes,
    String? colorHex,
    bool syncToDeviceCalendar = false,
  }) async {
    // Get creator details
    final creator = await _userRepository.getUserById(createdBy);
    if (creator == null) {
      throw Exception('Creator not found');
    }
    
    // Validate class if provided
    if (classId != null) {
      final classExists = await _classRepository.getClass(classId);
      if (classExists == null) {
        throw Exception('Class not found');
      }
    }
    
    // Validate end time
    if (endTime != null && endTime.isBefore(startTime)) {
      throw Exception('End time cannot be before start time');
    }
    
    // Create event
    final event = CalendarEvent(
      id: '', // Will be set by repository
      title: title,
      description: description,
      type: type,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: location,
      createdBy: createdBy,
      createdByName: creator.displayName,
      classId: classId,
      assignmentId: assignmentId,
      participantIds: participantIds,
      colorHex: colorHex,
      recurrence: recurrence,
      recurrenceEndDate: recurrenceEndDate,
      hasReminder: hasReminder,
      reminderMinutes: reminderMinutes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final createdEvent = await _calendarRepository.createEvent(event);
    
    // Schedule notification if reminder is enabled
    if (createdEvent.hasReminder) {
      final notificationService = NotificationService();
      await notificationService.scheduleEventReminder(createdEvent);
    }
    
    // Sync to device calendar if requested
    if (syncToDeviceCalendar) {
      final deviceCalendarService = DeviceCalendarServiceFactory.create();
      await deviceCalendarService.addCalendarEvent(event: createdEvent);
    }
    
    return createdEvent;
  }
  
  /// Updates an existing event with permission check.
  Future<CalendarEvent> updateEvent(
    String userId,
    CalendarEvent event,
  ) async {
    // Check permissions
    final canEdit = await _calendarRepository.canEditEvent(userId, event.id);
    if (!canEdit) {
      throw Exception('Insufficient permissions to edit this event');
    }
    
    final updatedEvent = await _calendarRepository.updateEvent(event);
    
    // Update notification if reminder settings changed
    final notificationService = NotificationService();
    // Cancel old notification
    await notificationService.cancelNotification(event.id.hashCode);
    
    // Schedule new one if reminder is enabled
    if (updatedEvent.hasReminder) {
      await notificationService.scheduleEventReminder(updatedEvent);
    }
    
    return updatedEvent;
  }
  
  /// Deletes an event with permission check.
  Future<void> deleteEvent(String userId, String eventId) async {
    // Check permissions
    final canEdit = await _calendarRepository.canEditEvent(userId, eventId);
    if (!canEdit) {
      throw Exception('Insufficient permissions to delete this event');
    }
    
    await _calendarRepository.deleteEvent(eventId);
    
    // Cancel notification if scheduled
    final notificationService = NotificationService();
    await notificationService.cancelNotification(eventId.hashCode);
  }
  
  /// Creates a recurring class event.
  Future<CalendarEvent> createClassSchedule({
    required String classId,
    required String teacherId,
    required String className,
    required DateTime startDate,
    required DateTime classStartTime,
    required DateTime classEndTime,
    required List<int> weekdays, // 1-7 (Monday-Sunday)
    required DateTime semesterEndDate,
    String? location,
  }) async {
    // TODO: Implement custom recurrence details for weekly class schedule
    // final recurrenceDetails = {
    //   'type': 'weekly_class',
    //   'weekdays': weekdays,
    //   'originalStartTime': classStartTime.toIso8601String(),
    //   'originalEndTime': classEndTime.toIso8601String(),
    // };
    
    return await createEvent(
      title: className,
      createdBy: teacherId,
      type: EventType.class_,
      startTime: _combineDateAndTime(startDate, classStartTime),
      endTime: _combineDateAndTime(startDate, classEndTime),
      classId: classId,
      location: location,
      recurrence: RecurrenceType.custom,
      recurrenceEndDate: semesterEndDate,
      hasReminder: true,
      reminderMinutes: 15,
    );
  }
  
  /// Creates an event from an assignment due date.
  Future<CalendarEvent> createAssignmentEvent({
    required String assignmentId,
    required String title,
    required String teacherId,
    required String classId,
    required DateTime dueDate,
    String? description,
  }) async {
    return await createEvent(
      title: 'Due: $title',
      description: description,
      createdBy: teacherId,
      type: EventType.assignment,
      startTime: dueDate,
      isAllDay: true,
      classId: classId,
      assignmentId: assignmentId,
      hasReminder: true,
      reminderMinutes: 1440, // 24 hours
      colorHex: '#F44336', // Red for assignments
    );
  }
  
  /// Checks for event conflicts.
  Future<List<CalendarEvent>> checkConflicts(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final events = await _calendarRepository.getEventsForDate(
      userId,
      startTime,
    );
    
    return events.where((event) {
      if (event.isAllDay) return false;
      
      final eventEnd = event.endTime ?? event.startTime.add(const Duration(hours: 1));
      
      // Check for overlap
      return (startTime.isBefore(eventEnd) && endTime.isAfter(event.startTime));
    }).toList();
  }
  
  /// Gets events grouped by date for agenda view.
  Stream<Map<DateTime, List<CalendarEvent>>> getEventsGroupedByDate(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _calendarRepository
        .getEventsByDateRange(userId, startDate, endDate)
        .map((events) {
      final grouped = <DateTime, List<CalendarEvent>>{};
      
      // Process each day in the range
      for (var date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        final dayEvents = events.where((event) => event.occursOn(date)).toList();
        
        if (dayEvents.isNotEmpty) {
          // Sort events by time
          dayEvents.sort((a, b) {
            if (a.isAllDay && !b.isAllDay) return -1;
            if (!a.isAllDay && b.isAllDay) return 1;
            return a.startTime.compareTo(b.startTime);
          });
          
          grouped[dateOnly] = dayEvents;
        }
      }
      
      return grouped;
    });
  }
  
  /// Adds a user to an event.
  Future<void> addParticipantToEvent(
    String eventId,
    String participantId,
  ) async {
    // Verify participant exists
    final participant = await _userRepository.getUserById(participantId);
    if (participant == null) {
      throw Exception('Participant not found');
    }
    
    await _calendarRepository.addParticipant(eventId, participantId);
  }
  
  /// Removes a user from an event.
  Future<void> removeParticipantFromEvent(
    String eventId,
    String participantId,
  ) async {
    await _calendarRepository.removeParticipant(eventId, participantId);
  }
  
  /// Gets suggested event colors based on type.
  String getSuggestedColor(EventType type) {
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
  
  /// Helper to combine date and time.
  DateTime _combineDateAndTime(DateTime date, DateTime time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }
}