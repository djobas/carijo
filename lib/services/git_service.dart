import 'package:flutter/material.dart';
export '../domain/models/git_file.dart';
import '../domain/models/git_file.dart';
import '../domain/repositories/git_repository.dart';

class GitService extends ChangeNotifier {
  final GitRepository repository;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  String? _lastError;
  String? get lastError => _lastError;

  GitService(this.repository);

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
      
      debugPrint("Git Push executed successfully");
    } catch (e) {
      _lastError = e.toString();
      debugPrint("Git Push error: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<List<GitFile>> getGitStatus(String workingDir) async {
    try {
      return await repository.getStatus(workingDir);
    } catch (e) {
      debugPrint("Git Status error: $e");
      return [];
    }
  }

  Future<void> toggleStaging(String path, bool stage, String workingDir) async {
    try {
      if (stage) {
        await repository.stageFile(path, workingDir);
      } else {
        await repository.unstageFile(path, workingDir);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Git Staging error: $e");
    }
  }

  Future<String> getFileDiff(String path, String workingDir) async {
    try {
      return await repository.getDiff(path, workingDir);
    } catch (e) {
      debugPrint("Git Diff error: $e");
      return "Error fetching diff: $e";
    }
  }
}
