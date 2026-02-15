import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  bool _isScreenReaderEnabled = false;
  bool _isHighContrastEnabled = false;
  bool _isLargeTextEnabled = false;
  bool _isBoldTextEnabled = false;
  bool _isReduceMotionEnabled = false;
  double _textScaleFactor = 1.0;

  bool get isScreenReaderEnabled => _isScreenReaderEnabled;
  bool get isHighContrastEnabled => _isHighContrastEnabled;
  bool get isLargeTextEnabled => _isLargeTextEnabled;
  bool get isBoldTextEnabled => _isBoldTextEnabled;
  bool get isReduceMotionEnabled => _isReduceMotionEnabled;
  double get textScaleFactor => _textScaleFactor;

  /// Initialize accessibility settings
  Future<void> initialize() async {
    try {
      // Check platform accessibility settings
      WidgetsBinding.instance.addObserver(_AccessibilityObserver(this));
      
      if (kDebugMode) {
        debugPrint('Accessibility Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing accessibility service: $e');
      }
    }
  }

  /// Update accessibility settings
  void updateSettings({
    bool? screenReader,
    bool? highContrast,
    bool? largeText,
    bool? boldText,
    bool? reduceMotion,
    double? textScale,
  }) {
    bool hasChanged = false;

    if (screenReader != null && _isScreenReaderEnabled != screenReader) {
      _isScreenReaderEnabled = screenReader;
      hasChanged = true;
    }

    if (highContrast != null && _isHighContrastEnabled != highContrast) {
      _isHighContrastEnabled = highContrast;
      hasChanged = true;
    }

    if (largeText != null && _isLargeTextEnabled != largeText) {
      _isLargeTextEnabled = largeText;
      hasChanged = true;
    }

    if (boldText != null && _isBoldTextEnabled != boldText) {
      _isBoldTextEnabled = boldText;
      hasChanged = true;
    }

    if (reduceMotion != null && _isReduceMotionEnabled != reduceMotion) {
      _isReduceMotionEnabled = reduceMotion;
      hasChanged = true;
    }

    if (textScale != null && _textScaleFactor != textScale) {
      _textScaleFactor = textScale;
      hasChanged = true;
    }

    if (hasChanged) {
      notifyListeners();
      if (kDebugMode) {
        debugPrint('Accessibility settings updated');
      }
    }
  }

  /// Get accessibility-aware text style
  TextStyle getAccessibleTextStyle({
    required TextStyle baseStyle,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    double finalFontSize = fontSize ?? baseStyle.fontSize ?? 14.0;
    FontWeight finalFontWeight = fontWeight ?? baseStyle.fontWeight ?? FontWeight.normal;

    // Apply large text setting
    if (_isLargeTextEnabled) {
      finalFontSize *= 1.3;
    }

    // Apply bold text setting
    if (_isBoldTextEnabled) {
      finalFontWeight = FontWeight.bold;
    }

    // Apply text scale factor
    finalFontSize *= _textScaleFactor;

    return baseStyle.copyWith(
      fontSize: finalFontSize,
      fontWeight: finalFontWeight,
    );
  }

  /// Get accessibility-aware color
  Color getAccessibleColor({
    required Color baseColor,
    required Color fallbackColor,
  }) {
    if (_isHighContrastEnabled) {
      // Use high contrast colors
      return _getHighContrastColor(baseColor, fallbackColor);
    }
    return baseColor;
  }

  Color _getHighContrastColor(Color baseColor, Color fallbackColor) {
    // Simple high contrast logic - can be enhanced
    final luminance = baseColor.computeLuminance();
    if (luminance > 0.5) {
      return Colors.black;
    } else {
      return Colors.white;
    }
  }

  /// Get accessibility-aware animation duration
  Duration getAccessibleDuration(Duration baseDuration) {
    if (_isReduceMotionEnabled) {
      return Duration.zero;
    }
    return baseDuration;
  }

  /// Announce to screen reader
  void announceToScreenReader(String message) {
    if (_isScreenReaderEnabled) {
      SemanticsService.announce(message, TextDirection.ltr);
    }
  }

  /// Get accessibility label for widget
  String getAccessibilityLabel(String baseLabel, {String? context}) {
    if (context != null) {
      return '$baseLabel, $context';
    }
    return baseLabel;
  }

  /// Get accessibility hint for widget
  String getAccessibilityHint(String baseHint, {String? action}) {
    if (action != null) {
      return '$baseHint. $action';
    }
    return baseHint;
  }

  /// Check if accessibility features are enabled
  bool get hasAccessibilityFeatures => 
    _isScreenReaderEnabled || 
    _isHighContrastEnabled || 
    _isLargeTextEnabled || 
    _isBoldTextEnabled || 
    _isReduceMotionEnabled ||
    _textScaleFactor != 1.0;

  /// Get accessibility report
  Map<String, dynamic> getAccessibilityReport() {
    return {
      'screenReaderEnabled': _isScreenReaderEnabled,
      'highContrastEnabled': _isHighContrastEnabled,
      'largeTextEnabled': _isLargeTextEnabled,
      'boldTextEnabled': _isBoldTextEnabled,
      'reduceMotionEnabled': _isReduceMotionEnabled,
      'textScaleFactor': _textScaleFactor,
      'hasAccessibilityFeatures': hasAccessibilityFeatures,
    };
  }
}

class _AccessibilityObserver extends WidgetsBindingObserver {
  final AccessibilityService _service;

  _AccessibilityObserver(this._service);

  @override
  void didChangeAccessibilityFeatures() {
    // Platform accessibility features changed -> tetikle
    _service.updateSettings();
  }

  @override
  void didChangeTextScaleFactor() {
    // Text scale factor changed
    final textScaleFactor = WidgetsBinding.instance.platformDispatcher.textScaleFactor;
    _service.updateSettings(textScale: textScaleFactor);
  }
}

/// Accessibility-aware widget mixin
mixin AccessibilityAwareWidget<T extends StatefulWidget> on State<T> {
  AccessibilityService get accessibilityService => AccessibilityService();

  /// Get accessible text style
  TextStyle getAccessibleTextStyle({
    required TextStyle baseStyle,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return accessibilityService.getAccessibleTextStyle(
      baseStyle: baseStyle,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get accessible color
  Color getAccessibleColor({
    required Color baseColor,
    required Color fallbackColor,
  }) {
    return accessibilityService.getAccessibleColor(
      baseColor: baseColor,
      fallbackColor: fallbackColor,
    );
  }

  /// Get accessible duration
  Duration getAccessibleDuration(Duration baseDuration) {
    return accessibilityService.getAccessibleDuration(baseDuration);
  }

  /// Announce to screen reader
  void announceToScreenReader(String message) {
    accessibilityService.announceToScreenReader(message);
  }
}

/// Accessibility-aware stateless widget mixin
mixin AccessibilityAwareStatelessWidget on StatelessWidget {
  AccessibilityService get accessibilityService => AccessibilityService();

  /// Get accessible text style
  TextStyle getAccessibleTextStyle({
    required TextStyle baseStyle,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return accessibilityService.getAccessibleTextStyle(
      baseStyle: baseStyle,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get accessible color
  Color getAccessibleColor({
    required Color baseColor,
    required Color fallbackColor,
  }) {
    return accessibilityService.getAccessibleColor(
      baseColor: baseColor,
      fallbackColor: fallbackColor,
    );
  }

  /// Get accessible duration
  Duration getAccessibleDuration(Duration baseDuration) {
    return accessibilityService.getAccessibleDuration(baseDuration);
  }

  /// Announce to screen reader
  void announceToScreenReader(String message) {
    accessibilityService.announceToScreenReader(message);
  }
}
