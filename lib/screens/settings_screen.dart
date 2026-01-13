import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/note_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final path = Provider.of<NoteService>(context, listen: false).notesPath;
    _pathController.text = path ?? '';
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1A1A1A);
    const textMain = Color(0xFFF4F1EA);
    const accent = Color(0xFFD93025);
    const borderGray = Color(0xFF8C8C8C);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Settings", style: GoogleFonts.spaceGrotesk(color: textMain, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF333333), height: 1),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Storage & Sync", 
                style: GoogleFonts.spaceGrotesk(
                  color: borderGray, 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2
                )
              ),
              const SizedBox(height: 20),
              
              Text("Local Folder Path", 
                style: GoogleFonts.spaceGrotesk(color: textMain.withOpacity(0.8), fontSize: 14)
              ),
              TextField(
                controller: _pathController,
                style: GoogleFonts.jetBrainsMono(color: textMain),
                decoration: InputDecoration(
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: borderGray)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  hintText: "/home/user/notes",
                  hintStyle: TextStyle(color: textMain.withOpacity(0.3)),
                ),
              ),
              const SizedBox(height: 40),
              
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Provider.of<NoteService>(context, listen: false).setNotesPath(_pathController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Configuration Saved"))
                    );
                    Navigator.pop(context);
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
    );
  }
}