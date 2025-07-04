import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'base_repository.dart';

abstract class AuthRepository extends BaseRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserModel?> getCurrentUserModel();
  
  Future<User?> signUpWithEmailOnly({
    required String email,
    required String password,
    required String displayName,
    required String firstName,
    required String lastName,
  });
  
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    UserRole? role,
    String? parentEmail,
    int? gradeLevel,
  });
  
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  });
  
  Future<UserModel?> signInWithGoogle();
  
  Future<UserModel?> completeGoogleSignUp({
    required UserRole role,
    String? parentEmail,
    int? gradeLevel,
  });
  
  Future<void> signOut();
  Future<void> resetPassword(String email);
  
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoURL,
    bool updatePhoto = false,
  });
}