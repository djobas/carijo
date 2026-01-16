import 'package:flutter/material.dart';
import '../domain/models/note.dart';

/// Lifecycle hooks for plugin initialization and cleanup.
enum PluginLifecycle {
  /// Called when the plugin is first loaded
  onLoad,

  /// Called when the plugin is being unloaded
  onUnload,

  /// Called when the app is being closed
  onAppClose,
}

/// Represents a menu item that a plugin can add to the UI.
class PluginMenuItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const PluginMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });
}

/// Represents a command that a plugin can add to the command palette.
class PluginCommand {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onExecute;
  final String? shortcut;

  const PluginCommand({
    required this.id,
    required this.label,
    required this.icon,
    required this.onExecute,
    this.shortcut,
  });
}

/// Context passed to plugins with access to app services.
abstract class PluginContext {
  /// The currently selected note, if any.
  Note? get currentNote;

  /// The base path where notes are stored.
  String get notesPath;

  /// All available notes.
  List<Note> get allNotes;

  /// Shows a notification to the user.
  void showNotification(String message, {bool isError = false});

  /// Navigates to a note by title.
  void navigateToNote(String title);

  /// Creates a new note with the given title and content.
  Future<Note?> createNote(String title, String content);

  /// Saves the current note with new content.
  Future<void> saveCurrentNote(String content);

  /// Registers a command to the command palette.
  void registerCommand(PluginCommand command);

  /// Unregisters a command from the command palette.
  void unregisterCommand(String commandId);

  /// Registers a menu item to a specific location.
  void registerMenuItem(String location, PluginMenuItem item);

  /// Unregisters a menu item.
  void unregisterMenuItem(String itemId);
}

/// Base interface that all plugins must implement.
///
/// Plugins extend the functionality of Carijó Notes by providing
/// additional commands, menu items, and note processing capabilities.
///
/// Example plugin implementation:
/// ```dart
/// class WordCountPlugin implements CarijoPlugin {
///   @override
///   String get id => 'word-count';
///
///   @override
///   String get name => 'Word Count';
///
///   @override
///   String get version => '1.0.0';
///
///   @override
///   Future<void> initialize(PluginContext context) async {
///     context.registerCommand(PluginCommand(
///       id: 'word-count',
///       label: 'Count Words',
///       icon: Icons.format_list_numbered,
///       onExecute: () => _showWordCount(context),
///     ));
///   }
/// }
/// ```
abstract class CarijoPlugin {
  /// Unique identifier for this plugin.
  String get id;

  /// Human-readable name of the plugin.
  String get name;

  /// Plugin version string (semver recommended).
  String get version;

  /// Optional description of what the plugin does.
  String get description => '';

  /// Optional author/maintainer information.
  String get author => '';

  /// Optional icon for the plugin.
  IconData get icon => Icons.extension;

  /// Whether the plugin is currently enabled.
  bool get isEnabled;

  /// Initializes the plugin with access to the app context.
  ///
  /// Called when the plugin is loaded. Register commands, menu items,
  /// and event listeners here.
  Future<void> initialize(PluginContext context);

  /// Cleans up plugin resources.
  ///
  /// Called when the plugin is being unloaded. Unregister any commands
  /// and menu items, and release resources.
  Future<void> dispose();

  /// Called when a note is opened in the editor.
  ///
  /// Override to provide custom behavior when notes are viewed.
  void onNoteOpened(Note note) {}

  /// Called when a note is saved.
  ///
  /// Override to provide custom behavior on save, such as
  /// auto-formatting or backups.
  void onNoteSaved(Note note, String newContent) {}

  /// Called when a note is created.
  void onNoteCreated(Note note) {}

  /// Called when a note is deleted.
  void onNoteDeleted(Note note) {}

  /// Processes note content before rendering.
  ///
  /// Can be used for custom markdown extensions or content transformations.
  /// Return the original content if no processing is needed.
  String processContent(String content) => content;

  /// Processes note content before saving.
  ///
  /// Can be used for auto-formatting or content normalization.
  /// Return the original content if no processing is needed.
  String preprocessContent(String content) => content;
}
