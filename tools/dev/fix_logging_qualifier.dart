import 'dart:io';

/// Codemod: qualify bare `this.logInfo(`/`this.logError(` calls so they invoke the
/// extension methods defined on `Object` (or optionally convert to static
/// LoggerService calls).
///
/// Default replacements (style=this):
/// - `this.logInfo(`  -> `this.logInfo(` when not already qualified
/// - `this.logError(` -> `this.logError(` when not already qualified
///
/// Alternate (style=static):
/// - `this.logInfo(`  -> `LoggerService.info(`
/// - `this.logError(` -> `LoggerService.error(`
///
/// Skips files named `logger_service.dart` and generated/build artifacts.
///
/// Usage:
///   dart run tools/dev/fix_logging_qualifier.dart [--dry-run] [--style=this|static] [--dir=lib]
void main(List<String> args) {
  final opts = _Options.parse(args);
  final repoRoot = Directory.current;
  final dirArg = args.firstWhere(
    (a) => a.startsWith('--dir='),
    orElse: () => '--dir=lib',
  );
  final targetDir = dirArg.split('=').last;
  final root = Directory(targetDir).existsSync()
      ? Directory(targetDir)
      : Directory(repoRoot.path + Platform.pathSeparator + targetDir);

  final dartFiles = _listDartFiles(root);

  int filesChanged = 0;
  int totalReplacements = 0;
  int totalMatches = 0;

  for (final file in dartFiles) {
    final original = file.readAsStringSync();
    var updated = original;

    final matches = _findMatchesByLine(original);
    if (opts.dryRun) {
      if (matches.isNotEmpty) {
        stdout.writeln('Matches: ${_relPath(file.path, repoRoot.path)}');
        for (final m in matches) {
          stdout.writeln('  L${m.line}: ${m.preview}');
        }
      }
      totalMatches += matches.length;
      continue;
    }

    if (opts.style == FixStyle.thisQualifier) {
      // Replace bare logInfo/logError not preceded by '.'
      updated = updated.replaceAllMapped(
        RegExp(r'(?<!\.)\blogInfo\s*\('),
        (m) => 'this.logInfo(',
      );
      updated = updated.replaceAllMapped(
        RegExp(r'(?<!\.)\blogError\s*\('),
        (m) => 'this.logError(',
      );
    } else {
      updated = updated.replaceAllMapped(
        RegExp(r'(?<!\.)\blogInfo\s*\('),
        (m) => 'LoggerService.info(',
      );
      updated = updated.replaceAllMapped(
        RegExp(r'(?<!\.)\blogError\s*\('),
        (m) => 'LoggerService.error(',
      );
    }

    if (updated != original) {
      file.writeAsStringSync(updated);
      filesChanged += 1;
      final infoBefore = _countMatches(original, RegExp(r'\blogInfo\s*\('));
      final errorBefore = _countMatches(original, RegExp(r'\blogError\s*\('));
      final infoAfter = _countMatches(updated, RegExp(r'\bthis\.logInfo\s*\(|\bLoggerService\.info\s*\('));
      final errorAfter = _countMatches(updated, RegExp(r'\bthis\.logError\s*\(|\bLoggerService\.error\s*\('));
      totalReplacements += (infoAfter - infoBefore).clamp(0, 1 << 30) +
          (errorAfter - errorBefore).clamp(0, 1 << 30);
      stdout.writeln('Updated: ${_relPath(file.path, repoRoot.path)}');
    }
  }

  if (opts.dryRun) {
    stdout.writeln('Dry run complete. Total matches: $totalMatches');
  } else {
    stdout.writeln('Done. Files changed: $filesChanged, total replacements: $totalReplacements');
  }
}

Iterable<File> _listDartFiles(Directory root) sync* {
  final skipDirs = {
    '.git', '.dart_tool', 'build', '.idea', '.vscode', '.fleet', 'ios', 'android', 'tools'
  };
  final queue = <Directory>[root];
  while (queue.isNotEmpty) {
    final dir = queue.removeLast();
    for (final entity in dir.listSync(followLinks: false)) {
      final path = entity.path.replaceAll('\\', '/');
      if (entity is Directory) {
        final name = path.split('/').last;
        if (skipDirs.contains(name)) continue;
        queue.add(entity);
      } else if (entity is File) {
        final name = path.split('/').last;
        if (name == 'fix_logging_qualifier.dart') continue; // skip self
        if (path.endsWith('.dart') && !path.endsWith('logger_service.dart')) {
          yield entity;
        }
      }
    }
  }
}

class _MatchInfo {
  final int line;
  final String preview;
  _MatchInfo(this.line, this.preview);
}

List<_MatchInfo> _findMatchesByLine(String content) {
  final callRe = RegExp(r'(?<!\.)\blog(?:Info|Error)\s*\(');
  final lines = content.split(RegExp(r'\r?\n'));
  final out = <_MatchInfo>[];
  bool inBlock = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    var codeSlice = line;
    if (inBlock) {
      final end = codeSlice.indexOf('*/');
      if (end >= 0) {
        inBlock = false;
        codeSlice = codeSlice.substring(end + 2);
      } else {
        // still in block comment, skip line
        continue;
      }
    }
    final blockIdx = codeSlice.indexOf('/*');
    final lineIdx = codeSlice.indexOf('//');
    var endOfCode = codeSlice.length;
    if (blockIdx >= 0 && (lineIdx == -1 || blockIdx < lineIdx)) {
      endOfCode = blockIdx;
      inBlock = true;
    } else if (lineIdx >= 0) {
      endOfCode = lineIdx;
    }
    final toScan = codeSlice.substring(0, endOfCode);
    if (callRe.hasMatch(toScan)) {
      final preview = line.trim();
      out.add(_MatchInfo(i + 1, preview.length > 140 ? preview.substring(0, 140) : preview));
    }
  }
  return out;
}

int _countMatches(String s, RegExp re) => re.allMatches(s).length;

String _relPath(String full, String root) {
  final normFull = full.replaceAll('\\', '/');
  final normRoot = root.replaceAll('\\', '/');
  if (normFull.startsWith(normRoot)) {
    return normFull.substring(normRoot.length + (normRoot.endsWith('/') ? 0 : 1));
  }
  return full;
}

class _Options {
  final bool dryRun;
  final FixStyle style;
  _Options({required this.dryRun, required this.style});

  static _Options parse(List<String> args) {
    var dry = false;
    var style = FixStyle.thisQualifier;
    for (final a in args) {
      if (a == '--dry-run') dry = true;
      if (a.startsWith('--style=')) {
        final v = a.split('=').last.trim();
        if (v == 'static') style = FixStyle.staticLogger;
        else style = FixStyle.thisQualifier;
      }
    }
    return _Options(dryRun: dry, style: style);
  }
}

enum FixStyle { thisQualifier, staticLogger }
