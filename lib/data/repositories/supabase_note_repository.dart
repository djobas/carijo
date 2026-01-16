import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/note.dart';
import '../../domain/repositories/remote_note_repository.dart';

class SupabaseNoteRepository implements RemoteNoteRepository {
  @override
  Future<void> publishNote(Note note) async {
    final client = Supabase.instance.client;
    
    await client.from('notes').upsert({
      'title': note.title,
      'content': note.content,
      'path': note.path, // This should be the relative path
      'modified_at': note.modified.toIso8601String(),
      'tags': note.tags,
      'metadata': note.metadata,
      'is_published': note.isPublished,
      'category': note.category,
      'slug': note.slug,
    }, onConflict: 'path');
  }

  @override
  Future<void> syncAll(List<Note> notes) async {
    final client = Supabase.instance.client;
    
    final List<Map<String, dynamic>> data = notes.map((note) => {
      'title': note.title,
      'content': note.content,
      'path': note.path, // This should be relative
      'modified_at': note.modified.toIso8601String(),
      'tags': note.tags,
      'metadata': note.metadata,
      'is_published': note.isPublished,
      'category': note.category,
      'slug': note.slug,
    }).toList();

    await client.from('notes').upsert(data, onConflict: 'path');
  }

  @override
  Future<List<Note>> fetchAllNotes() async {
    final client = Supabase.instance.client;
    final response = await client.from('notes').select();
    
    return (response as List).map((data) => Note(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      path: data['path'] ?? '', // This will be relative path from DB
      modified: DateTime.parse(data['modified_at'] ?? DateTime.now().toIso8601String()),
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      isPublished: data['is_published'] ?? false,
      category: data['category'],
      slug: data['slug'],
    )).toList();
  }
}
