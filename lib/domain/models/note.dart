import 'package:yaml/yaml.dart';
import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Id get id => fastHash(path);

  @Index(type: IndexType.value, caseSensitive: false)
  final String title;

  @Index(type: IndexType.value, caseSensitive: false)
  final String content;
  
  @Index(unique: true, replace: true)
  final String path;
  
  final DateTime modified;
  
  @ignore
  final Map<String, dynamic> metadata;
  
  final List<String> tags;
  final List<String> outgoingLinks;
  final bool isPublished;
  final String? category;
  final String? slug;

  Note({
    required this.title,
    required this.content,
    required this.path,
    required this.modified,
    this.metadata = const {},
    this.tags = const [],
    this.outgoingLinks = const [],
    this.isPublished = false,
    this.category,
    this.slug,
  });

  Note copyWith({
    String? title,
    String? content,
    String? path,
    DateTime? modified,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    List<String>? outgoingLinks,
    bool? isPublished,
    String? category,
    String? slug,
  }) {
    return Note(
      title: title ?? this.title,
      content: content ?? this.content,
      path: path ?? this.path,
      modified: modified ?? this.modified,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      outgoingLinks: outgoingLinks ?? this.outgoingLinks,
      isPublished: isPublished ?? this.isPublished,
      category: category ?? this.category,
      slug: slug ?? this.slug,
    );
  }

  static Note fromContent({
    required String content,
    required String path,
    required DateTime modified,
    String? filename,
    String? defaultTitle,
  }) {
    String effectiveFilename = filename ?? path.split(RegExp(r'[/\\]')).last;
    String title = defaultTitle ?? effectiveFilename;
    Map<String, dynamic> metadata = {};
    Set<String> tags = {};

    // 1. Try Frontmatter
    final RegExp frontmatterRegex = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n');
    final match = frontmatterRegex.firstMatch(content);

    if (match != null) {
      try {
        final yamlStr = match.group(1);
        if (yamlStr != null) {
          final yaml = loadYaml(yamlStr);
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
        }
      } catch (e) {
        // Silently skip parsing errors
      }
    }

    // 2. Try H1 for Title (if no Title in Frontmatter)
    if (title == effectiveFilename || title == defaultTitle) {
      final RegExp h1Regex = RegExp(r'^#\s+(.*)$', multiLine: true);
      final h1Match = h1Regex.firstMatch(content);
      if (h1Match != null) {
        title = (h1Match.group(1) ?? "").trim();
      }
    }

    // 3. Extract #tags from content
    final RegExp tagRegex = RegExp(r'#(\w+)');
    final tagMatches = tagRegex.allMatches(content);
    for (var m in tagMatches) {
      tags.add(m.group(1) ?? "");
    }

    // 4. Extract outgoing links [[Title]]
    final RegExp linkRegex = RegExp(r'\[\[(.*?)\]\]');
    final linkMatches = linkRegex.allMatches(content);
    final List<String> outgoingLinks =
        linkMatches.map((m) => (m.group(1) ?? "").trim()).toSet().toList();

    return Note(
      title: title,
      content: content,
      path: path,
      modified: modified,
      metadata: metadata,
      tags: tags.toList(),
      outgoingLinks: outgoingLinks,
      isPublished: metadata['published'] == true,
      category: metadata['category']?.toString(),
      slug: metadata['slug']?.toString(),
    );
  }
}

class NoteFolder {
  final String name;
  final String path;
  final List<NoteFolder> subfolders;
  final List<Note> notes;
  bool isExpanded;

  NoteFolder({
    required this.name,
    required this.path,
    required this.subfolders,
    required this.notes,
    this.isExpanded = false,
  });
}

class BacklinkMatch {
  final Note note;
  final String snippet;

  BacklinkMatch({required this.note, required this.snippet});
}

/// FNV-1a 64bit hash algorithm.
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}
