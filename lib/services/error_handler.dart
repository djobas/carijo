import 'package:flutter/material.dart';
import 'logger_service.dart';

/// Severity levels for user-facing errors
enum ErrorSeverity { info, warning, error }

/// Represents an error that can be displayed to the user
class AppError {
  final String userMessage;
  final String? technicalMessage;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final VoidCallback? retryAction;

  AppError({
    required this.userMessage,
    this.technicalMessage,
    this.severity = ErrorSeverity.error,
    DateTime? timestamp,
    this.retryAction,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Centralized error handler for displaying user-friendly error messages.
///
/// Use this service to report errors that should be shown to the user.
/// Subscribe to this ChangeNotifier to display error UI (e.g., SnackBars).
class ErrorHandler extends ChangeNotifier {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  AppError? _lastError;
  final List<AppError> _errorHistory = [];

  /// The most recent error, null if no error or cleared
  AppError? get lastError => _lastError;

  /// History of recent errors (last 50)
  List<AppError> get errorHistory => List.unmodifiable(_errorHistory);

  /// Report an error to be displayed to the user
  void reportError({
    required String userMessage,
    String? technicalMessage,
    ErrorSeverity severity = ErrorSeverity.error,
    Object? error,
    VoidCallback? retryAction,
  }) {
    final appError = AppError(
      userMessage: userMessage,
      technicalMessage: technicalMessage ?? error?.toString(),
      severity: severity,
      retryAction: retryAction,
    );

    _lastError = appError;
    _errorHistory.add(appError);
    
    // Keep only last 50 errors
    if (_errorHistory.length > 50) {
      _errorHistory.removeAt(0);
    }

    // Also log to LoggerService
    switch (severity) {
      case ErrorSeverity.info:
        LoggerService.info(userMessage);
        break;
      case ErrorSeverity.warning:
        LoggerService.warning(userMessage, error: error);
        break;
      case ErrorSeverity.error:
        LoggerService.error(userMessage, error: error);
        break;
    }

    notifyListeners();
  }

  /// Report a warning (less severe than error)
  void reportWarning(String message, {Object? error}) {
    reportError(
      userMessage: message,
      severity: ErrorSeverity.warning,
      error: error,
    );
  }

  /// Report an info message (for non-critical notifications)
  void reportInfo(String message) {
    reportError(
      userMessage: message,
      severity: ErrorSeverity.info,
    );
  }

  /// Clear the current error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Clear all error history
  void clearHistory() {
    _errorHistory.clear();
    notifyListeners();
  }
}
