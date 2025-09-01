/// State management for calendar functionality.
///
/// This module provides the calendar provider using ChangeNotifier
/// pattern, managing calendar events state and coordinating with
/// the calendar service for UI updates.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/calendar_event.dart';
import '../../data/services/calendar_service_simple.dart';
// import 'package:ical/ical.dart'; // Temporarily disabled due to null safety issues

/// Provider for managing calendar state.
///
/// Handles:
/// - Loading and caching calendar events
/// - Managing selected dates and view modes
/// - Filtering events by type
/// - Real-time updates via streams
/// - Event creation/update/deletion
class CalendarProvider with ChangeNotifier {
  // State variables
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  CalendarView _currentView = CalendarView.month;
  EventType? _filterType;

  // Events data
  List<CalendarEvent> _allEvents = [];
  Map<DateTime, List<CalendarEvent>> _eventsByDate = {};
  StreamSubscription<Map<DateTime, List<CalendarEvent>>>? _eventsSubscription;

  // Loading states
  bool _isLoading = false;
  String? _error;

  // User context
  String? _currentUserId;

  SimpleCalendarService? _calendarService;

  /// Gets the calendar service lazily.
  SimpleCalendarService get calendarService {
    _calendarService ??= SimpleCalendarService();
    return _calendarService!;
  }

  /// Creates provider with calendar service.
  CalendarProvider() {
    // CalendarProvider initialized
  }

  // Getters
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  CalendarView get currentView => _currentView;
  EventType? get filterType => _filterType;
  List<CalendarEvent> get allEvents => _allEvents;
  Map<DateTime, List<CalendarEvent>> get eventsByDate => _eventsByDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Gets events for a specific date.
  List<CalendarEvent> getEventsForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _eventsByDate[dateKey] ?? [];
  }

  /// Gets filtered events.
  List<CalendarEvent> get filteredEvents {
    if (_filterType == null) return _allEvents;
    return _allEvents.where((event) => event.type == _filterType).toList();
  }

  /// Initializes provider for a user.
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await loadUserEvents();
  }

  /// Loads events for the current user.
  Future<void> loadUserEvents() async {
    if (_currentUserId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancel previous subscription
      await _eventsSubscription?.cancel();

      // Subscribe to user events
      _eventsSubscription = calendarService
          .getEventsGroupedByDate()
          .listen((grouped) {
        _eventsByDate = grouped;
        _allEvents = grouped.values.expand((events) => events).toList();
        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets the selected date.
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Sets the focused date (month/week view).
  void setFocusedDate(DateTime date) {
    _focusedDate = date;
    notifyListeners();
  }

  /// Changes the calendar view.
  void setView(CalendarView view) {
    _currentView = view;
    notifyListeners();
  }

  /// Sets event type filter.
  void setFilterType(EventType? type) {
    _filterType = type;
    notifyListeners();
  }

  /// Creates a new event.
  Future<void> createEvent({
    required String title,
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
    if (_currentUserId == null) return;

    try {
      // Get user display name for the event
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      final userName = userDoc.data()?['displayName'] ?? 
                       userDoc.data()?['username'] ?? 
                       'Unknown User';

      await calendarService.createEvent(
        title: title,
        createdBy: _currentUserId!,
        createdByName: userName,
        type: type,
        startTime: startTime,
        endTime: endTime,
        description: description,
        location: location,
        classId: classId,
        assignmentId: assignmentId,
        participantIds: participantIds,
        isAllDay: isAllDay,
        recurrence: recurrence,
        recurrenceEndDate: recurrenceEndDate,
        hasReminder: hasReminder,
        reminderMinutes: reminderMinutes,
        colorHex: colorHex ?? calendarService.getSuggestedColor(type),
      );

      // Events will update via stream
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates an existing event.
  Future<void> updateEvent(CalendarEvent event) async {
    if (_currentUserId == null) return;

    try {
      await calendarService.updateCalendarEvent(_currentUserId!, event);
      // Events will update via stream
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes an event.
  Future<void> deleteEvent(String eventId) async {
    if (_currentUserId == null) return;

    try {
      await calendarService.deleteCalendarEvent(_currentUserId!, eventId);
      // Events will update via stream
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Checks for conflicts with a proposed event time.
  Future<List<CalendarEvent>> checkConflicts(
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (_currentUserId == null) return [];

    return await calendarService.checkConflicts(
      _currentUserId!,
      startTime,
      endTime,
    );
  }

  /// Gets events for export/sharing.
  /// Note: Basic iCalendar export implementation. Consider upgrading to a dedicated
  /// iCalendar package when null-safe options become available for enhanced features.
  String exportEventsToICS() {
    final buffer = StringBuffer();

    // Basic iCalendar format
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Teacher Dashboard//EN');

    for (final event in _allEvents) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${event.id}');
      buffer.writeln('SUMMARY:${event.title}');
      if (event.description != null && event.description!.isNotEmpty) {
        buffer.writeln('DESCRIPTION:${event.description}');
      }
      buffer.writeln('DTSTART:${_formatDateTime(event.startTime)}');
      if (event.endTime != null) {
        buffer.writeln('DTEND:${_formatDateTime(event.endTime!)}');
      }
      if (event.location != null && event.location!.isNotEmpty) {
        buffer.writeln('LOCATION:${event.location}');
      }
      buffer.writeln('STATUS:CONFIRMED');

      // Add basic recurrence rule if needed
      if (event.recurrence != RecurrenceType.none) {
        buffer
            .writeln('RRULE:FREQ=${_mapRecurrenceToString(event.recurrence)}');
      }

      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    return dateTime
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:-]'), '')
        .replaceAll('.000Z', 'Z');
  }

  String _mapRecurrenceToString(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return 'DAILY';
      case RecurrenceType.weekly:
        return 'WEEKLY';
      case RecurrenceType.monthly:
        return 'MONTHLY';
      case RecurrenceType.yearly:
        return 'YEARLY';
      default:
        return 'DAILY';
    }
  }

  /// Navigates to previous period based on view.
  void navigatePrevious() {
    switch (_currentView) {
      case CalendarView.month:
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month - 1,
        );
        break;
      case CalendarView.week:
        _focusedDate = _focusedDate.subtract(const Duration(days: 7));
        break;
      case CalendarView.agenda:
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month - 1,
        );
        break;
    }
    notifyListeners();
  }

  /// Navigates to next period based on view.
  void navigateNext() {
    switch (_currentView) {
      case CalendarView.month:
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month + 1,
        );
        break;
      case CalendarView.week:
        _focusedDate = _focusedDate.add(const Duration(days: 7));
        break;
      case CalendarView.agenda:
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month + 1,
        );
        break;
    }
    notifyListeners();
  }

  /// Goes to today.
  void goToToday() {
    _selectedDate = DateTime.now();
    _focusedDate = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }
}

/// Enumeration of calendar view modes.
enum CalendarView {
  month,
  week,
  agenda,
}
