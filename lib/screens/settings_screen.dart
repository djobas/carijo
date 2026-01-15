import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/note_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    final noteService = Provider.of<NoteService>(context, listen: false);
    _pathController.text = noteService.notesPath ?? '';

    _loadSupabasePrefs();
  }

  Future<void> _loadSupabasePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _supabaseUrlController.text = prefs.getString(SupabaseService.keyUrl) ?? '';
      _supabaseKeyController.text = prefs.getString(SupabaseService.keyAnonKey) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;

    final bgDark = theme.bgMain;
    final textMain = theme.textMain;
    final accent = theme.accent;
    final borderGray = theme.textMuted;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Settings", style: GoogleFonts.spaceGrotesk(color: textMain, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF333333), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Storage", 
                  style: GoogleFonts.spaceGrotesk(
                    color: borderGray, 
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                  )
                ),
                const SizedBox(height: 20),
                
                Text("UI Theme", 
                  style: GoogleFonts.spaceGrotesk(color: textMain.withValues(alpha: 0.8), fontSize: 14)
                ),
                DropdownButton<AppTheme>(
                  value: themeService.theme,
                  dropdownColor: theme.bgSidebar,
                  isExpanded: true,
                  underline: Container(height: 1, color: borderGray),
                  icon: Icon(Icons.palette, color: accent, size: 20),
                  items: themeService.themes.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name, style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 14)),
                  )).toList(),
                  onChanged: (newTheme) {
                    if (newTheme != null) themeService.setTheme(newTheme);
                  },
                ),
                const SizedBox(height: 32),

                Text("Local Folder Path", 
                  style: GoogleFonts.spaceGrotesk(color: textMain.withValues(alpha: 0.8), fontSize: 14)
                ),
                TextField(
                  controller: _pathController,
                  style: GoogleFonts.jetBrainsMono(color: textMain),
                  decoration: InputDecoration(
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderGray)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                    hintText: "/home/user/notes",
                    hintStyle: TextStyle(color: textMain.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(height: 40),

                Text("Sync & Blog (Supabase)", 
                  style: GoogleFonts.spaceGrotesk(
                    color: borderGray, 
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                  )
                ),
                const SizedBox(height: 20),

                Text("Supabase Project URL", 
                  style: GoogleFonts.spaceGrotesk(color: textMain.withValues(alpha: 0.8), fontSize: 14)
                ),
                TextField(
                  controller: _supabaseUrlController,
                  style: GoogleFonts.jetBrainsMono(color: textMain),
                  decoration: InputDecoration(
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderGray)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                    hintText: "https://xyz.supabase.co",
                    hintStyle: TextStyle(color: textMain.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(height: 20),

                Text("Anon Public Key", 
                  style: GoogleFonts.spaceGrotesk(color: textMain.withValues(alpha: 0.8), fontSize: 14)
                ),
                TextField(
                  controller: _supabaseKeyController,
                  obscureText: true,
                  style: GoogleFonts.jetBrainsMono(color: textMain),
                  decoration: InputDecoration(
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderGray)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                    hintText: "eyJhbGci...",
                    hintStyle: TextStyle(color: textMain.withValues(alpha: 0.3)),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final noteService = Provider.of<NoteService>(context, listen: false);
                      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      
                      noteService.setNotesPath(_pathController.text);
                      await supabaseService.saveConfig(_supabaseUrlController.text, _supabaseKeyController.text);

                      messenger.showSnackBar(
                        const SnackBar(content: Text("Configuration Saved"))
                      );
                      navigator.pop();
                    },
                    icon: const Icon(Icons.save),
                    label: Text("Save Configuration", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: textMain,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
