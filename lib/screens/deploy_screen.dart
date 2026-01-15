import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/git_service.dart';
import '../services/note_service.dart';
import '../services/supabase_service.dart';

class DeployScreen extends StatefulWidget {
  const DeployScreen({super.key});

  @override
  State<DeployScreen> createState() => _DeployScreenState();
}

class _DeployScreenState extends State<DeployScreen> {
  List<GitFile> _gitFiles = [];
  bool _isLoading = false;
  
  // Diff View State
  String? _selectedFilePath;
  String? _diffContent;
  bool _isDiffLoading = false;

  final TextEditingController _commitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    final noteService = Provider.of<NoteService>(context, listen: false);
    final gitService = Provider.of<GitService>(context, listen: false);
    
    final path = noteService.notesPath;
    if (path != null) {
      final files = await gitService.getGitStatus(path);
      if (!mounted) return;
      setState(() {
        _gitFiles = files;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDiff(String path) async {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final gitService = Provider.of<GitService>(context, listen: false);
    
    if (noteService.notesPath == null) return;

    setState(() {
      _selectedFilePath = path;
      _isDiffLoading = true;
      _diffContent = null;
    });

    final notesPath = noteService.notesPath;
    if (notesPath == null) return;

    try {
      final diff = await gitService.getFileDiff(path, notesPath);
      if (!mounted) return;
      setState(() {
        _diffContent = diff;
        _isDiffLoading = false;
      });
    } catch (e) {
      setState(() {
        _diffContent = "Error loading diff: $e";
        _isDiffLoading = false;
      });
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
    const supabaseAccent = Color(0xFF3ECF8E);

    final noteService = Provider.of<NoteService>(context);
    final gitService = Provider.of<GitService>(context);
    final supabaseService = Provider.of<SupabaseService>(context);

    final stagedFiles = _gitFiles.where((f) => f.isStaged).toList();
    final unstagedFiles = _gitFiles.where((f) => !f.isStaged).toList();

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: bgMain,
        title: Text("Deploy & Sync", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: textMain)),
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
                Text(gitService.lastError == null ? "Git: OK" : "Git: Error", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12)),
                const SizedBox(width: 16),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: supabaseService.isInitialized ? supabaseAccent : textMuted, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(supabaseService.isInitialized ? "Supabase: ON" : "Supabase: OFF", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12)),
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
                      ...stagedFiles.map((f) => _buildFileItem(f, noteService.notesPath ?? '')),
                    ],
                    if (unstagedFiles.isNotEmpty) ...[
                      _buildHeader("UNSTAGED CHANGES", unstagedFiles.length, textMuted),
                      ...unstagedFiles.map((f) => _buildFileItem(f, noteService.notesPath ?? '')),
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
                if (_isDiffLoading)
                  const Center(child: CircularProgressIndicator(color: accent))
                else if (gitService.lastError != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        border: Border.all(color: accent.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(gitService.lastError ?? "Unknown Error", style: GoogleFonts.jetBrainsMono(color: accent, fontSize: 12)),
                    ),
                  )
                else if (_diffContent != null)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedFilePath ?? "", style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: borderColor),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: (_diffContent ?? "").split('\n').map((line) {
                                  Color color = textMain;
                                  if (line.startsWith('+')) color = Colors.greenAccent;
                                  if (line.startsWith('-')) color = accent;
                                  if (line.startsWith('@@')) color = textMuted;

                                  return Text(line, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 12, height: 1.4));
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.compare_arrows, size: 48, color: borderColor),
                        const SizedBox(height: 16),
                        Text("Select a file to review changes", style: GoogleFonts.jetBrainsMono(color: textMuted)),
                      ],
                    ),
                  ),
                  
                Positioned(
                  top: 20,
                  right: 20,
                  child: Column(
                    children: [
                      // Git Card
                      Container(
                        width: 400,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("GIT COMMIT & PUSH", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commitController,
                              style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 12),
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: "Commit message...",
                                hintStyle: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 12),
                                fillColor: const Color(0xFF111111),
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: (gitService.isSyncing || noteService.notesPath == null) 
                                ? null 
                                : () async {
                                    final path = noteService.notesPath;
                                    if (path != null) {
                                      await gitService.pushToBlog(
                                        path, 
                                        commitMessage: _commitController.text.isNotEmpty ? _commitController.text : null
                                      );
                                      if (gitService.lastError == null) {
                                        _commitController.clear();
                                        _refreshStatus();
                                      }
                                    }
                                  },
                              icon: gitService.isSyncing 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: textMain)) 
                                : const Icon(Icons.cloud_upload),
                              label: Text(gitService.isSyncing ? "SYNCING..." : "PUSH TO GIT"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: textMain,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Supabase Card
                      Container(
                        width: 400,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("BLOG SYNC (SUPABASE)", style: GoogleFonts.spaceGrotesk(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                if (supabaseService.lastError != null)
                                  const Icon(Icons.error_outline, color: accent, size: 14),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "This will sync all your notes to the Supabase 'notes' table.", 
                              style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 11)
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: (supabaseService.isSyncing || !supabaseService.isInitialized) 
                                ? null 
                                : () async {
                                    try {
                                      await supabaseService.syncAll(noteService.notes);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Blog Sync Successful"))
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Sync Error: $e"), backgroundColor: accent)
                                      );
                                    }
                                  },
                              icon: supabaseService.isSyncing 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: textMain)) 
                                : const Icon(Icons.bolt),
                              label: Text(supabaseService.isSyncing ? "SYNCING..." : "SYNC TO BLOG"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: supabaseAccent,
                                foregroundColor: bgMain,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
    
    final isSelected = _selectedFilePath == file.path;

    return InkWell(
      onTap: () => _fetchDiff(file.path),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? surface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? accent.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () async {
                await Provider.of<GitService>(context, listen: false)
                    .toggleStaging(file.path, !file.isStaged, workingDir);
                _refreshStatus();
              },
              child: Icon(
                file.isStaged ? Icons.check_box : Icons.check_box_outline_blank, 
                color: file.isStaged ? accent : textMuted, 
                size: 18
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.path.split('/').last, style: GoogleFonts.jetBrainsMono(color: textMain, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
                Text(file.status.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 9, letterSpacing: 1)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
