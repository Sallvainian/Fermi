import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/services/logger_service.dart';

/// Handles Firebase Auth persistence configuration for web platform
class WebAuthPersistence {
  /// Configures Firebase Auth persistence for web platform
  /// 
  /// On web, we need to explicitly set persistence to LOCAL to maintain
  /// auth state across browser sessions and page refreshes
  static Future<void> configurePersistence() async {
    if (!kIsWeb) return;
    
    try {
      // Set persistence to LOCAL for web platform
      // This ensures auth state persists across browser sessions
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      
      LoggerService.info(
        'Firebase Auth persistence set to LOCAL for web platform',
        tag: 'WebAuthPersistence'
      );
    } catch (e) {
      LoggerService.error(
        'Failed to set Firebase Auth persistence',
        tag: 'WebAuthPersistence',
        error: e
      );
    }
  }
  
  /// Debug method to check current auth persistence
  static Future<void> checkPersistence() async {
    if (!kIsWeb) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      LoggerService.debug(
        'Current auth state - User: ${user?.uid ?? "none"}, '
        'Email: ${user?.email ?? "none"}, '
        'Anonymous: ${user?.isAnonymous ?? false}',
        tag: 'WebAuthPersistence'
      );
      
      // Check if there's a persisted session
      final idToken = await user?.getIdToken();
      LoggerService.debug(
        'ID Token exists: ${idToken != null}',
        tag: 'WebAuthPersistence'
      );
    } catch (e) {
      LoggerService.error(
        'Error checking persistence',
        tag: 'WebAuthPersistence',
        error: e
      );
    }
  }
}