import 'dart:io';

void main() async {
  final log = <String>[];
  log.add('Fixing withValues(alpha:) to use 0.0-1.0 range instead of 0-255...');
  
  // Map of incorrect integer values to correct decimal values
  final alphaConversions = {
    'alpha: 26': 'alpha: 0.1',   // 26/255 ≈ 0.1
    'alpha: 38': 'alpha: 0.15',  // 38/255 ≈ 0.15
    'alpha: 51': 'alpha: 0.2',   // 51/255 ≈ 0.2
    'alpha: 77': 'alpha: 0.3',   // 77/255 ≈ 0.3
    'alpha: 102': 'alpha: 0.4',  // 102/255 ≈ 0.4
    'alpha: 128': 'alpha: 0.5',  // 128/255 ≈ 0.5
    'alpha: 153': 'alpha: 0.6',  // 153/255 ≈ 0.6
    'alpha: 179': 'alpha: 0.7',  // 179/255 ≈ 0.7
    'alpha: 204': 'alpha: 0.8',  // 204/255 ≈ 0.8
    'alpha: 230': 'alpha: 0.9',  // 230/255 ≈ 0.9
  };
  
  // Find all Dart files
  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.dart'))
      .cast<File>()
      .toList();
  
  int totalFixed = 0;
  final filesFixed = <String>[];
  
  for (final file in dartFiles) {
    String content = await file.readAsString();
    final originalContent = content;
    int fileFixCount = 0;
    
    // Fix each alpha value
    for (final entry in alphaConversions.entries) {
      final regex = RegExp(r'\.withValues\(' + RegExp.escape(entry.key) + r'([,)])', multiLine: true);
      if (regex.hasMatch(content)) {
        content = content.replaceAllMapped(regex, (match) {
          fileFixCount++;
          return '.withValues(${entry.value}${match.group(1)}';
        });
      }
    }
    
    if (content != originalContent) {
      await file.writeAsString(content);
      filesFixed.add(file.path);
      totalFixed += fileFixCount;
      log.add('Fixed $fileFixCount occurrences in ${file.path}');
    }
  }
  
  log.add('\n✅ Fixed $totalFixed alpha values in ${filesFixed.length} files');
  log.add('\nConverted from 0-255 range to 0.0-1.0 range as required by Flutter 3.24+ API');
  
  for (final line in log) {
    stdout.writeln(line);
  }
}