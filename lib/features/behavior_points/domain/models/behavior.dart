/// Behavior model for tracking student behavior types and point values.
///
/// This module contains the data model for behaviors used in the
/// behavior points system within the education platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/behavior_icons.dart';

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

  /// Icon name for storage and retrieval
  final String? iconName;

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
    this.iconName,
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
  /// - JavaScript object conversion for web platform
  ///
  /// @param doc Firestore document snapshot containing behavior data
  /// @return Parsed Behavior instance
  factory Behavior.fromFirestore(DocumentSnapshot doc) {
    // Handle potential null data or LegacyJavaScriptObject issues
    final rawData = doc.data();
    if (rawData == null) {
      // Return default behavior if data is null
      return Behavior(
        id: doc.id,
        name: 'Unknown',
        description: '',
        points: 0,
        type: BehaviorType.positive,
        iconData: BehaviorIcons.defaultIcon,
        createdAt: DateTime.now(),
      );
    }

    // Convert to proper Map<String, dynamic>, handling JavaScript objects
    Map<String, dynamic> data;
    try {
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else {
        // Handle JavaScript object conversion (for web platform)
        data = Map<String, dynamic>.from(rawData as Map);
      }
    } catch (e) {
      // Fallback for any conversion errors
      data = <String, dynamic>{};
    }

    // Helper function to convert either Timestamp or DateTime to DateTime
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      // Handle JavaScript date object structure
      if (value is Map) {
        if (value['_seconds'] != null) {
          final seconds = value['_seconds'] as int;
          final nanoseconds = (value['_nanoseconds'] as int?) ?? 0;
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
          );
        }
      }
      return null;
    }

    // Get IconData from predefined constants map to ensure compile-time constant
    final int iconCodePoint = data['iconCodePoint'] ?? Icons.star.codePoint;
    final iconData = BehaviorIcons.getIconFromCodePoint(iconCodePoint);

    return Behavior(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      points: data['points'] ?? 0,
      type: BehaviorType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => BehaviorType.positive,
      ),
      iconData: iconData,
      iconName: data['iconName'],
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
      // Handle JavaScript date object structure
      if (value is Map) {
        if (value['_seconds'] != null) {
          final seconds = value['_seconds'] as int;
          final nanoseconds = (value['_nanoseconds'] as int?) ?? 0;
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
          );
        }
      }
      return null;
    }

    // Get IconData from predefined constants map to ensure compile-time constant
    final int iconCodePoint = data['iconCodePoint'] ?? Icons.star.codePoint;
    final iconData = BehaviorIcons.getIconFromCodePoint(iconCodePoint);

    return Behavior(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      points: data['points'] ?? 0,
      type: BehaviorType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => BehaviorType.positive,
      ),
      iconData: iconData,
      iconName: data['iconName'],
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
      'iconName': iconName,
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
    String? iconName,
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
      iconName: iconName ?? this.iconName,
      isCustom: isCustom ?? this.isCustom,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
