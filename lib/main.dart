import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisync/providers/providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/voice_ai_assistant_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/ai-assistant',
      builder: (context, state) => const AiAssistantScreen(),
    ),
    GoRoute(
      path: '/voice-ai-assistant',
      builder: (context, state) => const VoiceAIAssistantScreen(),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: NutriSyncApp()));
}

class NutriSyncApp extends ConsumerWidget {
  const NutriSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'NutriSync',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        fontFamily: 'Inter',
      ),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}