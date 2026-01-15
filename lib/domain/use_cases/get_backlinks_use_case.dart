import '../models/note.dart';

class GetBacklinksUseCase {
  List<BacklinkMatch> call({
    required Note targetNote,
    required List<Note> allNotes,
  }) {
    final List<BacklinkMatch> matches = [];
    for (final note in allNotes) {
      if (note.path == targetNote.path) continue;

      final content = note.content;
      final lowerContent = content.toLowerCase();
      
      // Look for [[Title]]
      final linkPattern = '[[${targetNote.title}]]'.toLowerCase();
      
      if (lowerContent.contains(linkPattern)) {
        // Extract snippet
        final index = lowerContent.indexOf(linkPattern);
        final start = (index - 40 < 0) ? 0 : index - 40;
        final end = (index + linkPattern.length + 40 > content.length) 
            ? content.length 
            : index + linkPattern.length + 40;
        
        String snippet = content.substring(start, end).replaceAll('\n', ' ');
        if (start > 0) snippet = '...$snippet';
        if (end < content.length) snippet = '$snippet...';

        matches.add(BacklinkMatch(note: note, snippet: snippet));
      }
    }

    return matches;
  }
}
