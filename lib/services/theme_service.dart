import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  final String name;
  final Color bgMain;
  final Color bgSidebar;
  final Color borderColor;
  final Color textMain;
  final Color textMuted;
  final Color accent;
  final Color success;

  AppTheme({
    required this.name,
    required this.bgMain,
    required this.bgSidebar,
    required this.borderColor,
    required this.textMain,
    required this.textMuted,
    required this.accent,
    this.success = const Color(0xFF3ECF8E),
  });
}

class ThemeService extends ChangeNotifier {
  static final AppTheme carijoDark = AppTheme(
    name: "Carijó Dark",
    bgMain: const Color(0xFF111111),
    bgSidebar: const Color(0xFF161616),
    borderColor: const Color(0xFF2A2A2A),
    textMain: const Color(0xFFF4F1EA),
    textMuted: const Color(0xFF8C8C8C),
    accent: const Color(0xFFD93025),
  );

  static final AppTheme dracula = AppTheme(
    name: "Dracula",
    bgMain: const Color(0xFF282a36),
    bgSidebar: const Color(0xFF21222c),
    borderColor: const Color(0xFF44475a),
    textMain: const Color(0xFFf8f8f2),
    textMuted: const Color(0xFF6272a4),
    accent: const Color(0xFFbd93f9),
  );

  static final AppTheme nord = AppTheme(
    name: "Nord",
    bgMain: const Color(0xFF2e3440),
    bgSidebar: const Color(0xFF242933),
    borderColor: const Color(0xFF3b4252),
    textMain: const Color(0xFFeceff4),
    textMuted: const Color(0xFF4c566a),
    accent: const Color(0xFF88c0d0),
  );

  static final AppTheme gruvbox = AppTheme(
    name: "Gruvbox",
    bgMain: const Color(0xFF282828),
    bgSidebar: const Color(0xFF1d2021),
    borderColor: const Color(0xFF3c3836),
    textMain: const Color(0xFFebdbb2),
    textMuted: const Color(0xFF928374),
    accent: const Color(0xFFfe8019),
  );

  static final AppTheme solarizedDark = AppTheme(
    name: "Solarized Dark",
    bgMain: const Color(0xFF002b36),
    bgSidebar: const Color(0xFF073642),
    borderColor: const Color(0xFF586e75),
    textMain: const Color(0xFF839496),
    textMuted: const Color(0xFF657b83),
    accent: const Color(0xFFb58900),
  );

  static final AppTheme monokaiPro = AppTheme(
    name: "Monokai Pro",
    bgMain: const Color(0xFF2d2a2e),
    bgSidebar: const Color(0xFF221f22),
    borderColor: const Color(0xFF403e41),
    textMain: const Color(0xFFfcfcfa),
    textMuted: const Color(0xFF727072),
    accent: const Color(0xFFffd866),
  );

  final List<AppTheme> themes = [carijoDark, dracula, nord, gruvbox, solarizedDark, monokaiPro];
  AppTheme _currentTheme = carijoDark;

  AppTheme get theme => _currentTheme;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('app_theme');
    if (themeName != null) {
      _currentTheme = themes.firstWhere((t) => t.name == themeName, orElse: () => carijoDark);
      notifyListeners();
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme.name);
    notifyListeners();
  }
}
