import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/error_handler.dart';
import '../services/theme_service.dart';

/// A widget that listens to ErrorHandler and displays SnackBars for errors.
/// 
/// Place this widget high in your widget tree (e.g., wrapping your main content).
class ErrorSnackbarListener extends StatefulWidget {
  final Widget child;

  const ErrorSnackbarListener({super.key, required this.child});

  @override
  State<ErrorSnackbarListener> createState() => _ErrorSnackbarListenerState();
}

class _ErrorSnackbarListenerState extends State<ErrorSnackbarListener> {
  @override
  void initState() {
    super.initState();
    // Listen to error handler changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ErrorHandler().addListener(_onError);
    });
  }

  @override
  void dispose() {
    ErrorHandler().removeListener(_onError);
    super.dispose();
  }

  void _onError() {
    final error = ErrorHandler().lastError;
    if (error != null && mounted) {
      _showErrorSnackbar(error);
      // Clear after showing to prevent showing again on rebuild
      ErrorHandler().clearError();
    }
  }

  void _showErrorSnackbar(AppError error) {
    final theme = Provider.of<ThemeService>(context, listen: false).theme;
    
    final Color backgroundColor;
    final IconData icon;
    
    switch (error.severity) {
      case ErrorSeverity.info:
        backgroundColor = theme.accent.withValues(alpha: 0.9);
        icon = Icons.info_outline;
        break;
      case ErrorSeverity.warning:
        backgroundColor = Colors.orange.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case ErrorSeverity.error:
        backgroundColor = Colors.red.shade700;
        icon = Icons.error_outline;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.userMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: error.severity == ErrorSeverity.error 
          ? const Duration(seconds: 6) 
          : const Duration(seconds: 4),
      action: error.retryAction != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: error.retryAction!,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A simple mixin that provides quick access to error reporting.
/// 
/// Use in StatefulWidget states that need to report errors:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with ErrorReporterMixin {
///   void _doSomething() {
///     try {
///       // ...
///     } catch (e) {
///       reportError("Operation failed", error: e);
///     }
///   }
/// }
/// ```
mixin ErrorReporterMixin<T extends StatefulWidget> on State<T> {
  void reportError(String message, {Object? error, VoidCallback? retry}) {
    ErrorHandler().reportError(
      userMessage: message,
      error: error,
      retryAction: retry,
    );
  }

  void reportWarning(String message, {Object? error}) {
    ErrorHandler().reportWarning(message, error: error);
  }

  void reportInfo(String message) {
    ErrorHandler().reportInfo(message);
  }
}
