import '../models/note.dart';

class SearchNotesUseCase {
  List<Note> call({
    required List<Note> notes,
    required String query,
    String? filterTag,
  }) {
    if (query.isEmpty && filterTag == null) {
      return notes;
    }

    return notes.where((note) {
      final matchesQuery = query.isEmpty ||
          note.title.toLowerCase().contains(query.toLowerCase()) ||
          note.content.toLowerCase().contains(query.toLowerCase());
      
      final matchesTag = filterTag == null || note.tags.contains(filterTag);
      
      return matchesQuery && matchesTag;
    }).toList();
  }
}
