import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api/auth_service.dart';
import '../api/firestore_service.dart' as api;
import '../models/user_model.dart';
import '../services/user_profile_service.dart';
import '../services/subscription_service.dart';

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

/// Provides a singleton instance of [UserProfileService] for profile management.
final userProfileServiceProvider = Provider<UserProfileService>((ref) => UserProfileService());

/// Provides a singleton instance of [SubscriptionService] for subscription management.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) => SubscriptionService());

/// Watches the authentication state (signed in/out) as a [StreamProvider].
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Provides the current user's profile from Firestore as an AsyncValue<UserModel?>.
/// If the user document does not exist, creates a new user document with default values.
final userProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final profileService = ref.watch(userProfileServiceProvider);
  final result = await profileService.getProfile(user.uid);
  if (result.data == null) {
    // Create a new user document with default values
    final createResult = await profileService.createProfile(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
    );
    if (createResult.error != null) {
      // Log or handle error as needed
      return null;
    }
    return createResult.data;
  }
  return result.data;
});

/// Provides the current user's subscription status
final subscriptionStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  final result = await subscriptionService.getSubscriptionStatus(user.uid);
  return result.data;
});

/// Provides the current user's available features
final availableFeaturesProvider = FutureProvider<Map<String, bool>?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  final result = await subscriptionService.getAvailableFeatures(user.uid);
  return result.data;
});

/// Provides the current user's profile completion percentage
final profileCompletionProvider = FutureProvider<double?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final profileService = ref.watch(userProfileServiceProvider);
  final result = await profileService.getProfileCompletionPercentage(user.uid);
  return result.data;
});
