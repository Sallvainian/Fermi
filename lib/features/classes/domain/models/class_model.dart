/// Class model for managing educational classes and courses.
/// 
/// This module contains the data model for classes, representing
/// the courses taught by teachers and attended by students in
/// the education management system.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Core class model representing an educational class or course.
/// 
/// This model encapsulates all data related to a class, including:
/// - Basic information (name, subject, grade level)
/// - Teacher and student associations
/// - Scheduling and location details
/// - Academic period information
/// - Configuration settings
/// 
/// Classes serve as the primary organizational unit for:
/// - Assignment distribution
/// - Grade tracking
/// - Student enrollment
/// - Communication channels
class ClassModel {
  /// Unique identifier for the class
  final String id;
  
  /// ID of the teacher who manages this class
  final String teacherId;
  
  /// Display name of the class (e.g., "Advanced Mathematics")
  final String name;
  
  /// Subject area of the class (e.g., "Mathematics", "Science")
  final String subject;
  
  /// Optional detailed description of the class content and objectives
  final String? description;
  
  /// Grade level for the class (e.g., "10", "11-12", "AP")
  final String gradeLevel;
  
  /// Physical classroom location (e.g., "Room 201", "Lab A")
  final String? room;
  
  /// Class meeting schedule (e.g., "MWF 10:00-11:00 AM")
  final String? schedule;
  
  /// List of student IDs enrolled in this class
  final List<String> studentIds;
  
  /// Optional URL to the class syllabus document
  final String? syllabusUrl;
  
  /// Timestamp when the class was created
  final DateTime createdAt;
  
  /// Timestamp of last modification (null if never updated)
  final DateTime? updatedAt;
  
  /// Whether the class is currently active
  final bool isActive;
  
  /// Academic year for the class (e.g., "2023-2024")
  final String academicYear;
  
  /// Semester or term (e.g., "Fall", "Spring", "Q1")
  final String semester;
  
  /// Optional maximum number of students allowed in the class
  final int? maxStudents;
  
  /// Unique enrollment code for students to join the class
  final String? enrollmentCode;
  
  /// Flexible settings map for class-specific configurations
  final Map<String, dynamic>? settings;

  ClassModel({
    required this.id,
    required this.teacherId,
    required this.name,
    required this.subject,
    this.description,
    required this.gradeLevel,
    this.room,
    this.schedule,
    required this.studentIds,
    this.syllabusUrl,
    required this.createdAt,
    this.updatedAt,
    required this.isActive,
    required this.academicYear,
    required this.semester,
    this.maxStudents,
    this.enrollmentCode,
    this.settings,
  });

  /// Factory constructor to create ClassModel from Firestore document.
  /// 
  /// Handles data parsing and type conversions including:
  /// - Timestamp to DateTime conversions
  /// - List casting for student IDs
  /// - Null safety for optional fields
  /// - Default values for required fields
  /// 
  /// @param doc Firestore document snapshot containing class data
  /// @return Parsed ClassModel instance
  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Debug logging for diagnostics
    print('DEBUG: Parsing class document ${doc.id}');
    print('DEBUG: Data keys: ${data.keys.toList()}');
    print('DEBUG: createdAt type: ${data['createdAt']?.runtimeType}');
    print('DEBUG: createdAt value: ${data['createdAt']}');
    
    // Safe timestamp parsing with fallback
    DateTime parseTimestamp(dynamic value, {DateTime? fallback}) {
      if (value == null) {
        print('DEBUG: Timestamp is null, using fallback');
        return fallback ?? DateTime.now();
      }
      
      try {
        if (value is Timestamp) {
          print('DEBUG: Converting Timestamp to DateTime');
          return value.toDate();
        } else if (value is DateTime) {
          print('DEBUG: Already a DateTime');
          return value;
        } else if (value is String) {
          print('DEBUG: Parsing string timestamp: $value');
          return DateTime.parse(value);
        } else if (value is int) {
          print('DEBUG: Converting milliseconds to DateTime: $value');
          return DateTime.fromMillisecondsSinceEpoch(value);
        } else {
          print('WARNING: Unknown timestamp type: ${value.runtimeType}');
          return fallback ?? DateTime.now();
        }
      } catch (e) {
        print('ERROR: Failed to parse timestamp: $e');
        print('ERROR: Value was: $value (${value.runtimeType})');
        return fallback ?? DateTime.now();
      }
    }
    
    try {
      return ClassModel(
        id: doc.id,
        teacherId: data['teacherId'] ?? '',
        name: data['name'] ?? '',
        subject: data['subject'] ?? '',
        description: data['description'],
        gradeLevel: data['gradeLevel'] ?? '',
        room: data['room'],
        schedule: data['schedule'],
        studentIds: List<String>.from(data['studentIds'] ?? []),
        syllabusUrl: data['syllabusUrl'],
        createdAt: parseTimestamp(data['createdAt']),
        updatedAt: data['updatedAt'] != null 
            ? parseTimestamp(data['updatedAt']) 
            : null,
        isActive: data['isActive'] ?? true,
        academicYear: data['academicYear'] ?? '2024-2025',
        semester: data['semester'] ?? 'Fall',
        maxStudents: data['maxStudents'],
        enrollmentCode: data['enrollmentCode'],
        settings: data['settings'],
      );
    } catch (e, stack) {
      print('CRITICAL ERROR: Failed to create ClassModel from Firestore');
      print('Error: $e');
      print('Stack: $stack');
      print('Document ID: ${doc.id}');
      print('Data: $data');
      
      // Return a minimal valid ClassModel to prevent crashes
      return ClassModel(
        id: doc.id,
        teacherId: data['teacherId'] ?? '',
        name: data['name'] ?? 'Unknown Class',
        subject: data['subject'] ?? 'Unknown',
        gradeLevel: data['gradeLevel'] ?? 'Unknown',
        studentIds: [],
        createdAt: DateTime.now(),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Fall',
      );
    }
  }

  /// Converts the ClassModel instance to a Map for Firestore storage.
  /// 
  /// Serializes all class data for persistence, including:
  /// - DateTime fields to Firestore Timestamps
  /// - Null checks for optional fields
  /// - Direct storage of complex types (lists, maps)
  /// 
  /// @return Map containing all class data ready for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'teacherId': teacherId,
      'name': name,
      'subject': subject,
      'description': description,
      'gradeLevel': gradeLevel,
      'room': room,
      'schedule': schedule,
      'studentIds': studentIds,
      'syllabusUrl': syllabusUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'academicYear': academicYear,
      'semester': semester,
      'maxStudents': maxStudents,
      'enrollmentCode': enrollmentCode,
      'settings': settings,
    };
  }

  /// Creates a copy of the ClassModel with updated fields.
  /// 
  /// Follows the immutable data pattern, allowing selective field updates
  /// while preserving all other values. Useful for:
  /// - Updating class details
  /// - Adding/removing students
  /// - Changing scheduling information
  /// - Modifying settings
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New ClassModel instance with updated fields
  ClassModel copyWith({
    String? id,
    String? teacherId,
    String? name,
    String? subject,
    String? description,
    String? gradeLevel,
    String? room,
    String? schedule,
    List<String>? studentIds,
    String? syllabusUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? academicYear,
    String? semester,
    int? maxStudents,
    String? enrollmentCode,
    Map<String, dynamic>? settings,
  }) {
    return ClassModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      room: room ?? this.room,
      schedule: schedule ?? this.schedule,
      studentIds: studentIds ?? this.studentIds,
      syllabusUrl: syllabusUrl ?? this.syllabusUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      maxStudents: maxStudents ?? this.maxStudents,
      enrollmentCode: enrollmentCode ?? this.enrollmentCode,
      settings: settings ?? this.settings,
    );
  }
  
  /// Gets the current number of students enrolled in the class.
  /// @return Count of students in the studentIds list
  int get studentCount => studentIds.length;
  
  /// Checks if the class has reached its maximum capacity.
  /// @return true if class is at or above max capacity, false otherwise
  bool get isFull => maxStudents != null && studentCount >= maxStudents!;
}