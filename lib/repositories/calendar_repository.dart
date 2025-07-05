/// Abstract repository interface for calendar operations.
/// 
/// This module defines the contract for calendar data operations,
/// providing methods for managing calendar events in the educational
/// platform with support for various event types and recurrence patterns.
library;

import '../models/calendar_event.dart';

/// Repository interface for calendar event operations.
/// 
/// Provides abstract methods for CRUD operations on calendar events,
/// including support for filtering by date ranges, event types,
/// and participant associations.
abstract class CalendarRepository {
  /// Creates a new calendar event.
  /// 
  /// Returns the created event with assigned ID.
  Future<CalendarEvent> createEvent(CalendarEvent event);
  
  /// Updates an existing calendar event.
  /// 
  /// Returns the updated event.
  Future<CalendarEvent> updateEvent(CalendarEvent event);
  
  /// Deletes a calendar event by ID.
  Future<void> deleteEvent(String eventId);
  
  /// Gets a single event by ID.
  Future<CalendarEvent?> getEvent(String eventId);
  
  /// Gets all events for a specific user.
  /// 
  /// Returns events where the user is either the creator
  /// or a participant.
  Stream<List<CalendarEvent>> getUserEvents(String userId);
  
  /// Gets events for a specific date range.
  /// 
  /// Returns events that occur within the specified date range,
  /// including recurring events that have instances in the range.
  Stream<List<CalendarEvent>> getEventsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );
  
  /// Gets events for a specific class.
  Stream<List<CalendarEvent>> getClassEvents(String classId);
  
  /// Gets events by type for a user.
  Stream<List<CalendarEvent>> getEventsByType(
    String userId,
    EventType type,
  );
  
  /// Gets upcoming events for a user.
  /// 
  /// Returns events occurring within the next specified number of days.
  Stream<List<CalendarEvent>> getUpcomingEvents(
    String userId,
    int daysAhead,
  );
  
  /// Gets events for a specific date.
  /// 
  /// Takes into account recurring events that occur on this date.
  Future<List<CalendarEvent>> getEventsForDate(
    String userId,
    DateTime date,
  );
  
  /// Adds a participant to an event.
  Future<void> addParticipant(String eventId, String participantId);
  
  /// Removes a participant from an event.
  Future<void> removeParticipant(String eventId, String participantId);
  
  /// Gets all participants for an event.
  Future<List<String>> getEventParticipants(String eventId);
  
  /// Checks if a user has permission to edit an event.
  Future<bool> canEditEvent(String userId, String eventId);
  
  /// Gets events that need reminders.
  /// 
  /// Returns events with reminders that should be sent within
  /// the specified time window.
  Stream<List<CalendarEvent>> getEventsNeedingReminders(
    DateTime fromTime,
    DateTime toTime,
  );
}