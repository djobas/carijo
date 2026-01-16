import 'package:flutter/material.dart';
import '../domain/models/note.dart';
import '../services/note_service.dart';
import '../services/error_handler.dart';
import '../services/logger_service.dart';
import 'plugin_interface.dart';

/// Concrete implementation of PluginContext that bridges plugins to app services.
class AppPluginContext implements PluginContext {
  final NoteService _noteService;
  final ErrorHandler _errorHandler;
  final List<PluginCommand> _commands = [];
  final Map<String, List<PluginMenuItem>> _menuItems = {};

  AppPluginContext({
    required NoteService noteService,
    required ErrorHandler errorHandler,
  }) : _noteService = noteService, _errorHandler = errorHandler;

  @override
  Note? get currentNote => _noteService.selectedNote;

  @override
  List<Note> get allNotes => _noteService.notes;

  @override
  void showNotification(String message, {bool isError = false}) {
    if (isError) {
      _errorHandler.reportError(userMessage: message);
    } else {
      _errorHandler.reportInfo(message);
    }
  }

  @override
  void navigateToNote(String title) {
    try {
      final note = _noteService.notes.firstWhere(
        (n) => n.title.toLowerCase() == title.toLowerCase(),
      );
      _noteService.selectNote(note);
    } catch (e) {
      showNotification('Note not found: $title', isError: true);
    }
  }

  @override
  Future<Note?> createNote(String title, String content) async {
    await _noteService.createNewNote(title: title, content: content);
    return _noteService.selectedNote;
  }

  @override
  Future<void> saveCurrentNote(String content) async {
    await _noteService.manualSaveCurrentNote(content);
  }

  @override
  void registerCommand(PluginCommand command) {
    _commands.add(command);
    LoggerService.info('Plugin registered command: ${command.id}');
  }

  @override
  void unregisterCommand(String commandId) {
    _commands.removeWhere((c) => c.id == commandId);
    LoggerService.info('Plugin unregistered command: $commandId');
  }

  @override
  void registerMenuItem(String location, PluginMenuItem item) {
    _menuItems.putIfAbsent(location, () => []).add(item);
    LoggerService.info('Plugin registered menu item: ${item.id} at $location');
  }

  @override
  void unregisterMenuItem(String itemId) {
    for (final items in _menuItems.values) {
      items.removeWhere((i) => i.id == itemId);
    }
    LoggerService.info('Plugin unregistered menu item: $itemId');
  }

  /// Gets all registered plugin commands.
  List<PluginCommand> get commands => List.unmodifiable(_commands);

  /// Gets menu items for a specific location.
  List<PluginMenuItem> getMenuItems(String location) {
    return List.unmodifiable(_menuItems[location] ?? []);
  }
}

/// Manages the lifecycle and registration of plugins.
///
/// Handles loading, unloading, enabling/disabling plugins, and provides
/// access to plugin-registered commands and menu items.
///
/// Example usage:
/// ```dart
/// final manager = PluginManager(noteService: noteService, errorHandler: errorHandler);
/// await manager.registerPlugin(WordCountPlugin());
/// await manager.initializeAll();
/// ```
class PluginManager extends ChangeNotifier {
  final List<CarijoPlugin> _plugins = [];
  final Map<String, bool> _enabledState = {};
  late final AppPluginContext _context;

  /// All registered plugins.
  List<CarijoPlugin> get plugins => List.unmodifiable(_plugins);

  /// All enabled plugins.
  List<CarijoPlugin> get enabledPlugins => 
    _plugins.where((p) => isEnabled(p.id)).toList();

  /// Creates a PluginManager with access to required services.
  PluginManager({
    required NoteService noteService,
    required ErrorHandler errorHandler,
  }) {
    _context = AppPluginContext(
      noteService: noteService,
      errorHandler: errorHandler,
    );
  }

  /// Registers a plugin without initializing it.
  void registerPlugin(CarijoPlugin plugin) {
    if (_plugins.any((p) => p.id == plugin.id)) {
      LoggerService.warning('Plugin already registered: ${plugin.id}');
      return;
    }

    _plugins.add(plugin);
    _enabledState[plugin.id] = true;
    LoggerService.info('Plugin registered: ${plugin.name} v${plugin.version}');
    notifyListeners();
  }

  /// Initializes all registered and enabled plugins.
  Future<void> initializeAll() async {
    for (final plugin in enabledPlugins) {
      try {
        await plugin.initialize(_context);
        LoggerService.info('Plugin initialized: ${plugin.name}');
      } catch (e) {
        LoggerService.error('Failed to initialize plugin: ${plugin.name}', error: e);
      }
    }
  }

  /// Initializes a specific plugin by ID.
  Future<void> initializePlugin(String pluginId) async {
    final plugin = _plugins.firstWhere(
      (p) => p.id == pluginId,
      orElse: () => throw Exception('Plugin not found: $pluginId'),
    );

    try {
      await plugin.initialize(_context);
      LoggerService.info('Plugin initialized: ${plugin.name}');
    } catch (e) {
      LoggerService.error('Failed to initialize plugin: ${plugin.name}', error: e);
      rethrow;
    }
  }

  /// Disposes a specific plugin.
  Future<void> disposePlugin(String pluginId) async {
    final plugin = _plugins.firstWhere(
      (p) => p.id == pluginId,
      orElse: () => throw Exception('Plugin not found: $pluginId'),
    );

    try {
      await plugin.dispose();
      LoggerService.info('Plugin disposed: ${plugin.name}');
    } catch (e) {
      LoggerService.error('Failed to dispose plugin: ${plugin.name}', error: e);
    }
  }

  /// Checks if a plugin is enabled.
  bool isEnabled(String pluginId) => _enabledState[pluginId] ?? false;

  /// Enables or disables a plugin.
  Future<void> setEnabled(String pluginId, bool enabled) async {
    if (!_plugins.any((p) => p.id == pluginId)) return;

    final wasEnabled = isEnabled(pluginId);
    _enabledState[pluginId] = enabled;

    if (enabled && !wasEnabled) {
      await initializePlugin(pluginId);
    } else if (!enabled && wasEnabled) {
      await disposePlugin(pluginId);
    }

    notifyListeners();
  }

  /// Unregisters and disposes a plugin.
  Future<void> unregisterPlugin(String pluginId) async {
    final plugin = _plugins.firstWhere(
      (p) => p.id == pluginId,
      orElse: () => throw Exception('Plugin not found: $pluginId'),
    );

    try {
      await plugin.dispose();
    } catch (e) {
      LoggerService.warning('Error disposing plugin during unregister', error: e);
    }

    _plugins.removeWhere((p) => p.id == pluginId);
    _enabledState.remove(pluginId);
    LoggerService.info('Plugin unregistered: ${plugin.name}');
    notifyListeners();
  }

  /// Gets all commands from enabled plugins.
  List<PluginCommand> get allCommands => _context.commands;

  /// Gets menu items for a location from enabled plugins.
  List<PluginMenuItem> getMenuItems(String location) => _context.getMenuItems(location);

  /// Notifies all enabled plugins that a note was opened.
  void notifyNoteOpened(Note note) {
    for (final plugin in enabledPlugins) {
      try {
        plugin.onNoteOpened(note);
      } catch (e) {
        LoggerService.error('Plugin error on note opened: ${plugin.id}', error: e);
      }
    }
  }

  /// Notifies all enabled plugins that a note was saved.
  void notifyNoteSaved(Note note, String content) {
    for (final plugin in enabledPlugins) {
      try {
        plugin.onNoteSaved(note, content);
      } catch (e) {
        LoggerService.error('Plugin error on note saved: ${plugin.id}', error: e);
      }
    }
  }

  /// Notifies all enabled plugins that a note was created.
  void notifyNoteCreated(Note note) {
    for (final plugin in enabledPlugins) {
      try {
        plugin.onNoteCreated(note);
      } catch (e) {
        LoggerService.error('Plugin error on note created: ${plugin.id}', error: e);
      }
    }
  }

  /// Notifies all enabled plugins that a note was deleted.
  void notifyNoteDeleted(Note note) {
    for (final plugin in enabledPlugins) {
      try {
        plugin.onNoteDeleted(note);
      } catch (e) {
        LoggerService.error('Plugin error on note deleted: ${plugin.id}', error: e);
      }
    }
  }

  /// Processes content through all enabled plugins.
  String processContent(String content) {
    String processed = content;
    for (final plugin in enabledPlugins) {
      try {
        processed = plugin.processContent(processed);
      } catch (e) {
        LoggerService.error('Plugin error processing content: ${plugin.id}', error: e);
      }
    }
    return processed;
  }

  /// Preprocesses content through all enabled plugins before saving.
  String preprocessContent(String content) {
    String processed = content;
    for (final plugin in enabledPlugins) {
      try {
        processed = plugin.preprocessContent(processed);
      } catch (e) {
        LoggerService.error('Plugin error preprocessing content: ${plugin.id}', error: e);
      }
    }
    return processed;
  }

  /// Disposes all plugins and cleans up.
  @override
  void dispose() {
    for (final plugin in _plugins) {
      try {
        plugin.dispose();
      } catch (e) {
        LoggerService.warning('Error disposing plugin: ${plugin.id}', error: e);
      }
    }
    super.dispose();
  }
}
