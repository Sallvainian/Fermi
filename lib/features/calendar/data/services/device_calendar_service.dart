/// This file is deprecated and kept only for reference.
/// 
/// Use the platform-specific implementations instead:
/// - device_calendar_service_interface.dart - The interface
/// - device_calendar_service_factory.dart - The factory
/// - device_calendar_service_mobile.dart - Mobile implementation
/// - device_calendar_service_web.dart - Web implementation
/// 
/// Example usage:
/// ```dart
/// final service = DeviceCalendarServiceFactory.create();
/// await service.addCalendarEvent(event: myEvent);
/// ```
library;

import 'dart:io';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../domain/models/calendar_event.dart';
import '../../../../models/assignment.dart';
import '../../../../shared/services/logger_service.dart';

/// DEPRECATED: Use DeviceCalendarServiceFactory.create() instead
/// Service for syncing events with device calendar
@Deprecated('Use DeviceCalendarServiceFactory.create() instead')
class DeviceCalendarService {
  static final DeviceCalendarService _instance = DeviceCalendarService._internal();
  factory DeviceCalendarService() => _instance;
  DeviceCalendarService._internal() {
    tzdata.initializeTimeZones();
  }

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  String? _defaultCalendarId;
  
  /// Check and request calendar permissions
  Future<bool> requestPermissions() async {
    try {
      // Request calendar permission
      final status = await Permission.calendarFullAccess.request();
      
      if (status.isGranted) {
        LoggerService.info('Calendar permissions granted', tag: 'DeviceCalendarService');
        return true;
      } else if (status.isPermanentlyDenied) {
        // Open app settings if permanently denied
        await openAppSettings();
      }
      
      LoggerService.warning('Calendar permissions denied', tag: 'DeviceCalendarService');
      return false;
    } catch (e) {
      LoggerService.error('Error requesting calendar permissions', 
          tag: 'DeviceCalendarService', error: e);
      return false;
    }
  }
  
  /// Get list of device calendars
  Future<List<Calendar>> getDeviceCalendars() async {
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
  Future<String?> getOrCreateDefaultCalendar() async {
    try {
      if (_defaultCalendarId != null) {
        return _defaultCalendarId;
      }
      
      final calendars = await getDeviceCalendars();
      
      // Look for existing app calendar
      final appCalendar = calendars.firstWhere(
        (cal) => cal.name == 'Teacher Dashboard',
        orElse: () => Calendar(name: '', id: ''),
      );
      
      if (appCalendar.id?.isNotEmpty == true) {
        _defaultCalendarId = appCalendar.id;
        return _defaultCalendarId;
      }
      
      // Create new calendar if not found
      if (Platform.isAndroid) {
        // On Android, use the first writable calendar
        final writableCalendar = calendars.firstWhere(
          (cal) => cal.isReadOnly == false,
          orElse: () => Calendar(name: '', id: ''),
        );
        
        if (writableCalendar.id?.isNotEmpty == true) {
          _defaultCalendarId = writableCalendar.id;
          return _defaultCalendarId;
        }
      } else if (Platform.isIOS) {
        // On iOS, we can create a new calendar
        // For now, use the default calendar
        final defaultCalendar = calendars.firstWhere(
          (cal) => cal.isDefault == true,
          orElse: () => calendars.isNotEmpty ? calendars.first : Calendar(name: '', id: ''),
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
  
  /// Sync calendar event to device calendar
  Future<bool> syncEventToDevice(CalendarEvent event) async {
    try {
      final calendarId = await getOrCreateDefaultCalendar();
      if (calendarId == null) {
        LoggerService.warning('No calendar available for sync', 
            tag: 'DeviceCalendarService');
        return false;
      }
      
      // Create device event
      final deviceEvent = Event(
        calendarId,
        eventId: event.id,
        title: event.title,
        description: event.description,
        start: tz.TZDateTime.from(event.startTime, tz.local),
        end: event.endTime != null 
            ? tz.TZDateTime.from(event.endTime!, tz.local)
            : tz.TZDateTime.from(event.startTime.add(const Duration(hours: 1)), tz.local),
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
      final result = await _deviceCalendarPlugin.createOrUpdateEvent(deviceEvent);
      
      if (result?.isSuccess == true) {
        LoggerService.info('Event synced to device calendar: ${event.title}', 
            tag: 'DeviceCalendarService');
        return true;
      }
      
      LoggerService.warning('Failed to sync event to device calendar', 
          tag: 'DeviceCalendarService');
      return false;
    } catch (e) {
      LoggerService.error('Error syncing event to device calendar', 
          tag: 'DeviceCalendarService', error: e);
      return false;
    }
  }
  
  /// Sync assignment to device calendar
  Future<bool> syncAssignmentToDevice(Assignment assignment) async {
    try {
      final calendarId = await getOrCreateDefaultCalendar();
      if (calendarId == null) {
        LoggerService.warning('No calendar available for sync', 
            tag: 'DeviceCalendarService');
        return false;
      }
      
      // Create device event for assignment
      final deviceEvent = Event(
        calendarId,
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
      final result = await _deviceCalendarPlugin.createOrUpdateEvent(deviceEvent);
      
      if (result?.isSuccess == true) {
        LoggerService.info('Assignment synced to device calendar: ${assignment.title}', 
            tag: 'DeviceCalendarService');
        return true;
      }
      
      LoggerService.warning('Failed to sync assignment to device calendar', 
          tag: 'DeviceCalendarService');
      return false;
    } catch (e) {
      LoggerService.error('Error syncing assignment to device calendar', 
          tag: 'DeviceCalendarService', error: e);
      return false;
    }
  }
  
  /// Remove event from device calendar
  Future<bool> removeEventFromDevice(String eventId) async {
    try {
      final calendarId = await getOrCreateDefaultCalendar();
      if (calendarId == null) return false;
      
      final result = await _deviceCalendarPlugin.deleteEvent(calendarId, eventId);
      
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