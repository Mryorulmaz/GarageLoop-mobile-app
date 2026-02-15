import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<double>> _metrics = {};

  /// Performans ölçümü başlat
  void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
  }

  /// Performans ölçümü bitir ve kaydet
  void endTimer(String name) {
    final timer = _timers[name];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsedMilliseconds.toDouble();
      
      if (!_metrics.containsKey(name)) {
        _metrics[name] = [];
      }
      _metrics[name]!.add(duration);
      
      // Debug modda log
      if (kDebugMode) {
        debugPrint('⏱️ Performance [$name]: ${duration}ms');
      }
      
      _timers.remove(name);
    }
  }

  /// Ortalama performans metriklerini al
  Map<String, double> getAverageMetrics() {
    final averages = <String, double>{};
    
    _metrics.forEach((name, values) {
      if (values.isNotEmpty) {
        final sum = values.reduce((a, b) => a + b);
        averages[name] = sum / values.length;
      }
    });
    
    return averages;
  }

  /// Bellek kullanımını optimize et
  void optimizeMemory() {
    // Garbage collection'ı tetikle
    _metrics.clear();
    _timers.clear();
  }

  /// Widget rebuild sayısını takip et
  int _rebuildCount = 0;
  void trackRebuild() {
    _rebuildCount++;
    if (kDebugMode && _rebuildCount % 100 == 0) {
      debugPrint('🔄 Widget Rebuild Count: $_rebuildCount');
    }
  }

  /// Image cache boyutunu kontrol et
  void checkImageCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    if (kDebugMode) {
      debugPrint('🖼️ Image Cache - Current: ${imageCache.currentSizeBytes}');
      debugPrint('🖼️ Image Cache - Maximum: ${imageCache.maximumSizeBytes}');
    }
  }

  /// Network request performansını takip et
  void trackNetworkRequest(String endpoint, int duration) {
    if (!_metrics.containsKey('network_$endpoint')) {
      _metrics['network_$endpoint'] = [];
    }
    _metrics['network_$endpoint']!.add(duration.toDouble());
    
    if (kDebugMode) {
      debugPrint('🌐 Network [$endpoint]: ${duration}ms');
    }
  }

  /// Database query performansını takip et
  void trackDatabaseQuery(String query, int duration) {
    if (!_metrics.containsKey('db_$query')) {
      _metrics['db_$query'] = [];
    }
    _metrics['db_$query']!.add(duration.toDouble());
    
    if (kDebugMode) {
      debugPrint('🗄️ Database [$query]: ${duration}ms');
    }
  }

  /// Performans raporu oluştur
  Map<String, dynamic> generateReport() {
    final averages = getAverageMetrics();
    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'rebuild_count': _rebuildCount,
      'average_metrics': averages,
      'total_metrics': _metrics.length,
    };
    
    return report;
  }
}
