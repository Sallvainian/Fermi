class BulkImportConstants {
  // Import types
  static const String studentImportType = 'student';
  static const String teacherImportType = 'teacher';
  
  // File formats
  static const String csvFormat = 'csv';
  static const String jsonFormat = 'json';
  
  // Field definitions
  static const List<String> studentRequiredFields = [
    'username',
    'displayName',
    'gradeLevel',
  ];
  
  static const List<String> studentOptionalFields = [
    'parentEmail',
    'classIds',
  ];
  
  static const List<String> teacherRequiredFields = [
    'email',
    'displayName',
  ];
  
  static const List<String> teacherOptionalFields = [
    'subjects',
    'password',
  ];
  
  // Batch processing settings
  static const int batchSize = 500;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration batchDelay = Duration(milliseconds: 500);
  
  // Password settings
  static const String defaultTeacherPassword = 'TempPass123!';
  static const int passwordLength = 12;
  static const String passwordCharset = 
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
  
  // CSV templates
  static const String studentCsvHeader = 
      'username,displayName,gradeLevel,parentEmail,classIds';
  static const String teacherCsvHeader = 
      'email,displayName,subjects,password';
  
  // Sample data for templates
  static const Map<String, dynamic> studentSampleData = {
    'username': 'johndoe2024',
    'displayName': 'John Doe',
    'gradeLevel': '10',
    'parentEmail': 'parent@example.com',
    'classIds': 'math101,science201',
  };
  
  static const Map<String, dynamic> teacherSampleData = {
    'email': 'teacher@school.edu',
    'displayName': 'Jane Smith',
    'subjects': 'Mathematics,Physics',
    'password': '', // Will use default if empty
  };
  
  // Validation patterns
  static final RegExp emailPattern = 
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp usernamePattern = 
      RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  
  // Error messages
  static const String usernameExistsError = 'Username already exists';
  static const String emailExistsError = 'Email already exists';
  static const String invalidEmailError = 'Invalid email format';
  static const String invalidUsernameError = 'Invalid username format';
  static const String missingRequiredFieldError = 'Missing required field';
  
  // UI Messages
  static const String importSuccessMessage = 'Import completed successfully';
  static const String importPartialSuccessMessage = 'Import completed with some errors';
  static const String importFailureMessage = 'Import failed';
  static const String validationErrorMessage = 'Please fix validation errors before importing';
  
  // File size limits
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxRecordsPerImport = 1000;
}