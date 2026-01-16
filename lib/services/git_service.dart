import 'package:flutter/material.dart';
export '../domain/models/git_file.dart';
import '../domain/models/git_file.dart';
import '../domain/repositories/git_repository.dart';
import 'logger_service.dart';

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
      
      LoggerService.info("Git Push executed successfully");
    } catch (e) {
      _lastError = e.toString();
      LoggerService.error("Git Push failed", error: e);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<List<GitFile>> getGitStatus(String workingDir) async {
    try {
      return await repository.getStatus(workingDir);
    } catch (e) {
      LoggerService.error("Git Status failed", error: e);
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
      LoggerService.error("Git Staging failed", error: e);
    }
  }

  Future<String> getFileDiff(String path, String workingDir) async {
    try {
      return await repository.getDiff(path, workingDir);
    } catch (e) {
      LoggerService.error("Git Diff failed", error: e);
      return "Error fetching diff: $e";
    }
  }
}
