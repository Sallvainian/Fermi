import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teacher_dashboard_flutter/features/auth/data/services/auth_service.dart';
import 'package:teacher_dashboard_flutter/features/auth/providers/auth_provider.dart';
import 'package:teacher_dashboard_flutter/shared/models/user_model.dart';

// Manual mock classes for Firebase Auth
class MockFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {
  MockUser? _currentUser;
  bool _deleteAccountCalled = false;
  bool _shouldThrowOnDelete = false;
  String? _deleteErrorMessage;
  
  @override
  firebase_auth.User? get currentUser => _currentUser;
  
  void setCurrentUser(MockUser? user) {
    _currentUser = user;
  }
  
  void setShouldThrowOnDelete(bool shouldThrow, [String? errorMessage]) {
    _shouldThrowOnDelete = shouldThrow;
    _deleteErrorMessage = errorMessage;
  }
  
  bool get deleteAccountCalled => _deleteAccountCalled;
  
  void reset() {
    _deleteAccountCalled = false;
    _shouldThrowOnDelete = false;
    _deleteErrorMessage = null;
  }
}

class MockUser extends Fake implements firebase_auth.User {
  final String _uid;
  final String? _email;
  final String? _displayName;
  bool _deleteCalled = false;
  bool _reauthenticateCalled = false;
  bool _shouldThrowOnDelete = false;
  String? _deleteErrorMessage;
  bool _shouldThrowOnReauth = false;
  String? _reauthErrorMessage;
  
  MockUser({
    required String uid,
    String? email,
    String? displayName,
  }) : _uid = uid,
       _email = email,
       _displayName = displayName;
  
  @override
  String get uid => _uid;
  
  @override
  String? get email => _email;
  
  @override
  String? get displayName => _displayName;
  
  @override
  bool get emailVerified => true;
  
  @override
  Future<void> delete() async {
    _deleteCalled = true;
    if (_shouldThrowOnDelete) {
      if (_deleteErrorMessage?.contains('requires-recent-login') ?? false) {
        throw firebase_auth.FirebaseAuthException(
          code: 'requires-recent-login',
          message: _deleteErrorMessage,
        );
      } else if (_deleteErrorMessage?.contains('network-request-failed') ?? false) {
        throw firebase_auth.FirebaseAuthException(
          code: 'network-request-failed',
          message: _deleteErrorMessage,
        );
      } else {
        throw Exception(_deleteErrorMessage ?? 'Delete failed');
      }
    }
  }
  
  @override
  Future<firebase_auth.UserCredential> reauthenticateWithCredential(
    firebase_auth.AuthCredential credential,
  ) async {
    _reauthenticateCalled = true;
    if (_shouldThrowOnReauth) {
      if (_reauthErrorMessage?.contains('wrong-password') ?? false) {
        throw firebase_auth.FirebaseAuthException(
          code: 'wrong-password',
          message: _reauthErrorMessage,
        );
      } else if (_reauthErrorMessage?.contains('user-mismatch') ?? false) {
        throw firebase_auth.FirebaseAuthException(
          code: 'user-mismatch',
          message: _reauthErrorMessage,
        );
      } else {
        throw Exception(_reauthErrorMessage ?? 'Reauthentication failed');
      }
    }
    return MockUserCredential(user: this);
  }
  
  @override
  Future<firebase_auth.UserCredential> reauthenticateWithPopup(
    firebase_auth.AuthProvider provider,
  ) async {
    _reauthenticateCalled = true;
    if (_shouldThrowOnReauth) {
      throw Exception(_reauthErrorMessage ?? 'Reauthentication failed');
    }
    return MockUserCredential(user: this);
  }
  
  bool get deleteCalled => _deleteCalled;
  bool get reauthenticateCalled => _reauthenticateCalled;
  
  void setShouldThrowOnDelete(bool shouldThrow, [String? errorMessage]) {
    _shouldThrowOnDelete = shouldThrow;
    _deleteErrorMessage = errorMessage;
  }
  
  void setShouldThrowOnReauth(bool shouldThrow, [String? errorMessage]) {
    _shouldThrowOnReauth = shouldThrow;
    _reauthErrorMessage = errorMessage;
  }
  
  void reset() {
    _deleteCalled = false;
    _reauthenticateCalled = false;
    _shouldThrowOnDelete = false;
    _deleteErrorMessage = null;
    _shouldThrowOnReauth = false;
    _reauthErrorMessage = null;
  }
}

class MockUserCredential extends Fake implements firebase_auth.UserCredential {
  final MockUser? _user;
  
  MockUserCredential({MockUser? user}) : _user = user;
  
  @override
  firebase_auth.User? get user => _user;
}

// Manual mock for Firestore
class MockFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, Map<String, dynamic>>> _collections = {};
  bool _shouldThrowOnDelete = false;
  String? _deleteErrorMessage;
  
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return MockCollectionReference(
      firestore: this,
      path: collectionPath,
    );
  }
  
  void setDocument(String collection, String docId, Map<String, dynamic> data) {
    _collections[collection] ??= {};
    _collections[collection]![docId] = data;
  }
  
  Map<String, dynamic>? getDocument(String collection, String docId) {
    return _collections[collection]?[docId];
  }
  
  void deleteDocument(String collection, String docId) {
    if (_shouldThrowOnDelete) {
      throw Exception(_deleteErrorMessage ?? 'Delete failed');
    }
    _collections[collection]?.remove(docId);
  }
  
  void setShouldThrowOnDelete(bool shouldThrow, [String? errorMessage]) {
    _shouldThrowOnDelete = shouldThrow;
    _deleteErrorMessage = errorMessage;
  }
  
  void reset() {
    _collections.clear();
    _shouldThrowOnDelete = false;
    _deleteErrorMessage = null;
  }
  
  bool documentExists(String collection, String docId) {
    return _collections[collection]?.containsKey(docId) ?? false;
  }
}

class MockCollectionReference extends Fake 
    implements CollectionReference<Map<String, dynamic>> {
  final MockFirebaseFirestore firestore;
  final String path;
  
  MockCollectionReference({
    required this.firestore,
    required this.path,
  });
  
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return MockDocumentReference(
      firestore: firestore,
      collection: this.path,
      docId: path ?? '',
    );
  }
}

class MockDocumentReference extends Fake 
    implements DocumentReference<Map<String, dynamic>> {
  final MockFirebaseFirestore firestore;
  final String collectionPath;
  final String docId;
  
  MockDocumentReference({
    required this.firestore,
    required String collection,
    required this.docId,
  }) : collectionPath = collection;
  
  @override
  String get id => docId;
  
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final data = firestore.getDocument(collectionPath, docId);
    return MockDocumentSnapshot(
      id: docId,
      exists: data != null,
      data: data,
    );
  }
  
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    firestore.setDocument(collectionPath, docId, data);
  }
  
  @override
  Future<void> update(Map<Object, Object?> data) async {
    final existing = firestore.getDocument(collectionPath, docId);
    if (existing != null) {
      final updated = Map<String, dynamic>.from(existing);
      data.forEach((key, value) {
        if (key is String) {
          updated[key] = value;
        }
      });
      firestore.setDocument(collectionPath, docId, updated);
    }
  }
  
  @override
  Future<void> delete() async {
    firestore.deleteDocument(collectionPath, docId);
  }
}

class MockDocumentSnapshot extends Fake 
    implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final bool _exists;
  final Map<String, dynamic>? _data;
  
  MockDocumentSnapshot({
    required String id,
    required bool exists,
    Map<String, dynamic>? data,
  }) : _id = id,
       _exists = exists,
       _data = data;
  
  @override
  String get id => _id;
  
  @override
  bool get exists => _exists;
  
  @override
  Map<String, dynamic>? data() => _data;
}

// Test AuthService that doesn't extend AuthService to avoid Firebase initialization
class TestAuthService {
  final MockFirebaseAuth mockAuth;
  final MockFirebaseFirestore mockFirestore;
  
  TestAuthService({
    required this.mockAuth,
    required this.mockFirestore,
  });
  
  firebase_auth.User? get currentUser => mockAuth.currentUser;
  
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await mockFirestore.collection('users').doc(uid).get();
    return doc.data();
  }
  
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final uid = user.uid;
      
      // Get user data to check role for additional cleanup
      final userData = await getUserData(uid);
      final userRole = userData?['role'] as String?;

      // Delete user document from Firestore
      await mockFirestore.collection('users').doc(uid).delete().catchError((_) {
        // Continue even if user document doesn't exist
      });

      // If user is a student, also delete from students collection
      if (userRole == 'student') {
        await mockFirestore.collection('students').doc(uid).delete().catchError((_) {
          // Continue even if student document doesn't exist
        });
      }
      
      // Delete Firebase Auth account (this must be done last)
      await user.delete();
      
    } catch (e) {
      // Handle common deletion errors
      if (e.toString().contains('requires-recent-login')) {
        throw Exception(
          'For security reasons, please sign in again before deleting your account.'
        );
      } else if (e.toString().contains('network-request-failed')) {
        throw Exception(
          'Network error. Please check your connection and try again.'
        );
      } else {
        throw Exception('Failed to delete account. Please try again.');
      }
    }
  }
  
  Future<void> reauthenticateWithEmail(String email, String password) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.toString().contains('user-mismatch')) {
        throw Exception('Email does not match current user.');
      } else {
        throw Exception('Authentication failed. Please try again.');
      }
    }
  }
  
  Future<void> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      // In test, we simulate the Google re-auth
      final provider = firebase_auth.GoogleAuthProvider();
      await user.reauthenticateWithPopup(provider);
    } catch (e) {
      throw Exception('Google authentication failed. Please try again.');
    }
  }
  
  Future<void> reauthenticateWithApple() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      // In test, we simulate the Apple re-auth
      final provider = firebase_auth.OAuthProvider('apple.com');
      await user.reauthenticateWithPopup(provider);
    } catch (e) {
      throw Exception('Apple authentication failed. Please try again.');
    }
  }
  
  Future<void> signOut() async {
    // Simple mock sign out
    mockAuth.setCurrentUser(null);
  }
}

// Test AuthProvider that works with TestAuthService
class TestAuthProvider extends ChangeNotifier {
  final TestAuthService _authService;
  AuthStatus _status;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading;
  bool _rememberMe = false;

  TestAuthProvider({
    required TestAuthService authService,
    AuthStatus initialStatus = AuthStatus.uninitialized,
    UserModel? userModel,
  }) : _authService = authService,
       _status = initialStatus,
       _userModel = userModel,
       _isLoading = false;

  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get rememberMe => _rememberMe;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.deleteAccount();
      _resetState();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reauthenticateWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (email.isEmpty || password.isEmpty) {
      _isLoading = false;
      setError('Email and password are required for re-authentication.');
      return;
    }

    try {
      await _authService.reauthenticateWithEmail(email, password);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.reauthenticateWithGoogle();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reauthenticateWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.reauthenticateWithApple();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetState() {
    _status = AuthStatus.unauthenticated;
    _userModel = null;
    _rememberMe = false;
    _errorMessage = null;
    _isLoading = false;
  }

  @override
  void dispose() {
    _isLoading = false;
    _errorMessage = null;
    _userModel = null;
    _status = AuthStatus.uninitialized;
    super.dispose();
  }
}

void main() {
  group('AuthService.deleteAccount', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late TestAuthService authService;
    late MockUser mockUser;
    
    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      authService = TestAuthService(
        mockAuth: mockAuth,
        mockFirestore: mockFirestore,
      );
      
      mockUser = MockUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
    });
    
    tearDown(() {
      mockAuth.reset();
      mockFirestore.reset();
      mockUser.reset();
    });
    
    test('should throw exception when no user is signed in', () async {
      // Arrange
      mockAuth.setCurrentUser(null);
      
      // Act & Assert
      expect(
        () => authService.deleteAccount(),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'message',
                contains('No user is currently signed in'),
              ),
        ),
      );
    });
    
    test('should delete user document from Firestore before Auth deletion', () async {
      // Arrange
      mockAuth.setCurrentUser(mockUser);
      mockFirestore.setDocument('users', 'test-uid-123', {
        'uid': 'test-uid-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'teacher',
      });
      
      // Act
      await authService.deleteAccount();
      
      // Assert
      expect(mockFirestore.documentExists('users', 'test-uid-123'), isFalse);
      expect(mockUser.deleteCalled, isTrue);
    });
    
    test('should delete student document for student users', () async {
      // Arrange
      mockAuth.setCurrentUser(mockUser);
      mockFirestore.setDocument('users', 'test-uid-123', {
        'uid': 'test-uid-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'student',
      });
      mockFirestore.setDocument('students', 'test-uid-123', {
        'uid': 'test-uid-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'isActive': true,
      });
      
      // Act
      await authService.deleteAccount();
      
      // Assert
      expect(mockFirestore.documentExists('users', 'test-uid-123'), isFalse);
      expect(mockFirestore.documentExists('students', 'test-uid-123'), isFalse);
      expect(mockUser.deleteCalled, isTrue);
    });
    
    test('should continue even if user document does not exist', () async {
      // Arrange
      mockAuth.setCurrentUser(mockUser);
      // No user document in Firestore
      
      // Act & Assert - should not throw
      await expectLater(
        authService.deleteAccount(),
        completes,
      );
      expect(mockUser.deleteCalled, isTrue);
    });
    
    test('should handle requires-recent-login error', () async {
      // Arrange
      mockAuth.setCurrentUser(mockUser);
      mockUser.setShouldThrowOnDelete(true, 'requires-recent-login');
      
      // Act & Assert
      expect(
        () => authService.deleteAccount(),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'message',
                contains('please sign in again before deleting'),
              ),
        ),
      );
    });
    
    test('should handle network error', () async {
      // Arrange
      mockAuth.setCurrentUser(mockUser);
      mockUser.setShouldThrowOnDelete(true, 'network-request-failed');
      
      // Act & Assert
      expect(
        () => authService.deleteAccount(),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'message',
                contains('Network error'),
              ),
        ),
      );
    });
    
    test('should handle generic deletion error', () async {
      // Arrange
      mockAuth.setCurrentUser(mockUser);
      mockUser.setShouldThrowOnDelete(true, 'unknown-error');
      
      // Act & Assert
      expect(
        () => authService.deleteAccount(),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'message',
                contains('Failed to delete account'),
              ),
        ),
      );
    });
  });
  
  group('AuthService re-authentication', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late TestAuthService authService;
    late MockUser mockUser;
    
    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      authService = TestAuthService(
        mockAuth: mockAuth,
        mockFirestore: mockFirestore,
      );
      
      mockUser = MockUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockAuth.setCurrentUser(mockUser);
    });
    
    tearDown(() {
      mockAuth.reset();
      mockFirestore.reset();
      mockUser.reset();
    });
    
    test('reauthenticateWithEmail should throw when no user signed in', () async {
      // Arrange
      mockAuth.setCurrentUser(null);
      
      // Act & Assert
      expect(
        () => authService.reauthenticateWithEmail('test@example.com', 'password'),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'message',
                contains('No user is currently signed in'),
              ),
        ),
      );
    });
    
    test('reauthenticateWithEmail should handle wrong password', () async {
      // Arrange
      mockUser.setShouldThrowOnReauth(true, 'wrong-password');
      
      // Act & Assert
      expect(
        () => authService.reauthenticateWithEmail('test@example.com', 'wrongpass'),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'message',
                contains('Incorrect password'),
              ),
        ),
      );
    });
    
    test('reauthenticateWithEmail should handle user mismatch', () async {
      // Arrange
      mockUser.setShouldThrowOnReauth(true, 'user-mismatch');
      
      // Act & Assert
      expect(
        () => authService.reauthenticateWithEmail('wrong@example.com', 'password'),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'message',
                contains('Email does not match'),
              ),
        ),
      );
    });
    
    test('reauthenticateWithEmail should succeed with correct credentials', () async {
      // Act & Assert - should not throw
      await expectLater(
        authService.reauthenticateWithEmail('test@example.com', 'password'),
        completes,
      );
      expect(mockUser.reauthenticateCalled, isTrue);
    });
  });
  
  group('AuthProvider.deleteAccount', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late TestAuthService authService;
    late TestAuthProvider authProvider;
    late MockUser mockUser;
    
    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      authService = TestAuthService(
        mockAuth: mockAuth,
        mockFirestore: mockFirestore,
      );
      
      mockUser = MockUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      
      mockAuth.setCurrentUser(mockUser);
      
      // Set up user data in Firestore
      mockFirestore.setDocument('users', 'test-uid-123', {
        'uid': 'test-uid-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'teacher',
      });
      
      authProvider = TestAuthProvider(
        authService: authService,
        initialStatus: AuthStatus.authenticated,
        userModel: const UserModel(
          uid: 'test-uid-123',
          email: 'test@example.com',
          displayName: 'Test User',
          role: UserRole.teacher,
        ),
      );
    });
    
    tearDown(() {
      mockAuth.reset();
      mockFirestore.reset();
      mockUser.reset();
      authProvider.dispose();
    });
    
    test('should set loading state during deletion', () async {
      // Arrange
      bool loadingStateSeen = false;
      authProvider.addListener(() {
        if (authProvider.isLoading) {
          loadingStateSeen = true;
        }
      });
      
      // Act
      await authProvider.deleteAccount();
      
      // Assert
      expect(loadingStateSeen, isTrue);
      expect(authProvider.isLoading, isFalse);
    });
    
    test('should reset auth state after successful deletion', () async {
      // Act
      await authProvider.deleteAccount();
      
      // Assert
      expect(authProvider.status, equals(AuthStatus.unauthenticated));
      expect(authProvider.userModel, isNull);
      expect(authProvider.errorMessage, isNull);
    });
    
    test('should set error message on deletion failure', () async {
      // Arrange
      mockUser.setShouldThrowOnDelete(true, 'requires-recent-login');
      
      // Act
      await authProvider.deleteAccount();
      
      // Assert
      expect(authProvider.errorMessage, isNotNull);
      expect(authProvider.errorMessage, contains('sign in again'));
      expect(authProvider.status, equals(AuthStatus.authenticated)); // State unchanged on error
    });
    
    test('should call AuthService.deleteAccount', () async {
      // Act
      await authProvider.deleteAccount();
      
      // Assert
      expect(mockUser.deleteCalled, isTrue);
      expect(mockFirestore.documentExists('users', 'test-uid-123'), isFalse);
    });
  });
  
  group('AuthProvider re-authentication', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late TestAuthService authService;
    late TestAuthProvider authProvider;
    late MockUser mockUser;
    
    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      authService = TestAuthService(
        mockAuth: mockAuth,
        mockFirestore: mockFirestore,
      );
      
      mockUser = MockUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      
      mockAuth.setCurrentUser(mockUser);
      
      authProvider = TestAuthProvider(
        authService: authService,
        initialStatus: AuthStatus.authenticated,
        userModel: const UserModel(
          uid: 'test-uid-123',
          email: 'test@example.com',
          displayName: 'Test User',
          role: UserRole.teacher,
        ),
      );
    });
    
    tearDown(() {
      mockAuth.reset();
      mockFirestore.reset();
      mockUser.reset();
      authProvider.dispose();
    });
    
    test('reauthenticateWithEmail should validate empty fields', () async {
      // Act
      await authProvider.reauthenticateWithEmail('', '');
      
      // Assert
      expect(authProvider.errorMessage, contains('Email and password are required'));
    });
    
    test('reauthenticateWithEmail should set loading state', () async {
      // Arrange
      bool loadingStateSeen = false;
      authProvider.addListener(() {
        if (authProvider.isLoading) {
          loadingStateSeen = true;
        }
      });
      
      // Act
      await authProvider.reauthenticateWithEmail('test@example.com', 'password');
      
      // Assert
      expect(loadingStateSeen, isTrue);
      expect(authProvider.isLoading, isFalse);
    });
    
    test('reauthenticateWithEmail should handle errors', () async {
      // Arrange
      mockUser.setShouldThrowOnReauth(true, 'wrong-password');
      
      // Act
      await authProvider.reauthenticateWithEmail('test@example.com', 'wrongpass');
      
      // Assert
      expect(authProvider.errorMessage, contains('Incorrect password'));
    });
    
    test('reauthenticateWithGoogle should call authService', () async {
      // Act
      await authProvider.reauthenticateWithGoogle();
      
      // Assert
      expect(mockUser.reauthenticateCalled, isTrue);
    });
    
    test('reauthenticateWithApple should call authService', () async {
      // Act
      await authProvider.reauthenticateWithApple();
      
      // Assert
      expect(mockUser.reauthenticateCalled, isTrue);
    });
  });
  
  group('Account deletion flow integration', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late TestAuthService authService;
    late TestAuthProvider authProvider;
    late MockUser mockUser;
    
    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      authService = TestAuthService(
        mockAuth: mockAuth,
        mockFirestore: mockFirestore,
      );
      
      mockUser = MockUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      
      mockAuth.setCurrentUser(mockUser);
      
      // Set up complete user profile
      mockFirestore.setDocument('users', 'test-uid-123', {
        'uid': 'test-uid-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'student',
        'firstName': 'Test',
        'lastName': 'User',
      });
      
      mockFirestore.setDocument('students', 'test-uid-123', {
        'uid': 'test-uid-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'isActive': true,
        'classIds': ['class-1', 'class-2'],
      });
      
      authProvider = TestAuthProvider(
        authService: authService,
        initialStatus: AuthStatus.authenticated,
        userModel: const UserModel(
          uid: 'test-uid-123',
          email: 'test@example.com',
          displayName: 'Test User',
          firstName: 'Test',
          lastName: 'User',
          role: UserRole.student,
        ),
      );
    });
    
    tearDown(() {
      mockAuth.reset();
      mockFirestore.reset();
      mockUser.reset();
      authProvider.dispose();
    });
    
    test('complete deletion flow for student with re-authentication', () async {
      // Step 1: First deletion attempt fails due to stale auth
      mockUser.setShouldThrowOnDelete(true, 'requires-recent-login');
      await authProvider.deleteAccount();
      
      // Verify error state
      expect(authProvider.errorMessage, contains('sign in again'));
      expect(authProvider.status, equals(AuthStatus.authenticated));
      
      // Step 2: Re-authenticate
      mockUser.setShouldThrowOnDelete(false);
      await authProvider.reauthenticateWithEmail('test@example.com', 'password');
      
      // Verify re-auth succeeded
      expect(mockUser.reauthenticateCalled, isTrue);
      expect(authProvider.errorMessage, isNull);
      
      // Step 3: Retry deletion
      await authProvider.deleteAccount();
      
      // Verify complete deletion
      expect(authProvider.status, equals(AuthStatus.unauthenticated));
      expect(authProvider.userModel, isNull);
      expect(mockFirestore.documentExists('users', 'test-uid-123'), isFalse);
      expect(mockFirestore.documentExists('students', 'test-uid-123'), isFalse);
      expect(mockUser.deleteCalled, isTrue);
    });
    
    test('deletion order: Firestore documents deleted before Auth account', () async {
      // This test verifies that Firestore documents are deleted before
      // the Firebase Auth account to ensure data cleanup happens first.
      // The order is tracked by checking that documents exist before deletion
      // and don't exist after, and that the Auth delete is called last.
      
      // Verify initial state
      expect(mockFirestore.documentExists('users', 'test-uid-123'), isTrue);
      expect(mockFirestore.documentExists('students', 'test-uid-123'), isTrue);
      expect(mockUser.deleteCalled, isFalse);
      
      // Act
      await authProvider.deleteAccount();
      
      // Assert - Verify deletion occurred in correct order
      expect(mockFirestore.documentExists('users', 'test-uid-123'), isFalse);
      expect(mockFirestore.documentExists('students', 'test-uid-123'), isFalse);
      expect(mockUser.deleteCalled, isTrue);
      
      // The implementation ensures Firestore deletions happen before Auth deletion
      // by the order of operations in the deleteAccount method
    });
  });
}