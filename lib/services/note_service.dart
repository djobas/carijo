import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
export '../domain/models/note.dart';
import '../domain/models/note.dart';
import '../domain/repositories/note_repository.dart';
import '../domain/use_cases/search_notes_use_case.dart';
import '../domain/use_cases/get_backlinks_use_case.dart';
import '../domain/use_cases/save_note_use_case.dart';
import 'logger_service.dart';

/// Service responsible for managing notes in the application.
///
/// Provides CRUD operations, search, filtering, templating, and folder
/// organization for markdown notes. Uses [ChangeNotifier] to notify
/// listeners of state changes.
///
/// Example usage:
/// ```dart
/// final noteService = Provider.of<NoteService>(context);
/// await noteService.createNewNote(title: 'My Note');
/// noteService.selectNote(noteService.notes.first);
/// ```
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

  /// The root directory path where notes are stored.
  String? get notesPath => _notesPath;

  /// The hierarchical folder structure of all notes.
  NoteFolder? get rootFolder => _rootFolder;
  
  /// Returns filtered and searched notes based on current query and tag filter.
  List<Note> get notes {
    return searchUseCase(
      notes: _notes,
      query: _searchQuery,
      filterTag: _filterTag,
    );
  }

  /// The currently selected note in the editor.
  Note? get selectedNote => _selectedNote;

  /// Whether notes are currently being loaded from disk.
  bool get isLoading => _isLoading;

  /// Map of all tags to their associated notes.
  Map<String, List<Note>> get allTags => _allTags;

  /// The currently active tag filter, or null if no filter is applied.
  String? get filterTag => _filterTag;

  /// The current search query string.
  String get searchQuery => _searchQuery;

  /// List of available note templates from the _templates folder.
  List<Note> get templates => _templates;

  /// Creates a NoteService with required use cases and repository.
  ///
  /// Automatically initializes by loading the notes path from preferences
  /// and refreshing the notes list.
  NoteService({
    required this.repository,
    required this.searchUseCase,
    required this.getBacklinksUseCase,
    required this.saveNoteUseCase,
  }) {
    _init();
  }

  /// Checks if auto-save is enabled for a note at the given [path].
  ///
  /// Auto-save is enabled after the first manual save of a note.
  bool isAutoSaveEnabled(String path) => _autoSaveEnabledPaths.contains(path);

  /// Updates the current search query and triggers a UI refresh.
  ///
  /// The [query] is used to filter notes by title and content.
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Toggles the tag filter on or off.
  ///
  /// If [tag] matches the current filter, it is cleared. Otherwise,
  /// the filter is set to the new tag.
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

  /// Sets the root directory path for notes and refreshes the notes list.
  ///
  /// Persists the [path] to SharedPreferences for future sessions.
  Future<void> setNotesPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_path', path);
    _notesPath = path;
    await refreshNotes();
  }

  /// Reloads all notes from the filesystem.
  ///
  /// Rebuilds the folder tree, tag index, and template list.
  /// Notifies listeners when complete.
  Future<void> refreshNotes() async {
    try {
      final path = _notesPath;
      if (path == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      final loadedNotes = await repository.getAllNotes(path);
      loadedNotes.sort((a, b) => b.modified.compareTo(a.modified));
      _notes = loadedNotes;
      _buildFolderTree();
    } catch (e) {
      LoggerService.error("Failed to load notes", error: e);
    }

    _isLoading = false;
    _buildTags();
    await _scanTemplates();
    notifyListeners();
  }

  Future<String?> addImageToNote(File imageFile) async {
    final path = _notesPath;
    if (path == null) return null;
    return await repository.uploadImage(path, imageFile);
  }

  void _buildFolderTree() {
    final path = _notesPath;
    if (path == null) {
      _rootFolder = null;
      return;
    }

    final root = NoteFolder(
      name: path.split(RegExp(r'[/\\]')).last,
      path: path,
      subfolders: [],
      notes: [],
      isExpanded: true,
    );

    for (var note in _notes) {
      final relativePath = note.path.substring(path.length).replaceFirst(RegExp(r'^[/\\]'), '');
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

  /// Finds all notes that link to the given [note].
  ///
  /// Returns a list of [BacklinkMatch] containing the linking note
  /// and the line snippet where the link appears.
  List<BacklinkMatch> getBacklinksFor(Note note) {
    return getBacklinksUseCase(targetNote: note, allNotes: _notes);
  }

  /// Calculates a fuzzy match score between [query] and [target].
  ///
  /// Returns a score from 0.0 (no match) to 1.0 (exact/prefix match).
  /// Used internally for ranked search results.
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

  /// Searches notes by [query] using fuzzy matching.
  ///
  /// Returns notes sorted by relevance score (title matches weighted 2x).
  /// Returns empty list if query is empty.
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

  /// Searches notes globally using the repository's search.
  ///
  /// Unlike [searchNotes], this may use indexed search for better performance.
  Future<List<Note>> searchGlobal(String query) async {
    if (query.isEmpty) return [];
    final path = _notesPath;
    if (path == null) return [];
    return await repository.searchNotes(query);
  }

  /// Selects a [note] to display in the editor.
  ///
  /// Notifies listeners to update the UI.
  void selectNote(Note note) {
    _selectedNote = note;
    notifyListeners();
  }

  /// Creates a new note with optional [title] and [content].
  ///
  /// If no title is provided, uses a timestamp-based name.
  /// Automatically selects the new note after creation.
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
    
    // Date/Time variables
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final datetimeStr = "$dateStr $timeStr";
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final weekdayStr = weekdays[now.weekday % 7];
    final uuid = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    
    // Apply all substitutions
    content = content.replaceAll('{{title}}', newNoteTitle);
    content = content.replaceAll('{{date}}', dateStr);
    content = content.replaceAll('{{time}}', timeStr);
    content = content.replaceAll('{{datetime}}', datetimeStr);
    content = content.replaceAll('{{weekday}}', weekdayStr);
    content = content.replaceAll('{{uuid}}', uuid);
    
    final filename = newNoteTitle.endsWith('.md') ? newNoteTitle : '$newNoteTitle.md';
    final path = "${_notesPath}${Platform.pathSeparator}$filename";
    
    await repository.saveNote(path, content);
    await refreshNotes();
    
    try {
      final newNote = _notes.firstWhere((n) => n.path == path);
      selectNote(newNote);
    } catch (_) {}
  }

  /// Opens or creates today's daily note.
  ///
  /// Daily notes are named with format YYYY-MM-DD.md and include the #daily tag.
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
      LoggerService.error("Failed to open daily note", error: e);
    }
  }

  Future<void> _scanTemplates() async {
    final path = _notesPath;
    if (path == null) return;
    _templates = await repository.getTemplates(path);
    notifyListeners();
  }

  /// Deletes a [note] from the filesystem.
  ///
  /// Clears selection if the deleted note was selected.
  Future<void> deleteNote(Note note) async {
    try {
      await repository.deleteNote(note.path);
      if (_selectedNote?.path == note.path) {
        _selectedNote = null;
      }
      await refreshNotes();
    } catch (e) {
      LoggerService.error("Failed to delete note", error: e);
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
    final selected = _selectedNote;
    if (selected == null) return;
    if (!_autoSaveEnabledPaths.contains(selected.path)) return;

    final updatedNote = await saveNoteUseCase(note: selected, newContent: newContent);
    
    final index = _notes.indexWhere((n) => n.path == selected.path);
    if (index != -1) {
      _notes[index] = updatedNote;
      // Only update _selectedNote if it hasn't changed to something else during the await
      if (_selectedNote?.path == selected.path) {
        _selectedNote = updatedNote;
      }
      _buildTags();
      notifyListeners();
    }
  }

  Future<void> manualSaveCurrentNote(String content) async {
    final selected = _selectedNote;
    if (selected == null) return;
    
    final updatedNote = await saveNoteUseCase(note: selected, newContent: content);
    _autoSaveEnabledPaths.add(selected.path);
    
    await refreshNotes();
    
    // Safety: only re-select if the path matches the one we just saved
    final latestNote = _notes.firstWhere((n) => n.path == updatedNote.path, orElse: () => updatedNote);
    if (_selectedNote?.path == selected.path) {
      selectNote(latestNote);
    }
    notifyListeners();
  }
}
