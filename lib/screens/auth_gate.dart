import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisync/providers/providers.dart';
import 'package:nutrisync/screens/home_screen.dart';
import 'package:nutrisync/screens/login_screen.dart';
import 'package:nutrisync/screens/onboarding_screen.dart';

/// Routes the user based on:
///   not logged in        → LoginScreen
///   logged in, no onboarding → OnboardingScreen
///   logged in, done      → MainScreen (with offline banner)
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _SplashLoader(),
      error: (e, _) => _AuthError(message: e.toString()),
      data: (user) {
        if (user == null) return const LoginScreen();

        // Check onboarding completion
        final onboarding = ref.watch(onboardingProvider);
        return onboarding.when(
          loading: () => const _SplashLoader(),
          error: (_, __) => const MainScreen(), // fail-open
          data: (complete) =>
              complete ? const MainScreen() : const OnboardingScreen(),
        );
      },
    );
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2D5B42),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'NutriSync',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
