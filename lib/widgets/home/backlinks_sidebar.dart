import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/note_service.dart';
import '../../services/theme_service.dart';

class BacklinksSidebar extends StatelessWidget {
  final Function(Note) onNoteSelected;

  const BacklinksSidebar({
    super.key,
    required this.onNoteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context);
    final selectedNote = noteService.selectedNote;
    if (selectedNote == null) return const SizedBox();
    
    final backlinks = noteService.getBacklinksFor(selectedNote);
    if (backlinks.isEmpty) return const SizedBox();

    final theme = Provider.of<ThemeService>(context).theme;
    final textMuted = theme.textMuted;
    final accent = theme.accent;
    final textMain = theme.textMain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, color: accent, size: 16),
            const SizedBox(width: 8),
            Text("LINKED MENTIONS", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          children: backlinks.map((match) => InkWell(
            onTap: () => onNoteSelected(match.note),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.bgSidebar,
                border: Border.all(color: theme.borderColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.note.title, style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    match.snippet, 
                    style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 10, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
