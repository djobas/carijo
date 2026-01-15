import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/note_service.dart';
import '../../services/theme_service.dart';
import '../../domain/models/note.dart';
import 'backlinks_sidebar.dart';

class NoteEditor extends StatelessWidget {
  final TextEditingController editorController;
  final bool isEditing;
  final bool showAutocomplete;
  final String autocompleteQuery;
  final int autocompleteCursorPos;
  final Function(Note) onNoteSelected;
  final Function(String) onNavigateToNote;
  final Function(String) onInjectAutocomplete;

  const NoteEditor({
    super.key,
    required this.editorController,
    required this.isEditing,
    required this.showAutocomplete,
    required this.autocompleteQuery,
    required this.autocompleteCursorPos,
    required this.onNoteSelected,
    required this.onNavigateToNote,
    required this.onInjectAutocomplete,
  });

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;

    final textMain = theme.textMain;
    final textMuted = theme.textMuted;
    final accent = theme.accent;
    final bgSidebar = theme.bgSidebar;

    if (noteService.selectedNote == null) {
      return Center(child: Text("Select a note", style: GoogleFonts.jetBrainsMono(color: textMuted)));
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (isEditing)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: TextField(
                    controller: editorController,
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
                        data: editorController.text,
                        imageDirectory: noteService.notesPath,
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            onNavigateToNote(href);
                          } else {
                            onNavigateToNote(text);
                          }
                        },
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.spaceGrotesk(color: textMain.withOpacity(0.9), fontSize: 16, height: 1.6),
                          h1: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 32, fontWeight: FontWeight.bold),
                          h2: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 24, fontWeight: FontWeight.bold),
                          code: GoogleFonts.jetBrainsMono(backgroundColor: accent.withOpacity(0.1), color: accent),
                          codeblockDecoration: BoxDecoration(color: bgSidebar, borderRadius: BorderRadius.circular(4)),
                          checkbox: TextStyle(color: accent),
                        ),
                      ),
                      const SizedBox(height: 64),
                      BacklinksSidebar(onNoteSelected: onNoteSelected),
                    ],
                  ),
                ),
              if (showAutocomplete)
                _buildAutocompleteOverlay(context, noteService),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutocompleteOverlay(BuildContext context, NoteService noteService) {
    final theme = Provider.of<ThemeService>(context, listen: false).theme;
    final filteredNotes = noteService.notes.where((n) => 
      n.title.toLowerCase().contains(autocompleteQuery.toLowerCase())
    ).take(5).toList();

    if (filteredNotes.isEmpty) return const SizedBox();

    return Positioned(
      top: 40,
      left: 60,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: theme.bgSidebar,
          border: Border.all(color: theme.borderColor),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filteredNotes.map((note) => InkWell(
            onTap: () => onInjectAutocomplete(note.title),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.borderColor))),
              child: Row(
                children: [
                  Icon(Icons.article_outlined, color: theme.textMuted, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(note.title, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 13)
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
}
