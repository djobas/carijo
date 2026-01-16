import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Log severity levels
enum LogLevel { debug, info, warning, error }

/// A single log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String toLogLine() {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp);
    final levelStr = level.name.toUpperCase().padRight(7);
    var line = '[$ts] $levelStr $message';
    if (error != null) line += '\n  ERROR: $error';
    if (stackTrace != null) line += '\n  STACK: $stackTrace';
    return line;
  }

  @override
  String toString() => toLogLine();
}

/// Centralized logging service with file persistence.
/// 
/// Features:
/// - Four log levels: debug, info, warning, error
/// - In-memory circular buffer (last 500 entries)
/// - File persistence with 5MB limit and rotation
/// - Export functionality for debugging
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  /// Maximum log entries to keep in memory
  static const int _maxMemoryEntries = 500;
  
  /// Maximum log file size in bytes (5MB)
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;
  
  /// Log filename
  static const String _logFileName = 'carijo_notes.log';
  static const String _logFileNameOld = 'carijo_notes.old.log';

  final List<LogEntry> _logs = [];
  File? _logFile;
  bool _initialized = false;

  /// Initialize the logger with file persistence
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final appDir = await getApplicationSupportDirectory();
      _logFile = File('${appDir.path}/$_logFileName');
      
      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      
      _initialized = true;
      info('LoggerService initialized');
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  /// Log a debug message (development only)
  static void debug(String message) {
    _instance._log(LogLevel.debug, message);
  }

  /// Log an info message
  static void info(String message) {
    _instance._log(LogLevel.info, message);
  }

  /// Log a warning message
  static void warning(String message, {Object? error}) {
    _instance._log(LogLevel.warning, message, error: error);
  }

  /// Log an error message
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _instance._log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  void _log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    // Add to memory buffer
    _logs.add(entry);
    if (_logs.length > _maxMemoryEntries) {
      _logs.removeAt(0);
    }

    // Always print to console in debug mode
    if (kDebugMode) {
      debugPrint(entry.toLogLine());
    }

    // Write to file asynchronously
    _writeToFile(entry);
  }

  Future<void> _writeToFile(LogEntry entry) async {
    if (_logFile == null) return;
    
    try {
      // Check file size and rotate if needed
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxFileSizeBytes) {
          await _rotateLogFile();
        }
      }
      
      // Append log entry
      await _logFile!.writeAsString(
        '${entry.toLogLine()}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  Future<void> _rotateLogFile() async {
    if (_logFile == null) return;
    
    try {
      final dir = _logFile!.parent.path;
      final oldFile = File('$dir/$_logFileNameOld');
      
      // Delete old backup if exists
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
      
      // Rename current to old
      await _logFile!.rename(oldFile.path);
      
      // Create new log file
      _logFile = File('$dir/$_logFileName');
      await _logFile!.create();
      
      info('Log file rotated');
    } catch (e) {
      debugPrint('Failed to rotate log file: $e');
    }
  }

  /// Get recent log entries from memory
  List<LogEntry> getRecentLogs([int count = 100]) {
    final start = _logs.length > count ? _logs.length - count : 0;
    return _logs.sublist(start);
  }

  /// Get all logs from memory
  List<LogEntry> getAllLogs() => List.unmodifiable(_logs);

  /// Export logs to a specified file path
  Future<String?> exportLogs(String destinationPath) async {
    try {
      final exportFile = File(destinationPath);
      final buffer = StringBuffer();
      
      buffer.writeln('=== Carijó Notes Log Export ===');
      buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
      buffer.writeln('Entries: ${_logs.length}');
      buffer.writeln('==============================\n');
      
      for (final entry in _logs) {
        buffer.writeln(entry.toLogLine());
      }
      
      await exportFile.writeAsString(buffer.toString());
      return exportFile.path;
    } catch (e) {
      error('Failed to export logs', error: e);
      return null;
    }
  }

  /// Get the current log file path
  String? get logFilePath => _logFile?.path;

  /// Clear all in-memory logs
  void clearMemoryLogs() {
    _logs.clear();
    info('Memory logs cleared');
  }
}
