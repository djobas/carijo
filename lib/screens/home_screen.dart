import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/note_service.dart';
import '../services/git_service.dart';
import '../services/theme_service.dart';
import '../widgets/command_palette.dart';
import '../widgets/home/folder_sidebar.dart';
import '../widgets/home/tags_sidebar.dart';
import '../widgets/home/properties_sidebar.dart';
import '../widgets/home/note_editor.dart';
import '../widgets/home/formatting_toolbar.dart';
import 'deploy_screen.dart';
import 'graph_view_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _editorController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  
  bool _isPublished = false;
  bool _isEditing = true;
  String? _lastSelectedPath;
  bool _showProperties = false;

  // Autocomplete state
  bool _showAutocomplete = false;
  String _autocompleteQuery = "";
  int _autocompleteCursorPos = -1;

  @override
  void initState() {
    super.initState();
    _editorController.addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final text = _editorController.text;
    final selection = _editorController.selection;

    final selectedNote = noteService.selectedNote;
    if (selectedNote != null && text != selectedNote.content) {
      noteService.updateCurrentNote(text);
    }

    // Autocomplete Trigger Detection
    if (selection.isCollapsed && selection.start >= 2) {
      final lastTwo = text.substring(selection.start - 2, selection.start);
      if (lastTwo == '[[' && !_showAutocomplete) {
        setState(() {
          _showAutocomplete = true;
          _autocompleteCursorPos = selection.start;
          _autocompleteQuery = "";
        });
      } else if (_showAutocomplete) {
        if (selection.start < _autocompleteCursorPos) {
          setState(() => _showAutocomplete = false);
        } else {
          final query = text.substring(_autocompleteCursorPos, selection.start);
          if (query.contains('\n') || query.contains(']]')) {
            setState(() => _showAutocomplete = false);
          } else {
            setState(() => _autocompleteQuery = query);
          }
        }
      }
    } else if (_showAutocomplete) {
      setState(() => _showAutocomplete = false);
    }
  }

  void _syncEditorWithSelection(NoteService noteService) {
    final selectedNote = noteService.selectedNote;
    if (selectedNote != null && selectedNote.path != _lastSelectedPath) {
      _editorController.removeListener(_onEditorChanged);
      _editorController.text = selectedNote.content;
      _titleController.text = selectedNote.title;
      _tagsController.text = selectedNote.tags.join(', ');
      _isPublished = selectedNote.isPublished;
      _categoryController.text = selectedNote.category ?? '';
      _slugController.text = selectedNote.slug ?? '';
      _lastSelectedPath = selectedNote.path;
      _editorController.addListener(_onEditorChanged);
    } else if (selectedNote == null) {
      _lastSelectedPath = null;
      _editorController.clear();
      _titleController.clear();
      _tagsController.clear();
      _categoryController.clear();
      _slugController.clear();
      _isPublished = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context);
    final theme = Provider.of<ThemeService>(context).theme;

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          noteService.manualSaveCurrentNote(_editorController.text);
        },
        SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _showCommandPalette(context, noteService),
        SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true): () => _showCommandPalette(context, noteService),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.bgMain,
          body: Row(
            children: [
              // 1. Sidebar (Folders, Search, Tags)
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    Expanded(
                      child: FolderSidebar(
                        onNewNote: () => _showNewNoteOptions(context, noteService),
                        onNoteSelected: (note) {
                          noteService.selectNote(note);
                          _editorController.text = note.content;
                        },
                        searchController: _searchController,
                      ),
                    ),
                    const TagsSidebar(),
                  ],
                ),
              ),

              // 2. Main Editor Area
              Expanded(
                child: Column(
                  children: [
                    // Toolbar
                    _buildTopToolbar(context, noteService, theme),
                    if (_isEditing && noteService.selectedNote != null)
                      FormattingToolbar(
                        onBold: () => _wrapSelection("**"),
                        onItalic: () => _wrapSelection("_"),
                        onCode: () => _wrapSelection("`"),
                        onBulletList: () => _toggleLinePrefix("- "),
                        onCheckboxList: () => _toggleLinePrefix("- [ ] "),
                        onHeading: () => _toggleLinePrefix("# "),
                        onTable: _insertTable,
                        onLink: () => _wrapSelection("[[", "]]"),
                        onMermaid: _insertMermaid,
                      ),
                    
                    // Editor & Backlinks
                    Expanded(
                      child: NoteEditor(
                        editorController: _editorController,
                        isEditing: _isEditing,
                        showAutocomplete: _showAutocomplete,
                        autocompleteQuery: _autocompleteQuery,
                        autocompleteCursorPos: _autocompleteCursorPos,
                        onNoteSelected: (note) {
                          noteService.selectNote(note);
                          _editorController.text = note.content;
                        },
                        onNavigateToNote: _navigateToNote,
                        onInjectAutocomplete: _injectSelection,
                      ),
                    ),

                    // Status Bar
                    _buildStatusBar(noteService, theme),
                  ],
                ),
              ),

              // 3. Properties Sidebar (Conditional)
              if (_showProperties)
                PropertiesSidebar(
                  titleController: _titleController,
                  tagsController: _tagsController,
                  categoryController: _categoryController,
                  slugController: _slugController,
                  isPublished: _isPublished,
                  onPublishedChanged: (val) => setState(() => _isPublished = val),
                  onClose: () => setState(() => _showProperties = false),
                  onSaveMetadata: () => _updateNoteMetadata(noteService),
                  onNavigateToNote: _navigateToNote,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context, NoteService noteService, theme) {
    if (noteService.selectedNote == null) return const SizedBox(height: 56);
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.borderColor))),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _confirmDelete(context, noteService), 
            icon: Icon(Icons.delete_outline, color: theme.textMuted, size: 20),
            tooltip: "Delete Note",
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _showCommandPalette(context, noteService),
            icon: Icon(Icons.search, color: theme.textMuted, size: 20),
            tooltip: "Command Palette (Ctrl+Shift+P)",
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _pickAndInsertImage(noteService), 
            icon: Icon(Icons.image_outlined, color: theme.textMuted, size: 20),
            tooltip: "Insert Image",
          ),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _showProperties = !_showProperties), 
            icon: Icon(_showProperties ? Icons.info : Icons.info_outline, color: _showProperties ? theme.accent : theme.textMuted, size: 20),
            tooltip: "Show Properties",
          ),
          const SizedBox(width: 12),
          Text("Mode: ${_isEditing ? 'EDIT' : 'PREVIEW'}", style: GoogleFonts.jetBrainsMono(color: theme.textMuted, fontSize: 10)),
          const SizedBox(width: 12),
          Switch(
            value: !_isEditing, 
            onChanged: (val) => setState(() => _isEditing = !val),
            activeColor: theme.accent,
            activeTrackColor: theme.accent.withOpacity(0.3),
            inactiveThumbColor: theme.textMuted,
            inactiveTrackColor: theme.borderColor,
          )
        ],
      ),
    );
  }

  Widget _buildStatusBar(NoteService noteService, theme) {
    if (noteService.selectedNote == null) return const SizedBox();
    final selectedNote = noteService.selectedNote;
    if (selectedNote == null) return const SizedBox();
    final isAutoSave = noteService.isAutoSaveEnabled(selectedNote.path);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.borderColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text("${_editorController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} words", 
              style: GoogleFonts.jetBrainsMono(color: theme.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: theme.borderColor),
          const SizedBox(width: 8),
          Icon(Icons.circle, size: 8, color: isAutoSave ? theme.accent : theme.textMuted),
          const SizedBox(width: 4),
          Text(
            isAutoSave ? "Autosave ON" : "CTRL+S to Save", 
            style: GoogleFonts.jetBrainsMono(
              color: isAutoSave ? theme.textMain : theme.textMuted, 
              fontSize: 12,
              fontWeight: isAutoSave ? FontWeight.normal : FontWeight.bold
            )
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, NoteService noteService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Delete Note?", style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Text("This action cannot be undone.", style: GoogleFonts.jetBrainsMono(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              final selected = noteService.selectedNote;
              if (selected != null) {
                noteService.deleteNote(selected);
              }
              Navigator.pop(ctx);
            }, 
            child: Text("DELETE", style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).theme.accent))
          ),
        ],
      )
    );
  }

  void _injectSelection(String title) {
    final text = _editorController.text;
    final start = _autocompleteCursorPos;
    final end = _editorController.selection.start;
    final newText = text.replaceRange(start, end, "$title]]");
    
    _editorController.removeListener(_onEditorChanged);
    _editorController.text = newText;
    _editorController.selection = TextSelection.collapsed(offset: start + title.length + 2);
    _editorController.addListener(_onEditorChanged);
    Provider.of<NoteService>(context, listen: false).updateCurrentNote(newText);
    setState(() => _showAutocomplete = false);
  }

  Future<void> _pickAndInsertImage(NoteService noteService) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (result != null && path != null) {
      final markdownLink = await noteService.addImageToNote(File(path));
      if (markdownLink != null) {
        final currentText = _editorController.text;
        final selection = _editorController.selection;
        final newText = selection.start == -1 
            ? "$currentText\n$markdownLink\n" 
            : currentText.replaceRange(selection.start, selection.end, markdownLink);
        
        _editorController.text = newText;
        if (selection.start != -1) {
          _editorController.selection = TextSelection.collapsed(offset: selection.start + markdownLink.length);
        }
        noteService.updateCurrentNote(_editorController.text);
      }
    }
  }

  void _insertTable() {
    const tableTemplate = "\n| Col 1 | Col 2 |\n|-------|-------|\n| Cell  | Cell  |\n";
    final text = _editorController.text;
    final selection = _editorController.selection;
    final newText = selection.start == -1 
        ? "$text$tableTemplate" 
        : text.replaceRange(selection.start, selection.end, tableTemplate);
    _editorController.text = newText;
    _editorController.selection = TextSelection.collapsed(offset: selection.start + tableTemplate.length);
  }

  void _insertMermaid() {
    const mermaidTemplate = "\n```mermaid\ngraph TD;\n    A-->B;\n    A-->C;\n    B-->D;\n    C-->D;\n```\n";
    final text = _editorController.text;
    final selection = _editorController.selection;
    final newText = selection.start == -1 
        ? "$text$mermaidTemplate" 
        : text.replaceRange(selection.start, selection.end, mermaidTemplate);
    _editorController.text = newText;
    final cursorPos = selection.start == -1 ? newText.length : selection.start + mermaidTemplate.length;
    _editorController.selection = TextSelection.collapsed(offset: cursorPos.clamp(0, newText.length));
  }

  void _wrapSelection(String prefix, [String? suffix]) {
    final s = suffix ?? prefix;
    final text = _editorController.text;
    final selection = _editorController.selection;
    if (selection.start == -1) return;
    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(selection.start, selection.end, "$prefix$selectedText$s");
    _editorController.text = newText;
    _editorController.selection = TextSelection(baseOffset: selection.start + prefix.length, extentOffset: selection.end + prefix.length);
  }

  void _toggleLinePrefix(String prefix) {
    final text = _editorController.text;
    final selection = _editorController.selection;
    if (selection.start == -1) return;
    int lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
    if (lineStart < 0) lineStart = 0;
    final line = text.substring(lineStart, selection.end);
    String newText = line.startsWith(prefix) ? text.replaceRange(lineStart, lineStart + prefix.length, "") : text.replaceRange(lineStart, lineStart, prefix);
    _editorController.text = newText;
    _editorController.selection = TextSelection.collapsed(offset: selection.start + (line.startsWith(prefix) ? -prefix.length : prefix.length));
  }

  void _showCommandPalette(BuildContext context, NoteService noteService) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => CommandPalette(
        actions: [
          CommandAction(label: "New Note", icon: Icons.add, onAction: () => _showNewNoteOptions(context, noteService)),
          CommandAction(label: "Daily Note", icon: Icons.calendar_today, onAction: () => noteService.openDailyNote()),
          CommandAction(label: "Toggle Preview", icon: Icons.auto_stories, onAction: () => setState(() => _isEditing = !_isEditing)),
          CommandAction(label: "Insert Image", icon: Icons.image, onAction: () => _pickAndInsertImage(noteService)),
          CommandAction(label: "Graph View", icon: Icons.hub, onAction: () async {
            final Note? selected = await Navigator.push<Note>(context, MaterialPageRoute(builder: (_) => GraphViewScreen(notes: noteService.notes)));
            if (selected != null) {
              _navigateToNote(selected.title);
            }
          }),
          CommandAction(label: "Deploy / Sync", icon: Icons.cloud_upload, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeployScreen()))),
          CommandAction(label: "Settings", icon: Icons.settings, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
    );
  }

  void _showNewNoteOptions(BuildContext context, NoteService noteService) {
    showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("New Note", style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: GoogleFonts.jetBrainsMono(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(hintText: "Enter title...", hintStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.note_add, color: Colors.white70),
                title: const Text("Empty Note", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  noteService.createNewNote(title: titleController.text.isEmpty ? null : titleController.text);
                },
              ),
              ...noteService.templates.map((template) => ListTile(
                leading: const Icon(Icons.copy, color: Colors.red),
                title: Text(template.title, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  noteService.createFromTemplate(template, titleController.text.isEmpty ? template.title : titleController.text);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _updateNoteMetadata(NoteService noteService) {
    if (noteService.selectedNote == null) return;
    final newTitle = _titleController.text;
    final tagsList = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final published = _isPublished;
    final category = _categoryController.text.trim();
    final slug = _slugController.text.trim();
    String content = _editorController.text;

    final RegExp frontmatterRegex = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n');
    final match = frontmatterRegex.firstMatch(content);
    String tagsYaml = tagsList.isEmpty ? '[]' : '[${tagsList.join(', ')}]';

    if (match != null) {
      String yaml = match.group(1) ?? "";
      yaml = yaml.contains(RegExp(r'^title:', multiLine: true)) ? yaml.replaceFirst(RegExp(r'^title:.*', multiLine: true), 'title: $newTitle') : 'title: $newTitle\n$yaml';
      yaml = yaml.contains(RegExp(r'^tags:', multiLine: true)) ? yaml.replaceFirst(RegExp(r'^tags:.*', multiLine: true), 'tags: $tagsYaml') : 'tags: $tagsYaml\n$yaml';
      yaml = yaml.contains(RegExp(r'^published:', multiLine: true)) ? yaml.replaceFirst(RegExp(r'^published:.*', multiLine: true), 'published: $published') : 'published: $published\n$yaml';
      if (category.isNotEmpty) yaml = yaml.contains(RegExp(r'^category:', multiLine: true)) ? yaml.replaceFirst(RegExp(r'^category:.*', multiLine: true), 'category: $category') : 'category: $category\n$yaml';
      if (slug.isNotEmpty) yaml = yaml.contains(RegExp(r'^slug:', multiLine: true)) ? yaml.replaceFirst(RegExp(r'^slug:.*', multiLine: true), 'slug: $slug') : 'slug: $slug\n$yaml';
      content = content.replaceRange(match.start, match.end, '---\n$yaml\n---\n');
    } else {
      String yamlContent = 'title: $newTitle\ntags: $tagsYaml\npublished: $published';
      if (category.isNotEmpty) yamlContent += '\ncategory: $category';
      if (slug.isNotEmpty) yamlContent += '\nslug: $slug';
      content = '---\n$yamlContent\n---\n\n' + content.replaceFirst(RegExp(r'^#\s+.*$', multiLine: true), '').trimLeft();
    }

    _editorController.text = content;
    noteService.manualSaveCurrentNote(content);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Metadata updated")));
  }

  void _navigateToNote(String titleOrPath) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    try {
      final note = noteService.notes.firstWhere((n) => n.title.toLowerCase() == titleOrPath.toLowerCase() || n.path.endsWith(titleOrPath));
      noteService.selectNote(note);
      _editorController.text = note.content;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Note not found: $titleOrPath")));
    }
  }
}