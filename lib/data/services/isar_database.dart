import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models/note.dart';

class IsarDatabase {
  late Isar _isar;

  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [NoteSchema],
      directory: dir.path,
      name: 'carijo_index',
    );
  }

  Future<void> saveNote(Note note) async {
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  Future<void> saveAll(List<Note> notes) async {
    await _isar.writeTxn(() async {
      await _isar.notes.putAll(notes);
    });
  }

  Future<List<Note>> getAllNotes() async {
    return await _isar.notes.where().findAll();
  }

  Future<Note?> getNoteByPath(String path) async {
    return await _isar.notes.filter().pathEqualTo(path).findFirst();
  }

  Future<void> deleteNote(String path) async {
    await _isar.writeTxn(() async {
      await _isar.notes.filter().pathEqualTo(path).deleteAll();
    });
  }

  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.notes.clear();
    });
  }
}
