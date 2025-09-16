import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/admin_provider.dart';
import '../../constants/bulk_import_constants.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  String _importType = BulkImportConstants.studentImportType;
  String _fileFormat = BulkImportConstants.csvFormat;
  Uint8List? _fileBytes;
  String? _fileName;
  List<Map<String, dynamic>> _parsedData = [];
  List<String> _headers = [];
  final Map<int, String> _validationErrors = {};
  bool _isProcessing = false;
  double _importProgress = 0.0;
  String _progressMessage = '';
  final List<String> _importErrors = [];
  final List<String> _importSuccesses = [];

  final List<String> _studentRequiredFields = BulkImportConstants.studentRequiredFields;
  final List<String> _teacherRequiredFields = BulkImportConstants.teacherRequiredFields;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Account Import'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _isProcessing
          ? _buildProgressView(colorScheme)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImportOptions(colorScheme),
                  const SizedBox(height: 24),
                  _buildFileUploadSection(colorScheme),
                  if (_parsedData.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildDataPreview(colorScheme),
                    const SizedBox(height: 24),
                    _buildImportActions(colorScheme),
                  ],
                  if (_importErrors.isNotEmpty || _importSuccesses.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildImportResults(colorScheme),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildImportOptions(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Configuration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Account Type'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: BulkImportConstants.studentImportType,
                            label: Text('Students'),
                            icon: Icon(Icons.school),
                          ),
                          ButtonSegment(
                            value: BulkImportConstants.teacherImportType,
                            label: Text('Teachers'),
                            icon: Icon(Icons.person),
                          ),
                        ],
                        selected: {_importType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _importType = newSelection.first;
                            _parsedData.clear();
                            _headers.clear();
                            _validationErrors.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('File Format'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: BulkImportConstants.csvFormat,
                            label: Text('CSV'),
                            icon: Icon(Icons.table_chart),
                          ),
                          ButtonSegment(
                            value: BulkImportConstants.jsonFormat,
                            label: Text('JSON'),
                            icon: Icon(Icons.code),
                          ),
                        ],
                        selected: {_fileFormat},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _fileFormat = newSelection.first;
                            _parsedData.clear();
                            _headers.clear();
                            _validationErrors.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTemplateSection(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Required Fields',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _importType == BulkImportConstants.studentImportType
                ? 'Students: ${_studentRequiredFields.join(', ')}\nOptional: ${BulkImportConstants.studentOptionalFields.join(', ')} (comma-separated)'
                : 'Teachers: ${_teacherRequiredFields.join(', ')}\nOptional: ${BulkImportConstants.teacherOptionalFields.join(', ')}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download, size: 16),
            label: Text('Download ${_fileFormat.toUpperCase()} Template'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadSection(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Upload',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outline,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(8),
                color: colorScheme.surfaceContainerHighest.withValues(alpha:0.1),
              ),
              child: InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(6),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fileName ?? 'Click to upload ${_fileFormat.toUpperCase()} file',
                        style: TextStyle(
                          fontSize: 16,
                          color: _fileName != null 
                              ? colorScheme.onSurface 
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_fileName != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _clearFile,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPreview(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data Preview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Chip(
                  label: Text('${_parsedData.length} records'),
                  backgroundColor: colorScheme.primaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _headers.map((header) => DataColumn(
                    label: Text(
                      header,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )).toList(),
                  rows: _parsedData.take(10).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    final hasError = _validationErrors.containsKey(index);
                    
                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (hasError) {
                          return colorScheme.errorContainer.withValues(alpha:0.2);
                        }
                        return null;
                      }),
                      cells: _headers.map((header) {
                        final value = row[header]?.toString() ?? '';
                        return DataCell(
                          Row(
                            children: [
                              if (hasError && _isRequiredField(header))
                                const Icon(Icons.error, size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_parsedData.length > 10) ...[
              const SizedBox(height: 8),
              Text(
                'Showing first 10 of ${_parsedData.length} records',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_validationErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Text(
                          'Validation Errors (${_validationErrors.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._validationErrors.entries.take(5).map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Row ${entry.key + 1}: ${entry.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                    if (_validationErrors.length > 5)
                      Text(
                        '... and ${_validationErrors.length - 5} more',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImportActions(ColorScheme colorScheme) {
    final hasValidData = _parsedData.isNotEmpty && _validationErrors.isEmpty;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_validationErrors.isNotEmpty)
              TextButton.icon(
                onPressed: _fixValidationErrors,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Fix Errors'),
              ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _clearFile,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: hasValidData ? _startImport : null,
              icon: const Icon(Icons.upload),
              label: Text('Import ${_parsedData.length} Accounts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressView(ColorScheme colorScheme) {
    return Center(
      child: Card(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _progressMessage,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _importProgress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_importProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportResults(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Results',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (_importSuccesses.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Successfully Imported (${_importSuccesses.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._importSuccesses.take(10).map((success) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(success, style: const TextStyle(fontSize: 12)),
                    )),
                    if (_importSuccesses.length > 10)
                      Text(
                        '... and ${_importSuccesses.length - 10} more',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_importErrors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, size: 16, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Text(
                          'Failed Imports (${_importErrors.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._importErrors.take(10).map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(error, style: const TextStyle(fontSize: 12)),
                    )),
                    if (_importErrors.length > 10)
                      Text(
                        '... and ${_importErrors.length - 10} more',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [_fileFormat],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileBytes = result.files.single.bytes;
          _fileName = result.files.single.name;
          _importErrors.clear();
          _importSuccesses.clear();
        });
        _parseFile();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  void _parseFile() {
    if (_fileBytes == null) return;

    setState(() {
      _parsedData.clear();
      _headers.clear();
      _validationErrors.clear();
    });

    try {
      if (_fileFormat == BulkImportConstants.csvFormat) {
        _parseCSV();
      } else {
        _parseJSON();
      }
      _validateData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing file: $e')),
      );
    }
  }

  void _parseCSV() {
    final csvString = utf8.decode(_fileBytes!);
    final List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);
    
    if (csvData.isEmpty) return;
    
    _headers = csvData[0].map((e) => e.toString()).toList();
    
    for (int i = 1; i < csvData.length; i++) {
      final Map<String, dynamic> row = {};
      for (int j = 0; j < _headers.length && j < csvData[i].length; j++) {
        row[_headers[j]] = csvData[i][j];
      }
      _parsedData.add(row);
    }
  }

  void _parseJSON() {
    final jsonString = utf8.decode(_fileBytes!);
    final jsonData = json.decode(jsonString);
    
    if (jsonData is List && jsonData.isNotEmpty) {
      _parsedData = jsonData.cast<Map<String, dynamic>>();
      _headers = _parsedData[0].keys.toList();
    }
  }

  void _validateData() {
    final requiredFields = _importType == 'student'
        ? _studentRequiredFields
        : _teacherRequiredFields;

    for (int i = 0; i < _parsedData.length; i++) {
      final row = _parsedData[i];
      final List<String> errors = [];

      for (final field in requiredFields) {
        if (row[field] == null || row[field].toString().trim().isEmpty) {
          errors.add('Missing required field: $field');
        }
      }

      if (_importType == BulkImportConstants.teacherImportType) {
        final email = row['email']?.toString() ?? '';
        if (email.isNotEmpty && !_isValidEmail(email)) {
          errors.add('Invalid email format');
        }

        final password = row['password']?.toString() ?? '';
        if (password.isNotEmpty && password.length < 6) {
          errors.add('Password must be at least 6 characters');
        }
      }

      if (_importType == BulkImportConstants.studentImportType) {
        final email = row['email']?.toString() ?? '';
        if (email.isNotEmpty) {
          if (!_isValidEmail(email)) {
            errors.add('Invalid email format');
          } else if (!email.toLowerCase().endsWith('@rosellestudent.com') &&
                     !email.toLowerCase().endsWith('@rosellestudent.org')) {
            errors.add('Email must be from @rosellestudent.com or @rosellestudent.org domain');
          }
        }

        final gradeLevel = row['gradeLevel'];
        if (gradeLevel != null) {
          final grade = int.tryParse(gradeLevel.toString());
          if (grade == null || grade < 1 || grade > 12) {
            errors.add('Grade level must be between 1-12');
          }
        }
      }

      if (errors.isNotEmpty) {
        _validationErrors[i] = errors.join(', ');
      }
    }

    setState(() {});
  }

  bool _isValidEmail(String email) {
    return BulkImportConstants.emailPattern.hasMatch(email);
  }

  bool _isValidUsername(String username) {
    return BulkImportConstants.usernamePattern.hasMatch(username);
  }

  bool _isRequiredField(String field) {
    final requiredFields = _importType == 'student' 
        ? _studentRequiredFields 
        : _teacherRequiredFields;
    return requiredFields.contains(field);
  }

  void _fixValidationErrors() {
    for (final index in _validationErrors.keys) {
      final row = _parsedData[index];

      if (_importType == 'student') {
        // Auto-generate email from display name if missing
        if (row['email'] == null || row['email'].toString().isEmpty) {
          final displayName = row['displayName']?.toString() ?? '';
          if (displayName.isNotEmpty) {
            final emailBase = displayName.toLowerCase()
                .replaceAll(' ', '.')
                .replaceAll(RegExp(r'[^a-z0-9.]'), '');
            row['email'] = '$emailBase@rosellestudent.com';
          }
        }
      }

      if (_importType == 'teacher' && (row['password'] == null || row['password'].toString().isEmpty)) {
        row['password'] = BulkImportConstants.defaultTeacherPassword;
      }
    }

    _validateData();
  }

  void _clearFile() {
    setState(() {
      _fileBytes = null;
      _fileName = null;
      _parsedData.clear();
      _headers.clear();
      _validationErrors.clear();
      _importErrors.clear();
      _importSuccesses.clear();
    });
  }

  Future<void> _downloadTemplate() async {
    String content;
    String fileName;

    if (_fileFormat == BulkImportConstants.csvFormat) {
      if (_importType == BulkImportConstants.studentImportType) {
        content = '${BulkImportConstants.studentCsvHeader}\n';
        content += 'johndoe@rosellestudent.com,John Doe,10,parent@example.com,"math101,science201",false\n';
        content += 'janesmith@rosellestudent.com,Jane Smith,11,parent2@example.com,english301,false\n';
        content += 'fcottone@rosellestudent.com,Frank Cottone,12,,"physics401,calculus501",true\n';
      } else {
        content = '${BulkImportConstants.teacherCsvHeader}\n';
        content += 'teacher1@school.edu,Mr. Smith,"Math,Science",SecurePass123!\n';
        content += 'teacher2@school.edu,Ms. Johnson,English,SecurePass456!\n';
      }
      fileName = '${_importType}_import_template.csv';
    } else {
      final List<Map<String, dynamic>> jsonData = [];
      if (_importType == BulkImportConstants.studentImportType) {
        jsonData.add({
          'email': 'johndoe@rosellestudent.com',
          'displayName': 'John Doe',
          'gradeLevel': 10,
          'parentEmail': 'parent@example.com',
          'classIds': ['math101', 'science201'],
          'isGoogleAuth': false,
        });
        jsonData.add({
          'email': 'janesmith@rosellestudent.com',
          'displayName': 'Jane Smith',
          'gradeLevel': 11,
          'parentEmail': 'parent2@example.com',
          'classIds': ['english301'],
          'isGoogleAuth': false,
        });
        jsonData.add({
          'email': 'fcottone@rosellestudent.com',
          'displayName': 'Frank Cottone',
          'gradeLevel': 12,
          'parentEmail': '',
          'classIds': ['physics401', 'calculus501'],
          'isGoogleAuth': true,
        });
      } else {
        jsonData.add({
          'email': 'teacher1@school.edu',
          'displayName': 'Mr. Smith',
          'subjects': ['Math', 'Science'],
          'password': 'SecurePass123!',
        });
        jsonData.add({
          'email': 'teacher2@school.edu',
          'displayName': 'Ms. Johnson',
          'subjects': ['English'],
          'password': 'SecurePass456!',
        });
      }
      content = const JsonEncoder.withIndent('  ').convert(jsonData);
      fileName = '${_importType}_import_template.json';
    }
    
    final bytes = utf8.encode(content);
    final blob = Uint8List.fromList(bytes);
    
    try {
      await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: blob,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template downloaded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading template: $e')),
      );
    }
  }

  Future<void> _startImport() async {
    setState(() {
      _isProcessing = true;
      _importProgress = 0.0;
      _progressMessage = 'Preparing bulk import...';
      _importErrors.clear();
      _importSuccesses.clear();
    });

    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    try {
      // Update progress message based on batch size
      final batchSize = _parsedData.length;
      setState(() {
        _importProgress = 0.1;
        _progressMessage = 'Processing ${batchSize} accounts in batch...';
      });

      // Use bulk import for efficient processing
      if (_importType == BulkImportConstants.studentImportType) {
        // Prepare student data for bulk import
        final studentsData = _parsedData.map((row) => {
          'email': row['email'].toString(),
          'displayName': row['displayName'].toString(),
          'gradeLevel': row['gradeLevel']?.toString(),
          'parentEmail': row['parentEmail']?.toString(),
          'classIds': _parseClassIds(row['classIds']),
          'isGoogleAuth': row['isGoogleAuth']?.toString().toLowerCase() == 'true',
          'className': row['className']?.toString(),
        }).toList();

        setState(() {
          _importProgress = 0.3;
          _progressMessage = 'Sending batch to server...';
        });

        // Call bulk import function
        final result = await adminProvider.bulkImportStudents(studentsData);

        setState(() {
          _importProgress = 0.8;
          _progressMessage = 'Processing results...';
        });

        // Process results
        for (final success in result.successes) {
          _importSuccesses.add('✓ Student: ${success['displayName']} (${success['email']})');
        }

        for (final error in result.errors) {
          _importErrors.add('✗ ${error.identifier}: ${error.message}');
        }

      } else {
        // Prepare teacher data for bulk import
        final teachersData = _parsedData.map((row) => {
          'email': row['email'].toString(),
          'password': row['password'].toString(),
          'displayName': row['displayName'].toString(),
          'subjects': _parseSubjects(row['subjects']),
        }).toList();

        setState(() {
          _importProgress = 0.3;
          _progressMessage = 'Sending batch to server...';
        });

        // Call bulk import function
        final result = await adminProvider.bulkImportTeachers(teachersData);

        setState(() {
          _importProgress = 0.8;
          _progressMessage = 'Processing results...';
        });

        // Process results
        for (final success in result.successes) {
          _importSuccesses.add('✓ Teacher: ${success['displayName']} (${success['email']})');
        }

        for (final error in result.errors) {
          _importErrors.add('✗ ${error.identifier}: ${error.message}');
        }
      }

      setState(() {
        _importProgress = 1.0;
        _progressMessage = 'Import completed!';
      });

      // Brief delay to show completion
      await Future.delayed(const Duration(seconds: 1));

    } catch (e) {
      setState(() {
        _importErrors.add('Bulk import failed: ${e.toString()}');
      });
    }

    setState(() {
      _isProcessing = false;
      _progressMessage = '';
    });

    if (!mounted) return;

    final message = _importErrors.isEmpty
        ? 'Successfully imported ${_importSuccesses.length} accounts in bulk!'
        : 'Bulk import completed: ${_importSuccesses.length} successes, ${_importErrors.length} failures';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        backgroundColor: _importErrors.isEmpty ? Colors.green : Colors.orange,
      ),
    );
  }

  List<String> _parseClassIds(dynamic classIds) {
    if (classIds == null) return [];
    if (classIds is List) return classIds.map((e) => e.toString()).toList();
    if (classIds is String) {
      return classIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  List<String> _parseSubjects(dynamic subjects) {
    if (subjects == null) return [];
    if (subjects is List) return subjects.map((e) => e.toString()).toList();
    if (subjects is String) {
      return subjects.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }
}