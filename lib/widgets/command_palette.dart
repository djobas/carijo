import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/note_service.dart';
import '../screens/graph_view_screen.dart';
import '../screens/deploy_screen.dart';
import '../screens/settings_screen.dart';

class CommandAction {
  final String label;
  final IconData icon;
  final VoidCallback onAction;

  CommandAction({required this.label, required this.icon, required this.onAction});
}

class CommandPalette extends StatefulWidget {
  final List<CommandAction>? actions;

  const CommandPalette({super.key, this.actions});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  List<CommandAction> _filteredActions = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActions('');
    });
  }

  void _loadActions(String query) {
    if (widget.actions != null) {
      setState(() {
        _filteredActions = widget.actions!
            .where((a) => a.label.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _selectedIndex = 0;
      });
      return;
    }

    // Default actions if none provided
    final noteService = Provider.of<NoteService>(context, listen: false);
    
    final List<CommandAction> defaults = [
      CommandAction(label: "New Note", icon: Icons.add, onAction: () => noteService.createNewNote()),
      CommandAction(label: "Daily Note", icon: Icons.calendar_today, onAction: () => noteService.openDailyNote()),
      CommandAction(label: "Graph View", icon: Icons.hub, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GraphViewScreen(notes: noteService.notes)))),
      CommandAction(label: "Deploy / Sync", icon: Icons.cloud_upload, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeployScreen()))),
      CommandAction(label: "Settings", icon: Icons.settings, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
    ];

    // Also add note search results if they match
    final matchingNotes = noteService.searchNotes(query);
    for (var note in matchingNotes) {
      defaults.add(CommandAction(
        label: "Open: ${note.title}", 
        icon: Icons.description, 
        onAction: () => noteService.selectNote(note)
      ));
    }

    setState(() {
      _filteredActions = defaults.where((a) => a.label.toLowerCase().contains(query.toLowerCase())).toList();
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1A1A1A);
    const borderColor = Color(0xFF2A2A2A);
    const accent = Color(0xFFD93025);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 500,
          height: 400,
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: (event) {
                    if (event is RawKeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        setState(() {
                          _selectedIndex = (_selectedIndex + 1) % _filteredActions.length;
                        });
                      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        setState(() {
                          _selectedIndex = (_selectedIndex - 1 + _filteredActions.length) % _filteredActions.length;
                        });
                      }
                    }
                  },
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _loadActions,
                    style: GoogleFonts.jetBrainsMono(color: textMain),
                    decoration: InputDecoration(
                      hintText: "Type a command...",
                      hintStyle: GoogleFonts.jetBrainsMono(color: textMuted),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: textMuted),
                    ),
                    onSubmitted: (_) {
                      if (_filteredActions.isNotEmpty) {
                        _filteredActions[_selectedIndex].onAction();
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
              const Divider(color: borderColor, height: 1),
              Expanded(
                child: _filteredActions.isEmpty
                    ? Center(child: Text("No commands found", style: GoogleFonts.jetBrainsMono(color: textMuted)))
                    : ListView.builder(
                        itemCount: _filteredActions.length,
                        itemBuilder: (context, index) {
                          final action = _filteredActions[index];
                          final isSelected = index == _selectedIndex;
                          return InkWell(
                            onTap: () {
                              action.onAction();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: isSelected ? const Color(0xFF242424) : null,
                              child: Row(
                                children: [
                                  Icon(action.icon, size: 18, color: isSelected ? accent : textMuted),
                                  const SizedBox(width: 16),
                                  Text(
                                    action.label,
                                    style: GoogleFonts.jetBrainsMono(
                                      color: isSelected ? textMain : textMuted,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                color: const Color(0xFF161616),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("↑↓ to navigate, ENTER to select, ESC to dismiss", 
                      style: GoogleFonts.jetBrainsMono(color: textMuted.withOpacity(0.5), fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
