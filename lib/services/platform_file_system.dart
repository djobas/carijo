import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Platform-agnostic file system abstraction.
///
/// Provides unified access to the file system across different platforms
/// (Windows, Android, iOS, etc.), handling platform-specific paths and
/// permission requirements.
///
/// Example usage:
/// ```dart
/// final fs = PlatformFileSystem();
/// final notesDir = await fs.getNotesDirectory();
/// final files = await fs.listMarkdownFiles(notesDir);
/// ```
class PlatformFileSystem {
  static final PlatformFileSystem _instance = PlatformFileSystem._internal();
  factory PlatformFileSystem() => _instance;
  PlatformFileSystem._internal();

  /// Whether running on a mobile platform (Android or iOS).
  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Whether running on a desktop platform (Windows, macOS, Linux).
  bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Gets the default directory for storing notes.
  ///
  /// On desktop: Uses Documents folder or user-selected path.
  /// On mobile: Uses app's documents directory (sandboxed).
  Future<String> getDefaultNotesDirectory() async {
    if (isMobile) {
      final appDir = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${appDir.path}/notes');
      if (!await notesDir.exists()) {
        await notesDir.create(recursive: true);
      }
      return notesDir.path;
    } else {
      // Desktop: return null to indicate user should choose
      // Or use a default like Documents/CarijoNotes
      final docs = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${docs.path}/CarijoNotes');
      if (!await notesDir.exists()) {
        await notesDir.create(recursive: true);
      }
      return notesDir.path;
    }
  }

  /// Gets the directory for storing app data (logs, cache, etc.).
  Future<String> getAppDataDirectory() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  /// Gets the directory for temporary files.
  Future<String> getTempDirectory() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// Lists all markdown files in a directory recursively.
  Future<List<File>> listMarkdownFiles(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final files = <File>[];
    
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.md')) {
        files.add(entity);
      }
    }

    return files;
  }

  /// Reads a file's content as a string.
  ///
  /// Returns null if the file doesn't exist or can't be read.
  Future<String?> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    
    try {
      return await file.readAsString();
    } catch (e) {
      debugPrint('Error reading file $path: $e');
      return null;
    }
  }

  /// Writes content to a file, creating parent directories if needed.
  Future<bool> writeFile(String path, String content) async {
    try {
      final file = File(path);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(content);
      return true;
    } catch (e) {
      debugPrint('Error writing file $path: $e');
      return false;
    }
  }

  /// Deletes a file.
  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting file $path: $e');
      return false;
    }
  }

  /// Creates a directory if it doesn't exist.
  Future<bool> ensureDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('Error creating directory $path: $e');
      return false;
    }
  }

  /// Checks if a path exists (file or directory).
  Future<bool> exists(String path) async {
    return await File(path).exists() || await Directory(path).exists();
  }

  /// Gets file statistics (size, modified time, etc.).
  Future<FileStat?> getStats(String path) async {
    try {
      return await FileStat.stat(path);
    } catch (e) {
      return null;
    }
  }

  /// Copies a file to a new location.
  Future<bool> copyFile(String source, String destination) async {
    try {
      final sourceFile = File(source);
      if (!await sourceFile.exists()) return false;
      
      final destDir = File(destination).parent;
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      
      await sourceFile.copy(destination);
      return true;
    } catch (e) {
      debugPrint('Error copying file $source to $destination: $e');
      return false;
    }
  }

  /// Moves/renames a file.
  Future<bool> moveFile(String source, String destination) async {
    try {
      final sourceFile = File(source);
      if (!await sourceFile.exists()) return false;
      
      final destDir = File(destination).parent;
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      
      await sourceFile.rename(destination);
      return true;
    } catch (e) {
      debugPrint('Error moving file $source to $destination: $e');
      return false;
    }
  }

  /// Gets an appropriate separator for the current platform.
  String get pathSeparator => Platform.pathSeparator;

  /// Joins path segments using the platform's separator.
  String joinPath(List<String> segments) {
    return segments.join(pathSeparator);
  }

  /// Gets the filename from a path.
  String getFileName(String path) {
    return path.split(RegExp(r'[/\\]')).last;
  }

  /// Gets the directory path from a file path.
  String getDirectoryPath(String filePath) {
    final parts = filePath.split(RegExp(r'[/\\]'));
    parts.removeLast();
    return parts.join(pathSeparator);
  }
}
