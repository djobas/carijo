class Note {
  final String title;
  final String content;
  final String path;
  final DateTime modified;
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
