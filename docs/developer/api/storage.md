# Firebase Storage Documentation

File storage patterns and structure for the Fermi education platform.

## Overview

Firebase Storage handles all file uploads and media management with:
- Secure file uploads with authentication
- Automatic image optimization and resizing
- CDN delivery for global performance
- Role-based access control
- Virus scanning and content validation

## Storage Structure

### Root Directory Organization
```
/users/
  /{userId}/
    /profile/
      - profile_image.jpg
      - banner_image.jpg
    /uploads/
      - temporary files

/classes/
  /{classId}/
    /assignments/
      /{assignmentId}/
        - assignment_files.*
    /resources/
      - class_materials.*
    /images/
      - class_banner.*

/assignments/
  /{assignmentId}/
    /submissions/
      /{studentId}/
        - submission_files.*
    /resources/
      - assignment_materials.*

/chat/
  /{chatRoomId}/
    /media/
      - shared_images.*
      - shared_documents.*

/system/
  /backups/
    - automated_backups.*
  /reports/
    - generated_reports.*
  /templates/
    - document_templates.*
```

## File Types and Handling

### Supported File Types

#### Images
- **Formats**: JPEG, PNG, GIF, WebP
- **Max Size**: 10MB per file
- **Processing**: Automatic compression and thumbnail generation
- **Use Cases**: Profile pictures, assignment attachments, chat media

#### Documents
- **Formats**: PDF, DOC, DOCX, TXT, RTF
- **Max Size**: 25MB per file
- **Processing**: Metadata extraction and preview generation
- **Use Cases**: Assignment submissions, class resources

#### Media Files
- **Formats**: MP4, MP3, WAV (limited support)
- **Max Size**: 100MB per file
- **Processing**: Basic validation only
- **Use Cases**: Educational content, presentations

### File Validation

#### Security Checks
```dart
// File type validation
final allowedTypes = ['.jpg', '.png', '.pdf', '.doc', '.docx'];
if (!allowedTypes.contains(fileExtension)) {
  throw Exception('File type not allowed');
}

// File size validation
if (file.lengthSync() > maxFileSize) {
  throw Exception('File size exceeds limit');
}

// Content validation
await validateFileContent(file);
```

#### Content Scanning
- Automatic virus scanning for all uploads
- Content policy enforcement
- Malicious file detection and blocking

## Upload Patterns

### Standard Upload Flow
```dart
class StorageService {
  Future<String> uploadFile({
    required File file,
    required String path,
    Map<String, String>? metadata,
  }) async {
    try {
      // Validate file
      await _validateFile(file);
      
      // Generate unique filename
      final fileName = _generateFileName(file);
      
      // Create storage reference
      final ref = FirebaseStorage.instance.ref().child('$path/$fileName');
      
      // Upload with metadata
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(file),
          customMetadata: metadata,
        ),
      );
      
      // Monitor progress
      await _trackUploadProgress(uploadTask);
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw StorageException('Upload failed: $e');
    }
  }
}
```

### Progressive Upload for Large Files
```dart
class ProgressiveUploadService {
  Future<String> uploadLargeFile({
    required File file,
    required String path,
    required Function(double) onProgress,
  }) async {
    final uploadTask = FirebaseStorage.instance
        .ref()
        .child(path)
        .putFile(file);
    
    // Monitor upload progress
    uploadTask.snapshotEvents.listen((snapshot) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress(progress);
    });
    
    await uploadTask;
    return await uploadTask.snapshot.ref.getDownloadURL();
  }
}
```

## Access Control

### Security Rules Structure
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User profile images
    match /users/{userId}/profile/{allPaths=**} {
      allow read: if true; // Public read
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Class resources
    match /classes/{classId}/resources/{allPaths=**} {
      allow read: if isClassMember(classId);
      allow write: if isTeacher() || isClassTeacher(classId);
    }
    
    // Assignment submissions
    match /assignments/{assignmentId}/submissions/{studentId}/{allPaths=**} {
      allow read: if isTeacher() || request.auth.uid == studentId;
      allow write: if request.auth != null && request.auth.uid == studentId;
    }
    
    // Chat media
    match /chat/{chatRoomId}/media/{allPaths=**} {
      allow read, write: if isChatRoomMember(chatRoomId);
    }
    
    // Helper functions
    function isClassMember(classId) {
      return request.auth != null && 
             exists(/databases/$(database)/documents/classes/$(classId)/students/$(request.auth.uid));
    }
    
    function isTeacher() {
      return request.auth != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'teacher';
    }
  }
}
```

### Role-Based Permissions

#### Student Access
- Read: Own submissions, class resources, shared chat media
- Write: Own profile images, assignment submissions, chat uploads

#### Teacher Access  
- Read: All class-related files, student submissions
- Write: Class resources, assignment materials, grade feedback files

#### Admin Access
- Read: All files with audit logging
- Write: System files, backup management, template updates

## Performance Optimization

### Image Optimization
```dart
class ImageOptimizer {
  Future<File> optimizeImage(File originalImage) async {
    // Compress image
    final compressed = await FlutterImageCompress.compressWithFile(
      originalImage.absolute.path,
      quality: 85,
      minWidth: 1024,
      minHeight: 1024,
    );
    
    // Generate thumbnail
    final thumbnail = await _generateThumbnail(compressed);
    
    return compressed;
  }
  
  Future<void> _generateThumbnail(File image) async {
    // Create multiple sizes for responsive loading
    final sizes = [150, 300, 600];
    for (final size in sizes) {
      await _resizeImage(image, size);
    }
  }
}
```

### Caching Strategy
```dart
class StorageCache {
  static final Map<String, String> _urlCache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  Future<String> getCachedUrl(String path) async {
    // Check cache first
    if (_urlCache.containsKey(path)) {
      return _urlCache[path]!;
    }
    
    // Fetch from Firebase Storage
    final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
    
    // Cache result
    _urlCache[path] = url;
    
    // Set expiry timer
    Timer(_cacheExpiry, () => _urlCache.remove(path));
    
    return url;
  }
}
```

## Monitoring and Analytics

### Upload Metrics
- File size distribution
- Upload success/failure rates
- Popular file types and sizes
- Storage usage by feature

### Performance Tracking
```dart
class StorageAnalytics {
  static void trackUpload({
    required String fileType,
    required int fileSize,
    required Duration uploadTime,
    required bool success,
  }) {
    FirebaseAnalytics.instance.logEvent(
      name: 'file_upload',
      parameters: {
        'file_type': fileType,
        'file_size_mb': (fileSize / (1024 * 1024)).round(),
        'upload_time_ms': uploadTime.inMilliseconds,
        'success': success,
      },
    );
  }
}
```

## Backup and Recovery

### Automated Backups
- Daily incremental backups of critical files
- Weekly full backups with retention policy
- Geographic redundancy across regions
- Point-in-time recovery capabilities

### Disaster Recovery
- Cross-region replication for critical data
- Automated failover procedures
- Regular recovery testing
- Data integrity verification

## Cost Optimization

### Storage Management
- Automatic cleanup of temporary files
- Compression for archive data
- Lifecycle policies for old files
- Usage monitoring and alerts

### Bandwidth Optimization
- CDN caching for frequently accessed files
- Lazy loading for image galleries
- Progressive download for large files
- Client-side compression before upload

[content placeholder]