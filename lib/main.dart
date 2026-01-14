import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/note_service.dart';
import 'services/git_service.dart';
import 'screens/home_screen.dart';
import 'components/quick_capture.dart';
import 'components/command_palette.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteService()),
        ChangeNotifierProvider(create: (_) => GitService()),
      ],
      child: const CarijoApp(),
    ),
  );
}

class CarijoApp extends StatelessWidget {
  const CarijoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carijó Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        primaryColor: const Color(0xFFD93025),
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
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
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