import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/services/region_detector_service.dart';

/// Service to handle VoIP push token management for iOS
class VoIPTokenService {
  static final VoIPTokenService _instance = VoIPTokenService._internal();
  factory VoIPTokenService() => _instance;
  VoIPTokenService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RegionDetectorService _regionDetector = RegionDetectorService();

  String? _currentVoIPToken;

  /// Initialize VoIP token handling
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isIOS) {
      LoggerService.info('VoIP tokens only supported on iOS native',
          tag: 'VoIPTokenService');
      return;
    }

    // Initialize region detector
    await _regionDetector.initialize();

    // Check if CallKit is allowed in current region
    if (!_regionDetector.isCallKitAllowed) {
      LoggerService.info(
        'VoIP tokens disabled due to regional restrictions (China MIIT requirement)',
        tag: 'VoIPTokenService'
      );
      return;
    }

    try {
      // Listen for VoIP token updates from iOS
      // Note: flutter_callkit_incoming doesn't have onTokenRefresh stream
      // VoIP tokens are handled by the native iOS code in AppDelegate.swift

      // Get current token if available (this may return null if not set from native side)
      try {
        final currentToken =
            await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        if (currentToken != null && currentToken.isNotEmpty) {
          LoggerService.info('Current VoIP token: $currentToken',
              tag: 'VoIPTokenService');
          await _saveVoIPToken(currentToken);
        }
      } catch (e) {
        LoggerService.warning(
            'Could not get VoIP token - may not be available yet',
            tag: 'VoIPTokenService');
      }
    } catch (e) {
      LoggerService.error('Failed to initialize VoIP token service',
          error: e, tag: 'VoIPTokenService');
    }
  }

  /// Save VoIP token to Firestore
  Future<void> _saveVoIPToken(String token) async {
    if (token == _currentVoIPToken) return; // Skip if same token

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      LoggerService.warning('Cannot save VoIP token - user not authenticated',
          tag: 'VoIPTokenService');
      return;
    }

    try {
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'voipToken': token,
        'voipTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': 'ios',
      });

      // Also save in separate collection for easier querying
      await _firestore.collection('voip_tokens').doc(userId).set({
        'token': token,
        'userId': userId,
        'platform': 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _currentVoIPToken = token;
      LoggerService.info('VoIP token saved successfully',
          tag: 'VoIPTokenService');
    } catch (e) {
      LoggerService.error('Failed to save VoIP token',
          error: e, tag: 'VoIPTokenService');
    }
  }

  /// Get VoIP token for a user
  Future<String?> getVoIPTokenForUser(String userId) async {
    try {
      final doc = await _firestore.collection('voip_tokens').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['token'] as String?;
      }
    } catch (e) {
      LoggerService.error('Failed to get VoIP token for user',
          error: e, tag: 'VoIPTokenService');
    }
    return null;
  }

  /// Delete VoIP token (for logout)
  Future<void> deleteVoIPToken() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Remove from user document
      await _firestore.collection('users').doc(userId).update({
        'voipToken': FieldValue.delete(),
        'voipTokenUpdatedAt': FieldValue.delete(),
      });

      // Remove from tokens collection
      await _firestore.collection('voip_tokens').doc(userId).delete();

      _currentVoIPToken = null;
      LoggerService.info('VoIP token deleted', tag: 'VoIPTokenService');
    } catch (e) {
      LoggerService.error('Failed to delete VoIP token',
          error: e, tag: 'VoIPTokenService');
    }
  }

  /// Send VoIP push notification (for server implementation reference)
  /// This would typically be implemented on your backend server
  Map<String, dynamic> generateVoIPPushPayload({
    required String voipToken,
    required String callId,
    required String callerId,
    required String callerName,
    required bool isVideo,
    String? callerPhotoUrl,
    String? chatRoomId,
  }) {
    return {
      'aps': {
        // Empty aps for VoIP push
      },
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl ?? '',
      'isVideo': isVideo,
      'chatRoomId': chatRoomId ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
