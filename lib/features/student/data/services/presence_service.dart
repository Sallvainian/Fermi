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

  // Track user's online status with privacy controls
  Future<void> updateUserPresence(bool isOnline, {String? userRole}) async {
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
        await userStatusDoc.set(presenceData);
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
    } catch (error) {
      debugPrint('PresenceService: ERROR updating presence: $error');
      LoggerService.error('Error updating user presence', error: error);
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

    return _firestore
        .collection('presence')
        .where('online', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('PresenceService: Stream update - received ${snapshot.docs.length} online users');
      
      final List<OnlineUser> onlineUsers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
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
    }).handleError((error) {
      // Log the error but return empty list to keep UI functional
      debugPrint('PresenceService: Stream error: $error');
      LoggerService.error('Error fetching online users', error: error);
      return <OnlineUser>[];
    });
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
      }
    });
  }

  // Clean up presence on sign out
  Future<void> cleanupPresence() async {
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
