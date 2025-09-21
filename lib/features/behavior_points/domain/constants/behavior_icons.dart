import 'package:flutter/material.dart';

/// Predefined behavior icons as compile-time constants for tree shaking.
///
/// This class provides a static map of icon codepoints to IconData instances
/// to ensure all icons are compile-time constants, allowing Flutter to properly
/// tree-shake unused icons and reduce app size.
class BehaviorIcons {
  BehaviorIcons._(); // Private constructor to prevent instantiation

  // Positive behavior icons
  static const IconData star = Icons.star;
  static const IconData thumbUp = Icons.thumb_up;
  static const IconData favorite = Icons.favorite;
  static const IconData lightbulb = Icons.lightbulb;
  static const IconData psychology = Icons.psychology;
  static const IconData frontHand = Icons.front_hand;
  static const IconData peopleOutline = Icons.people_outline;
  static const IconData schedule = Icons.schedule;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData emojiEmotions = Icons.emoji_emotions;
  static const IconData school = Icons.school;
  static const IconData assignmentTurnedIn = Icons.assignment_turned_in;
  static const IconData volunteerActivism = Icons.volunteer_activism;
  static const IconData workspacePremium = Icons.workspace_premium;
  static const IconData trendingUp = Icons.trending_up;

  // Negative/Neutral behavior icons
  static const IconData warning = Icons.warning;
  static const IconData cancel = Icons.cancel;
  static const IconData accessTime = Icons.access_time;
  static const IconData assignmentLate = Icons.assignment_late;
  static const IconData moodBad = Icons.mood_bad;
  static const IconData phonelinkOff = Icons.phonelink_off;
  static const IconData backpack = Icons.backpack;
  static const IconData recordVoiceOver = Icons.record_voice_over;
  static const IconData priorityHigh = Icons.priority_high;
  static const IconData errorOutline = Icons.error_outline;
  static const IconData thumbDown = Icons.thumb_down;
  static const IconData removeCircleOutline = Icons.remove_circle_outline;
  static const IconData block = Icons.block;
  static const IconData notificationsOff = Icons.notifications_off;
  static const IconData trendingDown = Icons.trending_down;

  // Additional commonly used icons
  static const IconData starOutline = Icons.star_outline;
  static const IconData add = Icons.add;
  static const IconData remove = Icons.remove;
  static const IconData build = Icons.build;

  /// Map of icon codepoints to their corresponding IconData constants.
  /// Used to look up icons when loading from Firestore.
  static const Map<int, IconData> iconMap = {
    // Positive behavior icons
    0xe5f9: star, // Icons.star.codePoint
    0xe8dc: thumbUp, // Icons.thumb_up
    0xe25b: favorite, // Icons.favorite
    0xe0f0: lightbulb, // Icons.lightbulb
    0xe631: psychology, // Icons.psychology
    0xe9ae: frontHand, // Icons.front_hand
    0xe7fc: peopleOutline, // Icons.people_outline
    0xe8b5: schedule, // Icons.schedule
    0xe86c: checkCircle, // Icons.check_circle
    0xe7f2: emojiEmotions, // Icons.emoji_emotions
    0xe80c: school, // Icons.school
    0xe169: assignmentTurnedIn, // Icons.assignment_turned_in
    0xea70: volunteerActivism, // Icons.volunteer_activism
    0xf490: workspacePremium, // Icons.workspace_premium
    0xe8e5: trendingUp, // Icons.trending_up

    // Negative/Neutral behavior icons
    0xe002: warning, // Icons.warning
    0xe5c9: cancel, // Icons.cancel
    0xe003: accessTime, // Icons.access_time
    0xe16a: assignmentLate, // Icons.assignment_late
    0xe7f3: moodBad, // Icons.mood_bad
    0xe627: phonelinkOff, // Icons.phonelink_off
    0xf540: backpack, // Icons.backpack
    0xe91f: recordVoiceOver, // Icons.record_voice_over
    0xe645: priorityHigh, // Icons.priority_high
    0xe001: errorOutline, // Icons.error_outline
    0xe8db: thumbDown, // Icons.thumb_down
    0xe15d: removeCircleOutline, // Icons.remove_circle_outline
    0xe14b: block, // Icons.block
    0xe7f6: notificationsOff, // Icons.notifications_off
    0xe8e6: trendingDown, // Icons.trending_down

    // Additional commonly used icons
    0xe5f8: starOutline, // Icons.star_outline
    0xe047: add, // Icons.add
    0xe15b: remove, // Icons.remove
    0xe869: build, // Icons.build
  };

  /// Get IconData from codepoint, with fallback to star icon.
  ///
  /// This method ensures we always return a valid compile-time constant IconData,
  /// never creating dynamic IconData instances.
  static IconData getIconFromCodePoint(int codePoint) {
    return iconMap[codePoint] ?? star;
  }

  /// Get all available icons as a list for UI pickers.
  static List<IconData> get allIcons => [
    // Positive icons first
    star,
    thumbUp,
    favorite,
    lightbulb,
    psychology,
    frontHand,
    peopleOutline,
    schedule,
    checkCircle,
    emojiEmotions,
    school,
    assignmentTurnedIn,
    volunteerActivism,
    workspacePremium,
    trendingUp,

    // Negative icons
    warning,
    cancel,
    accessTime,
    assignmentLate,
    moodBad,
    phonelinkOff,
    backpack,
    recordVoiceOver,
    priorityHigh,
    errorOutline,
    thumbDown,
    removeCircleOutline,
    block,
    notificationsOff,
    trendingDown,
  ];

  /// Default icon for behaviors when none is specified
  static const IconData defaultIcon = star;
}