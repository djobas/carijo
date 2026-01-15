import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/note_service.dart';
import '../../services/theme_service.dart';

class TagsSidebar extends StatelessWidget {
  const TagsSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;
    
    final textMuted = theme.textMuted;
    final textMain = theme.textMain;
    final accent = theme.accent;

    if (noteService.allTags.isEmpty) return const SizedBox();

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
                      color: isFiltered ? accent.withOpacity(0.2) : theme.bgSidebar,
                      borderRadius: BorderRadius.circular(4),
                      border: isFiltered ? Border.all(color: accent) : Border.all(color: theme.borderColor),
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
        Divider(color: theme.borderColor, height: 32, indent: 24, endIndent: 24),
      ],
    );
  }
}
