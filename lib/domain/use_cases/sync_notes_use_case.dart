import '../models/note.dart';
import '../repositories/remote_note_repository.dart';

class SyncNotesUseCase {
  final RemoteNoteRepository remoteRepository;

  SyncNotesUseCase(this.remoteRepository);

  Future<void> call(List<Note> notes) async {
    // 1. Filter only published notes (or all, depending on logic)
    // For now, let's sync all as per previous SupabaseService implementation
    
    if (notes.isEmpty) return;
    
    await remoteRepository.syncAll(notes);
  }

  Future<void> publishSingle(Note note) async {
    await remoteRepository.publishNote(note);
  }
}
