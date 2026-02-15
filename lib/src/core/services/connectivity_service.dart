import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  // Uygulamada tekil kullanım için varsayılan örnek
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService({Connectivity? connectivity}) {
    if (connectivity != null) {
      return ConnectivityService._internal(connectivity);
    }
    return _instance;
  }
  ConnectivityService._internal([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isConnected = true;
  bool _isInitialized = false;

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // İlk bağlantı durumunu kontrol et (timeout ile)
      final results = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Connectivity check timeout - assuming connected');
          return [ConnectivityResult.wifi]; // Default to connected
        },
      );
      _updateConnectionStatus(results);

      // Bağlantı değişikliklerini dinle
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _updateConnectionStatus(results);
        },
        onError: (error) {
          debugPrint('Connectivity error: $error');
          _isConnected = true; // Default to connected on error
          notifyListeners();
        },
        cancelOnError: false, // Don't cancel on error
      );

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize connectivity service: $e');
      _isConnected = true; // Default to connected on error
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    
    // Herhangi bir bağlantı varsa online kabul et
    _isConnected = results.any((result) => 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet
    );

    // Durum değiştiyse bildir
    if (wasConnected != _isConnected) {
      notifyListeners();
      
      // Analytics event gönder
      if (_isConnected) {
        _logConnectionRestored();
      } else {
        _logConnectionLost();
      }
    }
  }

  void _logConnectionRestored() {
    // Firebase Analytics event (gelecekte eklenecek)
    debugPrint('Connection restored');
  }

  void _logConnectionLost() {
    // Firebase Analytics event (gelecekte eklenecek)
    debugPrint('Connection lost');
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
