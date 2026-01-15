import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/note_service.dart';
import '../../services/theme_service.dart';

class PropertiesSidebar extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController tagsController;
  final TextEditingController categoryController;
  final TextEditingController slugController;
  final bool isPublished;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onClose;
  final VoidCallback onSaveMetadata;
  final Function(String) onNavigateToNote;

  const PropertiesSidebar({
    super.key,
    required this.titleController,
    required this.tagsController,
    required this.categoryController,
    required this.slugController,
    required this.isPublished,
    required this.onPublishedChanged,
    required this.onClose,
    required this.onSaveMetadata,
    required this.onNavigateToNote,
  });

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context);
    final note = noteService.selectedNote;
    if (note == null) return const SizedBox();
    
    final theme = Provider.of<ThemeService>(context).theme;
    const sidebarWidth = 300.0;
    final bgSidebar = theme.bgSidebar;
    final borderColor = theme.borderColor;
    final textMain = theme.textMain;
    final textMuted = theme.textMuted;
    final accent = theme.accent;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
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
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: textMuted, size: 18),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                Text("TITLE", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 24),
                _buildPropertyField(context, "Path", note.path),
                _buildPropertyField(context, "Modified", note.modified.toString().split('.')[0]),
                const SizedBox(height: 24),
                Text("TAGS", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                TextField(
                  controller: tagsController,
                  style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "tag1, tag2",
                    hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 24),
                Text("CATEGORY", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Ex: Blog, Projects",
                    hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 24),
                Text("CUSTOM SLUG", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                TextField(
                  controller: slugController,
                  style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "seo-friendly-slug",
                    hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("PUBLISHED TO BLOG", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    Switch(
                      value: isPublished,
                      onChanged: onPublishedChanged,
                      activeThumbColor: const Color(0xFF3ECF8E),
                      activeTrackColor: const Color(0xFF3ECF8E).withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: onSaveMetadata,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: textMain,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: Text("SAVE METADATA", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                if (note.outgoingLinks.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text("OUTGOING LINKS", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  ...note.outgoingLinks.map((link) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => onNavigateToNote(link),
                      child: Row(
                        children: [
                          Icon(Icons.link, color: textMuted, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(link, style: GoogleFonts.jetBrainsMono(color: accent, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
                if (note.metadata.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text("FRONTMATTER", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  ...note.metadata.entries.where((e) => e.key != 'title').map((e) => _buildPropertyField(context, e.key, e.value.toString())),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyField(BuildContext context, String label, String value) {
    final theme = Provider.of<ThemeService>(context, listen: false).theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(color: theme.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(value, 
            style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
