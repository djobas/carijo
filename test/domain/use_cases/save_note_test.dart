import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carijo_notes/domain/models/note.dart';
import 'package:carijo_notes/domain/repositories/note_repository.dart';
import 'package:carijo_notes/domain/use_cases/save_note_use_case.dart';

class MockNoteRepository implements NoteRepository {
  String? lastSavedPath;
  String? lastSavedContent;

  @override
  Future<void> saveNote(String path, String content) async {
    lastSavedPath = path;
    lastSavedContent = content;
  }

  @override
  Future<List<Note>> getAllNotes(String rootPath) async => [];

  @override
  Future<void> deleteNote(String path) async {}

  @override
  Future<List<Note>> getTemplates(String path) async => [];

  @override
  Future<List<Note>> searchNotes(String query) async => [];

  @override
  Future<String?> uploadImage(String rootPath, File imageFile) async => null;
}

void main() {
  late SaveNoteUseCase saveNoteUseCase;
  late MockNoteRepository mockRepository;

  setUp(() {
    mockRepository = MockNoteRepository();
    saveNoteUseCase = SaveNoteUseCase(mockRepository);
  });

  group('SaveNoteUseCase', () {
    test('should save note to repository and return updated note object', () async {
      final note = Note(
        title: 'Original Title',
        content: '# Old Content',
        path: 'note.md',
        modified: DateTime.now().subtract(const Duration(days: 1)),
      );

      const newContent = '# Updated Title\n\nNew body here.';
      
      final updatedNote = await saveNoteUseCase(note: note, newContent: newContent);

      // Verify repository was called
      expect(mockRepository.lastSavedPath, 'note.md');
      expect(mockRepository.lastSavedContent, newContent);

      // Verify returned object is updated and re-parsed
      expect(updatedNote.title, 'Updated Title');
      expect(updatedNote.content, newContent);
      expect(updatedNote.path, 'note.md');
      // Modified time should be updated (close to now)
      expect(updatedNote.modified.isAfter(note.modified), true);
    });

    test('should handle notes without H1 by using the original title', () async {
      final note = Note(
        title: 'Fixed Title',
        content: 'No H1 here',
        path: 'note.md',
        modified: DateTime.now(),
      );

      const newContent = 'Still no H1, just text.';
      
      final updatedNote = await saveNoteUseCase(note: note, newContent: newContent);

      expect(updatedNote.title, 'Fixed Title');
      expect(updatedNote.content, newContent);
    });
  });
}
