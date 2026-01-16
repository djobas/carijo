import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carijo_notes/services/theme_service.dart';

void main() {
  group('AppTheme', () {
    test('Carijó Dark should have correct properties', () {
      final carijoDark = ThemeService.carijoDark;
      
      expect(carijoDark.name, 'Carijó Dark');
      expect(carijoDark.accent.value, 0xFFD93025);
      expect(carijoDark.bgMain, isNotNull);
      expect(carijoDark.bgSidebar, isNotNull);
    });

    test('Dracula should have correct accent color', () {
      final dracula = ThemeService.dracula;
      
      expect(dracula.name, 'Dracula');
      expect(dracula.accent.value, 0xFFbd93f9);
    });

    test('Nord should have correct accent color', () {
      final nord = ThemeService.nord;
      
      expect(nord.name, 'Nord');
      expect(nord.accent.value, 0xFF88c0d0);
    });

    test('Gruvbox should have correct accent color', () {
      final gruvbox = ThemeService.gruvbox;
      
      expect(gruvbox.name, 'Gruvbox');
      expect(gruvbox.accent.value, 0xFFfe8019);
    });

    test('Solarized Dark should have correct accent color', () {
      final solarized = ThemeService.solarizedDark;
      
      expect(solarized.name, 'Solarized Dark');
      expect(solarized.accent.value, 0xFFb58900);
    });

    test('Monokai Pro should have correct accent color', () {
      final monokai = ThemeService.monokaiPro;
      
      expect(monokai.name, 'Monokai Pro');
      expect(monokai.accent.value, 0xFFffd866);
    });

    test('all static themes should have required properties', () {
      final themes = [
        ThemeService.carijoDark,
        ThemeService.dracula,
        ThemeService.nord,
        ThemeService.gruvbox,
        ThemeService.solarizedDark,
        ThemeService.monokaiPro,
      ];
      
      for (final theme in themes) {
        expect(theme.name, isNotEmpty);
        expect(theme.bgMain, isNotNull);
        expect(theme.bgSidebar, isNotNull);
        expect(theme.borderColor, isNotNull);
        expect(theme.textMain, isNotNull);
        expect(theme.textMuted, isNotNull);
        expect(theme.accent, isNotNull);
        expect(theme.success, isNotNull);
      }
    });
  });
}
