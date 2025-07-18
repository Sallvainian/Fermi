import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../shared/services/logger_service.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseDatabase? _database;
  
  FirebaseDatabase get database {
    _database ??= FirebaseDatabase.instance;
    return _database!;
  }
  
  // Privacy settings - can be extended to user preferences
  static const bool _showFullName = true;
  static const bool _showPhoto = true;
  static const bool _showRole = true;
  
  // Track user's online status with privacy controls
  Future<void> updateUserPresence(bool isOnline, {String? userRole}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final userStatusRef = database.ref('presence/${user.uid}');
      
      if (isOnline) {
        // User is online - store only necessary public information
        final presenceData = _buildPresenceData(user, true, userRole);
        await userStatusRef.set(presenceData);
        
        // Set up disconnect handler
        final offlineData = _buildPresenceData(user, false, userRole);
        await userStatusRef.onDisconnect().set(offlineData);
      } else {
        // User is offline
        await userStatusRef.update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
      }
    } catch (error) {
      LoggerService.error('Error updating user presence', error: error);
    }
  }
  
  // Build presence data with privacy controls
  Map<String, dynamic> _buildPresenceData(User user, bool isOnline, String? userRole) {
    return {
      'online': isOnline,
      'lastSeen': ServerValue.timestamp,
      'uid': user.uid,
      'displayName': _showFullName 
          ? (user.displayName ?? 'Anonymous User')
          : _getInitials(user.displayName ?? 'AU'),
      // Never expose email in presence data
      // 'email': _showEmail ? user.email : null, // Removed for security
      'photoURL': _showPhoto ? user.photoURL : null,
      'role': _showRole ? userRole : null,
      // Add privacy-safe metadata
      'isAnonymous': user.isAnonymous,
      'metadata': {
        'platform': 'web', // Can be extended to detect platform
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
      // Return an empty list if no user is logged in
      return Stream.value([]);
    }
    
    return database.ref('presence').onValue.map((DatabaseEvent event) {
      final List<OnlineUser> onlineUsers = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        // Safely handle the data conversion
        final rawData = event.snapshot.value;
        if (rawData is! Map) {
          LoggerService.error('Unexpected presence data format: ${rawData.runtimeType}');
          return onlineUsers;
        }
        final data = Map<dynamic, dynamic>.from(rawData);
        
        data.forEach((key, value) {
          // Filter out offline users and optionally self
          if (value['online'] == true) {
            final uid = value['uid'] ?? '';
            if (!excludeSelf || uid != currentUser.uid) {
              onlineUsers.add(OnlineUser(
                uid: uid,
                displayName: value['displayName'] ?? 'Anonymous User',
                // Email is no longer exposed in presence data
                photoURL: value['photoURL'],
                role: value['role'],
                lastSeen: value['lastSeen'] != null 
                    ? DateTime.fromMillisecondsSinceEpoch(value['lastSeen'])
                    : DateTime.now(),
                isAnonymous: value['isAnonymous'] ?? false,
                metadata: value['metadata'] != null
                    ? PresenceMetadata.fromMap(value['metadata'])
                    : null,
              ));
            }
          }
        });
      }
      
      // Sort by last seen (most recent first)
      onlineUsers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      
      return onlineUsers;
    }).handleError((error) {
      // Log the error but return empty list to keep UI functional
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
    
    return database.ref('presence/$uid/online').onValue.map((DatabaseEvent event) {
      return event.snapshot.value as bool? ?? false;
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
    
    return database.ref('presence/$uid/lastSeen').onValue.map((DatabaseEvent event) {
      final timestamp = event.snapshot.value as int?;
      return timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
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
  
  // Batch update presence for multiple users (admin function)
  Future<void> batchUpdatePresence(Map<String, bool> userStatuses) async {
    try {
      final updates = <String, dynamic>{};
      userStatuses.forEach((uid, isOnline) {
        updates['presence/$uid/online'] = isOnline;
        updates['presence/$uid/lastSeen'] = ServerValue.timestamp;
      });
      await database.ref().update(updates);
    } catch (error) {
      LoggerService.error('Error in batch presence update', error: error);
    }
  }
  
  // Get count of online users by role
  Stream<Map<String, int>> getOnlineUserCountByRole() {
    if (_auth.currentUser == null) {
      return Stream.value({});
    }
    
    return database.ref('presence').onValue.map((DatabaseEvent event) {
      final Map<String, int> roleCounts = {};
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        // Safely handle the data conversion
        final rawData = event.snapshot.value;
        if (rawData is! Map) {
          LoggerService.error('Unexpected presence data format: ${rawData.runtimeType}');
          return roleCounts;
        }
        final data = Map<dynamic, dynamic>.from(rawData);
        
        data.forEach((key, value) {
          if (value['online'] == true) {
            final role = value['role'] ?? 'unknown';
            roleCounts[role] = (roleCounts[role] ?? 0) + 1;
          }
        });
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