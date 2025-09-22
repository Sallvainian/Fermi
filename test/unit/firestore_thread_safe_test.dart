import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fermi_plus/shared/utils/firestore_thread_safe.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  group('FirestoreThreadSafe', () {
    setUp(() {
      // Reset metrics before each test
      FirestoreThreadSafe.resetMetrics();
    });

    testWidgets('should execute callbacks with Future.microtask', (
      tester,
    ) async {
      final executionOrder = <String>[];

      // Build a simple widget
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Simulate a callback that would come from Firestore
              FirestoreThreadSafe.runOnPlatformThread(() {
                executionOrder.add('callback');
              });

              executionOrder.add('build');
              return Container();
            },
          ),
        ),
      );

      // Let microtasks run
      await tester.pump();

      // Callback should execute after build completes
      expect(executionOrder, ['build', 'callback']);
    });

    testWidgets('should handle priority scheduling', (tester) async {
      final executionOrder = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Schedule callbacks with different priorities
              FirestoreThreadSafe.runOnPlatformThread(
                () => executionOrder.add('low'),
                priority: CallbackPriority.low,
              );

              FirestoreThreadSafe.runOnPlatformThread(
                () => executionOrder.add('critical'),
                priority: CallbackPriority.critical,
              );

              FirestoreThreadSafe.runOnPlatformThread(
                () => executionOrder.add('normal'),
                priority: CallbackPriority.normal,
              );

              FirestoreThreadSafe.runOnPlatformThread(
                () => executionOrder.add('high'),
                priority: CallbackPriority.high,
              );

              return Container();
            },
          ),
        ),
      );

      // Let all callbacks execute
      await tester.pump();

      // Should execute in priority order: critical, high, normal, low
      expect(executionOrder, ['critical', 'high', 'normal', 'low']);
    });

    test('should deduplicate callbacks within time window', () {
      fakeAsync((async) {
        int callbackCount = 0;
        int callback() => callbackCount++;

        // Schedule same callback multiple times quickly
        for (int i = 0; i < 5; i++) {
          FirestoreThreadSafe.runOnPlatformThread(
            callback,
            priority: CallbackPriority.normal,
          );
        }

        // Let callbacks execute
        async.flushMicrotasks();

        // Without deduplication key, all should execute
        expect(callbackCount, 5);

        // Reset for deduplication test
        callbackCount = 0;

        // Schedule with same deduplication key
        for (int i = 0; i < 5; i++) {
          FirestoreThreadSafe.executeWithPriority(
            callback,
            priority: CallbackPriority.normal,
            deduplicationKey: 'test_key',
          );
        }

        // Let callbacks execute
        async.flushMicrotasks();

        // With deduplication, only first should execute
        expect(callbackCount, 1);

        // After time window, should execute again
        async.elapse(const Duration(milliseconds: 20));
        FirestoreThreadSafe.executeWithPriority(
          callback,
          priority: CallbackPriority.normal,
          deduplicationKey: 'test_key',
        );
        async.flushMicrotasks();
        expect(callbackCount, 2);
      });
    });

    test('should track metrics correctly', () {
      fakeAsync((async) {
        // Execute some callbacks
        for (int i = 0; i < 10; i++) {
          FirestoreThreadSafe.runOnPlatformThread(() {});
        }

        // Execute some with deduplication
        for (int i = 0; i < 5; i++) {
          FirestoreThreadSafe.executeWithPriority(
            () {},
            priority: CallbackPriority.normal,
            deduplicationKey: 'dup_test',
          );
        }

        async.flushMicrotasks();

        final metrics = FirestoreThreadSafe.getMetrics();

        // Should have tracked all attempts
        expect(metrics.totalCallbacks, 14); // 10 + 4 deduped
        expect(metrics.dedupedCallbacks, 4); // 4 duplicates skipped
        expect(metrics.currentQueueDepth, 0); // All processed
      });
    });

    testWidgets('should handle safeNotify for ChangeNotifier', (tester) async {
      int notificationCount = 0;

      final notifier = TestNotifier();
      notifier.addListener(() => notificationCount++);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Simulate notification during build
              FirestoreThreadSafe.safeNotify(() => notifier.notify());
              return Container();
            },
          ),
        ),
      );

      // Initially no notifications
      expect(notificationCount, 0);

      // After pump, notification should be delivered
      await tester.pump();
      expect(notificationCount, 1);
    });

    test('should handle error callbacks with high priority', () {
      fakeAsync((async) {
        final executionOrder = <String>[];

        FirestoreThreadSafe.runOnPlatformThread(
          () => executionOrder.add('normal'),
          priority: CallbackPriority.normal,
        );

        // Error callback should get high priority automatically
        FirestoreThreadSafe.executeWithPriority(
          () => executionOrder.add('error'),
          priority: CallbackPriority.high,
          deduplicationKey: 'error_test',
        );

        FirestoreThreadSafe.runOnPlatformThread(
          () => executionOrder.add('low'),
          priority: CallbackPriority.low,
        );

        async.flushMicrotasks();

        // Error should execute before low priority
        expect(executionOrder, ['error', 'normal', 'low']);
      });
    });

    test('should clean up old deduplication entries', () {
      fakeAsync((async) {
        // Add many deduplication entries
        for (int i = 0; i < 150; i++) {
          FirestoreThreadSafe.executeWithPriority(
            () {},
            priority: CallbackPriority.normal,
            deduplicationKey: 'key_$i',
          );
        }

        async.flushMicrotasks();

        // Old entries should be cleaned up when limit exceeded
        // This is internal behavior, but we can verify metrics
        final metrics = FirestoreThreadSafe.getMetrics();
        expect(metrics.totalCallbacks, 150);
      });
    });

    test('should calculate deduplication rate correctly', () {
      fakeAsync((async) {
        // Execute 100 callbacks
        for (int i = 0; i < 100; i++) {
          FirestoreThreadSafe.runOnPlatformThread(() {});
        }

        // Try to execute 50 duplicates
        for (int i = 0; i < 50; i++) {
          for (int j = 0; j < 2; j++) {
            FirestoreThreadSafe.executeWithPriority(
              () {},
              priority: CallbackPriority.normal,
              deduplicationKey: 'dup_$i',
            );
          }
        }

        async.flushMicrotasks();

        final metrics = FirestoreThreadSafe.getMetrics();

        // Should have 100 + 100 total attempts
        expect(metrics.totalCallbacks, 200);
        // Should have deduped 50
        expect(metrics.dedupedCallbacks, 50);
        // Rate should be 25%
        expect(double.parse(metrics.deduplicationRate), 25.0);
      });
    });

    test('should track max queue depth', () {
      fakeAsync((async) {
        // Schedule many callbacks at once
        for (int i = 0; i < 50; i++) {
          FirestoreThreadSafe.runOnPlatformThread(() {});
        }

        // Check max queue depth before processing
        var metrics = FirestoreThreadSafe.getMetrics();
        expect(metrics.maxQueueDepth, greaterThan(0));

        // Process all
        async.flushMicrotasks();

        // Queue should be empty but max depth remembered
        metrics = FirestoreThreadSafe.getMetrics();
        expect(metrics.currentQueueDepth, 0);
        expect(metrics.maxQueueDepth, greaterThan(0));
      });
    });

    test('should reset metrics correctly', () {
      fakeAsync((async) {
        // Execute some callbacks
        for (int i = 0; i < 10; i++) {
          FirestoreThreadSafe.runOnPlatformThread(() {});
        }

        async.flushMicrotasks();

        var metrics = FirestoreThreadSafe.getMetrics();
        expect(metrics.totalCallbacks, 10);

        // Reset metrics
        FirestoreThreadSafe.resetMetrics();

        metrics = FirestoreThreadSafe.getMetrics();
        expect(metrics.totalCallbacks, 0);
        expect(metrics.dedupedCallbacks, 0);
        expect(metrics.currentQueueDepth, 0);
        expect(metrics.maxQueueDepth, 0);
      });
    });
  });
}

// Test helper class
class TestNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
