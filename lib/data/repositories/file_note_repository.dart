import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/models/note.dart';
import '../../domain/repositories/note_repository.dart';

class FileNoteRepository implements NoteRepository {
  @override
  Future<List<Note>> getAllNotes(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final List<FileSystemEntity> entities = dir.listSync(recursive: true);
    final List<Note> loadedNotes = [];

    for (var entity in entities) {
      if (entity.path.contains('${Platform.pathSeparator}.') ||
          entity.path.contains('${Platform.pathSeparator}assets${Platform.pathSeparator}')) {
        continue;
      }

      if (entity is File && entity.path.endsWith('.md')) {
        final content = await entity.readAsString();
        final stat = await entity.stat();

        loadedNotes.add(Note.fromContent(
          content: content,
          path: entity.path,
          modified: stat.modified,
        ));
      }
    }
    return loadedNotes;
  }

  @override
  Future<void> saveNote(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  @override
  Future<void> deleteNote(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String?> uploadImage(String notesPath, File imageFile) async {
    try {
      final assetsDir = Directory('$notesPath${Platform.pathSeparator}assets');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      final fileName = p.basename(imageFile.path);
      final targetPath = p.join(assetsDir.path, fileName);
      await imageFile.copy(targetPath);
      return '![](assets/$fileName)';
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Note>> getTemplates(String notesPath) async {
    final templateDir = Directory('$notesPath${Platform.pathSeparator}.templates');
    if (!await templateDir.exists()) return [];

    final List<Note> loadedTemplates = [];
    final entities = templateDir.listSync();

    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.md')) {
        final content = await entity.readAsString();
        final stat = await entity.stat();

        loadedTemplates.add(Note.fromContent(
          content: content,
          path: entity.path,
          modified: stat.modified,
        ));
      }
    }
    return loadedTemplates;
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    // In FileNoteRepository, we don't maintain a cache, 
    // so global search is not efficient here.
    return [];
  }
}
