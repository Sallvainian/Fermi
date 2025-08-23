import '../utils/platform_utils.dart';
import 'interfaces/auth_service.dart';
import 'interfaces/database_service.dart';
import 'interfaces/storage_service.dart';
import 'firebase/firebase_auth_service.dart';
import 'firebase/firebase_database_service.dart';
import 'windows/windows_auth_service.dart';
import 'windows/windows_database_service.dart';

/// Factory class for creating platform-specific service implementations
class ServiceFactory {
  static AuthService? _authService;
  static DatabaseService? _databaseService;
  static StorageService? _storageService;

  /// Get the auth service for the current platform
  static AuthService getAuthService() {
    _authService ??= _createAuthService();
    return _authService!;
  }

  /// Get the database service for the current platform
  static DatabaseService getDatabaseService() {
    _databaseService ??= _createDatabaseService();
    return _databaseService!;
  }

  /// Get the storage service for the current platform
  static StorageService? getStorageService() {
    _storageService ??= _createStorageService();
    return _storageService;
  }

  /// Create the appropriate auth service based on platform
  static AuthService _createAuthService() {
    if (PlatformUtils.needsWindowsServices) {
      return WindowsAuthService();
    } else {
      return FirebaseAuthService();
    }
  }

  /// Create the appropriate database service based on platform
  static DatabaseService _createDatabaseService() {
    if (PlatformUtils.needsWindowsServices) {
      return WindowsDatabaseService();
    } else {
      return FirebaseDatabaseService();
    }
  }

  /// Create the appropriate storage service based on platform
  static StorageService? _createStorageService() {
    if (PlatformUtils.needsWindowsServices) {
      // TODO: Implement WindowsStorageService for local file storage
      // For now, return null on Windows
      return null;
    } else {
      // TODO: Implement FirebaseStorageService
      return null;
    }
  }

  /// Reset all services (useful for testing)
  static void reset() {
    _authService = null;
    _databaseService = null;
    _storageService = null;
  }

  /// Get information about the current platform and services
  static Map<String, dynamic> getServiceInfo() {
    return {
      'platform': PlatformUtils.platformName,
      'isFirebaseSupported': PlatformUtils.isFirebaseSupported,
      'needsWindowsServices': PlatformUtils.needsWindowsServices,
      'authService': _authService?.runtimeType.toString() ?? 'Not initialized',
      'databaseService': _databaseService?.runtimeType.toString() ?? 'Not initialized',
      'storageService': _storageService?.runtimeType.toString() ?? 'Not available',
    };
  }
}