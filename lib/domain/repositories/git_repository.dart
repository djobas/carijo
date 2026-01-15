import '../models/git_file.dart';

abstract class GitRepository {
  Future<List<GitFile>> getStatus(String workingDir);
  Future<void> stageFile(String path, String workingDir);
  Future<void> unstageFile(String path, String workingDir);
  Future<void> commit(String message, String workingDir);
  Future<void> push(String workingDir);
  Future<String> getDiff(String path, String workingDir);
}
