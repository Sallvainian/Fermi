/// PreviewExampleWrapper widget with explicit DataState enum.
///
/// This widget provides a robust state management solution for showing
/// example/preview content when real data is empty, with clear visual
/// indicators and smooth transitions.
library;

import 'package:flutter/material.dart';
import 'example_badge.dart';

/// Enumeration representing different data states to prevent race conditions.
enum DataState {
  /// Data is currently being loaded
  loading,

  /// No data available (empty state)
  empty,

  /// Real data is available and populated
  populated,

  /// Error occurred while loading data
  error,
}

/// A wrapper widget that intelligently shows example data when real data is empty.
///
/// This widget provides:
/// - Explicit state management with DataState enum
/// - Visual indicators for example content
/// - Smooth transitions between states
/// - Accessibility support
/// - Interaction guards for example items
class PreviewExampleWrapper<T> extends StatelessWidget {
  /// Real data from the application
  final List<T>? realData;

  /// Example/preview data to show when real data is empty
  final List<T> exampleData;

  /// Builder function to render the data
  final Widget Function(BuildContext context, List<T> data, bool isExample)
  builder;

  /// Whether data is currently loading
  final bool isLoading;

  /// Error message if data loading failed
  final String? error;

  /// Callback when user taps on an example item
  final VoidCallback? onExampleTap;

  /// Custom empty state widget
  final Widget? emptyWidget;

  /// Custom loading widget
  final Widget? loadingWidget;

  /// Custom error widget
  final Widget? errorWidget;

  /// Whether to show the example badge
  final bool showExampleBadge;

  /// Animation duration for state transitions
  final Duration animationDuration;

  const PreviewExampleWrapper({
    super.key,
    this.realData,
    required this.exampleData,
    required this.builder,
    this.isLoading = false,
    this.error,
    this.onExampleTap,
    this.emptyWidget,
    this.loadingWidget,
    this.errorWidget,
    this.showExampleBadge = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  /// Determine the current data state based on inputs
  DataState get _currentState {
    if (error != null) return DataState.error;
    if (isLoading) return DataState.loading;
    if (realData != null && realData!.isNotEmpty) return DataState.populated;
    return DataState.empty;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: animationDuration,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      child: _buildStateContent(context),
    );
  }

  Widget _buildStateContent(BuildContext context) {
    switch (_currentState) {
      case DataState.loading:
        return _buildLoadingState(context);

      case DataState.error:
        return _buildErrorState(context);

      case DataState.empty:
        return _buildExampleState(context);

      case DataState.populated:
        return _buildPopulatedState(context);
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    if (loadingWidget != null) return loadingWidget!;

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    if (errorWidget != null) return errorWidget!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: $error',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleState(BuildContext context) {
    if (exampleData.isEmpty) {
      return _buildTrueEmptyState(context);
    }

    return Semantics(
      label:
          'Preview examples - showing sample content to demonstrate features',
      child: Stack(
        children: [
          // Example content with interaction guard
          _InteractionGuard(
            onTap: onExampleTap,
            child: builder(context, exampleData, true),
          ),

          // Example badge
          if (showExampleBadge)
            Positioned(
              top: 8,
              right: 8,
              child: ExampleBadge(onTap: onExampleTap),
            ),
        ],
      ),
    );
  }

  Widget _buildPopulatedState(BuildContext context) {
    return builder(context, realData!, false);
  }

  Widget _buildTrueEmptyState(BuildContext context) {
    if (emptyWidget != null) return emptyWidget!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first item to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that guards interactions with example content
class _InteractionGuard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InteractionGuard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: GestureDetector(
        onTap: () {
          // Show info dialog about example content
          if (onTap != null) {
            onTap!.call();
          } else {
            _showExampleInfoDialog(context);
          }
        },
        child: child,
      ),
    );
  }

  void _showExampleInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: const Text('Example Content'),
        content: const Text(
          'This is preview content to show you how the app works. '
          'Create your own content to replace these examples.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
