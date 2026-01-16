import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context).theme;

    return Container(
      height: 32,
      color: theme.bgSidebar,
      child: WindowCaption(
        brightness: Brightness.dark,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.edit_note, size: 16, color: theme.accent),
            const SizedBox(width: 8),
            Text(
              "Carijó Notes",
              style: GoogleFonts.spaceGrotesk(
                color: theme.textMain,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowCaption extends StatelessWidget {
  final Widget? title;
  final Color backgroundColor;
  final Brightness brightness;

  const WindowCaption({
    super.key,
    this.title,
    this.backgroundColor = Colors.transparent,
    this.brightness = Brightness.light,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                padding: const EdgeInsets.only(left: 16),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: brightness == Brightness.light ? Colors.black : Colors.white,
                    fontSize: 14,
                  ),
                  child: title ?? Container(),
                ),
              ),
            ),
          ),
          const WindowButtons(),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context).theme;
    
    return Row(
      children: [
        WindowButton(
          icon: Icons.minimize,
          onPressed: () => windowManager.minimize(),
          hoverColor: Colors.white10,
        ),
        WindowButton(
          icon: Icons.crop_square,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
          hoverColor: Colors.white10,
        ),
        WindowButton(
          icon: Icons.close,
          onPressed: () => windowManager.close(),
          hoverColor: Colors.red.withValues(alpha: 0.8),
          iconHoverColor: Colors.white,
        ),
      ],
    );
  }
}

class WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? iconHoverColor;

  const WindowButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    this.iconHoverColor,
  });

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context).theme;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onPressed,
        child: Container(
          width: 45,
          height: 32,
          color: _isHovering ? widget.hoverColor : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovering && widget.iconHoverColor != null 
                ? widget.iconHoverColor 
                : theme.textMuted,
          ),
        ),
      ),
    );
  }
}
