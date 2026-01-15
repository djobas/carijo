import 'package:flutter_test/flutter_test.dart';
import 'package:carijo_notes/domain/models/note.dart';
import 'package:carijo_notes/domain/use_cases/search_notes_use_case.dart';

void main() {
  late SearchNotesUseCase searchUseCase;
  late List<Note> mockNotes;

  setUp(() {
    searchUseCase = SearchNotesUseCase();
    mockNotes = [
      Note(
        title: 'Flutter Guide',
        content: 'Learn Flutter development with Dart.',
        path: 'flutter.md',
        modified: DateTime.now(),
        tags: ['flutter', 'programming'],
      ),
      Note(
        title: 'Dart Basics',
        content: 'Understanding the Dart language.',
        path: 'dart.md',
        modified: DateTime.now(),
        tags: ['dart', 'programming'],
      ),
      Note(
        title: 'Architecture',
        content: 'Clean architecture in mobile apps.',
        path: 'arch.md',
        modified: DateTime.now(),
        tags: ['architecture'],
      ),
    ];
  });

  group('SearchNotesUseCase', () {
    test('should return all notes when query and tag are empty', () {
      final result = searchUseCase(notes: mockNotes, query: '');
      expect(result.length, 3);
    });

    test('should filter notes by title query', () {
      final result = searchUseCase(notes: mockNotes, query: 'Flutter');
      expect(result.length, 1);
      expect(result.first.title, 'Flutter Guide');
    });

    test('should filter notes by content query', () {
      final result = searchUseCase(notes: mockNotes, query: 'language');
      expect(result.length, 1);
      expect(result.first.title, 'Dart Basics');
    });

    test('should filter notes by tag', () {
      final result = searchUseCase(notes: mockNotes, query: '', filterTag: 'programming');
      expect(result.length, 2);
    });

    test('should filter notes by both query and tag', () {
      final result = searchUseCase(
        notes: mockNotes, 
        query: 'Dart', 
        filterTag: 'programming'
      );
      expect(result.length, 2);
      expect(result.any((n) => n.title == 'Dart Basics'), true);
      expect(result.any((n) => n.title == 'Flutter Guide'), true);
    });

    test('should be case insensitive', () {
      final result = searchUseCase(notes: mockNotes, query: 'fLuTtEr');
      expect(result.length, 1);
      expect(result.first.title, 'Flutter Guide');
    });

    test('should return empty list if no match found', () {
      final result = searchUseCase(notes: mockNotes, query: 'React');
      expect(result.isEmpty, true);
    });
  });
}
