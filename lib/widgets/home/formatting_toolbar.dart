import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';

class FormattingToolbar extends StatelessWidget {
  // History actions
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  // Text formatting
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onStrikethrough;
  final VoidCallback onCode;
  // Structure
  final VoidCallback onBulletList;
  final VoidCallback onCheckboxList;
  final VoidCallback onHeading;
  final VoidCallback onQuote;
  // Insertions
  final VoidCallback onTable;
  final VoidCallback onLink;
  final VoidCallback onDivider;
  final VoidCallback onImage;

  const FormattingToolbar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onBold,
    required this.onItalic,
    required this.onStrikethrough,
    required this.onCode,
    required this.onBulletList,
    required this.onCheckboxList,
    required this.onHeading,
    required this.onQuote,
    required this.onTable,
    required this.onLink,
    required this.onDivider,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context, listen: false).theme;
    final textMuted = theme.textMuted;
    final borderColor = theme.borderColor;
    final accent = theme.accent;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        border: Border(bottom: BorderSide(color: theme.borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // History Group
          _buildToolbarBtn(Icons.undo, accent, onUndo, "Undo (Ctrl+Z)"),
          _buildToolbarBtn(Icons.redo, accent, onRedo, "Redo (Ctrl+Y)"),
          VerticalDivider(color: borderColor, indent: 10, endIndent: 10),
          // Text Formatting Group
          _buildToolbarBtn(Icons.format_bold, textMuted, onBold, "Bold"),
          _buildToolbarBtn(Icons.format_italic, textMuted, onItalic, "Italic"),
          _buildToolbarBtn(Icons.strikethrough_s, textMuted, onStrikethrough, "Strikethrough"),
          _buildToolbarBtn(Icons.code, textMuted, onCode, "Inline Code"),
          VerticalDivider(color: borderColor, indent: 10, endIndent: 10),
          // Structure Group
          _buildToolbarBtn(Icons.format_list_bulleted, textMuted, onBulletList, "Bulleted List"),
          _buildToolbarBtn(Icons.check_box_outlined, textMuted, onCheckboxList, "Checklist"),
          _buildToolbarBtn(Icons.title, textMuted, onHeading, "Heading"),
          _buildToolbarBtn(Icons.format_quote, textMuted, onQuote, "Quote"),
          VerticalDivider(color: borderColor, indent: 10, endIndent: 10),
          // Insertions Group
          _buildToolbarBtn(Icons.table_chart_outlined, textMuted, onTable, "Insert Table"),
          _buildToolbarBtn(Icons.link, textMuted, onLink, "WikiLink"),
          _buildToolbarBtn(Icons.horizontal_rule, textMuted, onDivider, "Divider"),
          _buildToolbarBtn(Icons.image_outlined, textMuted, onImage, "Insert Image"),
        ],
      ),
    );
  }

  Widget _buildToolbarBtn(IconData icon, Color color, VoidCallback onPressed, String tooltip) {
    return IconButton(
      icon: Icon(icon, color: color, size: 18),
      onPressed: onPressed,
      tooltip: tooltip,
      hoverColor: color.withValues(alpha: 0.1),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}
