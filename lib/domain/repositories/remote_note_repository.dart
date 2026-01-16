import '../models/note.dart';

abstract class RemoteNoteRepository {
  Future<void> publishNote(Note note);
  Future<void> syncAll(List<Note> notes);
  Future<List<Note>> fetchAllNotes();
}
