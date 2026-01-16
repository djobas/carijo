import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/note_service.dart';
import '../../services/theme_service.dart';
import '../../screens/settings_screen.dart';
import '../../screens/graph_view_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class FolderSidebar extends StatefulWidget {
  final VoidCallback onNewNote;
  final Function(Note) onNoteSelected;
  final TextEditingController searchController;

  const FolderSidebar({
    super.key,
    required this.onNewNote,
    required this.onNoteSelected,
    required this.searchController,
  });

  @override
  State<FolderSidebar> createState() => _FolderSidebarState();
}

class _FolderSidebarState extends State<FolderSidebar> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;

    final bgSidebar = theme.bgSidebar;
    final borderColor = theme.borderColor;
    final textMain = theme.textMain;
    final textMuted = theme.textMuted;
    final accent = theme.accent;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: bgSidebar.withValues(alpha: 0.8),
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  style: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (noteService.filterTag != null)
                  IconButton(
                    onPressed: () => noteService.toggleTagFilter(null),
                    icon: Icon(Icons.close, color: textMuted, size: 18),
                    tooltip: "Clear Filter",
                  )
                else ...[
                  IconButton(
                    onPressed: () => noteService.openDailyNote(),
                    icon: Icon(Icons.calendar_today, color: textMuted, size: 18),
                    tooltip: "Daily Note",
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GraphViewScreen(notes: noteService.notes)),
                    ),
                    icon: Icon(Icons.hub, color: textMuted, size: 18),
                    tooltip: "Graph View",
                  ),
                  IconButton(
                    onPressed: widget.onNewNote,
                    icon: Icon(Icons.add, color: textMuted, size: 20),
                    tooltip: "New Note (Ctrl+N)",
                  ),
                ]
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: bgSidebar.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      onChanged: (value) => noteService.updateSearchQuery(value),
                      style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search notes...",
                        hintStyle: GoogleFonts.jetBrainsMono(color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (widget.searchController.text.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close, color: textMuted, size: 16),
                      onPressed: () {
                        widget.searchController.clear();
                        noteService.updateSearchQuery("");
                      },
                    )
                ],
              ),
            ),
          ),
          
          Expanded(
            child: Consumer<NoteService>(
              builder: (context, noteService, _) {
                if (noteService.isLoading) return Center(child: CircularProgressIndicator(color: accent));
                if (noteService.notesPath == null) {
                  return Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      child: Text("Set Folder", style: TextStyle(color: accent)),
                    ),
                  );
                }

                final root = noteService.rootFolder;
                if (root == null) return const SizedBox();

                if (noteService.filterTag != null || noteService.searchQuery.isNotEmpty) {
                  return ListView.builder(
                    itemCount: noteService.notes.length,
                    itemBuilder: (context, index) => _buildSimpleNoteItem(context, noteService.notes[index], noteService),
                  );
                }

                return ListView(
                  children: [
                    _buildFolderItem(root, noteService, level: 0),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: textMuted, size: 16),
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
      ),
    );
  }

  Widget _buildSimpleNoteItem(BuildContext context, Note note, NoteService noteService) {
    final theme = Provider.of<ThemeService>(context).theme;
    final isSelected = noteService.selectedNote?.path == note.path;
    final accent = theme.accent;
    final textMain = theme.textMain;
    final textMuted = theme.textMuted;

    return InkWell(
      onTap: () => widget.onNoteSelected(note),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: isSelected ? accent : Colors.transparent, width: 2)),
          color: isSelected ? accent.withValues(alpha: 0.1) : null,
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
            const SizedBox(height: 4),
            Text(
              note.content.substring(0, (100 < note.content.length) ? 100 : note.content.length).replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem(NoteFolder folder, NoteService noteService, {int level = 0}) {
    final theme = Provider.of<ThemeService>(context).theme;
    final accent = theme.accent;
    final textMain = theme.textMain;
    final textMuted = theme.textMuted;
    final isExpanded = _expandedFolders.contains(folder.path) || folder.path == noteService.notesPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (_expandedFolders.contains(folder.path)) {
                _expandedFolders.remove(folder.path);
              } else {
                _expandedFolders.add(folder.path);
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.0 + (level * 12), 8, 16, 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: textMuted,
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  size: 16,
                  color: accent.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folder.name,
                    style: GoogleFonts.spaceGrotesk(
                      color: textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          ...folder.subfolders.map((sub) => _buildFolderItem(sub, noteService, level: level + 1)),
          ...folder.notes.map((note) => _buildNoteItem(note, noteService, level: level + 1)),
        ],
      ],
    );
  }

  Widget _buildNoteItem(Note note, NoteService noteService, {int level = 0}) {
    final theme = Provider.of<ThemeService>(context).theme;
    final accent = theme.accent;
    final textMain = theme.textMain;
    final textMuted = theme.textMuted;
    final isSelected = noteService.selectedNote?.path == note.path;

    return InkWell(
      onTap: () => widget.onNoteSelected(note),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: isSelected ? accent : Colors.transparent, width: 2)),
          color: isSelected ? accent.withValues(alpha: 0.1) : null,
        ),
        padding: EdgeInsets.fromLTRB(36.0 + (level * 12), 10, 16, 10),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 14, color: textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  color: textMain,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
