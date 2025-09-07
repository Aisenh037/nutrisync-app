import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api/auth_service.dart';
import '../api/firestore_service.dart' as api;
import '../models/user_model.dart';

// Theme mode provider (light/dark)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// Notifications enabled provider
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);

/// Provides the current user's meal plan from Firestore as an AsyncValue<Map<String, List<String>>>.
final mealPlanProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return {};
  final firestore = ref.watch(firestoreServiceProvider);
  final result = await firestore.getMealPlan(user.uid);
  return result.data ?? {};
});

/// Provides the current user's grocery list from Firestore as an AsyncValue<List<String>>.
final groceriesProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return [];
  final firestore = ref.watch(firestoreServiceProvider);
  final result = await firestore.getGroceries(user.uid);
  return result.data ?? [];
});

/// Provides a singleton instance of [AuthService] for authentication actions.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Provides a singleton instance of [FirestoreService] for Firestore actions.
final firestoreServiceProvider = Provider<api.FirestoreService>((ref) => api.FirestoreService());

/// Watches the authentication state (signed in/out) as a [StreamProvider].
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Provides the current user's profile from Firestore as an AsyncValue<UserModel?>.
final userProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final firestore = ref.watch(firestoreServiceProvider);
  final result = await firestore.getUser(user.uid);
  return result.data;
});