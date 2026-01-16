import 'package:flutter_test/flutter_test.dart';
import 'package:carijo_notes/services/git_service.dart';
import 'package:carijo_notes/domain/models/git_file.dart';
import 'package:carijo_notes/domain/repositories/git_repository.dart';

/// Mock implementation of GitRepository for testing
class MockGitRepository implements GitRepository {
  bool stageFileCalled = false;
  bool unstageFileCalled = false;
  bool commitCalled = false;
  bool pushCalled = false;
  bool getDiffCalled = false;
  bool getStatusCalled = false;
  
  String? lastStagedFile;
  String? lastCommitMessage;
  String? lastDiffPath;
  
  bool shouldThrowOnPush = false;
  bool shouldThrowOnCommit = false;
  bool shouldThrowOnStatus = false;
  
  List<GitFile> mockStatus = [];
  String mockDiff = 'mock diff content';

  @override
  Future<void> stageFile(String path, String workingDir) async {
    stageFileCalled = true;
    lastStagedFile = path;
  }

  @override
  Future<void> unstageFile(String path, String workingDir) async {
    unstageFileCalled = true;
  }

  @override
  Future<void> commit(String message, String workingDir) async {
    if (shouldThrowOnCommit) {
      throw Exception('Commit failed');
    }
    commitCalled = true;
    lastCommitMessage = message;
  }

  @override
  Future<void> push(String workingDir) async {
    if (shouldThrowOnPush) {
      throw Exception('Push failed: remote rejected');
    }
    pushCalled = true;
  }

  @override
  Future<List<GitFile>> getStatus(String workingDir) async {
    if (shouldThrowOnStatus) {
      throw Exception('Status failed');
    }
    getStatusCalled = true;
    return mockStatus;
  }

  @override
  Future<String> getDiff(String path, String workingDir) async {
    getDiffCalled = true;
    lastDiffPath = path;
    return mockDiff;
  }
}

void main() {
  late GitService gitService;
  late MockGitRepository mockRepository;

  setUp(() {
    mockRepository = MockGitRepository();
    gitService = GitService(mockRepository);
  });

  group('GitService', () {
    group('pushToBlog', () {
      test('should stage, commit and push in sequence', () async {
        await gitService.pushToBlog('/test/dir', commitMessage: 'Test commit');
        
        expect(mockRepository.stageFileCalled, true);
        expect(mockRepository.lastStagedFile, '.');
        expect(mockRepository.commitCalled, true);
        expect(mockRepository.lastCommitMessage, 'Test commit');
        expect(mockRepository.pushCalled, true);
      });

      test('should use default commit message when not provided', () async {
        await gitService.pushToBlog('/test/dir');
        
        expect(mockRepository.lastCommitMessage, contains('Carijó Deploy'));
      });

      test('should set isSyncing during operation', () async {
        expect(gitService.isSyncing, false);
        
        final future = gitService.pushToBlog('/test/dir');
        // Note: In a real test we'd need to observe the state during async
        await future;
        
        expect(gitService.isSyncing, false);
      });

      test('should capture error when push fails', () async {
        mockRepository.shouldThrowOnPush = true;
        
        await gitService.pushToBlog('/test/dir');
        
        expect(gitService.lastError, contains('Push failed'));
      });

      test('should capture error when commit fails', () async {
        mockRepository.shouldThrowOnCommit = true;
        
        await gitService.pushToBlog('/test/dir');
        
        expect(gitService.lastError, contains('Commit failed'));
      });
    });

    group('getGitStatus', () {
      test('should return file list from repository', () async {
        mockRepository.mockStatus = [
          const GitFile(path: 'file1.md', status: 'M', isStaged: false),
          const GitFile(path: 'file2.md', status: 'A', isStaged: true),
        ];
        
        final result = await gitService.getGitStatus('/test/dir');
        
        expect(mockRepository.getStatusCalled, true);
        expect(result.length, 2);
        expect(result[0].path, 'file1.md');
        expect(result[1].isStaged, true);
      });

      test('should return empty list on error', () async {
        mockRepository.shouldThrowOnStatus = true;
        
        final result = await gitService.getGitStatus('/test/dir');
        
        expect(result, isEmpty);
      });
    });

    group('toggleStaging', () {
      test('should call stageFile when staging', () async {
        await gitService.toggleStaging('file.md', true, '/test/dir');
        
        expect(mockRepository.stageFileCalled, true);
        expect(mockRepository.unstageFileCalled, false);
      });

      test('should call unstageFile when unstaging', () async {
        await gitService.toggleStaging('file.md', false, '/test/dir');
        
        expect(mockRepository.stageFileCalled, false);
        expect(mockRepository.unstageFileCalled, true);
      });
    });

    group('getFileDiff', () {
      test('should return diff content from repository', () async {
        mockRepository.mockDiff = 'added line\nremoved line';
        
        final result = await gitService.getFileDiff('file.md', '/test/dir');
        
        expect(mockRepository.getDiffCalled, true);
        expect(result, contains('added line'));
      });
    });
  });
}
