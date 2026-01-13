import 'package:flutter/material.dart';

class GitService extends ChangeNotifier {
  // Placeholder for Git logic
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<void> pushToBlog() async {
    _isSyncing = true;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    print("Git Push executed (Placeholder)");
    
    _isSyncing = false;
    notifyListeners();
  }

  Future<List<String>> getChangedFiles() async {
    // Mock data for the Deploy Screen UI
    return [
      'new-feature-launch.md',
      'config.json',
      'draft-post-01.md'
    ];
  }
}