import 'dart:io';
import '../models/note.dart';

abstract class NoteRepository {
  Future<List<Note>> getAllNotes(String path);
  Future<void> saveNote(String path, String content);
  Future<void> deleteNote(String path);
  Future<String?> uploadImage(String notesPath, File imageFile);
  Future<List<Note>> getTemplates(String notesPath);
  Future<List<Note>> searchNotes(String query);
}
