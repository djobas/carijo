import 'dart:io';
import '../../domain/models/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../services/isar_database.dart';

class IndexedNoteRepository implements NoteRepository {
  final NoteRepository _fileRepository;
  final IsarDatabase _isarDatabase;

  IndexedNoteRepository(this._fileRepository, this._isarDatabase);

  @override
  Future<List<Note>> getAllNotes(String rootPath) async {
    // 1. Try to get from Isar first (High Performance)
    final cachedNotes = await _isarDatabase.getAllNotes();
    
    if (cachedNotes.isNotEmpty) {
      // In a real scenario, we should verify if the cache is stale
      // For now, return cached and trigger a background sync if needed
      return cachedNotes;
    }

    // 2. Fallback to File System
    final notes = await _fileRepository.getAllNotes(rootPath);
    
    // 3. Index in background
    await _isarDatabase.saveAll(notes);
    
    return notes;
  }

  @override
  Future<void> saveNote(String path, String content) async {
    // 1. Save to File System (Source of Truth)
    await _fileRepository.saveNote(path, content);
    
    // 2. Re-parse and Update Index
    final updatedNote = Note.fromContent(
      content: content, 
      path: path, 
      modified: DateTime.now()
    );
    await _isarDatabase.saveNote(updatedNote);
  }

  @override
  Future<void> deleteNote(String path) async {
    await _fileRepository.deleteNote(path);
    await _isarDatabase.deleteNote(path);
  }

  @override
  Future<List<Note>> getTemplates(String rootPath) async {
    return await _fileRepository.getTemplates(rootPath);
  }

  @override
  Future<String?> uploadImage(String rootPath, File imageFile) async {
    return await _fileRepository.uploadImage(rootPath, imageFile);
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    return await _isarDatabase.searchNotes(query);
  }
}
