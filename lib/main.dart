import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisync/providers/providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Disable Crashlytics in debug builds — noise-free local dev.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    // Catch Flutter framework errors (widget build failures, etc.).
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Catch errors from the platform thread / async gaps not inside Flutter.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    runApp(const ProviderScope(child: NutriSyncApp()));
  }, (error, stack) {
    // Catch errors thrown inside runZonedGuarded (Dart isolate zone).
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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