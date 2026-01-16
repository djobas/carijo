import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/note_service.dart';
import '../domain/models/note.dart';
import '../services/theme_service.dart';
import '../screens/graph_view_screen.dart';
import '../screens/deploy_screen.dart';
import '../screens/settings_screen.dart';
import '../plugins/plugin_manager.dart';

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

  Future<void> _loadActions(String query) async {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final pluginManager = Provider.of<PluginManager>(context, listen: false);

    final actions = widget.actions;
    if (actions != null) {
      final scoredActions = actions
          .map((a) => MapEntry(a, noteService.fuzzyScore(query, a.label)))
          .where((e) => e.value > 0)
          .toList();
      scoredActions.sort((a, b) => b.value.compareTo(a.value));
      
      setState(() {
        _filteredActions = scoredActions.map((e) => e.key).toList();
        _selectedIndex = 0;
      });
      return;
    }

    // Default actions if none provided
    final List<CommandAction> staticCommands = [
      CommandAction(label: "New Note", icon: Icons.add, onAction: () => noteService.createNewNote()),
      CommandAction(label: "Daily Note", icon: Icons.calendar_today, onAction: () => noteService.openDailyNote()),
      CommandAction(label: "Graph View", icon: Icons.hub, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GraphViewScreen(notes: noteService.notes)))),
      CommandAction(label: "Deploy / Sync", icon: Icons.cloud_upload, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeployScreen()))),
      CommandAction(label: "Settings", icon: Icons.settings, onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
    ];

    // Add plugin commands
    for (final command in pluginManager.allCommands) {
      staticCommands.add(CommandAction(
        label: "Plugin: ${command.label}",
        icon: command.icon,
        onAction: command.onExecute,
      ));
    }

    final scoredStatic = staticCommands
        .map((c) => MapEntry(c, noteService.fuzzyScore(query, c.label)))
        .where((e) => e.value > 0)
        .toList();

    // Notes: First search titles (Fast), then search global (Deep)
    final quickNotes = noteService.searchNotes(query);
    final globalNotes = query.length > 2 ? await noteService.searchGlobal(query) : [];
    
    // Merge and deduplicate
    final Set<String> seenPaths = {};
    final List<Note> mergedNotes = [];
    for (var n in [...quickNotes, ...globalNotes]) {
      if (!seenPaths.contains(n.path)) {
        mergedNotes.add(n);
        seenPaths.add(n.path);
      }
    }

    final List<CommandAction> items = scoredStatic.map((e) => e.key).toList();
    
    for (var note in mergedNotes) {
      items.add(CommandAction(
        label: "Open: ${note.title}", 
        icon: Icons.description, 
        onAction: () => noteService.selectNote(note)
      ));
    }

    if (!mounted) return;
    setState(() {
      _filteredActions = items;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context).theme;
    final bgDark = theme.bgMain;
    final borderColor = theme.borderColor;
    final accent = theme.accent;
    final textMain = theme.textMain;
    final textMuted = theme.textMuted;

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
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent) {
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
                      icon: Icon(Icons.search, color: textMuted),
                    ),
                    onSubmitted: (_) {
                      if (_filteredActions.isNotEmpty) {
                        final action = _filteredActions[_selectedIndex];
                        Navigator.pop(context);
                        action.onAction();
                      }
                    },
                  ),
                ),
              ),
              Divider(color: borderColor, height: 1),
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
                              Navigator.pop(context);
                              action.onAction();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: isSelected ? accent.withValues(alpha: 0.1) : null,
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
                      style: GoogleFonts.jetBrainsMono(color: textMuted.withValues(alpha: 0.5), fontSize: 10)),
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
