import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:fermi_plus/firebase_options.dart';
import 'package:fermi_plus/shared/routing/app_router.dart';
import 'package:fermi_plus/core/logging/logger_config.dart';

// Import providers
import 'package:fermi_plus/features/auth/presentation/providers/auth_provider.dart';
import 'package:fermi_plus/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:fermi_plus/features/classes/presentation/providers/class_provider.dart';
import 'package:fermi_plus/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:fermi_plus/features/behavior_points/presentation/providers/behavior_point_provider.dart';
import 'package:fermi_plus/features/admin/presentation/providers/admin_provider.dart';
// import 'package:fermi_plus/features/parent/presentation/providers/parent_provider.dart'; // Does not exist
// import 'package:fermi_plus/features/teacher/presentation/providers/teacher_provider.dart'; // Does not exist

/// Debug version of main.dart with leak tracking and logging enabled
///
/// This version includes:
/// - Memory leak detection
/// - Comprehensive logging
/// - Performance monitoring
/// - Dead code tracking
///
/// Use this for development and debugging.
/// Run with: flutter run --target lib/main_debug.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging with debug mode
  initializeLogging(isProduction: false);
  final logger = getLogger('main_debug');
  logger.info('Starting Fermi Plus in DEBUG mode with leak tracking');

  // Initialize leak tracking
  if (kDebugMode) {
    logger.info('Enabling leak tracking...');
    LeakTracking.start();
    LeakTracking.phase = const PhaseSettings(
      ignoredLeaks: IgnoredLeaks(
        // Add any known leaks to ignore here temporarily
        // Example: classes: ['SomeWidget'],
      ),
    );
  }

  // Initialize Firebase
  try {
    logger.info('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.info('Firebase initialized successfully');
  } catch (e, stack) {
    logger.severe('Failed to initialize Firebase', e, stack);
  }

  // Track app launch
  markDeadCode('main', 'app_launch');

  runApp(const FermiPlusDebugApp());
}

class FermiPlusDebugApp extends StatefulWidget {
  const FermiPlusDebugApp({super.key});

  @override
  State<FermiPlusDebugApp> createState() => _FermiPlusDebugAppState();
}

class _FermiPlusDebugAppState extends State<FermiPlusDebugApp> {
  final logger = getLogger('app');

  @override
  void initState() {
    super.initState();
    logger.info('FermiPlusDebugApp initialized');

    // Set up leak tracking callbacks
    if (kDebugMode) {
      LeakTracking.collectedLeaks.stream.listen((leaks) {
        for (final leak in leaks) {
          logger.warning('Memory leak detected: ${leak.type} - ${leak.context}');
        }
      });
    }
  }

  @override
  void dispose() {
    // Log disposal for leak tracking
    logger.info('FermiPlusDebugApp disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating AuthProvider');
          markDeadCode('providers', 'AuthProvider');
          return AuthProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating DashboardProvider');
          markDeadCode('providers', 'DashboardProvider');
          return DashboardProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating ClassProvider');
          markDeadCode('providers', 'ClassProvider');
          return ClassProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating AssignmentProvider');
          markDeadCode('providers', 'AssignmentProvider');
          return AssignmentProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating GradeProvider');
          markDeadCode('providers', 'GradeProvider');
          return GradeProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating ChatProviderSimple');
          markDeadCode('providers', 'ChatProviderSimple');
          return ChatProviderSimple();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating CalendarProvider');
          markDeadCode('providers', 'CalendarProvider');
          return CalendarProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating BehaviorPointProvider');
          markDeadCode('providers', 'BehaviorPointProvider');
          return BehaviorPointProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating AdminProvider');
          markDeadCode('providers', 'AdminProvider');
          return AdminProvider();
        }),
        // Commented out - ParentProvider doesn't exist
        // ChangeNotifierProvider(create: (_) {
        //   logger.info('Creating ParentProvider');
        //   markDeadCode('providers', 'ParentProvider');
        //   return ParentProvider();
        // }),
        // Commented out - TeacherProvider doesn't exist
        // ChangeNotifierProvider(create: (_) {
        //   logger.info('Creating TeacherProvider');
        //   markDeadCode('providers', 'TeacherProvider');
        //   return TeacherProvider();
        // }),
        ChangeNotifierProvider(create: (_) {
          logger.info('Creating StudentProviderSimple');
          markDeadCode('providers', 'StudentProviderSimple');
          return StudentProviderSimple();
        }),
      ],
      child: Builder(
        builder: (context) {
          stopwatch.stop();
          logPerformance('app_initialization', stopwatch.elapsedMilliseconds);
          logger.info('App initialized in ${stopwatch.elapsedMilliseconds}ms');

          return MaterialApp.router(
            title: 'Fermi Plus (Debug)',
            debugShowCheckedModeBanner: true,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF8B5CF6),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF8B5CF6),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: ThemeMode.system,
            routerConfig: AppRouter.router,
            builder: (context, child) {
              if (kDebugMode) {
                // Wrap with debug overlay
                return Stack(
                  children: [
                    child!,
                    // Debug overlay showing memory usage
                    Positioned(
                      top: 40,
                      right: 10,
                      child: _DebugOverlay(),
                    ),
                  ],
                );
              }
              return child!;
            },
          );
        },
      ),
    );
  }
}

/// Debug overlay widget showing memory and performance stats
class _DebugOverlay extends StatefulWidget {
  @override
  _DebugOverlayState createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<_DebugOverlay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isExpanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🐛 Debug Info',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leaks: ${LeakTracking.phase.leakCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Features Used: ${getUsageStats().length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Generate usage report
                      final stats = getUsageStats();
                      final perfStats = getPerformanceStats();
                      debugPrint('=== Feature Usage Stats ===');
                      stats.forEach((feature, count) {
                        debugPrint('$feature: $count calls');
                      });
                      debugPrint('=== Performance Stats ===');
                      perfStats.forEach((op, stats) {
                        debugPrint('$op: $stats');
                      });
                    },
                    child: const Text('Dump Stats'),
                  ),
                ],
              )
            : const Icon(
                Icons.bug_report,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }
}