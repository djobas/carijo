import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/note.dart';
import '../domain/repositories/remote_note_repository.dart';
import '../domain/use_cases/sync_notes_use_case.dart';

class SupabaseService extends ChangeNotifier {
  final RemoteNoteRepository repository;
  final SyncNotesUseCase syncUseCase;

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
  });

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(keyUrl);
    final anonKey = prefs.getString(keyAnonKey);

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
    await prefs.setString(keyAnonKey, anonKey);
    await initialize();
  }

  Future<void> publishNote(Note note) async {
    if (!_initialized) throw Exception("Supabase not initialized");
    
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      await syncUseCase.publishSingle(note);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
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
