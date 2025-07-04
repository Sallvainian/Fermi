import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String teacherId;
  final String name;
  final String subject;
  final String? description;
  final String gradeLevel;
  final String? room;
  final String? schedule;
  final List<String> studentIds;
  final String? syllabusUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String academicYear;
  final String semester;
  final int? maxStudents;
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
    this.settings,
  });

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
      academicYear: data['academicYear'] ?? '',
      semester: data['semester'] ?? '',
      maxStudents: data['maxStudents'],
      settings: data['settings'],
    );
  }

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
      'settings': settings,
    };
  }

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
      settings: settings ?? this.settings,
    );
  }
  
  int get studentCount => studentIds.length;
  
  bool get isFull => maxStudents != null && studentCount >= maxStudents!;
}