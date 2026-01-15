import '../models/note.dart';

abstract class RemoteNoteRepository {
  Future<void> publishNote(Note note);
  Future<void> syncAll(List<Note> notes);
  // Add more cloud-specific methods as needed, e.g., fetchRemoteNotes()
}
