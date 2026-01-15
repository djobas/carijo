import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../domain/models/note.dart';

class GraphViewScreen extends StatefulWidget {
  final List<Note> notes;

  const GraphViewScreen({super.key, required this.notes});

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<NodeData> _nodes = [];
  final Random _random = Random();
  
  NodeData? _draggedNode;
  Offset? _hoverPos;

  @override
  void initState() {
    super.initState();
    _initializeGraph();
    _ticker = createTicker(_onTick)..start();
  }

  void _initializeGraph() {
    // 1. Create Nodes
    for (var note in widget.notes) {
      // Calculate link density for node size
      int connections = note.outgoingLinks.length + 
          widget.notes.where((n) => n.outgoingLinks.contains(note.title)).length;
      
      _nodes.add(NodeData(
        note: note,
        position: Offset(_random.nextDouble() * 800 + 400, _random.nextDouble() * 600 + 400),
        mass: 1.0 + (connections * 0.2),
        radius: 6.0 + (connections * 1.5).clamp(0, 20),
      ));
    }

    // 2. Link Nodes
    for (var node in _nodes) {
      for (var linkTitle in node.note.outgoingLinks) {
        final target = _nodes.where((n) => n.note.title == linkTitle).firstOrNull;
        if (target != null) {
          node.links.add(target);
        }
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    const double k = 120.0; // Ideal distance
    const double repulsionStrength = 8000.0;
    const double springStrength = 0.05;
    const double damping = 0.85;

    // 1. Repulsion (All nodes push each other)
    for (var i = 0; i < _nodes.length; i++) {
      for (var j = i + 1; j < _nodes.length; j++) {
        final nodeA = _nodes[i];
        final nodeB = _nodes[j];
        
        final delta = nodeB.position - nodeA.position;
        final distance = delta.distance;
        if (distance < 1.0) continue;

        final force = (repulsionStrength * nodeA.mass * nodeB.mass) / (distance * distance);
        final forceVector = delta / distance * force;

        if (nodeA != _draggedNode) nodeA.velocity -= forceVector / nodeA.mass;
        if (nodeB != _draggedNode) nodeB.velocity += forceVector / nodeB.mass;
      }
    }

    // 2. Attraction (Linked nodes pull each other)
    for (var node in _nodes) {
      for (var linked in node.links) {
        final delta = linked.position - node.position;
        final distance = delta.distance;
        if (distance < 1.0) continue;

        final force = springStrength * (distance - k);
        final forceVector = delta / distance * force;

        if (node != _draggedNode) node.velocity += forceVector / node.mass;
        if (linked != _draggedNode) linked.velocity -= forceVector / linked.mass;
      }
    }

    // 3. Center Gravity (Keep it focused)
    final center = const Offset(1000, 1000);
    for (var node in _nodes) {
      final delta = center - node.position;
      if (node != _draggedNode) {
        node.velocity += delta * 0.005;
      }
    }

    // 4. Apply Velocity & Damping
    setState(() {
      for (var node in _nodes) {
        if (node == _draggedNode) continue;
        node.position += node.velocity;
        node.velocity *= damping;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context).theme;

    return Scaffold(
      backgroundColor: theme.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("O Ninho (Graph V2)", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onPanStart: (details) {
          final localPos = _getLocalPosition(details.globalPosition, context);
          
          for (var node in _nodes) {
            if ((node.position - localPos).distance < node.radius + 10) {
              setState(() => _draggedNode = node);
              break;
            }
          }
        },
        onPanUpdate: (details) {
          final dragged = _draggedNode;
          if (dragged != null) {
            setState(() {
              dragged.position = _getLocalPosition(details.globalPosition, context);
              dragged.velocity = Offset.zero;
            });
          }
        },
        onPanEnd: (_) => setState(() => _draggedNode = null),
        onTapUp: (details) {
          final localPos = _getLocalPosition(details.globalPosition, context);
          for (var node in _nodes) {
            if ((node.position - localPos).distance < node.radius + 5) {
              Navigator.pop(context, node.note);
              break;
            }
          }
        },
        child: MouseRegion(
          onHover: (event) => setState(() => _hoverPos = _getLocalPosition(event.position, context)),
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(2000),
            minScale: 0.1,
            maxScale: 2.0,
            child: SizedBox(
              width: 2000,
              height: 2000,
              child: CustomPaint(
                painter: GraphPainter(
                  nodes: _nodes,
                  theme: theme,
                  hoverPos: _hoverPos,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _getLocalPosition(Offset globalPos, BuildContext context) {
    // This is approximate due to InteractiveViewer's transformations, 
    // but works for basic physics and interaction.
    // Ideally we'd use the Viewer's transformation controller.
    final renderBox = context.findRenderObject() as RenderBox;
    return renderBox.globalToLocal(globalPos) + const Offset(1000, 1000) - Offset(renderBox.size.width/2, renderBox.size.height/2);
  }
}

class NodeData {
  final Note note;
  Offset position;
  Offset velocity = Offset.zero;
  final double mass;
  final double radius;
  final List<NodeData> links = [];

  NodeData({
    required this.note,
    required this.position,
    required this.mass,
    required this.radius,
  });
}

class GraphPainter extends CustomPainter {
  final List<NodeData> nodes;
  final dynamic theme;
  final Offset? hoverPos;

  GraphPainter({
    required this.nodes,
    required this.theme,
    this.hoverPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = theme.borderColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;
    
    final nodePaint = Paint()
      ..color = theme.accent
      ..style = PaintingStyle.fill;

    // 1. Draw Edges
    for (var node in nodes) {
      for (var linked in node.links) {
        canvas.drawLine(node.position, linked.position, edgePaint);
      }
    }

    // 2. Draw Nodes
    for (var node in nodes) {
      final hp = hoverPos;
      final isHovered = hp != null && (node.position - hp).distance < node.radius + 5;
      
      // Node Circle
      canvas.drawCircle(
        node.position, 
        node.radius * (isHovered ? 1.2 : 1.0), 
        nodePaint..color = isHovered ? theme.accent : theme.accent.withValues(alpha: 0.8)
      );

      // Label (only if important or hovered)
      if (node.mass > 1.2 || isHovered) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: node.note.title, 
            style: GoogleFonts.inter(
              color: isHovered ? theme.textMain : theme.textMuted, 
              fontSize: 12 * (isHovered ? 1.2 : 1.0),
              fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
            )
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(canvas, Offset(node.position.dx + node.radius + 4, node.position.dy - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
