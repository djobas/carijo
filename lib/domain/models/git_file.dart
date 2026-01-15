class GitFile {
  final String path;
  final bool isStaged;
  final String status; // 'modified', 'added', 'deleted'

  GitFile({required this.path, required this.isStaged, required this.status});
}
