import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'note_service.dart';
import '../domain/models/note.dart';

class SupabaseService extends ChangeNotifier {
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastError;
  String? get lastError => _lastError;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  static const String keyUrl = 'supabase_url';
  static const String keyAnonKey = 'supabase_anon_key';

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
      // If already initialized by Supabase.initialize, we don't need to do it again
      // But we need to handle potential re-initialization if config changes
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
      final client = Supabase.instance.client;
      
      // Upsert note by path (unique identifier)
      await client.from('notes').upsert({
        'title': note.title,
        'content': note.content,
        'path': note.path,
        'modified_at': note.modified.toIso8601String(),
        'tags': note.tags,
        'metadata': note.metadata,
        'is_published': note.isPublished,
        'category': note.category,
        'slug': note.slug,
      }, onConflict: 'path');

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
      final client = Supabase.instance.client;
      
      final List<Map<String, dynamic>> data = notes.map((note) => {
        'title': note.title,
        'content': note.content,
        'path': note.path,
        'modified_at': note.modified.toIso8601String(),
        'tags': note.tags,
        'metadata': note.metadata,
        'is_published': note.isPublished,
        'category': note.category,
        'slug': note.slug,
      }).toList();

      await client.from('notes').upsert(data, onConflict: 'path');
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
