import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive user profile model for voice-first AI agent
class UserModel {
  final String uid;
  final String name;
  final String email;
  final List<String> dietaryNeeds;
  final List<String> healthGoals;
  
  // Extended profile fields for voice-first AI agent
  final int? age;
  final String? gender;
  final double? height; // in cm
  final double? weight; // in kg
  final String? activityLevel; // sedentary, light, moderate, active, very_active
  final List<String> medicalConditions;
  final List<String> allergies;
  final List<String> foodDislikes;
  final String? preferredLanguage; // hindi, english, hinglish
  final Map<String, dynamic> culturalPreferences; // regional cuisine preferences
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Subscription and usage tracking
  final String subscriptionTier; // free, premium
  final DateTime? subscriptionExpiresAt;
  final int dailyQueriesUsed;
  final int monthlyQueriesLimit;
  final DateTime? lastQueryResetDate;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.dietaryNeeds = const [],
    this.healthGoals = const [],
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.activityLevel,
    this.medicalConditions = const [],
    this.allergies = const [],
    this.foodDislikes = const [],
    this.preferredLanguage = 'hinglish',
    this.culturalPreferences = const {},
    this.createdAt,
    this.updatedAt,
    this.subscriptionTier = 'free',
    this.subscriptionExpiresAt,
    this.dailyQueriesUsed = 0,
    this.monthlyQueriesLimit = 50, // Default for free tier
    this.lastQueryResetDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'dietaryNeeds': dietaryNeeds,
      'healthGoals': healthGoals,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'medicalConditions': medicalConditions,
      'allergies': allergies,
      'foodDislikes': foodDislikes,
      'preferredLanguage': preferredLanguage,
      'culturalPreferences': culturalPreferences,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'subscriptionTier': subscriptionTier,
      'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
      'dailyQueriesUsed': dailyQueriesUsed,
      'monthlyQueriesLimit': monthlyQueriesLimit,
      'lastQueryResetDate': lastQueryResetDate?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      dietaryNeeds: (map['dietaryNeeds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      healthGoals: (map['healthGoals'] as List?)?.map((e) => e.toString()).toList() ?? [],
      age: map['age']?.toInt(),
      gender: map['gender'],
      height: map['height']?.toDouble(),
      weight: map['weight']?.toDouble(),
      activityLevel: map['activityLevel'],
      medicalConditions: (map['medicalConditions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      allergies: (map['allergies'] as List?)?.map((e) => e.toString()).toList() ?? [],
      foodDislikes: (map['foodDislikes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      preferredLanguage: map['preferredLanguage'] ?? 'hinglish',
      culturalPreferences: Map<String, dynamic>.from(map['culturalPreferences'] ?? {}),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      subscriptionTier: map['subscriptionTier'] ?? 'free',
      subscriptionExpiresAt: map['subscriptionExpiresAt'] != null ? DateTime.parse(map['subscriptionExpiresAt']) : null,
      dailyQueriesUsed: map['dailyQueriesUsed'] ?? 0,
      monthlyQueriesLimit: map['monthlyQueriesLimit'] ?? 50,
      lastQueryResetDate: map['lastQueryResetDate'] != null ? DateTime.parse(map['lastQueryResetDate']) : null,
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    List<String>? dietaryNeeds,
    List<String>? healthGoals,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
    List<String>? medicalConditions,
    List<String>? allergies,
    List<String>? foodDislikes,
    String? preferredLanguage,
    Map<String, dynamic>? culturalPreferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subscriptionTier,
    DateTime? subscriptionExpiresAt,
    int? dailyQueriesUsed,
    int? monthlyQueriesLimit,
    DateTime? lastQueryResetDate,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      dietaryNeeds: dietaryNeeds ?? this.dietaryNeeds,
      healthGoals: healthGoals ?? this.healthGoals,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      allergies: allergies ?? this.allergies,
      foodDislikes: foodDislikes ?? this.foodDislikes,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      culturalPreferences: culturalPreferences ?? this.culturalPreferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      dailyQueriesUsed: dailyQueriesUsed ?? this.dailyQueriesUsed,
      monthlyQueriesLimit: monthlyQueriesLimit ?? this.monthlyQueriesLimit,
      lastQueryResetDate: lastQueryResetDate ?? this.lastQueryResetDate,
    );
  }

  /// Calculate BMI if height and weight are available
  double? get bmi {
    if (height != null && weight != null && height! > 0) {
      final heightInMeters = height! / 100;
      return weight! / (heightInMeters * heightInMeters);
    }
    return null;
  }

  /// Get BMI category
  String? get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return null;
    
    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal weight';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }

  /// Check if user has premium subscription
  bool get isPremium {
    if (subscriptionTier != 'premium') return false;
    if (subscriptionExpiresAt == null) return true; // Lifetime premium
    return DateTime.now().isBefore(subscriptionExpiresAt!);
  }

  /// Check if user has reached query limit
  bool get hasReachedQueryLimit {
    return dailyQueriesUsed >= monthlyQueriesLimit;
  }

  /// Get remaining queries for the month
  int get remainingQueries {
    return (monthlyQueriesLimit - dailyQueriesUsed).clamp(0, monthlyQueriesLimit);
  }

  /// Check if user has specific medical condition
  bool hasMedicalCondition(String condition) {
    return medicalConditions.any((c) => c.toLowerCase() == condition.toLowerCase());
  }

  /// Check if user has specific allergy
  bool hasAllergy(String allergen) {
    return allergies.any((a) => a.toLowerCase() == allergen.toLowerCase());
  }

  /// Check if user dislikes specific food
  bool dislikesFood(String food) {
    return foodDislikes.any((f) => f.toLowerCase() == food.toLowerCase());
  }

  /// Get user's preferred regional cuisine
  String get preferredRegionalCuisine {
    return culturalPreferences['preferredRegion'] ?? 'North Indian';
  }

  /// Check if profile is complete enough for personalized recommendations
  bool get isProfileComplete {
    return age != null && 
           gender != null && 
           healthGoals.isNotEmpty && 
           (height != null || weight != null);
  }
}

/// A result class for Firestore actions, containing either a user or an error message.
class FirestoreResult<T> {
  final T? data;
  final String? error;
  FirestoreResult({this.data, this.error});
}

/// Service for handling Firestore user profile operations.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get the grocery list for a user.
  Future<FirestoreResult<List<String>>> getGroceries(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final groceries = (doc.data()!['groceries'] as List?)?.map((e) => e.toString()).toList() ?? [];
        return FirestoreResult<List<String>>(data: List<String>.from(groceries));
      } else {
        return FirestoreResult<List<String>>(data: []);
      }
    } catch (e) {
      return FirestoreResult<List<String>>(error: 'Failed to fetch groceries: $e');
    }
  }

  /// Add a grocery item for a user.
  Future<FirestoreResult<void>> addGrocery(String uid, String item) async {
    try {
      await _db.collection('users').doc(uid).update({
        'groceries': FieldValue.arrayUnion([item])
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to add grocery: $e');
    }
  }

  /// Remove a grocery item for a user.
  Future<FirestoreResult<void>> removeGrocery(String uid, String item) async {
    try {
      await _db.collection('users').doc(uid).update({
        'groceries': FieldValue.arrayRemove([item])
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to remove grocery: $e');
    }
  }

  /// Get the meal plan for a user.
  Future<FirestoreResult<Map<String, List<String>>>> getMealPlan(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final mealPlanRaw = doc.data()!['mealPlan'] as Map<String, dynamic>?;
        final mealPlan = mealPlanRaw != null
            ? mealPlanRaw.map((k, v) => MapEntry(k, List<String>.from(v)))
            : <String, List<String>>{};
        return FirestoreResult<Map<String, List<String>>>(data: mealPlan);
      } else {
        return FirestoreResult<Map<String, List<String>>>(data: {});
      }
    } catch (e) {
      return FirestoreResult<Map<String, List<String>>>(error: 'Failed to fetch meal plan: $e');
    }
  }

  /// Set the meal plan for a user (overwrites all days).
  Future<FirestoreResult<void>> setMealPlan(String uid, Map<String, List<String>> mealPlan) async {
    try {
      await _db.collection('users').doc(uid).update({
        'mealPlan': mealPlan,
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to set meal plan: $e');
    }
  }

  /// Add a meal to a specific day for a user.
  Future<FirestoreResult<void>> addMeal(String uid, String day, String meal) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final mealPlanRaw = data['mealPlan'] as Map<String, dynamic>? ?? {};
      final mealPlan = mealPlanRaw.map((k, v) => MapEntry(k, List<String>.from(v)));
      final meals = List<String>.from(mealPlan[day] ?? []);
      meals.add(meal);
      mealPlan[day] = meals;
      await _db.collection('users').doc(uid).set({'mealPlan': mealPlan}, SetOptions(merge: true));
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to add meal: $e');
    }
  }

  /// Remove a meal from a specific day for a user.
  Future<FirestoreResult<void>> removeMeal(String uid, String day, String meal) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final mealPlanRaw = data['mealPlan'] as Map<String, dynamic>? ?? {};
      final mealPlan = mealPlanRaw.map((k, v) => MapEntry(k, List<String>.from(v)));
      final meals = List<String>.from(mealPlan[day] ?? []);
      meals.remove(meal);
      mealPlan[day] = meals;
      await _db.collection('users').doc(uid).update({'mealPlan': mealPlan});
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to remove meal: $e');
    }
  }

  /// Create or update a user profile.
  /// Returns [FirestoreResult] with null data or error message.
  Future<FirestoreResult<void>> setUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap());
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to save user: $e');
    }
  }

  /// Get a user's profile by uid.
  /// Returns [FirestoreResult] with UserModel or error message.
  Future<FirestoreResult<UserModel>> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return FirestoreResult<UserModel>(data: UserModel.fromMap(doc.data()!));
      } else {
        return FirestoreResult<UserModel>(error: 'User not found');
      }
    } catch (e) {
      return FirestoreResult<UserModel>(error: 'Failed to fetch user: $e');
    }
  }
}