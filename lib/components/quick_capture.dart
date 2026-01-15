import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/note_service.dart';
import '../domain/models/note.dart';

class QuickCaptureDialog extends StatefulWidget {
  const QuickCaptureDialog({super.key});

  @override
  State<QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends State<QuickCaptureDialog> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Use RawKeyboardListener in build to catch Enter
  }

  void _saveAndClose() {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final filename = 'capture_$timestamp.md';

    Provider.of<NoteService>(context, listen: false).saveNote(filename, content);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Design System Colors
    const bgDark = Color(0xFF1A1A1A);
    const borderColor = Color(0xFF333333);
    const accent = Color(0xFFD93025);
    const textMain = Color(0xFFF4F1EA);
    const textMuted = Color(0xFF8C8C8C);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 600,
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag, color: textMuted, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      "Quick Capture",
                      style: GoogleFonts.jetBrainsMono(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        border: Border.all(color: accent.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "ENTER TO SAVE",
                        style: GoogleFonts.jetBrainsMono(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              // Input
              RawKeyboardListener(
                focusNode: FocusNode(), // Dummy node to capture keys
                onKey: (event) {
                  if (event is RawKeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter && !event.isShiftPressed) {
                      _saveAndClose();
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                child: TextField(
                  controller: _contentController,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: 6,
                  minLines: 3,
                  style: GoogleFonts.jetBrainsMono(color: textMain, fontSize: 16),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    hintText: "Type your thought...",
                    hintStyle: GoogleFonts.jetBrainsMono(color: textMuted.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(24),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1F1F1F),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                     const Icon(Icons.code, color: textMuted, size: 18),
                     const SizedBox(width: 8),
                     Text(
                       "Markdown supported",
                       style: GoogleFonts.jetBrainsMono(color: textMuted, fontSize: 10),
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
}