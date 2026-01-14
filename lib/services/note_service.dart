import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

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

class NoteFolder {
  final String name;
  final String path;
  final List<NoteFolder> subfolders;
  final List<Note> notes;
  bool isExpanded;

  NoteFolder({
    required this.name,
    required this.path,
    required this.subfolders,
    required this.notes,
    this.isExpanded = false,
  });
}

class BacklinkMatch {
  final Note note;
  final String snippet;

  BacklinkMatch({required this.note, required this.snippet});
}

class NoteService extends ChangeNotifier {
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
        final List<FileSystemEntity> entities = dir.listSync(recursive: true);
        final List<Note> loadedNotes = [];

        for (var entity in entities) {
          // Skip internal directories
          if (entity.path.contains('${Platform.pathSeparator}.') || 
              entity.path.contains('${Platform.pathSeparator}assets${Platform.pathSeparator}')) {
            continue;
          }

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
        // Build Folder Tree
        _buildFolderTree();
      }
    } catch (e) {
      print("Error loading notes: $e");
    }

    _isLoading = false;
    _buildTags();
    _scanTemplates();
    notifyListeners();
  }

  Future<String?> addImageToNote(File imageFile) async {
    if (_notesPath == null) return null;

    try {
      final assetsDir = Directory('$_notesPath${Platform.pathSeparator}assets');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      final fileName = p.basename(imageFile.path);
      final targetPath = p.join(assetsDir.path, fileName);
      
      // Copy the file
      await imageFile.copy(targetPath);
      
      // Return the standard markdown link with relative path
      return '![](assets/$fileName)';
    } catch (e) {
      print("Error adding image: $e");
      return null;
    }
  }

  void _buildFolderTree() {
    if (_notesPath == null) {
      _rootFolder = null;
      return;
    }

    final root = NoteFolder(
      name: p.basename(_notesPath!),
      path: _notesPath!,
      subfolders: [],
      notes: [],
      isExpanded: true,
    );

    for (var note in _notes) {
      final relativePath = p.relative(note.path, from: _notesPath);
      final parts = p.split(relativePath);
      
      NoteFolder currentFolder = root;
      
      // Traverse/create subfolders
      for (int i = 0; i < parts.length - 1; i++) {
        final folderName = parts[i];
        final folderPath = p.join(currentFolder.path, folderName);
        
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
    final filename = note.path.split(Platform.pathSeparator).last.replaceAll('.md', '');
    final List<Note> linkedNotes = [];
    final seenPaths = <String>{};
    
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
      // Bonus if it starts with the query
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
      // All chars found in order. Score decreases with more gaps.
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