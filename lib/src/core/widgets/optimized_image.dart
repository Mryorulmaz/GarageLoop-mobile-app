import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate cache dimensions safely (avoid Infinity or NaN)
    int? cacheWidth;
    int? cacheHeight;
    
    if (width != null && width!.isFinite && width! > 0) {
      cacheWidth = (width! * 2).toInt();
    }
    
    if (height != null && height!.isFinite && height! > 0) {
      cacheHeight = (height! * 2).toInt();
    }
    
    // Validate image URL
    if (imageUrl.isEmpty) {
      return errorWidget ?? _buildErrorWidget();
    }
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildSkeleton(),
      errorWidget: (context, url, error) {
        // Log error for debugging
        debugPrint('Image load error: $error for URL: $url');
        return errorWidget ?? _buildErrorWidget();
      },
      // Hedef cihaz boyutlarına göre makul cache; grid kartları için 2x piksel yeterlidir
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      maxWidthDiskCache: 1024,
      maxHeightDiskCache: 768,
      fadeInDuration: const Duration(milliseconds: 80),
      fadeOutDuration: const Duration(milliseconds: 80),
      // Retry on network errors
      httpHeaders: const {
        'Cache-Control': 'max-age=3600',
      },
    );
  }

  Widget _buildSkeleton() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
        size: 32,
      ),
    );
  }
}
