import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image to Firebase Storage
  Future<String> uploadImage({
    required File imageFile,
    required String folder,
    String? fileName,
  }) async {
    try {
      // Generate unique filename if not provided
      final String finalFileName = fileName ?? 
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      
      // Create reference
      final Reference ref = _storage.ref().child('$folder/$finalFileName');
      
      // Upload file
      final UploadTask uploadTask = ref.putFile(imageFile);
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (kDebugMode) {
        debugPrint('📁 Storage: Image uploaded successfully - $downloadUrl');
      }
      
      return downloadUrl;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error uploading image - $e');
      }
      rethrow;
    }
  }

  /// Upload multiple images
  Future<List<String>> uploadImages({
    required List<File> imageFiles,
    required String folder,
    String? prefix,
  }) async {
    try {
      final List<String> downloadUrls = [];
      
      for (int i = 0; i < imageFiles.length; i++) {
        final String fileName = prefix != null 
            ? '${prefix}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}'
            : 'image_${i + 1}_${DateTime.now().millisecondsSinceEpoch}';
        
        final String downloadUrl = await uploadImage(
          imageFile: imageFiles[i],
          folder: folder,
          fileName: fileName,
        );
        
        downloadUrls.add(downloadUrl);
      }
      
      if (kDebugMode) {
        debugPrint('📁 Storage: ${downloadUrls.length} images uploaded successfully');
      }
      
      return downloadUrls;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error uploading images - $e');
      }
      rethrow;
    }
  }

  /// Upload bytes data (for processed images)
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
  }) async {
    try {
      // Create reference
      final Reference ref = _storage.ref().child('$folder/$fileName');
      
      // Upload bytes
      final UploadTask uploadTask = ref.putData(bytes);
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (kDebugMode) {
        debugPrint('📁 Storage: Bytes uploaded successfully - $downloadUrl');
      }
      
      return downloadUrl;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error uploading bytes - $e');
      }
      rethrow;
    }
  }

  /// Delete image from Firebase Storage
  Future<void> deleteImage(String downloadUrl) async {
    try {
      // Extract path from URL
      final Uri uri = Uri.parse(downloadUrl);
      final String path = uri.pathSegments.last;
      
      // Create reference and delete
      final Reference ref = _storage.ref().child(path);
      await ref.delete();
      
      if (kDebugMode) {
        debugPrint('📁 Storage: Image deleted successfully - $downloadUrl');
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error deleting image - $e');
      }
      rethrow;
    }
  }

  /// Delete multiple images
  Future<void> deleteImages(List<String> downloadUrls) async {
    try {
      for (final String url in downloadUrls) {
        await deleteImage(url);
      }
      
      if (kDebugMode) {
        debugPrint('📁 Storage: ${downloadUrls.length} images deleted successfully');
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error deleting images - $e');
      }
      rethrow;
    }
  }

  /// Get image metadata
  Future<FullMetadata> getImageMetadata(String downloadUrl) async {
    try {
      final Uri uri = Uri.parse(downloadUrl);
      final String path = uri.pathSegments.last;
      final Reference ref = _storage.ref().child(path);
      
      return await ref.getMetadata();
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error getting metadata - $e');
      }
      rethrow;
    }
  }

  /// Download image to local storage
  Future<File> downloadImage({
    required String downloadUrl,
    String? localFileName,
  }) async {
    try {
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      
      // Generate filename
      final String fileName = localFileName ?? 
          '${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Create local file
      final File localFile = File(path.join(tempDir.path, fileName));
      
      // Download file
      final Reference ref = _storage.refFromURL(downloadUrl);
      await ref.writeToFile(localFile);
      
      if (kDebugMode) {
        debugPrint('📁 Storage: Image downloaded successfully - ${localFile.path}');
      }
      
      return localFile;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error downloading image - $e');
      }
      rethrow;
    }
  }

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      // This would require custom implementation based on your needs
      // For now, return basic info
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error getting stats - $e');
      }
      return {};
    }
  }

  /// Clean up old temporary files
  Future<void> cleanupTempFiles() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final List<FileSystemEntity> files = tempDir.listSync();
      
      int deletedCount = 0;
      for (final FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          final DateTime fileTime = file.lastModifiedSync();
          final Duration age = DateTime.now().difference(fileTime);
          
          // Delete files older than 7 days
          if (age.inDays > 7) {
            await file.delete();
            deletedCount++;
          }
        }
      }
      
      if (kDebugMode) {
        debugPrint('📁 Storage: Cleaned up $deletedCount old temporary files');
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (kDebugMode) {
        debugPrint('❌ Storage: Error cleaning up temp files - $e');
      }
    }
  }
}
