import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../services/note_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../plugins/plugin_manager.dart';
import '../plugins/plugin_interface.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseKeyController = TextEditingController();

  bool _gitDetected = false;
  String? _gitRemote;
  bool _testingSupabase = false;
  String? _supabaseTestResult;

  @override
  void initState() {
    super.initState();
    final noteService = Provider.of<NoteService>(context, listen: false);
    _pathController.text = noteService.notesPath ?? '';
    _loadSupabasePrefs();
    _detectGit();
  }

  Future<void> _loadSupabasePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _supabaseUrlController.text = prefs.getString(SupabaseService.keyUrl) ?? '';
      _supabaseKeyController.text = prefs.getString(SupabaseService.keyAnonKey) ?? '';
    });
  }

  Future<void> _detectGit() async {
    final path = _pathController.text;
    if (path.isEmpty) return;
    
    final gitDir = Directory('$path${Platform.pathSeparator}.git');
    if (await gitDir.exists()) {
      setState(() => _gitDetected = true);
      // Try to get remote URL
      try {
        final result = await Process.run('git', ['remote', 'get-url', 'origin'], workingDirectory: path);
        if (result.exitCode == 0) {
          setState(() => _gitRemote = result.stdout.toString().trim());
        }
      } catch (_) {}
    } else {
      setState(() {
        _gitDetected = false;
        _gitRemote = null;
      });
    }
  }

  Future<void> _testSupabaseConnection() async {
    setState(() {
      _testingSupabase = true;
      _supabaseTestResult = null;
    });
    
    try {
      final url = _supabaseUrlController.text.trim();
      final key = _supabaseKeyController.text.trim();
      
      if (url.isEmpty || key.isEmpty) {
        setState(() => _supabaseTestResult = "❌ URL and Key are required");
        return;
      }
      
      // Basic URL validation
      if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
        setState(() => _supabaseTestResult = "❌ Invalid Supabase URL format");
        return;
      }
      
      // Save and reinitialize
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      await supabaseService.saveConfig(url, key);
      
      if (supabaseService.isInitialized) {
        setState(() => _supabaseTestResult = "✅ Connection successful!");
      } else {
        setState(() => _supabaseTestResult = "❌ Failed to initialize");
      }
    } catch (e) {
      setState(() => _supabaseTestResult = "❌ Error: $e");
    } finally {
      setState(() => _testingSupabase = false);
    }
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _pathController.text = result);
      _detectGit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;
    final supabaseService = Provider.of<SupabaseService>(context);
    final pluginManager = Provider.of<PluginManager>(context);

    return Scaffold(
      backgroundColor: theme.bgMain,
      appBar: AppBar(
        backgroundColor: theme.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Settings", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sync Status Overview
                _buildSyncOverview(theme, supabaseService),
                const SizedBox(height: 32),

                // Storage Section
                _buildSectionHeader("STORAGE", theme),
                const SizedBox(height: 16),
                _buildStorageSection(theme, themeService),
                const SizedBox(height: 32),

                // Git Sync Section
                _buildSectionHeader("GIT SYNC", theme),
                const SizedBox(height: 16),
                _buildGitSection(theme),
                const SizedBox(height: 32),

                // Supabase Section
                _buildSectionHeader("CLOUD SYNC (SUPABASE)", theme),
                const SizedBox(height: 16),
                _buildSupabaseSection(theme),
                const SizedBox(height: 32),

                // Plugins Section
                _buildSectionHeader("PLUGINS", theme),
                const SizedBox(height: 16),
                _buildPluginsSection(theme, pluginManager),
                const SizedBox(height: 40),

                // Save Button
                _buildSaveButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncOverview(dynamic theme, SupabaseService supabaseService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        children: [
          _buildStatusCard(
            icon: Icons.folder_open,
            label: "Local",
            status: _pathController.text.isNotEmpty ? "Configured" : "Not Set",
            isActive: _pathController.text.isNotEmpty,
            theme: theme,
          ),
          const SizedBox(width: 16),
          _buildStatusCard(
            icon: Icons.commit,
            label: "Git",
            status: _gitDetected ? "Detected" : "Not Found",
            isActive: _gitDetected,
            theme: theme,
          ),
          const SizedBox(width: 16),
          _buildStatusCard(
            icon: Icons.cloud,
            label: "Supabase",
            status: supabaseService.isInitialized ? "Connected" : "Not Set",
            isActive: supabaseService.isInitialized,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required String status,
    required bool isActive,
    required dynamic theme,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.bgMain,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? theme.success : theme.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? theme.success : theme.textMuted, size: 24),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(status, style: GoogleFonts.jetBrainsMono(color: isActive ? theme.success : theme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, dynamic theme) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        color: theme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildStorageSection(dynamic theme, ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("UI Theme", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButton<AppTheme>(
            value: themeService.theme,
            dropdownColor: theme.bgSidebar,
            isExpanded: true,
            underline: Container(height: 1, color: theme.borderColor),
            icon: Icon(Icons.palette, color: theme.accent, size: 18),
            items: themeService.themes.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t.name, style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 13)),
            )).toList(),
            onChanged: (newTheme) {
              if (newTheme != null) themeService.setTheme(newTheme);
            },
          ),
          const SizedBox(height: 20),
          Text("Notes Folder", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: theme.bgMain,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.accent)),
                    hintText: "C:\\Users\\you\\notes",
                    hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
                  ),
                  onChanged: (_) => _detectGit(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _pickFolder,
                icon: Icon(Icons.folder_open, color: theme.accent),
                tooltip: "Browse...",
                style: IconButton.styleFrom(
                  backgroundColor: theme.bgMain,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGitSection(dynamic theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gitDetected ? theme.success : theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_gitDetected ? Icons.check_circle : Icons.warning_amber_rounded, 
                color: _gitDetected ? theme.success : theme.textMuted, size: 20),
              const SizedBox(width: 12),
              Text(
                _gitDetected ? "Git Repository Detected" : "No Git Repository Found",
                style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_gitRemote != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.link, color: theme.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _gitRemote!,
                    style: GoogleFonts.jetBrainsMono(color: theme.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _gitDetected 
              ? "Your notes folder is a Git repository. Use Deploy (Ctrl+K → Deploy) to push changes."
              : "To enable Git sync, initialize a Git repository in your notes folder using 'git init'.",
            style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSupabaseSection(dynamic theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Project URL", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _supabaseUrlController,
            style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: theme.bgMain,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.accent)),
              hintText: "https://yourproject.supabase.co",
              hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.link, color: theme.textMuted, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          Text("Anon Public Key", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _supabaseKeyController,
            obscureText: true,
            style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: theme.bgMain,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.accent)),
              hintText: "eyJhbGciOiJIUzI1NiIs...",
              hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.key, color: theme.textMuted, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testingSupabase ? null : _testSupabaseConnection,
                icon: _testingSupabase 
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent))
                  : Icon(Icons.wifi_tethering, size: 16),
                label: Text("Test Connection", style: GoogleFonts.spaceGrotesk(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textMain,
                  side: BorderSide(color: theme.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              if (_supabaseTestResult != null) ...[
                const SizedBox(width: 16),
                Text(_supabaseTestResult!, style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Create a free project at supabase.com. Copy the URL and anon key from Settings > API.",
            style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(dynamic theme) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: () async {
          final noteService = Provider.of<NoteService>(context, listen: false);
          final supabaseService = Provider.of<SupabaseService>(context, listen: false);
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);

          noteService.setNotesPath(_pathController.text);
          await supabaseService.saveConfig(_supabaseUrlController.text.trim(), _supabaseKeyController.text.trim());

          messenger.showSnackBar(const SnackBar(content: Text("✅ Configuration Saved")));
          navigator.pop();
        },
        icon: const Icon(Icons.save, size: 18),
        label: Text("Save All", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: theme.textMain,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildPluginsSection(dynamic theme, PluginManager pluginManager) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...pluginManager.plugins.map((plugin) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.bgMain,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(plugin.icon, color: theme.accent, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plugin.name, style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text("v${plugin.version}", style: GoogleFonts.jetBrainsMono(color: theme.textMuted, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(plugin.description, style: GoogleFonts.inter(color: theme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: pluginManager.isEnabled(plugin.id),
                  onChanged: (value) => pluginManager.setEnabled(plugin.id, value),
                  activeColor: theme.accent,
                ),
              ],
            ),
          )),
          if (pluginManager.plugins.isEmpty)
            Text("No plugins installed", style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
