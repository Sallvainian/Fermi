import 'dart:async';
import 'dart:typed_data';

/// Abstract storage service interface
/// Implementations can use Firebase Storage, local storage, or other providers
abstract class StorageService {
  /// Upload a file from bytes
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
    void Function(double progress)? onProgress,
  });

  /// Upload a file from a file path
  Future<String> uploadFile({
    required String path,
    required String filePath,
    String? contentType,
    Map<String, String>? metadata,
    void Function(double progress)? onProgress,
  });

  /// Download file as bytes
  Future<Uint8List> downloadBytes({
    required String path,
    void Function(double progress)? onProgress,
  });

  /// Download file to a local path
  Future<void> downloadFile({
    required String path,
    required String savePath,
    void Function(double progress)? onProgress,
  });

  /// Get download URL for a file
  Future<String> getDownloadUrl({
    required String path,
  });

  /// Delete a file
  Future<void> delete({
    required String path,
  });

  /// Delete multiple files
  Future<void> deleteMultiple({
    required List<String> paths,
  });

  /// List files in a directory
  Future<List<StorageItem>> listFiles({
    required String path,
    int? maxResults,
    String? pageToken,
  });

  /// Get file metadata
  Future<StorageMetadata> getMetadata({
    required String path,
  });

  /// Update file metadata
  Future<void> updateMetadata({
    required String path,
    required Map<String, String> metadata,
  });

  /// Check if file exists
  Future<bool> exists({
    required String path,
  });

  /// Move/rename a file
  Future<void> move({
    required String fromPath,
    required String toPath,
  });

  /// Copy a file
  Future<void> copy({
    required String fromPath,
    required String toPath,
  });

  /// Get storage usage statistics
  Future<StorageStats> getStats();
}

/// Storage item (file or folder)
class StorageItem {
  final String path;
  final String name;
  final bool isFolder;
  final int? size;
  final DateTime? created;
  final DateTime? updated;
  final String? contentType;
  final Map<String, String>? metadata;

  StorageItem({
    required this.path,
    required this.name,
    required this.isFolder,
    this.size,
    this.created,
    this.updated,
    this.contentType,
    this.metadata,
  });
}

/// Storage metadata
class StorageMetadata {
  final String path;
  final String name;
  final int size;
  final String? contentType;
  final DateTime created;
  final DateTime updated;
  final String? md5Hash;
  final Map<String, String>? customMetadata;
  final String? downloadUrl;

  StorageMetadata({
    required this.path,
    required this.name,
    required this.size,
    this.contentType,
    required this.created,
    required this.updated,
    this.md5Hash,
    this.customMetadata,
    this.downloadUrl,
  });
}

/// Storage statistics
class StorageStats {
  final int totalFiles;
  final int totalSize;
  final int usedSpace;
  final int availableSpace;
  final Map<String, int> fileTypeBreakdown;

  StorageStats({
    required this.totalFiles,
    required this.totalSize,
    required this.usedSpace,
    required this.availableSpace,
    this.fileTypeBreakdown = const {},
  });
}