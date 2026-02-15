import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../services/image_optimizer_service.dart';
import '../../home/home_screen.dart';

class ImageOptimizationWidget extends StatefulWidget {
  final File imageFile;
  final Function(File) onOptimized;
  final Function(String) onError;

  const ImageOptimizationWidget({
    super.key,
    required this.imageFile,
    required this.onOptimized,
    required this.onError,
  });

  @override
  State<ImageOptimizationWidget> createState() => _ImageOptimizationWidgetState();
}

class _ImageOptimizationWidgetState extends State<ImageOptimizationWidget> {
  bool _isOptimizing = false;
  double _progress = 0.0;
  String _status = '';
  Map<String, int>? _originalDimensions;
  int? _originalFileSize;
  Map<String, int>? _optimizedDimensions;
  int? _optimizedFileSize;

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    try {
      final optimizer = ImageOptimizerService();
      // Orijinal boyutları al
      _originalDimensions = await optimizer.getImageDimensions(widget.imageFile);
      _originalFileSize = await widget.imageFile.length();
      setState(() {});
    } catch (e) {
      widget.onError('Failed to analyze image: $e');
    }
  }

  Future<void> _optimizeImage() async {
    setState(() {
      _isOptimizing = true;
      _progress = 0.0;
      _status = 'Analyzing image...';
    });

    try {
      final optimizer = ImageOptimizerService();
      // Progress callback
      setState(() {
        _progress = 0.3;
        _status = 'Resizing image...';
      });
      // Resmi optimize et
      final optimizedFile = await optimizer.optimizeImage(
        imageFile: widget.imageFile,
        maxWidth: 1024,
        maxHeight: 1024,
        quality: 85,
      );
      setState(() {
        _progress = 0.7;
        _status = 'Finalizing...';
      });
      // Optimize edilmiş boyutları al
      _optimizedDimensions = await optimizer.getImageDimensions(optimizedFile);
      _optimizedFileSize = await optimizedFile.length();
      setState(() {
        _progress = 1.0;
        _status = 'Optimization complete!';
      });
      // Kısa bir gecikme ile callback'i çağır
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onOptimized(optimizedFile);
    } catch (e) {
      setState(() {
        _isOptimizing = false;
        _status = 'Optimization failed';
      });
      widget.onError('Failed to optimize image: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  double _getCompressionRatio() {
    if (_originalFileSize == null || _optimizedFileSize == null) return 0.0;
    return ((_originalFileSize! - _optimizedFileSize!) / _originalFileSize!) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.image,
                color: HomeScreen.primaryNavy,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Image Optimization',
                style: GoogleFonts.openSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Image preview
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Original image info
          if (_originalDimensions != null) ...[
            _buildInfoRow('Original Size', '${_originalDimensions!['width']} × ${_originalDimensions!['height']}'),
            _buildInfoRow('File Size', _formatFileSize(_originalFileSize!)),
            const SizedBox(height: 8),
          ],
          // Optimization progress
          if (_isOptimizing) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(HomeScreen.primaryNavy),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: GoogleFonts.openSans(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Optimized image info
          if (_optimizedDimensions != null) ...[
            _buildInfoRow('Optimized Size', '${_optimizedDimensions!['width']} × ${_optimizedDimensions!['height']}'),
            _buildInfoRow('File Size', _formatFileSize(_optimizedFileSize!)),
            _buildInfoRow('Compression', '${_getCompressionRatio().toStringAsFixed(1)}% smaller'),
            const SizedBox(height: 16),
          ],
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isOptimizing ? null : _optimizeImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeScreen.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isOptimizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Optimize Image',
                          style: GoogleFonts.openSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.openSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageOptimizationDialog extends StatelessWidget {
  final File imageFile;
  final Function(File) onOptimized;

  const ImageOptimizationDialog({
    super.key,
    required this.imageFile,
    required this.onOptimized,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Optimize Image',
              style: GoogleFonts.openSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ImageOptimizationWidget(
              imageFile: imageFile,
              onOptimized: (optimizedFile) {
                Navigator.of(context).pop(optimizedFile);
                onOptimized(optimizedFile);
              },
              onError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
