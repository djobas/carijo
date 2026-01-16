import 'dart:io';
import '../models/note.dart';
import '../repositories/remote_note_repository.dart';
import '../repositories/note_repository.dart';
import 'package:path/path.dart' as p;

class SyncNotesUseCase {
  final RemoteNoteRepository remoteRepository;
  final NoteRepository localRepository;

  SyncNotesUseCase(this.remoteRepository, this.localRepository);

  Future<void> call(List<Note> localNotes, String basePath) async {
    // 1. Fetch all remote notes
    final remoteNotes = await remoteRepository.fetchAllNotes();
    
    // 2. Map remote notes by relative path for easy lookup
    final Map<String, Note> remoteMap = {for (var n in remoteNotes) n.path: n};
    
    // 3. Map local notes by relative path
    final Map<String, Note> localMap = {};
    for (var note in localNotes) {
      final relative = p.relative(note.path, from: basePath);
      localMap[relative] = note;
    }

    // 4. Determine what to push and what to pull
    final List<Note> toPush = [];
    
    // Check local notes against remote
    for (var entry in localMap.entries) {
      final relativePath = entry.key;
      final localNote = entry.value;
      final remoteNote = remoteMap[relativePath];

      if (remoteNote == null) {
        // New local note, push it (but convert to relative path for remote)
        toPush.add(localNote.copyWith(path: relativePath));
      } else {
        // Compare modification dates
        if (localNote.modified.isAfter(remoteNote.modified.add(const Duration(seconds: 1)))) {
           // Local is newer, push it
           toPush.add(localNote.copyWith(path: relativePath));
        } else if (remoteNote.modified.isAfter(localNote.modified.add(const Duration(seconds: 1)))) {
           // Remote is newer, pull it (Save locally later)
           final absolutePath = p.join(basePath, relativePath);
           await localRepository.saveNote(absolutePath, remoteNote.content);
        }
      }
    }

    // Check for remote notes that don't exist locally
    for (var entry in remoteMap.entries) {
      final relativePath = entry.key;
      final remoteNote = entry.value;

      if (!localMap.containsKey(relativePath)) {
        // New remote note, pull it
        final absolutePath = p.join(basePath, relativePath);
        
        // Ensure directory exists
        final dir = Directory(p.dirname(absolutePath));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        await localRepository.saveNote(absolutePath, remoteNote.content);
      }
    }

    // 5. Execute push
    if (toPush.isNotEmpty) {
      await remoteRepository.syncAll(toPush);
    }
  }

  Future<void> publishSingle(Note note) async {
    // Note: This expects the note to have a relative path if used for cloud
    await remoteRepository.publishNote(note);
  }
}
