import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
export '../domain/models/note.dart';
import '../domain/models/note.dart';
import '../domain/repositories/note_repository.dart';
import '../domain/use_cases/search_notes_use_case.dart';
import '../domain/use_cases/get_backlinks_use_case.dart';
import '../domain/use_cases/save_note_use_case.dart';

class NoteService extends ChangeNotifier {
  final NoteRepository repository;
  final SearchNotesUseCase searchUseCase;
  final GetBacklinksUseCase getBacklinksUseCase;
  final SaveNoteUseCase saveNoteUseCase;

  String? _notesPath;
  List<Note> _notes = [];
  NoteFolder? _rootFolder;
  Note? _selectedNote;
  bool _isLoading = true;
  Map<String, List<Note>> _allTags = {};
  String? _filterTag;
  String _searchQuery = "";
  List<Note> _templates = [];
  final Set<String> _autoSaveEnabledPaths = {};

  String? get notesPath => _notesPath;
  NoteFolder? get rootFolder => _rootFolder;
  
  List<Note> get notes {
    return searchUseCase(
      notes: _notes,
      query: _searchQuery,
      filterTag: _filterTag,
    );
  }

  Note? get selectedNote => _selectedNote;
  bool get isLoading => _isLoading;
  Map<String, List<Note>> get allTags => _allTags;
  String? get filterTag => _filterTag;
  String get searchQuery => _searchQuery;
  List<Note> get templates => _templates;

  NoteService({
    required this.repository,
    required this.searchUseCase,
    required this.getBacklinksUseCase,
    required this.saveNoteUseCase,
  }) {
    _init();
  }

  bool isAutoSaveEnabled(String path) => _autoSaveEnabledPaths.contains(path);

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleTagFilter(String? tag) {
    _filterTag = (_filterTag == tag) ? null : tag;
    notifyListeners();
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
      loadedNotes.sort((a, b) => b.modified.compareTo(a.modified));
      _notes = loadedNotes;
      _buildFolderTree();
    } catch (e) {
      debugPrint("Error loading notes: $e");
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

    final root = NoteFolder(
      name: _notesPath!.split(RegExp(r'[/\\]')).last,
      path: _notesPath!,
      subfolders: [],
      notes: [],
      isExpanded: true,
    );

    for (var note in _notes) {
      final relativePath = note.path.substring(_notesPath!.length).replaceFirst(RegExp(r'^[/\\]'), '');
      if (relativePath.isEmpty) continue;
      
      final parts = relativePath.split(RegExp(r'[/\\]'));
      NoteFolder currentFolder = root;
      
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

  List<BacklinkMatch> getBacklinksFor(Note note) {
    return getBacklinksUseCase(targetNote: note, allNotes: _notes);
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

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return [];
    
    final results = <MapEntry<Note, double>>[];
    
    for (var note in _notes) {
      double score = fuzzyScore(query, note.title) * 2.0;
      score = score > 0 ? score : fuzzyScore(query, note.content);
      
      if (score > 0) {
        results.add(MapEntry(note, score));
      }
    }
    
    results.sort((a, b) => b.value.compareTo(a.value));
    return results.map((e) => e.key).toList();
  }

  Future<List<Note>> searchGlobal(String query) async {
    if (query.isEmpty) return [];
    return await repository.searchNotes(query);
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
    await repository.saveNote(path, '# $dateStr\n\n#daily\n\n');
    await refreshNotes();

    try {
      final note = _notes.firstWhere((n) => n.path.endsWith(filename));
      selectNote(note);
    } catch (e) {
      debugPrint("Error opening daily note: $e");
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
      debugPrint("Error deleting note: $e");
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

    final updatedNote = await saveNoteUseCase(note: _selectedNote!, newContent: newContent);
    
    final index = _notes.indexWhere((n) => n.path == _selectedNote!.path);
    if (index != -1) {
      _notes[index] = updatedNote;
      _selectedNote = updatedNote;
      _buildTags();
      notifyListeners();
    }
  }

  Future<void> manualSaveCurrentNote(String content) async {
    if (_selectedNote == null) return;
    
    final updatedNote = await saveNoteUseCase(note: _selectedNote!, newContent: content);
    _autoSaveEnabledPaths.add(_selectedNote!.path);
    
    await refreshNotes();
    
    final latestNote = _notes.firstWhere((n) => n.path == updatedNote.path, orElse: () => updatedNote);
    selectNote(latestNote);
    notifyListeners();
  }
}
