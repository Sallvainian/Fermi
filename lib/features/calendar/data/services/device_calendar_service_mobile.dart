import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../domain/models/calendar_event.dart';
import '../../../assignments/domain/models/assignment.dart';
import '../../../../shared/services/logger_service.dart';
import 'device_calendar_service_interface.dart';

/// Factory function for conditional imports
DeviceCalendarServiceInterface getDeviceCalendarService() {
  return DeviceCalendarServiceMobile();
}

/// Mobile implementation of device calendar service
class DeviceCalendarServiceMobile implements DeviceCalendarServiceInterface {
  static final DeviceCalendarServiceMobile _instance =
      DeviceCalendarServiceMobile._internal();
  factory DeviceCalendarServiceMobile() => _instance;
  DeviceCalendarServiceMobile._internal() {
    tz.initializeTimeZones();
  }

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  String? _defaultCalendarId;

  @override
  Future<bool> requestPermissions() async {
    try {
      // Placeholder implementation - permission_handler package was removed
      // In a real implementation, you would need to handle permissions properly
      // For now, return true on mobile platforms and false on web
      if (kIsWeb) {
        LoggerService.warning('Calendar permissions not available on web',
            tag: 'DeviceCalendarService');
        return false;
      }

      // On mobile platforms, we'll attempt to use the calendar directly
      // The device_calendar plugin will handle permission requests internally
      LoggerService.info('Calendar permissions check (placeholder)',
          tag: 'DeviceCalendarService');

      // Try to retrieve calendars as a permission check
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess) {
        LoggerService.info('Calendar access available',
            tag: 'DeviceCalendarService');
        return true;
      }

      LoggerService.warning('Calendar access denied or unavailable',
          tag: 'DeviceCalendarService');
      return false;
    } catch (e) {
      LoggerService.error('Error checking calendar permissions',
          tag: 'DeviceCalendarService', error: e);
      return false;
    }
  }

  @override
  Future<List<dynamic>> getDeviceCalendars() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return [];

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        return calendarsResult.data!;
      }

      return [];
    } catch (e) {
      LoggerService.error('Error retrieving calendars',
          tag: 'DeviceCalendarService', error: e);
      return [];
    }
  }

  /// Get or create default calendar for the app
  Future<String?> _getOrCreateDefaultCalendar() async {
    try {
      if (_defaultCalendarId != null) {
        return _defaultCalendarId;
      }

      final calendars = await getDeviceCalendars();
      final calendarList = calendars.cast<Calendar>();

      // Look for existing app calendar
      final appCalendar = calendarList.firstWhere(
        (cal) => cal.name == 'Teacher Dashboard',
        orElse: () => Calendar(name: '', id: ''),
      );

      if (appCalendar.id?.isNotEmpty == true) {
        _defaultCalendarId = appCalendar.id;
        return _defaultCalendarId;
      }

      // Create new calendar if not found
      if (!kIsWeb && Platform.isAndroid) {
        // On Android, use the first writable calendar
        final writableCalendar = calendarList.firstWhere(
          (cal) => cal.isReadOnly == false,
          orElse: () => Calendar(name: '', id: ''),
        );

        if (writableCalendar.id?.isNotEmpty == true) {
          _defaultCalendarId = writableCalendar.id;
          return _defaultCalendarId;
        }
      } else if (!kIsWeb && Platform.isIOS) {
        // On iOS, we can create a new calendar
        // For now, use the default calendar
        final defaultCalendar = calendarList.firstWhere(
          (cal) => cal.isDefault == true,
          orElse: () => calendarList.isNotEmpty
              ? calendarList.first
              : Calendar(name: '', id: ''),
        );

        if (defaultCalendar.id?.isNotEmpty == true) {
          _defaultCalendarId = defaultCalendar.id;
          return _defaultCalendarId;
        }
      }

      return null;
    } catch (e) {
      LoggerService.error('Error getting/creating default calendar',
          tag: 'DeviceCalendarService', error: e);
      return null;
    }
  }

  @override
  Future<String?> addCalendarEvent({
    required CalendarEvent event,
    String? calendarId,
  }) async {
    try {
      final finalCalendarId = calendarId ?? await _getOrCreateDefaultCalendar();
      if (finalCalendarId == null) {
        LoggerService.warning('No calendar available for sync',
            tag: 'DeviceCalendarService');
        return null;
      }

      // Create device event
      final deviceEvent = Event(
        finalCalendarId,
        eventId: event.id,
        title: event.title,
        description: event.description,
        start: tz.TZDateTime.from(event.startTime, tz.local),
        end: event.endTime != null
            ? tz.TZDateTime.from(event.endTime!, tz.local)
            : tz.TZDateTime.from(
                event.startTime.add(const Duration(hours: 1)), tz.local),
        allDay: event.isAllDay,
      );

      // Set location if available
      if (event.location != null) {
        deviceEvent.location = event.location;
      }

      // Add reminder if enabled
      if (event.hasReminder && event.reminderMinutes != null) {
        deviceEvent.reminders = [
          Reminder(minutes: event.reminderMinutes!),
        ];
      }

      // Add recurrence if applicable
      if (event.recurrence != RecurrenceType.none) {
        deviceEvent.recurrenceRule = _createRecurrenceRule(event);
      }

      // Create or update event
      final result =
          await _deviceCalendarPlugin.createOrUpdateEvent(deviceEvent);

      if (result?.isSuccess == true) {
        LoggerService.info('Event synced to device calendar: ${event.title}',
            tag: 'DeviceCalendarService');
        return result!.data;
      }

      LoggerService.warning('Failed to sync event to device calendar',
          tag: 'DeviceCalendarService');
      return null;
    } catch (e) {
      LoggerService.error('Error syncing event to device calendar',
          tag: 'DeviceCalendarService', error: e);
      return null;
    }
  }

  @override
  Future<String?> addAssignmentToCalendar({
    required Assignment assignment,
    String? calendarId,
  }) async {
    try {
      final finalCalendarId = calendarId ?? await _getOrCreateDefaultCalendar();
      if (finalCalendarId == null) {
        LoggerService.warning('No calendar available for sync',
            tag: 'DeviceCalendarService');
        return null;
      }

      // Create device event for assignment
      final deviceEvent = Event(
        finalCalendarId,
        eventId: 'assignment_${assignment.id}',
        title: 'Due: ${assignment.title}',
        description: assignment.description,
        start: tz.TZDateTime.from(assignment.dueDate, tz.local),
        allDay: true,
      );

      // Add 24-hour reminder
      deviceEvent.reminders = [
        Reminder(minutes: 1440), // 24 hours
      ];

      // Create or update event
      final result =
          await _deviceCalendarPlugin.createOrUpdateEvent(deviceEvent);

      if (result?.isSuccess == true) {
        LoggerService.info(
            'Assignment synced to device calendar: ${assignment.title}',
            tag: 'DeviceCalendarService');
        return result!.data;
      }

      LoggerService.warning('Failed to sync assignment to device calendar',
          tag: 'DeviceCalendarService');
      return null;
    } catch (e) {
      LoggerService.error('Error syncing assignment to device calendar',
          tag: 'DeviceCalendarService', error: e);
      return null;
    }
  }

  @override
  Future<bool> updateCalendarEvent({
    required String eventId,
    required CalendarEvent event,
    String? calendarId,
  }) async {
    try {
      final finalCalendarId = calendarId ?? await _getOrCreateDefaultCalendar();
      if (finalCalendarId == null) return false;

      // Create updated device event
      final deviceEvent = Event(
        finalCalendarId,
        eventId: eventId,
        title: event.title,
        description: event.description,
        start: tz.TZDateTime.from(event.startTime, tz.local),
        end: event.endTime != null
            ? tz.TZDateTime.from(event.endTime!, tz.local)
            : tz.TZDateTime.from(
                event.startTime.add(const Duration(hours: 1)), tz.local),
        allDay: event.isAllDay,
      );

      // Set location if available
      if (event.location != null) {
        deviceEvent.location = event.location;
      }

      // Add reminder if enabled
      if (event.hasReminder && event.reminderMinutes != null) {
        deviceEvent.reminders = [
          Reminder(minutes: event.reminderMinutes!),
        ];
      }

      // Add recurrence if applicable
      if (event.recurrence != RecurrenceType.none) {
        deviceEvent.recurrenceRule = _createRecurrenceRule(event);
      }

      // Update event
      final result =
          await _deviceCalendarPlugin.createOrUpdateEvent(deviceEvent);

      if (result?.isSuccess == true) {
        LoggerService.info('Event updated in device calendar: ${event.title}',
            tag: 'DeviceCalendarService');
        return true;
      }

      return false;
    } catch (e) {
      LoggerService.error('Error updating event in device calendar',
          tag: 'DeviceCalendarService', error: e);
      return false;
    }
  }

  @override
  Future<bool> deleteCalendarEvent({
    required String eventId,
    String? calendarId,
  }) async {
    try {
      final finalCalendarId = calendarId ?? await _getOrCreateDefaultCalendar();
      if (finalCalendarId == null) return false;

      final result =
          await _deviceCalendarPlugin.deleteEvent(finalCalendarId, eventId);

      if (result.isSuccess) {
        LoggerService.info('Event removed from device calendar: $eventId',
            tag: 'DeviceCalendarService');
        return true;
      }

      return false;
    } catch (e) {
      LoggerService.error('Error removing event from device calendar',
          tag: 'DeviceCalendarService', error: e);
      return false;
    }
  }

  /// Create recurrence rule based on CalendarEvent settings
  RecurrenceRule? _createRecurrenceRule(CalendarEvent event) {
    if (event.recurrence == RecurrenceType.none) return null;

    RecurrenceFrequency? frequency;
    switch (event.recurrence) {
      case RecurrenceType.daily:
        frequency = RecurrenceFrequency.Daily;
        break;
      case RecurrenceType.weekly:
        frequency = RecurrenceFrequency.Weekly;
        break;
      case RecurrenceType.monthly:
        frequency = RecurrenceFrequency.Monthly;
        break;
      case RecurrenceType.yearly:
        frequency = RecurrenceFrequency.Yearly;
        break;
      default:
        return null;
    }

    return RecurrenceRule(
      frequency,
      endDate: event.recurrenceEndDate,
    );
  }
}
