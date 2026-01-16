import 'package:flutter/material.dart';
import '../domain/models/note.dart';
import 'plugin_interface.dart';

/// Example plugin that counts words in the current note.
///
/// Demonstrates basic plugin structure with command palette integration.
class WordCountPlugin implements CarijoPlugin {
  late PluginContext _context;
  bool _enabled = true;

  @override
  String get id => 'carijo.word-count';

  @override
  String get name => 'Word Count';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Shows word and character count for the current note.';

  @override
  String get author => 'Carijó Team';

  @override
  IconData get icon => Icons.format_list_numbered;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    
    context.registerCommand(PluginCommand(
      id: 'word-count.show',
      label: 'Show Word Count',
      icon: Icons.format_list_numbered,
      onExecute: _showWordCount,
    ));
  }

  @override
  Future<void> dispose() async {
    _context.unregisterCommand('word-count.show');
  }

  void _showWordCount() {
    final note = _context.currentNote;
    if (note == null) {
      _context.showNotification('No note selected');
      return;
    }

    final content = note.content;
    final words = content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final chars = content.length;
    final lines = content.split('\n').length;
    final readTime = (words / 200).ceil(); // avg 200 wpm

    _context.showNotification(
      '📊 $words words · $chars chars · $lines lines · ~$readTime min read'
    );
  }

  @override
  void onNoteOpened(Note note) {}

  @override
  void onNoteSaved(Note note, String newContent) {}

  @override
  void onNoteCreated(Note note) {}

  @override
  void onNoteDeleted(Note note) {}

  @override
  String processContent(String content) => content;

  @override
  String preprocessContent(String content) => content;
}


/// Example plugin that adds a timestamp to notes on save.
class TimestampPlugin implements CarijoPlugin {
  late PluginContext _context;
  bool _enabled = true;

  @override
  String get id => 'carijo.timestamp';

  @override
  String get name => 'Auto Timestamp';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Automatically adds last modified timestamp to frontmatter.';

  @override
  String get author => 'Carijó Team';

  @override
  IconData get icon => Icons.access_time;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    
    context.registerCommand(PluginCommand(
      id: 'timestamp.insert',
      label: 'Insert Timestamp',
      icon: Icons.access_time,
      onExecute: () {
        final note = _context.currentNote;
        if (note == null) return;
        
        final now = DateTime.now();
        final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        _context.showNotification('Timestamp: $timestamp');
      },
    ));
  }

  @override
  Future<void> dispose() async {
    _context.unregisterCommand('timestamp.insert');
  }

  @override
  void onNoteOpened(Note note) {}

  @override
  void onNoteSaved(Note note, String newContent) {}

  @override
  void onNoteCreated(Note note) {}

  @override
  void onNoteDeleted(Note note) {}

  @override
  String processContent(String content) => content;

  @override
  String preprocessContent(String content) {
    // Update modified timestamp in frontmatter on save
    final now = DateTime.now();
    final timestamp = now.toIso8601String();
    
    final frontmatterRegex = RegExp(r'^---\s*\n([\s\S]*?)\n---');
    final match = frontmatterRegex.firstMatch(content);
    
    if (match != null) {
      String yaml = match.group(1) ?? '';
      if (yaml.contains(RegExp(r'^modified:', multiLine: true))) {
        yaml = yaml.replaceFirst(
          RegExp(r'^modified:.*', multiLine: true),
          'modified: $timestamp',
        );
      } else {
        yaml = 'modified: $timestamp\n$yaml';
      }
      return content.replaceRange(match.start, match.end, '---\n$yaml\n---');
    }
    
    return content;
  }
}


/// Built-in plugins that come with Carijó Notes.
class BuiltinPlugins {
  static List<CarijoPlugin> get all => [
    WordCountPlugin(),
    TimestampPlugin(),
  ];
}
