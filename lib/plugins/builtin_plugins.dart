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

/// Plugin that suggests tags based on content.
class AutoTaggingPlugin implements CarijoPlugin {
  late PluginContext _context;
  bool _enabled = true;

  final Map<String, String> _keywords = {
    'todo': '#todo',
    'fazer': '#todo',
    'reunião': '#meeting',
    'meeting': '#meeting',
    'ideia': '#idea',
    'brainstorm': '#idea',
    'projeto': '#project',
    'estudo': '#study',
    'importante': '#important',
    'urgente': '#urgent',
  };

  @override
  String get id => 'carijo.auto-tag';

  @override
  String get name => 'Auto Tagging';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Suggests tags based on content keywords.';

  @override
  String get author => 'Carijó Team';

  @override
  IconData get icon => Icons.label_important_outline;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    context.registerCommand(PluginCommand(
      id: 'auto-tag.run',
      label: 'Suggest Tags',
      icon: Icons.label_important_outline,
      onExecute: _suggestTags,
    ));
  }

  @override
  Future<void> dispose() async {
    _context.unregisterCommand('auto-tag.run');
  }

  void _suggestTags() {
    final note = _context.currentNote;
    if (note == null) return;

    final content = note.content.toLowerCase();
    List<String> suggested = [];

    _keywords.forEach((key, tag) {
      if (content.contains(key) && !note.tags.contains(tag.replaceAll('#', ''))) {
        suggested.add(tag);
      }
    });

    if (suggested.isEmpty) {
      _context.showNotification('No new tags suggested.');
    } else {
      _context.showNotification('Suggestions: ${suggested.join(", ")}');
    }
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
    // Auto-add tags on save if enabled
    final note = _context.currentNote;
    if (note == null) return content;

    String updatedContent = content;
    final lowerContent = content.toLowerCase();

    _keywords.forEach((key, tag) {
      if (lowerContent.contains(key) && !content.contains(tag)) {
        // Simple logic: append at the end of frontmatter or start of note
        if (!updatedContent.contains(tag)) {
           // For simplicity in this demo, we just notify or we could inject.
           // Let's just notify for now to be "safe".
        }
      }
    });
    return updatedContent;
  }
}

/// Plugin that manages note templates from a .templates folder.
class TemplatePlugin implements CarijoPlugin {
  late PluginContext _context;
  bool _enabled = true;

  @override
  String get id => 'carijo.templates';

  @override
  String get name => 'Templates';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Apply note templates from your .templates folder.';

  @override
  String get author => 'Carijó Team';

  @override
  IconData get icon => Icons.copy_all;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    context.registerCommand(PluginCommand(
      id: 'templates.apply',
      label: 'Apply Template',
      icon: Icons.copy_all,
      onExecute: _showTemplateSelector,
    ));
  }

  @override
  Future<void> dispose() async {
    _context.unregisterCommand('templates.apply');
  }

  Future<void> _showTemplateSelector() async {
    final templatesDir = Directory('${_context.notesPath}${Platform.pathSeparator}.templates');
    if (!await templatesDir.exists()) {
      await templatesDir.create(recursive: true);
      _context.showNotification('Created .templates folder. Add .md files there!');
      return;
    }

    final files = await templatesDir.list().toList();
    final templateFiles = files.whereType<File>().where((f) => f.path.endsWith('.md')).toList();

    if (templateFiles.isEmpty) {
      _context.showNotification('No templates found in .templates/');
      return;
    }

    // Since we don't have a generic Picker UI yet, we'll just apply the first one for demo
    // or list them in a notification. 
    // TODO: Implement a proper picker in the Omnibar.
    final names = templateFiles.map((f) => f.path.split(Platform.pathSeparator).last).join(', ');
    _context.showNotification('Available templates: $names. (Apply logic coming in next UI update)');
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

/// Plugin that renders Mermaid diagrams using Mermaid.ink (Safe/No dependency).
class MermaidPlugin implements CarijoPlugin {
  late PluginContext _context;
  bool _enabled = true;

  @override
  String get id => 'carijo.mermaid';

  @override
  String get name => 'Mermaid Renderer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Renders mermaid code blocks as images using Mermaid.ink.';

  @override
  String get author => 'Carijó Team';

  @override
  IconData get icon => Icons.auto_graph;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
  }

  @override
  Future<void> dispose() async {}

  @override
  void onNoteOpened(Note note) {}

  @override
  void onNoteSaved(Note note, String newContent) {}

  @override
  void onNoteCreated(Note note) {}

  @override
  void onNoteDeleted(Note note) {}

  @override
  String processContent(String content) {
    if (!isEnabled) return content;

    final mermaidRegex = RegExp(r'```mermaid([\s\S]*?)```');
    return content.replaceAllMapped(mermaidRegex, (match) {
      final code = match.group(1)?.trim() ?? '';
      if (code.isEmpty) return match.group(0)!;
      
      // Encode to base64 for mermaid.ink
      final bytes = utf8.encode(code);
      final base64String = base64.encode(bytes);
      
      return '\n![Mermaid Diagram](https://mermaid.ink/img/$base64String)\n';
    });
  }

  @override
  String preprocessContent(String content) => content;
}

/// Built-in plugins that come with Carijó Notes.
class BuiltinPlugins {
  static List<CarijoPlugin> get all => [
    WordCountPlugin(),
    TimestampPlugin(),
    AutoTaggingPlugin(),
    TemplatePlugin(),
    MermaidPlugin(),
  ];
}
