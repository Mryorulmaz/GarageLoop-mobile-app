import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

enum ErrorType {
  network,
  authentication,
  permission,
  validation,
  server,
  unknown,
}

class AppError {
  final String message;
  final ErrorType type;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppError({
    required this.message,
    required this.type,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  factory AppError.fromException(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppError) return error;

    String message = 'An unexpected error occurred';
    ErrorType type = ErrorType.unknown;

    if (error.toString().contains('network') || 
        error.toString().contains('connection') ||
        error.toString().contains('timeout')) {
      type = ErrorType.network;
      message = 'Network connection error. Please check your internet connection.';
    } else if (error.toString().contains('auth') || 
               error.toString().contains('sign in') ||
               error.toString().contains('permission')) {
      type = ErrorType.authentication;
      message = 'Authentication error. Please sign in again.';
    } else if (error.toString().contains('validation') ||
               error.toString().contains('invalid')) {
      type = ErrorType.validation;
      message = 'Invalid input. Please check your data.';
    } else if (error.toString().contains('server') ||
               error.toString().contains('500') ||
               error.toString().contains('503')) {
      type = ErrorType.server;
      message = 'Server error. Please try again later.';
    }

    return AppError(
      message: message,
      type: type,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => 'AppError($type): $message';
}

class ErrorService extends ChangeNotifier {
  AppError? _lastError;
  bool _isHandlingError = false;

  AppError? get lastError => _lastError;
  bool get isHandlingError => _isHandlingError;
  bool get hasError => _lastError != null;

  // Handle error and show appropriate UI
  Future<void> handleError(
    dynamic error, {
    BuildContext? context,
    bool showSnackBar = true,
    bool showDialog = false,
    VoidCallback? onRetry,
  }) async {
    final appError = AppError.fromException(error);
    _lastError = appError;
    _isHandlingError = true;
    notifyListeners();

    // Log error for debugging
    _logError(appError);

    // Show UI feedback
    if (context != null) {
      if (showSnackBar) {
        _showErrorSnackBar(context, appError, onRetry);
      }
      if (showDialog) {
        await _showErrorDialog(context, appError, onRetry);
      }
    }

    _isHandlingError = false;
    notifyListeners();
  }

  // Clear last error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // Show error snackbar
  void _showErrorSnackBar(BuildContext context, AppError error, VoidCallback? onRetry) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getErrorIcon(error.type),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: _getErrorColor(error.type),
      duration: const Duration(seconds: 4),
      action: onRetry != null ? SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: () {
          clearError();
          onRetry();
        },
      ) : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Show error dialog
  Future<void> _showErrorDialog(
    BuildContext context, 
    AppError error, 
    VoidCallback? onRetry,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getErrorIcon(error.type),
                color: _getErrorColor(error.type),
              ),
              const SizedBox(width: 8),
              Text(_getErrorTitle(error.type)),
            ],
          ),
          content: Text(error.message),
          actions: [
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  clearError();
                  onRetry();
                },
                child: const Text('Retry'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                clearError();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Get error icon based on type
  IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.validation:
        return Icons.error_outline;
      case ErrorType.server:
        return Icons.cloud_off;
      case ErrorType.unknown:
        return Icons.error;
    }
  }

  // Get error color based on type
  Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.permission:
        return Colors.red;
      case ErrorType.validation:
        return Colors.orange;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.unknown:
        return Colors.grey;
    }
  }

  // Get error title based on type
  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Network Error';
      case ErrorType.authentication:
        return 'Authentication Error';
      case ErrorType.permission:
        return 'Permission Error';
      case ErrorType.validation:
        return 'Validation Error';
      case ErrorType.server:
        return 'Server Error';
      case ErrorType.unknown:
        return 'Error';
    }
  }

  // Log error for debugging
  void _logError(AppError error) {
    if (kDebugMode) {
      print('=== APP ERROR ===');
      print('Type: ${error.type}');
      print('Message: ${error.message}');
      print('Code: ${error.code}');
      if (error.originalError != null) {
        print('Original Error: ${error.originalError}');
      }
      if (error.stackTrace != null) {
        print('StackTrace: ${error.stackTrace}');
      }
      print('================');
    }
  }

  // Retry mechanism
  Future<T?> retry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        if (attempts >= maxAttempts) {
          rethrow;
        }
        await Future.delayed(delay * attempts);
      }
    }
    throw Exception('Max retry attempts reached');
  }
}
