import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/calendar_event.dart';

/// Simplified calendar service - direct Firestore access
class SimpleCalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get calendar events
  Future<List<CalendarEvent>> getEvents() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('calendar_events')
          .where('participantIds', arrayContains: user.uid)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
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
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isActive: data['isActive'] ?? true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading events: $e');
      return [];
    }
  }

  /// Get events grouped by date
  Stream<Map<DateTime, List<CalendarEvent>>> getEventsGroupedByDate() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({});

    return _firestore
        .collection('calendar_events')
        .where('participantIds', arrayContains: user.uid)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map((doc) {
        final data = doc.data();
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
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isActive: data['isActive'] ?? true,
        );
      }).toList();

      // Group by date
      final grouped = <DateTime, List<CalendarEvent>>{};
      for (final event in events) {
        final date = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
        );
        grouped[date] = (grouped[date] ?? [])..add(event);
      }
      return grouped;
    });
  }

  /// Create calendar event with proper parameters
  Future<String> createEvent({
    required String title,
    required String createdBy,
    required String createdByName,
    required EventType type,
    required DateTime startTime,
    DateTime? endTime,
    String? description,
    String? location,
    bool isAllDay = false,
    String? classId,
    String? assignmentId,
    List<String>? participantIds,
    List<String>? participantEmails,
    String? colorHex,
    RecurrenceType recurrence = RecurrenceType.none,
    DateTime? recurrenceEndDate,
    Map<String, dynamic>? recurrenceDetails,
    bool hasReminder = false,
    int? reminderMinutes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final docRef = await _firestore.collection('calendar_events').add({
        'title': title,
        'description': description,
        'type': type.name,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime) : null,
        'isAllDay': isAllDay,
        'location': location,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'classId': classId,
        'assignmentId': assignmentId,
        'participantIds': participantIds ?? [user.uid],
        'participantEmails': participantEmails,
        'colorHex': colorHex,
        'recurrence': recurrence.name,
        'recurrenceEndDate': recurrenceEndDate != null
            ? Timestamp.fromDate(recurrenceEndDate)
            : null,
        'recurrenceDetails': recurrenceDetails,
        'hasReminder': hasReminder,
        'reminderMinutes': reminderMinutes,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating event: $e');
      rethrow;
    }
  }

  /// Update calendar event
  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('calendar_events').doc(eventId).update(updates);
    } catch (e) {
      debugPrint('Error updating event: $e');
      rethrow;
    }
  }

  /// Delete calendar event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('calendar_events').doc(eventId).delete();
    } catch (e) {
      debugPrint('Error deleting event: $e');
      rethrow;
    }
  }

  /// Get events for a specific date range
  Future<List<CalendarEvent>> getEventsInRange(DateTime start, DateTime end) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Note: Firestore doesn't support multiple inequality filters with array-contains
      // So we only filter by start date and manually filter the end date
      final snapshot = await _firestore
          .collection('calendar_events')
          .where('participantIds', arrayContains: user.uid)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('startTime')
          .get();

      // Filter by end date in memory
      final endTimestamp = Timestamp.fromDate(end);
      final filteredDocs = snapshot.docs.where((doc) {
        final startTime = doc.data()['startTime'] as Timestamp;
        return startTime.compareTo(endTimestamp) <= 0;
      }).toList();

      return filteredDocs.map((doc) {
        final data = doc.data();
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
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isActive: data['isActive'] ?? true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading events in range: $e');
      return [];
    }
  }

  /// Get a suggested color for event type
  String getSuggestedColor(EventType type) {
    switch (type) {
      case EventType.class_:
        return '#2196F3';
      case EventType.assignment:
        return '#F44336';
      case EventType.meeting:
        return '#4CAF50';
      case EventType.exam:
        return '#FF9800';
      case EventType.personal:
        return '#9C27B0';
      case EventType.school:
        return '#00BCD4';
      case EventType.other:
        return '#607D8B';
    }
  }

  /// Check for conflicts
  Future<List<CalendarEvent>> checkConflicts(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('calendar_events')
          .where('participantIds', arrayContains: userId)
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .get();

      final conflicts = <CalendarEvent>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final eventStart = (data['startTime'] as Timestamp).toDate();
        final eventEnd = data['endTime'] != null
            ? (data['endTime'] as Timestamp).toDate()
            : eventStart.add(const Duration(hours: 1));

        // Check for overlap
        if (startTime.isBefore(eventEnd) && endTime.isAfter(eventStart)) {
          conflicts.add(CalendarEvent(
            id: doc.id,
            title: data['title'] ?? '',
            description: data['description'],
            type: EventType.fromString(data['type'] ?? 'other'),
            startTime: eventStart,
            endTime: eventEnd,
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
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isActive: data['isActive'] ?? true,
          ));
        }
      }

      return conflicts;
    } catch (e) {
      debugPrint('Error checking conflicts: $e');
      return [];
    }
  }

  /// Update a CalendarEvent
  Future<void> updateCalendarEvent(String userId, CalendarEvent event) async {
    try {
      await _firestore
          .collection('calendar_events')
          .doc(event.id)
          .update(event.toFirestore());
    } catch (e) {
      debugPrint('Error updating calendar event: $e');
      rethrow;
    }
  }

  /// Delete a CalendarEvent
  Future<void> deleteCalendarEvent(String userId, String eventId) async {
    try {
      await _firestore.collection('calendar_events').doc(eventId).delete();
    } catch (e) {
      debugPrint('Error deleting calendar event: $e');
      rethrow;
    }
  }
}