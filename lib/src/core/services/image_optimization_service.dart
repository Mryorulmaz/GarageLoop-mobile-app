import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../widgets/skeleton_loading.dart';

class ImageOptimizationService {
  static const int _maxWidth = 1024;
  static const int _maxHeight = 1024;
  static const int _quality = 85;
  static const int _maxFileSize = 2 * 1024 * 1024; // 2MB

  static final ImageOptimizationService _instance = ImageOptimizationService._internal();
  factory ImageOptimizationService() => _instance;
  ImageOptimizationService._internal();

  Future<File?> optimizeImageFromFile(File imageFile) async {
    try {
      if (kDebugMode) {
        debugPrint('Optimizing image: ${imageFile.path}');
      }

      final fileSize = await imageFile.length();
      if (fileSize <= _maxFileSize) {
        if (kDebugMode) {
          debugPrint('Image size is already within limits: $fileSize bytes');
        }
        return imageFile;
      }

      final bytes = await imageFile.readAsBytes();
      final optimizedBytes = await _optimizeImageBytes(bytes);

      if (optimizedBytes == null) return null;

      final optimizedFile = await _saveOptimizedImage(optimizedBytes, imageFile.path);
      
      if (kDebugMode) {
        final optimizedSize = await optimizedFile.length();
        debugPrint('Image optimized: $fileSize -> $optimizedSize bytes');
      }

      return optimizedFile;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to optimize image: $e');
      }
      return null;
    }
  }

  Future<Uint8List?> optimizeImageBytes(Uint8List bytes) async {
    try {
      return await _optimizeImageBytes(bytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to optimize image bytes: $e');
      }
      return null;
    }
  }

  Future<Uint8List?> _optimizeImageBytes(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final newDimensions = _calculateOptimalDimensions(image.width, image.height);
      
      img.Image resizedImage = image;
      if (newDimensions.width != image.width || newDimensions.height != image.height) {
        resizedImage = img.copyResize(
          image,
          width: newDimensions.width.toInt(),
          height: newDimensions.height.toInt(),
          interpolation: img.Interpolation.linear,
        );
      }

      final optimizedBytes = img.encodeJpg(resizedImage, quality: _quality);
      
      return Uint8List.fromList(optimizedBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to optimize image bytes: $e');
      }
      return null;
    }
  }

  Size _calculateOptimalDimensions(int width, int height) {
    if (width <= _maxWidth && height <= _maxHeight) {
      return Size(width.toDouble(), height.toDouble());
    }

    final double ratio = width / height;
    
    if (width > height) {
      return Size(_maxWidth.toDouble(), (_maxWidth / ratio).round().toDouble());
    } else {
      return Size((_maxHeight * ratio).round().toDouble(), _maxHeight.toDouble());
    }
  }

  Future<File> _saveOptimizedImage(Uint8List bytes, String originalPath) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'optimized_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File('${tempDir.path}/$fileName');
    
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Uint8List?> createThumbnail(Uint8List bytes, {int size = 200}) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
        interpolation: img.Interpolation.linear,
      );

      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 80);
      return Uint8List.fromList(thumbnailBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to create thumbnail: $e');
      }
      return null;
    }
  }

  Future<ImageInfo?> getImageInfo(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;

      return ImageInfo(
        width: image.width,
        height: image.height,
        size: bytes.length,
        format: _getImageFormat(bytes),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get image info: $e');
      }
      return null;
    }
  }

  String _getImageFormat(Uint8List bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'JPEG';
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'PNG';
      if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'GIF';
      if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'WEBP';
    }
    return 'Unknown';
  }

  Future<void> clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      final tempDir = await getTemporaryDirectory();
      final optimizedImages = tempDir.listSync().where((file) => 
        file.path.contains('optimized_') && file.path.endsWith('.jpg')
      );
      
      for (final file in optimizedImages) {
        await file.delete();
      }
      
      if (kDebugMode) {
        debugPrint('Image cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to clear cache: $e');
      }
    }
  }

  Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final optimizedImages = tempDir.listSync().where((file) => 
        file.path.contains('optimized_') && file.path.endsWith('.jpg')
      );
      
      int totalSize = 0;
      for (final file in optimizedImages) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get cache size: $e');
      }
      return 0;
    }
  }
}

class ImageInfo {
  final int width;
  final int height;
  final int size;
  final String format;

  ImageInfo({
    required this.width,
    required this.height,
    required this.size,
    required this.format,
  });

  String get sizeInMB => '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  String get dimensions => '${width}x$height';
}

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? 
          SkeletonLoading(
            width: width,
            height: height,
            borderRadius: borderRadius,
          ),
        errorWidget: (context, url, error) => errorWidget ?? 
          Container(
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
            ),
          ),
        cacheManager: DefaultCacheManager(),
        memCacheWidth: width?.toInt(),
        memCacheHeight: height?.toInt(),
      ),
    );
  }
}

class ProgressiveImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProgressiveImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => SkeletonLoading(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.error,
            color: Colors.grey,
          ),
        ),
        cacheManager: DefaultCacheManager(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
        memCacheWidth: width?.toInt(),
        memCacheHeight: height?.toInt(),
      ),
    );
  }
}
