import 'dart:convert';
import 'dart:io';

/// Generates a Markdown dependency map from Dart import statements.
///
/// - Scans `lib/` recursively
/// - Maps internal imports (relative/lib/ and package:<pkg>/) to edges
/// - Summarizes hubs (outgoing) and widely-used (incoming)
///
/// Usage:
///   dart run tools/dev/generate_dependency_map.dart --output docs/developer/architecture/code-dependency-map.md
///   dart run tools/dev/generate_dependency_map.dart > CODEMAP.md
void main(List<String> args) async {
  final outArgIndex = args.indexOf('--output');
  final outputPath = outArgIndex >= 0 && outArgIndex + 1 < args.length
      ? args[outArgIndex + 1]
      : null;

  final packageName = Platform.environment['PACKAGE_NAME'] ?? 'fermi_plus';
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ directory not found');
    exit(1);
  }

  final files = <String>[];
  await for (final ent in libDir.list(recursive: true, followLinks: false)) {
    if (ent is File && ent.path.endsWith('.dart')) {
      files.add(ent.path);
    }
  }

  final importRe = RegExp(r"^import\s+'([^']+)';");
  final Map<String, Set<String>> edges = {};

  for (final path in files) {
    final lines = await File(path).readAsLines(encoding: utf8);
    for (final raw in lines) {
      final line = raw.trim();
      final m = importRe.firstMatch(line);
      if (m == null) continue;
      final spec = m.group(1)!;

      String? dest;
      if (spec.startsWith('package:$packageName/')) {
        dest = 'lib/${spec.substring('package:$packageName/'.length)}';
      } else if (spec.startsWith('package:')) {
        // external package – skip
        dest = null;
      } else if (spec.startsWith('dart:')) {
        dest = null;
      } else if (spec.startsWith('../') ||
          spec.startsWith('./') ||
          spec.startsWith('lib/') ||
          spec.startsWith('/')) {
        final base = File(path).parent.path;
        dest = File('$base/$spec').uri.normalizePath().toFilePath();
        // Normalize to project-relative
        if (dest.startsWith(Directory.current.path)) {
          dest = dest.substring(Directory.current.path.length + 1);
        }
      }
      if (dest != null && dest.endsWith('.dart') && dest.startsWith('lib/') &&
          File(dest).existsSync()) {
        edges.putIfAbsent(path, () => <String>{}).add(dest);
      }
    }
  }

  // Incoming counts
  final incoming = <String, int>{};
  for (final outs in edges.values) {
    for (final dst in outs) {
      incoming[dst] = (incoming[dst] ?? 0) + 1;
    }
  }

  String groupOf(String f) {
    final parts = f.split('/');
    if (parts.length > 2 && parts[0] == 'lib' &&
        (parts[1] == 'features' || parts[1] == 'shared')) {
      return parts.sublist(0, 3).join('/');
    }
    if (parts.length > 1 && parts[0] == 'lib') {
      return parts.sublist(0, 2).join('/');
    }
    return 'lib';
  }

  final groups = <String, Set<String>>{};
  for (final f in files) {
    groups.putIfAbsent(groupOf(f), () => <String>{}).add(f);
  }

  String mdEscape(String s) => s.replaceAll('_', '\\_');

  final buf = StringBuffer();
  buf.writeln('# Code Dependency Map');
  buf.writeln();
  buf.writeln('This document maps internal Dart file dependencies derived from import statements. '
      'External packages (package:*) are omitted. Package imports (package:$packageName/…) were mapped to `lib/` paths.');
  buf.writeln();
  buf.writeln('## Summary');
  buf.writeln('- Files scanned: ${files.length}');
  buf.writeln('- Internal nodes (with internal deps): ${edges.length}');
  buf.writeln('- Internal edges: ${edges.values.fold<int>(0, (a, b) => a + b.length)}');
  buf.writeln();
  buf.writeln('Top-level groups (folder → file count):');
  for (final entry in groups.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    buf.writeln('- ${entry.key} (${entry.value.length})');
  }
  buf.writeln();

  List<MapEntry<String, Set<String>>> sortOut(List<MapEntry<String, Set<String>>> l) {
    l.sort((a, b) => b.value.length.compareTo(a.value.length));
    return l;
  }
  final topOut = sortOut(edges.entries.toList()).take(20).toList();
  final topIn = incoming.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  buf.writeln('## Top Outgoing Dependencies (hubs)');
  for (final e in topOut) {
    if (e.value.isEmpty) continue;
    buf.writeln('- ${e.key} → ${e.value.length} internal imports');
  }
  buf.writeln();
  buf.writeln('## Top Incoming References (widely used)');
  for (final e in topIn.take(20)) {
    if (e.value == 0) continue;
    buf.writeln('- ${e.key} ← referenced by ${e.value} files');
  }
  buf.writeln();

  buf.writeln('## Notes & Limitations');
  buf.writeln('- Import-based only: dynamic wiring, reflection, and runtime provider lookups are not captured.');
  buf.writeln('- Use this as a starting point for impact analysis; confirm with code navigation/tests.');
  buf.writeln();

  if (outputPath != null) {
    File(outputPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(buf.toString());
  } else {
    stdout.write(buf.toString());
  }
}
