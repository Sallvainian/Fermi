import 'dart:convert';

/// Comprehensive validation and sanitization service for user inputs
class ValidationService {
  
  // Email validation regex - RFC 5322 compliant
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );
  
  // Password strength regex patterns
  static final _hasUpperCase = RegExp(r'[A-Z]');
  static final _hasLowerCase = RegExp(r'[a-z]');
  static final _hasDigit = RegExp(r'\d');
  static final _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
  
  // Phone number patterns for common formats
  static final _phoneRegex = RegExp(
    r'^(\+\d{1,3}[- ]?)?\(?\d{3}\)?[- ]?\d{3}[- ]?\d{4}$',
  );
  
  // Class code pattern (6 characters, uppercase letters and numbers)
  static final _classCodeRegex = RegExp(r'^[A-Z0-9]{6}$');
  
  // Username pattern (alphanumeric, underscore, hyphen, 3-20 chars)
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
  
  // URL validation pattern
  static final _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  /// Validate email address
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    final trimmed = email.trim().toLowerCase();
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    
    // Additional checks for common typos
    if (trimmed.contains('..') || 
        trimmed.startsWith('.') || 
        trimmed.endsWith('.') ||
        trimmed.contains('@.') ||
        trimmed.contains('.@')) {
      return 'Invalid email format';
    }
    
    return null;
  }

  /// Validate password with strength requirements
  static String? validatePassword(String? password, {
    int minLength = 8,
    bool requireUpperCase = true,
    bool requireLowerCase = true,
    bool requireDigit = true,
    bool requireSpecialChar = true,
  }) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    
    final requirements = <String>[];
    
    if (requireUpperCase && !_hasUpperCase.hasMatch(password)) {
      requirements.add('uppercase letter');
    }
    
    if (requireLowerCase && !_hasLowerCase.hasMatch(password)) {
      requirements.add('lowercase letter');
    }
    
    if (requireDigit && !_hasDigit.hasMatch(password)) {
      requirements.add('number');
    }
    
    if (requireSpecialChar && !_hasSpecialChar.hasMatch(password)) {
      requirements.add('special character');
    }
    
    if (requirements.isNotEmpty) {
      final reqText = requirements.join(', ');
      return 'Password must contain at least one $reqText';
    }
    
    return null;
  }

  /// Validate username
  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'Username is required';
    }
    
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    if (username.length > 20) {
      return 'Username must be less than 20 characters';
    }
    
    if (!_usernameRegex.hasMatch(username)) {
      return 'Username can only contain letters, numbers, underscore, and hyphen';
    }
    
    // Check for offensive words (basic list - extend as needed)
    final lowercased = username.toLowerCase();
    final restrictedUsernames = ['admin', 'root', 'test', 'user', 'guest'];
    if (restrictedUsernames.contains(lowercased)) {
      return 'This username is not available';
    }
    
    return null;
  }

  /// Validate display name
  static String? validateDisplayName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Name is required';
    }
    
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (trimmed.length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    // Allow letters, spaces, hyphens, apostrophes
    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    
    return null;
  }

  /// Validate phone number
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is often optional
    }
    
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length < 10 || cleaned.length > 15) {
      return 'Please enter a valid phone number';
    }
    
    if (!_phoneRegex.hasMatch(phone)) {
      return 'Invalid phone number format';
    }
    
    return null;
  }

  /// Validate class code
  static String? validateClassCode(String? code) {
    if (code == null || code.isEmpty) {
      return 'Class code is required';
    }
    
    final upperCode = code.toUpperCase().trim();
    if (upperCode.length != 6) {
      return 'Class code must be exactly 6 characters';
    }
    
    if (!_classCodeRegex.hasMatch(upperCode)) {
      return 'Class code can only contain uppercase letters and numbers';
    }
    
    return null;
  }

  /// Validate URL
  static String? validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null; // URLs are often optional
    }
    
    if (!_urlRegex.hasMatch(url)) {
      return 'Please enter a valid URL';
    }
    
    return null;
  }

  /// Validate age/date of birth
  static String? validateAge(int? age, {int minAge = 13, int maxAge = 120}) {
    if (age == null) {
      return 'Age is required';
    }
    
    if (age < minAge) {
      return 'You must be at least $minAge years old';
    }
    
    if (age > maxAge) {
      return 'Please enter a valid age';
    }
    
    return null;
  }

  /// Validate text length
  static String? validateTextLength(
    String? text, {
    required String fieldName,
    int? minLength,
    int? maxLength,
    bool required = true,
  }) {
    if (text == null || text.isEmpty) {
      return required ? '$fieldName is required' : null;
    }
    
    final trimmed = text.trim();
    
    if (minLength != null && trimmed.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    
    if (maxLength != null && trimmed.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }
    
    return null;
  }

  /// Sanitize HTML input
  static String sanitizeHtml(String input) {
    // Basic HTML entity decoding
    var sanitized = input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    
    // Remove script tags and their content
    sanitized = sanitized.replaceAll(RegExp(r'<script[^>]*>.*?</script>', 
        multiLine: true, caseSensitive: false), '');
    
    // Remove iframe tags
    sanitized = sanitized.replaceAll(RegExp(r'<iframe[^>]*>.*?</iframe>', 
        multiLine: true, caseSensitive: false), '');
    
    // Remove event handlers (simplified)
    sanitized = sanitized.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
    
    // Remove javascript: URLs
    sanitized = sanitized.replaceAll(RegExp(r'javascript:', 
        caseSensitive: false), '');
    
    return sanitized.trim();
  }

  /// Sanitize input for Firebase paths
  static String sanitizeFirebasePath(String input) {
    // Firebase doesn't allow: ., #, $, [, ]
    return input
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('/', '_'); // Also replace forward slashes
  }

  /// Sanitize input for display (prevent XSS)
  static String sanitizeForDisplay(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Validate and sanitize JSON string
  static Map<String, dynamic>? validateJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      // Invalid JSON
    }
    
    return null;
  }

  /// Check if string contains SQL injection patterns
  static bool containsSqlInjection(String input) {
    final sqlPatterns = [
      RegExp(r'\b(union|select|insert|update|delete|drop|create)\b', 
          caseSensitive: false),
      RegExp(r'(--|;)', caseSensitive: false),
      RegExp(r"['`]", caseSensitive: false),
    ];
    
    return sqlPatterns.any((pattern) => pattern.hasMatch(input));
  }

  /// Validate file upload
  static String? validateFileUpload({
    required String fileName,
    required int fileSizeBytes,
    List<String> allowedExtensions = const ['.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx'],
    int maxSizeMB = 10,
  }) {
    // Check file extension
    final extension = fileName.toLowerCase().substring(fileName.lastIndexOf('.'));
    if (!allowedExtensions.contains(extension)) {
      return 'File type not allowed. Allowed types: ${allowedExtensions.join(', ')}';
    }
    
    // Check file size
    final maxSizeBytes = maxSizeMB * 1024 * 1024;
    if (fileSizeBytes > maxSizeBytes) {
      return 'File size must be less than $maxSizeMB MB';
    }
    
    // Check for double extensions (potential security risk)
    final parts = fileName.split('.');
    if (parts.length > 2) {
      // Check if any part contains executable extensions
      final dangerousExtensions = ['exe', 'bat', 'cmd', 'sh', 'app'];
      for (final part in parts) {
        if (dangerousExtensions.contains(part.toLowerCase())) {
          return 'Invalid file name';
        }
      }
    }
    
    return null;
  }

  /// Validate credit card number (basic Luhn algorithm)
  static String? validateCreditCard(String? cardNumber) {
    if (cardNumber == null || cardNumber.isEmpty) {
      return 'Card number is required';
    }
    
    // Remove spaces and hyphens
    final cleaned = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
    
    // Check if all characters are digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Card number can only contain digits';
    }
    
    // Check length (most cards are 13-19 digits)
    if (cleaned.length < 13 || cleaned.length > 19) {
      return 'Invalid card number length';
    }
    
    // Luhn algorithm
    var sum = 0;
    var isEven = false;
    
    for (var i = cleaned.length - 1; i >= 0; i--) {
      var digit = int.parse(cleaned[i]);
      
      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      
      sum += digit;
      isEven = !isEven;
    }
    
    if (sum % 10 != 0) {
      return 'Invalid card number';
    }
    
    return null;
  }

  /// Generate strong password
  static String generateStrongPassword({
    int length = 16,
    bool includeUpperCase = true,
    bool includeLowerCase = true,
    bool includeDigits = true,
    bool includeSpecialChars = true,
  }) {
    const upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowerCase = 'abcdefghijklmnopqrstuvwxyz';
    const digits = '0123456789';
    const specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    
    var chars = '';
    if (includeUpperCase) chars += upperCase;
    if (includeLowerCase) chars += lowerCase;
    if (includeDigits) chars += digits;
    if (includeSpecialChars) chars += specialChars;
    
    if (chars.isEmpty) {
      throw ArgumentError('At least one character type must be included');
    }
    
    final random = DateTime.now().millisecondsSinceEpoch;
    final password = List.generate(length, (index) {
      final charIndex = (random + index * 7) % chars.length;
      return chars[charIndex];
    });
    
    // Shuffle the password
    password.shuffle();
    
    return password.join();
  }
}