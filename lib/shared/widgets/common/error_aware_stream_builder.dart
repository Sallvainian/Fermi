/// Error-aware stream builder widget that handles Firebase errors gracefully.
///
/// This widget wraps StreamBuilder to provide consistent error handling
/// for Firestore permission errors and other stream errors.
library;

import 'package:flutter/material.dart';
import '../../services/error_handler_service.dart';

/// A StreamBuilder that automatically handles errors with user-friendly messages.
///
/// Features:
/// - Automatic error detection and display
/// - Permission error handling with clear messages
/// - Network error handling
/// - Loading states
/// - Empty state handling
/// - Custom error widgets
class ErrorAwareStreamBuilder<T> extends StatelessWidget {
  /// The stream to listen to.
  final Stream<T> stream;

  /// Builder for the data state.
  final Widget Function(BuildContext context, T data) builder;

  /// Optional custom loading widget.
  final Widget? loadingWidget;

  /// Optional custom error widget builder.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Optional custom empty state widget.
  final Widget? emptyWidget;

  /// Whether to show error as dialog instead of inline.
  final bool showErrorAsDialog;

  /// Optional retry callback.
  final VoidCallback? onRetry;

  /// Check if data is empty (for showing empty state).
  final bool Function(T data)? isDataEmpty;

  const ErrorAwareStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.emptyWidget,
    this.showErrorAsDialog = false,
    this.onRetry,
    this.isDataEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        // Handle different states
        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error!);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState(context);
        }

        if (!snapshot.hasData) {
          return _buildEmptyState(context);
        }

        // Build the data state
        return builder(context, snapshot.data as T);
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return loadingWidget ?? const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    // Use custom error builder if provided
    if (errorBuilder != null) {
      return errorBuilder!(context, error);
    }

    // Check if it's a permission error
    final isPermissionError = ErrorHandlerService.isPermissionError(error);
    final errorMessage = ErrorHandlerService.getErrorMessage(error);

    // Show dialog if requested
    if (showErrorAsDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ErrorHandlerService.handleError(
          error,
          context: context,
          showAsDialog: true,
          onRetry: onRetry,
        );
      });
      return _buildLoadingState(context); // Show loading while dialog is shown
    }

    // Default inline error widget
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionError ? Icons.lock_outline : Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isPermissionError ? 'Access Denied' : 'Error Loading Data',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return emptyWidget ??
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 77 / 255.0),
              ),
              const SizedBox(height: 16),
              Text(
                'No data available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
  }
}

/// FutureBuilder with error handling
class ErrorAwareFutureBuilder<T> extends StatelessWidget {
  /// The future to listen to.
  final Future<T> future;

  /// Builder for the data state.
  final Widget Function(BuildContext context, T data) builder;

  /// Optional custom loading widget.
  final Widget? loadingWidget;

  /// Optional custom error widget builder.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Whether to show error as dialog instead of inline.
  final bool showErrorAsDialog;

  /// Optional retry callback.
  final VoidCallback? onRetry;

  const ErrorAwareFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.showErrorAsDialog = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        // Handle different states
        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error!);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(context);
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        // Build the data state
        return builder(context, snapshot.data as T);
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return loadingWidget ?? const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    // Use custom error builder if provided
    if (errorBuilder != null) {
      return errorBuilder!(context, error);
    }

    // Check if it's a permission error
    final isPermissionError = ErrorHandlerService.isPermissionError(error);
    final errorMessage = ErrorHandlerService.getErrorMessage(error);

    // Show dialog if requested
    if (showErrorAsDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ErrorHandlerService.handleError(
          error,
          context: context,
          showAsDialog: true,
          onRetry: onRetry,
        );
      });
      return _buildLoadingState(context); // Show loading while dialog is shown
    }

    // Default inline error widget
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionError ? Icons.lock_outline : Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isPermissionError ? 'Access Denied' : 'Error Loading Data',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
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
