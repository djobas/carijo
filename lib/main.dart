import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/sync_queue.dart';
import 'services/connectivity_service.dart';
import 'services/git_service.dart';
import 'services/logger_service.dart';
import 'services/error_handler.dart';
import 'screens/home_screen.dart';
import 'components/quick_capture.dart';
import 'widgets/command_palette.dart';
import 'widgets/error_snackbar.dart';
import 'services/note_service.dart';
import 'services/theme_service.dart';
import 'services/speech_service.dart';
import 'data/repositories/file_note_repository.dart';
import 'domain/use_cases/search_notes_use_case.dart';
import 'domain/use_cases/get_backlinks_use_case.dart';
import 'domain/use_cases/save_note_use_case.dart';

import 'data/repositories/supabase_note_repository.dart';
import 'data/repositories/shell_git_repository.dart';
import 'data/repositories/indexed_note_repository.dart';
import 'data/services/isar_database.dart';
import 'domain/use_cases/sync_notes_use_case.dart';
import 'plugins/plugin_manager.dart';
import 'plugins/builtin_plugins.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  // Initialize logging first
  await LoggerService().initialize();
  LoggerService.info('Carijó Notes starting...');
  
  final isarDb = IsarDatabase();
  await isarDb.initialize();

  final fileRepository = FileNoteRepository();
  final noteRepository = IndexedNoteRepository(fileRepository, isarDb);
  
  final connectivityService = ConnectivityService();
  final syncQueue = SyncQueue(connectivityService);

  final supabaseRepository = SupabaseNoteRepository();
  final gitRepository = ShellGitRepository();
  final syncUseCase = SyncNotesUseCase(supabaseRepository);

  final supabaseService = SupabaseService(
    repository: supabaseRepository,
    syncUseCase: syncUseCase,
    syncQueue: syncQueue,
  );
  await supabaseService.initialize();

  final noteService = NoteService(
    repository: noteRepository,
    searchUseCase: SearchNotesUseCase(),
    getBacklinksUseCase: GetBacklinksUseCase(),
    saveNoteUseCase: SaveNoteUseCase(noteRepository),
  );

  final errorHandler = ErrorHandler();
  final themeService = ThemeService();

  final pluginManager = PluginManager(
    noteService: noteService,
    errorHandler: errorHandler,
  );

  // Register and initialize builtin plugins
  for (final plugin in BuiltinPlugins.all) {
    pluginManager.registerPlugin(plugin);
  }
  await pluginManager.initializeAll();

  // Link plugin manager as observer to note service
  noteService.addObserver(pluginManager);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: noteService),
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider.value(value: syncQueue),
        ChangeNotifierProvider(create: (_) => GitService(gitRepository)),
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: errorHandler),
        ChangeNotifierProvider.value(value: pluginManager),
        ChangeNotifierProvider(create: (_) => SpeechService()..initialize()),
      ],
      child: const CarijoApp(),
    ),
  );
}

void _showAnimatedDialog(BuildContext context, Widget dialog) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Dialog",
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => dialog,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
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
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _showAnimatedDialog(context, const CommandPalette()),
            const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true): () => _showAnimatedDialog(context, const CommandPalette()),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _showAnimatedDialog(context, const CommandPalette()),
            const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true): () => _showAnimatedDialog(context, const CommandPalette()),
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _showAnimatedDialog(context, const QuickCaptureDialog()),
          },
          child: Focus(
            autofocus: true,
            child: child ?? const SizedBox(),
          ),
        );
      },
      home: const ErrorSnackbarListener(child: HomeScreen()),
    );
  }
}
