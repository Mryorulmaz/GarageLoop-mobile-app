import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageOptimizerService {
  static final ImageOptimizerService _instance = ImageOptimizerService._internal();
  factory ImageOptimizerService() => _instance;
  ImageOptimizerService._internal();

  // Varsayılan optimizasyon ayarları
  static const int _defaultMaxWidth = 1024;
  static const int _defaultMaxHeight = 1024;
  static const int _defaultQuality = 85;
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB

  /// Resmi optimize eder ve dosya olarak kaydeder
  Future<File> optimizeImage({
    required File imageFile,
    int? maxWidth,
    int? maxHeight,
    int? quality,
    String? outputFileName,
  }) async {
    try {
      // Parametreleri ayarla
      final width = maxWidth ?? _defaultMaxWidth;
      final height = maxHeight ?? _defaultMaxHeight;
      final imageQuality = quality ?? _defaultQuality;

      // Resmi yükle
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resmi yeniden boyutlandır
      final resizedImage = _resizeImage(image, width, height);
      
      // JPEG formatında sıkıştır
      final optimizedBytes = img.encodeJpg(resizedImage, quality: imageQuality);
      
      // Dosya boyutunu kontrol et
      if (optimizedBytes.length > _maxFileSize) {
        throw Exception('Image is still too large after optimization');
      }

      // Optimize edilmiş dosyayı kaydet
      final outputFile = await _saveOptimizedImage(
        optimizedBytes,
        outputFileName ?? _generateFileName(imageFile.path),
      );

      return outputFile;
    } catch (e) {
      throw Exception('Failed to optimize image: $e');
    }
  }

  /// Resmi yeniden boyutlandırır
  img.Image _resizeImage(img.Image image, int maxWidth, int maxHeight) {
    // Orijinal boyutları al
    final originalWidth = image.width;
    final originalHeight = image.height;

    // Aspect ratio'yu koru
    double scale = 1.0;
    
    if (originalWidth > maxWidth || originalHeight > maxHeight) {
      final scaleX = maxWidth / originalWidth;
      final scaleY = maxHeight / originalHeight;
      scale = scaleX < scaleY ? scaleX : scaleY;
    }

    // Yeni boyutları hesapla
    final newWidth = (originalWidth * scale).round();
    final newHeight = (originalHeight * scale).round();

    // Resmi yeniden boyutlandır
    return img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Optimize edilmiş resmi kaydeder
  Future<File> _saveOptimizedImage(List<int> bytes, String fileName) async {
    final directory = await getTemporaryDirectory();
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);
    
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Dosya adı oluşturur
  String _generateFileName(String originalPath) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(originalPath);
    return 'optimized_$timestamp$extension';
  }

  /// Resim boyutunu kontrol eder
  Future<bool> isImageTooLarge(File imageFile) async {
    final fileSize = await imageFile.length();
    return fileSize > _maxFileSize;
  }

  /// Resim boyutunu alır
  Future<Map<String, int>> getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      throw Exception('Failed to get image dimensions: $e');
    }
  }

  /// Resim formatını kontrol eder
  Future<String> getImageFormat(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Format tespiti - dosya uzantısına göre
      final extension = path.extension(imageFile.path).toLowerCase();
      switch (extension) {
        case '.jpg':
        case '.jpeg':
          return 'JPEG';
        case '.png':
          return 'PNG';
        case '.gif':
          return 'GIF';
        case '.webp':
          return 'WebP';
        default:
          return 'Unknown';
      }
    } catch (e) {
      throw Exception('Failed to get image format: $e');
    }
  }

  /// Çoklu resimleri optimize eder
  Future<List<File>> optimizeMultipleImages({
    required List<File> imageFiles,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    final optimizedFiles = <File>[];
    
    for (final imageFile in imageFiles) {
      try {
        final optimizedFile = await optimizeImage(
          imageFile: imageFile,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: quality,
        );
        optimizedFiles.add(optimizedFile);
      } catch (e) {
        debugPrint('Failed to optimize image ${imageFile.path}: $e');
        // Hata durumunda orijinal dosyayı ekle
        optimizedFiles.add(imageFile);
      }
    }
    
    return optimizedFiles;
  }

  /// Resim kalitesini ayarlar
  Future<File> adjustImageQuality({
    required File imageFile,
    required int quality,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final optimizedBytes = img.encodeJpg(image, quality: quality);
      final outputFile = await _saveOptimizedImage(
        optimizedBytes,
        _generateFileName(imageFile.path),
      );

      return outputFile;
    } catch (e) {
      throw Exception('Failed to adjust image quality: $e');
    }
  }

  /// Resim formatını dönüştürür
  Future<File> convertImageFormat({
    required File imageFile,
    required String targetFormat,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      List<int> convertedBytes;
      
      switch (targetFormat.toUpperCase()) {
        case 'JPEG':
        case 'JPG':
          convertedBytes = img.encodeJpg(image, quality: 85);
          break;
        case 'PNG':
          convertedBytes = img.encodePng(image);
          break;
        default:
          throw Exception('Unsupported format: $targetFormat. Only JPEG and PNG are supported.');
      }

      final outputFile = await _saveOptimizedImage(
        convertedBytes,
        _generateFileName(imageFile.path),
      );

      return outputFile;
    } catch (e) {
      throw Exception('Failed to convert image format: $e');
    }
  }
}
