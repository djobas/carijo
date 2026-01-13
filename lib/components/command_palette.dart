import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/note_service.dart';
import '../screens/settings_screen.dart';
import '../screens/deploy_screen.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<dynamic> _options = []; // Can be Note or String (Command)
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadOptions('');
  }

  void _loadOptions(String query) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final notes = noteService.notes;
    
    final commands = [
      {'title': 'Go to Settings', 'action': 'settings', 'icon': Icons.settings},
      {'title': 'Deploy / Staging', 'action': 'deploy', 'icon': Icons.rocket_launch},
      {'title': 'Create New Note', 'action': 'new_note', 'icon': Icons.add},
    ];

    List<dynamic> results = [];

    // Filter Commands
    for (var cmd in commands) {
      if (cmd['title'].toString().toLowerCase().contains(query.toLowerCase())) {
        results.add(cmd);
      }
    }

    // Filter Notes
    for (var note in notes) {
      if (note.title.toLowerCase().contains(query.toLowerCase())) {
        results.add(note);
      }
    }

    setState(() {
      _options = results;
      _selectedIndex = 0;
    });
  }

  void _executeSelection() {
    if (_options.isEmpty) return;
    
    final selection = _options[_selectedIndex];

    if (selection is Map) {
      // It's a command
      Navigator.pop(context); // Close palette first
      final action = selection['action'];
      
      if (action == 'settings') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      } else if (action == 'deploy') {
         Navigator.push(context, MaterialPageRoute(builder: (_) => const DeployScreen()));
      } else if (action == 'new_note') {
        // Simple logic: create generic note
        Provider.of<NoteService>(context, listen: false).saveNote(
          "Untitled ${DateTime.now().millisecondsSinceEpoch}.md", 
          "# New Note\n"
        );
      }
    } else if (selection is Note) {
      // It's a note
      Provider.of<NoteService>(context, listen: false).selectNote(selection);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Design System
    const bgDark = Color(0xFF1A1A1A);
    const surfaceHighlight = Color(0xFF262626);
    const borderColor = Color(0xFF333333);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 640,
          height: 400,
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
          ),
          child: Column(
            children: [
              // Search Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: const Border(bottom: BorderSide(color: borderColor)),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) {
                          if (event is RawKeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              setState(() {
                                if (_selectedIndex < _options.length - 1) _selectedIndex++;
                              });
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              setState(() {
                                if (_selectedIndex > 0) _selectedIndex--;
                              });
                            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                              _executeSelection();
                            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                              Navigator.pop(context);
                            }
                          }
                        },
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: GoogleFonts.jetbrainsMono(color: textMain, fontSize: 18),
                          cursorColor: accent,
                          decoration: InputDecoration.collapsed(
                            hintText: "Type a command or search...",
                            hintStyle: GoogleFonts.jetbrainsMono(color: textMuted),
                          ),
                          onChanged: _loadOptions,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: surfaceHighlight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        "ESC",
                        style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 10),
                      ),
                    )
                  ],
                ),
              ),
              // List Results
              Expanded(
                child: ListView.builder(
                  itemCount: _options.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedIndex;
                    final item = _options[index];
                    
                    IconData icon;
                    String title;
                    String subtitle = "";

                    if (item is Map) {
                      icon = item['icon'];
                      title = item['title'];
                      subtitle = "Command";
                    } else {
                      // Note
                      icon = Icons.description;
                      title = (item as Note).title;
                      subtitle = "Note";
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        _executeSelection();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, 
                              color: isSelected ? textMain : textMuted, 
                              size: 20
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.jetbrainsMono(
                                  color: isSelected ? textMain : textMain,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.keyboard_return, color: textMain, size: 16)
                            else 
                              Text(subtitle, style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}