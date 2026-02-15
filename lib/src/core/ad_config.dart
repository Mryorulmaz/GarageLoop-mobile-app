import 'dart:io';

import 'package:flutter/foundation.dart';

/// Central ad configuration (placeholder for public repo).
/// Debug: Google test IDs. Release: add your own Ad Unit IDs from AdMob Console.
class AdConfig {
  AdConfig._();

  /// Set to true to disable rewarded ads on iOS debug (e.g. for App Store review).
  static const bool _skipAdsIOSDebug = false;

  static bool _isPlaceholder(String id) =>
      id.isEmpty || id.contains('XXXXX');

  /// Banner ad - main grid, product detail, favorites, listings.
  static String bannerAdUnitId() {
    if (kIsWeb) return '';
    final id = Platform.isIOS
        ? (kDebugMode ? 'ca-app-pub-3940256099942544/2934735716' : _bannerIos)
        : (kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : _bannerAndroid);
    return _isPlaceholder(id) ? '' : id;
  }

  /// Rewarded ad - watch video to earn credits.
  static String rewardedAdUnitId() {
    if (kIsWeb || _skipAdsIOSDebug) return '';
    final id = Platform.isIOS
        ? (kDebugMode ? 'ca-app-pub-3940256099942544/1712485313' : _rewardedIos)
        : (kDebugMode ? 'ca-app-pub-3940256099942544/5224354917' : _rewardedAndroid);
    return _isPlaceholder(id) ? '' : id;
  }

  // Add your own Ad Unit IDs from AdMob Console (Apps -> Ad units).
  // Format: ca-app-pub-PUBLISHER_ID/AD_UNIT_ID

  static const String _bannerIos = 'ca-app-pub-0000000000000000/0000000000';
  static const String _bannerAndroid = 'ca-app-pub-0000000000000000/0000000000';
  static const String _rewardedIos = 'ca-app-pub-0000000000000000/0000000000';
  static const String _rewardedAndroid = 'ca-app-pub-0000000000000000/0000000000';
}
