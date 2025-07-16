import '../../domain/models/calendar_event.dart';
import '../../../assignments/domain/models/assignment.dart';
import '../../../../shared/services/logger_service.dart';
import 'device_calendar_service_interface.dart';

/// Factory function for conditional imports
DeviceCalendarServiceInterface getDeviceCalendarService() {
  return DeviceCalendarServiceWeb();
}

/// Web implementation of device calendar service (stub)
class DeviceCalendarServiceWeb implements DeviceCalendarServiceInterface {
  static final DeviceCalendarServiceWeb _instance = DeviceCalendarServiceWeb._internal();
  factory DeviceCalendarServiceWeb() => _instance;
  DeviceCalendarServiceWeb._internal();

  @override
  Future<bool> requestPermissions() async {
    // Calendar permissions are not applicable on web
    LoggerService.info('Calendar permissions not required on web', tag: 'DeviceCalendarService');
    return false;
  }
  
  @override
  Future<List<dynamic>> getDeviceCalendars() async {
    // No device calendars available on web
    LoggerService.info('Device calendars not available on web', tag: 'DeviceCalendarService');
    return [];
  }
  
  @override
  Future<String?> addCalendarEvent({
    required CalendarEvent event,
    String? calendarId,
  }) async {
    // Calendar sync not available on web
    LoggerService.info('Calendar sync not available on web: ${event.title}', 
        tag: 'DeviceCalendarService');
    // Could potentially open Google Calendar web or create an .ics file
    // For now, just return null
    return null;
  }
  
  @override
  Future<String?> addAssignmentToCalendar({
    required Assignment assignment,
    String? calendarId,
  }) async {
    // Calendar sync not available on web
    LoggerService.info('Assignment calendar sync not available on web: ${assignment.title}', 
        tag: 'DeviceCalendarService');
    // Could potentially open Google Calendar web or create an .ics file
    // For now, just return null
    return null;
  }
  
  @override
  Future<bool> updateCalendarEvent({
    required String eventId,
    required CalendarEvent event,
    String? calendarId,
  }) async {
    // Calendar sync not available on web
    LoggerService.info('Calendar event update not available on web: ${event.title}', 
        tag: 'DeviceCalendarService');
    return false;
  }
  
  @override
  Future<bool> deleteCalendarEvent({
    required String eventId,
    String? calendarId,
  }) async {
    // Calendar sync not available on web
    LoggerService.info('Calendar event deletion not available on web: $eventId', 
        tag: 'DeviceCalendarService');
    return false;
  }
}