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
  final List<String> tags;
  final List<String> outgoingLinks;

  Note({
    required this.title, 
    required this.content, 
    required this.path, 
    required this.modified,
    this.metadata = const {},
    this.tags = const [],
    this.outgoingLinks = const [],
  });
}

class NoteService extends ChangeNotifier {
  String? _notesPath;
  List<Note> _notes = [];
  Note? _selectedNote;
  bool _isLoading = true;
  Map<String, List<Note>> _backlinks = {};
  Map<String, List<Note>> _allTags = {};
  String? _filterTag;
  String _searchQuery = "";
  List<Note> _templates = [];
  final Set<String> _autoSaveEnabledPaths = {};

  String? get notesPath => _notesPath;
  List<Note> get notes {
    List<Note> filtered = _notes;
    if (_filterTag != null) {
      filtered = filtered.where((n) => n.tags.contains(_filterTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((n) => 
        n.title.toLowerCase().contains(query) || 
        n.content.toLowerCase().contains(query)
      ).toList();
    }
    return filtered;
  }
  Note? get selectedNote => _selectedNote;
  bool get isLoading => _isLoading;
  Map<String, List<Note>> get backlinks => _backlinks;
  Map<String, List<Note>> get allTags => _allTags;
  String? get filterTag => _filterTag;
  String get searchQuery => _searchQuery;
  List<Note> get templates => _templates;

  bool isAutoSaveEnabled(String path) => _autoSaveEnabledPaths.contains(path);

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleTagFilter(String? tag) {
    if (_filterTag == tag) {
      _filterTag = null;
    } else {
      _filterTag = tag;
    }
    notifyListeners();
  }

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
              tags: noteData['tags'],
              outgoingLinks: noteData['outgoingLinks'],
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
    _buildTags();
    _scanTemplates();
    notifyListeners();
  }

  void _buildTags() {
    _allTags = {};
    for (var note in _notes) {
      for (var tag in note.tags) {
        _allTags.putIfAbsent(tag, () => []).add(note);
      }
    }
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

  Future<void> createNewNote({String? title, String? content}) async {
    if (_notesPath == null) return;
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = "${title ?? 'Untitled $timestamp'}.md";
    final defaultContent = content ?? "# New Note\n\nStart writing here...";
    
    await saveNote(filename, defaultContent);
  }

  Future<void> openDailyNote() async {
    if (_notesPath == null) return;

    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final filename = "$dateStr.md";
    
    // Check if it already exists in memory
    final existing = _notes.where((n) => n.path.endsWith(filename));
    if (existing.isNotEmpty) {
      selectNote(existing.first);
      return;
    }

    // Otherwise check file system or create
    final path = '$_notesPath/$filename';
    final file = File(path);

    if (!await file.exists()) {
      await file.writeAsString('# $dateStr\n\n#daily\n\n');
      await refreshNotes();
    }

    try {
      final note = _notes.firstWhere((n) => n.path.endsWith(filename));
      selectNote(note);
    } catch (e) {
      print("Error opening daily note: $e");
    }
  }

  Future<void> _scanTemplates() async {
    if (_notesPath == null) return;
    final templateDir = Directory('$_notesPath${Platform.pathSeparator}.templates');
    if (!await templateDir.exists()) {
      _templates = [];
      return;
    }

    final List<Note> loadedTemplates = [];
    final entities = templateDir.listSync();
    
    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.md')) {
        final content = await entity.readAsString();
        final filename = entity.path.split(Platform.pathSeparator).last;
        final noteData = _parseNoteContent(content, filename);
        
        loadedTemplates.add(Note(
          title: noteData['title'],
          content: content,
          path: entity.path,
          modified: (await entity.stat()).modified,
          metadata: noteData['metadata'],
          tags: noteData['tags'],
          outgoingLinks: noteData['outgoingLinks'],
        ));
      }
    }
    _templates = loadedTemplates;
    notifyListeners();
  }

  Future<void> deleteNote(Note note) async {
    try {
      final file = File(note.path);
      if (await file.exists()) {
        await file.delete();
        if (_selectedNote?.path == note.path) {
          _selectedNote = null;
        }
        await refreshNotes();
      }
    } catch (e) {
      print("Error deleting note: $e");
    }
  }

  Future<void> saveNote(String filename, String content) async {
    if (_notesPath == null) return;
    
    // Ensure .md extension
    if (!filename.endsWith('.md')) filename += '.md';
    
    // Normalize path to avoid double separators or slash mismatches
    final dir = Directory(_notesPath!);
    final path = File('${dir.path}${Platform.pathSeparator}$filename').path;
    
    final file = File(path);
    await file.writeAsString(content);
    await refreshNotes();
    
    // Select the newly created note
    try {
      final newNote = _notes.firstWhere(
        (n) => File(n.path).path == path, 
        orElse: () => _notes.isNotEmpty ? _notes.first : throw Exception("No notes found after saving")
      );
      selectNote(newNote);
    } catch (e) {
      print("Warning: Could not auto-select new note: $e");
    }
  }

  Future<void> updateCurrentNote(String newContent) async {
    if (_selectedNote == null) return;
    
    // Skip auto-save if not enabled for this path yet
    if (!_autoSaveEnabledPaths.contains(_selectedNote!.path)) return;

    final file = File(_selectedNote!.path);
    await file.writeAsString(newContent);
    
    // Re-parse to update title/tags in memory
    final noteData = _parseNoteContent(newContent, file.uri.pathSegments.last);

    // Optimistic update
    final index = _notes.indexWhere((n) => n.path == _selectedNote!.path);
    if (index != -1) {
      _notes[index] = Note(
        title: noteData['title'],
        content: newContent,
        path: _notes[index].path,
        modified: DateTime.now(),
        metadata: noteData['metadata'],
        tags: noteData['tags'],
        outgoingLinks: noteData['outgoingLinks'],
      );
      _selectedNote = _notes[index];
      _buildTags(); // Update global tags map
      notifyListeners();
    }
  }

  Future<void> manualSaveCurrentNote(String content) async {
    if (_selectedNote == null) return;
    
    // 1. Perform the save
    final file = File(_selectedNote!.path);
    await file.writeAsString(content);
    
    // 2. Enable auto-save for this note for future edits
    _autoSaveEnabledPaths.add(_selectedNote!.path);
    
    // 3. Refresh metadata/title (especially if user just typed an H1)
    await refreshNotes();
    
    // 4. Force selection update to reflect potential title change
    final updatedNote = _notes.firstWhere((n) => n.path == file.path, orElse: () => _notes.first);
    selectNote(updatedNote);
    
    notifyListeners();
  }

  Map<String, dynamic> _parseNoteContent(String content, String filename) {
    String title = filename;
    Map<String, dynamic> metadata = {};
    Set<String> tags = {};

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
          }
          if (metadata.containsKey('tags')) {
            final dynamic yamlTags = metadata['tags'];
            if (yamlTags is List) {
              tags.addAll(yamlTags.map((t) => t.toString()));
            } else if (yamlTags is String) {
              tags.add(yamlTags);
            }
          }
        }
      } catch (e) {
        print("Error parsing frontmatter: $e");
      }
    }

    // 2. Try H1 for Title (if no Title in Frontmatter)
    if (title == filename) {
      final RegExp h1Regex = RegExp(r'^#\s+(.*)$', multiLine: true);
      final h1Match = h1Regex.firstMatch(content);
      if (h1Match != null) {
        title = h1Match.group(1)!.trim();
      }
    }

    // 3. Extract #tags from content
    final RegExp tagRegex = RegExp(r'#(\w+)');
    final tagMatches = tagRegex.allMatches(content);
    for (var m in tagMatches) {
      tags.add(m.group(1)!);
    }

    // 4. Extract outgoing links [[Title]]
    final RegExp linkRegex = RegExp(r'\[\[(.*?)\]\]');
    final linkMatches = linkRegex.allMatches(content);
    final List<String> outgoingLinks = linkMatches.map((m) => m.group(1)!.trim()).toList();

    return {
      'title': title, 
      'metadata': metadata, 
      'tags': tags.toList(),
      'outgoingLinks': outgoingLinks.toSet().toList(), // Deduplicate
    };
  }
}