import 'dart:io';
import '../../domain/models/git_file.dart';
import '../../domain/repositories/git_repository.dart';

class ShellGitRepository implements GitRepository {
  @override
  Future<List<GitFile>> getStatus(String workingDir) async {
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
  }

  @override
  Future<void> stageFile(String path, String workingDir) async {
    await _runGit(['add', path], workingDir);
  }

  @override
  Future<void> unstageFile(String path, String workingDir) async {
    await _runGit(['reset', 'HEAD', path], workingDir);
  }

  @override
  Future<void> commit(String message, String workingDir) async {
    await _runGit(['commit', '-m', message], workingDir);
  }

  @override
  Future<void> push(String workingDir) async {
    await _runGit(['push'], workingDir);
  }

  @override
  Future<String> getDiff(String path, String workingDir) async {
    try {
      return await _runGit(['diff', 'HEAD', '--', path], workingDir);
    } catch (_) {
      try {
        return await _runGit(['diff', '--no-index', '/dev/null', path], workingDir);
      } catch (_) {
        return "New file: $path";
      }
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
