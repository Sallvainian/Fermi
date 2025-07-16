import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Builds the Google Sign-In button for web platform
Widget buildGoogleSignInButtonWeb() {
  if (!kIsWeb) {
    return const SizedBox.shrink();
  }
  
  // Use the web-only renderButton method
  try {
    return web.renderButton();
  } catch (e) {
    // Fallback if platform is not properly initialized
    return const Center(
      child: Text('Google Sign-In not available'),
    );
  }
}