import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';

class FormattingToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onCode;
  final VoidCallback onBulletList;
  final VoidCallback onCheckboxList;
  final VoidCallback onHeading;

  const FormattingToolbar({
    super.key,
    required this.onBold,
    required this.onItalic,
    required this.onCode,
    required this.onBulletList,
    required this.onCheckboxList,
    required this.onHeading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context, listen: false).theme;
    final textMuted = theme.textMuted;
    final borderColor = theme.borderColor;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        border: Border(bottom: BorderSide(color: theme.borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          _buildToolbarBtn(Icons.format_bold, textMuted, onBold),
          _buildToolbarBtn(Icons.format_italic, textMuted, onItalic),
          _buildToolbarBtn(Icons.code, textMuted, onCode),
          VerticalDivider(color: borderColor, indent: 10, endIndent: 10),
          _buildToolbarBtn(Icons.format_list_bulleted, textMuted, onBulletList),
          _buildToolbarBtn(Icons.check_box_outlined, textMuted, onCheckboxList),
          _buildToolbarBtn(Icons.title, textMuted, onHeading),
        ],
      ),
    );
  }

  Widget _buildToolbarBtn(IconData icon, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: color, size: 18),
      onPressed: onPressed,
      hoverColor: color.withOpacity(0.1),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}
