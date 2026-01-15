import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
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
        final noteData = _parseNoteContent(content, entity.uri.pathSegments.last);

        loadedNotes.add(Note(
          title: noteData['title'],
          content: content,
          path: entity.path,
          modified: stat.modified,
          metadata: noteData['metadata'],
          tags: noteData['tags'],
          outgoingLinks: noteData['outgoingLinks'],
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
        final filename = p.basename(entity.path);
        final noteData = _parseNoteContent(content, filename);

        loadedTemplates.add(Note(
          title: noteData['title'],
          content: content,
          path: entity.path,
          modified: (await entity.stat()).modified,
          metadata: noteData['metadata'],
          tags: noteData['tags'],
          outgoingLinks: noteData['outgoingLinks'],
          isPublished: noteData['isPublished'] ?? false,
          category: noteData['category'],
          slug: noteData['slug'],
        ));
      }
    }
    return loadedTemplates;
  }

  Map<String, dynamic> _parseNoteContent(String content, String filename) {
    String title = filename;
    Map<String, dynamic> metadata = {};
    Set<String> tags = {};

    final RegExp frontmatterRegex = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n');
    final match = frontmatterRegex.firstMatch(content);

    if (match != null) {
      try {
        final yamlStr = match.group(1);
        final yaml = loadYaml(yamlStr!);
        if (yaml is Map) {
          metadata = Map<String, dynamic>.from(yaml);
          if (metadata.containsKey('title')) {
            title = metadata['title'].toString();
          }
          if (metadata.containsKey('tags')) {
            final dynamic yamlTags = metadata['tags'];
            if (yamlTags is List) {
              tags.addAll(yamlTags.map((t) => t.toString()));
            } else if (yamlTags is String) {
              tags.add(yamlTags);
            }
          }
        }
      } catch (e) {}
    }

    if (title == filename) {
      final RegExp h1Regex = RegExp(r'^#\s+(.*)$', multiLine: true);
      final h1Match = h1Regex.firstMatch(content);
      if (h1Match != null) {
        title = h1Match.group(1)!.trim();
      }
    }

    final RegExp tagRegex = RegExp(r'#(\w+)');
    final tagMatches = tagRegex.allMatches(content);
    for (var m in tagMatches) {
      tags.add(m.group(1)!);
    }

    final RegExp linkRegex = RegExp(r'\[\[(.*?)\]\]');
    final linkMatches = linkRegex.allMatches(content);
    final List<String> outgoingLinks = linkMatches.map((m) => m.group(1)!.trim()).toList();

    return {
      'title': title,
      'metadata': metadata,
      'tags': tags.toList(),
      'outgoingLinks': outgoingLinks.toSet().toList(),
      'isPublished': metadata['published'] == true,
      'category': metadata['category']?.toString(),
      'slug': metadata['slug']?.toString(),
    };
  }
}
