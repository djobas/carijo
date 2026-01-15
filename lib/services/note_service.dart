import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
export '../domain/models/note.dart';
import '../domain/models/note.dart';
import '../domain/repositories/note_repository.dart';

class NoteService extends ChangeNotifier {
  final NoteRepository repository;
  String? _notesPath;
  List<Note> _notes = [];
  NoteFolder? _rootFolder;
  Note? _selectedNote;
  bool _isLoading = true;
  Map<String, List<Note>> _backlinks = {};
  Map<String, List<Note>> _allTags = {};
  String? _filterTag;
  String _searchQuery = "";
  List<Note> _templates = [];
  final Set<String> _autoSaveEnabledPaths = {};

  String? get notesPath => _notesPath;
  NoteFolder? get rootFolder => _rootFolder;
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

  NoteService(this.repository) {
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
      final loadedNotes = await repository.getAllNotes(_notesPath!);
      // Sort by newest
      loadedNotes.sort((a, b) => b.modified.compareTo(a.modified));
      _notes = loadedNotes;
      
      // Build Backlinks
      _buildBacklinks();
      // Build Folder Tree
      _buildFolderTree();
    } catch (e) {
      print("Error loading notes: $e");
    }

    _isLoading = false;
    _buildTags();
    await _scanTemplates();
    notifyListeners();
  }

  Future<String?> addImageToNote(File imageFile) async {
    if (_notesPath == null) return null;
    return await repository.uploadImage(_notesPath!, imageFile);
  }

  void _buildFolderTree() {
    if (_notesPath == null) {
      _rootFolder = null;
      return;
    }

    // This logic stays here as it's about organizing the state for the UI
    final root = NoteFolder(
      name: _notesPath!.split(RegExp(r'[/\\]')).last,
      path: _notesPath!,
      subfolders: [],
      notes: [],
      isExpanded: true,
    );

    for (var note in _notes) {
      // Manual path comparison/splitting to avoid 'path' dependency in models if possible
      // but 'path' is used in note object so it's okay for now.
      // For a truly clean approach, relative path calculation could be in a utility.
      
      // Simplified relative path split
      final relativePath = note.path.substring(_notesPath!.length).replaceFirst(RegExp(r'^[/\\]'), '');
      if (relativePath.isEmpty) continue;
      
      final parts = relativePath.split(RegExp(r'[/\\]'));
      
      NoteFolder currentFolder = root;
      
      // Traverse/create subfolders
      for (int i = 0; i < parts.length - 1; i++) {
        final folderName = parts[i];
        final folderPath = "${currentFolder.path}${Platform.pathSeparator}$folderName";
        
        NoteFolder nextFolder;
        final existing = currentFolder.subfolders.where((f) => f.name == folderName);
        
        if (existing.isNotEmpty) {
          nextFolder = existing.first;
        } else {
          nextFolder = NoteFolder(
            name: folderName,
            path: folderPath,
            subfolders: [],
            notes: [],
          );
          currentFolder.subfolders.add(nextFolder);
        }
        currentFolder = nextFolder;
      }
      
      currentFolder.notes.add(note);
    }
    
    // Sort folders and notes
    _sortFolder(root);
    
    _rootFolder = root;
  }

  void _sortFolder(NoteFolder folder) {
    folder.subfolders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    folder.notes.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    for (var sub in folder.subfolders) {
      _sortFolder(sub);
    }
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

  List<BacklinkMatch> getBacklinksFor(Note note) {
    final filename = note.path.split(RegExp(r'[/\\]')).last.replaceAll('.md', '');
    final titlesToMatch = [note.title, filename];
    final results = <BacklinkMatch>[];
    
    for (var otherNote in _notes) {
      if (otherNote.path == note.path) continue;
      
      for (var title in titlesToMatch) {
        final linkPattern = '[[${title}]]';
        if (otherNote.content.contains(linkPattern)) {
          // Extract snippet
          final index = otherNote.content.indexOf(linkPattern);
          final start = (index - 50).clamp(0, otherNote.content.length);
          final end = (index + linkPattern.length + 50).clamp(0, otherNote.content.length);
          
          String snippet = otherNote.content.substring(start, end).replaceAll('\n', ' ');
          if (start > 0) snippet = '...$snippet';
          if (end < otherNote.content.length) snippet = '$snippet...';
          
          results.add(BacklinkMatch(note: otherNote, snippet: snippet));
          break; // Found a link in this note, move to next note
        }
      }
    }
    
    return results;
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return [];
    
    final results = <MapEntry<Note, double>>[];
    
    for (var note in _notes) {
      double score = fuzzyScore(query, note.title) * 2.0; // Title matches weigh more
      score = score > 0 ? score : fuzzyScore(query, note.content);
      
      if (score > 0) {
        results.add(MapEntry(note, score));
      }
    }
    
    results.sort((a, b) => b.value.compareTo(a.value));
    return results.map((e) => e.key).toList();
  }

  double fuzzyScore(String query, String target) {
    if (query.isEmpty) return 1.0;
    query = query.toLowerCase();
    target = target.toLowerCase();
    
    if (target.contains(query)) {
      if (target.startsWith(query)) return 1.0;
      return 0.8;
    }
    
    int queryIdx = 0;
    int targetIdx = 0;
    int matches = 0;
    int gaps = 0;
    
    while (queryIdx < query.length && targetIdx < target.length) {
      if (query[queryIdx] == target[targetIdx]) {
        queryIdx++;
        matches++;
      } else {
        gaps++;
      }
      targetIdx++;
    }
    
    if (matches == query.length) {
      return 0.5 / (1 + gaps * 0.1);
    }
    
    return 0.0;
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
    
    final path = "${_notesPath}${Platform.pathSeparator}$filename";
    await repository.saveNote(path, defaultContent);
    await refreshNotes();
    
    // Select the newly created note
    try {
      final newNote = _notes.firstWhere((n) => n.path == path);
      selectNote(newNote);
    } catch (_) {}
  }

  Future<void> createFromTemplate(Note template, String newNoteTitle) async {
    if (_notesPath == null) return;
    
    String content = template.content;
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    content = content.replaceAll('{{title}}', newNoteTitle);
    content = content.replaceAll('{{date}}', dateStr);
    
    final filename = newNoteTitle.endsWith('.md') ? newNoteTitle : '$newNoteTitle.md';
    final path = "${_notesPath}${Platform.pathSeparator}$filename";
    
    await repository.saveNote(path, content);
    await refreshNotes();
    
    try {
      final newNote = _notes.firstWhere((n) => n.path == path);
      selectNote(newNote);
    } catch (_) {}
  }

  Future<void> openDailyNote() async {
    if (_notesPath == null) return;

    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final filename = "$dateStr.md";
    
    final existing = _notes.where((n) => n.path.endsWith(filename));
    if (existing.isNotEmpty) {
      selectNote(existing.first);
      return;
    }

    final path = '$_notesPath${Platform.pathSeparator}$filename';
    final file = File(path);

    if (!await file.exists()) {
      await repository.saveNote(path, '# $dateStr\n\n#daily\n\n');
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
    _templates = await repository.getTemplates(_notesPath!);
    notifyListeners();
  }

  Future<void> deleteNote(Note note) async {
    try {
      await repository.deleteNote(note.path);
      if (_selectedNote?.path == note.path) {
        _selectedNote = null;
      }
      await refreshNotes();
    } catch (e) {
      print("Error deleting note: $e");
    }
  }

  Future<void> saveNote(String filename, String content) async {
    if (_notesPath == null) return;
    
    if (!filename.endsWith('.md')) filename += '.md';
    final path = '$_notesPath${Platform.pathSeparator}$filename';
    
    await repository.saveNote(path, content);
    await refreshNotes();
    
    try {
      final newNote = _notes.firstWhere((n) => n.path == path);
      selectNote(newNote);
    } catch (_) {}
  }

  Future<void> updateCurrentNote(String newContent) async {
    if (_selectedNote == null) return;
    if (!_autoSaveEnabledPaths.contains(_selectedNote!.path)) return;

    await repository.saveNote(_selectedNote!.path, newContent);
    
    // Optimistic update
    final index = _notes.indexWhere((n) => n.path == _selectedNote!.path);
    if (index != -1) {
      _notes[index] = Note.fromContent(
        content: newContent,
        path: _selectedNote!.path,
        modified: DateTime.now(),
      );
      _selectedNote = _notes[index];
      _buildTags();
      notifyListeners();
    }
  }

  Future<void> manualSaveCurrentNote(String content) async {
    if (_selectedNote == null) return;
    
    await repository.saveNote(_selectedNote!.path, content);
    _autoSaveEnabledPaths.add(_selectedNote!.path);
    
    await refreshNotes();
    
    final updatedNote = _notes.firstWhere((n) => n.path == _selectedNote!.path, orElse: () => _notes.first);
    selectNote(updatedNote);
    
    notifyListeners();
  }
}
