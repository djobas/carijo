import 'package:flutter/material.dart';
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
  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    _editorController.addListener(() {
      final noteService = Provider.of<NoteService>(context, listen: false);
      if (noteService.selectedNote != null && 
          _editorController.text != noteService.selectedNote!.content) {
        // Simple debounce could go here
        noteService.updateCurrentNote(_editorController.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1A1A1A);
    const bgSidebar = Color(0xFF161616);
    const borderColor = Color(0xFF2A2A2A);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);

    return Scaffold(
      backgroundColor: bgDark,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: bgSidebar,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view, color: accent),
                      const SizedBox(width: 8),
                      Text("Inbox", style: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 20, fontWeight: FontWeight.bold)),
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
                        Text("Search notes...", style: GoogleFonts.jetbrainsMono(color: textMuted)),
                      ],
                    ),
                  ),
                ),
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
                                    style: GoogleFonts.jetbrainsMono(
                                      color: textMain, 
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                    )
                                  ),
                                  const SizedBox(height: 4),
                                  Text(note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 12),
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
                            Text("Settings", style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 12)),
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
                  return Center(child: Text("Select a note", style: GoogleFonts.jetbrainsMono(color: textMuted)));
                }

                return Column(
                  children: [
                    // Toolbar
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                           Text("Mode: ${_isEditing ? 'EDIT' : 'PREVIEW'}", style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 10)),
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
                      child: _isEditing 
                      ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: TextField(
                            controller: _editorController,
                            maxLines: null,
                            expands: true,
                            style: GoogleFonts.jetbrainsMono(color: textMain, fontSize: 16, height: 1.6),
                            cursorColor: accent,
                            decoration: const InputDecoration(border: InputBorder.none),
                          ),
                      )
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: MarkdownBody(
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
                            code: GoogleFonts.jetbrainsMono(backgroundColor: const Color(0xFF242424), color: accent),
                            codeblockDecoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    // Status Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text("${_editorController.text.split(' ').length} words", style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 12)),
                          const SizedBox(width: 8),
                          Container(width: 1, height: 12, color: borderColor),
                          const SizedBox(width: 8),
                          const Icon(Icons.circle, size: 8, color: accent),
                          const SizedBox(width: 4),
                          Text("Saved", style: GoogleFonts.jetbrainsMono(color: textMain, fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _navigateToNote(String titleOrPath) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    
    // Try by title first
    try {
      final note = noteService.notes.firstWhere(
        (n) => n.title.toLowerCase() == titleOrPath.toLowerCase() || 
               n.path.endsWith(titleOrPath)
      );
      noteService.selectNote(note);
      _editorController.text = note.content;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Note not found: $titleOrPath"))
      );
    }
  }
}