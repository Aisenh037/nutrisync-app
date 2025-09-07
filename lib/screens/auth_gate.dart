import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisync/providers/providers.dart';
import 'package:nutrisync/screens/home_screen.dart';
import 'package:nutrisync/screens/login_screen.dart';

/// AuthGate routes the user to the correct screen based on authentication state.
/// Shows loading indicator while checking, and displays error messages if any.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const MainScreen(); // User is logged in
        } else {
          return const LoginScreen(); // User is not logged in
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Auth error: $e', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}