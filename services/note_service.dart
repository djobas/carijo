import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Note {
  final String title;
  final String content;
  final String path;
  final DateTime modified;

  Note({required this.title, required this.content, required this.path, required this.modified});
}

class NoteService extends ChangeNotifier {
  String? _notesPath;
  List<Note> _notes = [];
  Note? _selectedNote;
  bool _isLoading = true;

  String? get notesPath => _notesPath;
  List<Note> get notes => _notes;
  Note? get selectedNote => _selectedNote;
  bool get isLoading => _isLoading;

  NoteService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _notesPath = prefs.getString('notes_path');
    if (_notesPath != null) {
      await refreshNotes();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setNotesPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_path', path);
    _notesPath = path;
    await refreshNotes();
  }

  Future<void> refreshNotes() async {
    if (_notesPath == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final dir = Directory(_notesPath!);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = dir.listSync();
        final List<Note> loadedNotes = [];

        for (var entity in entities) {
          if (entity is File && entity.path.endsWith('.md')) {
            final content = await entity.readAsString();
            final stat = await entity.stat();
            // Simple title extraction: filename or first line #
            final filename = entity.uri.pathSegments.last;
            
            loadedNotes.add(Note(
              title: filename, 
              content: content, 
              path: entity.path,
              modified: stat.modified,
            ));
          }
        }
        // Sort by newest
        loadedNotes.sort((a, b) => b.modified.compareTo(a.modified));
        _notes = loadedNotes;
      }
    } catch (e) {
      print("Error loading notes: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectNote(Note note) {
    _selectedNote = note;
    notifyListeners();
  }

  Future<void> saveNote(String filename, String content) async {
    if (_notesPath == null) return;
    
    // Ensure .md extension
    if (!filename.endsWith('.md')) filename += '.md';
    
    final path = '$_notesPath${Platform.pathSeparator}$filename';
    final file = File(path);
    await file.writeAsString(content);
    await refreshNotes();
    
    // Select the newly created note
    final newNote = _notes.firstWhere((n) => n.path == path, orElse: () => _notes.first);
    selectNote(newNote);
  }

  Future<void> updateCurrentNote(String newContent) async {
    if (_selectedNote == null) return;
    final file = File(_selectedNote!.path);
    await file.writeAsString(newContent);
    // Optimistic update
    final index = _notes.indexWhere((n) => n.path == _selectedNote!.path);
    if (index != -1) {
      _notes[index] = Note(
        title: _notes[index].title,
        content: newContent,
        path: _notes[index].path,
        modified: DateTime.now()
      );
      _selectedNote = _notes[index];
      notifyListeners();
    }
  }
}