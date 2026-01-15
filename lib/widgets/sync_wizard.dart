import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/supabase_service.dart';

class SyncWizard extends StatefulWidget {
  const SyncWizard({super.key});

  @override
  State<SyncWizard> createState() => _SyncWizardState();
}

class _SyncWizardState extends State<SyncWizard> {
  int _currentStep = 0;
  String _selectedMethod = 'supabase'; // git, supabase, or both
  
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  
  bool _testing = false;
  String? _testResult;

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    
    try {
      final url = _urlController.text.trim();
      final key = _keyController.text.trim();
      
      if (url.isEmpty || key.isEmpty) {
        setState(() => _testResult = "❌ Both fields are required");
        return;
      }
      
      if (!url.startsWith('https://') || !url.contains('supabase')) {
        setState(() => _testResult = "❌ Invalid URL format");
        return;
      }
      
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      await supabaseService.saveConfig(url, key);
      
      if (supabaseService.isInitialized) {
        setState(() => _testResult = "✅ Success!");
      } else {
        setState(() => _testResult = "❌ Connection failed");
      }
    } catch (e) {
      setState(() => _testResult = "❌ Error: $e");
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context).theme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: theme.bgMain,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              Expanded(child: _buildStepContent(theme)),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_sync, color: theme.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Setup Sync", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Step ${_currentStep + 1} of 3", style: GoogleFonts.jetBrainsMono(color: theme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: theme.textMuted, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(dynamic theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(theme);
      case 1:
        return _buildStep2(theme);
      case 2:
        return _buildStep3(theme);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1(dynamic theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Choose Your Sync Method", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("How would you like to sync your notes?", style: GoogleFonts.inter(color: theme.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          _buildMethodCard(
            theme: theme,
            value: 'git',
            icon: Icons.commit,
            title: 'Git Only',
            description: 'Version control with GitHub, GitLab, etc. Requires Git installed.',
          ),
          const SizedBox(height: 12),
          _buildMethodCard(
            theme: theme,
            value: 'supabase',
            icon: Icons.cloud,
            title: 'Supabase Cloud',
            description: 'Real-time sync to your own Supabase project. Free tier available.',
          ),
          const SizedBox(height: 12),
          _buildMethodCard(
            theme: theme,
            value: 'both',
            icon: Icons.sync_alt,
            title: 'Both',
            description: 'Use Git for versioning and Supabase for cloud access.',
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required dynamic theme,
    required String value,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedMethod == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent.withValues(alpha: 0.1) : theme.bgSidebar,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? theme.accent : theme.borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? theme.accent : theme.bgMain,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? theme.textMain : theme.textMuted, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description, style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(dynamic theme) {
    if (_selectedMethod == 'git') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Git Configuration", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.bgSidebar,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.terminal, color: theme.textMuted, size: 40),
                  const SizedBox(height: 12),
                  Text("Git is configured via command line", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text("Run these commands in your notes folder:", style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.bgMain, borderRadius: BorderRadius.circular(6)),
                    child: Text("git init\ngit remote add origin <your-repo-url>", style: GoogleFonts.jetBrainsMono(color: theme.accent, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Supabase Configuration", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Enter your Supabase project credentials:", style: GoogleFonts.inter(color: theme.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          Text("Project URL", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(14),
              filled: true,
              fillColor: theme.bgSidebar,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              hintText: "https://yourproject.supabase.co",
              hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 16),
          Text("Anon Key", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _keyController,
            obscureText: true,
            style: GoogleFonts.jetBrainsMono(color: theme.textMain, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(14),
              filled: true,
              fillColor: theme.bgSidebar,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              hintText: "eyJhbGciOiJIUzI1NiIs...",
              hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 16),
          Text("Find these in your Supabase dashboard → Settings → API", style: GoogleFonts.inter(color: theme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStep3(dynamic theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Test Connection", style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Let's verify everything is working:", style: GoogleFonts.inter(color: theme.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (_selectedMethod == 'git' || _selectedMethod == 'both')
            _buildTestRow(theme, "Git", Icons.commit, null),
          if (_selectedMethod == 'supabase' || _selectedMethod == 'both') ...[
            const SizedBox(height: 16),
            _buildTestRow(theme, "Supabase", Icons.cloud, _testResult),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.textMain))
                : const Icon(Icons.wifi_tethering, size: 18),
              label: Text("Test Supabase", style: GoogleFonts.spaceGrotesk()),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.textMain,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTestRow(dynamic theme, String name, IconData icon, String? result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bgSidebar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.textMuted, size: 20),
          const SizedBox(width: 12),
          Text(name, style: GoogleFonts.spaceGrotesk(color: theme.textMain, fontSize: 14)),
          const Spacer(),
          Text(result ?? "Ready to test", style: GoogleFonts.jetBrainsMono(color: result?.startsWith("✅") == true ? theme.success : theme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFooter(dynamic theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: Text("Back", style: GoogleFonts.spaceGrotesk(color: theme.textMuted)),
            )
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: () {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Sync configured successfully!")),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.textMain,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(_currentStep == 2 ? "Finish" : "Next", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
