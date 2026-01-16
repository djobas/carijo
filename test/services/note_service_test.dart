import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carijo_notes/domain/models/note.dart';
import 'package:carijo_notes/domain/repositories/note_repository.dart';
import 'package:carijo_notes/domain/use_cases/search_notes_use_case.dart';
import 'package:carijo_notes/domain/use_cases/get_backlinks_use_case.dart';
import 'package:carijo_notes/domain/use_cases/save_note_use_case.dart';

/// Mock implementation of NoteRepository for testing
class MockNoteRepository implements NoteRepository {
  List<Note> mockNotes = [];
  String? lastSavedPath;
  String? lastSavedContent;
  String? lastDeletedPath;
  bool shouldThrowOnGetAll = false;
  bool shouldThrowOnDelete = false;

  @override
  Future<List<Note>> getAllNotes(String path) async {
    if (shouldThrowOnGetAll) {
      throw Exception('Failed to load notes');
    }
    return mockNotes;
  }

  @override
  Future<void> saveNote(String path, String content) async {
    lastSavedPath = path;
    lastSavedContent = content;
    mockNotes.add(Note(
      title: path.split('/').last.replaceAll('.md', ''),
      content: content,
      path: path,
      modified: DateTime.now(),
    ));
  }

  @override
  Future<void> deleteNote(String path) async {
    if (shouldThrowOnDelete) {
      throw Exception('Failed to delete note');
    }
    lastDeletedPath = path;
    mockNotes.removeWhere((n) => n.path == path);
  }

  @override
  Future<String?> uploadImage(String notesPath, File imageFile) async {
    return '![image](assets/${imageFile.path.split('/').last})';
  }

  @override
  Future<List<Note>> getTemplates(String notesPath) async {
    return mockNotes.where((n) => n.path.contains('_templates')).toList();
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    return mockNotes.where((n) => 
      n.title.toLowerCase().contains(query.toLowerCase()) ||
      n.content.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
}

void main() {
  group('SearchNotesUseCase', () {
    late SearchNotesUseCase searchUseCase;

    setUp(() {
      searchUseCase = SearchNotesUseCase();
    });

    test('should return all notes when query is empty', () {
      final notes = [
        Note(title: 'Flutter', content: 'Content', path: 'a.md', modified: DateTime.now()),
        Note(title: 'Dart', content: 'Content', path: 'b.md', modified: DateTime.now()),
      ];

      final result = searchUseCase(notes: notes, query: '', filterTag: null);
      
      expect(result.length, 2);
    });

    test('should filter by tag when provided', () {
      final notes = [
        Note(title: 'Flutter', content: 'Content', path: 'a.md', modified: DateTime.now(), tags: ['dart', 'flutter']),
        Note(title: 'Dart', content: 'Content', path: 'b.md', modified: DateTime.now(), tags: ['dart']),
        Note(title: 'Python', content: 'Content', path: 'c.md', modified: DateTime.now(), tags: ['python']),
      ];

      final result = searchUseCase(notes: notes, query: '', filterTag: 'flutter');
      
      expect(result.length, 1);
      expect(result[0].title, 'Flutter');
    });
  });

  group('GetBacklinksUseCase', () {
    late GetBacklinksUseCase getBacklinksUseCase;

    setUp(() {
      getBacklinksUseCase = GetBacklinksUseCase();
    });

    test('should find notes linking to target', () {
      final targetNote = Note(
        title: 'Flutter',
        content: 'Main flutter content',
        path: 'flutter.md',
        modified: DateTime.now(),
      );

      final allNotes = [
        targetNote,
        Note(
          title: 'Dart',
          content: 'Dart is used in [[Flutter]]',
          path: 'dart.md',
          modified: DateTime.now(),
        ),
        Note(
          title: 'Python',
          content: 'No links here',
          path: 'python.md',
          modified: DateTime.now(),
        ),
      ];

      final result = getBacklinksUseCase(targetNote: targetNote, allNotes: allNotes);
      
      expect(result.length, 1);
      expect(result[0].note.title, 'Dart');
    });
  });

  group('SaveNoteUseCase', () {
    late SaveNoteUseCase saveNoteUseCase;
    late MockNoteRepository mockRepository;

    setUp(() {
      mockRepository = MockNoteRepository();
      saveNoteUseCase = SaveNoteUseCase(mockRepository);
    });

    test('should save note content to repository', () async {
      final note = Note(
        title: 'Test',
        content: '# Old',
        path: '/test/note.md',
        modified: DateTime.now(),
      );

      await saveNoteUseCase(note: note, newContent: '# New Content');
      
      expect(mockRepository.lastSavedPath, '/test/note.md');
      expect(mockRepository.lastSavedContent, '# New Content');
    });

    test('should return updated note with new content', () async {
      final note = Note(
        title: 'Test',
        content: '# Old',
        path: '/test/note.md',
        modified: DateTime.now().subtract(const Duration(days: 1)),
      );

      final result = await saveNoteUseCase(note: note, newContent: '# Updated');
      
      expect(result.content, '# Updated');
      expect(result.modified.isAfter(note.modified), true);
    });
  });

  group('Note.fromContent', () {
    test('should parse title from H1', () {
      final note = Note.fromContent(
        content: '# My Title\n\nSome content',
        path: '/notes/test.md',
        modified: DateTime.now(),
      );

      expect(note.title, 'My Title');
    });

    test('should parse title from frontmatter', () {
      final note = Note.fromContent(
        content: '---\ntitle: Frontmatter Title\n---\n\n# H1 Title\n\nContent',
        path: '/notes/test.md',
        modified: DateTime.now(),
      );

      expect(note.title, 'Frontmatter Title');
    });

    test('should extract tags from frontmatter', () {
      final note = Note.fromContent(
        content: '---\ntags: [dart, flutter]\n---\n\nContent',
        path: '/notes/test.md',
        modified: DateTime.now(),
      );

      expect(note.tags, contains('dart'));
      expect(note.tags, contains('flutter'));
    });

    test('should extract inline hashtags', () {
      final note = Note.fromContent(
        content: 'Some content with #tag1 and #tag2',
        path: '/notes/test.md',
        modified: DateTime.now(),
      );

      expect(note.tags, contains('tag1'));
      expect(note.tags, contains('tag2'));
    });

    test('should extract outgoing links', () {
      final note = Note.fromContent(
        content: 'Link to [[Note A]] and [[Note B]]',
        path: '/notes/test.md',
        modified: DateTime.now(),
      );

      expect(note.outgoingLinks, contains('Note A'));
      expect(note.outgoingLinks, contains('Note B'));
    });

    test('should use filename as fallback title', () {
      final note = Note.fromContent(
        content: 'Just plain content',
        path: '/notes/my-note.md',
        modified: DateTime.now(),
      );

      expect(note.title, 'my-note.md');
    });
  });
}
