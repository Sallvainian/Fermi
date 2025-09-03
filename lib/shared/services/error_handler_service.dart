/// Global error handling service for the application.
///
/// This service provides centralized error handling with user-friendly
/// messages for common Firebase errors, especially permission errors.
/// It can show errors as snackbars, dialogs, or custom overlays.
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

/// Global error handler service for consistent error presentation.
///
/// Features:
/// - User-friendly error messages for Firebase errors
/// - Permission error detection and handling
/// - Network error handling
/// - Customizable error presentation (snackbar, dialog, overlay)
/// - Error logging and tracking
class ErrorHandlerService {
  static const String _tag = 'ErrorHandlerService';

  /// Global navigator key for showing errors from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Global scaffold messenger key for showing snackbars
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Handle an error and show appropriate UI feedback.
  ///
  /// @param error The error object
  /// @param context Optional build context for showing dialogs
  /// @param message Optional custom message to show
  /// @param showAsDialog Whether to show as dialog instead of snackbar
  static void handleError(
    dynamic error, {
    BuildContext? context,
    String? message,
    bool showAsDialog = false,
    VoidCallback? onRetry,
  }) {
    // Log the error
    LoggerService.error(
      message ?? 'An error occurred',
      tag: _tag,
      error: error,
    );

    // Get user-friendly message
    final errorMessage = getErrorMessage(error, customMessage: message);

    // Show error UI
    if (showAsDialog &&
        (context != null || navigatorKey.currentContext != null)) {
      _showErrorDialog(
        context ?? navigatorKey.currentContext!,
        errorMessage,
        onRetry: onRetry,
      );
    } else {
      _showErrorSnackbar(errorMessage, onRetry: onRetry);
    }
  }

  /// Get a user-friendly error message based on the error type.
  static String getErrorMessage(dynamic error, {String? customMessage}) {
    if (customMessage != null) return customMessage;

    // Handle FirebaseException
    if (error is FirebaseException) {
      switch (error.code) {
        // Firestore permission errors
        case 'permission-denied':
          return 'You don\'t have permission to access this data. Please contact your teacher if you believe this is an error.';

        // Auth errors
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'Password is too weak. Please use a stronger password.';
        case 'invalid-email':
          return 'Invalid email address format.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';

        // Firestore errors
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again later.';
        case 'data-loss':
          return 'Data integrity error. Please refresh and try again.';
        case 'deadline-exceeded':
          return 'Request timed out. Please check your connection and try again.';
        case 'resource-exhausted':
          return 'Too many requests. Please wait a moment and try again.';
        case 'failed-precondition':
          return 'Operation failed. Please refresh and try again.';
        case 'aborted':
          return 'Operation was cancelled. Please try again.';
        case 'out-of-range':
          return 'Invalid data range. Please check your input.';
        case 'unimplemented':
          return 'This feature is not yet available.';
        case 'internal':
          return 'An internal error occurred. Please try again later.';
        case 'not-found':
          return 'The requested data was not found.';
        case 'already-exists':
          return 'This item already exists.';

        default:
          return 'An error occurred: ${error.message ?? error.code}';
      }
    }

    // Handle other specific error types
    if (error is FirebaseAuthException) {
      return getErrorMessage(error as FirebaseException);
    }

    // Network errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException')) {
      return 'Network error. Please check your internet connection.';
    }

    // Format errors
    if (error is FormatException) {
      return 'Invalid data format. Please check your input.';
    }

    // Type errors (often from null data)
    if (error is TypeError) {
      return 'Data loading error. Please refresh and try again.';
    }

    // Default error message
    return 'An unexpected error occurred. Please try again.';
  }

  /// Show error as a snackbar.
  static void _showErrorSnackbar(String message, {VoidCallback? onRetry}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show error as a dialog.
  static void _showErrorDialog(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('RETRY'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a permission denied dialog with more context.
  static void showPermissionDeniedDialog(
    BuildContext context, {
    required String resource,
    String? additionalInfo,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.lock_outline,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: const Text('Access Denied'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You don\'t have permission to access $resource.'),
            if (additionalInfo != null) ...[
              const SizedBox(height: 8),
              Text(
                additionalInfo,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'If you believe this is an error, please contact your teacher or administrator.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Extract Firebase error code from error message.
  static String? extractFirebaseErrorCode(dynamic error) {
    if (error is FirebaseException) {
      return error.code;
    }

    // Try to extract from string representation
    final errorString = error.toString();
    final match = RegExp(r'\[([^\]]+)\]').firstMatch(errorString);
    return match?.group(1);
  }

  /// Check if error is a permission error.
  static bool isPermissionError(dynamic error) {
    final code = extractFirebaseErrorCode(error);
    return code == 'permission-denied' ||
        error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED');
  }

  /// Check if error is a network error.
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('unavailable');
  }
}

/// Extension to make error handling easier on BuildContext.
extension ErrorHandlingExtension on BuildContext {
  /// Show an error with context-aware presentation.
  void showError(
    dynamic error, {
    String? message,
    bool asDialog = false,
    VoidCallback? onRetry,
  }) {
    ErrorHandlerService.handleError(
      error,
      context: this,
      message: message,
      showAsDialog: asDialog,
      onRetry: onRetry,
    );
  }

  /// Show a permission denied error.
  void showPermissionError({required String resource, String? additionalInfo}) {
    ErrorHandlerService.showPermissionDeniedDialog(
      this,
      resource: resource,
      additionalInfo: additionalInfo,
    );
  }
}
