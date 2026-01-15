import 'package:flutter_test/flutter_test.dart';
import 'package:carijo_notes/domain/models/note.dart';
import 'package:carijo_notes/domain/use_cases/get_backlinks_use_case.dart';

void main() {
  late GetBacklinksUseCase getBacklinksUseCase;
  late List<Note> mockNotes;

  setUp(() {
    getBacklinksUseCase = GetBacklinksUseCase();
    mockNotes = [
      Note(
        title: 'Flutter',
        content: 'Main note about Flutter.',
        path: 'flutter.md',
        modified: DateTime.now(),
      ),
      Note(
        title: 'Architecture',
        content: 'Discussing [[Flutter]] clean architecture.',
        path: 'arch.md',
        modified: DateTime.now(),
      ),
      Note(
        title: 'State Management',
        content: 'Provider is good for [[Flutter]] apps.',
        path: 'state.md',
        modified: DateTime.now(),
      ),
      Note(
        title: 'Random',
        content: 'No links here.',
        path: 'random.md',
        modified: DateTime.now(),
      ),
    ];
  });

  group('GetBacklinksUseCase', () {
    test('should find all notes linking to target note', () {
      final targetNote = mockNotes[0]; // Flutter
      final result = getBacklinksUseCase(targetNote: targetNote, allNotes: mockNotes);
      
      expect(result.length, 2);
      expect(result.any((m) => m.note.title == 'Architecture'), true);
      expect(result.any((m) => m.note.title == 'State Management'), true);
    });

    test('should capture the line content containing the link', () {
      final targetNote = mockNotes[0]; // Flutter
      final result = getBacklinksUseCase(targetNote: targetNote, allNotes: mockNotes);
      
      final archMatch = result.firstWhere((m) => m.note.title == 'Architecture');
      expect(archMatch.snippet, contains('Discussing [[Flutter]] clean architecture.'));
    });

    test('should not include the target note itself in backlinks', () {
      // Create a note that links to itself
      final circularNote = Note(
        title: 'Self',
        content: 'Linking to [[Self]].',
        path: 'self.md',
        modified: DateTime.now(),
      );
      
      final result = getBacklinksUseCase(targetNote: circularNote, allNotes: [circularNote]);
      expect(result.isEmpty, true);
    });

    test('should handle multiple links in different notes', () {
      final targetNote = mockNotes[0];
      final result = getBacklinksUseCase(targetNote: targetNote, allNotes: mockNotes);
      expect(result.length, 2);
    });

    test('should return empty list if no notes link to target', () {
      final targetNote = mockNotes[3]; // Random
      final result = getBacklinksUseCase(targetNote: targetNote, allNotes: mockNotes);
      expect(result.isEmpty, true);
    });
  });
}
