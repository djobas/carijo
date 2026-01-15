import '../models/note.dart';
import '../repositories/note_repository.dart';

class SaveNoteUseCase {
  final NoteRepository repository;

  SaveNoteUseCase(this.repository);

  Future<Note> call({
    required Note note,
    required String newContent,
  }) async {
    // 1. Persist via repository
    await repository.saveNote(note.path, newContent);

    // 2. Re-parse content to get updated metadata, tags, links
    return Note.fromContent(
      content: newContent,
      path: note.path,
      modified: DateTime.now(),
      defaultTitle: note.title,
    );
  }
}
