/// Behavior model for tracking student behavior types and point values.
///
/// This module contains the data model for behaviors used in the
/// behavior points system within the education platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Enumeration representing the types of behaviors.
///
/// Behaviors can be either positive (earning points) or negative (losing points):
/// - [positive]: Good behaviors that earn points
/// - [negative]: Poor behaviors that result in point deductions
enum BehaviorType { positive, negative }

/// Core behavior model representing different behavior types and their point values.
///
/// Behaviors define the actions students can be recognized for, including:
/// - Point values (positive or negative)
/// - Visual representation through icons
/// - Categorization by type
/// - Teacher customization options
/// - Class-specific or system-wide behaviors
///
/// The system includes default behaviors but allows teachers to create
/// custom behaviors specific to their classes.
class Behavior {
  /// Unique identifier for the behavior
  final String id;

  /// Name of the behavior (e.g., "Working Hard")
  final String name;

  /// Detailed description of the behavior
  final String description;

  /// Point value assigned to this behavior (positive or negative)
  final int points;

  /// Type of behavior (positive or negative)
  final BehaviorType type;

  /// Icon data for visual representation
  final IconData iconData;

  /// Whether this is a custom behavior created by a teacher
  final bool isCustom;

  /// ID of the teacher who created this behavior (null for default behaviors)
  final String? teacherId;

  /// ID of the class this behavior applies to (null for system-wide behaviors)
  final String? classId;

  /// Timestamp when the behavior was created
  final DateTime createdAt;

  /// Timestamp of last modification (null if never updated)
  final DateTime? updatedAt;

  Behavior({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.type,
    required this.iconData,
    this.isCustom = false,
    this.teacherId,
    this.classId,
    required this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to create Behavior from Firestore document.
  ///
  /// Handles data parsing including:
  /// - Timestamp to DateTime conversions
  /// - Enum parsing with fallback defaults
  /// - Icon data conversion from codePoint
  /// - Null safety for optional fields
  ///
  /// @param doc Firestore document snapshot containing behavior data
  /// @return Parsed Behavior instance
  factory Behavior.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Helper function to convert either Timestamp or DateTime to DateTime
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return Behavior(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      points: data['points'] ?? 0,
      type: BehaviorType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => BehaviorType.positive,
      ),
      iconData: IconData(
        data['iconCodePoint'] ?? Icons.star.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      isCustom: data['isCustom'] ?? false,
      teacherId: data['teacherId'],
      classId: data['classId'],
      createdAt: parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  /// Alternative factory constructor to create Behavior from Map data.
  ///
  /// @param id Behavior identifier
  /// @param data Map containing behavior fields
  /// @return Parsed Behavior instance
  factory Behavior.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return Behavior(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      points: data['points'] ?? 0,
      type: BehaviorType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => BehaviorType.positive,
      ),
      iconData: IconData(
        data['iconCodePoint'] ?? Icons.star.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      isCustom: data['isCustom'] ?? false,
      teacherId: data['teacherId'],
      classId: data['classId'],
      createdAt: parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  /// Converts the Behavior instance to a Map for Firestore storage.
  ///
  /// Serializes all behavior data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Enum values to string representations
  /// - Icon data to codePoint for storage
  /// - Null checks for optional fields
  ///
  /// @return Map containing all behavior data ready for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'points': points,
      'type': type.name,
      'iconCodePoint': iconData.codePoint,
      'isCustom': isCustom,
      'teacherId': teacherId,
      'classId': classId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Creates a copy of the Behavior with updated fields.
  ///
  /// Follows the immutable data pattern, allowing selective field updates
  /// while preserving all other values.
  ///
  /// @return New Behavior instance with updated fields
  Behavior copyWith({
    String? id,
    String? name,
    String? description,
    int? points,
    BehaviorType? type,
    IconData? iconData,
    bool? isCustom,
    String? teacherId,
    String? classId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Behavior(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      points: points ?? this.points,
      type: type ?? this.type,
      iconData: iconData ?? this.iconData,
      isCustom: isCustom ?? this.isCustom,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Static list of default positive behaviors
  static List<Behavior> get defaultPositiveBehaviors => [
        Behavior(
          id: 'working_hard',
          name: 'Working Hard',
          description: 'Student demonstrates effort and persistence in their work',
          points: 2,
          type: BehaviorType.positive,
          iconData: Icons.work_outline,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'participating',
          name: 'Participating',
          description: 'Student actively engages in class discussions and activities',
          points: 2,
          type: BehaviorType.positive,
          iconData: Icons.record_voice_over,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'on_task',
          name: 'On Task',
          description: 'Student stays focused and completes assigned work',
          points: 1,
          type: BehaviorType.positive,
          iconData: Icons.task_alt,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'helping_others',
          name: 'Helping Others',
          description: 'Student assists classmates and shows kindness',
          points: 3,
          type: BehaviorType.positive,
          iconData: Icons.helping_hand_outlined,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'teamwork',
          name: 'Teamwork',
          description: 'Student collaborates effectively with others',
          points: 2,
          type: BehaviorType.positive,
          iconData: Icons.groups,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'good_manners',
          name: 'Good Manners',
          description: 'Student demonstrates politeness and respect',
          points: 1,
          type: BehaviorType.positive,
          iconData: Icons.emoji_people,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'following_directions',
          name: 'Following Directions',
          description: 'Student listens carefully and follows instructions',
          points: 1,
          type: BehaviorType.positive,
          iconData: Icons.directions_run,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'making_smart_choices',
          name: 'Making Smart Choices',
          description: 'Student demonstrates good decision-making skills',
          points: 2,
          type: BehaviorType.positive,
          iconData: Icons.psychology,
          createdAt: DateTime.now(),
        ),
      ];

  /// Static list of default negative behaviors
  static List<Behavior> get defaultNegativeBehaviors => [
        Behavior(
          id: 'not_following_directions',
          name: 'Not Following Directions',
          description: 'Student fails to listen to or follow given instructions',
          points: -1,
          type: BehaviorType.negative,
          iconData: Icons.do_not_disturb,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'off_task',
          name: 'Off Task',
          description: 'Student is not focused on assigned work or activities',
          points: -1,
          type: BehaviorType.negative,
          iconData: Icons.schedule,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'talking',
          name: 'Talking',
          description: 'Student talks inappropriately during instruction or quiet work time',
          points: -1,
          type: BehaviorType.negative,
          iconData: Icons.chat_bubble_outline,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'disrespectful',
          name: 'Disrespectful',
          description: 'Student shows disrespect to teacher or classmates',
          points: -3,
          type: BehaviorType.negative,
          iconData: Icons.thumb_down,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'no_homework',
          name: 'No Homework',
          description: 'Student did not complete or bring assigned homework',
          points: -2,
          type: BehaviorType.negative,
          iconData: Icons.assignment_late,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'playing',
          name: 'Playing',
          description: 'Student plays with objects or acts inappropriately during class',
          points: -1,
          type: BehaviorType.negative,
          iconData: Icons.toys,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'arguing',
          name: 'Arguing',
          description: 'Student argues with teacher or classmates',
          points: -2,
          type: BehaviorType.negative,
          iconData: Icons.forum,
          createdAt: DateTime.now(),
        ),
        Behavior(
          id: 'blurting_out',
          name: 'Blurting Out',
          description: 'Student speaks without permission or interrupts others',
          points: -1,
          type: BehaviorType.negative,
          iconData: Icons.volume_up,
          createdAt: DateTime.now(),
        ),
      ];

  /// Gets all default behaviors (positive and negative combined)
  static List<Behavior> get allDefaultBehaviors => [
        ...defaultPositiveBehaviors,
        ...defaultNegativeBehaviors,
      ];
}