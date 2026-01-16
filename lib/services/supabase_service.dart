import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/models/note.dart';
import '../domain/repositories/remote_note_repository.dart';
import '../domain/use_cases/sync_notes_use_case.dart';
import 'sync_queue.dart';

class SupabaseService extends ChangeNotifier {
  final RemoteNoteRepository repository;
  final SyncNotesUseCase syncUseCase;
  final SyncQueue syncQueue;
  final _secureStorage = const FlutterSecureStorage();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastError;
  String? get lastError => _lastError;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  static const String keyUrl = 'supabase_url';
  static const String keyAnonKey = 'supabase_anon_key';

  SupabaseService({
    required this.repository,
    required this.syncUseCase,
    required this.syncQueue,
  }) {
    _setupSyncQueue();
  }

  void _setupSyncQueue() {
    syncQueue.onExecute = (operation) async {
      final note = Note(
        title: operation.noteId.split(RegExp(r'[/\\]')).last, // Minimalist note for sync
        content: operation.content ?? '',
        path: operation.noteId,
        modified: DateTime.now(),
      );

      if (operation.type == SyncOperationType.publish) {
        await syncUseCase.publishSingle(note);
      } else if (operation.type == SyncOperationType.delete) {
        // Implement remote delete if needed
      }
    };
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(keyUrl);
    final anonKey = await _secureStorage.read(key: keyAnonKey);

    if (url == null || anonKey == null || url.isEmpty || anonKey.isEmpty) {
      _initialized = false;
      notifyListeners();
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _initialized = true;
    } catch (e) {
      // Probably already initialized
      _initialized = true;
    }
    notifyListeners();
  }

  Future<void> saveConfig(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUrl, url);
    await _secureStorage.write(key: keyAnonKey, value: anonKey);
    await initialize();
  }

  Future<void> publishNote(Note note) async {
    if (!_initialized) throw Exception("Supabase not initialized");
    
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      if (syncQueue.pendingCount > 0) {
        // Queue has priority, add this to queue
        await syncQueue.enqueue(SyncOperationType.publish, note);
      } else {
        await syncUseCase.publishSingle(note);
      }
    } catch (e) {
      LoggerService.warning('Direct publish failed, enqueuing for background sync: $e');
      await syncQueue.enqueue(SyncOperationType.publish, note);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncAll(List<Note> notes) async {
    if (!_initialized) throw Exception("Supabase not initialized");

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      await syncUseCase(notes);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
