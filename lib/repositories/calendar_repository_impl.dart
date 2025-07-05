/// Concrete implementation of the calendar repository.
/// 
/// This module implements the CalendarRepository interface using
/// Firebase Firestore for data persistence, providing full CRUD
/// operations for calendar events with recurrence support.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_event.dart';
import 'calendar_repository.dart';

/// Firebase implementation of CalendarRepository.
/// 
/// Manages calendar events in Firestore with support for:
/// - Multiple event types (classes, assignments, meetings, etc.)
/// - Recurrence patterns for repeating events
/// - Participant management
/// - Date-based queries with recurrence calculation
class CalendarRepositoryImpl implements CalendarRepository {
  final FirebaseFirestore _firestore;
  static const String _collection = 'calendar_events';
  
  /// Creates repository with Firestore instance.
  CalendarRepositoryImpl(this._firestore);
  
  @override
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    final docRef = await _firestore.collection(_collection).add(
      event.toFirestore(),
    );
    
    return event.copyWith(id: docRef.id);
  }
  
  @override
  Future<CalendarEvent> updateEvent(CalendarEvent event) async {
    await _firestore.collection(_collection).doc(event.id).update(
      event.copyWith(updatedAt: DateTime.now()).toFirestore(),
    );
    
    return event.copyWith(updatedAt: DateTime.now());
  }
  
  @override
  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection(_collection).doc(eventId).delete();
  }
  
  @override
  Future<CalendarEvent?> getEvent(String eventId) async {
    final doc = await _firestore.collection(_collection).doc(eventId).get();
    
    if (!doc.exists) return null;
    
    return CalendarEvent.fromFirestore(doc);
  }
  
  @override
  Stream<List<CalendarEvent>> getUserEvents(String userId) {
    // Get events where user is creator or participant
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where(
          Filter.or(
            Filter('createdBy', isEqualTo: userId),
            Filter('participantIds', arrayContains: userId),
          ),
        )
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromFirestore(doc))
            .toList());
  }
  
  @override
  Stream<List<CalendarEvent>> getEventsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Get all user events and filter by date range including recurrence
    return getUserEvents(userId).map((events) {
      return events.where((event) {
        // Check if event or its recurrences fall within range
        if (event.recurrence == RecurrenceType.none) {
          // Single event - check if it's in range
          return event.startTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
                 event.startTime.isBefore(endDate.add(const Duration(days: 1)));
        } else {
          // Recurring event - check if any instance is in range
          final eventEnd = event.recurrenceEndDate ?? endDate;
          
          // Event starts before range end and ends after range start
          return event.startTime.isBefore(endDate.add(const Duration(days: 1))) &&
                 eventEnd.isAfter(startDate.subtract(const Duration(days: 1)));
        }
      }).toList();
    });
  }
  
  @override
  Stream<List<CalendarEvent>> getClassEvents(String classId) {
    return _firestore
        .collection(_collection)
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromFirestore(doc))
            .toList());
  }
  
  @override
  Stream<List<CalendarEvent>> getEventsByType(
    String userId,
    EventType type,
  ) {
    return getUserEvents(userId).map((events) =>
        events.where((event) => event.type == type).toList());
  }
  
  @override
  Stream<List<CalendarEvent>> getUpcomingEvents(
    String userId,
    int daysAhead,
  ) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    
    return getEventsByDateRange(userId, now, endDate);
  }
  
  @override
  Future<List<CalendarEvent>> getEventsForDate(
    String userId,
    DateTime date,
  ) async {
    // Get all user events
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where(
          Filter.or(
            Filter('createdBy', isEqualTo: userId),
            Filter('participantIds', arrayContains: userId),
          ),
        )
        .get();
    
    final events = snapshot.docs
        .map((doc) => CalendarEvent.fromFirestore(doc))
        .toList();
    
    // Filter events that occur on the specified date
    return events.where((event) => event.occursOn(date)).toList();
  }
  
  @override
  Future<void> addParticipant(String eventId, String participantId) async {
    await _firestore.collection(_collection).doc(eventId).update({
      'participantIds': FieldValue.arrayUnion([participantId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Future<void> removeParticipant(String eventId, String participantId) async {
    await _firestore.collection(_collection).doc(eventId).update({
      'participantIds': FieldValue.arrayRemove([participantId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Future<List<String>> getEventParticipants(String eventId) async {
    final doc = await _firestore.collection(_collection).doc(eventId).get();
    
    if (!doc.exists) return [];
    
    final data = doc.data() as Map<String, dynamic>;
    return List<String>.from(data['participantIds'] ?? []);
  }
  
  @override
  Future<bool> canEditEvent(String userId, String eventId) async {
    final event = await getEvent(eventId);
    
    if (event == null) return false;
    
    // User can edit if they are the creator
    return event.createdBy == userId;
  }
  
  @override
  Stream<List<CalendarEvent>> getEventsNeedingReminders(
    DateTime fromTime,
    DateTime toTime,
  ) {
    return _firestore
        .collection(_collection)
        .where('hasReminder', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('startTime', isGreaterThan: Timestamp.fromDate(fromTime))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(toTime))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromFirestore(doc))
            .where((event) {
              if (event.reminderMinutes == null) return false;
              
              final reminderTime = event.startTime.subtract(
                Duration(minutes: event.reminderMinutes!),
              );
              
              return reminderTime.isAfter(fromTime) &&
                     reminderTime.isBefore(toTime);
            })
            .toList());
  }
}