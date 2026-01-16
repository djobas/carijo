import '../domain/models/note.dart';

/// Interface for objects that want to listen to note-related events.
abstract class NoteObserver {
  /// Called when a note is opened in the editor.
  void onNoteOpened(Note note);

  /// Called when a note is saved.
  void onNoteSaved(Note note, String content);

  /// Called when a note is created.
  void onNoteCreated(Note note);

  /// Called when a note is deleted.
  void onNoteDeleted(Note note);

  /// Processes content before saving.
  String preprocessContent(String content);

  /// Processes content before rendering.
  String processContent(String content);
}
