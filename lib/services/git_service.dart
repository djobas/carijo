import 'package:flutter/material.dart';
export '../domain/models/git_file.dart';
import '../domain/models/git_file.dart';
import '../domain/repositories/git_repository.dart';
import 'logger_service.dart';

/// Service for Git operations including staging, committing and pushing.
///
/// Provides a high-level interface for Git version control operations,
/// primarily used for deploying notes to a remote repository.
///
/// Example usage:
/// ```dart
/// final gitService = Provider.of<GitService>(context);
/// await gitService.pushToBlog('/path/to/repo', commitMessage: 'Deploy notes');
/// ```
class GitService extends ChangeNotifier {
  final GitRepository repository;
  
  bool _isSyncing = false;

  /// Whether a sync operation is currently in progress.
  bool get isSyncing => _isSyncing;
  
  String? _lastError;

  /// The last error message, or null if no error occurred.
  String? get lastError => _lastError;

  /// Creates a GitService with the given [repository].
  GitService(this.repository);

  /// Stages all changes, commits, and pushes to the remote repository.
  ///
  /// The [workingDir] is the path to the Git repository.
  /// An optional [commitMessage] can be provided; defaults to a timestamp.
  ///
  /// Sets [isSyncing] to true during the operation and updates [lastError]
  /// if an error occurs.
  Future<void> pushToBlog(String workingDir, {String? commitMessage}) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Stage all changes
      await repository.stageFile('.', workingDir);
      
      // 2. Commit
      final message = commitMessage ?? "Carijó Deploy: ${DateTime.now().toIso8601String()}";
      await repository.commit(message, workingDir);
      
      // 3. Push
      await repository.push(workingDir);
      
      LoggerService.info("Git Push executed successfully");
    } catch (e) {
      _lastError = e.toString();
      LoggerService.error("Git Push failed", error: e);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Gets the current Git status for the [workingDir].
  ///
  /// Returns a list of [GitFile] objects representing modified, added,
  /// or deleted files. Returns an empty list if an error occurs.
  Future<List<GitFile>> getGitStatus(String workingDir) async {
    try {
      return await repository.getStatus(workingDir);
    } catch (e) {
      LoggerService.error("Git Status failed", error: e);
      return [];
    }
  }

  /// Stages or unstages a file at [path].
  ///
  /// If [stage] is true, the file is staged for commit.
  /// If [stage] is false, the file is unstaged.
  Future<void> toggleStaging(String path, bool stage, String workingDir) async {
    try {
      if (stage) {
        await repository.stageFile(path, workingDir);
      } else {
        await repository.unstageFile(path, workingDir);
      }
      notifyListeners();
    } catch (e) {
      LoggerService.error("Git Staging failed", error: e);
    }
  }

  /// Gets the diff for a file at [path].
  ///
  /// Returns the diff output as a string, or an error message if the
  /// operation fails.
  Future<String> getFileDiff(String path, String workingDir) async {
    try {
      return await repository.getDiff(path, workingDir);
    } catch (e) {
      LoggerService.error("Git Diff failed", error: e);
      return "Error fetching diff: $e";
    }
  }
}

