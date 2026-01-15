import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.bgMain,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette, color: theme.accent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    "Choose Theme",
                    style: GoogleFonts.spaceGrotesk(
                      color: theme.textMain, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.textMuted, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: themeService.themes.map((t) => _buildThemeCard(context, t, themeService)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, AppTheme t, ThemeService themeService) {
    final isSelected = themeService.theme.name == t.name;

    return GestureDetector(
      onTap: () {
        themeService.setTheme(t);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.bgSidebar,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? t.accent : t.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _colorDot(t.bgMain),
                const SizedBox(width: 4),
                _colorDot(t.accent),
                const SizedBox(width: 4),
                _colorDot(t.textMain),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              t.name,
              style: GoogleFonts.jetBrainsMono(
                color: t.textMain,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: t.accent, size: 12),
                    const SizedBox(width: 4),
                    Text("Active", style: GoogleFonts.jetBrainsMono(color: t.accent, fontSize: 9)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
    );
  }
}
