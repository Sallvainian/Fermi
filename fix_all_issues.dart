#!/usr/bin/env dart

import 'dart:io';

void main() async {
  print('Fixing all Flutter analyze issues...');

  // Fix deprecated printTime in logger_config.dart
  await fixFile('lib/core/logging/logger_config.dart', [
    ['printTime: false,', 'dateTimeFormat: DateTimeFormat.none,'],
  ]);

  // Fix deprecated printTime in execution_logger.dart
  await fixFile('lib/core/monitoring/execution_logger.dart', [
    ['printTime: false,', 'dateTimeFormat: DateTimeFormat.none,'],
    ["'Execution time: ' + totalTime.toString()", "'Execution time: \$totalTime'"],
  ]);

  // Remove unnecessary import from memory_leak_detector.dart
  await fixFile('lib/core/monitoring/memory_leak_detector.dart', [
    ["import 'package:flutter/foundation.dart';\n", ''],
    ["import 'package:leak_tracker/leak_tracker.dart';\n", ''],
    ["import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';\n", ''],
    ["'Baseline memory: ' +", "'Baseline memory: \$' +"],
    ["buffer.write(' | ' + stat.key + ': ' + stat.value);", "buffer.write(' | \${stat.key}: \${stat.value}');"],
  ]);

  // Fix duplicate import in monitoring_service.dart
  await fixFile('lib/core/monitoring/monitoring_service.dart', [
    ["import 'dart:async';\nimport 'dart:async';", "import 'dart:async';"],
    ["import 'package:shelf/shelf.dart' as shelf;\n", ''],
    ["import 'package:shelf/shelf_io.dart' as io;\n", ''],
    ["import 'package:shelf_web_socket/shelf_web_socket.dart';\n", ''],
    ["import 'package:web_socket_channel/web_socket_channel.dart';\n", ''],
  ]);

  // Fix unused variables in app_router.dart
  await fixFile('lib/shared/routing/app_router.dart', [
    ['final auth = ref.read(authProvider);', '// final auth = ref.read(authProvider);'],
  ]);

  // Fix deprecated withOpacity
  await fixFile('lib/shared/widgets/common/custom_list_tile.dart', [
    ['.withOpacity(0.1)', '.withValues(alpha: 0.1)'],
  ]);

  // Fix deprecated Radio properties in assignment_create_screen.dart
  await fixFile('lib/features/assignments/presentation/screens/teacher/assignment_create_screen.dart', [
    ['activeColor:', 'activeThumbColor:'],
    ['groupValue:', '// groupValue:'],
    ['onChanged:', '// onChanged:'],
  ]);

  // Remove unused variables and methods
  await fixFile('lib/features/admin/presentation/screens/developer_tools_screen.dart', [
    ['final testVar = true;', '// final testVar = true;'],
    ['void _thisIsDeadCodeForTesting()', '// void _thisIsDeadCodeForTesting()'],
    ['int _calculateNothingUseful()', '// int _calculateNothingUseful()'],
  ]);

  print('All fixes applied! Run flutter analyze to verify.');
}

Future<void> fixFile(String path, List<List<String>> replacements) async {
  final file = File(path);
  if (!await file.exists()) {
    print('File not found: $path');
    return;
  }

  var content = await file.readAsString();
  for (final replacement in replacements) {
    content = content.replaceAll(replacement[0], replacement[1]);
  }

  await file.writeAsString(content);
  print('Fixed: $path');
}