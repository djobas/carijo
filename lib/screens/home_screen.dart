import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/note_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _editorController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isEditing = true;
  String? _lastSelectedPath;
  
  // Autocomplete state
  bool _showAutocomplete = false;
  String _autocompleteQuery = "";
  int _autocompleteCursorPos = -1;
  bool _showProperties = false;

  @override
  void initState() {
    super.initState();
    _editorController.addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final text = _editorController.text;
    final selection = _editorController.selection;

    if (noteService.selectedNote != null && 
        text != noteService.selectedNote!.content) {
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
        // Update query or close if cursor moved back or link closed
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
      // Avoid triggering the listener while we programmatically update the text
      _editorController.removeListener(_onEditorChanged);
      _editorController.text = selectedNote.content;
      _titleController.text = selectedNote.title;
      _lastSelectedPath = selectedNote.path;
      _editorController.addListener(_onEditorChanged);
    } else if (selectedNote == null) {
      _lastSelectedPath = null;
      _editorController.clear();
      _titleController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1A1A1A);
    const bgSidebar = Color(0xFF161616);
    const borderColor = Color(0xFF2A2A2A);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);

    final noteService = Provider.of<NoteService>(context);
    _syncEditorWithSelection(noteService);

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          noteService.manualSaveCurrentNote(_editorController.text);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: bgDark,
          body: Row(
            children: [
              // ... (Sidebar code)
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: bgSidebar,
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Icon(noteService.filterTag != null ? Icons.filter_alt : Icons.grid_view, color: accent),
                          const SizedBox(width: 8),
                          Text(
                            noteService.filterTag != null ? "#${noteService.filterTag}" : "Inbox", 
                            style: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 20, fontWeight: FontWeight.bold)
                          ),
                          const Spacer(),
                          if (noteService.filterTag != null)
                            IconButton(
                              onPressed: () => noteService.toggleTagFilter(null),
                              icon: const Icon(Icons.close, color: textMuted, size: 18),
                              tooltip: "Clear Filter",
                            )
                          else
                            IconButton(
                              onPressed: () => noteService.createNewNote(), 
                              icon: const Icon(Icons.add, color: textMuted, size: 20),
                              tooltip: "New Note (Ctrl+N)",
                            )
                        ],
                      ),
                    ),
                    // Search Mock
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: textMuted, size: 18),
                            const SizedBox(width: 8),
                            Text("Search notes...", style: GoogleFonts.jetBrainsMono(color: textMuted)),
                          ],
                        ),
                      ),
                    ),
                    // Tags Section Mock
                    if (noteService.allTags.isNotEmpty)
                      _buildTagsSidebarList(context, noteService),
                    // Note List
                    Expanded(
                      child: Consumer<NoteService>(
                        builder: (context, noteService, _) {
                          if (noteService.isLoading) return const Center(child: CircularProgressIndicator(color: accent));
                          if (noteService.notesPath == null) {
                            return Center(
                              child: TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), 
                                child: const Text("Set Folder", style: TextStyle(color: accent))
                              )
                            );
                          }
                          
                          return ListView.builder(
                            itemCount: noteService.notes.length,
                            itemBuilder: (context, index) {
                              final note = noteService.notes[index];
                              final isSelected = noteService.selectedNote?.path == note.path;
                              
                              return InkWell(
                                onTap: () {
                                  noteService.selectNote(note);
                                  _editorController.text = note.content;
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(left: BorderSide(color: isSelected ? accent : Colors.transparent, width: 2)),
                                    color: isSelected ? const Color(0xFF242424) : null,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(note.title, 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.jetBrainsMono(
                                          color: textMain, 
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                        )
                                      ),
                                      const SizedBox(height: 4),
                                      Text(note.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Sidebar Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                            child: Row(
                              children: [
                                const Icon(Icons.settings, color: textMuted, size: 16),
                                const SizedBox(width: 8),
                                Text("Settings", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              // Main Editor
              Expanded(
                child: Consumer<NoteService>(
                  builder: (context, noteService, _) {
                    if (noteService.selectedNote == null) {
                      return Center(child: Text("Select a note", style: GoogleFonts.jetBrainsMono(color: textMuted)));
                    }

                    final isAutoSave = noteService.isAutoSaveEnabled(noteService.selectedNote!.path);

                    return Column(
                      children: [
                        // Toolbar
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1A1A1A),
                                      title: Text("Delete Note?", style: GoogleFonts.spaceGrotesk(color: textMain)),
                                      content: Text("This action cannot be undone.", style: GoogleFonts.jetBrainsMono(color: textMuted)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: textMuted))),
                                        TextButton(
                                          onPressed: () {
                                            Provider.of<NoteService>(context, listen: false).deleteNote(noteService.selectedNote!);
                                            Navigator.pop(ctx);
                                          }, 
                                          child: const Text("DELETE", style: TextStyle(color: accent))
                                        ),
                                      ],
                                    )
                                  );
                                }, 
                                icon: const Icon(Icons.delete_outline, color: textMuted, size: 20),
                                tooltip: "Delete Note",
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => setState(() => _showProperties = !_showProperties), 
                                icon: Icon(_showProperties ? Icons.info : Icons.info_outline, color: _showProperties ? accent : textMuted, size: 20),
                                tooltip: "Show Properties",
                              ),
                              const SizedBox(width: 12),
                              Text("Mode: ${_isEditing ? 'EDIT' : 'PREVIEW'}", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 10)),
                              const SizedBox(width: 12),
                              Switch(
                                value: !_isEditing, 
                                onChanged: (val) => setState(() => _isEditing = !val),
                                activeColor: accent,
                                activeTrackColor: accent.withOpacity(0.3),
                                inactiveThumbColor: textMuted,
                                inactiveTrackColor: borderColor,
                              )
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              if (_isEditing) 
                                Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: TextField(
                                    controller: _editorController,
                                    maxLines: null,
                                    expands: true,
                                    style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 16, height: 1.6),
                                    cursorColor: accent,
                                    decoration: const InputDecoration(border: InputBorder.none),
                                  ),
                                )
                              else
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      MarkdownBody(
                                        data: _editorController.text,
                                        onTapLink: (text, href, title) {
                                          if (href != null) {
                                            _navigateToNote(href);
                                          } else {
                                            _navigateToNote(text);
                                          }
                                        },
                                        styleSheet: MarkdownStyleSheet(
                                          p: GoogleFonts.spaceGrotesk(color: textMain.withOpacity(0.9), fontSize: 16, height: 1.6),
                                          h1: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 32, fontWeight: FontWeight.bold),
                                          h2: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 24, fontWeight: FontWeight.bold),
                                          code: GoogleFonts.jetBrainsMono(backgroundColor: const Color(0xFF242424), color: accent),
                                          codeblockDecoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                      const SizedBox(height: 64),
                                      _buildBacklinksSection(context, noteService),
                                    ],
                                  ),
                                ),
                              
                              if (_showAutocomplete)
                                _buildAutocompleteOverlay(context, noteService),
                            ],
                          ),
                        ),
                    // Status Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text("${_editorController.text.split(' ').length} words", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12)),
                          const SizedBox(width: 8),
                          Container(width: 1, height: 12, color: borderColor),
                          const SizedBox(width: 8),
                          Icon(Icons.circle, size: 8, color: isAutoSave ? accent : textMuted),
                          const SizedBox(width: 4),
                          Text(
                            isAutoSave ? "Autosave ON" : "CTRL+S to Save", 
                            style: GoogleFonts.jetBrainsMono(
                              color: isAutoSave ? textMain : textMuted, 
                              fontSize: 12,
                              fontWeight: isAutoSave ? FontWeight.normal : FontWeight.bold
                            )
                          ),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          ),
          if (_showProperties)
            Consumer<NoteService>(
              builder: (context, noteService, _) => _buildPropertiesSidebar(context, noteService),
            ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildAutocompleteOverlay(BuildContext context, NoteService noteService) {
    final filteredNotes = noteService.notes.where((n) => 
      n.title.toLowerCase().contains(_autocompleteQuery.toLowerCase())
    ).take(5).toList();

    if (filteredNotes.isEmpty) return const SizedBox();

    return Positioned(
      top: 40,
      left: 60,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border.all(color: const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filteredNotes.map((note) => InkWell(
            onTap: () => _injectSelection(note.title),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A)))),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, color: Color(0xFF8C8C8C), size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(note.title, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(color: const Color(0xFFF4F1EA), fontSize: 13)
                    )
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  void _injectSelection(String title) {
    final text = _editorController.text;
    final start = _autocompleteCursorPos;
    final end = _editorController.selection.start;
    
    // Replace the query part from [[ onwards
    final newText = text.replaceRange(start, end, "$title]]");
    
    _editorController.removeListener(_onEditorChanged);
    _editorController.text = newText;
    _editorController.selection = TextSelection.collapsed(offset: start + title.length + 2);
    _editorController.addListener(_onEditorChanged);
    
    // Sync with service
    Provider.of<NoteService>(context, listen: false).updateCurrentNote(newText);
    
    setState(() => _showAutocomplete = false);
  }

  Widget _buildPropertiesSidebar(BuildContext context, NoteService noteService) {
    final note = noteService.selectedNote;
    if (note == null) return const SizedBox();
    
    const sidebarWidth = 300.0;
    const bgSidebar = Color(0xFF161616);
    const borderColor = Color(0xFF2A2A2A);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);

    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: bgSidebar,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Text("Properties", style: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _showProperties = false),
                  icon: const Icon(Icons.close, color: textMuted, size: 18),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                // Editable Title
                Text("TITLE", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 24),
                _buildPropertyField("Path", note.path),
                _buildPropertyField("Modified", note.modified.toString().split('.')[0]),
                const SizedBox(height: 24),
                Text("TAGS", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                if (note.tags.isEmpty)
                   Text("No tags found", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: note.tags.map((tag) => InkWell(
                      onTap: () {
                        noteService.toggleTagFilter(tag);
                        setState(() => _showProperties = false); // Close properties to show filtered list
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: noteService.filterTag == tag ? accent.withOpacity(0.2) : const Color(0xFF242424),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: noteService.filterTag == tag ? accent : borderColor),
                        ),
                        child: Text("#$tag", style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 11)),
                      ),
                    )).toList(),
                  ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _updateNoteMetadata(noteService),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: textMain,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: Text("SAVE METADATA", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                if (note.metadata.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text("FRONTMATTER", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  ...note.metadata.entries.where((e) => e.key != 'title').map((e) => _buildPropertyField(e.key, e.value.toString())),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateNoteMetadata(NoteService noteService) {
    if (noteService.selectedNote == null) return;
    
    final note = noteService.selectedNote!;
    final newTitle = _titleController.text;
    String content = _editorController.text;

    // 1. Update Title in Content
    final RegExp frontmatterRegex = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n');
    final match = frontmatterRegex.firstMatch(content);

    if (match != null) {
      // Update YAML
      String yaml = match.group(1)!;
      if (yaml.contains('title:')) {
        yaml = yaml.replaceFirst(RegExp(r'title:.*'), 'title: $newTitle');
      } else {
        yaml = 'title: $newTitle\n$yaml';
      }
      content = content.replaceRange(match.start, match.end, '---\n$yaml\n---\n');
    } else {
      // Update H1
      final RegExp h1Regex = RegExp(r'^#\s+(.*)$', multiLine: true);
      if (h1Regex.hasMatch(content)) {
        content = content.replaceFirst(h1Regex, '# $newTitle');
      } else {
        content = '# $newTitle\n\n$content';
      }
    }

    // 2. Save
    _editorController.text = content;
    noteService.manualSaveCurrentNote(content);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Metadata updated")));
  }

  Widget _buildPropertyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(color: const Color(0xFF8C8C8C), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(value, 
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFFF4F1EA), fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBacklinksSection(BuildContext context, NoteService noteService) {
    if (noteService.selectedNote == null) return const SizedBox();
    
    final backlinks = noteService.getBacklinksFor(noteService.selectedNote!);
    if (backlinks.isEmpty) return const SizedBox();

    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);
    const textMain = Color(0xFFF4F1EA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.link, color: accent, size: 16),
            const SizedBox(width: 8),
            Text("LINKED MENTIONS", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: backlinks.map((note) => InkWell(
            onTap: () {
              noteService.selectNote(note);
              _editorController.text = note.content;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2A2A2A)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(note.title, style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 12)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildTagsSidebarList(BuildContext context, NoteService noteService) {
    const textMuted = Color(0xFF8C8C8C);
    const textMain = Color(0xFFF4F1EA);
    const accent = Color(0xFFD93025);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text("TAGS", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: noteService.allTags.keys.map((tag) {
              final isFiltered = noteService.filterTag == tag;
              return Center(
                child: InkWell(
                  onTap: () => noteService.toggleTagFilter(tag),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFiltered ? accent.withOpacity(0.2) : const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(4),
                      border: isFiltered ? Border.all(color: accent) : null,
                    ),
                    child: Text("#$tag", style: GoogleFonts.jetBrainsMono(
                      color: isFiltered ? textMain : textMain.withOpacity(0.7), 
                      fontSize: 10,
                      fontWeight: isFiltered ? FontWeight.bold : FontWeight.normal
                    )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(color: Color(0xFF2A2A2A), height: 32, indent: 24, endIndent: 24),
      ],
    );
  }

  void _navigateToNote(String titleOrPath) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    
    // Try by title or path
    Note? note;
    try {
      note = noteService.notes.firstWhere(
        (n) => n.title.toLowerCase() == titleOrPath.toLowerCase() || 
               n.path.endsWith(titleOrPath) ||
               n.path.replaceAll('.md', '').endsWith(titleOrPath),
        orElse: () => throw Exception("Not found"),
      );
    } catch (_) {
      note = null;
    }

    if (note != null) {
      noteService.selectNote(note);
      _editorController.text = note.content;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Note not found: $titleOrPath"))
      );
    }
  }
}