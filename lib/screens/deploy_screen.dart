import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/git_service.dart';
import '../services/note_service.dart';

class DeployScreen extends StatefulWidget {
  const DeployScreen({super.key});

  @override
  State<DeployScreen> createState() => _DeployScreenState();
}

class _DeployScreenState extends State<DeployScreen> {
  List<GitFile> _gitFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    final noteService = Provider.of<NoteService>(context, listen: false);
    final gitService = Provider.of<GitService>(context, listen: false);
    
    if (noteService.notesPath != null) {
      final files = await gitService.getGitStatus(noteService.notesPath!);
      setState(() {
        _gitFiles = files;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgMain = Color(0xFF1A1A1A);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);
    const borderColor = Color(0xFF333333);
    const surface = Color(0xFF1F1F1F);

    final noteService = Provider.of<NoteService>(context);
    final gitService = Provider.of<GitService>(context);

    final stagedFiles = _gitFiles.where((f) => f.isStaged).toList();
    final unstagedFiles = _gitFiles.where((f) => !f.isStaged).toList();

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: bgMain,
        title: Text("Staging Area", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: textMain)),
        iconTheme: const IconThemeData(color: textMain),
        actions: [
          IconButton(
            onPressed: _refreshStatus, 
            icon: const Icon(Icons.refresh, color: textMuted)
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: gitService.lastError == null ? Colors.green : accent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(gitService.lastError == null ? "system: stable" : "system: error", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // Sidebar (Staged Files)
          Container(
            width: 350,
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: accent))
              : ListView(
                  children: [
                    if (stagedFiles.isNotEmpty) ...[
                      _buildHeader("READY FOR PUSH", stagedFiles.length, accent),
                      ...stagedFiles.map((f) => _buildFileItem(f, noteService.notesPath!)),
                    ],
                    if (unstagedFiles.isNotEmpty) ...[
                      _buildHeader("UNSTAGED CHANGES", unstagedFiles.length, textMuted),
                      ...unstagedFiles.map((f) => _buildFileItem(f, noteService.notesPath!)),
                    ],
                    if (_gitFiles.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text("No changes detected", style: GoogleFonts.jetBrainsMono(color: textMuted)),
                        ),
                      )
                  ],
                ),
          ),
          
          // Main Diff Area
          Expanded(
            child: Stack(
              children: [
                if (gitService.lastError != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        border: Border.all(color: accent.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(gitService.lastError!, style: GoogleFonts.jetBrainsMono(color: accent, fontSize: 12)),
                    ),
                  )
                else
                  Center(
                    child: Text("Select a file to view diff (Coming Soon)", style: GoogleFonts.jetBrainsMono(color: textMuted)),
                  ),
                  
                Positioned(
                  top: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: (gitService.isSyncing || noteService.notesPath == null) 
                      ? null 
                      : () async {
                          await gitService.pushToBlog(noteService.notesPath!);
                          _refreshStatus();
                        },
                    icon: gitService.isSyncing 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: textMain)) 
                      : const Icon(Icons.cloud_upload),
                    label: Text(gitService.isSyncing ? "SYNCING..." : "PUSH TO BLOG"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: textMain,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text("$count FILES", style: GoogleFonts.jetBrainsMono(color: color, fontSize: 10)),
          )
        ],
      ),
    );
  }

  Widget _buildFileItem(GitFile file, String workingDir) {
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);
    const surface = Color(0xFF1F1F1F);
    
    return InkWell(
      onTap: () async {
        await Provider.of<GitService>(context, listen: false)
            .toggleStaging(file.path, !file.isStaged, workingDir);
        _refreshStatus();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: file.isStaged ? surface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: file.isStaged ? accent.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              file.isStaged ? Icons.check_box : Icons.check_box_outline_blank, 
              color: file.isStaged ? accent : textMuted, 
              size: 18
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.path.split('/').last, style: GoogleFonts.jetBrainsMono(color: textMain, fontWeight: FontWeight.w500, fontSize: 13)),
                Text(file.status.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 9, letterSpacing: 1)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
