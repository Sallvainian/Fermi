import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/services/logger_service.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Simplified updatePresence method for compatibility
  Future<void> updatePresence(String userId, bool isOnline, {String? userRole}) async {
    await updateUserPresence(isOnline, userRole: userRole);
  }

  // Privacy settings - can be extended to user preferences
  static const bool _showFullName = true;
  static const bool _showPhoto = true;
  static const bool _showRole = true;

  // Failure threshold for disabling presence updates
  static const int _maxFailureAttempts = 3;

  // Configurable thresholds
  static const int _updateDebounceSeconds = 5;  // Reduced for better UX
  static const int _stalePresenceMinutes = 5;

  // Track update attempts for error handling
  static int _updateAttempts = 0;
  static DateTime? _lastUpdateTime;
  static bool _presenceDisabled = false;
  static DateTime? _lastActivityTime;
  static Timer? _heartbeatTimer;

  // Track last presence state to prevent redundant updates
  static bool? _lastOnlineState;
  static String? _lastUserRole;

  // Standard practice: use real-time listeners across platforms.
  // Keep a Windows polling fallback behind a feature flag for environments
  // where long-lived connections are unreliable (rare). Disabled by default.
  static bool enableWindowsPollingFallback = false;

  // Track user's online status with privacy controls
  Future<void> updateUserPresence(bool isOnline, {String? userRole}) async {
    // If presence updates are disabled due to errors, skip
    if (_presenceDisabled) {
      LoggerService.warning(
        'Presence updates disabled due to errors',
        tag: 'PresenceService',
      );
      return;
    }

    // Skip redundant updates - only update if state actually changed
    if (_lastOnlineState == isOnline && _lastUserRole == userRole) {
      LoggerService.debug(
        'Skipping redundant presence update - no state change',
        tag: 'PresenceService',
      );
      return;
    }

    // Debounce rapid updates (reduced to 5 seconds for better UX)
    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
      if (timeSinceLastUpdate.inSeconds < _updateDebounceSeconds) {
        LoggerService.debug(
          'Skipping update, too soon (${timeSinceLastUpdate.inSeconds}s < ${_updateDebounceSeconds}s)',
          tag: 'PresenceService',
        );
        return;
      }
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        LoggerService.warning(
          'No current user, cannot update presence',
          tag: 'PresenceService',
        );
        return;
      }

      LoggerService.info(
        'Updating presence for ${user.email} - online: $isOnline, role: $userRole',
        tag: 'PresenceService',
      );

      final userStatusDoc = _firestore.collection('presence').doc(user.uid);

      if (isOnline) {
        // User is online - store only necessary public information
        final presenceData = _buildPresenceData(user, true, userRole);
        LoggerService.debug(
          'Setting online presence data: $presenceData',
          tag: 'PresenceService',
        );
        await userStatusDoc.set(presenceData, SetOptions(merge: true));
        LoggerService.info(
          'Successfully set online presence for ${user.email}',
          tag: 'PresenceService',
        );
      } else {
        // User is offline
        LoggerService.info('Setting user offline', tag: 'PresenceService');
        await userStatusDoc.update({
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
        LoggerService.info(
          'Successfully set offline presence for ${user.email}',
          tag: 'PresenceService',
        );
      }

      // Reset error counters on success and track state
      _updateAttempts = 0;
      _lastUpdateTime = DateTime.now();
      _lastOnlineState = isOnline;
      _lastUserRole = userRole;
    } catch (error) {
      _updateAttempts++;
      LoggerService.error(
        'Error updating user presence (attempt $_updateAttempts)',
        tag: 'PresenceService',
        error: error,
      );

      // Disable presence updates after consecutive failures
      if (_updateAttempts >= _maxFailureAttempts) {
        _presenceDisabled = true;
        LoggerService.warning(
          'Disabling presence updates after $_maxFailureAttempts failures',
          tag: 'PresenceService',
        );

        // Re-enable after 2 minutes (reduced from 5)
        Future.delayed(const Duration(minutes: 2), () {
          _presenceDisabled = false;
          _updateAttempts = 0;
          LoggerService.info('Re-enabling presence updates', tag: 'PresenceService');
        });
      }
    }
  }

  // Build presence data with privacy controls
  Map<String, dynamic> _buildPresenceData(
    User user,
    bool isOnline,
    String? userRole,
  ) {
    return {
      'online': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      'uid': user.uid,
      'displayName': _showFullName
          ? (user.displayName ?? 'Anonymous User')
          : _getInitials(user.displayName ?? 'AU'),
      // Never expose email in presence data
      'photoURL': _showPhoto ? user.photoURL : null,
      'role': _showRole ? userRole : null,
      // Add privacy-safe metadata
      'isAnonymous': user.isAnonymous,
      'metadata': {
        'platform': kIsWeb ? 'web' : 'mobile',
        'version': '1.0.0', // App version for compatibility
      },
    };
  }

  // Get initials from display name
  String _getInitials(String displayName) {
    if (displayName.isEmpty) return 'AU';
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }

  // Get stream of online users with filtering
  Stream<List<OnlineUser>> getOnlineUsers({bool excludeSelf = false}) {
    // Check if user is authenticated before accessing database
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      LoggerService.warning(
        'No current user, returning empty stream',
        tag: 'PresenceService',
      );
      // Return an empty list if no user is logged in
      return Stream.value([]);
    }

    LoggerService.debug(
      'Setting up stream for online users, excludeSelf: $excludeSelf',
      tag: 'PresenceService',
    );

    // Use real-time listeners everywhere by default.
    // Optionally enable polling on Windows if needed for specific environments.
    if (!kIsWeb && Platform.isWindows && enableWindowsPollingFallback) {
      LoggerService.warning('Using polling fallback for Windows (flag enabled)', tag: 'PresenceService');
      return _getOnlineUsersPolling(excludeSelf: excludeSelf);
    }

    LoggerService.debug('Using real-time listeners', tag: 'PresenceService');
    return _getOnlineUsersRealtime(excludeSelf: excludeSelf);
  }

  // Real-time implementation for web/mobile
  Stream<List<OnlineUser>> _getOnlineUsersRealtime({bool excludeSelf = false}) {
    final currentUser = _auth.currentUser!;

    return _firestore
        .collection('presence')
        .where('online', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          LoggerService.debug(
            'Real-time update - ${snapshot.docs.length} online users',
            tag: 'PresenceService',
          );
          final allUsers = _processOnlineUsersData(
            snapshot.docs,
            currentUser,
            excludeSelf,
          );
          // Filter to only show users who are actually active (last seen within threshold)
          final activeUsers = allUsers.where((user) => user.isActive).toList();
          LoggerService.debug(
            'Filtered to ${activeUsers.length} active users (${_stalePresenceMinutes}m)',
            tag: 'PresenceService',
          );
          return activeUsers;
        })
        .handleError((error) {
          // Log the error but return empty list to keep UI functional
          LoggerService.error('Real-time stream error', tag: 'PresenceService', error: error);
          LoggerService.error('Error fetching online users', error: error);
          return <OnlineUser>[];
        });
  }

  // Polling implementation for Windows
  Stream<List<OnlineUser>> _getOnlineUsersPolling({
    bool excludeSelf = false,
  }) async* {
    final currentUser = _auth.currentUser!;

    while (true) {
      try {
        LoggerService.debug('Polling for online users...', tag: 'PresenceService');

        final snapshot = await _firestore
            .collection('presence')
            .where('online', isEqualTo: true)
            .get();

        LoggerService.debug(
          'Polling update - ${snapshot.docs.length} online users',
          tag: 'PresenceService',
        );
        final allUsers = _processOnlineUsersData(
          snapshot.docs,
          currentUser,
          excludeSelf,
        );
        // Filter to only show users who are actually active (last seen within threshold)
        final activeUsers = allUsers.where((user) => user.isActive).toList();
        LoggerService.debug(
          'Filtered to ${activeUsers.length} active users (${_stalePresenceMinutes}m)',
          tag: 'PresenceService',
        );
        yield activeUsers;

        // Poll every 10 seconds for Windows to reduce Firestore reads
        await Future.delayed(const Duration(seconds: 10));
      } catch (error) {
        LoggerService.error('Polling error', tag: 'PresenceService', error: error);
        LoggerService.error('Error polling online users', error: error);
        yield <OnlineUser>[];
        // Continue polling even on error, but with longer delay
        await Future.delayed(const Duration(seconds: 30));
      }
    }
  }

  // Common data processing logic
  List<OnlineUser> _processOnlineUsersData(
    List<QueryDocumentSnapshot> docs,
    User currentUser,
    bool excludeSelf,
  ) {
    final List<OnlineUser> onlineUsers = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final uid = data['uid'] ?? '';

      LoggerService.debug(
        'Processing user ${data['displayName']} (${data['role']}) - UID: $uid',
        tag: 'PresenceService',
      );

      // Filter out self if requested
      if (!excludeSelf || uid != currentUser.uid) {
        // Handle Firestore Timestamp conversion
        DateTime lastSeen;
        if (data['lastSeen'] is Timestamp) {
          lastSeen = (data['lastSeen'] as Timestamp).toDate();
        } else {
          lastSeen = DateTime.now();
        }

        onlineUsers.add(
          OnlineUser(
            uid: uid,
            displayName: data['displayName'] ?? 'Anonymous User',
            photoURL: data['photoURL'],
            role: data['role'],
            lastSeen: lastSeen,
            isAnonymous: data['isAnonymous'] ?? false,
            metadata: data['metadata'] != null
                ? PresenceMetadata.fromMap(data['metadata'])
                : null,
          ),
        );

        LoggerService.debug(
          'Added ${data['displayName']} to online users list',
          tag: 'PresenceService',
        );
      } else {
        LoggerService.debug(
          'Excluded self (${data['displayName']}) from list',
          tag: 'PresenceService',
        );
      }
    }

    // Sort by last seen (most recent first)
    onlineUsers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    LoggerService.debug(
      'Returning ${onlineUsers.length} users after filtering and sorting',
      tag: 'PresenceService',
    );
    return onlineUsers;
  }

  // Get specific user's online status
  Stream<bool> getUserOnlineStatus(String uid) {
    // Check if user is authenticated before accessing database
    if (_auth.currentUser == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('presence')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return snapshot.data()?['online'] as bool? ?? false;
          }
          return false;
        })
        .handleError((error) {
          LoggerService.error(
            'Error fetching user online status',
            error: error,
          );
          return false;
        });
  }

  // Get user's last seen time
  Stream<DateTime?> getUserLastSeen(String uid) {
    if (_auth.currentUser == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('presence')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final lastSeen = snapshot.data()?['lastSeen'];
            if (lastSeen is Timestamp) {
              return lastSeen.toDate();
            }
          }
          return null;
        })
        .handleError((error) {
          LoggerService.error('Error fetching user last seen', error: error);
          return null;
        });
  }

  // Initialize presence tracking
  void initializePresence({String? userRole}) {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        updateUserPresence(true, userRole: userRole);
        _startActivityBasedHeartbeat(userRole);
      } else {
        _stopHeartbeat();
      }
    });
  }

  // Update presence on user activity (call this from UI interactions)
  void markUserActive({String? userRole}) {
    // This should be called from key user interactions like:
    // - Navigation changes
    // - Message sends
    // - Button clicks
    // - Form submissions
    _lastActivityTime = DateTime.now();

    // Only update Firestore if enough time has passed
    if (_auth.currentUser != null && !_presenceDisabled) {
      updateUserPresence(true, userRole: userRole);
    }
  }

  // Start activity-based heartbeat
  void _startActivityBasedHeartbeat(String? userRole) {
    _stopHeartbeat(); // Cancel any existing timer

    // Check every minute if user has been active
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_auth.currentUser == null) {
        _stopHeartbeat();
        return;
      }

      // Only update if user has been active in the last 3 minutes
      if (_lastActivityTime != null) {
        final timeSinceActivity = DateTime.now().difference(_lastActivityTime!);
        if (timeSinceActivity.inMinutes < 3) {
          // User is active, update presence
          updateUserPresence(true, userRole: userRole);
        }
      }
    });
  }

  // Stop the heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Clean up stale presence records (users who appear online but haven't updated in >5 minutes)
  Future<void> cleanupStalePresence() async {
    try {
      LoggerService.info('Cleaning up stale presence data...', tag: 'PresenceService');
      final snapshot = await _firestore
          .collection('presence')
          .where('online', isEqualTo: true)
          .get();

      final now = DateTime.now();
      final batch = _firestore.batch();
      int staleCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['lastSeen'] is Timestamp) {
          final lastSeen = (data['lastSeen'] as Timestamp).toDate();
          // If last seen is older than threshold, mark as offline
          if (now.difference(lastSeen).inMinutes >= _stalePresenceMinutes) {
            batch.update(doc.reference, {
              'online': false,
              'lastSeen': FieldValue.serverTimestamp(),
            });
            staleCount++;
            LoggerService.warning(
              'Marking ${data['displayName']} as offline (stale)',
              tag: 'PresenceService',
            );
          }
        }
      }

      if (staleCount > 0) {
        await batch.commit();
        LoggerService.info(
          'Cleaned up $staleCount stale presence records',
          tag: 'PresenceService',
        );
      }
    } catch (error) {
      LoggerService.error('Error cleaning stale presence', tag: 'PresenceService', error: error);
      LoggerService.error('Error cleaning stale presence', error: error);
    }
  }

  // Clean up presence on sign out
  Future<void> cleanupPresence() async {
    _stopHeartbeat();
    _lastActivityTime = null;
    await updateUserPresence(false);
  }

  // Force clear all presence data (for debugging/cleanup)
  Future<void> clearAllPresenceData() async {
    try {
      LoggerService.info('Clearing all presence data...', tag: 'PresenceService');
      final snapshot = await _firestore.collection('presence').get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
        LoggerService.debug('Deleted presence for ${doc.id}', tag: 'PresenceService');
      }

      LoggerService.info(
        'Cleared ${snapshot.docs.length} presence documents',
        tag: 'PresenceService',
      );
    } catch (error) {
      LoggerService.error('Error clearing presence data', tag: 'PresenceService', error: error);
      LoggerService.error('Error clearing presence data', error: error);
    }
  }

  // Batch update presence for multiple users (admin function)
  Future<void> batchUpdatePresence(Map<String, bool> userStatuses) async {
    try {
      final batch = _firestore.batch();
      userStatuses.forEach((uid, isOnline) {
        final docRef = _firestore.collection('presence').doc(uid);
        batch.update(docRef, {
          'online': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
    } catch (error) {
      LoggerService.error('Error in batch presence update', error: error);
    }
  }

  // Get count of online users by role
  Stream<Map<String, int>> getOnlineUserCountByRole() {
    if (_auth.currentUser == null) {
      return Stream.value({});
    }

    return _firestore
        .collection('presence')
        .where('online', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final Map<String, int> roleCounts = {};

          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['online'] == true) {
              final role = data['role'] ?? 'unknown';
              roleCounts[role] = (roleCounts[role] ?? 0) + 1;
            }
          }

          return roleCounts;
        })
        .handleError((error) {
          LoggerService.error(
            'Error fetching online user counts',
            error: error,
          );
          return <String, int>{};
        });
  }
}

// Enhanced model for online users with privacy in mind
class OnlineUser {
  final String uid;
  final String displayName;
  final String? photoURL;
  final String? role;
  final DateTime lastSeen;
  final bool isAnonymous;
  final PresenceMetadata? metadata;

  OnlineUser({
    required this.uid,
    required this.displayName,
    this.photoURL,
    this.role,
    required this.lastSeen,
    this.isAnonymous = false,
    this.metadata,
  });

  // Helper method to get relative time
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  // Helper to check if user is active (online in last 5 minutes)
  bool get isActive {
    return DateTime.now().difference(lastSeen).inMinutes <
        PresenceService._stalePresenceMinutes;
  }
}

// Metadata for presence information
class PresenceMetadata {
  final String platform;
  final String version;

  PresenceMetadata({required this.platform, required this.version});

  factory PresenceMetadata.fromMap(Map<dynamic, dynamic> map) {
    return PresenceMetadata(
      platform: map['platform'] ?? 'unknown',
      version: map['version'] ?? '0.0.0',
    );
  }

  Map<String, dynamic> toMap() {
    return {'platform': platform, 'version': version};
  }
}
