import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/git_service.dart';

class DeployScreen extends StatelessWidget {
  const DeployScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bgMain = Color(0xFF1A1A1A);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);
    const borderColor = Color(0xFF333333);
    const surface = Color(0xFF1F1F1F);

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: bgMain,
        title: Text("Staging Area", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: textMain)),
        iconTheme: const IconThemeData(color: textMain),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: borderColor, height: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text("system: stable", style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // Sidebar (Staged Files)
          Container(
            width: 300,
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("READY FOR PUSH", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: accent, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text("2 FILES", style: GoogleFonts.jetbrainsMono(color: accent, fontSize: 10)),
                      )
                    ],
                  ),
                ),
                _buildFileItem("new-feature-launch.md", "src/posts/", true),
                _buildFileItem("config.json", "src/settings/", true),
                
                const Divider(color: borderColor),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("UNSTAGED CHANGES", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: textMuted, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(4)),
                        child: Text("3 FILES", style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 10)),
                      )
                    ],
                  ),
                ),
                _buildFileItem("draft-post-01.md", "src/drafts/", false),
                _buildFileItem("notes-refactor.md", "src/notes/", false),
              ],
            ),
          ),
          
          // Main Diff Area
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Text("Select a file to view diff", style: GoogleFonts.jetbrainsMono(color: textMuted)),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Consumer<GitService>(
                    builder: (context, git, child) {
                      return ElevatedButton.icon(
                        onPressed: git.isSyncing ? null : () => git.pushToBlog(),
                        icon: git.isSyncing 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: textMain)) 
                          : const Icon(Icons.cloud_upload),
                        label: Text(git.isSyncing ? "SYNCING..." : "PUSH TO BLOG"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: textMain,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFileItem(String name, String path, bool checked) {
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);
    const accent = Color(0xFFD93025);
    const surface = Color(0xFF1F1F1F);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: checked ? surface : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: checked ? accent.withOpacity(0.3) : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank, 
            color: checked ? accent : textMuted, 
            size: 18
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.jetbrainsMono(color: textMain, fontWeight: FontWeight.w500)),
              Text(path, style: GoogleFonts.jetbrainsMono(color: textMuted, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }
}