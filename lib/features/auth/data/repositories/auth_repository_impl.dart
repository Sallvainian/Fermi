/// Concrete implementation of the authentication repository.
/// 
/// This module implements the AuthRepository interface by delegating
/// all operations to the AuthService, providing a clean separation
/// between the repository pattern and service layer.
library;

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/models/user_model.dart';
import '../services/auth_service.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete authentication repository implementation.
/// 
/// This class implements the AuthRepository interface by delegating
/// all authentication operations to the underlying AuthService.
/// It acts as an adapter between the repository pattern used by
/// the application and the service layer that handles the actual
/// authentication logic.
/// 
/// The repository pattern provides:
/// - Abstraction of data source implementation details
/// - Testability through interface-based design  
/// - Flexibility to switch authentication providers
/// - Consistent API for the application layer
class AuthRepositoryImpl extends AuthRepository {
  /// The authentication service handling actual auth operations.
  final AuthService _authService;
  
  /// Creates an authentication repository instance.
  /// 
  /// @param _authService Service instance for authentication
  AuthRepositoryImpl(this._authService);
  
  @override
  Stream<User?> get authStateChanges => _authService.authStateChanges;
  
  @override
  User? get currentUser => _authService.currentUser;
  
  @override
  Future<UserModel?> getCurrentUserModel() => _authService.getCurrentUserModel();
  
  @override
  Future<User?> signUpWithEmailOnly({
    required String email,
    required String password,
    required String displayName,
    required String firstName,
    required String lastName,
  }) =>
      _authService.signUpWithEmailOnly(
        email: email,
        password: password,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
      );  
  @override
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    UserRole? role,
    String? parentEmail,
    int? gradeLevel,
  }) =>
      _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        parentEmail: parentEmail,
        gradeLevel: gradeLevel,
      );
  
  @override
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _authService.signInWithEmail(
        email: email,
        password: password,
      );
  
  @override
  Future<UserModel?> signInWithGoogle() => _authService.signInWithGoogle();  
  @override
  Future<UserModel?> completeGoogleSignUp({
    required UserRole role,
    String? parentEmail,
    int? gradeLevel,
  }) =>
      _authService.completeGoogleSignUp(
        role: role,
        parentEmail: parentEmail,
        gradeLevel: gradeLevel,
      );
  
  @override
  Future<void> signOut() => _authService.signOut();
  
  @override
  Future<void> resetPassword(String email) => _authService.resetPassword(email);
  
  @override
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoURL,
    bool updatePhoto = false,
  }) =>
      _authService.updateProfile(
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        photoURL: photoURL,
        updatePhoto: updatePhoto,
      );
}