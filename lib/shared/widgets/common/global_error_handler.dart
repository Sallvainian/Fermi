/// Global error handler widget that listens for Firebase errors.
/// 
/// This widget should wrap the entire app to catch and display
/// Firebase permission errors and other errors globally.
library;

import 'package:flutter/material.dart';
import '../../services/error_handler_service.dart';

/// Global error handler that displays errors as snackbars or dialogs.
class GlobalErrorHandler extends StatefulWidget {
  final Widget child;
  
  const GlobalErrorHandler({
    super.key,
    required this.child,
  });

  @override
  State<GlobalErrorHandler> createState() => _GlobalErrorHandlerState();
}

class _GlobalErrorHandlerState extends State<GlobalErrorHandler> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin to add global error handling to any stateful widget.
mixin GlobalErrorHandlerMixin<T extends StatefulWidget> on State<T> {
  /// Show error message using the nearest scaffold.
  void showError(dynamic error, {VoidCallback? onRetry}) {
    if (!mounted) return;
    
    final message = ErrorHandlerService.getErrorMessage(error);
    final isPermissionError = ErrorHandlerService.isPermissionError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isPermissionError ? Icons.lock_outline : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onRetry();
                },
              )
            : null,
      ),
    );
  }
  
  /// Show permission error dialog.
  void showPermissionError({
    required String resource,
    String? additionalInfo,
  }) {
    if (!mounted) return;
    
    ErrorHandlerService.showPermissionDeniedDialog(
      context,
      resource: resource,
      additionalInfo: additionalInfo,
    );
  }
}

/// Extension to make showing errors easier from anywhere.
extension GlobalErrorContext on BuildContext {
  /// Show a Firebase error with appropriate UI.
  void showFirebaseError(dynamic error, {VoidCallback? onRetry}) {
    final message = ErrorHandlerService.getErrorMessage(error);
    final isPermissionError = ErrorHandlerService.isPermissionError(error);
    
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isPermissionError ? Icons.lock_outline : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
          backgroundColor: Theme.of(this).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: onRetry != null
              ? SnackBarAction(
                  label: 'RETRY',
                  textColor: Colors.white,
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onRetry();
                  },
                )
              : null,
        ),
      );
    } else {
      // Fallback to dialog if no scaffold
      showDialog(
        context: this,
        builder: (context) => AlertDialog(
          icon: Icon(
            isPermissionError ? Icons.lock_outline : Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 48,
          ),
          title: Text(isPermissionError ? 'Access Denied' : 'Error'),
          content: Text(message),
          actions: [
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                child: const Text('RETRY'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}