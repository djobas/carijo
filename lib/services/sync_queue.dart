import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/note.dart';
import 'logger_service.dart';
import 'connectivity_service.dart';

/// Represents a pending sync operation to be executed when online.
class SyncOperation {
  final String id;
  final SyncOperationType type;
  final String noteId;
  final String? content;
  final DateTime createdAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.noteId,
    this.content,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'noteId': noteId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'],
    type: SyncOperationType.values.byName(json['type']),
    noteId: json['noteId'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Types of sync operations that can be queued.
enum SyncOperationType {
  /// Publish a note to the remote server
  publish,

  /// Delete a note from the remote server
  delete,

  /// Full sync of all notes
  fullSync,
}

/// Manages a queue of pending sync operations for offline support.
///
/// When the device is offline, sync operations are queued and persisted
/// to SharedPreferences. When connectivity is restored, the queue is
/// automatically processed with exponential backoff on failures.
///
/// Example usage:
/// ```dart
/// final queue = SyncQueue(connectivityService);
/// await queue.enqueue(SyncOperationType.publish, note);
/// ```
class SyncQueue extends ChangeNotifier {
  static const String _storageKey = 'sync_queue_operations';
  static const int _maxRetries = 3;
  
  final ConnectivityService _connectivity;
  final List<SyncOperation> _queue = [];
  bool _isProcessing = false;
  Timer? _retryTimer;
  
  /// Callback function to execute a sync operation.
  Future<void> Function(SyncOperation)? onExecute;

  /// The current queue of pending operations.
  List<SyncOperation> get queue => List.unmodifiable(_queue);

  /// Whether the queue is currently being processed.
  bool get isProcessing => _isProcessing;

  /// Number of pending operations in the queue.
  int get pendingCount => _queue.length;

  /// Whether there are pending operations.
  bool get hasPending => _queue.isNotEmpty;

  /// Creates a SyncQueue with the given [ConnectivityService].
  ///
  /// Automatically loads any persisted queue from previous sessions
  /// and sets up connectivity change listeners.
  SyncQueue(this._connectivity) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadQueue();
    _connectivity.addListener(_onConnectivityChanged);
    
    // If we're online and have pending items, process them
    if (_connectivity.isOnline && _queue.isNotEmpty) {
      _processQueue();
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _queue.isNotEmpty && !_isProcessing) {
      LoggerService.info('Connectivity restored, processing sync queue');
      _processQueue();
    }
  }

  /// Enqueues a sync operation to be processed when online.
  ///
  /// If currently online, the operation will be processed immediately.
  /// Otherwise, it's persisted and will be processed when connectivity
  /// is restored.
  Future<void> enqueue(SyncOperationType type, Note note) async {
    final operation = SyncOperation(
      id: '${note.path}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      noteId: note.path,
      content: type == SyncOperationType.publish ? note.content : null,
      createdAt: DateTime.now(),
    );

    // Conflict Detection / Redundancy Check (Last Write Wins)
    if (type != SyncOperationType.fullSync) {
      _queue.removeWhere((op) => op.noteId == note.path && op.type == type);
      LoggerService.info('Removed redundant sync operation for ${note.title}');
    }

    _queue.add(operation);
    await _saveQueue();
    notifyListeners();

    LoggerService.info('Enqueued sync operation: ${type.name} for ${note.title}');

    if (_connectivity.isOnline && !_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    notifyListeners();

    try {
      while (_queue.isNotEmpty && _connectivity.isOnline) {
        final operation = _queue.first;
        
        try {
          await _executeOperation(operation);
          _queue.removeAt(0);
          await _saveQueue();
          notifyListeners();
          
          LoggerService.info('Sync operation completed: ${operation.type.name}');
        } catch (e) {
          operation.retryCount++;
          
          if (operation.retryCount >= _maxRetries) {
            LoggerService.error('Sync operation failed after $_maxRetries retries', error: e);
            _queue.removeAt(0);
            await _saveQueue();
          } else {
            // Exponential backoff
            final delay = Duration(seconds: operation.retryCount * operation.retryCount * 5);
            LoggerService.warning('Sync operation failed, retry ${operation.retryCount}/$_maxRetries in ${delay.inSeconds}s');
            
            _retryTimer?.cancel();
            _retryTimer = Timer(delay, () {
              if (_connectivity.isOnline) _processQueue();
            });
            break;
          }
        }
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _executeOperation(SyncOperation operation) async {
    if (onExecute != null) {
      await onExecute!(operation);
    } else {
      // Fallback for testing/simulation
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _queue.map((op) => op.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      LoggerService.error('Failed to save sync queue', error: e);
    }
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonList = jsonDecode(jsonString) as List;
        _queue.clear();
        _queue.addAll(jsonList.map((json) => SyncOperation.fromJson(json)));
        notifyListeners();
        
        LoggerService.info('Loaded ${_queue.length} pending sync operations');
      }
    } catch (e) {
      LoggerService.error('Failed to load sync queue', error: e);
    }
  }

  /// Clears all pending operations from the queue.
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
    notifyListeners();
    LoggerService.info('Sync queue cleared');
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    _retryTimer?.cancel();
    super.dispose();
  }
}
