import '../../domain/models/calendar_event.dart';
import '../../../assignments/domain/models/assignment.dart';

/// Abstract interface for device calendar service
abstract class DeviceCalendarServiceInterface {
  Future<bool> requestPermissions();
  Future<List<dynamic>> getDeviceCalendars();
  Future<String?> addCalendarEvent({
    required CalendarEvent event,
    String? calendarId,
  });
  Future<String?> addAssignmentToCalendar({
    required Assignment assignment,
    String? calendarId,
  });
  Future<bool> updateCalendarEvent({
    required String eventId,
    required CalendarEvent event,
    String? calendarId,
  });
  Future<bool> deleteCalendarEvent({
    required String eventId,
    String? calendarId,
  });
}