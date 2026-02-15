import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// User login event
  Future<void> logUserLogin({String? method}) async {
    try {
      await _analytics.logLogin(loginMethod: method ?? 'email');
      if (kDebugMode) {
        debugPrint('📊 Analytics: User login logged');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// User signup event
  Future<void> logUserSignup({String? method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method ?? 'email');
      if (kDebugMode) {
        debugPrint('📊 Analytics: User signup logged');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Screen view event
  Future<void> logScreenView({required String screenName}) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      if (kDebugMode) {
        debugPrint('📊 Analytics: Screen view - $screenName');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Product view event
  Future<void> logProductView({
    required String productId,
    required String productName,
    required String category,
    double? price,
  }) async {
    try {
      await _analytics.logViewItem(
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: productName,
            itemCategory: category,
            price: price,
          ),
        ],
        currency: 'USD',
        value: price,
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Product view - $productName');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Add to favorites event
  Future<void> logAddToFavorites({
    required String productId,
    required String productName,
    required String category,
    double? price,
  }) async {
    try {
      await _analytics.logAddToWishlist(
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: productName,
            itemCategory: category,
            price: price,
          ),
        ],
        currency: 'USD',
        value: price,
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Added to favorites - $productName');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Search event
  Future<void> logSearch({required String searchTerm}) async {
    try {
      await _analytics.logSearch(searchTerm: searchTerm);
      if (kDebugMode) {
        debugPrint('📊 Analytics: Search - $searchTerm');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Contact seller event
  Future<void> logContactSeller({
    required String productId,
    required String sellerId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'contact_seller',
        parameters: {
          'product_id': productId,
          'seller_id': sellerId,
        },
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Contact seller logged');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Create listing event
  Future<void> logCreateListing({
    required String category,
    double? price,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'create_listing',
        parameters: {
          'category': category,
          if (price != null) 'price': price,
        },
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Create listing logged');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// App open event
  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      if (kDebugMode) {
        debugPrint('📊 Analytics: App open logged');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Error event
  Future<void> logError({
    required String error,
    required String screen,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error': error,
          'screen': screen,
          ...?parameters,
        },
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Error logged - $error');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Custom event
  Future<void> logCustomEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Custom event - $name');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Set user properties
  Future<void> setUserProperties({
    String? userId,
    String? userType,
    String? location,
  }) async {
    try {
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
      if (userType != null) {
        await _analytics.setUserProperty(name: 'user_type', value: userType);
      }
      if (location != null) {
        await _analytics.setUserProperty(name: 'location', value: location);
      }
      if (kDebugMode) {
        debugPrint('📊 Analytics: User properties set');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// Enable/disable analytics
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      if (kDebugMode) {
        debugPrint('📊 Analytics: Collection ${enabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
}
