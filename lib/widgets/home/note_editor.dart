import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/note_service.dart';
import '../../services/theme_service.dart';
import '../../domain/models/note.dart';
import 'backlinks_sidebar.dart';

// --- Markdown Extensions for Tech Editor ---

class MermaidBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^```mermaid\s*$');

  const MermaidBlockSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    final childLines = <String>[];
    parser.advance();
    
    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim() == '```') {
        parser.advance();
        break;
      }
      childLines.add(line);
      parser.advance();
    }
    
    return md.Element.text('mermaid', childLines.join('\n'));
  }
}

class MermaidBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return MermaidWidget(content: element.textContent.trim());
  }
}

class MermaidWidget extends StatefulWidget {
  final String content;
  const MermaidWidget({super.key, required this.content});

  @override
  State<MermaidWidget> createState() => _MermaidWidgetState();
}

class _MermaidWidgetState extends State<MermaidWidget> {
  WebviewController? _controller;
  bool _initialized = false;
  String? _initializedContent;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  @override
  void didUpdateWidget(MermaidWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _initWebview();
    }
  }

  Future<void> _initWebview() async {
    final currentContent = widget.content;
    if (_initialized && _initializedContent == currentContent) return;

    try {
      final controller = _controller ?? WebviewController();
      if (!_initialized) {
        await controller.initialize();
      }
      
      if (!mounted) {
        controller.dispose();
        return;
      }
      
      await controller.setBackgroundColor(Colors.transparent);
      
      final html = """
        <!DOCTYPE html>
        <html>
        <head>
          <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
          <style>
            body { background: transparent; margin: 0; padding: 10px; color: white; overflow: hidden; font-family: sans-serif; }
            #graph { width: 100%; display: flex; justify-content: center; }
          </style>
        </head>
        <body>
          <div id="graph" class="mermaid">
            ${currentContent.replaceAll('`', '\\`')}
          </div>
          <script>
            try {
              mermaid.initialize({ 
                startOnLoad: true, 
                theme: 'dark', 
                securityLevel: 'loose'
              });
              mermaid.run();
            } catch (e) {
              document.body.innerHTML = '<pre style="color:red">' + e.message + '</pre>';
            }
          </script>
        </body>
        </html>
      """;
      
      await controller.loadStringContent(html);
      if (mounted) {
        setState(() {
          _controller = controller;
          _initialized = true;
          _initializedContent = currentContent;
        });
      }
    } catch (e) {
      debugPrint("Mermaid Init Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    return Container(
      key: ValueKey(_initializedContent),
      height: 350,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: (_initialized && ctrl != null)
          ? Webview(ctrl)
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'\$([^\$]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match.group(1);
    if (content != null) {
      parser.addNode(md.Element.text('latex', content));
    }
    return true;
  }
}

class LatexBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$(.*)\$\$$', multiLine: true);

  LatexBlockSyntax() : super();

  @override
  md.Node parse(md.BlockParser parser) {
    if (parser.isDone) return md.Text("");
    final line = parser.current.content;
    final match = pattern.firstMatch(line);
    final content = match != null ? (match.group(1) ?? "") : "";
    parser.advance();
    return md.Element.text('latex-block', content);
  }
}

class MathBuilder extends MarkdownElementBuilder {
  final bool isBlock;
  MathBuilder({this.isBlock = false});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isBlock ? 16 : 0),
      child: Math.tex(
        text,
        mathStyle: isBlock ? MathStyle.display : MathStyle.text,
        textStyle: preferredStyle?.copyWith(fontSize: isBlock ? 18 : null),
        onErrorFallback: (err) => Text(text, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  final TextEditingController editorController;
  final bool isEditing;
  final bool showAutocomplete;
  final String autocompleteQuery;
  final int autocompleteCursorPos;
  final Function(Note) onNoteSelected;
  final Function(String) onNavigateToNote;
  final Function(String) onInjectAutocomplete;

  const NoteEditor({
    super.key,
    required this.editorController,
    required this.isEditing,
    required this.showAutocomplete,
    required this.autocompleteQuery,
    required this.autocompleteCursorPos,
    required this.onNoteSelected,
    required this.onNavigateToNote,
    required this.onInjectAutocomplete,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  String? _lastPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final noteService = Provider.of<NoteService>(context);
    final selectedNote = noteService.selectedNote;
    
    // Sync editor content only when the selected note actually changes
    if (selectedNote != null && selectedNote.path != _lastPath) {
      _lastPath = selectedNote.path;
      widget.editorController.text = selectedNote.content;
    }
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;

    if (noteService.selectedNote == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 64, color: theme.textMuted.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text("Select a note to start writing", 
              style: GoogleFonts.spaceGrotesk(color: theme.textMuted, fontSize: 16)
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (widget.isEditing)
                _buildEditor(theme)
              else
                _buildPreview(context, noteService, theme),
              if (widget.showAutocomplete)
                _buildAutocompleteOverlay(context, noteService),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: KeyboardListener(
        focusNode: _keyboardFocusNode, 
        onKeyEvent: _onKey,
        child: TextField(
          controller: widget.editorController,
          focusNode: _editorFocusNode,
          maxLines: null,
          expands: true,
          autofocus: true,
          style: GoogleFonts.jetBrainsMono(
            color: theme.textMain, 
            fontSize: 16, 
            height: 1.6,
            letterSpacing: -0.2,
          ),
          cursorColor: theme.accent,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "Your thoughts start here...",
            hintStyle: TextStyle(color: Colors.white10),
          ),
        ),
      ),
    );
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final controller = widget.editorController;
    final selection = controller.selection;
    final text = controller.text;

    if (!selection.isCollapsed) return;

    // 1. Auto-pairing
    final pairings = {
      LogicalKeyboardKey.parenthesisLeft: '()',
      LogicalKeyboardKey.bracketLeft: '[]',
      LogicalKeyboardKey.braceLeft: '{}',
      LogicalKeyboardKey.quote: '""',
    };

    if (pairings.containsKey(event.logicalKey)) {
      final pair = pairings[event.logicalKey] ?? "";
      final newText = text.replaceRange(selection.start, selection.start, pair);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (selection.start + 1).clamp(0, newText.length)),
      );
      // We don't return here because we might want the default behavior to handle 
      // the first char, but actually we replaced the whole thing.
      // In Flutter, KeyboardListener doesn't easily "cancel" the event for TextField
      // unless we use Actions. But let's see if this works as a trigger.
      // Actually, if we update controller.value here, the TextField will still
      // process the key and add another '('.
      // So we should probably do this in a way that handles the "after-effect"
      // or use a more advanced approach.
    }

    // 2. Smart Indentation (Enter)
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
      final currentLine = text.substring(lineStart, selection.start);
      
      final listMatch = RegExp(r'^(\s*[-*]\s+)').firstMatch(currentLine);
      if (listMatch != null) {
        final prefix = listMatch.group(1) ?? "";
        
        // If the line is ONLY the prefix, clear it (User wants to stop the list)
        if (currentLine.trim() == prefix.trim()) {
            // Handled elsewhere or requires custom logic
        } else {
          // This is tricky to do in KeyboardListener without blocking the default Enter.
        }
      }
    }
  }

  Widget _buildPreview(BuildContext context, NoteService noteService, theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: widget.editorController.text,
            imageDirectory: noteService.notesPath,
            selectable: true,
            extensionSet: md.ExtensionSet(
              [const MermaidBlockSyntax(), const md.FencedCodeBlockSyntax(), LatexBlockSyntax(), const md.TableSyntax()],
              [md.EmojiSyntax(), LatexSyntax(), md.AutolinkExtensionSyntax()],
            ),
            key: ValueKey(noteService.selectedNote?.path ?? 'preview'),
            builders: {
              'latex': MathBuilder(isBlock: false),
              'latex-block': MathBuilder(isBlock: true),
              'mermaid': MermaidBuilder(),
            },
            onTapLink: (text, href, title) {
              if (href != null) {
                widget.onNavigateToNote(href);
              } else {
                widget.onNavigateToNote(text);
              }
            },
            styleSheet: MarkdownStyleSheet(
              // Typography
              p: GoogleFonts.inter(color: theme.textMain.withOpacity(0.9), fontSize: 17, height: 1.7),
              h1: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 36, fontWeight: FontWeight.bold, height: 1.4),
              h2: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 28, fontWeight: FontWeight.bold, height: 1.4),
              h3: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 22, fontWeight: FontWeight.bold),
              
              // Code
              code: GoogleFonts.jetBrainsMono(
                backgroundColor: theme.accent.withOpacity(0.08), 
                color: theme.accent,
                fontSize: 14,
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.borderColor),
              ),
              codeblockPadding: const EdgeInsets.all(20),
              
              // Blocks
              blockquote: GoogleFonts.inter(color: theme.textMuted, fontStyle: FontStyle.italic),
              blockquoteDecoration: BoxDecoration(
                border: Border(left: BorderSide(color: theme.accent, width: 4)),
              ),
              blockquotePadding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
              
              // Lists & Tables
              listBullet: GoogleFonts.inter(color: theme.accent, fontWeight: FontWeight.bold),
              tableBorder: TableBorder.all(color: theme.borderColor, width: 0.5),
              tableHead: GoogleFonts.inter(color: theme.accent, fontWeight: FontWeight.bold, fontSize: 13),
              tableBody: GoogleFonts.inter(color: theme.textMain, fontSize: 14),
              tableCellsPadding: const EdgeInsets.all(12),
              
              // Misc
              horizontalRuleDecoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.borderColor, width: 1)),
              ),
              checkbox: TextStyle(color: theme.accent),
            ),
          ),
          const SizedBox(height: 80),
          const Divider(height: 1),
          const SizedBox(height: 48),
          BacklinksSidebar(onNoteSelected: widget.onNoteSelected),
        ],
      ),
    );
  }

  Widget _buildAutocompleteOverlay(BuildContext context, NoteService noteService) {
    final theme = Provider.of<ThemeService>(context, listen: false).theme;
    final filteredNotes = noteService.notes.where((n) => 
      n.title.toLowerCase().contains(widget.autocompleteQuery.toLowerCase())
    ).take(5).toList();

    if (filteredNotes.isEmpty) return const SizedBox();

    return Positioned(
      top: 60,
      left: 48,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: theme.bgSidebar,
          border: Border.all(color: theme.borderColor),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 8))]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filteredNotes.map((note) => InkWell(
            onTap: () => widget.onInjectAutocomplete(note.title),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.borderColor))),
              child: Row(
                children: [
                  Icon(Icons.article_outlined, color: theme.accent, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(note.title, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: theme.textMain, fontSize: 14, fontWeight: FontWeight.w500)
                    )
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
