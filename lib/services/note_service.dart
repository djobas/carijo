import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

class Note {
  final String title;
  final String content;
  final String path;
  final DateTime modified;
  final Map<String, dynamic> metadata;

  Note({
    required this.title, 
    required this.content, 
    required this.path, 
    required this.modified,
    this.metadata = const {},
  });
}

class NoteService extends ChangeNotifier {
  String? _notesPath;
  List<Note> _notes = [];
  Note? _selectedNote;
  bool _isLoading = true;
  Map<String, List<Note>> _backlinks = {};

  String? get notesPath => _notesPath;
  List<Note> get notes => _notes;
  Note? get selectedNote => _selectedNote;
  bool get isLoading => _isLoading;
  Map<String, List<Note>> get backlinks => _backlinks;

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
            
            // Extract Frontmatter and Title
            final noteData = _parseNoteContent(content, entity.uri.pathSegments.last);
            
            loadedNotes.add(Note(
              title: noteData['title'], 
              content: content, 
              path: entity.path,
              modified: stat.modified,
              metadata: noteData['metadata'],
            ));
          }
        }
        // Sort by newest
        loadedNotes.sort((a, b) => b.modified.compareTo(a.modified));
        _notes = loadedNotes;
        
        // Build Backlinks
        _buildBacklinks();
      }
    } catch (e) {
      print("Error loading notes: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void _buildBacklinks() {
    _backlinks = {};
    final linkRegex = RegExp(r'\[\[(.*?)\]\]');

    for (var note in _notes) {
      final matches = linkRegex.allMatches(note.content);
      for (var match in matches) {
        final targetTitle = match.group(1)!.trim();
        if (!_backlinks.containsKey(targetTitle)) {
          _backlinks[targetTitle] = [];
        }
        // Avoid duplicates in backlinks (if Note A links to Note B twice)
        if (!_backlinks[targetTitle]!.any((n) => n.path == note.path)) {
          _backlinks[targetTitle]!.add(note);
        }
      }
    }
  }

  List<Note> getBacklinksFor(Note note) {
    // Check by title and by filename (without .md)
    final filename = note.path.split(Platform.pathSeparator).last.replaceAll('.md', '');
    final linksById = _backlinks[note.title] ?? [];
    final linksByFile = _backlinks[filename] ?? [];
    
    // Combine and unique
    final allLinks = [...linksById, ...linksByFile];
    final seenPaths = <String>{};
    return allLinks.where((n) => seenPaths.add(n.path)).toList();
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return [];
    
    return _notes.where((note) {
      final inTitle = note.title.toLowerCase().contains(query.toLowerCase());
      final inContent = note.content.toLowerCase().contains(query.toLowerCase());
      return inTitle || inContent;
    }).toList();
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
        modified: DateTime.now(),
        metadata: _notes[index].metadata,
      );
      _selectedNote = _notes[index];
      notifyListeners();
    }
  }

  Map<String, dynamic> _parseNoteContent(String content, String filename) {
    String title = filename;
    Map<String, dynamic> metadata = {};

    // 1. Try Frontmatter
    final RegExp frontmatterRegex = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n');
    final match = frontmatterRegex.firstMatch(content);

    if (match != null) {
      try {
        final yamlStr = match.group(1);
        final yaml = loadYaml(yamlStr!);
        if (yaml is Map) {
          metadata = Map<String, dynamic>.from(yaml);
          if (metadata.containsKey('title')) {
            title = metadata['title'].toString();
            return {'title': title, 'metadata': metadata};
          }
        }
      } catch (e) {
        print("Error parsing frontmatter: $e");
      }
    }

    // 2. Try H1
    final RegExp h1Regex = RegExp(r'^#\s+(.*)$', multiLine: true);
    final h1Match = h1Regex.firstMatch(content);
    if (h1Match != null) {
      title = h1Match.group(1)!.trim();
    }

    return {'title': title, 'metadata': metadata};
  }
}