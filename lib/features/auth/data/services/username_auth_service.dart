import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed unused foundation import
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/models/user_role.dart';

/// A service for managing username-based authentication.
///
/// This service abstracts the complexity of using usernames with Firebase Auth
/// by converting them to and from synthetic email addresses. It also provides
/// methods for checking username availability and creating user accounts.
class UsernameAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for username lookups with 5-minute TTL and size limit
  static final Map<String, _CachedUsername> _usernameCache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);
  static const int _maxCacheSize = 100; // Maximum number of cached usernames
  static final List<String> _cacheAccessOrder = []; // Track access order for LRU

  /// Domain suffix for synthetic emails (using .local as per RFC 2606 for private use)
  /// Format: {username}@students.fermi-app.local for students
  static const String _studentEmailDomain = '@students.fermi-app.local';
  static const String _teacherEmailDomain = '@teachers.fermi-app.local';

  /// Maximum number of username suffix attempts
  static const int _maxUsernameSuffixAttempts = 100;

  /// Generates a synthetic email from a username and role.
  ///
  /// - [username]: The username.
  /// - [role]: The user's role, which determines the email domain.
  ///
  /// Returns a synthetic email address (e.g., `johndoe@students.fermi-app.local`).
  String generateSyntheticEmail(String username, {UserRole role = UserRole.student}) {
    final domain = role == UserRole.teacher ? _teacherEmailDomain : _studentEmailDomain;
    return '${username.toLowerCase()}$domain';
  }

  /// Extracts a username from a synthetic email address.
  ///
  /// - [email]: The synthetic email.
  ///
  /// Returns the username, or `null` if the email is not a synthetic one.
  String? extractUsernameFromEmail(String email) {
    if (email.endsWith(_studentEmailDomain)) {
      return email.substring(0, email.length - _studentEmailDomain.length);
    } else if (email.endsWith(_teacherEmailDomain)) {
      return email.substring(0, email.length - _teacherEmailDomain.length);
    }
    return null;
  }

  /// Checks if a username is available.
  ///
  /// - [username]: The username to check.
  ///
  /// Returns `true` if the username is available, `false` otherwise.
  Future<bool> isUsernameAvailable(String username) async {
    try {
      // Check in public_usernames collection (safe for unauthenticated access)
      final publicUsernameDoc = await _firestore
          .collection('public_usernames')
          .doc(username.toLowerCase())
          .get();

      return !publicUsernameDoc.exists;
    } catch (e) {
      LoggerService.error('Error checking username availability', tag: 'UsernameAuthService', error: e);
      return false;
    }
  }

  /// Retrieves a user's UID by their username.
  ///
  /// - [username]: The user's username.
  ///
  /// Returns the UID, or `null` if not found.
  Future<String?> getUidByUsername(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      LoggerService.error('Error getting UID by username', tag: 'UsernameAuthService', error: e);
      return null;
    }
  }

  /// Signs in a user with their username and password.
  ///
  /// This method first looks up the user's synthetic email using their username
  /// and then signs them in with Firebase Auth.
  ///
  /// - [username]: The user's username.
  /// - [password]: The user's password.
  ///
  /// Returns the signed-in [User] object.
  Future<User?> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final lowerUsername = username.toLowerCase();
      String? uid;
      
      // Check cache first
      final cached = _usernameCache[lowerUsername];
      if (cached != null && !cached.isExpired) {
        uid = cached.uid;
        _updateCacheAccess(lowerUsername); // Update LRU access order
        LoggerService.info('Using cached username lookup for: $lowerUsername', tag: 'UsernameAuthService');
      } else {
        // Cache miss or expired, lookup in public collection first
        final publicUsernameDoc = await _firestore
            .collection('public_usernames')
            .doc(lowerUsername)
            .get();

        if (publicUsernameDoc.exists) {
          // Found in public collection
          final publicData = publicUsernameDoc.data()!;
          uid = publicData['uid'];
          
          if (uid == null) {
            LoggerService.error('Public username document missing uid field', tag: 'UsernameAuthService');
            throw Exception('Invalid username mapping. Please contact support.');
          }
        } else {
          // FALLBACK: Not in public collection, try users collection (for existing users)
          LoggerService.info('Username not in public collection, checking users collection for: $lowerUsername', tag: 'UsernameAuthService');
          
          try {
            final userQuery = await _firestore
                .collection('users')
                .where('username', isEqualTo: lowerUsername)
                .limit(1)
                .get();
            
            if (userQuery.docs.isEmpty) {
              throw Exception('Invalid username or password');
            }
            
            // Found in users collection - migrate to public_usernames for next time
            final userDoc = userQuery.docs.first;
            final userData = userDoc.data();
            uid = userDoc.id;
            
            // Create entry in public_usernames for future lookups
            try {
              await _firestore.collection('public_usernames')
                  .doc(lowerUsername)
                  .set({
                    'uid': uid,
                    'role': userData['role'] ?? 'student',
                  });
              LoggerService.info('Migrated username to public collection: $lowerUsername', tag: 'UsernameAuthService');
            } catch (e) {
              // Log but don't fail login if migration fails
              LoggerService.warning('Failed to migrate username to public collection: $e', tag: 'UsernameAuthService');
            }
          } catch (e) {
            // If we can't access the users collection (permission denied), username doesn't exist
            LoggerService.info('Username lookup failed (likely does not exist): $lowerUsername', tag: 'UsernameAuthService');
            throw Exception('Invalid username or password');
          }
        }
        
        // Cache the result with LRU eviction
        // At this point uid is guaranteed to be non-null or an exception would have been thrown
        _addToCache(lowerUsername, uid);
        LoggerService.info('Cached username lookup for: $lowerUsername', tag: 'UsernameAuthService');
      }
      
      // Now fetch the actual user document using the uid (requires authentication after this)
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
          
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }
      
      final userData = userDoc.data()!;
      final email = userData['email'];
      
      if (email == null) {
        LoggerService.error('User document missing email field', tag: 'UsernameAuthService');
        throw Exception('Invalid user profile. Please contact support.');
      }

      // Sign in with Firebase Auth using the email from Firestore
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update last active timestamp
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .update({'lastActive': FieldValue.serverTimestamp()})
            .catchError((e) {
              LoggerService.warning('Failed to update lastActive', tag: 'UsernameAuthService');
            });
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Convert Firebase Auth errors to user-friendly messages
      switch (e.code) {
        case 'user-not-found':
          throw Exception('Invalid username or password');
        case 'wrong-password':
          throw Exception('Invalid username or password');
        case 'invalid-email':
          throw Exception('Invalid account format detected. Please contact support if this persists.');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        case 'invalid-credential':
          throw Exception('Invalid username or password');
        default:
          throw Exception(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      if (e.toString().contains('Username not found')) {
        rethrow;
      }
      LoggerService.error('Username sign-in error', tag: 'UsernameAuthService', error: e);
      rethrow;
    }
  }

  /// Creates a new student account.
  ///
  /// - [username]: The student's username.
  /// - [password]: The student's password.
  /// - [firstName]: The student's first name.
  /// - [lastName]: The student's last name.
  /// - [teacherId]: The ID of the teacher creating the account (optional).
  ///
  /// Returns the newly created [User] object.
  Future<User?> createStudentAccount({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    String? teacherId,
  }) async {
    try {
      // Validate username format
      if (!isValidUsername(username)) {
        throw Exception('Username must be 3-20 characters, start with a letter, and contain only letters, numbers, and underscores');
      }

      // Validate username availability
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username "$username" is already taken');
      }

      // Generate synthetic email with student domain
      final email = generateSyntheticEmail(username, role: UserRole.student);
      final displayName = '$firstName $lastName';

      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(displayName);

        // Create user document in Firestore with consistent structure
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'username': username.toLowerCase(),
          'email': email,  // Store the synthetic email
          'displayName': displayName,
          'firstName': firstName,
          'lastName': lastName,
          'role': 'student',
          'teacherId': teacherId,
          'photoURL': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
        
        // Also create entry in public_usernames collection for login lookups
        await _firestore.collection('public_usernames').doc(username.toLowerCase()).set({
          'uid': credential.user!.uid,
          'role': 'student',
        });

        LoggerService.info('Created student account: $username', tag: 'UsernameAuthService');
        return credential.user;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Username already exists');
        case 'weak-password':
          throw Exception('Password is too weak (minimum 6 characters)');
        case 'invalid-email':
          throw Exception('Invalid username format');
        default:
          throw Exception(e.message ?? 'Failed to create account');
      }
    } catch (e) {
      LoggerService.error('Create student account error', tag: 'UsernameAuthService', error: e);
      rethrow;
    }
  }

  /// Creates a new teacher account.
  ///
  /// - [username]: The teacher's username.
  /// - [password]: The teacher's password.
  /// - [firstName]: The teacher's first name.
  /// - [lastName]: The teacher's last name.
  ///
  /// Returns the newly created [User] object.
  Future<User?> createTeacherAccount({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      // Validate username format
      if (!isValidUsername(username)) {
        throw Exception('Username must be 3-20 characters, start with a letter, and contain only letters, numbers, and underscores');
      }

      // Validate username availability
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username "$username" is already taken');
      }

      // Generate synthetic email with teacher domain
      final email = generateSyntheticEmail(username, role: UserRole.teacher);
      final displayName = '$firstName $lastName';

      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(displayName);

        // Create user document in Firestore with consistent structure
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'username': username.toLowerCase(),
          'email': email,  // Store the synthetic email
          'displayName': displayName,
          'firstName': firstName,
          'lastName': lastName,
          'role': 'teacher',
          'photoURL': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
        
        // Also create entry in public_usernames collection for login lookups
        await _firestore.collection('public_usernames').doc(username.toLowerCase()).set({
          'uid': credential.user!.uid,
          'role': 'teacher',
        });

        LoggerService.info('Created teacher account: $username', tag: 'UsernameAuthService');
        return credential.user;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Firebase Auth error during account creation', tag: 'UsernameAuthService', error: e);
      
      if (e.code == 'email-already-in-use') {
        throw Exception('Username "$username" is already taken');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Please use at least 6 characters');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid username format');
      } else {
        throw Exception('Failed to create account: ${e.message}');
      }
    } catch (e) {
      LoggerService.error('Unexpected error during account creation', tag: 'UsernameAuthService', error: e);
      throw Exception('Failed to create account. Please try again.');
    }
  }

  /// Deletes a user from both the `users` and `public_usernames` collections.
  ///
  /// - [uid]: The UID of the user to delete.
  /// - [username]: The username of the user to delete.
  Future<void> deleteUser({
    required String uid,
    required String username,
  }) async {
    try {
      // Use batch write to ensure atomicity
      final batch = _firestore.batch();
      
      // Delete from users collection
      batch.delete(_firestore.collection('users').doc(uid));
      
      // Delete from public_usernames collection
      batch.delete(_firestore.collection('public_usernames').doc(username.toLowerCase()));
      
      // Commit the batch
      await batch.commit();
      
      // Invalidate cache entry
      invalidateCacheEntry(username);
      
      LoggerService.info('Deleted user $username (uid: $uid) from both collections', tag: 'UsernameAuthService');
    } catch (e) {
      LoggerService.error('Failed to delete user', tag: 'UsernameAuthService', error: e);
      rethrow;
    }
  }
  
  /// Updates the password for a user. (Not implemented)
  ///
  /// This requires backend support (e.g., a Cloud Function with the Admin SDK)
  /// and is not implemented on the client side for security reasons.
  Future<void> updatePasswordForUser({
    required String username,
    required String newPassword,
  }) async {
    try {
      // This would require Firebase Admin SDK or Cloud Functions
      // For now, we'll throw an exception indicating this needs backend support
      throw UnimplementedError(
        'Password reset requires Firebase Admin SDK. '
        'Please implement a Cloud Function for this feature.',
      );
    } catch (e) {
      LoggerService.error('Update password error', tag: 'UsernameAuthService', error: e);
      rethrow;
    }
  }

  /// Validates the format of a username.
  ///
  /// Usernames must be 3-20 characters long, start with a letter, and
  /// contain only letters, numbers, and underscores.
  ///
  /// - [username]: The username to validate.
  ///
  /// Returns `true` if the username is valid.
  bool isValidUsername(String username) {
    // Username must be:
    // - 3-20 characters long
    // - Contain only letters, numbers, and underscores
    // - Start with a letter
    final regex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{2,19}$');
    return regex.hasMatch(username);
  }

  /// Generates a username suggestion based on a user's first and last name.
  ///
  /// - [firstName]: The user's first name.
  /// - [lastName]: The user's last name.
  ///
  /// Returns a suggested username (e.g., `jdoe01`).
  String generateUsername(String firstName, String lastName) {
    // Create username from first initial + last name + number
    final firstInitial = firstName.isNotEmpty ? firstName[0].toLowerCase() : '';
    final lastNameClean = lastName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    // Start with base username
    String baseUsername = '$firstInitial$lastNameClean';

    // Ensure minimum length
    if (baseUsername.length < 3) {
      baseUsername = '${firstName.toLowerCase()}${lastName.toLowerCase()}'
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    // Truncate if too long
    if (baseUsername.length > 17) {
      baseUsername = baseUsername.substring(0, 17);
    }

    // Add number suffix (will be incremented if not unique)
    return '${baseUsername}01';
  }

  /// Finds the next available username by incrementing a numerical suffix.
  ///
  /// - [baseUsername]: The base username to start with.
  ///
  /// Returns an available username.
  Future<String> getNextAvailableUsername(String baseUsername) async {
    // Remove any trailing numbers
    final cleanBase = baseUsername.replaceAll(RegExp(r'\d+$'), '');

    // Try suffixes up to the maximum attempts
    for (int i = 1; i < _maxUsernameSuffixAttempts; i++) {
      final username = '$cleanBase${i.toString().padLeft(2, '0')}';
      if (await isUsernameAvailable(username)) {
        return username;
      }
    }

    // If all 99 are taken, throw error
    throw Exception('Could not generate unique username');
  }
  
  /// Adds a username-UID mapping to the cache with an LRU eviction policy.
  ///
  /// - [username]: The username to cache.
  /// - [uid]: The corresponding UID.
  static void _addToCache(String username, String uid) {
    // Remove from access order if already exists
    _cacheAccessOrder.remove(username);
    
    // Add to end of access order (most recently used)
    _cacheAccessOrder.add(username);
    
    // Check if we need to evict
    if (_usernameCache.length >= _maxCacheSize && !_usernameCache.containsKey(username)) {
      // Remove least recently used items until we have space
      while (_usernameCache.length >= _maxCacheSize && _cacheAccessOrder.isNotEmpty) {
        final lru = _cacheAccessOrder.removeAt(0);
        _usernameCache.remove(lru);
        LoggerService.debug('Evicted $lru from cache (LRU)', tag: 'UsernameAuthService');
      }
    }
    
    // Add the new entry
    _usernameCache[username] = _CachedUsername(
      uid: uid,
      timestamp: DateTime.now(),
    );
  }
  
  /// Updates the access order for a cached item, marking it as recently used.
  ///
  /// - [username]: The username to update.
  static void _updateCacheAccess(String username) {
    _cacheAccessOrder.remove(username);
    _cacheAccessOrder.add(username);
  }
  
  /// Clears the entire username cache.
  static void clearCache() {
    _usernameCache.clear();
    _cacheAccessOrder.clear();
    LoggerService.info('Username cache cleared', tag: 'UsernameAuthService');
  }
  
  /// Removes a specific username from the cache.
  ///
  /// - [username]: The username to invalidate.
  static void invalidateCacheEntry(String username) {
    final lowerUsername = username.toLowerCase();
    _usernameCache.remove(lowerUsername);
    _cacheAccessOrder.remove(lowerUsername);
    LoggerService.info('Invalidated cache entry for: $lowerUsername', tag: 'UsernameAuthService');
  }
}

/// Represents a cached username-to-UID mapping.
class _CachedUsername {
  /// The user's UID.
  final String uid;

  /// The timestamp when the entry was cached.
  final DateTime timestamp;
  
  /// Creates a cache entry.
  _CachedUsername({
    required this.uid,
    required this.timestamp,
  });
  
  /// Whether the cache entry has expired.
  bool get isExpired => 
      DateTime.now().difference(timestamp) > UsernameAuthService._cacheTTL;
}
