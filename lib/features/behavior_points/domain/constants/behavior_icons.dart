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
  static final Map<int, IconData> iconMap = {
    // Positive behavior icons
    star.codePoint: star,
    thumbUp.codePoint: thumbUp,
    favorite.codePoint: favorite,
    lightbulb.codePoint: lightbulb,
    psychology.codePoint: psychology,
    frontHand.codePoint: frontHand,
    peopleOutline.codePoint: peopleOutline,
    schedule.codePoint: schedule,
    checkCircle.codePoint: checkCircle,
    emojiEmotions.codePoint: emojiEmotions,
    school.codePoint: school,
    assignmentTurnedIn.codePoint: assignmentTurnedIn,
    volunteerActivism.codePoint: volunteerActivism,
    workspacePremium.codePoint: workspacePremium,
    trendingUp.codePoint: trendingUp,

    // Negative/Neutral behavior icons
    warning.codePoint: warning,
    cancel.codePoint: cancel,
    accessTime.codePoint: accessTime,
    assignmentLate.codePoint: assignmentLate,
    moodBad.codePoint: moodBad,
    phonelinkOff.codePoint: phonelinkOff,
    backpack.codePoint: backpack,
    recordVoiceOver.codePoint: recordVoiceOver,
    priorityHigh.codePoint: priorityHigh,
    errorOutline.codePoint: errorOutline,
    thumbDown.codePoint: thumbDown,
    removeCircleOutline.codePoint: removeCircleOutline,
    block.codePoint: block,
    notificationsOff.codePoint: notificationsOff,
    trendingDown.codePoint: trendingDown,

    // Additional commonly used icons
    starOutline.codePoint: starOutline,
    add.codePoint: add,
    remove.codePoint: remove,
    build.codePoint: build,
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