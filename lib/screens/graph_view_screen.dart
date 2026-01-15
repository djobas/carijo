import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/note_service.dart';
import '../domain/models/note.dart';

class GraphViewScreen extends StatefulWidget {
  final List<Note> notes;

  const GraphViewScreen({super.key, required this.notes});

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> {
  final Map<String, Offset> _positions = {};
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializePositions();
  }

  void _initializePositions() {
    for (var note in widget.notes) {
      _positions[note.title] = Offset(
        _random.nextDouble() * 1200 + 400,
        _random.nextDouble() * 800 + 400,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgMain = Color(0xFF0F0F0F);
    const accent = Color(0xFFD93025);
    const textMain = Color(0xFFF4F1EA);

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("O Ninho: Network Graph", style: GoogleFonts.spaceGrotesk(color: textMain, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(2000),
        minScale: 0.1,
        maxScale: 2.0,
        child: SizedBox(
          width: 2000,
          height: 2000,
          child: CustomPaint(
            painter: GraphPainter(
              notes: widget.notes,
              positions: _positions,
              accent: accent,
              textStyle: GoogleFonts.jetBrainsMono(color: textMain.withOpacity(0.5), fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<Note> notes;
  final Map<String, Offset> positions;
  final Color accent;
  final TextStyle textStyle;

  GraphPainter({
    required this.notes,
    required this.positions,
    required this.accent,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    
    final nodePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    // 1. Draw Edges
    for (var note in notes) {
      final startPos = positions[note.title];
      if (startPos == null) continue;

      for (var link in note.outgoingLinks) {
        final endPos = positions[link];
        if (endPos != null) {
          canvas.drawLine(startPos, endPos, linePaint);
        }
      }
    }

    // 2. Draw Nodes
    for (var note in notes) {
      final pos = positions[note.title];
      if (pos == null) continue;

      canvas.drawCircle(pos, 4, nodePaint);

      final textPainter = TextPainter(
        text: TextSpan(text: note.title, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(canvas, Offset(pos.dx + 8, pos.dy - 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
