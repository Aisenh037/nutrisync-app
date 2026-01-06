import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Service for managing user profiles with comprehensive health and dietary information
class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Create a new user profile with default values
  Future<FirestoreResult<UserModel>> createProfile({
    required String uid,
    required String name,
    required String email,
    List<String>? dietaryNeeds,
    List<String>? healthGoals,
  }) async {
    try {
      final now = DateTime.now();
      final userModel = UserModel(
        uid: uid,
        name: name,
        email: email,
        dietaryNeeds: dietaryNeeds ?? [],
        healthGoals: healthGoals ?? [],
        createdAt: now,
        updatedAt: now,
        subscriptionTier: 'free',
        monthlyQueriesLimit: 50, // Free tier limit
        dailyQueriesUsed: 0,
        lastQueryResetDate: now,
      );

      await _db.collection('users').doc(uid).set(userModel.toMap());
      return FirestoreResult<UserModel>(data: userModel);
    } catch (e) {
      return FirestoreResult<UserModel>(error: 'Failed to create profile: $e');
    }
  }

  /// Update user profile with new information
  Future<FirestoreResult<UserModel>> updateProfile({
    required String uid,
    String? name,
    String? email,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
    List<String>? dietaryNeeds,
    List<String>? healthGoals,
    List<String>? medicalConditions,
    List<String>? allergies,
    List<String>? foodDislikes,
    String? preferredLanguage,
    Map<String, dynamic>? culturalPreferences,
  }) async {
    try {
      // Get current profile
      final currentResult = await getProfile(uid);
      if (currentResult.error != null) {
        return FirestoreResult<UserModel>(error: currentResult.error);
      }

      final currentProfile = currentResult.data!;
      final updatedProfile = currentProfile.copyWith(
        name: name,
        email: email,
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
        dietaryNeeds: dietaryNeeds,
        healthGoals: healthGoals,
        medicalConditions: medicalConditions,
        allergies: allergies,
        foodDislikes: foodDislikes,
        preferredLanguage: preferredLanguage,
        culturalPreferences: culturalPreferences,
        updatedAt: DateTime.now(),
      );

      await _db.collection('users').doc(uid).update(updatedProfile.toMap());
      return FirestoreResult<UserModel>(data: updatedProfile);
    } catch (e) {
      return FirestoreResult<UserModel>(error: 'Failed to update profile: $e');
    }
  }

  /// Get user profile by UID
  Future<FirestoreResult<UserModel>> getProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return FirestoreResult<UserModel>(data: UserModel.fromMap(doc.data()!));
      } else {
        return FirestoreResult<UserModel>(error: 'User profile not found');
      }
    } catch (e) {
      return FirestoreResult<UserModel>(error: 'Failed to fetch profile: $e');
    }
  }

  /// Add medical condition to user profile
  Future<FirestoreResult<void>> addMedicalCondition(String uid, String condition) async {
    try {
      await _db.collection('users').doc(uid).update({
        'medicalConditions': FieldValue.arrayUnion([condition]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to add medical condition: $e');
    }
  }

  /// Remove medical condition from user profile
  Future<FirestoreResult<void>> removeMedicalCondition(String uid, String condition) async {
    try {
      await _db.collection('users').doc(uid).update({
        'medicalConditions': FieldValue.arrayRemove([condition]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to remove medical condition: $e');
    }
  }

  /// Add allergy to user profile
  Future<FirestoreResult<void>> addAllergy(String uid, String allergy) async {
    try {
      await _db.collection('users').doc(uid).update({
        'allergies': FieldValue.arrayUnion([allergy]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to add allergy: $e');
    }
  }

  /// Remove allergy from user profile
  Future<FirestoreResult<void>> removeAllergy(String uid, String allergy) async {
    try {
      await _db.collection('users').doc(uid).update({
        'allergies': FieldValue.arrayRemove([allergy]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to remove allergy: $e');
    }
  }

  /// Update dietary preferences
  Future<FirestoreResult<void>> updateDietaryPreferences({
    required String uid,
    required List<String> dietaryNeeds,
    required List<String> foodDislikes,
  }) async {
    try {
      await _db.collection('users').doc(uid).update({
        'dietaryNeeds': dietaryNeeds,
        'foodDislikes': foodDislikes,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to update dietary preferences: $e');
    }
  }

  /// Update health goals
  Future<FirestoreResult<void>> updateHealthGoals(String uid, List<String> healthGoals) async {
    try {
      await _db.collection('users').doc(uid).update({
        'healthGoals': healthGoals,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to update health goals: $e');
    }
  }

  /// Update cultural preferences
  Future<FirestoreResult<void>> updateCulturalPreferences({
    required String uid,
    required Map<String, dynamic> culturalPreferences,
  }) async {
    try {
      await _db.collection('users').doc(uid).update({
        'culturalPreferences': culturalPreferences,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to update cultural preferences: $e');
    }
  }

  /// Update physical measurements
  Future<FirestoreResult<void>> updatePhysicalMeasurements({
    required String uid,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (age != null) updateData['age'] = age;
      if (gender != null) updateData['gender'] = gender;
      if (height != null) updateData['height'] = height;
      if (weight != null) updateData['weight'] = weight;
      if (activityLevel != null) updateData['activityLevel'] = activityLevel;

      await _db.collection('users').doc(uid).update(updateData);
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to update physical measurements: $e');
    }
  }

  /// Get users with similar dietary needs (for community features)
  Future<FirestoreResult<List<UserModel>>> getSimilarUsers(String uid, {int limit = 10}) async {
    try {
      final userResult = await getProfile(uid);
      if (userResult.error != null) {
        return FirestoreResult<List<UserModel>>(error: userResult.error);
      }

      final user = userResult.data!;
      final query = _db
          .collection('users')
          .where('dietaryNeeds', arrayContainsAny: user.dietaryNeeds.take(3).toList())
          .limit(limit);

      final snapshot = await query.get();
      final users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((u) => u.uid != uid) // Exclude current user
          .toList();

      return FirestoreResult<List<UserModel>>(data: users);
    } catch (e) {
      return FirestoreResult<List<UserModel>>(error: 'Failed to fetch similar users: $e');
    }
  }

  /// Validate profile completeness for personalized features
  Future<FirestoreResult<Map<String, bool>>> validateProfileCompleteness(String uid) async {
    try {
      final result = await getProfile(uid);
      if (result.error != null) {
        return FirestoreResult<Map<String, bool>>(error: result.error);
      }

      final user = result.data!;
      final completeness = {
        'basicInfo': user.name.isNotEmpty && user.email.isNotEmpty,
        'physicalMeasurements': user.age != null && user.gender != null,
        'healthGoals': user.healthGoals.isNotEmpty,
        'dietaryPreferences': user.dietaryNeeds.isNotEmpty,
        'medicalInfo': true, // Optional, so always true
        'culturalPreferences': user.culturalPreferences.isNotEmpty,
      };

      return FirestoreResult<Map<String, bool>>(data: completeness);
    } catch (e) {
      return FirestoreResult<Map<String, bool>>(error: 'Failed to validate profile: $e');
    }
  }

  /// Get profile completion percentage
  Future<FirestoreResult<double>> getProfileCompletionPercentage(String uid) async {
    try {
      final validationResult = await validateProfileCompleteness(uid);
      if (validationResult.error != null) {
        return FirestoreResult<double>(error: validationResult.error);
      }

      final completeness = validationResult.data!;
      final completedSections = completeness.values.where((v) => v).length;
      final totalSections = completeness.length;
      final percentage = (completedSections / totalSections) * 100;

      return FirestoreResult<double>(data: percentage);
    } catch (e) {
      return FirestoreResult<double>(error: 'Failed to calculate completion: $e');
    }
  }
}