/// A widget that wraps content and handles Firebase errors globally.
///
/// This widget acts as an error boundary for Firebase operations,
/// catching and displaying errors in a user-friendly way.
library;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../services/error_handler_service.dart';

/// Wraps child widgets to catch and handle Firebase errors.
///
/// This widget creates an error boundary that catches Firebase
/// exceptions that bubble up from child widgets and displays
/// them using the ErrorHandlerService.
class FirebaseErrorBoundary extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRetry;

  const FirebaseErrorBoundary({super.key, required this.child, this.onRetry});

  @override
  State<FirebaseErrorBoundary> createState() => _FirebaseErrorBoundaryState();
}

class _FirebaseErrorBoundaryState extends State<FirebaseErrorBoundary> {
  bool _hasError = false;
  dynamic _error;

  @override
  void initState() {
    super.initState();
    // Reset error state when widget rebuilds
    _hasError = false;
    _error = null;
  }

  void _handleError(dynamic error) {
    setState(() {
      _hasError = true;
      _error = error;
    });
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _error = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(context);
    }

    // Wrap child in error handler
    return ErrorBoundary(onError: _handleError, child: widget.child);
  }

  Widget _buildErrorWidget(BuildContext context) {
    final theme = Theme.of(context);
    final isPermissionError = ErrorHandlerService.isPermissionError(_error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionError ? Icons.lock_outline : Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isPermissionError ? 'Access Denied' : 'Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ErrorHandlerService.getErrorMessage(_error),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error boundary widget that catches errors in child widgets.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final void Function(dynamic error)? onError;

  const ErrorBoundary({super.key, required this.child, this.onError});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Check if this is a Firebase error
      if (details.exception is FirebaseException ||
          details.exception.toString().contains('permission-denied')) {
        widget.onError?.call(details.exception);
      }

      // Return a widget that displays the error
      return Container();
    };

    return widget.child;
  }
}
