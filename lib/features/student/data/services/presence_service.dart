import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/services/logger_service.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Privacy settings - can be extended to user preferences
  static const bool _showFullName = true;
  static const bool _showPhoto = true;
  static const bool _showRole = true;

  // Failure threshold for disabling presence updates
  static const int _maxFailureAttempts = 3;

  // Track update attempts for error handling
  static int _updateAttempts = 0;
  static DateTime? _lastUpdateTime;
  static bool _presenceDisabled = false;
  static DateTime? _lastActivityTime;
  static Timer? _heartbeatTimer;

  // Track user's online status with privacy controls
  Future<void> updateUserPresence(bool isOnline, {String? userRole}) async {
    // If presence updates are disabled due to errors, skip
    if (_presenceDisabled) {
      debugPrint('PresenceService: Presence updates disabled due to errors');
      return;
    }

    // Debounce rapid updates (minimum 30 seconds between updates to prevent blocking)
    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
      if (timeSinceLastUpdate.inSeconds < 30) {
        debugPrint('PresenceService: Skipping update, too soon since last update (${timeSinceLastUpdate.inSeconds}s)');
        return;
      }
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('PresenceService: No current user, cannot update presence');
        return;
      }

      debugPrint('PresenceService: Updating presence for ${user.email} - online: $isOnline, role: $userRole');

      final userStatusDoc = _firestore.collection('presence').doc(user.uid);

      if (isOnline) {
        // User is online - store only necessary public information
        final presenceData = _buildPresenceData(user, true, userRole);
        debugPrint('PresenceService: Setting online presence data: $presenceData');
        await userStatusDoc.set(presenceData, SetOptions(merge: true));
        debugPrint('PresenceService: Successfully set online presence for ${user.email}');
      } else {
        // User is offline
        debugPrint('PresenceService: Setting user offline');
        await userStatusDoc.update({
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
        debugPrint('PresenceService: Successfully set offline presence for ${user.email}');
      }

      // Reset error counters on success
      _updateAttempts = 0;
      _lastUpdateTime = DateTime.now();
    } catch (error) {
      _updateAttempts++;
      debugPrint('PresenceService: ERROR updating presence (attempt $_updateAttempts): $error');
      LoggerService.error('Error updating user presence', error: error);

      // Disable presence updates after consecutive failures
      if (_updateAttempts >= _maxFailureAttempts) {
        _presenceDisabled = true;
        debugPrint('PresenceService: Disabling presence updates after $_maxFailureAttempts failures');
        
        // Re-enable after 2 minutes (reduced from 5)
        Future.delayed(const Duration(minutes: 2), () {
          _presenceDisabled = false;
          _updateAttempts = 0;
          debugPrint('PresenceService: Re-enabling presence updates');
        });
      }
    }
  }

  // Build presence data with privacy controls
  Map<String, dynamic> _buildPresenceData(
      User user, bool isOnline, String? userRole) {
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
      debugPrint('PresenceService: No current user, returning empty stream');
      // Return an empty list if no user is logged in
      return Stream.value([]);
    }

    debugPrint('PresenceService: Setting up stream for online users, excludeSelf: $excludeSelf');

    // Platform-specific implementation due to Windows Firebase limitations
    if (!kIsWeb && Platform.isWindows) {
      debugPrint('PresenceService: Using polling fallback for Windows');
      return _getOnlineUsersPolling(excludeSelf: excludeSelf);
    } else {
      debugPrint('PresenceService: Using real-time listeners for web/mobile');
      return _getOnlineUsersRealtime(excludeSelf: excludeSelf);
    }
  }

  // Real-time implementation for web/mobile
  Stream<List<OnlineUser>> _getOnlineUsersRealtime({bool excludeSelf = false}) {
    final currentUser = _auth.currentUser!;
    
    return _firestore
        .collection('presence')
        .where('online', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('PresenceService: Real-time update - received ${snapshot.docs.length} online users');
      final allUsers = _processOnlineUsersData(snapshot.docs, currentUser, excludeSelf);
      // Filter to only show users who are actually active (last seen within 5 minutes)
      final activeUsers = allUsers.where((user) => user.isActive).toList();
      debugPrint('PresenceService: Filtered to ${activeUsers.length} active users (last 5 min)');
      return activeUsers;
    }).handleError((error) {
      // Log the error but return empty list to keep UI functional
      debugPrint('PresenceService: Real-time stream error: $error');
      LoggerService.error('Error fetching online users', error: error);
      return <OnlineUser>[];
    });
  }

  // Polling implementation for Windows
  Stream<List<OnlineUser>> _getOnlineUsersPolling({bool excludeSelf = false}) async* {
    final currentUser = _auth.currentUser!;
    
    while (true) {
      try {
        debugPrint('PresenceService: Polling for online users...');
        
        final snapshot = await _firestore
            .collection('presence')
            .where('online', isEqualTo: true)
            .get();
        
        debugPrint('PresenceService: Polling update - received ${snapshot.docs.length} online users');
        final allUsers = _processOnlineUsersData(snapshot.docs, currentUser, excludeSelf);
        // Filter to only show users who are actually active (last seen within 5 minutes)
        final activeUsers = allUsers.where((user) => user.isActive).toList();
        debugPrint('PresenceService: Filtered to ${activeUsers.length} active users (last 5 min)');
        yield activeUsers;
        
        // Poll every 10 seconds for Windows to reduce Firestore reads
        await Future.delayed(const Duration(seconds: 10));
      } catch (error) {
        debugPrint('PresenceService: Polling error: $error');
        LoggerService.error('Error polling online users', error: error);
        yield <OnlineUser>[];
        // Continue polling even on error, but with longer delay
        await Future.delayed(const Duration(seconds: 30));
      }
    }
  }

  // Common data processing logic
  List<OnlineUser> _processOnlineUsersData(List<QueryDocumentSnapshot> docs, User currentUser, bool excludeSelf) {
    final List<OnlineUser> onlineUsers = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final uid = data['uid'] ?? '';
      
      debugPrint('PresenceService: Processing user ${data['displayName']} (${data['role']}) - UID: $uid');
      
      // Filter out self if requested
      if (!excludeSelf || uid != currentUser.uid) {
        // Handle Firestore Timestamp conversion
        DateTime lastSeen;
        if (data['lastSeen'] is Timestamp) {
          lastSeen = (data['lastSeen'] as Timestamp).toDate();
        } else {
          lastSeen = DateTime.now();
        }
        
        onlineUsers.add(OnlineUser(
          uid: uid,
          displayName: data['displayName'] ?? 'Anonymous User',
          photoURL: data['photoURL'],
          role: data['role'],
          lastSeen: lastSeen,
          isAnonymous: data['isAnonymous'] ?? false,
          metadata: data['metadata'] != null
              ? PresenceMetadata.fromMap(data['metadata'])
              : null,
        ));
        
        debugPrint('PresenceService: Added ${data['displayName']} to online users list');
      } else {
        debugPrint('PresenceService: Excluded self (${data['displayName']}) from list');
      }
    }

    // Sort by last seen (most recent first)
    onlineUsers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    debugPrint('PresenceService: Returning ${onlineUsers.length} users after filtering and sorting');
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
    }).handleError((error) {
      LoggerService.error('Error fetching user online status', error: error);
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
    }).handleError((error) {
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
      debugPrint('PresenceService: Cleaning up stale presence data...');
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
          // If last seen is more than 5 minutes ago, mark as offline
          if (now.difference(lastSeen).inMinutes >= 5) {
            batch.update(doc.reference, {
              'online': false,
              'lastSeen': FieldValue.serverTimestamp(),
            });
            staleCount++;
            debugPrint('PresenceService: Marking ${data['displayName']} as offline (stale)');
          }
        }
      }
      
      if (staleCount > 0) {
        await batch.commit();
        debugPrint('PresenceService: Cleaned up $staleCount stale presence records');
      }
    } catch (error) {
      debugPrint('PresenceService: Error cleaning stale presence: $error');
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
      debugPrint('PresenceService: Clearing all presence data...');
      final snapshot = await _firestore.collection('presence').get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
        debugPrint('PresenceService: Deleted presence for ${doc.id}');
      }
      
      debugPrint('PresenceService: Cleared ${snapshot.docs.length} presence documents');
    } catch (error) {
      debugPrint('PresenceService: Error clearing presence data: $error');
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
    }).handleError((error) {
      LoggerService.error('Error fetching online user counts', error: error);
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
    return DateTime.now().difference(lastSeen).inMinutes < 5;
  }
}

// Metadata for presence information
class PresenceMetadata {
  final String platform;
  final String version;

  PresenceMetadata({
    required this.platform,
    required this.version,
  });

  factory PresenceMetadata.fromMap(Map<dynamic, dynamic> map) {
    return PresenceMetadata(
      platform: map['platform'] ?? 'unknown',
      version: map['version'] ?? '0.0.0',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'version': version,
    };
  }
}
