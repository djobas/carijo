import 'dart:io';
import 'package:flutter/material.dart';

class GitFile {
  final String path;
  final bool isStaged;
  final String status; // 'modified', 'added', 'deleted'

  GitFile({required this.path, required this.isStaged, required this.status});
}

class GitService extends ChangeNotifier {
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  String? _lastError;
  String? get lastError => _lastError;

  Future<void> pushToBlog(String workingDir) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Stage all changes (simple flow for now)
      await _runGit(['add', '.'], workingDir);
      
      // 2. Commit with timestamp
      final timestamp = DateTime.now().toIso8601String();
      await _runGit(['commit', '-m', 'Carijó Deploy: $timestamp'], workingDir);
      
      // 3. Push
      await _runGit(['push'], workingDir);
      
      print("Git Push executed successfully");
    } catch (e) {
      _lastError = e.toString();
      print("Git Push error: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<List<GitFile>> getGitStatus(String workingDir) async {
    try {
      final result = await _runGit(['status', '--porcelain'], workingDir);
      if (result.isEmpty) return [];

      return result.split('\n').where((line) => line.isNotEmpty).map((line) {
        final statusCodes = line.substring(0, 2);
        final path = line.substring(3).trim();
        
        // Porcelain format: XY path
        // X = index, Y = working tree
        final isStaged = statusCodes[0] != ' ' && statusCodes[0] != '?';
        
        String status = 'modified';
        if (statusCodes.contains('?')) status = 'added';
        if (statusCodes.contains('D')) status = 'deleted';

        return GitFile(path: path, isStaged: isStaged, status: status);
      }).toList();
    } catch (e) {
      print("Git Status error: $e");
      return [];
    }
  }

  Future<void> toggleStaging(String path, bool stage, String workingDir) async {
    try {
      if (stage) {
        await _runGit(['add', path], workingDir);
      } else {
        await _runGit(['reset', 'HEAD', path], workingDir);
      }
      notifyListeners();
    } catch (e) {
      print("Git Staging error: $e");
    }
  }

  Future<String> _runGit(List<String> args, String workingDir) async {
    final result = await Process.run('git', args, workingDirectory: workingDir);
    if (result.exitCode != 0) {
      throw Exception("Git command failed: git ${args.join(' ')}\nError: ${result.stderr}");
    }
    return result.stdout.toString();
  }
}