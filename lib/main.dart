import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/git_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'components/quick_capture.dart';
import 'widgets/command_palette.dart';
import 'services/note_service.dart';
import 'services/theme_service.dart';
import 'data/repositories/file_note_repository.dart';
import 'domain/use_cases/search_notes_use_case.dart';
import 'domain/use_cases/get_backlinks_use_case.dart';
import 'domain/use_cases/save_note_use_case.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final supabaseService = SupabaseService();
  await supabaseService.initialize();

  final repository = FileNoteRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NoteService(
            repository: repository,
            searchUseCase: SearchNotesUseCase(),
            getBacklinksUseCase: GetBacklinksUseCase(),
            saveNoteUseCase: SaveNoteUseCase(repository),
          ),
        ),
        ChangeNotifierProvider(create: (_) => GitService()),
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const CarijoApp(),
    ),
  );
}

class CarijoApp extends StatelessWidget {
  const CarijoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.theme;

    return MaterialApp(
      title: 'Carijó Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: theme.bgMain,
        primaryColor: theme.accent,
        useMaterial3: true,
      ),
      builder: (context, child) {
        // Global Shortcuts Wrapper
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
              showDialog(
                context: context, 
                builder: (_) => const CommandPalette(),
                barrierColor: Colors.black.withOpacity(0.7),
              );
            },
            const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true): () {
              showDialog(
                context: context, 
                builder: (_) => const CommandPalette(),
                barrierColor: Colors.black.withOpacity(0.7),
              );
            },
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
              // MacOS support
              showDialog(
                context: context, 
                builder: (_) => const CommandPalette(),
                barrierColor: Colors.black.withOpacity(0.7),
              );
            },
            const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true): () {
              // MacOS support
              showDialog(
                context: context, 
                builder: (_) => const CommandPalette(),
                barrierColor: Colors.black.withOpacity(0.7),
              );
            },
            // Quick Capture shortcut could be globally bound here too if window focus permits
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
               showDialog(context: context, builder: (_) => const QuickCaptureDialog());
            },
          },
          child: Focus(
            autofocus: true,
            child: child!,
          ),
        );
      },
      home: HomeScreen(),
    );
  }
}