import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/services/logger_service.dart';
import 'package:flutter/foundation.dart';

class AuthErrorMapper {
  static String signInMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'invalid-email':
          return 'Invalid email address';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'invalid-credential':
          return 'Invalid email or password';
      }
      return error.message ?? 'Authentication failed';
    }
    return error.toString();
  }

  static String signUpMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'invalid-email':
          return 'Invalid email address';
        case 'weak-password':
          return 'Password is too weak';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled';
      }
      return error.message ?? 'Account creation failed';
    }
    return error.toString();
  }

  static String oAuthMessage(dynamic error, String provider) {
    final errorString = error.toString();
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address';
        case 'invalid-credential':
          return 'Invalid $provider credentials';
        case 'operation-not-allowed':
          return '$provider sign-in is not enabled';
        case 'user-disabled':
          return 'This account has been disabled';
      }
      return error.message ?? '$provider authentication failed';
    }

    if (errorString.contains('not available') ||
        errorString.contains('not built with OAuth')) {
      return '$provider Sign-In is not available in this build. Please use email/password.';
    }
    if (errorString.contains('authentication server')) {
      return 'Sign-in service temporarily unavailable. Please try again or use email/password.';
    }
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    }
    if (errorString.contains('Failed to open browser')) {
      return 'Could not open browser for sign-in. Please check your default browser settings.';
    }
    if (errorString.contains('Authorization was cancelled')) {
      return 'Sign-in was cancelled';
    }
    return 'Sign-in failed. Please try again or use email/password.';
  }

  static void logOAuthError(dynamic error, String provider) {
    LoggerService.error('OAuth error', tag: 'Auth', error: error);
    if (kDebugMode && error is FirebaseAuthException) {
      LoggerService.debug('Firebase code: ${error.code}', tag: 'Auth');
      LoggerService.debug('Firebase message: ${error.message}', tag: 'Auth');
    }
  }

  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'invalid-email':
          return 'Invalid email address';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'invalid-credential':
          return 'Invalid email or password';
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'weak-password':
          return 'Password is too weak';
        case 'operation-not-allowed':
          return 'This operation is not allowed';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address';
        default:
          return error.message ?? 'Authentication failed';
      }
    }
    return error.toString();
  }
}

