import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum LoadingType {
  fullScreen,
  overlay,
  button,
  inline,
}

class LoadingState {
  final bool isLoading;
  final String? message;
  final LoadingType type;
  final String? id;

  LoadingState({
    required this.isLoading,
    this.message,
    this.type = LoadingType.overlay,
    this.id,
  });

  LoadingState copyWith({
    bool? isLoading,
    String? message,
    LoadingType? type,
    String? id,
  }) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
      type: type ?? this.type,
      id: id ?? this.id,
    );
  }
}

class LoadingService extends ChangeNotifier {
  final Map<String, LoadingState> _loadingStates = {};
  bool _isGlobalLoading = false;
  String? _globalLoadingMessage;

  // Global loading state
  bool get isGlobalLoading => _isGlobalLoading;
  String? get globalLoadingMessage => _globalLoadingMessage;

  // Check if any loading is active
  bool get hasAnyLoading => _isGlobalLoading || _loadingStates.values.any((state) => state.isLoading);

  // Get loading state by ID
  LoadingState? getLoadingState(String id) => _loadingStates[id];

  // Check if specific loading is active
  bool isLoading(String id) => _loadingStates[id]?.isLoading ?? false;

  // Show global loading
  void showGlobalLoading([String? message]) {
    _isGlobalLoading = true;
    _globalLoadingMessage = message;
    notifyListeners();
  }

  // Hide global loading
  void hideGlobalLoading() {
    _isGlobalLoading = false;
    _globalLoadingMessage = null;
    notifyListeners();
  }

  // Show loading with ID
  void showLoading(
    String id, {
    String? message,
    LoadingType type = LoadingType.overlay,
  }) {
    _loadingStates[id] = LoadingState(
      isLoading: true,
      message: message,
      type: type,
      id: id,
    );
    notifyListeners();
  }

  // Hide loading with ID
  void hideLoading(String id) {
    _loadingStates.remove(id);
    notifyListeners();
  }

  // Show button loading
  void showButtonLoading(String buttonId, [String? message]) {
    showLoading(
      buttonId,
      message: message,
      type: LoadingType.button,
    );
  }

  // Hide button loading
  void hideButtonLoading(String buttonId) {
    hideLoading(buttonId);
  }

  // Show inline loading
  void showInlineLoading(String id, [String? message]) {
    showLoading(
      id,
      message: message,
      type: LoadingType.inline,
    );
  }

  // Hide inline loading
  void hideInlineLoading(String id) {
    hideLoading(id);
  }

  // Clear all loading states
  void clearAll() {
    _loadingStates.clear();
    _isGlobalLoading = false;
    _globalLoadingMessage = null;
    notifyListeners();
  }

  // Loading widget builder
  Widget buildLoadingWidget({
    required String id,
    required Widget child,
    Widget? loadingWidget,
    String? message,
  }) {
    return Consumer<LoadingService>(
      builder: (context, loadingService, _) {
        final loadingState = loadingService.getLoadingState(id);
        final isLoading = loadingState?.isLoading ?? false;

        if (!isLoading) return child;

        switch (loadingState?.type ?? LoadingType.overlay) {
          case LoadingType.fullScreen:
            return _buildFullScreenLoading(message ?? loadingState?.message);
          case LoadingType.overlay:
            return Stack(
              children: [
                child,
                _buildOverlayLoading(message ?? loadingState?.message),
              ],
            );
          case LoadingType.button:
            return _buildButtonLoading(child, message ?? loadingState?.message);
          case LoadingType.inline:
            return _buildInlineLoading(child, message ?? loadingState?.message);
        }
      },
    );
  }

  // Full screen loading
  Widget _buildFullScreenLoading(String? message) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Overlay loading
  Widget _buildOverlayLoading(String? message) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Button loading
  Widget _buildButtonLoading(Widget child, String? message) {
    return Stack(
      children: [
        Opacity(
          opacity: 0.6,
          child: child,
        ),
        Positioned.fill(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Inline loading
  Widget _buildInlineLoading(Widget child, String? message) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
        if (message != null) ...[
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  // Global loading overlay
  Widget buildGlobalLoadingOverlay(Widget child) {
    return Consumer<LoadingService>(
      builder: (context, loadingService, _) {
        if (!loadingService.isGlobalLoading) return child;

        return Stack(
          children: [
            child,
            _buildOverlayLoading(loadingService.globalLoadingMessage),
          ],
        );
      },
    );
  }
}
