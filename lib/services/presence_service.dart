import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseDatabase? _database;
  
  FirebaseDatabase get database {
    _database ??= FirebaseDatabase.instance;
    return _database!;
  }
  
  // Track user's online status
  Future<void> updateUserPresence(bool isOnline, {Map<String, dynamic>? userData}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final userStatusRef = database.ref('presence/${user.uid}');
      
      if (isOnline) {
        // User is online - merge Firebase Auth data with provided userData
        final presenceData = {
          'online': true,
          'lastSeen': ServerValue.timestamp,
          'uid': user.uid,
          'displayName': userData?['displayName'] ?? user.displayName ?? 'Unknown User',
          'email': user.email,
          'photoURL': userData?['photoURL'] ?? user.photoURL,
          'role': userData?['role'] ?? 'student', // Default to student if not provided
          'firstName': userData?['firstName'] ?? '',
          'lastName': userData?['lastName'] ?? '',
        };
        await userStatusRef.set(presenceData);
        
        // Set up disconnect handler with same user data
        await userStatusRef.onDisconnect().set({
          ...presenceData,
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
      } else {
        // User is offline
        await userStatusRef.update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
      }
    } catch (error) {
      print('Error updating user presence: $error');
    }
  }
  
  // Get stream of online users
  Stream<List<OnlineUser>> getOnlineUsers() {
    // Check if user is authenticated before accessing database
    if (_auth.currentUser == null) {
      // Return an empty list if no user is logged in
      return Stream.value([]);
    }
    
    return database.ref('presence').onValue.map((event) {
      final List<OnlineUser> onlineUsers = [];
      
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        data.forEach((key, value) {
          if (value['online'] == true) {
            onlineUsers.add(OnlineUser(
              uid: value['uid'] ?? '',
              displayName: value['displayName'] ?? 'Unknown User',
              email: value['email'] ?? '',
              photoURL: value['photoURL'],
              lastSeen: value['lastSeen'] != null 
                ? DateTime.fromMillisecondsSinceEpoch(value['lastSeen'])
                : DateTime.now(),
              role: value['role'] ?? 'student',
              firstName: value['firstName'] ?? '',
              lastName: value['lastName'] ?? '',
            ));
          }
        });
      }
      
      return onlineUsers;
    }).handleError((error) {
      // Log the error but return empty list to keep UI functional
      print('Error fetching online users: $error');
      return <OnlineUser>[];
    });
  }
  
  // Get specific user's online status
  Stream<bool> getUserOnlineStatus(String uid) {
    // Check if user is authenticated before accessing database
    if (_auth.currentUser == null) {
      return Stream.value(false);
    }
    
    return database.ref('presence/$uid/online').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    }).handleError((error) {
      print('Error fetching user online status: $error');
      return false;
    });
  }
  
  // Initialize presence tracking
  void initializePresence({Map<String, dynamic>? userData}) {
    // Just update presence immediately - auth state is already being tracked by AuthProvider
    updateUserPresence(true, userData: userData);
  }
  
  // Clean up presence on sign out
  Future<void> cleanupPresence() async {
    await updateUserPresence(false);
  }
}

// Simple model for online users
class OnlineUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;
  final DateTime lastSeen;
  final String role;
  final String firstName;
  final String lastName;
  
  OnlineUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.lastSeen,
    required this.role,
    required this.firstName,
    required this.lastName,
  });
}